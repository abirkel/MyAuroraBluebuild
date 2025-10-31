#!/bin/bash
set -euo pipefail

# Build or fetch maccel RPM packages
# This script checks GitHub Releases for pre-built RPMs and downloads them if available.
# If not available, it builds the RPMs from spec files and uploads them to GitHub Releases.

echo "=== Maccel RPM Build/Fetch Script ==="

# Configuration
REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-abirkel}"
REPO_NAME="${GITHUB_REPOSITORY_NAME:-MyAuroraBluebuild}"
OUTPUT_DIR="/tmp/maccel-rpms"
RPMBUILD_DIR="$HOME/rpmbuild"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Get maccel version (should be set by generate-maccel-specs.sh)
MACCEL_VERSION="${MACCEL_VERSION:-latest}"
if [ "$MACCEL_VERSION" = "latest" ]; then
    echo "Detecting latest maccel version..."
    MACCEL_VERSION=$(curl -s https://api.github.com/repos/Gnarus-G/maccel/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    echo "Latest version: $MACCEL_VERSION"
fi

# Detect Fedora version
FEDORA_VERSION=$(rpm -E %fedora)
echo "Fedora version: $FEDORA_VERSION"

# Construct release tag
RELEASE_TAG="rpms-maccel-${MACCEL_VERSION}-fc${FEDORA_VERSION}"
echo "Release tag: $RELEASE_TAG"

# Function to check if release exists
check_release_exists() {
    local tag=$1
    echo "Checking if release $tag exists..."
    
    if curl -sf "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/tags/${tag}" > /dev/null 2>&1; then
        echo "✓ Release found"
        return 0
    else
        echo "✗ Release not found"
        return 1
    fi
}

# Function to download RPMs from release
download_rpms() {
    local tag=$1
    echo "Downloading RPMs from release $tag..."
    
    # Get release info
    local release_info
    release_info=$(curl -sf "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/tags/${tag}")
    
    # Download akmod-maccel RPM
    local akmod_url
    akmod_url=$(echo "$release_info" | jq -r '.assets[] | select(.name | startswith("akmod-maccel")) | .browser_download_url')
    if [ -n "$akmod_url" ]; then
        echo "Downloading akmod-maccel..."
        curl -L -o "$OUTPUT_DIR/$(basename "$akmod_url")" "$akmod_url"
    else
        echo "ERROR: akmod-maccel RPM not found in release"
        return 1
    fi
    
    # Download maccel RPM
    local maccel_url
    maccel_url=$(echo "$release_info" | jq -r '.assets[] | select(.name | startswith("maccel-") and (startswith("akmod-") | not)) | .browser_download_url')
    if [ -n "$maccel_url" ]; then
        echo "Downloading maccel..."
        curl -L -o "$OUTPUT_DIR/$(basename "$maccel_url")" "$maccel_url"
    else
        echo "ERROR: maccel RPM not found in release"
        return 1
    fi
    
    # Download checksums if available
    local checksums_url
    checksums_url=$(echo "$release_info" | jq -r '.assets[] | select(.name == "checksums.txt") | .browser_download_url')
    if [ -n "$checksums_url" ]; then
        echo "Downloading checksums..."
        curl -L -o "$OUTPUT_DIR/checksums.txt" "$checksums_url"
        
        # Verify checksums
        echo "Verifying checksums..."
        cd "$OUTPUT_DIR"
        sha256sum -c checksums.txt
        cd -
    fi
    
    echo "✓ RPMs downloaded successfully"
    return 0
}

# Function to build RPMs
build_rpms() {
    echo "Building RPMs from spec files..."
    
    # Check if spec files are available
    if [ -z "${AKMOD_SPEC_PATH:-}" ] || [ -z "${MACCEL_SPEC_PATH:-}" ]; then
        echo "ERROR: Spec file paths not set. Run generate-maccel-specs.sh first."
        exit 1
    fi
    
    if [ ! -f "$AKMOD_SPEC_PATH" ] || [ ! -f "$MACCEL_SPEC_PATH" ]; then
        echo "ERROR: Spec files not found"
        exit 1
    fi
    
    # Install build dependencies
    echo "Installing build dependencies..."
    dnf install -y \
        rpm-build \
        rpmdevtools \
        rust \
        cargo \
        gcc \
        make \
        kmodtool \
        akmods
    
    # Set up rpmbuild directory
    echo "Setting up rpmbuild directory..."
    rpmdev-setuptree
    
    # Build akmod-maccel
    echo "Building akmod-maccel..."
    rpmbuild -ba "$AKMOD_SPEC_PATH"
    
    # Build maccel
    echo "Building maccel..."
    rpmbuild -ba "$MACCEL_SPEC_PATH"
    
    # Copy built RPMs to output directory
    echo "Copying built RPMs..."
    find "$RPMBUILD_DIR/RPMS" -name "*.rpm" -exec cp {} "$OUTPUT_DIR/" \;
    
    # Generate checksums
    echo "Generating checksums..."
    cd "$OUTPUT_DIR"
    sha256sum *.rpm > checksums.txt
    cd -
    
    echo "✓ RPMs built successfully"
}

# Function to upload RPMs to GitHub Release
upload_to_release() {
    local tag=$1
    echo "Uploading RPMs to GitHub Release $tag..."
    
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        echo "WARNING: gh CLI not available, skipping upload"
        echo "RPMs will be rebuilt on next run"
        return 0
    fi
    
    # Check if GITHUB_TOKEN is available
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        echo "WARNING: GITHUB_TOKEN not set, skipping upload"
        echo "RPMs will be rebuilt on next run"
        return 0
    fi
    
    # Create release
    echo "Creating release..."
    gh release create "$tag" \
        --repo "${REPO_OWNER}/${REPO_NAME}" \
        --title "Maccel RPMs ${MACCEL_VERSION} for Fedora ${FEDORA_VERSION}" \
        --notes "Pre-built RPM packages for maccel ${MACCEL_VERSION} on Fedora ${FEDORA_VERSION}

Built from spec files generated from upstream maccel source.

**Packages:**
- akmod-maccel: Kernel module with AKMOD for automatic rebuilding
- maccel: CLI tools for mouse acceleration configuration

**Installation:**
\`\`\`bash
sudo dnf install akmod-maccel-*.rpm maccel-*.rpm
\`\`\`" \
        "$OUTPUT_DIR"/*.rpm \
        "$OUTPUT_DIR/checksums.txt" || {
            echo "WARNING: Failed to create release, continuing anyway"
            return 0
        }
    
    echo "✓ RPMs uploaded to release"
}

# Main logic
if check_release_exists "$RELEASE_TAG"; then
    # Download existing RPMs
    if download_rpms "$RELEASE_TAG"; then
        echo "✓ Using cached RPMs from GitHub Release"
    else
        echo "Failed to download RPMs, building instead..."
        build_rpms
        upload_to_release "$RELEASE_TAG"
    fi
else
    # Build new RPMs
    echo "No cached RPMs found, building..."
    build_rpms
    upload_to_release "$RELEASE_TAG"
fi

# List built/downloaded RPMs
echo ""
echo "=== Available RPMs ==="
ls -lh "$OUTPUT_DIR"/*.rpm

echo ""
echo "=== Maccel RPM Build/Fetch Complete ==="
