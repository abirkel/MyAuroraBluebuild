#!/bin/bash
# MyAuroraBluebuild Health Check Script
# This script performs quick health checks on the image and services

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-abirkel}"
IMAGE_NAME="ghcr.io/${REPO_OWNER}/myaurorabluebuild"
TIMEOUT=30

echo -e "${BLUE}=== MyAuroraBluebuild Health Check ===${NC}"
echo "Image: ${IMAGE_NAME}"
echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo ""

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "pass")
            echo -e "${GREEN}✅ PASS: $message${NC}"
            ;;
        "fail")
            echo -e "${RED}❌ FAIL: $message${NC}"
            ;;
        "warn")
            echo -e "${YELLOW}⚠️ WARN: $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️ INFO: $message${NC}"
            ;;
    esac
}

# Track overall health
HEALTH_SCORE=0
TOTAL_CHECKS=0

# Function to run health check
run_check() {
    local check_name=$1
    local check_command=$2
    local success_message=$3
    local failure_message=$4
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    print_status "info" "Running: $check_name"
    
    if eval "$check_command" >/dev/null 2>&1; then
        print_status "pass" "$success_message"
        HEALTH_SCORE=$((HEALTH_SCORE + 1))
        return 0
    else
        print_status "fail" "$failure_message"
        return 1
    fi
}

echo "=== Image Availability Check ==="
run_check \
    "Image Pull Test" \
    "timeout $TIMEOUT docker pull ${IMAGE_NAME}:latest" \
    "Image is available and pullable" \
    "Image is not available or pull failed"
echo ""

echo "=== Basic Functionality Checks ==="
run_check \
    "Container Start Test" \
    "timeout $TIMEOUT docker run --rm ${IMAGE_NAME}:latest echo 'Container started successfully'" \
    "Container starts and runs successfully" \
    "Container fails to start or run"

run_check \
    "Maccel Package Check" \
    "docker run --rm ${IMAGE_NAME}:latest rpm -q maccel" \
    "Maccel CLI package is installed" \
    "Maccel CLI package is missing"

run_check \
    "Maccel Kernel Module Check" \
    "docker run --rm ${IMAGE_NAME}:latest rpm -q kmod-maccel" \
    "Maccel kernel module package is installed" \
    "Maccel kernel module package is missing"

run_check \
    "Maccel Group Check" \
    "docker run --rm ${IMAGE_NAME}:latest getent group maccel" \
    "Maccel group exists" \
    "Maccel group is missing"

run_check \
    "Udev Rules Check" \
    "docker run --rm ${IMAGE_NAME}:latest test -f /etc/udev/rules.d/99-maccel.rules" \
    "Maccel udev rules are present" \
    "Maccel udev rules are missing"

run_check \
    "Module Loading Config Check" \
    "docker run --rm ${IMAGE_NAME}:latest test -f /etc/modules-load.d/maccel.conf" \
    "Maccel module loading config is present" \
    "Maccel module loading config is missing"
echo ""

echo "=== System Integration Checks ==="
run_check \
    "RPM Database Check" \
    "docker run --rm ${IMAGE_NAME}:latest rpm -qa | wc -l | grep -q '[0-9]'" \
    "RPM database is functional" \
    "RPM database appears corrupted"

run_check \
    "Systemd Check" \
    "docker run --rm ${IMAGE_NAME}:latest systemctl --version" \
    "Systemd is available" \
    "Systemd is not available"

run_check \
    "User Management Check" \
    "docker run --rm ${IMAGE_NAME}:latest getent passwd root" \
    "User management is functional" \
    "User management has issues"
echo ""

echo "=== Performance Checks ==="
# Test container startup time
print_status "info" "Testing container startup performance"
START_TIME=$(date +%s%N)
if docker run --rm ${IMAGE_NAME}:latest echo "Performance test" >/dev/null 2>&1; then
    END_TIME=$(date +%s%N)
    STARTUP_TIME=$(( (END_TIME - START_TIME) / 1000000 ))  # Convert to milliseconds
    
    if [[ "$STARTUP_TIME" -lt 5000 ]]; then
        print_status "pass" "Container startup time is excellent (${STARTUP_TIME}ms)"
        HEALTH_SCORE=$((HEALTH_SCORE + 1))
    elif [[ "$STARTUP_TIME" -lt 10000 ]]; then
        print_status "pass" "Container startup time is good (${STARTUP_TIME}ms)"
        HEALTH_SCORE=$((HEALTH_SCORE + 1))
    elif [[ "$STARTUP_TIME" -lt 20000 ]]; then
        print_status "warn" "Container startup time is acceptable (${STARTUP_TIME}ms)"
    else
        print_status "fail" "Container startup time is slow (${STARTUP_TIME}ms)"
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
else
    print_status "fail" "Container performance test failed"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
fi

# Test image size
print_status "info" "Checking image size"
if IMAGE_SIZE=$(docker image inspect ${IMAGE_NAME}:latest --format='{{.Size}}' 2>/dev/null); then
    IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
    
    if [[ "$IMAGE_SIZE_MB" -lt 4096 ]]; then
        print_status "pass" "Image size is optimal (${IMAGE_SIZE_MB}MB)"
        HEALTH_SCORE=$((HEALTH_SCORE + 1))
    elif [[ "$IMAGE_SIZE_MB" -lt 6144 ]]; then
        print_status "pass" "Image size is reasonable (${IMAGE_SIZE_MB}MB)"
        HEALTH_SCORE=$((HEALTH_SCORE + 1))
    elif [[ "$IMAGE_SIZE_MB" -lt 8192 ]]; then
        print_status "warn" "Image size is large (${IMAGE_SIZE_MB}MB)"
    else
        print_status "fail" "Image size is very large (${IMAGE_SIZE_MB}MB)"
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
else
    print_status "fail" "Could not determine image size"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
fi
echo ""

echo "=== Custom Package Checks ==="
# Test some common custom packages that might be installed
run_check \
    "Custom Package Test (htop)" \
    "docker run --rm ${IMAGE_NAME}:latest rpm -q htop" \
    "Custom packages are installed correctly" \
    "Some custom packages may be missing (this may be expected)"

# Check for removed packages (should fail)
print_status "info" "Checking that removed packages are actually removed"
if docker run --rm ${IMAGE_NAME}:latest rpm -q sunshine >/dev/null 2>&1; then
    print_status "warn" "Removed package 'sunshine' is still present"
else
    print_status "pass" "Removed packages are properly removed"
    HEALTH_SCORE=$((HEALTH_SCORE + 1))
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
echo ""

echo "=== Security Checks ==="
run_check \
    "File Permissions Check" \
    "docker run --rm ${IMAGE_NAME}:latest test -r /etc/udev/rules.d/99-maccel.rules" \
    "Critical files have correct permissions" \
    "File permission issues detected"

run_check \
    "No Root Password Check" \
    "docker run --rm ${IMAGE_NAME}:latest grep -q '^root:!' /etc/shadow" \
    "Root account is properly secured" \
    "Root account security issue detected"
echo ""

# Calculate and display health score
echo "=== Health Check Summary ==="
HEALTH_PERCENTAGE=$((HEALTH_SCORE * 100 / TOTAL_CHECKS))

print_status "info" "Health Score: ${HEALTH_SCORE}/${TOTAL_CHECKS} (${HEALTH_PERCENTAGE}%)"

if [[ "$HEALTH_PERCENTAGE" -ge 90 ]]; then
    print_status "pass" "System health is EXCELLENT"
    EXIT_CODE=0
elif [[ "$HEALTH_PERCENTAGE" -ge 80 ]]; then
    print_status "pass" "System health is GOOD"
    EXIT_CODE=0
elif [[ "$HEALTH_PERCENTAGE" -ge 70 ]]; then
    print_status "warn" "System health is ACCEPTABLE - some issues need attention"
    EXIT_CODE=1
elif [[ "$HEALTH_PERCENTAGE" -ge 50 ]]; then
    print_status "warn" "System health is POOR - multiple issues need attention"
    EXIT_CODE=1
else
    print_status "fail" "System health is CRITICAL - immediate attention required"
    EXIT_CODE=2
fi

echo ""
echo "=== Recommendations ==="
if [[ "$HEALTH_PERCENTAGE" -lt 100 ]]; then
    echo "Based on the health check results:"
    
    if [[ "$HEALTH_SCORE" -lt "$TOTAL_CHECKS" ]]; then
        echo "• Review failed checks above and address issues"
        echo "• Check build logs for any warnings or errors"
        echo "• Verify maccel-rpm-builder integration is working"
        echo "• Consider running a fresh build if multiple issues exist"
    fi
    
    if [[ "$HEALTH_PERCENTAGE" -lt 80 ]]; then
        echo "• Run full maintenance check: ./scripts/maintenance-check.sh"
        echo "• Check monitoring workflow for recent issues"
        echo "• Review recent changes that might have caused problems"
    fi
    
    if [[ "$HEALTH_PERCENTAGE" -lt 50 ]]; then
        echo "• Consider reverting to a previous working image version"
        echo "• Check Aurora base image for recent breaking changes"
        echo "• Coordinate with maccel-rpm-builder maintainer if needed"
    fi
else
    echo "• System is healthy - no immediate action required"
    echo "• Continue regular monitoring and maintenance"
    echo "• Consider running this health check weekly"
fi

echo ""
echo "Health check completed at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo -e "${BLUE}=== Health Check Complete ===${NC}"

exit $EXIT_CODE