# Build Monitoring and Alerting

This document describes the monitoring and alerting system for MyAuroraBluebuild, which provides automated notifications for build failures, Aurora base image updates, and comprehensive build status tracking.

## Overview

The monitoring system consists of several automated workflows and tools that help maintain the health and reliability of the MyAuroraBluebuild image:

- **Build Status Monitoring**: Automatic notifications for build failures and recoveries
- **Aurora Base Image Monitoring**: Detection of upstream Aurora image updates
- **Build Dashboard**: Real-time status and history tracking
- **Package Status Monitoring**: Verification of maccel package availability
- **Automated Issue Management**: Creation and cleanup of monitoring issues

## Monitoring Components

### 1. Build Status Notifications

**Workflow**: `.github/workflows/monitoring.yml` (build-status-notification job)

**Triggers**:
- Automatically runs after each build workflow completion
- Monitors both successful and failed builds

**Actions**:
- **On Build Failure**: Creates a GitHub issue with detailed failure information
- **On Build Recovery**: Comments on existing failure issues to indicate recovery
- **Includes**: Workflow logs, commit information, troubleshooting steps

**Issue Labels**: `build-failure`, `monitoring`, `automated`

### 2. Aurora Base Image Update Monitor

**Workflow**: `.github/workflows/monitoring.yml` (aurora-update-monitor job)

**Schedule**: Every 6 hours (`0 */6 * * *`)

**Functionality**:
- Checks Aurora base image for digest changes
- Detects new kernel versions
- Caches previous state for comparison
- Automatically triggers builds when updates are detected

**Actions on Update**:
- Creates GitHub issue with update details
- Automatically triggers a new build with `force_rebuild=true`
- Provides manual build instructions

**Issue Labels**: `aurora-update`, `monitoring`, `automated`

### 3. Build Dashboard

**Location**: `.github/dashboard/index.html`

**Features**:
- Real-time build status overview
- Current Aurora kernel version
- Maccel integration status
- Success rate metrics (last 10 builds)
- Recent build history table
- Automatic updates every 6 hours

**Access**: The dashboard is automatically generated and can be served via GitHub Pages or viewed locally.

### 4. Package Status Monitor

**Workflow**: `.github/workflows/monitoring.yml` (package-status-monitor job)

**Trigger**: Manual workflow dispatch

**Functionality**:
- Verifies maccel package availability for current kernel version
- Checks maccel-rpm-builder release status
- Identifies potential build issues before they occur

### 5. Automated Issue Cleanup

**Workflow**: `.github/workflows/monitoring.yml` (cleanup-old-issues job)

**Schedule**: Daily with Aurora update checks

**Actions**:
- Closes build failure issues older than 7 days
- Closes Aurora update notifications older than 3 days
- Prevents issue accumulation and maintains clean issue tracker

## Notification Types

### Build Failure Notifications

```
🚨 Build Failed - 2024-10-30 14:30 UTC

Build Details:
- Status: ❌ Failed
- Workflow Run: [12345](link-to-workflow)
- Branch: main
- Commit: abc123def
- Commit Message: Update recipe configuration
- Timestamp: 2024-10-30 14:30:15 UTC

Possible Causes:
- Aurora base image changes causing compatibility issues
- Maccel RPM build failures
- Package dependency conflicts
- Network connectivity issues during build
- GitHub Actions infrastructure problems

Troubleshooting Steps:
1. Check the workflow logs for specific error messages
2. Verify Aurora base image availability and kernel version compatibility
3. Check maccel-rpm-builder status and recent builds
4. Review recent changes to recipe.yml or build scripts
5. Consider running a manual build with force_rebuild=true
```

### Aurora Update Notifications

```
🔄 Aurora Base Image Updated - 2024-10-30

Update Details:
- Base Image: ghcr.io/ublue-os/aurora-nvidia:latest
- New Kernel Version: 6.11.5-300.fc41.x86_64
- New Digest: sha256:abc123...
- Previous Digest: sha256:def456...
- Detection Time: 2024-10-30 12:00:00 UTC

Recommended Actions:
1. Trigger a new build to incorporate the updated Aurora base image
2. Verify maccel compatibility with the new kernel version
3. Test the new image before promoting to users
4. Update documentation if there are significant changes

Automatic Actions:
- This notification was automatically generated
- A new build may be triggered automatically by the daily schedule
- Monitor the build workflow for any compatibility issues
```

## Manual Monitoring Operations

### Trigger Manual Monitoring Checks

You can manually run monitoring checks using GitHub Actions:

1. Go to **Actions** → **Build Monitoring and Alerting**
2. Click **Run workflow**
3. Select check type:
   - `all`: Run all monitoring checks
   - `aurora_updates`: Check only Aurora base image updates
   - `build_status`: Check only build status
   - `package_status`: Check only maccel package availability

### Force Build After Aurora Update

If an Aurora update is detected but automatic build doesn't trigger:

1. Go to **Actions** → **bluebuild**
2. Click **Run workflow**
3. Enable **Force rebuild even if no changes detected**
4. Click **Run workflow**

### View Build Dashboard

The build dashboard provides a comprehensive overview of build status and history:

1. Navigate to `.github/dashboard/index.html` in the repository
2. Open the file in a web browser
3. The dashboard shows:
   - Current build status
   - Aurora kernel version
   - Maccel integration status
   - Success rate metrics
   - Recent build history

## Troubleshooting Common Issues

### Build Failures

**Symptoms**: Build failure notifications, red status in dashboard

**Common Causes**:
1. **Aurora Base Image Issues**: New kernel version incompatible with maccel
2. **Maccel RPM Build Failures**: maccel-rpm-builder workflow issues
3. **Package Conflicts**: Dependency resolution problems
4. **Network Issues**: Download failures during build

**Resolution Steps**:
1. Check workflow logs for specific error messages
2. Verify Aurora base image accessibility: `skopeo inspect docker://ghcr.io/ublue-os/aurora-nvidia:latest`
3. Check maccel-rpm-builder status and recent releases
4. Review recent changes to recipe.yml or build scripts
5. Try manual build with force rebuild option

### Aurora Update Detection Issues

**Symptoms**: No Aurora update notifications despite known updates

**Possible Causes**:
1. Monitoring workflow not running on schedule
2. Cache issues preventing update detection
3. Network connectivity problems
4. GitHub API rate limiting

**Resolution Steps**:
1. Check monitoring workflow execution history
2. Manually trigger aurora update check
3. Clear cache by running workflow with `workflow_dispatch`
4. Verify GitHub token permissions

### Dashboard Not Updating

**Symptoms**: Stale information in build dashboard

**Possible Causes**:
1. Dashboard update workflow failures
2. Git commit permissions issues
3. File system problems

**Resolution Steps**:
1. Check monitoring workflow logs
2. Manually trigger dashboard update
3. Verify repository write permissions
4. Check for file conflicts in `.github/dashboard/`

### Package Availability Issues

**Symptoms**: Builds fail due to missing maccel packages

**Possible Causes**:
1. maccel-rpm-builder workflow failures
2. Kernel version detection problems
3. Repository dispatch issues
4. Package naming inconsistencies

**Resolution Steps**:
1. Check maccel-rpm-builder repository status
2. Verify kernel version detection in build logs
3. Test repository dispatch manually
4. Coordinate with maccel-rpm-builder maintainer

## Configuration

### Required Secrets

The monitoring system uses the following GitHub secrets:

- `GITHUB_TOKEN`: Automatically provided, used for API access
- `DISPATCH_TOKEN`: Optional, for enhanced repository dispatch permissions

### Workflow Permissions

The monitoring workflow requires these permissions:

```yaml
permissions:
  contents: read      # Read repository contents
  issues: write       # Create and manage issues
  actions: read       # Read workflow run information
  packages: read      # Read container registry information
```

### Customization Options

You can customize the monitoring behavior by modifying `.github/workflows/monitoring.yml`:

**Notification Frequency**:
```yaml
schedule:
  - cron: "0 */6 * * *"  # Change to adjust Aurora check frequency
```

**Issue Auto-Assignment**:
```yaml
--assignee "${{ github.repository_owner }}"  # Change to assign to different user
```

**Cleanup Timing**:
```yaml
# Adjust age thresholds for issue cleanup
select((.createdAt | fromdateiso8601) < (now - 604800))  # 7 days for build failures
select((.createdAt | fromdateiso8601) < (now - 259200))  # 3 days for Aurora updates
```

## Integration with External Services

### Slack/Discord Notifications

To integrate with external notification services, you can extend the monitoring workflow:

```yaml
- name: Send Slack notification
  if: github.event.workflow_run.conclusion == 'failure'
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Email Notifications

GitHub automatically sends email notifications for:
- Issues assigned to you
- Repository watch notifications
- Workflow failure notifications (if enabled in settings)

### Custom Webhooks

You can add custom webhook notifications by extending the monitoring workflow with HTTP requests to your preferred services.

## Metrics and Analytics

The monitoring system tracks several key metrics:

### Build Metrics
- **Success Rate**: Percentage of successful builds in the last 10 runs
- **Build Frequency**: How often builds are triggered
- **Build Duration**: Time taken for each build (available in workflow logs)
- **Failure Patterns**: Common causes of build failures

### Aurora Update Metrics
- **Update Frequency**: How often Aurora base image updates
- **Kernel Version Changes**: Tracking kernel version progression
- **Update Response Time**: Time between Aurora update and our build

### Package Metrics
- **Package Availability**: Success rate of maccel package builds
- **Package Build Time**: Time for maccel-rpm-builder to complete
- **Version Compatibility**: Success rate across different kernel versions

## Best Practices

### Monitoring Hygiene
1. **Regular Review**: Check monitoring issues weekly
2. **Issue Cleanup**: Close resolved issues promptly
3. **Dashboard Monitoring**: Review dashboard metrics regularly
4. **Log Analysis**: Investigate patterns in build failures

### Proactive Monitoring
1. **Aurora Tracking**: Monitor Aurora repository for upcoming changes
2. **Maccel Updates**: Track maccel upstream for new releases
3. **Dependency Monitoring**: Watch for Fedora package updates
4. **Security Updates**: Monitor for security-related base image updates

### Response Procedures
1. **Build Failures**: Investigate within 24 hours
2. **Aurora Updates**: Test compatibility within 48 hours
3. **Security Issues**: Address immediately
4. **User Reports**: Respond to user issues within 72 hours

## Maintenance

### Regular Tasks

**Weekly**:
- Review monitoring issues and close resolved ones
- Check dashboard metrics for trends
- Verify monitoring workflow execution

**Monthly**:
- Review and update monitoring thresholds
- Analyze build failure patterns
- Update documentation as needed

**Quarterly**:
- Review monitoring effectiveness
- Update notification preferences
- Evaluate new monitoring tools

### Monitoring the Monitoring

To ensure the monitoring system itself is working:

1. **Workflow Execution**: Check that monitoring workflows run on schedule
2. **Issue Creation**: Verify that issues are created for actual failures
3. **Dashboard Updates**: Confirm dashboard reflects current status
4. **Notification Delivery**: Test that notifications reach intended recipients

### Troubleshooting Monitoring Issues

If the monitoring system itself fails:

1. Check GitHub Actions status page
2. Verify repository permissions and secrets
3. Review workflow syntax and dependencies
4. Test individual monitoring components
5. Check for GitHub API rate limiting

## Future Enhancements

Potential improvements to the monitoring system:

### Enhanced Metrics
- Build performance trending
- Resource usage monitoring
- User adoption metrics
- Security vulnerability tracking

### Advanced Alerting
- Predictive failure detection
- Intelligent alert routing
- Integration with incident management systems
- Custom alert thresholds

### Improved Dashboard
- Interactive charts and graphs
- Historical trend analysis
- Comparative metrics with other projects
- Mobile-responsive design

### Automation
- Automatic issue resolution for known problems
- Self-healing build processes
- Intelligent retry mechanisms
- Automated rollback procedures