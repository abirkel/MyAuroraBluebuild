#!/bin/bash
# validate-maccel.sh - Post-installation validation for maccel configuration
# This script verifies that maccel is properly configured after installation

set -euo pipefail

# Logging functions
log_info() {
    echo "[VALIDATE] $1"
}

log_error() {
    echo "[VALIDATE-ERROR] $1" >&2
}

log_warn() {
    echo "[VALIDATE-WARN] $1" >&2
}

# Function to validate maccel group
validate_maccel_group() {
    log_info "Validating maccel group..."
    
    if getent group maccel >/dev/null 2>&1; then
        log_info "✓ maccel group exists"
        return 0
    else
        log_error "✗ maccel group does not exist"
        return 1
    fi
}

# Function to validate udev rules
validate_udev_rules() {
    log_info "Validating maccel udev rules..."
    
    local rules_file="/etc/udev/rules.d/99-maccel.rules"
    
    if [[ ! -f "$rules_file" ]]; then
        log_error "✗ maccel udev rules file not found: $rules_file"
        return 1
    fi
    
    log_info "✓ udev rules file exists: $rules_file"
    
    # Check for required content
    local has_maccel_group=false
    local has_correct_mode=false
    
    if grep -q "uinput" "$rules_file"; then
        log_info "✓ udev rules cover uinput device"
    else
        log_warn "⚠ udev rules may not cover uinput device"
    fi
    
    if grep -q "event.*input" "$rules_file"; then
        log_info "✓ udev rules cover input event devices"
    else
        log_warn "⚠ udev rules may not cover input event devices"
    fi
    
    if grep -q 'GROUP="maccel"' "$rules_file"; then
        has_maccel_group=true
        log_info "✓ udev rules specify maccel group"
    else
        log_error "✗ udev rules do not specify maccel group"
    fi
    
    if grep -q 'MODE="0660"' "$rules_file"; then
        has_correct_mode=true
        log_info "✓ udev rules specify correct permissions (0660)"
    else
        log_warn "⚠ udev rules may not have correct permissions"
    fi
    
    if [[ "$has_maccel_group" == "true" && "$has_correct_mode" == "true" ]]; then
        log_info "✓ udev rules have proper permissions configuration"
        return 0
    else
        log_error "✗ udev rules do not have proper permissions configuration"
        return 1
    fi
}

# Function to validate module loading configuration
validate_module_config() {
    log_info "Validating maccel module loading configuration..."
    
    local module_config="/etc/modules-load.d/maccel.conf"
    
    if [[ -f "$module_config" ]]; then
        log_info "✓ maccel module loading configuration exists"
        
        if grep -q "maccel" "$module_config"; then
            log_info "✓ maccel module is configured to load at boot"
            return 0
        else
            log_warn "⚠ maccel module may not be configured to load at boot"
            return 1
        fi
    else
        log_warn "⚠ maccel module loading configuration not found: $module_config"
        return 1
    fi
}

# Function to validate installed packages
validate_packages() {
    log_info "Validating installed maccel packages..."
    
    local kmod_installed=false
    local cli_installed=false
    
    if rpm -q kmod-maccel >/dev/null 2>&1; then
        kmod_installed=true
        local kmod_version
        kmod_version=$(rpm -q kmod-maccel --queryformat '%{VERSION}-%{RELEASE}')
        log_info "✓ kmod-maccel package installed: $kmod_version"
    else
        log_error "✗ kmod-maccel package not installed"
    fi
    
    if rpm -q maccel >/dev/null 2>&1; then
        cli_installed=true
        local cli_version
        cli_version=$(rpm -q maccel --queryformat '%{VERSION}-%{RELEASE}')
        log_info "✓ maccel CLI package installed: $cli_version"
    else
        log_error "✗ maccel CLI package not installed"
    fi
    
    if [[ "$kmod_installed" == "true" && "$cli_installed" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate CLI accessibility
validate_cli() {
    log_info "Validating maccel CLI accessibility..."
    
    if command -v maccel >/dev/null 2>&1; then
        log_info "✓ maccel CLI is accessible in PATH"
        
        # Try to get version (this should work even without the kernel module loaded)
        if maccel --version >/dev/null 2>&1; then
            local version
            version=$(maccel --version 2>/dev/null || echo "unknown")
            log_info "✓ maccel CLI responds to --version: $version"
            return 0
        else
            log_warn "⚠ maccel CLI does not respond to --version command"
            return 1
        fi
    else
        log_error "✗ maccel CLI not found in PATH"
        return 1
    fi
}

# Main validation function
main() {
    log_info "Starting maccel configuration validation..."
    
    local validation_passed=true
    
    # Run all validation checks
    if ! validate_maccel_group; then
        validation_passed=false
    fi
    
    if ! validate_udev_rules; then
        validation_passed=false
    fi
    
    if ! validate_module_config; then
        validation_passed=false
    fi
    
    if ! validate_packages; then
        validation_passed=false
    fi
    
    if ! validate_cli; then
        validation_passed=false
    fi
    
    # Summary
    if [[ "$validation_passed" == "true" ]]; then
        log_info "✅ All maccel configuration validations passed!"
        log_info "Users should add themselves to the maccel group: sudo usermod -aG maccel \$USER"
        log_info "Then reboot to start using maccel mouse acceleration"
        return 0
    else
        log_error "❌ Some maccel configuration validations failed"
        log_error "Manual configuration may be required after deployment"
        return 1
    fi
}

# Execute main function
main "$@"