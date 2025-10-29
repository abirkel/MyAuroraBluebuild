# Maintenance and Update Procedures

This document outlines the maintenance procedures and update processes for MyAuroraBluebuild, ensuring the project remains current, secure, and functional over time.

## Overview

MyAuroraBluebuild requires regular maintenance to:
- Keep up with Aurora base image updates
- Maintain compatibility with maccel updates
- Update Blue Build framework components
- Address security vulnerabilities
- Optimize build performance
- Ensure user experience quality

## Maintenance Schedule

### Daily (Automated)
- **Aurora Base Image Monitoring**: Automatic checks every 6 hours
- **Build Execution**: Scheduled daily builds at 06:00 UTC
- **Issue Cleanup**: Automated cleanup of resolved monitoring issues
- **Dashboard Updates**: Real-time build status and metrics

### Weekly (Manual Review)
- **Monitoring Review**: Check build failure patterns and success rates
- **Issue Triage**: Review and prioritize open issues
- **Documentation Updates**: Update docs based on recent changes
- **User Feedback**: Review and respond to user reports

### Monthly (Planned Maintenance)
- **Dependency Updates**: Review and update all dependencies
- **Security Audit**: Check for security vulnerabilities
- **Performance Review**: Analyze build times and optimization opportunities
- **Process Improvement**: Evaluate and improve maintenance procedures

### Quarterly (Major Updates)
- **Framework Updates**: Update Blue Build framework to latest version
- **Architecture Review**: Evaluate system architecture and improvements
- **Documentation Overhaul**: Comprehensive documentation review and updates
- **User Survey**: Gather feedback on image quality and features

## Update Procedures

### 1. Aurora Base Image Updates

Aurora base image updates are the most frequent and critical updates for MyAuroraBluebuild.

#### Automatic Handling

The system automatically handles Aurora updates through:

1. **Detection**: Monitoring workflow checks Aurora digest every 6 hours
2. **Notification**: GitHub issue created when update detected
3. **Build Trigger**: Automatic build triggered with new base image
4. **Verification**: Build process validates new kernel version compatibility

#### Manual Intervention Required

Some Aurora updates may require manual intervention:

**New Kernel Major Version**:
```bash
# Check kernel compatibility
KERNEL_VERSION=$(skopeo inspect docker://ghcr.io/ublue-os/aurora-nvidia:latest | jq -r '.Labels["ostree.linux"]')
echo "New kernel version: $KERNEL_VERSION"

# Verify maccel compatibility
gh api repos/abirkel/maccel-rpm-builder/releases | jq -r '.[].tag_name' | grep "$KERNEL_VERSION"
```

**Fedora Version Updates**:
```bash
# Update recipe.yml if needed
# Check for package availability in new Fedora version
# Test build with new Fedora base
```

**Breaking Changes**:
- Review Aurora changelog for breaking changes
- Update recipe.yml configuration if needed
- Test build and functionality thoroughly
- Update documentation for user-facing changes

#### Aurora Update Checklist

- [ ] Monitor Aurora update notification issue
- [ ] Verify automatic build triggered successfully
- [ ] Check build logs for any new warnings or errors
- [ ] Test maccel functionality in new image
- [ ] Verify all packages install correctly
- [ ] Update documentation if there are user-facing changes
- [ ] Close Aurora update issue when resolved

### 2. Blue Build Framework Updates

Blue Build framework updates improve functionality and security.

#### Update Process

1. **Check Current Version**:
```bash
# Check current Blue Build action version in .github/workflows/build.yml
grep "blue-build/github-action@" .github/workflows/build.yml
```

2. **Review Release Notes**:
- Visit [Blue Build releases](https://github.com/blue-build/github-action/releases)
- Review changelog for breaking changes
- Check for new features or improvements

3. **Update Workflow**:
```yaml
# In .github/workflows/build.yml
- name: Build Custom Image
  uses: blue-build/github-action@v1.9  # Update version here
  with:
    recipe: ${{ matrix.recipe }}
    registry_token: ${{ github.token }}
    pr_event_number: ${{ github.event.number }}
    maximize_build_space: true
```

4. **Test Update**:
```bash
# Trigger test build
gh workflow run build.yml --field force_rebuild=true
```

5. **Validate Changes**:
- Check build logs for new features or changes
- Verify image builds successfully
- Test image functionality
- Update documentation for new features

#### Blue Build Update Checklist

- [ ] Check for new Blue Build releases monthly
- [ ] Review release notes and breaking changes
- [ ] Update workflow file with new version
- [ ] Test build with updated framework
- [ ] Update recipe.yml if new features are beneficial
- [ ] Update documentation for new capabilities
- [ ] Monitor first few builds after update

### 3. Maccel Integration Updates

Maccel updates require coordination with maccel-rpm-builder.

#### Update Process

1. **Monitor Maccel Releases**:
```bash
# Check latest maccel version
gh api repos/Gnarus-G/maccel/releases/latest --jq '.tag_name'
```

2. **Coordinate with maccel-rpm-builder**:
- Check if maccel-rpm-builder supports new version
- Trigger builds for current kernel versions if needed
- Verify package availability

3. **Test Integration**:
```bash
# Trigger build to test new maccel version
gh workflow run build.yml --field force_rebuild=true
```

4. **Validate Functionality**:
- Test maccel CLI in new image
- Verify kernel module loads correctly
- Check udev rules and permissions
- Test non-root user access

#### Maccel Update Checklist

- [ ] Monitor maccel upstream releases
- [ ] Coordinate with maccel-rpm-builder maintainer
- [ ] Verify package builds for current kernels
- [ ] Test maccel functionality in new image
- [ ] Update documentation if CLI changes
- [ ] Notify users of significant changes

### 4. Package Management Updates

Regular package updates ensure security and functionality.

#### RPM Package Updates

1. **Review Package Lists**:
```yaml
# In recipes/recipe.yml
modules:
  - type: dnf
    remove:
      packages:
        - sunshine  # Review if still needed to remove
    install:
      packages:
        - htop     # Check for newer alternatives
        - neovim   # Verify still desired
```

2. **Security Updates**:
- Monitor security advisories for installed packages
- Update packages with known vulnerabilities
- Test functionality after updates

3. **Package Optimization**:
- Remove unused packages to reduce image size
- Add packages requested by users
- Consolidate similar functionality

#### Flatpak Application Updates

1. **Review Application Lists**:
```yaml
# In recipes/recipe.yml
- type: default-flatpaks
  configurations:
    - scope: system
      remove:
        - org.mozilla.Thunderbird  # Review if still needed to remove
      install:
        - org.keepassxc.KeePassXC  # Check for updates
```

2. **Application Lifecycle**:
- Remove deprecated applications
- Add new applications based on user feedback
- Update application configurations

#### Package Update Checklist

- [ ] Review current package lists monthly
- [ ] Check for security vulnerabilities
- [ ] Test package functionality after changes
- [ ] Monitor image size impact
- [ ] Update documentation for package changes
- [ ] Gather user feedback on package selection

### 5. Security Updates

Security is critical for container images.

#### Security Monitoring

1. **Base Image Security**:
- Monitor Aurora security updates
- Check for CVE notifications
- Verify security patches are included

2. **Package Security**:
- Monitor installed packages for vulnerabilities
- Use tools like `trivy` for vulnerability scanning
- Update packages with security fixes promptly

3. **Build Security**:
- Review GitHub Actions security
- Update action versions for security fixes
- Monitor for supply chain attacks

#### Security Update Process

1. **Vulnerability Detection**:
```bash
# Scan image for vulnerabilities (example)
trivy image ghcr.io/USERNAME/myaurorabluebuild:latest
```

2. **Impact Assessment**:
- Determine severity of vulnerabilities
- Assess impact on users
- Prioritize fixes based on risk

3. **Remediation**:
- Update affected packages
- Rebuild image with fixes
- Test functionality after updates
- Notify users of security updates

#### Security Update Checklist

- [ ] Monitor security advisories weekly
- [ ] Scan images for vulnerabilities
- [ ] Prioritize critical security updates
- [ ] Test security fixes thoroughly
- [ ] Document security changes
- [ ] Notify users of security updates

## Automated Maintenance Tasks

### Dependabot Configuration

Create `.github/dependabot.yml` for automated dependency updates:

```yaml
version: 2
updates:
  # GitHub Actions updates
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "ci"
      include: "scope"

  # Docker base image updates (if using Dockerfile)
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "docker"
      include: "scope"
```

### Automated Testing

Implement automated testing for maintenance:

```yaml
# .github/workflows/maintenance-test.yml
name: Maintenance Testing
on:
  schedule:
    - cron: "0 2 * * 1"  # Weekly on Monday at 2 AM
  workflow_dispatch:

jobs:
  test-image:
    runs-on: ubuntu-latest
    steps:
      - name: Test latest image
        run: |
          # Pull and test latest image
          docker pull ghcr.io/USERNAME/myaurorabluebuild:latest
          
          # Basic functionality tests
          docker run --rm ghcr.io/USERNAME/myaurorabluebuild:latest rpm -q maccel
          docker run --rm ghcr.io/USERNAME/myaurorabluebuild:latest getent group maccel
```

### Performance Monitoring

Monitor build performance over time:

```bash
# Track build metrics
echo "Build started: $(date)" >> .github/metrics/build-times.log
# ... build process ...
echo "Build completed: $(date)" >> .github/metrics/build-times.log
```

## Troubleshooting Maintenance Issues

### Common Maintenance Problems

#### Build Failures After Updates

**Symptoms**: Builds fail after Aurora or framework updates

**Diagnosis**:
1. Check build logs for specific errors
2. Compare with previous successful builds
3. Identify what changed between builds

**Resolution**:
1. Revert to previous working version if critical
2. Fix compatibility issues
3. Test thoroughly before deploying

#### Package Conflicts

**Symptoms**: RPM installation failures, dependency conflicts

**Diagnosis**:
1. Check dnf logs in build output
2. Identify conflicting packages
3. Review package dependencies

**Resolution**:
1. Remove conflicting packages
2. Find alternative packages
3. Update package lists in recipe.yml

#### Performance Degradation

**Symptoms**: Slower builds, larger images, poor runtime performance

**Diagnosis**:
1. Compare build times over time
2. Analyze image size trends
3. Profile runtime performance

**Resolution**:
1. Optimize package selection
2. Improve build caching
3. Remove unnecessary components

### Emergency Procedures

#### Critical Security Vulnerability

1. **Immediate Response**:
   - Assess vulnerability impact
   - Determine if immediate action required
   - Prepare emergency update

2. **Emergency Update**:
   ```bash
   # Trigger immediate build
   gh workflow run build.yml --field force_rebuild=true
   ```

3. **User Notification**:
   - Create security advisory
   - Notify users via GitHub releases
   - Provide update instructions

#### Build System Failure

1. **Diagnosis**:
   - Check GitHub Actions status
   - Verify repository permissions
   - Test individual components

2. **Workaround**:
   - Use manual build process if needed
   - Implement temporary fixes
   - Communicate status to users

3. **Resolution**:
   - Fix underlying issues
   - Test full workflow
   - Resume normal operations

## Documentation Maintenance

### Documentation Update Process

1. **Regular Review**:
   - Check documentation accuracy monthly
   - Update for new features and changes
   - Fix broken links and outdated information

2. **User Feedback Integration**:
   - Review user questions and issues
   - Update documentation to address common problems
   - Add FAQ sections for frequent questions

3. **Version Control**:
   - Keep documentation in sync with code changes
   - Tag documentation versions with releases
   - Maintain changelog for documentation updates

### Documentation Checklist

- [ ] Review all documentation monthly
- [ ] Update installation instructions
- [ ] Verify all links and references
- [ ] Update screenshots and examples
- [ ] Check for outdated information
- [ ] Add new features and changes
- [ ] Review user feedback and questions

## Maintenance Tools and Scripts

### Maintenance Scripts

Create utility scripts for common maintenance tasks:

```bash
#!/bin/bash
# scripts/maintenance-check.sh

echo "=== MyAuroraBluebuild Maintenance Check ==="

# Check Aurora base image
echo "Checking Aurora base image..."
CURRENT_DIGEST=$(skopeo inspect docker://ghcr.io/ublue-os/aurora-nvidia:latest | jq -r '.Digest')
echo "Current Aurora digest: $CURRENT_DIGEST"

# Check maccel version
echo "Checking maccel version..."
MACCEL_VERSION=$(gh api repos/Gnarus-G/maccel/releases/latest --jq '.tag_name')
echo "Latest maccel version: $MACCEL_VERSION"

# Check build status
echo "Checking recent builds..."
gh run list --workflow=build.yml --limit=5 --json status,conclusion,createdAt

echo "=== Maintenance check complete ==="
```

### Monitoring Scripts

```bash
#!/bin/bash
# scripts/health-check.sh

echo "=== Health Check ==="

# Test image availability
echo "Testing image availability..."
if docker pull ghcr.io/USERNAME/myaurorabluebuild:latest; then
    echo "✅ Image available"
else
    echo "❌ Image not available"
fi

# Test maccel functionality
echo "Testing maccel functionality..."
if docker run --rm ghcr.io/USERNAME/myaurorabluebuild:latest rpm -q maccel; then
    echo "✅ Maccel package installed"
else
    echo "❌ Maccel package missing"
fi

echo "=== Health check complete ==="
```

## Best Practices

### Maintenance Best Practices

1. **Proactive Monitoring**: Monitor for issues before they affect users
2. **Regular Updates**: Keep all components current with security updates
3. **Testing**: Test all changes thoroughly before deployment
4. **Documentation**: Keep documentation current and accurate
5. **Communication**: Communicate changes and issues to users promptly

### Change Management

1. **Version Control**: Use git tags for releases and major changes
2. **Testing**: Test changes in isolated environments first
3. **Rollback Plan**: Always have a rollback plan for changes
4. **User Impact**: Consider user impact before making changes
5. **Communication**: Notify users of significant changes

### Quality Assurance

1. **Automated Testing**: Implement automated tests for critical functionality
2. **Manual Testing**: Perform manual testing for user-facing changes
3. **Performance Testing**: Monitor performance impact of changes
4. **Security Testing**: Verify security of all changes
5. **User Acceptance**: Gather user feedback on changes

## Maintenance Metrics

Track these metrics to measure maintenance effectiveness:

### Build Metrics
- Build success rate over time
- Build duration trends
- Image size trends
- Update frequency

### Issue Metrics
- Time to resolve issues
- Number of open issues
- Issue recurrence rate
- User satisfaction

### Security Metrics
- Time to patch vulnerabilities
- Number of security updates
- Security scan results
- Compliance status

### Performance Metrics
- Build performance trends
- Runtime performance
- Resource usage
- User experience metrics

## Conclusion

Regular maintenance is essential for keeping MyAuroraBluebuild secure, functional, and up-to-date. By following these procedures and maintaining a proactive approach to updates and monitoring, the project can continue to provide value to users while minimizing disruptions and security risks.

The key to successful maintenance is:
- **Automation**: Automate routine tasks where possible
- **Monitoring**: Continuously monitor for issues and updates
- **Testing**: Thoroughly test all changes
- **Documentation**: Keep procedures and documentation current
- **Communication**: Keep users informed of changes and issues

Regular review and improvement of these maintenance procedures will ensure they remain effective as the project evolves.