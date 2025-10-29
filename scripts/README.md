# MyAuroraBluebuild Maintenance Scripts

This directory contains utility scripts for maintaining and monitoring the MyAuroraBluebuild project. These scripts help automate routine maintenance tasks, perform health checks, and manage updates.

## Available Scripts

### 🔍 `maintenance-check.sh`

**Purpose**: Comprehensive maintenance check that reviews all aspects of the project health.

**Usage**:
```bash
./scripts/maintenance-check.sh
```

**What it checks**:
- Aurora base image accessibility and kernel version
- Maccel integration status and package availability
- Recent build success rates
- Image availability and basic functionality
- Blue Build framework version status
- Open issues and their status

**When to use**:
- Weekly maintenance reviews
- Before making major changes
- When investigating build issues
- As part of troubleshooting process

**Requirements**: `gh`, `skopeo`, `jq`, `docker`

---

### 🏥 `health-check.sh`

**Purpose**: Quick health check focused on image functionality and performance.

**Usage**:
```bash
./scripts/health-check.sh
```

**What it checks**:
- Image availability and pull success
- Container startup and basic functionality
- Maccel package installation and configuration
- System integration (RPM, systemd, users)
- Performance metrics (startup time, image size)
- Security basics (file permissions, root account)

**Exit codes**:
- `0`: Health check passed (≥80% score)
- `1`: Health issues found (50-79% score)
- `2`: Critical health issues (<50% score)

**When to use**:
- Daily automated monitoring
- Before releasing new versions
- After making configuration changes
- When users report issues

**Requirements**: `docker`

---

### 🔄 `update-framework.sh`

**Purpose**: Update Blue Build framework and other dependencies safely.

**Usage**:
```bash
# Update everything
./scripts/update-framework.sh

# Update specific components
./scripts/update-framework.sh bluebuild    # Blue Build framework only
./scripts/update-framework.sh actions     # GitHub Actions only
./scripts/update-framework.sh deps        # Other dependencies only
```

**What it updates**:
- Blue Build framework version
- GitHub Actions versions (checkout, cache, upload-artifact, etc.)
- Dependency configuration review
- Recipe.yml recommendations

**Safety features**:
- Creates automatic backups
- Validates YAML syntax
- Shows changes before committing
- Provides rollback instructions
- Interactive confirmation prompts

**When to use**:
- Monthly dependency updates
- When security updates are available
- Before major feature development
- When Blue Build releases new versions

**Requirements**: `gh`, `jq`, `git`, `python3`

---

### 🧪 `test-cosign-verification.sh`

**Purpose**: Test and validate cosign image signature verification.

**Usage**:
```bash
./scripts/test-cosign-verification.sh [IMAGE_TAG]
```

**What it tests**:
- Cosign installation and setup
- Keyless signature verification
- Image signature validation
- Verification command generation

**When to use**:
- After enabling image signing
- When troubleshooting signature issues
- Before documenting verification steps
- As part of security audits

**Requirements**: `cosign`, `docker`

## Script Dependencies

### Required Tools

Most scripts require these common tools:

```bash
# GitHub CLI (for API access)
gh --version

# Skopeo (for container image inspection)
skopeo --version

# jq (for JSON processing)
jq --version

# Docker (for container operations)
docker --version

# Git (for version control)
git --version
```

### Installation Commands

**Ubuntu/Debian**:
```bash
# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Other tools
sudo apt install skopeo jq docker.io git python3
```

**Fedora**:
```bash
sudo dnf install gh skopeo jq docker git python3
```

**macOS**:
```bash
brew install gh skopeo jq docker git python3
```

## Usage Patterns

### Daily Monitoring

```bash
# Quick health check (automated)
./scripts/health-check.sh

# If health check fails, run detailed maintenance check
if [ $? -ne 0 ]; then
    ./scripts/maintenance-check.sh
fi
```

### Weekly Maintenance

```bash
# Comprehensive maintenance review
./scripts/maintenance-check.sh

# Check for framework updates
./scripts/update-framework.sh --dry-run  # (if implemented)
```

### Monthly Updates

```bash
# Update all dependencies
./scripts/update-framework.sh all

# Run full health check after updates
./scripts/health-check.sh

# Test image signing
./scripts/test-cosign-verification.sh
```

### Troubleshooting Workflow

```bash
# 1. Quick health assessment
./scripts/health-check.sh

# 2. Detailed investigation
./scripts/maintenance-check.sh

# 3. Check recent changes
git log --oneline -10

# 4. Test specific functionality
./scripts/test-cosign-verification.sh

# 5. Consider framework updates if issues persist
./scripts/update-framework.sh
```

## Integration with GitHub Actions

These scripts are designed to work both locally and in GitHub Actions workflows:

### Local Development

```bash
# Set up environment
export GITHUB_REPOSITORY_OWNER="your-username"
export GITHUB_TOKEN="your-token"

# Run scripts
./scripts/maintenance-check.sh
```

### GitHub Actions

```yaml
- name: Run Health Check
  run: ./scripts/health-check.sh

- name: Run Maintenance Check
  run: ./scripts/maintenance-check.sh
  env:
    GITHUB_TOKEN: ${{ github.token }}
```

## Script Output

### Success Indicators
- ✅ Green checkmarks for passed checks
- ℹ️ Blue info messages for status updates
- Detailed progress information

### Warning Indicators
- ⚠️ Yellow warnings for issues needing attention
- Recommendations for resolution
- Non-critical problems

### Error Indicators
- ❌ Red errors for critical issues
- Clear failure descriptions
- Troubleshooting guidance

### Example Output

```
=== MyAuroraBluebuild Health Check ===
Image: ghcr.io/username/myaurorabluebuild
Timestamp: 2024-10-30 14:30:00 UTC

=== Image Availability Check ===
ℹ️ INFO: Running: Image Pull Test
✅ PASS: Image is available and pullable

=== Basic Functionality Checks ===
ℹ️ INFO: Running: Container Start Test
✅ PASS: Container starts and runs successfully
ℹ️ INFO: Running: Maccel Package Check
✅ PASS: Maccel CLI package is installed

=== Health Check Summary ===
ℹ️ INFO: Health Score: 12/12 (100%)
✅ PASS: System health is EXCELLENT
```

## Customization

### Environment Variables

Scripts respect these environment variables:

- `GITHUB_REPOSITORY_OWNER`: Repository owner (default: `abirkel`)
- `GITHUB_TOKEN`: GitHub API token
- `IMAGE_NAME`: Custom image name override
- `TIMEOUT`: Operation timeout in seconds (default: `30`)

### Configuration Files

Scripts read configuration from:

- `recipes/recipe.yml`: Base image and recipe configuration
- `.github/workflows/build.yml`: Build workflow configuration
- `.github/dependabot.yml`: Dependency update configuration

### Extending Scripts

To add new checks or functionality:

1. Follow the existing pattern of status functions
2. Use consistent output formatting
3. Include error handling and timeouts
4. Add documentation to this README
5. Test both success and failure scenarios

## Troubleshooting

### Common Issues

**Permission Denied**:
```bash
chmod +x scripts/*.sh
```

**Command Not Found**:
```bash
# Install missing dependencies
sudo apt install gh skopeo jq docker.io
```

**GitHub API Rate Limiting**:
```bash
# Authenticate with GitHub CLI
gh auth login
```

**Docker Permission Issues**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Script Debugging

Enable debug mode:
```bash
# Add to beginning of script
set -x  # Enable debug output
```

Check script syntax:
```bash
bash -n scripts/script-name.sh
```

### Getting Help

1. Check script output for specific error messages
2. Review the troubleshooting section in docs/MAINTENANCE.md
3. Check GitHub Issues for similar problems
4. Run scripts with verbose output when available

## Contributing

When adding new maintenance scripts:

1. Follow the established naming convention
2. Include comprehensive error handling
3. Add usage documentation to this README
4. Test on multiple environments
5. Include both success and failure test cases
6. Follow the existing output formatting patterns

## Security Considerations

- Scripts may require GitHub tokens for API access
- Docker operations may require elevated privileges
- Always review script contents before execution
- Use environment variables for sensitive configuration
- Avoid hardcoding credentials in scripts

## Maintenance

These scripts themselves require maintenance:

- Update dependency versions as tools evolve
- Review and update API calls for GitHub changes
- Test scripts with new Blue Build framework versions
- Update documentation for new features
- Monitor for deprecated commands or options