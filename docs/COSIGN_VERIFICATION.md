# Cosign Image Verification Guide

MyAuroraBluebuild uses [Sigstore cosign](https://docs.sigstore.dev/cosign/overview/) for cryptographic signing of container images. This ensures the authenticity and integrity of the images you install.

## Overview

Our images are signed using **keyless signing** with GitHub's OIDC identity provider. This means:
- No private keys to manage or compromise
- Automatic signing through GitHub Actions
- Public verification through Sigstore's transparency log
- Full supply chain security without key management complexity

## Verification Commands

### Basic Verification

Verify the latest image with keyless signing:

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/.*/MyAuroraBluebuild" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/USERNAME/myaurorabluebuild:latest
```

Replace `USERNAME` with the actual GitHub username/organization.

### Verify Specific Tags

Verify a specific kernel version tag:

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/.*/MyAuroraBluebuild" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/USERNAME/myaurorabluebuild:kernel-6.11.5-300.fc41.x86_64
```

### Verify with Rekor Transparency Log

For additional security, verify against the Sigstore transparency log:

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/.*/MyAuroraBluebuild" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  --rekor-url=https://rekor.sigstore.dev \
  ghcr.io/USERNAME/myaurorabluebuild:latest
```

## Installation with Verification

### Using rpm-ostree with Signature Verification

1. **Add the signing policy** (optional but recommended):

Create `/etc/containers/policy.json` with signature verification:

```json
{
  "default": [
    {
      "type": "reject"
    }
  ],
  "transports": {
    "docker": {
      "ghcr.io/USERNAME/myaurorabluebuild": [
        {
          "type": "sigstoreSigned",
          "keyless": {
            "issuer": "https://token.actions.githubusercontent.com",
            "subject": "https://github.com/USERNAME/MyAuroraBluebuild/.github/workflows/build.yml@refs/heads/main"
          }
        }
      ]
    }
  }
}
```

2. **Rebase to the signed image**:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/USERNAME/myaurorabluebuild:latest
```

The `ostree-image-signed:` prefix ensures signature verification during installation.

### Manual Verification Before Installation

Verify the image before rebasing:

```bash
# Verify the image signature
cosign verify \
  --certificate-identity-regexp="https://github.com/.*/MyAuroraBluebuild" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/USERNAME/myaurorabluebuild:latest

# If verification succeeds, proceed with rebase
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/USERNAME/myaurorabluebuild:latest
```

## Understanding the Signature

### Certificate Identity

Our images are signed with the GitHub Actions identity:
- **Issuer**: `https://token.actions.githubusercontent.com`
- **Subject**: `https://github.com/USERNAME/MyAuroraBluebuild/.github/workflows/build.yml@refs/heads/main`

This proves the image was built by our official GitHub Actions workflow.

### Transparency Log

All signatures are recorded in Sigstore's public transparency log (Rekor), providing:
- Immutable audit trail
- Public verification of signing events
- Protection against signature backdating

## Troubleshooting

### Common Verification Issues

**Error: "no matching signatures"**
- Ensure you're using the correct image URL
- Check that the image tag exists
- Verify the certificate identity pattern matches

**Error: "certificate identity does not match"**
- Update the `--certificate-identity-regexp` pattern
- Ensure you're using the correct repository name

**Error: "OIDC issuer mismatch"**
- Verify the `--certificate-oidc-issuer` is exactly `https://token.actions.githubusercontent.com`

### Verification Without cosign

If cosign is not available, you can still verify through container registry metadata:

```bash
# Check image signatures in registry
skopeo inspect docker://ghcr.io/USERNAME/myaurorabluebuild:latest | jq '.Signatures'
```

## Security Best Practices

1. **Always verify signatures** before installing custom images
2. **Use signed image URLs** (`ostree-image-signed:`) with rpm-ostree
3. **Check transparency logs** for additional assurance
4. **Monitor signing certificates** for any unexpected changes
5. **Keep cosign updated** to the latest version

## Advanced Verification

### Verify Build Provenance

Check the build provenance attestation (if available):

```bash
cosign verify-attestation \
  --certificate-identity-regexp="https://github.com/.*/MyAuroraBluebuild" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  --type slsaprovenance \
  ghcr.io/USERNAME/myaurorabluebuild:latest
```

### Verify Multiple Tags

Verify all available tags for consistency:

```bash
#!/bin/bash
REPO="ghcr.io/USERNAME/myaurorabluebuild"
TAGS=("latest" "kernel-6.11.5-300.fc41.x86_64" "maccel-1.0.0" "fedora-41")

for tag in "${TAGS[@]}"; do
  echo "Verifying $REPO:$tag"
  cosign verify \
    --certificate-identity-regexp="https://github.com/.*/MyAuroraBluebuild" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    "$REPO:$tag"
done
```

## Migration from GPG Signing

If migrating from GPG-signed images:

1. **Remove old GPG verification** from container policies
2. **Update to cosign verification** as shown above
3. **Test verification** before production use
4. **Update documentation** and user instructions

## Support

For verification issues:
- Check the [GitHub Actions workflow logs](https://github.com/USERNAME/MyAuroraBluebuild/actions)
- Review [Sigstore documentation](https://docs.sigstore.dev/)
- Open an issue in the [MyAuroraBluebuild repository](https://github.com/USERNAME/MyAuroraBluebuild/issues)

---

**Note**: Replace `USERNAME` with the actual GitHub username/organization throughout this document.