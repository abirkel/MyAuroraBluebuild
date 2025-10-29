#!/bin/bash
set -euo pipefail

# install-maccel.sh - Maccel integration script for MyAuroraBluebuild
# This script coordinates with maccel-rpm-builder to install maccel packages

echo "Starting maccel integration..."

# Function to detect kernel version from current system
detect_kernel_version() {
    local kernel_version
    kernel_version=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)
    echo "Detected kernel version: $kernel_version"
    echo "$kernel_version"
}

# Function to trigger maccel RPM build via repository dispatch
trigger_maccel_build() {
    local kernel_version="$1"
    
    echo "Triggering maccel RPM build for kernel $kernel_version..."
    
    # Check if DISPATCH_TOKEN is available
    if [[ -z "${DISPATCH_TOKEN:-}" ]]; then
        echo "Warning: DISPATCH_TOKEN not set, skipping repository dispatch"
        return 0
    fi
    
    # Trigger maccel-rpm-builder via repository dispatch
    gh api repos/abirkel/maccel-rpm-builder/dispatches \
        --method POST \
        --field event_type='build-for-kernel' \
        --field client_payload="{
            \"kernel_version\": \"$kernel_version\",
            \"trigger_repo\": \"MyAuroraBluebuild\"
        }" || {
        echo "Warning: Failed to trigger maccel build, continuing without maccel integration"
        return 0
    }
    
    echo "Repository dispatch sent successfully"
}

# Function to wait for packages and install them
install_packages() {
    local kernel_version="$1"
    
    echo "Checking for maccel packages..."
    
    # For now, we'll implement a basic check
    # In a full implementation, this would poll for package availability
    echo "Note: Maccel package installation will be implemented in task 3.1"
    echo "This is a placeholder for the maccel integration logic"
    
    # Create maccel group (this should be done by the RPM package)
    groupadd -r maccel || true
    
    # Placeholder for udev rules (should be installed by maccel RPM)
    echo "Maccel group and udev rules will be configured by maccel RPM packages"
}

# Main execution
main() {
    echo "MyAuroraBluebuild maccel integration starting..."
    
    # Detect kernel version
    local kernel_version
    kernel_version=$(detect_kernel_version)
    
    # Trigger maccel build
    trigger_maccel_build "$kernel_version"
    
    # Install packages (placeholder for now)
    install_packages "$kernel_version"
    
    echo "Maccel integration completed successfully"
}

# Execute main function
main "$@"