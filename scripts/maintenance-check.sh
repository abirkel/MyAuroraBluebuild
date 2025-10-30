#!/bin/bash
# MyAuroraBluebuild Maintenance Check Script
# This script performs routine maintenance checks and reports status

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-abirkel}"
REPO_NAME="${GITHUB_REPOSITORY##*/}"
IMAGE_NAME="ghcr.io/${REPO_OWNER}/myaurorabluebuild"

echo -e "${BLUE}=== MyAuroraBluebuild Maintenance Check ===${NC}"
echo "Repository: ${REPO_OWNER}/${REPO_NAME}"
echo "Image: ${IMAGE_NAME}"
echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo ""

# Function to check command availability
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}❌ Required command '$1' not found${NC}"
        echo "Please install $1 to run this maintenance check"
        exit 1
    fi
}

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️ $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️ $message${NC}"
            ;;
    esac
}

# Check required commands
echo "Checking required tools..."
check_command "gh"
check_command "skopeo"
check_command "jq"
check_command "docker"
print_status "success" "All required tools are available"
echo ""

# Check Aurora base image
echo "=== Aurora Base Image Check ==="
if [[ -f "recipes/recipe.yml" ]]; then
    BASE_IMAGE=$(grep "base-image:" recipes/recipe.yml | awk '{print $2}')
    IMAGE_VERSION=$(grep "image-version:" recipes/recipe.yml | awk '{print $2}')
    FULL_IMAGE="${BASE_IMAGE}:${IMAGE_VERSION}"
    
    print_status "info" "Base image: $FULL_IMAGE"
    
    # Check image accessibility
    if CURRENT_DIGEST=$(skopeo inspect docker://$FULL_IMAGE 2>/dev/null | jq -r '.Digest'); then
        print_status "success" "Aurora base image is accessible"
        print_status "info" "Digest: $CURRENT_DIGEST"
        
        # Get kernel version
        if KERNEL_VERSION=$(skopeo inspect docker://$FULL_IMAGE | jq -r '.Labels["ostree.linux"] // "unknown"'); then
            if [[ "$KERNEL_VERSION" != "unknown" ]]; then
                print_status "success" "Kernel version: $KERNEL_VERSION"
            else
                print_status "warning" "Could not detect kernel version"
            fi
        fi
    else
        print_status "error" "Aurora base image is not accessible"
    fi
else
    print_status "error" "Recipe file not found at recipes/recipe.yml"
fi
echo ""

# Check maccel version and availability
echo "=== Maccel Integration Check ==="
if MACCEL_VERSION=$(gh api repos/Gnarus-G/maccel/releases/latest --jq '.tag_name' 2>/dev/null | sed 's/^v//'); then
    print_status "success" "Latest maccel version: v$MACCEL_VERSION"
    
    # Check maccel-rpm-builder
    if gh api repos/${REPO_OWNER}/maccel-rpm-builder/releases/latest >/dev/null 2>&1; then
        print_status "success" "maccel-rpm-builder is accessible"
        
        # Check if packages exist for current kernel
        if [[ -n "${KERNEL_VERSION:-}" && "$KERNEL_VERSION" != "unknown" ]]; then
            RELEASE_TAG="kernel-${KERNEL_VERSION}-maccel-${MACCEL_VERSION}"
            
            if gh api repos/${REPO_OWNER}/maccel-rpm-builder/releases/tags/$RELEASE_TAG >/dev/null 2>&1; then
                print_status "success" "Maccel packages available for current kernel"
            else
                print_status "warning" "Maccel packages may not be available for kernel $KERNEL_VERSION"
                print_status "info" "Expected release tag: $RELEASE_TAG"
            fi
        fi
    else
        print_status "warning" "maccel-rpm-builder may not be accessible"
    fi
else
    print_status "error" "Could not fetch maccel version information"
fi
echo ""

# Check recent builds
echo "=== Recent Build Status ==="
if BUILD_RUNS=$(gh run list --workflow=build.yml --limit=5 --json status,conclusion,createdAt,headSha,headBranch 2>/dev/null); then
    echo "Recent builds:"
    echo "$BUILD_RUNS" | jq -r '.[] | "  \(.createdAt | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y-%m-%d %H:%M")) - \(.conclusion // .status) - \(.headBranch) (\(.headSha[0:7]))"'
    
    # Calculate success rate
    TOTAL_BUILDS=$(echo "$BUILD_RUNS" | jq length)
    SUCCESS_BUILDS=$(echo "$BUILD_RUNS" | jq '[.[] | select(.conclusion == "success")] | length')
    
    if [[ "$TOTAL_BUILDS" -gt 0 ]]; then
        SUCCESS_RATE=$(( SUCCESS_BUILDS * 100 / TOTAL_BUILDS ))
        print_status "info" "Success rate (last 5 builds): ${SUCCESS_RATE}%"
        
        if [[ "$SUCCESS_RATE" -ge 80 ]]; then
            print_status "success" "Build success rate is good"
        elif [[ "$SUCCESS_RATE" -ge 60 ]]; then
            print_status "warning" "Build success rate needs attention"
        else
            print_status "error" "Build success rate is poor"
        fi
    fi
else
    print_status "warning" "Could not fetch recent build information"
fi
echo ""

# Check image availability and size
echo "=== Image Status Check ==="
if docker pull "${IMAGE_NAME}:latest" >/dev/null 2>&1; then
    print_status "success" "Latest image is available"
    
    # Get image size
    if IMAGE_SIZE=$(docker image inspect "${IMAGE_NAME}:latest" --format='{{.Size}}' 2>/dev/null); then
        IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
        print_status "info" "Image size: ${IMAGE_SIZE_MB} MB"
        
        if [[ "$IMAGE_SIZE_MB" -gt 8192 ]]; then
            print_status "warning" "Image size is quite large (${IMAGE_SIZE_MB} MB)"
        elif [[ "$IMAGE_SIZE_MB" -gt 6144 ]]; then
            print_status "info" "Image size is moderate (${IMAGE_SIZE_MB} MB)"
        else
            print_status "success" "Image size is reasonable (${IMAGE_SIZE_MB} MB)"
        fi
    fi
    
    # Test basic functionality
    print_status "info" "Testing basic image functionality..."
    
    if docker run --rm "${IMAGE_NAME}:latest" rpm -q maccel >/dev/null 2>&1; then
        print_status "success" "Maccel package is installed"
    else
        print_status "error" "Maccel package is missing"
    fi
    
    if docker run --rm "${IMAGE_NAME}:latest" getent group maccel >/dev/null 2>&1; then
        print_status "success" "Maccel group exists"
    else
        print_status "error" "Maccel group is missing"
    fi
    
    if docker run --rm "${IMAGE_NAME}:latest" test -f /etc/udev/rules.d/99-maccel.rules 2>/dev/null; then
        print_status "success" "Maccel udev rules exist"
    else
        print_status "error" "Maccel udev rules are missing"
    fi
    
else
    print_status "error" "Latest image is not available"
fi
echo ""

# Check Blue Build framework version
echo "=== Blue Build Framework Check ==="
if [[ -f ".github/workflows/build.yml" ]]; then
    if CURRENT_BB_VERSION=$(grep "blue-build/github-action@" .github/workflows/build.yml | head -1 | sed 's/.*@v\([0-9.]*\).*/\1/'); then
        print_status "info" "Current Blue Build version: v$CURRENT_BB_VERSION"
        
        if LATEST_BB_VERSION=$(gh api repos/blue-build/github-action/releases/latest --jq '.tag_name' 2>/dev/null | sed 's/^v//'); then
            print_status "info" "Latest Blue Build version: v$LATEST_BB_VERSION"
            
            if [[ "$CURRENT_BB_VERSION" == "$LATEST_BB_VERSION" ]]; then
                print_status "success" "Blue Build framework is up to date"
            else
                print_status "warning" "Blue Build framework update available: v$CURRENT_BB_VERSION → v$LATEST_BB_VERSION"
            fi
        else
            print_status "warning" "Could not check latest Blue Build version"
        fi
    else
        print_status "warning" "Could not detect current Blue Build version"
    fi
else
    print_status "error" "Build workflow file not found"
fi
echo ""

# Check for open issues
echo "=== Issue Status Check ==="
if OPEN_ISSUES=$(gh issue list --state open --json number,title,labels 2>/dev/null); then
    TOTAL_ISSUES=$(echo "$OPEN_ISSUES" | jq length)
    BUILD_FAILURE_ISSUES=$(echo "$OPEN_ISSUES" | jq '[.[] | select(.labels[]?.name == "build-failure")] | length')
    MONITORING_ISSUES=$(echo "$OPEN_ISSUES" | jq '[.[] | select(.labels[]?.name == "monitoring")] | length')
    
    print_status "info" "Total open issues: $TOTAL_ISSUES"
    
    if [[ "$BUILD_FAILURE_ISSUES" -gt 0 ]]; then
        print_status "warning" "Build failure issues: $BUILD_FAILURE_ISSUES"
    fi
    
    if [[ "$MONITORING_ISSUES" -gt 0 ]]; then
        print_status "info" "Monitoring issues: $MONITORING_ISSUES"
    fi
    
    if [[ "$TOTAL_ISSUES" -eq 0 ]]; then
        print_status "success" "No open issues"
    elif [[ "$TOTAL_ISSUES" -le 5 ]]; then
        print_status "info" "Issue count is manageable"
    else
        print_status "warning" "High number of open issues"
    fi
else
    print_status "warning" "Could not fetch issue information"
fi
echo ""

# Summary
echo "=== Maintenance Check Summary ==="
echo "Check completed at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo ""
echo "Next recommended actions:"
echo "1. Review any warnings or errors above"
echo "2. Check monitoring workflow execution"
echo "3. Update dependencies if needed"
echo "4. Review and close resolved issues"
echo "5. Test image functionality if issues found"
echo ""
print_status "info" "For detailed monitoring, check the GitHub Actions workflows"
print_status "info" "For automated updates, ensure Dependabot is enabled"
echo ""
echo -e "${BLUE}=== Maintenance Check Complete ===${NC}"