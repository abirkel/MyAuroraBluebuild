#!/bin/bash
set -euo pipefail

# generate-maccel-specs.sh
# Generates RPM spec files for maccel packages, with caching support
# Version: 1.0.0

#######################################
# Logging Functions
#######################################

log_info() {
    echo "[INFO] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

#######################################
# Usage Documentation
#######################################

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Generate RPM spec files for maccel packages with caching support.

OPTIONS:
    -h, --help              Show this help message
    -v, --version VERSION   Pin to specific maccel version (default: latest)
    -f, --force             Force regeneration even if cached
    -d, --dry-run           Validate inputs without generating files

ENVIRONMENT VARIABLES:
    MACCEL_VERSION          Pin to specific maccel version (default: latest)
    FORCE_REGENERATE        Force regeneration (true/false, default: false)

OUTPUTS:
    AKMOD_SPEC_PATH         Path to generated akmod-maccel.spec
    MACCEL_SPEC_PATH        Path to generated maccel.spec

EXAMPLES:
    # Generate specs for latest version
    $(basename "$0")

    # Generate specs for specific version
    $(basename "$0") --version 0.4.1
    MACCEL_VERSION=0.4.1 $(basename "$0")

    # Force regeneration of cached specs
    $(basename "$0") --force
    FORCE_REGENERATE=true $(basename "$0")

EOF
}

#######################################
# Global Variables
#######################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATES_DIR="$WORKSPACE_ROOT/files/templates"
SPECS_CACHE_DIR="$WORKSPACE_ROOT/specs"
TEMP_DIR=""
DRY_RUN=false
FORCE_REGENERATE="${FORCE_REGENERATE:-false}"
MACCEL_VERSION="${MACCEL_VERSION:-}"
RETRY_MAX=3
RETRY_DELAY=5

#######################################
# Cleanup Handler
#######################################

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

#######################################
# Parse Command Line Arguments
#######################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                MACCEL_VERSION="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_REGENERATE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

#######################################
# Version Resolution
#######################################

get_latest_version() {
    local attempt=1
    local delay=$RETRY_DELAY
    
    log_info "Fetching latest maccel version from GitHub..."
    
    while [[ $attempt -le $RETRY_MAX ]]; do
        if latest=$(gh api repos/Gnarus-G/maccel/releases/latest --jq '.tag_name' 2>/dev/null); then
            # Remove 'v' prefix if present
            latest="${latest#v}"
            echo "$latest"
            return 0
        fi
        
        log_warn "Failed to fetch latest version (attempt $attempt/$RETRY_MAX)"
        if [[ $attempt -lt $RETRY_MAX ]]; then
            log_info "Retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done
    
    log_error "Cannot reach GitHub API after $RETRY_MAX attempts"
    log_error "Check network connectivity or GitHub status"
    return 1
}

validate_version_exists() {
    local version="$1"
    local tag="v$version"
    local attempt=1
    local delay=$RETRY_DELAY
    
    log_info "Validating maccel version $version exists..."
    
    while [[ $attempt -le $RETRY_MAX ]]; do
        if gh api "repos/Gnarus-G/maccel/releases/tags/$tag" &>/dev/null; then
            log_info "Version $version validated successfully"
            return 0
        fi
        
        log_warn "Failed to validate version (attempt $attempt/$RETRY_MAX)"
        if [[ $attempt -lt $RETRY_MAX ]]; then
            log_info "Retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done
    
    log_error "Maccel version '$version' does not exist"
    log_error "Check available versions at: https://github.com/Gnarus-G/maccel/releases"
    return 1
}

resolve_maccel_version() {
    if [[ -z "$MACCEL_VERSION" ]]; then
        log_info "No version pinned, resolving to latest..."
        MACCEL_VERSION=$(get_latest_version) || return 1
        log_info "Resolved to latest version: $MACCEL_VERSION"
    else
        # Remove 'v' prefix if present
        MACCEL_VERSION="${MACCEL_VERSION#v}"
        log_info "Using pinned version: $MACCEL_VERSION"
        validate_version_exists "$MACCEL_VERSION" || return 1
    fi
}

#######################################
# Cache Management
#######################################

check_cache() {
    local version="$1"
    local cache_dir="$SPECS_CACHE_DIR/maccel-$version"
    
    if [[ "$FORCE_REGENERATE" == "true" ]]; then
        log_info "Force regeneration enabled, skipping cache"
        return 1
    fi
    
    # Check all required files atomically to avoid TOCTOU race condition
    if [[ ! -d "$cache_dir" ]] || \
       [[ ! -f "$cache_dir/akmod-maccel.spec" ]] || \
       [[ ! -f "$cache_dir/maccel.spec" ]] || \
       [[ ! -f "$cache_dir/metadata.json" ]]; then
        log_info "Cache incomplete or missing for version $version"
        return 1
    fi
    
    log_info "Found complete cached specs for version $version"
    log_info "Cache validated successfully"
    return 0
}

use_cached_specs() {
    local version="$1"
    local cache_dir="$SPECS_CACHE_DIR/maccel-$version"
    
    export AKMOD_SPEC_PATH="$cache_dir/akmod-maccel.spec"
    export MACCEL_SPEC_PATH="$cache_dir/maccel.spec"
    
    log_info "Using cached spec files:"
    log_info "  AKMOD_SPEC_PATH=$AKMOD_SPEC_PATH"
    log_info "  MACCEL_SPEC_PATH=$MACCEL_SPEC_PATH"
}

#######################################
# Metadata Fetching
#######################################

fetch_license() {
    local version="$1"
    local attempt=1
    local delay=$RETRY_DELAY
    
    log_info "Fetching license information..."
    
    while [[ $attempt -le $RETRY_MAX ]]; do
        if license=$(gh api repos/Gnarus-G/maccel --jq '.license.spdx_id' 2>/dev/null); then
            if [[ -n "$license" && "$license" != "null" ]]; then
                echo "$license"
                return 0
            fi
        fi
        
        log_warn "Failed to fetch license (attempt $attempt/$RETRY_MAX)"
        if [[ $attempt -lt $RETRY_MAX ]]; then
            log_info "Retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done
    
    log_error "Cannot fetch license information after $RETRY_MAX attempts"
    return 1
}

fetch_changelog() {
    local version="$1"
    local tag="v$version"
    local attempt=1
    local delay=$RETRY_DELAY
    
    log_info "Fetching changelog entries..."
    
    while [[ $attempt -le $RETRY_MAX ]]; do
        if release_data=$(gh api "repos/Gnarus-G/maccel/releases/tags/$tag" 2>/dev/null); then
            local body
            body=$(echo "$release_data" | jq -r '.body // ""')
            
            if [[ -n "$body" ]]; then
                echo "$body"
                return 0
            fi
        fi
        
        log_warn "Failed to fetch changelog (attempt $attempt/$RETRY_MAX)"
        if [[ $attempt -lt $RETRY_MAX ]]; then
            log_info "Retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done
    
    log_warn "Cannot fetch changelog after $RETRY_MAX attempts, using default"
    echo "Update to maccel $version"
    return 0
}

fetch_source_url() {
    local version="$1"
    echo "https://github.com/Gnarus-G/maccel/archive/refs/tags/v${version}.tar.gz"
}

fetch_upstream_commit() {
    local version="$1"
    local tag="v$version"
    
    if commit=$(gh api "repos/Gnarus-G/maccel/git/ref/tags/$tag" --jq '.object.sha' 2>/dev/null); then
        echo "$commit"
    else
        echo "unknown"
    fi
}

#######################################
# Spec File Generation
#######################################

format_changelog_entry() {
    local version="$1"
    local changelog_body="$2"
    local date
    date=$(date '+%a %b %d %Y')
    
    # Start with RPM changelog header
    echo "* $date Blue Build <noreply@bluebuild.org> - $version-1"
    echo "- Update to maccel $version"
    
    # Format changelog body if present
    if [[ -n "$changelog_body" && "$changelog_body" != "Update to maccel $version" ]]; then
        echo "- Upstream changes:"
        # Convert markdown list items to RPM format, limit to first 10 lines
        echo "$changelog_body" | head -n 10 | sed 's/^[*-] /  - /' | sed 's/^/  /'
    fi
}

generate_spec_from_template() {
    local template_file="$1"
    local output_file="$2"
    local version="$3"
    local license="$4"
    local source_url="$5"
    local changelog="$6"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        log_error "Expected location: $TEMPLATES_DIR/"
        log_error "Ensure all template files are present in the repository"
        return 1
    fi
    
    log_info "Generating spec from template: $(basename "$template_file")"
    
    # Read template and replace variables
    local content
    content=$(cat "$template_file")
    
    content="${content//\{\{MACCEL_VERSION\}\}/$version}"
    content="${content//\{\{LICENSE\}\}/$license}"
    content="${content//\{\{SOURCE_URL\}\}/$source_url}"
    content="${content//\{\{CHANGELOG\}\}/$changelog}"
    
    echo "$content" > "$output_file"
    log_info "Generated: $output_file"
}

generate_specs() {
    local version="$1"
    local license="$2"
    local source_url="$3"
    local changelog_body="$4"
    
    TEMP_DIR=$(mktemp -d)
    log_info "Using temporary directory: $TEMP_DIR"
    
    # Format changelog
    local changelog
    changelog=$(format_changelog_entry "$version" "$changelog_body")
    
    # Generate akmod spec
    local akmod_template="$TEMPLATES_DIR/akmod-maccel.spec.template"
    local akmod_spec="$TEMP_DIR/akmod-maccel.spec"
    generate_spec_from_template "$akmod_template" "$akmod_spec" "$version" "$license" "$source_url" "$changelog" || return 1
    
    # Generate maccel spec
    local maccel_template="$TEMPLATES_DIR/maccel.spec.template"
    local maccel_spec="$TEMP_DIR/maccel.spec"
    generate_spec_from_template "$maccel_template" "$maccel_spec" "$version" "$license" "$source_url" "$changelog" || return 1
    
    export TEMP_AKMOD_SPEC="$akmod_spec"
    export TEMP_MACCEL_SPEC="$maccel_spec"
}

#######################################
# Spec File Validation
#######################################

validate_spec_file() {
    local spec_file="$1"
    local spec_name
    spec_name=$(basename "$spec_file")
    
    log_info "Validating $spec_name with rpmlint..."
    
    # Check if rpmlint is available
    if ! command -v rpmlint &>/dev/null; then
        log_warn "rpmlint not found, skipping validation"
        log_warn "Install rpmlint for spec file validation: dnf install rpmlint"
        return 0
    fi
    
    local output
    if output=$(rpmlint "$spec_file" 2>&1); then
        log_info "$spec_name validation passed"
        return 0
    else
        # rpmlint often returns non-zero even for warnings, check output
        if echo "$output" | grep -qi "error"; then
            log_error "Spec file validation failed for $spec_name"
            log_error "rpmlint output:"
            echo "$output" >&2
            log_error ""
            log_error "Fix the spec file template and regenerate"
            return 1
        else
            log_warn "rpmlint warnings for $spec_name (non-fatal):"
            echo "$output" >&2
            return 0
        fi
    fi
}

validate_specs() {
    validate_spec_file "$TEMP_AKMOD_SPEC" || return 1
    validate_spec_file "$TEMP_MACCEL_SPEC" || return 1
    log_info "All spec files validated successfully"
}

#######################################
# Caching
#######################################

cache_specs() {
    local version="$1"
    local license="$2"
    local source_url="$3"
    local upstream_commit="$4"
    
    local cache_dir="$SPECS_CACHE_DIR/maccel-$version"
    
    log_info "Caching spec files to: $cache_dir"
    
    # Create cache directory
    mkdir -p "$cache_dir"
    
    # Move spec files atomically
    mv "$TEMP_AKMOD_SPEC" "$cache_dir/akmod-maccel.spec"
    mv "$TEMP_MACCEL_SPEC" "$cache_dir/maccel.spec"
    
    # Generate metadata
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    
    cat > "$cache_dir/metadata.json" << EOF
{
  "maccel_version": "$version",
  "generated_at": "$timestamp",
  "source_url": "$source_url",
  "license": "$license",
  "generator_version": "1.0.0",
  "upstream_commit": "$upstream_commit",
  "changelog_entries": 1
}
EOF
    
    log_info "Spec files cached successfully"
    log_info "Cache contents:"
    log_info "  - akmod-maccel.spec"
    log_info "  - maccel.spec"
    log_info "  - metadata.json"
}

#######################################
# Output
#######################################

output_spec_paths() {
    local version="$1"
    local cache_dir="$SPECS_CACHE_DIR/maccel-$version"
    
    export AKMOD_SPEC_PATH="$cache_dir/akmod-maccel.spec"
    export MACCEL_SPEC_PATH="$cache_dir/maccel.spec"
    
    log_info "Spec files ready:"
    log_info "  AKMOD_SPEC_PATH=$AKMOD_SPEC_PATH"
    log_info "  MACCEL_SPEC_PATH=$MACCEL_SPEC_PATH"
    
    # Output for sourcing in other scripts
    echo "export AKMOD_SPEC_PATH='$AKMOD_SPEC_PATH'"
    echo "export MACCEL_SPEC_PATH='$MACCEL_SPEC_PATH'"
}

#######################################
# Main Execution
#######################################

main() {
    log_info "Starting maccel spec file generator..."
    
    # Parse arguments
    parse_args "$@"
    
    # Resolve version
    resolve_maccel_version || exit 1
    
    # Check cache
    if check_cache "$MACCEL_VERSION"; then
        use_cached_specs "$MACCEL_VERSION"
        log_info "Using cached specs, generation complete"
        return 0
    fi
    
    # Dry run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run mode: validation complete, no files generated"
        return 0
    fi
    
    # Fetch metadata
    log_info "Fetching metadata for version $MACCEL_VERSION..."
    LICENSE=$(fetch_license "$MACCEL_VERSION") || exit 1
    SOURCE_URL=$(fetch_source_url "$MACCEL_VERSION")
    CHANGELOG_BODY=$(fetch_changelog "$MACCEL_VERSION") || exit 1
    UPSTREAM_COMMIT=$(fetch_upstream_commit "$MACCEL_VERSION")
    
    log_info "Metadata fetched:"
    log_info "  License: $LICENSE"
    log_info "  Source URL: $SOURCE_URL"
    log_info "  Upstream commit: $UPSTREAM_COMMIT"
    
    # Generate specs
    log_info "Generating spec files..."
    generate_specs "$MACCEL_VERSION" "$LICENSE" "$SOURCE_URL" "$CHANGELOG_BODY" || exit 1
    
    # Validate specs
    validate_specs || exit 1
    
    # Cache specs
    cache_specs "$MACCEL_VERSION" "$LICENSE" "$SOURCE_URL" "$UPSTREAM_COMMIT" || exit 1
    
    # Output paths
    output_spec_paths "$MACCEL_VERSION"
    
    log_info "Spec file generation completed successfully"
}

# Execute main function
main "$@"
