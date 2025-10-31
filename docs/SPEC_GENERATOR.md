# Maccel Spec File Generator Documentation

This document describes the maccel spec file generator system, which creates RPM spec files on-demand for building maccel packages.

## Overview

The spec file generator is a self-contained system that:
- Generates RPM spec files from templates
- Fetches metadata from the upstream maccel repository
- Caches generated specs for reuse
- Validates specs with rpmlint
- Supports version pinning and automatic latest version detection

## Architecture

### Components

1. **Generator Script**: `files/scripts/generate-maccel-specs.sh`
   - Main script that orchestrates spec generation
   - Handles version resolution, caching, and validation

2. **Spec Templates**: `files/templates/`
   - `akmod-maccel.spec.template` - AKMOD kernel module package
   - `maccel.spec.template` - CLI tools package

3. **Spec Cache**: `specs/`
   - Organized by maccel version
   - Contains generated specs and metadata

### Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Determine maccel version (env var or latest)                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Check cache: specs/maccel-{version}/*.spec                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼
            ┌───────────────┐   ┌──────────────────┐
            │ Cache Hit     │   │ Cache Miss       │
            │ Use existing  │   │ Generate new     │
            └───────────────┘   └──────────────────┘
                    │                   │
                    │                   ▼
                    │       ┌──────────────────────────┐
                    │       │ Fetch metadata from      │
                    │       │ GitHub (license,         │
                    │       │ changelog, source URL)   │
                    │       └──────────────────────────┘
                    │                   │
                    │                   ▼
                    │       ┌──────────────────────────┐
                    │       │ Generate specs from      │
                    │       │ templates                │
                    │       └──────────────────────────┘
                    │                   │
                    │                   ▼
                    │       ┌──────────────────────────┐
                    │       │ Validate with rpmlint    │
                    │       └──────────────────────────┘
                    │                   │
                    │                   ▼
                    │       ┌──────────────────────────┐
                    │       │ Cache in specs/          │
                    │       │ maccel-{version}/        │
                    │       └──────────────────────────┘
                    │                   │
                    └───────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Export spec file paths to environment variables             │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Usage

The generator is typically called automatically by the Blue Build workflow:

```yaml
# In recipes/recipe.yml
modules:
  - type: script
    scripts:
      - generate-maccel-specs.sh
```

### Manual Usage

You can run the generator manually for testing:

```bash
# Generate specs for latest version
bash files/scripts/generate-maccel-specs.sh

# Generate specs for specific version
MACCEL_VERSION=0.4.1 bash files/scripts/generate-maccel-specs.sh

# Force regeneration even if cached
FORCE_REGENERATE=true bash files/scripts/generate-maccel-specs.sh
```

### Environment Variables

#### Input Variables

- **MACCEL_VERSION** (optional)
  - Specifies which maccel version to use
  - Default: `latest` (auto-detects newest release)
  - Example: `0.4.1`, `0.4.2`, `latest`

- **FORCE_REGENERATE** (optional)
  - Forces regeneration even if specs are cached
  - Default: `false`
  - Set to `true` to force regeneration

#### Output Variables

The generator exports these environment variables:

- **AKMOD_SPEC_PATH**
  - Path to the generated akmod-maccel.spec file
  - Example: `/workspace/specs/maccel-0.4.1/akmod-maccel.spec`

- **MACCEL_SPEC_PATH**
  - Path to the generated maccel.spec file
  - Example: `/workspace/specs/maccel-0.4.1/maccel.spec`

## Spec Templates

### Template Structure

Templates use a simple variable substitution system:

```spec
Name:           akmod-maccel
Version:        {{MACCEL_VERSION}}
License:        {{LICENSE}}
Source0:        {{SOURCE_URL}}

%changelog
{{CHANGELOG}}
```

### Template Variables

- **{{MACCEL_VERSION}}**
  - Replaced with the maccel version number
  - Example: `0.4.1`

- **{{LICENSE}}**
  - Replaced with the license identifier from upstream
  - Fetched from GitHub repository metadata
  - Example: `MIT`

- **{{SOURCE_URL}}**
  - Replaced with the source tarball download URL
  - Example: `https://github.com/Gnarus-G/maccel/archive/refs/tags/v0.4.1.tar.gz`

- **{{CHANGELOG}}**
  - Replaced with formatted changelog entries
  - Fetched from GitHub releases
  - Formatted in RPM changelog format

### AKMOD Template

The AKMOD template (`akmod-maccel.spec.template`) creates a package that:
- Uses the AKMOD framework for automatic kernel module rebuilding
- Installs source files for akmods to build from
- Configures kmodtool for kernel module packaging
- Declares dependencies on akmods and build tools

Key sections:
```spec
BuildRequires:  kmodtool
BuildRequires:  akmods
BuildRequires:  gcc
BuildRequires:  make

Requires:       akmods

# Kmodtool does the rest
%{expand:%(kmodtool --target %{_target_cpu} --repo rpmfusion --kmodname maccel ...)}
```

### CLI Template

The CLI template (`maccel.spec.template`) creates a package that:
- Builds the Rust-based CLI tools
- Installs udev rules for device access
- Creates the maccel group for non-root access
- Depends on the akmod-maccel package

Key sections:
```spec
BuildRequires:  rust
BuildRequires:  cargo

Requires:       akmod-maccel = %{version}-%{release}

%post
groupadd -r maccel 2>/dev/null || :
udevadm control --reload-rules || :
```

## Spec Cache

### Cache Structure

```
specs/
├── maccel-0.4.1/
│   ├── akmod-maccel.spec
│   ├── maccel.spec
│   └── metadata.json
└── maccel-0.4.2/
    ├── akmod-maccel.spec
    ├── maccel.spec
    └── metadata.json
```

### Metadata Format

The `metadata.json` file contains information about the generated specs:

```json
{
  "maccel_version": "0.4.1",
  "generated_at": "2025-10-31T12:34:56Z",
  "source_url": "https://github.com/Gnarus-G/maccel/archive/refs/tags/v0.4.1.tar.gz",
  "license": "MIT",
  "generator_version": "1.0.0",
  "upstream_commit": "abc123def456",
  "changelog_entries": 5
}
```

### Cache Management

**View cached versions**:
```bash
ls -la specs/
```

**View metadata**:
```bash
cat specs/maccel-0.4.1/metadata.json
```

**Remove old versions**:
```bash
rm -rf specs/maccel-0.4.0
```

**Clear all cache**:
```bash
rm -rf specs/maccel-*
```

## Customization

### Modifying Templates

1. **Edit the template file**:
```bash
nano files/templates/akmod-maccel.spec.template
```

2. **Test generation**:
```bash
FORCE_REGENERATE=true bash files/scripts/generate-maccel-specs.sh
```

3. **Validate generated specs**:
```bash
rpmlint specs/maccel-*/akmod-maccel.spec
rpmlint specs/maccel-*/maccel.spec
```

4. **Test build**:
```bash
gh workflow run build.yml
```

5. **Commit changes**:
```bash
git add files/templates/
git add specs/
git commit -m "Update spec templates"
```

### Common Customizations

#### Adding Build Dependencies

```spec
# In template file
BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  your-new-dependency
```

#### Modifying Installation Paths

```spec
# In %install section
install -D -m 0755 target/release/maccel %{buildroot}/your/custom/path/maccel
```

#### Adding Post-Install Scripts

```spec
%post
# Your custom post-install commands
groupadd -r maccel 2>/dev/null || :
# Add more commands here
```

#### Customizing Package Metadata

```spec
Summary:        Your custom summary
URL:            https://your-custom-url.com
```

### Adding New Template Variables

To add a new template variable:

1. **Update the generator script**:
```bash
# In generate-maccel-specs.sh
NEW_VARIABLE="your_value"

# In the sed command
sed -e "s|{{NEW_VARIABLE}}|$NEW_VARIABLE|g" \
    template.spec > output.spec
```

2. **Use in template**:
```spec
CustomField:    {{NEW_VARIABLE}}
```

## Troubleshooting

### Common Issues

#### Spec Generation Fails

**Problem**: Generator fails with "maccel version not found"

**Solution**:
```bash
# Check if version exists
gh api repos/Gnarus-G/maccel/releases | jq -r '.[].tag_name'

# Use a valid version
MACCEL_VERSION=0.4.1 bash files/scripts/generate-maccel-specs.sh
```

#### Template Not Found

**Problem**: Generator fails with "template file not found"

**Solution**:
```bash
# Verify templates exist
ls -la files/templates/

# Ensure you're running from repository root
cd /path/to/MyAuroraBluebuild
bash files/scripts/generate-maccel-specs.sh
```

#### rpmlint Validation Fails

**Problem**: Generated specs fail rpmlint validation

**Solution**:
```bash
# View rpmlint errors
rpmlint specs/maccel-*/akmod-maccel.spec

# Fix template based on errors
nano files/templates/akmod-maccel.spec.template

# Regenerate
FORCE_REGENERATE=true bash files/scripts/generate-maccel-specs.sh
```

#### GitHub API Rate Limit

**Problem**: Generator fails with "API rate limit exceeded"

**Solution**:
```bash
# Check rate limit status
gh api rate_limit

# Wait for rate limit reset or authenticate
gh auth login

# Retry generation
bash files/scripts/generate-maccel-specs.sh
```

#### Cache Corruption

**Problem**: Cached specs are invalid or corrupted

**Solution**:
```bash
# Remove corrupted cache
rm -rf specs/maccel-0.4.1

# Regenerate
bash files/scripts/generate-maccel-specs.sh
```

### Debugging

#### Enable Verbose Output

The generator script uses `set -x` for debugging:

```bash
# Run with verbose output
bash -x files/scripts/generate-maccel-specs.sh
```

#### Check Generated Specs

```bash
# View generated spec files
cat specs/maccel-0.4.1/akmod-maccel.spec
cat specs/maccel-0.4.1/maccel.spec

# Check metadata
cat specs/maccel-0.4.1/metadata.json
```

#### Validate Spec Syntax

```bash
# Check spec file syntax
rpmspec -P specs/maccel-0.4.1/akmod-maccel.spec

# Run rpmlint
rpmlint specs/maccel-0.4.1/akmod-maccel.spec
```

#### Test Spec Building

```bash
# Test building RPM locally (requires rpmbuild)
rpmbuild -ba specs/maccel-0.4.1/akmod-maccel.spec
```

## Integration with Blue Build

### Recipe Configuration

```yaml
# In recipes/recipe.yml
modules:
  # Step 1: Generate spec files
  - type: script
    scripts:
      - generate-maccel-specs.sh
  
  # Step 2: Build RPMs from specs
  - type: rpm-build
    specs:
      - ${AKMOD_SPEC_PATH}
      - ${MACCEL_SPEC_PATH}
```

### Workflow Configuration

```yaml
# In .github/workflows/build.yml
env:
  MACCEL_VERSION: "latest"  # or pin to specific version
```

### Build Process

1. Blue Build calls the generator script
2. Generator determines maccel version
3. Generator checks cache or generates new specs
4. Generator exports spec paths to environment
5. Blue Build rpm-build module uses exported paths
6. RPMs are built and installed into the image

## Best Practices

### Version Management

- **Use latest for rolling releases**: Automatically get new versions
- **Pin for stability**: Use specific versions for production
- **Test before pinning**: Verify new versions work before pinning

### Cache Management

- **Commit cached specs**: Include in version control for reproducibility
- **Clean old versions**: Remove unused cached versions periodically
- **Regenerate after template changes**: Always regenerate when templates are updated

### Template Maintenance

- **Keep templates simple**: Avoid complex logic in templates
- **Document customizations**: Comment custom changes in templates
- **Test thoroughly**: Validate all template changes with rpmlint and builds
- **Follow RPM standards**: Adhere to Fedora packaging guidelines

### Error Handling

- **Check exit codes**: Always check generator exit code
- **Log output**: Capture generator output for debugging
- **Validate specs**: Run rpmlint before building
- **Test builds**: Test RPM builds before deploying

## Advanced Topics

### Custom Metadata Sources

You can modify the generator to fetch metadata from alternative sources:

```bash
# In generate-maccel-specs.sh
# Instead of GitHub API, use custom source
CUSTOM_LICENSE=$(curl -s https://your-source.com/license)
```

### Multi-Version Support

Generate specs for multiple versions:

```bash
# Generate specs for multiple versions
for version in 0.4.1 0.4.2 0.4.3; do
  MACCEL_VERSION=$version bash files/scripts/generate-maccel-specs.sh
done
```

### Automated Testing

Test spec generation in CI:

```yaml
# In .github/workflows/test.yml
- name: Test spec generation
  run: |
    bash files/scripts/generate-maccel-specs.sh
    rpmlint specs/maccel-*/akmod-maccel.spec
    rpmlint specs/maccel-*/maccel.spec
```

## Reference

### Generator Script Functions

- `get_maccel_version()` - Resolve version (pinned or latest)
- `check_spec_cache()` - Check if specs exist for version
- `fetch_maccel_metadata()` - Get license, changelog from GitHub
- `generate_akmod_spec()` - Generate AKMOD spec from template
- `generate_maccel_spec()` - Generate CLI spec from template
- `validate_spec_files()` - Run rpmlint on generated specs
- `cache_spec_files()` - Store specs in version directory

### Exit Codes

- `0` - Success
- `1` - General error
- `2` - Invalid version
- `3` - Template not found
- `4` - Validation failed
- `5` - Network error

### File Locations

- Generator script: `files/scripts/generate-maccel-specs.sh`
- Templates: `files/templates/*.spec.template`
- Cache: `specs/maccel-*/`
- Metadata: `specs/maccel-*/metadata.json`

## See Also

- [MAINTENANCE.md](MAINTENANCE.md) - Maintenance procedures including spec cache management
- [Blue Build Documentation](https://blue-build.org/) - Blue Build framework documentation
- [RPM Packaging Guide](https://rpm-packaging-guide.github.io/) - RPM packaging best practices
- [AKMOD Documentation](https://rpmfusion.org/Packaging/KernelModules/Akmods) - AKMOD system documentation
