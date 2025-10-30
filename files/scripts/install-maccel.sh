#!/bin/bash
set -euo pipefail

# install-maccel.sh - Maccel integration script for Blue Build
# This script handles kernel version detection, RPM package coordination,
# and installation of maccel mouse acceleration for MyAuroraBluebuild

# Configuration
MACCEL_RPM_BUILDER_REPO="${GITHUB_REPOSITORY_OWNER:-abirkel}/maccel-rpm-builder"
MACCEL_UPSTREAM_REPO="Gnarus-G/maccel"
MAX_WAIT_TIME=1800  # 30 minutes maximum wait time
POLL_INTERVAL=30    # Poll every 30 seconds

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_warn() {
    echo "[WARN] $1" >&2
}

# Function to detect kernel version from current system
detect_kernel_version() {
    log_info "Detecting kernel version from current system..."
    
    # Get kernel version from running system
    local kernel_version
    kernel_version=$(uname -r)
    
    if [[ -z "$kernel_version" ]]; then
        log_error "Failed to detect kernel version"
        return 1
    fi
    
    log_info "Detected kernel version: $kernel_version"
    echo "$kernel_version"
}

# Function to extract Fedora version from kernel version
extract_fedora_version() {
    local kernel_version="$1"
    local fedora_version
    
    # Extract Fedora version from kernel string (e.g., 6.11.5-300.fc41.x86_64 -> 41)
    fedora_version=$(echo "$kernel_version" | sed -n 's/.*\.fc\([0-9]\+\)\..*/\1/p')
    
    if [[ -z "$fedora_version" ]]; then
        log_warn "Could not extract Fedora version from kernel version, defaulting to 41"
        fedora_version="41"
    fi
    
    log_info "Extracted Fedora version: $fedora_version"
    echo "$fedora_version"
}

# Function to get latest maccel version from upstream
get_latest_maccel_version() {
    log_info "Getting latest maccel version from upstream..."
    
    local maccel_version
    if command -v gh >/dev/null 2>&1; then
        maccel_version=$(gh api repos/$MACCEL_UPSTREAM_REPO/releases/latest --jq '.tag_name' 2>/dev/null || echo "")
    fi
    
    # Fallback to curl if gh is not available or fails
    if [[ -z "$maccel_version" ]]; then
        maccel_version=$(curl -s "https://api.github.com/repos/$MACCEL_UPSTREAM_REPO/releases/latest" | \
            grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' || echo "")
    fi
    
    # Remove 'v' prefix if present
    maccel_version=${maccel_version#v}
    
    if [[ -z "$maccel_version" ]]; then
        log_warn "Could not detect maccel version, defaulting to 1.0.0"
        maccel_version="1.0.0"
    fi
    
    log_info "Latest maccel version: $maccel_version"
    echo "$maccel_version"
}

# Function to check if packages already exist
check_existing_packages() {
    local kernel_version="$1"
    local maccel_version="$2"
    local release_tag="kernel-${kernel_version}-maccel-${maccel_version}"
    
    log_info "Checking for existing packages with release tag: $release_tag"
    
    # Check if release exists using GitHub API
    local release_exists=false
    if command -v gh >/dev/null 2>&1; then
        if gh api "repos/$MACCEL_RPM_BUILDER_REPO/releases/tags/$release_tag" >/dev/null 2>&1; then
            release_exists=true
        fi
    else
        # Fallback to curl
        if curl -s -f "https://api.github.com/repos/$MACCEL_RPM_BUILDER_REPO/releases/tags/$release_tag" >/dev/null 2>&1; then
            release_exists=true
        fi
    fi
    
    if [[ "$release_exists" == "true" ]]; then
        log_info "Found existing release: $release_tag"
        echo "true"
    else
        log_info "No existing release found for: $release_tag"
        echo "false"
    fi
}

# Function to trigger maccel RPM build via repository dispatch
trigger_maccel_build() {
    local kernel_version="$1"
    local fedora_version="$2"
    local maccel_version="$3"
    
    log_info "Triggering maccel RPM build for kernel $kernel_version, Fedora $fedora_version, maccel $maccel_version"
    
    # Prepare repository dispatch payload
    local payload
    payload=$(cat <<EOF
{
  "kernel_version": "$kernel_version",
  "fedora_version": "$fedora_version",
  "trigger_repo": "MyAuroraBluebuild",
  "maccel_version": "$maccel_version"
}
EOF
)
    
    # Send repository dispatch using gh CLI if available
    if command -v gh >/dev/null 2>&1 && [[ -n "${GITHUB_TOKEN:-}" ]]; then
        log_info "Sending repository dispatch using gh CLI..."
        if gh api "repos/$MACCEL_RPM_BUILDER_REPO/dispatches" \
            --method POST \
            --field event_type='build-for-kernel' \
            --field client_payload="$payload"; then
            log_info "Repository dispatch sent successfully"
            return 0
        else
            log_error "Failed to send repository dispatch via gh CLI"
            return 1
        fi
    elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
        # Fallback to curl
        log_info "Sending repository dispatch using curl..."
        if curl -X POST \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/$MACCEL_RPM_BUILDER_REPO/dispatches" \
            -d "{\"event_type\":\"build-for-kernel\",\"client_payload\":$payload}"; then
            log_info "Repository dispatch sent successfully"
            return 0
        else
            log_error "Failed to send repository dispatch via curl"
            return 1
        fi
    else
        log_error "No GitHub token available for repository dispatch"
        log_error "Set GITHUB_TOKEN environment variable or ensure gh CLI is authenticated"
        return 1
    fi
}

# Function to wait for RPM build completion
wait_for_packages() {
    local kernel_version="$1"
    local maccel_version="$2"
    local release_tag="kernel-${kernel_version}-maccel-${maccel_version}"
    local wait_time=0
    
    log_info "Waiting for maccel RPM build to complete (max wait: ${MAX_WAIT_TIME}s)..."
    
    while [[ $wait_time -lt $MAX_WAIT_TIME ]]; do
        log_info "Checking for packages... (waited ${wait_time}s)"
        
        if [[ "$(check_existing_packages "$kernel_version" "$maccel_version")" == "true" ]]; then
            log_info "Packages are now available!"
            return 0
        fi
        
        log_info "Packages not ready yet, waiting ${POLL_INTERVAL}s..."
        sleep $POLL_INTERVAL
        wait_time=$((wait_time + POLL_INTERVAL))
    done
    
    log_error "Timeout waiting for packages after ${MAX_WAIT_TIME}s"
    return 1
}

# Function to generate package download URLs
generate_package_urls() {
    local kernel_version="$1"
    local maccel_version="$2"
    local fedora_version="$3"
    local release_tag="kernel-${kernel_version}-maccel-${maccel_version}"
    local base_url="https://github.com/$MACCEL_RPM_BUILDER_REPO/releases/download/$release_tag"
    
    local kmod_url="${base_url}/kmod-maccel-${maccel_version}-1.fc${fedora_version}.x86_64.rpm"
    local cli_url="${base_url}/maccel-${maccel_version}-1.fc${fedora_version}.x86_64.rpm"
    
    log_info "Generated package URLs:"
    log_info "  kmod-maccel: $kmod_url"
    log_info "  maccel CLI: $cli_url"
    
    echo "$kmod_url"
    echo "$cli_url"
}

# Function to download and install RPM packages
install_packages() {
    local kmod_url="$1"
    local cli_url="$2"
    local temp_dir="/tmp/maccel-install"
    
    log_info "Installing maccel RPM packages..."
    
    # Create temporary directory
    mkdir -p "$temp_dir"
    
    # Download packages
    log_info "Downloading kmod-maccel package..."
    if ! curl -L -f "$kmod_url" -o "$temp_dir/kmod-maccel.rpm"; then
        log_error "Failed to download kmod-maccel package from: $kmod_url"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_info "Downloading maccel CLI package..."
    if ! curl -L -f "$cli_url" -o "$temp_dir/maccel.rpm"; then
        log_error "Failed to download maccel CLI package from: $cli_url"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Install packages using rpm-ostree
    log_info "Installing packages with rpm-ostree..."
    if ! rpm-ostree install "$temp_dir/kmod-maccel.rpm" "$temp_dir/maccel.rpm"; then
        log_error "Failed to install maccel packages with rpm-ostree"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_info "Packages installed successfully"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    return 0
}

# Function to verify maccel configuration
verify_maccel_configuration() {
    log_info "Verifying maccel configuration..."
    
    # Check if maccel group exists (should be created by RPM package)
    if getent group maccel >/dev/null 2>&1; then
        log_info "✓ maccel group exists"
    else
        log_warn "⚠ maccel group not found - creating it"
        groupadd -r maccel || {
            log_error "Failed to create maccel group"
            return 1
        }
    fi
    
    # Check udev rules (should be installed by RPM package)
    if [[ -f "/etc/udev/rules.d/99-maccel.rules" ]]; then
        log_info "✓ maccel udev rules found"
        
        # Verify udev rules content
        if grep -q 'GROUP="maccel"' /etc/udev/rules.d/99-maccel.rules && \
           grep -q 'MODE="0660"' /etc/udev/rules.d/99-maccel.rules; then
            log_info "✓ udev rules have correct permissions"
        else
            log_warn "⚠ udev rules may have incorrect permissions"
        fi
        
        # Check for required device rules
        if grep -q "uinput" /etc/udev/rules.d/99-maccel.rules && \
           grep -q "event.*input" /etc/udev/rules.d/99-maccel.rules; then
            log_info "✓ udev rules cover required devices (uinput and input events)"
        else
            log_warn "⚠ udev rules may not cover all required devices"
        fi
    else
        log_error "✗ maccel udev rules not found at /etc/udev/rules.d/99-maccel.rules"
        return 1
    fi
    
    # Check module loading configuration
    if [[ -f "/etc/modules-load.d/maccel.conf" ]]; then
        log_info "✓ maccel module loading configuration found"
    else
        log_warn "⚠ maccel module loading configuration not found"
        log_info "Creating /etc/modules-load.d/maccel.conf"
        echo "maccel" > /etc/modules-load.d/maccel.conf || {
            log_error "Failed to create module loading configuration"
            return 1
        }
    fi
    
    log_info "Maccel configuration verification completed"
    return 0
}



# Main execution function
main() {
    log_info "Starting maccel integration for MyAuroraBluebuild..."
    
    # Step 1: Detect kernel version
    local kernel_version
    if ! kernel_version=$(detect_kernel_version); then
        log_error "Failed to detect kernel version - build cannot continue"
        return 1
    fi
    
    # Step 2: Extract Fedora version
    local fedora_version
    fedora_version=$(extract_fedora_version "$kernel_version")
    
    # Step 3: Get latest maccel version
    local maccel_version
    maccel_version=$(get_latest_maccel_version)
    
    log_info "Build parameters:"
    log_info "  Kernel version: $kernel_version"
    log_info "  Fedora version: $fedora_version"
    log_info "  Maccel version: $maccel_version"
    
    # Step 4: Check if packages already exist
    local packages_exist
    packages_exist=$(check_existing_packages "$kernel_version" "$maccel_version")
    
    if [[ "$packages_exist" == "false" ]]; then
        log_info "Packages don't exist, triggering build..."
        
        # Step 5: Trigger maccel RPM build
        if ! trigger_maccel_build "$kernel_version" "$fedora_version" "$maccel_version"; then
            log_error "Failed to trigger maccel RPM build - build cannot continue"
            return 1
        fi
        
        # Step 6: Wait for build completion
        if ! wait_for_packages "$kernel_version" "$maccel_version"; then
            log_error "Timeout waiting for maccel RPM build - build cannot continue"
            return 1
        fi
    else
        log_info "Packages already exist, skipping build trigger"
    fi
    
    # Step 7: Generate package URLs
    local package_urls
    package_urls=($(generate_package_urls "$kernel_version" "$maccel_version" "$fedora_version"))
    local kmod_url="${package_urls[0]}"
    local cli_url="${package_urls[1]}"
    
    # Step 8: Download and install packages
    if ! install_packages "$kmod_url" "$cli_url"; then
        log_error "Failed to download and install maccel packages - build cannot continue"
        return 1
    fi
    
    # Step 9: Verify configuration
    if ! verify_maccel_configuration; then
        log_warn "Configuration verification failed, but packages are installed"
        log_warn "Manual configuration may be required after deployment"
    fi
    
    log_info "Maccel integration completed successfully!"
    log_info "Users should add themselves to the maccel group: sudo usermod -aG maccel \$USER"
    log_info "Then reboot to start using maccel mouse acceleration"
    
    return 0
}

# Execute main function with all arguments
main "$@"