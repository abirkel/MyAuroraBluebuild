#!/bin/bash
# maccel-fallback.sh - Fallback mechanisms for maccel integration failures
# This script provides graceful degradation when maccel integration fails

set -euo pipefail

# Logging functions
log_info() {
    echo "[FALLBACK] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[FALLBACK-ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_warn() {
    echo "[FALLBACK-WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Function to create user notice about maccel integration failure
create_user_notice() {
    local error_reason="$1"
    local notice_file="/etc/maccel-integration-notice.txt"
    
    log_info "Creating user notice about maccel integration failure..."
    
    cat > "$notice_file" <<EOF
NOTICE: Maccel Integration Failed During Image Build

The maccel mouse acceleration driver could not be integrated during image build.
Reason: $error_reason

MANUAL INSTALLATION OPTIONS:

Option 1: Use maccel's native installer (recommended)
1. Install required dependencies:
   sudo dnf install git make dkms kernel-devel
2. Install maccel using the upstream installer:
   curl -sSL https://raw.githubusercontent.com/Gnarus-G/maccel/main/install.sh | bash
3. Add your user to the maccel group:
   sudo usermod -aG maccel \$USER
4. Reboot to load the kernel module

Option 2: Use RPM packages (if available)
1. Check for available packages at:
   https://github.com/abirkel/maccel-rpm-builder/releases
2. Download and install packages for your kernel version:
   sudo dnf install ./kmod-maccel-*.rpm ./maccel-*.rpm
3. Add your user to the maccel group:
   sudo usermod -aG maccel \$USER
4. Reboot to load the kernel module

Option 3: Build from source
1. Install build dependencies:
   sudo dnf install git rust cargo make kernel-devel
2. Clone and build maccel:
   git clone https://github.com/Gnarus-G/maccel.git
   cd maccel && make install
3. Follow post-installation steps from Option 1

TROUBLESHOOTING:
- Check kernel version: uname -r
- Verify group membership: groups \$USER
- Check module loading: lsmod | grep maccel
- View maccel logs: journalctl -u maccel

For more information, visit:
- maccel project: https://github.com/Gnarus-G/maccel
- MyAuroraBluebuild: https://github.com/abirkel/MyAuroraBluebuild

This notice was created on: $(date)
EOF
    
    log_info "User notice created at: $notice_file"
}

# Function to create a desktop notification script for users
create_desktop_notification() {
    local notification_script="/usr/local/bin/maccel-integration-notice"
    
    log_info "Creating desktop notification script..."
    
    cat > "$notification_script" <<'EOF'
#!/bin/bash
# Desktop notification about maccel integration failure

if command -v notify-send >/dev/null 2>&1; then
    notify-send "MyAuroraBluebuild Notice" \
        "Maccel integration failed during build. Check /etc/maccel-integration-notice.txt for manual installation instructions." \
        --icon=dialog-warning \
        --urgency=normal
fi

# Also show in terminal if run from terminal
if [[ -t 1 ]]; then
    echo "=== MyAuroraBluebuild Notice ==="
    echo "Maccel integration failed during image build."
    echo "See /etc/maccel-integration-notice.txt for manual installation instructions."
    echo "================================"
fi
EOF
    
    chmod +x "$notification_script"
    log_info "Desktop notification script created at: $notification_script"
}

# Function to create a systemd service for first-boot notification
create_notification_service() {
    local service_file="/etc/systemd/system/maccel-integration-notice.service"
    
    log_info "Creating systemd notification service..."
    
    cat > "$service_file" <<EOF
[Unit]
Description=Maccel Integration Notice
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/maccel-integration-notice
User=root
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the service
    systemctl enable maccel-integration-notice.service || {
        log_warn "Could not enable notification service"
    }
    
    log_info "Notification service created and enabled"
}

# Function to set up alternative mouse acceleration
setup_alternative_acceleration() {
    log_info "Setting up alternative mouse acceleration options..."
    
    # Create a script that users can run to set up libinput acceleration
    local alt_script="/usr/local/bin/setup-mouse-acceleration"
    
    cat > "$alt_script" <<'EOF'
#!/bin/bash
# Alternative mouse acceleration setup using libinput

echo "Setting up alternative mouse acceleration using libinput..."

# Create libinput configuration
sudo mkdir -p /etc/X11/xorg.conf.d/

cat > /tmp/40-libinput-mouse.conf <<'LIBINPUT_EOF'
Section "InputClass"
    Identifier "libinput pointer catchall"
    MatchIsPointer "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    Option "AccelProfile" "adaptive"
    Option "AccelSpeed" "0.5"
LIBINPUT_EOF

sudo mv /tmp/40-libinput-mouse.conf /etc/X11/xorg.conf.d/

echo "Alternative mouse acceleration configured."
echo "You may need to restart your session for changes to take effect."
echo "To adjust acceleration, modify AccelSpeed in /etc/X11/xorg.conf.d/40-libinput-mouse.conf"
echo "Values range from -1 (slowest) to 1 (fastest), default is 0"
EOF
    
    chmod +x "$alt_script"
    log_info "Alternative acceleration script created at: $alt_script"
}

# Function to create troubleshooting information
create_troubleshooting_info() {
    local info_file="/etc/maccel-troubleshooting.txt"
    
    log_info "Creating troubleshooting information..."
    
    cat > "$info_file" <<EOF
MyAuroraBluebuild - Maccel Troubleshooting Information

SYSTEM INFORMATION:
- Image build date: $(date)
- Base image: $(grep "base-image:" /etc/os-release 2>/dev/null || echo "Unknown")
- Kernel version: $(uname -r)
- Fedora version: $(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')

MACCEL INTEGRATION STATUS:
- Integration attempted: Yes
- Integration successful: No
- Fallback activated: Yes

COMMON ISSUES AND SOLUTIONS:

1. "maccel command not found"
   - Maccel was not installed during image build
   - Use manual installation options in /etc/maccel-integration-notice.txt

2. "Permission denied" when using maccel
   - Add your user to the maccel group: sudo usermod -aG maccel \$USER
   - Reboot after adding to group

3. "No such device" errors
   - Kernel module may not be loaded: sudo modprobe maccel
   - Check if module exists: find /lib/modules/\$(uname -r) -name "*maccel*"

4. Mouse acceleration not working
   - Verify maccel is running: maccel status
   - Check for conflicting acceleration: xinput list-props <device-id>
   - Try alternative acceleration: /usr/local/bin/setup-mouse-acceleration

USEFUL COMMANDS:
- Check kernel version: uname -r
- List input devices: xinput list
- Check loaded modules: lsmod | grep maccel
- View system logs: journalctl -b | grep maccel
- Test mouse settings: xinput test <device-id>

GETTING HELP:
- maccel project: https://github.com/Gnarus-G/maccel
- MyAuroraBluebuild issues: https://github.com/abirkel/MyAuroraBluebuild/issues
- Universal Blue community: https://universal-blue.org/

This file was generated on: $(date)
EOF
    
    log_info "Troubleshooting information created at: $info_file"
}

# Function to log integration failure details
log_integration_failure() {
    local error_reason="$1"
    local log_file="/var/log/maccel-integration-failure.log"
    
    log_info "Logging integration failure details..."
    
    cat > "$log_file" <<EOF
MyAuroraBluebuild - Maccel Integration Failure Log

Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Error Reason: $error_reason

System Information:
- Hostname: $(hostname)
- Kernel: $(uname -r)
- Architecture: $(uname -m)
- Fedora Version: $(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"' 2>/dev/null || echo "Unknown")

Environment Variables:
- GITHUB_TOKEN: $(if [[ -n "${GITHUB_TOKEN:-}" ]]; then echo "Set"; else echo "Not set"; fi)
- DISPATCH_TOKEN: $(if [[ -n "${DISPATCH_TOKEN:-}" ]]; then echo "Set"; else echo "Not set"; fi)

Network Connectivity:
- GitHub API: $(curl -s -o /dev/null -w "%{http_code}" https://api.github.com/ || echo "Failed")
- maccel-rpm-builder: $(curl -s -o /dev/null -w "%{http_code}" https://github.com/abirkel/maccel-rpm-builder || echo "Failed")

Available Tools:
- gh CLI: $(command -v gh >/dev/null && echo "Available" || echo "Not available")
- curl: $(command -v curl >/dev/null && echo "Available" || echo "Not available")
- rpm-ostree: $(command -v rpm-ostree >/dev/null && echo "Available" || echo "Not available")

This log can help diagnose integration issues.
EOF
    
    log_info "Integration failure logged to: $log_file"
}

# Main fallback handler
main() {
    local error_reason="${1:-Unknown error}"
    
    log_warn "Activating maccel integration fallback mechanisms..."
    log_warn "Reason: $error_reason"
    
    # Create all fallback resources
    create_user_notice "$error_reason"
    create_desktop_notification
    create_notification_service
    setup_alternative_acceleration
    create_troubleshooting_info
    log_integration_failure "$error_reason"
    
    log_info "Fallback mechanisms activated successfully"
    log_info "Image build will continue without maccel integration"
    log_info "Users can install maccel manually after deployment"
    
    return 0
}

# Execute main function with all arguments
main "$@"