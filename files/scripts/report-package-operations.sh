#!/bin/bash
set -euo pipefail

# report-package-operations.sh - Report on package installation/removal operations
# This script provides visibility into which package operations succeeded or failed

# Logging functions
log_info() {
    echo "[REPORT] $1"
}

log_warn() {
    echo "[REPORT-WARN] $1" >&2
}

# Function to check if a package is installed
is_package_installed() {
    local package="$1"
    rpm -q "$package" >/dev/null 2>&1
}

# Function to check if a flatpak is installed
is_flatpak_installed() {
    local app_id="$1"
    flatpak list --app --columns=application 2>/dev/null | grep -q "^${app_id}$"
}

# Main reporting function
main() {
    log_info "=== Package Operation Report ==="
    log_info ""
    
    # Report on RPM removals (from recipe.yml)
    log_info "RPM Packages - Removal Attempts:"
    local rpm_removals=("sunshine")
    local removed_count=0
    local skipped_count=0
    
    for pkg in "${rpm_removals[@]}"; do
        if ! is_package_installed "$pkg"; then
            log_info "  ✓ $pkg - Not present (removal skipped or successful)"
            skipped_count=$((skipped_count + 1))
        else
            log_warn "  ⚠ $pkg - Still installed (removal may have failed)"
        fi
    done
    
    log_info "  Summary: $skipped_count package(s) not present"
    log_info ""
    
    # Report on RPM installations (from recipe.yml)
    log_info "RPM Packages - Installation Attempts:"
    local rpm_installs=("htop" "maccel" "kmod-maccel")
    local installed_count=0
    local failed_count=0
    
    for pkg in "${rpm_installs[@]}"; do
        if is_package_installed "$pkg"; then
            log_info "  ✓ $pkg - Successfully installed"
            installed_count=$((installed_count + 1))
        else
            log_warn "  ✗ $pkg - Not installed (installation may have failed)"
            failed_count=$((failed_count + 1))
        fi
    done
    
    log_info "  Summary: $installed_count installed, $failed_count failed"
    log_info ""
    
    # Report on Flatpak removals (from recipe.yml)
    log_info "Flatpak Applications - Removal Attempts:"
    local flatpak_removals=("org.mozilla.Thunderbird")
    local flat_removed_count=0
    local flat_skipped_count=0
    
    for app in "${flatpak_removals[@]}"; do
        if ! is_flatpak_installed "$app"; then
            log_info "  ✓ $app - Not present (removal skipped or successful)"
            flat_skipped_count=$((flat_skipped_count + 1))
        else
            log_warn "  ⚠ $app - Still installed (removal may have failed)"
        fi
    done
    
    log_info "  Summary: $flat_skipped_count application(s) not present"
    log_info ""
    
    # Report on Flatpak installations (from recipe.yml)
    log_info "Flatpak Applications - Installation Attempts:"
    local flatpak_installs=("org.keepassxc.KeePassXC")
    local flat_installed_count=0
    local flat_failed_count=0
    
    for app in "${flatpak_installs[@]}"; do
        if is_flatpak_installed "$app"; then
            log_info "  ✓ $app - Successfully installed"
            flat_installed_count=$((flat_installed_count + 1))
        else
            log_warn "  ✗ $app - Not installed (installation may have failed)"
            flat_failed_count=$((flat_failed_count + 1))
        fi
    done
    
    log_info "  Summary: $flat_installed_count installed, $flat_failed_count failed"
    log_info ""
    log_info "=== End Package Operation Report ==="
    
    return 0
}

# Execute main function
main "$@"
