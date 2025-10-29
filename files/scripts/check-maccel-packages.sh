#!/bin/bash
# check-maccel-packages.sh - Efficient package detection for maccel-rpm-builder coordination
# This script provides utilities for checking existing packages and avoiding unnecessary builds

set -euo pipefail

# Configuration
MACCEL_RPM_BUILDER_REPO="abirkel/maccel-rpm-builder"
MACCEL_UPSTREAM_REPO="Gnarus-G/maccel"

# Logging functions
log_info() {
    echo "[CHECK] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[CHECK-ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Function to check if a release exists
check_release_exists() {
    local release_tag="$1"
    
    if command -v gh >/dev/null 2>&1; then
        if gh api "repos/$MACCEL_RPM_BUILDER_REPO/releases/tags/$release_tag" >/dev/null 2>&1; then
            echo "true"
        else
            echo "false"
        fi
    else
        # Fallback to curl
        if curl -s -f "https://api.github.com/repos/$MACCEL_RPM_BUILDER_REPO/releases/tags/$release_tag" >/dev/null 2>&1; then
            echo "true"
        else
            echo "false"
        fi
    fi
}

# Function to get package URLs from a release
get_package_urls() {
    local release_tag="$1"
    local maccel_version="$2"
    local fedora_version="$3"
    
    local base_url="https://github.com/$MACCEL_RPM_BUILDER_REPO/releases/download/$release_tag"
    local kmod_url="${base_url}/kmod-maccel-${maccel_version}-1.fc${fedora_version}.x86_64.rpm"
    local cli_url="${base_url}/maccel-${maccel_version}-1.fc${fedora_version}.x86_64.rpm"
    
    echo "$kmod_url"
    echo "$cli_url"
}

# Function to verify package accessibility
verify_package_urls() {
    local kmod_url="$1"
    local cli_url="$2"
    
    local kmod_accessible=false
    local cli_accessible=false
    
    if curl -I "$kmod_url" 2>/dev/null | grep -q "200 OK"; then
        kmod_accessible=true
    fi
    
    if curl -I "$cli_url" 2>/dev/null | grep -q "200 OK"; then
        cli_accessible=true
    fi
    
    if [[ "$kmod_accessible" == "true" && "$cli_accessible" == "true" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to get latest maccel version
get_latest_maccel_version() {
    local maccel_version=""
    
    if command -v gh >/dev/null 2>&1; then
        maccel_version=$(gh api "repos/$MACCEL_UPSTREAM_REPO/releases/latest" --jq '.tag_name' 2>/dev/null | sed 's/^v//' || echo "")
    fi
    
    # Fallback to curl if gh is not available or fails
    if [[ -z "$maccel_version" ]]; then
        maccel_version=$(curl -s "https://api.github.com/repos/$MACCEL_UPSTREAM_REPO/releases/latest" | \
            grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | sed 's/^v//' || echo "")
    fi
    
    if [[ -z "$maccel_version" ]]; then
        maccel_version="1.0.0"
    fi
    
    echo "$maccel_version"
}

# Function to generate release tag
generate_release_tag() {
    local kernel_version="$1"
    local maccel_version="$2"
    
    echo "kernel-${kernel_version}-maccel-${maccel_version}"
}

# Function to list all releases for a kernel pattern
list_kernel_releases() {
    local kernel_pattern="$1"
    
    if command -v gh >/dev/null 2>&1; then
        gh api "repos/$MACCEL_RPM_BUILDER_REPO/releases" --jq ".[].tag_name" | grep "$kernel_pattern" || true
    else
        curl -s "https://api.github.com/repos/$MACCEL_RPM_BUILDER_REPO/releases" | \
            grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | grep "$kernel_pattern" || true
    fi
}

# Function to get build status information
get_build_info() {
    local release_tag="$1"
    
    log_info "Getting build information for release: $release_tag"
    
    if command -v gh >/dev/null 2>&1; then
        local release_info
        release_info=$(gh api "repos/$MACCEL_RPM_BUILDER_REPO/releases/tags/$release_tag" 2>/dev/null || echo "")
        
        if [[ -n "$release_info" ]]; then
            local created_at
            local assets_count
            created_at=$(echo "$release_info" | jq -r '.created_at')
            assets_count=$(echo "$release_info" | jq -r '.assets | length')
            
            log_info "Release created: $created_at"
            log_info "Number of assets: $assets_count"
            
            # List assets
            echo "$release_info" | jq -r '.assets[].name' | while read -r asset; do
                log_info "Asset: $asset"
            done
        else
            log_error "Release not found: $release_tag"
        fi
    else
        log_info "GitHub CLI not available, limited build information"
    fi
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    
    case "$command" in
        "check")
            if [[ $# -lt 3 ]]; then
                log_error "Usage: $0 check <kernel_version> <maccel_version>"
                exit 1
            fi
            local kernel_version="$2"
            local maccel_version="$3"
            local release_tag
            release_tag=$(generate_release_tag "$kernel_version" "$maccel_version")
            check_release_exists "$release_tag"
            ;;
            
        "urls")
            if [[ $# -lt 4 ]]; then
                log_error "Usage: $0 urls <kernel_version> <maccel_version> <fedora_version>"
                exit 1
            fi
            local kernel_version="$2"
            local maccel_version="$3"
            local fedora_version="$4"
            local release_tag
            release_tag=$(generate_release_tag "$kernel_version" "$maccel_version")
            get_package_urls "$release_tag" "$maccel_version" "$fedora_version"
            ;;
            
        "verify")
            if [[ $# -lt 3 ]]; then
                log_error "Usage: $0 verify <kmod_url> <cli_url>"
                exit 1
            fi
            local kmod_url="$2"
            local cli_url="$3"
            verify_package_urls "$kmod_url" "$cli_url"
            ;;
            
        "latest-maccel")
            get_latest_maccel_version
            ;;
            
        "release-tag")
            if [[ $# -lt 3 ]]; then
                log_error "Usage: $0 release-tag <kernel_version> <maccel_version>"
                exit 1
            fi
            local kernel_version="$2"
            local maccel_version="$3"
            generate_release_tag "$kernel_version" "$maccel_version"
            ;;
            
        "list")
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 list <kernel_pattern>"
                exit 1
            fi
            local kernel_pattern="$2"
            list_kernel_releases "$kernel_pattern"
            ;;
            
        "info")
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 info <release_tag>"
                exit 1
            fi
            local release_tag="$2"
            get_build_info "$release_tag"
            ;;
            
        "help"|*)
            cat << EOF
Usage: $0 <command> [arguments]

Commands:
  check <kernel_version> <maccel_version>
    Check if packages exist for the given kernel and maccel versions
    Returns: true/false
    
  urls <kernel_version> <maccel_version> <fedora_version>
    Generate package download URLs for the given versions
    Returns: kmod_url and cli_url (one per line)
    
  verify <kmod_url> <cli_url>
    Verify that package URLs are accessible
    Returns: true/false
    
  latest-maccel
    Get the latest maccel version from upstream
    Returns: version string
    
  release-tag <kernel_version> <maccel_version>
    Generate release tag for the given versions
    Returns: release tag string
    
  list <kernel_pattern>
    List all releases matching the kernel pattern
    Returns: list of release tags
    
  info <release_tag>
    Get detailed information about a release
    Returns: release information
    
  help
    Show this help message

Examples:
  $0 check 6.11.5-300.fc41.x86_64 1.0.0
  $0 urls 6.11.5-300.fc41.x86_64 1.0.0 41
  $0 latest-maccel
  $0 list 6.11.5-300.fc41.x86_64
EOF
            ;;
    esac
}

# Execute main function with all arguments
main "$@"