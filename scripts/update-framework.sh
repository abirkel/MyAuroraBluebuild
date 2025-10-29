#!/bin/bash
# MyAuroraBluebuild Framework Update Script
# This script helps update Blue Build framework and other dependencies

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKFLOW_FILE=".github/workflows/build.yml"
BACKUP_SUFFIX=".backup-$(date +%Y%m%d-%H%M%S)"

echo -e "${BLUE}=== MyAuroraBluebuild Framework Update ===${NC}"
echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo ""

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

# Function to check command availability
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_status "error" "Required command '$1' not found"
        echo "Please install $1 to run this update script"
        exit 1
    fi
}

# Function to confirm action
confirm_action() {
    local message=$1
    echo -e "${YELLOW}$message${NC}"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "info" "Operation cancelled by user"
        exit 0
    fi
}

# Check required commands
print_status "info" "Checking required tools..."
check_command "gh"
check_command "jq"
check_command "git"
print_status "success" "All required tools are available"
echo ""

# Parse command line arguments
UPDATE_TYPE="${1:-all}"
case $UPDATE_TYPE in
    "bluebuild"|"framework")
        UPDATE_BLUEBUILD=true
        UPDATE_ACTIONS=false
        UPDATE_DEPS=false
        ;;
    "actions")
        UPDATE_BLUEBUILD=false
        UPDATE_ACTIONS=true
        UPDATE_DEPS=false
        ;;
    "deps"|"dependencies")
        UPDATE_BLUEBUILD=false
        UPDATE_ACTIONS=false
        UPDATE_DEPS=true
        ;;
    "all")
        UPDATE_BLUEBUILD=true
        UPDATE_ACTIONS=true
        UPDATE_DEPS=true
        ;;
    *)
        echo "Usage: $0 [bluebuild|actions|deps|all]"
        echo ""
        echo "Options:"
        echo "  bluebuild  - Update Blue Build framework only"
        echo "  actions    - Update GitHub Actions only"
        echo "  deps       - Update other dependencies only"
        echo "  all        - Update everything (default)"
        exit 1
        ;;
esac

print_status "info" "Update type: $UPDATE_TYPE"
echo ""

# Backup current workflow file
if [[ -f "$WORKFLOW_FILE" ]]; then
    print_status "info" "Creating backup of current workflow file"
    cp "$WORKFLOW_FILE" "${WORKFLOW_FILE}${BACKUP_SUFFIX}"
    print_status "success" "Backup created: ${WORKFLOW_FILE}${BACKUP_SUFFIX}"
else
    print_status "error" "Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

# Update Blue Build framework
if [[ "$UPDATE_BLUEBUILD" == "true" ]]; then
    echo "=== Blue Build Framework Update ==="
    
    # Get current version
    if CURRENT_VERSION=$(grep "blue-build/github-action@" "$WORKFLOW_FILE" | head -1 | sed 's/.*@v\([0-9.]*\).*/\1/'); then
        print_status "info" "Current Blue Build version: v$CURRENT_VERSION"
        
        # Get latest version
        if LATEST_VERSION=$(gh api repos/blue-build/github-action/releases/latest --jq '.tag_name' | sed 's/^v//'); then
            print_status "info" "Latest Blue Build version: v$LATEST_VERSION"
            
            if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
                print_status "success" "Blue Build framework is already up to date"
            else
                print_status "warning" "Blue Build framework update available: v$CURRENT_VERSION → v$LATEST_VERSION"
                
                # Show release notes
                print_status "info" "Fetching release notes..."
                RELEASE_NOTES=$(gh api repos/blue-build/github-action/releases/latest --jq '.body' | head -20)
                echo "Release notes (first 20 lines):"
                echo "$RELEASE_NOTES"
                echo ""
                
                confirm_action "Update Blue Build framework from v$CURRENT_VERSION to v$LATEST_VERSION?"
                
                # Perform update
                print_status "info" "Updating Blue Build framework..."
                sed -i "s/blue-build\/github-action@v$CURRENT_VERSION/blue-build\/github-action@v$LATEST_VERSION/g" "$WORKFLOW_FILE"
                
                if grep -q "blue-build/github-action@v$LATEST_VERSION" "$WORKFLOW_FILE"; then
                    print_status "success" "Blue Build framework updated successfully"
                else
                    print_status "error" "Blue Build framework update failed"
                    print_status "info" "Restoring backup..."
                    cp "${WORKFLOW_FILE}${BACKUP_SUFFIX}" "$WORKFLOW_FILE"
                    exit 1
                fi
            fi
        else
            print_status "error" "Could not fetch latest Blue Build version"
        fi
    else
        print_status "error" "Could not detect current Blue Build version"
    fi
    echo ""
fi

# Update other GitHub Actions
if [[ "$UPDATE_ACTIONS" == "true" ]]; then
    echo "=== GitHub Actions Update ==="
    
    # List of actions to check and update
    declare -A ACTIONS_TO_UPDATE=(
        ["actions/checkout"]="v4"
        ["actions/cache"]="v4"
        ["actions/upload-artifact"]="v4"
        ["snok/container-retention-policy"]="v3.0.0"
    )
    
    for action in "${!ACTIONS_TO_UPDATE[@]}"; do
        EXPECTED_VERSION="${ACTIONS_TO_UPDATE[$action]}"
        
        if grep -q "$action@" "$WORKFLOW_FILE"; then
            CURRENT_ACTION_VERSION=$(grep "$action@" "$WORKFLOW_FILE" | head -1 | sed "s/.*$action@\([^[:space:]]*\).*/\1/")
            print_status "info" "Current $action version: $CURRENT_ACTION_VERSION"
            
            if [[ "$CURRENT_ACTION_VERSION" != "$EXPECTED_VERSION" ]]; then
                print_status "warning" "$action update available: $CURRENT_ACTION_VERSION → $EXPECTED_VERSION"
                
                confirm_action "Update $action from $CURRENT_ACTION_VERSION to $EXPECTED_VERSION?"
                
                # Perform update
                sed -i "s/$action@$CURRENT_ACTION_VERSION/$action@$EXPECTED_VERSION/g" "$WORKFLOW_FILE"
                print_status "success" "$action updated to $EXPECTED_VERSION"
            else
                print_status "success" "$action is up to date"
            fi
        else
            print_status "info" "$action not found in workflow (may not be used)"
        fi
    done
    echo ""
fi

# Update other dependencies
if [[ "$UPDATE_DEPS" == "true" ]]; then
    echo "=== Other Dependencies Update ==="
    
    # Check for Dependabot configuration
    if [[ -f ".github/dependabot.yml" ]]; then
        print_status "success" "Dependabot is configured for automatic updates"
        
        # Check if Dependabot PRs exist
        if DEPENDABOT_PRS=$(gh pr list --author "app/dependabot" --json number,title 2>/dev/null); then
            PR_COUNT=$(echo "$DEPENDABOT_PRS" | jq length)
            if [[ "$PR_COUNT" -gt 0 ]]; then
                print_status "info" "Found $PR_COUNT Dependabot PRs"
                echo "$DEPENDABOT_PRS" | jq -r '.[] | "  #\(.number): \(.title)"'
                print_status "info" "Review and merge Dependabot PRs to update dependencies"
            else
                print_status "success" "No pending Dependabot PRs"
            fi
        fi
    else
        print_status "warning" "Dependabot is not configured"
        print_status "info" "Consider enabling Dependabot for automatic dependency updates"
    fi
    
    # Check recipe.yml for any updates needed
    if [[ -f "recipes/recipe.yml" ]]; then
        print_status "info" "Checking recipe configuration..."
        
        # Check base image
        BASE_IMAGE=$(grep "base-image:" recipes/recipe.yml | awk '{print $2}')
        print_status "info" "Current base image: $BASE_IMAGE"
        
        # Check if we should suggest any recipe updates
        if grep -q "image-version: latest" recipes/recipe.yml; then
            print_status "success" "Using latest base image version (automatic updates)"
        else
            print_status "info" "Consider using 'latest' for automatic base image updates"
        fi
    fi
    echo ""
fi

# Validate updated workflow
echo "=== Validation ==="
print_status "info" "Validating updated workflow file..."

# Check YAML syntax
if python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW_FILE'))" 2>/dev/null; then
    print_status "success" "Workflow file YAML syntax is valid"
else
    print_status "error" "Workflow file YAML syntax is invalid"
    print_status "info" "Restoring backup..."
    cp "${WORKFLOW_FILE}${BACKUP_SUFFIX}" "$WORKFLOW_FILE"
    exit 1
fi

# Check for required components
REQUIRED_COMPONENTS=(
    "blue-build/github-action"
    "registry_token"
    "recipe:"
)

for component in "${REQUIRED_COMPONENTS[@]}"; do
    if grep -q "$component" "$WORKFLOW_FILE"; then
        print_status "success" "Required component found: $component"
    else
        print_status "error" "Required component missing: $component"
        print_status "info" "Restoring backup..."
        cp "${WORKFLOW_FILE}${BACKUP_SUFFIX}" "$WORKFLOW_FILE"
        exit 1
    fi
done

print_status "success" "Workflow file validation passed"
echo ""

# Show changes
echo "=== Changes Summary ==="
print_status "info" "Comparing changes..."
if diff -u "${WORKFLOW_FILE}${BACKUP_SUFFIX}" "$WORKFLOW_FILE" || true; then
    echo ""
fi

# Commit changes
echo "=== Commit Changes ==="
if git diff --quiet "$WORKFLOW_FILE"; then
    print_status "info" "No changes to commit"
else
    print_status "info" "Changes detected in workflow file"
    
    confirm_action "Commit the changes to git?"
    
    # Configure git if needed
    if ! git config user.name >/dev/null 2>&1; then
        print_status "info" "Configuring git user..."
        git config user.name "Framework Update Script"
        git config user.email "noreply@github.com"
    fi
    
    # Commit changes
    git add "$WORKFLOW_FILE"
    
    COMMIT_MESSAGE="Update framework dependencies

- Blue Build framework: $(grep "blue-build/github-action@" "$WORKFLOW_FILE" | head -1 | sed 's/.*@\(v[0-9.]*\).*/\1/')
- Updated by: update-framework.sh
- Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    
    git commit -m "$COMMIT_MESSAGE"
    print_status "success" "Changes committed to git"
    
    print_status "info" "Push changes with: git push origin main"
fi
echo ""

# Test recommendation
echo "=== Testing Recommendations ==="
print_status "info" "After updating the framework:"
echo "1. Push changes to trigger a test build"
echo "2. Monitor the build workflow for any issues"
echo "3. Test the resulting image functionality"
echo "4. Run health check: ./scripts/health-check.sh"
echo "5. If issues occur, revert using: cp ${WORKFLOW_FILE}${BACKUP_SUFFIX} $WORKFLOW_FILE"
echo ""

# Cleanup option
echo "=== Cleanup ==="
print_status "info" "Backup file created: ${WORKFLOW_FILE}${BACKUP_SUFFIX}"
read -p "Remove backup file? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm "${WORKFLOW_FILE}${BACKUP_SUFFIX}"
    print_status "success" "Backup file removed"
else
    print_status "info" "Backup file kept for safety"
fi

echo ""
print_status "success" "Framework update completed successfully"
echo -e "${BLUE}=== Update Complete ===${NC}"