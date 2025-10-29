# GitHub Actions Secrets Setup

This document outlines the secrets that need to be configured for MyAuroraBluebuild.

## Required Secrets

### 1. SIGNING_SECRET (Optional - for private key signing)
- **Purpose**: Cosign private key for image signing
- **Recommended**: Use keyless signing instead (omit this secret)
- **Setup**: Only needed if you prefer private key signing over keyless signing

### 2. DISPATCH_TOKEN (Required for maccel integration)
- **Purpose**: GitHub token for triggering maccel-rpm-builder workflows
- **Setup**: Create a Personal Access Token with `repo` scope
- **Usage**: Used by install-maccel.sh script to trigger repository dispatch

## Keyless Signing (Recommended)
The Blue Build workflow supports keyless signing using GitHub's OIDC identity. This is the preferred approach as it:
- Eliminates private key management
- Uses GitHub's identity for automatic signing
- Provides transparency through Sigstore

To use keyless signing, simply omit the `cosign_private_key` parameter in the workflow.

## Setup Instructions

1. Go to repository Settings > Secrets and variables > Actions
2. Add the required secrets listed above
3. Ensure the workflow has proper permissions (already configured)

## Next Steps
- Configure the workflow to use keyless signing
- Set up DISPATCH_TOKEN for maccel-rpm-builder integration
- Test the build workflow