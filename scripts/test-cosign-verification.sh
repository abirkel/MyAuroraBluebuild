#!/bin/bash
set -euo pipefail

# Test script for cosign image verification
# This script validates that the image signing and verification process works correctly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
IMAGE_NAME="ghcr.io/abirkel/myaurorabluebuild"
TAGS=("latest")
CERT_IDENTITY_REGEXP="https://github.com/abirkel/MyAuroraBluebuild"
OIDC_ISSUER="https://token.actions.githubusercontent.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if cosign is installed
check_cosign() {
    if ! command -v cosign &> /dev/null; then
        log_error "cosign is not installed. Please install it first:"
        echo "  # Using go install"
        echo "  go install github.com/sigstore/cosign/v2/cmd/cosign@latest"
        echo ""
        echo "  # Using package manager (example for Fedora)"
        echo "  sudo dnf install cosign"
        echo ""
        echo "  # Using binary download"
        echo "  curl -O -L https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
        echo "  sudo mv cosign-linux-amd64 /usr/local/bin/cosign"
        echo "  sudo chmod +x /usr/local/bin/cosign"
        exit 1
    fi
    
    local cosign_version
    cosign_version=$(cosign version --short 2>/dev/null || echo "unknown")
    log_info "cosign version: $cosign_version"
}

# Check if image exists
check_image_exists() {
    local image="$1"
    log_info "Checking if image exists: $image"
    
    if ! skopeo inspect "docker://$image" &>/dev/null; then
        log_error "Image does not exist or is not accessible: $image"
        log_info "Available tags can be checked with:"
        echo "  skopeo list-tags docker://${IMAGE_NAME}"
        return 1
    fi
    
    log_info "Image exists and is accessible"
    return 0
}

# Verify image signature with keyless signing
verify_keyless() {
    local image="$1"
    log_info "Verifying keyless signature for: $image"
    
    if cosign verify \
        --certificate-identity-regexp="$CERT_IDENTITY_REGEXP" \
        --certificate-oidc-issuer="$OIDC_ISSUER" \
        "$image" &>/dev/null; then
        log_info "✓ Keyless signature verification successful"
        return 0
    else
        log_error "✗ Keyless signature verification failed"
        return 1
    fi
}

# Verify image signature with Rekor transparency log
verify_rekor() {
    local image="$1"
    log_info "Verifying signature with Rekor transparency log: $image"
    
    if cosign verify \
        --certificate-identity-regexp="$CERT_IDENTITY_REGEXP" \
        --certificate-oidc-issuer="$OIDC_ISSUER" \
        --rekor-url=https://rekor.sigstore.dev \
        "$image" &>/dev/null; then
        log_info "✓ Rekor transparency log verification successful"
        return 0
    else
        log_error "✗ Rekor transparency log verification failed"
        return 1
    fi
}

# Get signature information
get_signature_info() {
    local image="$1"
    log_info "Getting signature information for: $image"
    
    echo "=== Signature Details ==="
    cosign verify \
        --certificate-identity-regexp="$CERT_IDENTITY_REGEXP" \
        --certificate-oidc-issuer="$OIDC_ISSUER" \
        "$image" 2>/dev/null | jq -r '.[0] | {
            "Certificate Subject": .optional.Subject,
            "Certificate Issuer": .optional.Issuer,
            "GitHub Workflow": .optional["github-workflow-name"],
            "GitHub Repository": .optional["github-workflow-repository"],
            "GitHub SHA": .optional["github-workflow-sha"],
            "Signature Algorithm": .optional["signature-algorithm"]
        }' || log_warn "Could not parse signature details"
    echo "========================="
}

# Test rpm-ostree compatibility
test_rpm_ostree_compatibility() {
    local image="$1"
    log_info "Testing rpm-ostree compatibility for: $image"
    
    # Check if we can inspect the image as an OCI container
    if skopeo inspect "docker://$image" | jq -r '.Labels["org.opencontainers.image.title"]' &>/dev/null; then
        log_info "✓ Image has proper OCI metadata"
    else
        log_warn "⚠ Image may be missing OCI metadata"
    fi
    
    # Check for ostree-specific labels
    local ostree_version
    ostree_version=$(skopeo inspect "docker://$image" | jq -r '.Labels["ostree.version"] // "not found"')
    log_info "OSTree version: $ostree_version"
    
    local ostree_commit
    ostree_commit=$(skopeo inspect "docker://$image" | jq -r '.Labels["ostree.commit"] // "not found"')
    log_info "OSTree commit: ${ostree_commit:0:12}..."
}

# Generate verification commands for users
generate_user_commands() {
    local image="$1"
    log_info "Generating verification commands for users"
    
    echo ""
    echo "=== User Verification Commands ==="
    echo ""
    echo "# Basic keyless verification:"
    echo "cosign verify \\"
    echo "  --certificate-identity-regexp=\"$CERT_IDENTITY_REGEXP\" \\"
    echo "  --certificate-oidc-issuer=\"$OIDC_ISSUER\" \\"
    echo "  $image"
    echo ""
    echo "# Verification with Rekor transparency log:"
    echo "cosign verify \\"
    echo "  --certificate-identity-regexp=\"$CERT_IDENTITY_REGEXP\" \\"
    echo "  --certificate-oidc-issuer=\"$OIDC_ISSUER\" \\"
    echo "  --rekor-url=https://rekor.sigstore.dev \\"
    echo "  $image"
    echo ""
    echo "# rpm-ostree installation with signature verification:"
    echo "rpm-ostree rebase ostree-image-signed:docker://$image"
    echo ""
    echo "=================================="
}

# Main test function
run_verification_tests() {
    local image="$1"
    local success=true
    
    log_info "Starting verification tests for: $image"
    echo ""
    
    # Test 1: Check image exists
    if ! check_image_exists "$image"; then
        success=false
    fi
    echo ""
    
    # Test 2: Keyless verification
    if ! verify_keyless "$image"; then
        success=false
    fi
    echo ""
    
    # Test 3: Rekor verification
    if ! verify_rekor "$image"; then
        success=false
    fi
    echo ""
    
    # Test 4: Get signature information
    get_signature_info "$image"
    echo ""
    
    # Test 5: rpm-ostree compatibility
    test_rpm_ostree_compatibility "$image"
    echo ""
    
    # Generate user commands
    generate_user_commands "$image"
    
    return $success
}

# Main execution
main() {
    log_info "MyAuroraBluebuild Cosign Verification Test"
    log_info "=========================================="
    echo ""
    
    # Check prerequisites
    check_cosign
    echo ""
    
    # Test all configured tags
    local overall_success=true
    for tag in "${TAGS[@]}"; do
        local image="${IMAGE_NAME}:${tag}"
        if ! run_verification_tests "$image"; then
            overall_success=false
        fi
        echo ""
        echo "----------------------------------------"
        echo ""
    done
    
    # Final report
    if $overall_success; then
        log_info "🎉 All verification tests passed!"
        log_info "The image signing and verification process is working correctly."
    else
        log_error "❌ Some verification tests failed!"
        log_error "Please check the output above for details."
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Test cosign verification for MyAuroraBluebuild images"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --image IMAGE  Test specific image (default: $IMAGE_NAME:latest)"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Test default image"
        echo "  $0 --image ghcr.io/user/image:tag   # Test specific image"
        exit 0
        ;;
    --image)
        if [[ -n "${2:-}" ]]; then
            TAGS=("${2#*:}")  # Extract tag from full image name
            IMAGE_NAME="${2%:*}"  # Extract image name without tag
        else
            log_error "Error: --image requires an argument"
            exit 1
        fi
        ;;
    "")
        # No arguments, use defaults
        ;;
    *)
        log_error "Unknown argument: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

# Run main function
main "$@"