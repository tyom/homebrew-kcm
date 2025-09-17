#!/bin/bash
# Script to create a new release and update the formula

set -euo pipefail

# Parse arguments
DRY_RUN=false
VERSION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            VERSION="$1"
            shift
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    echo "Usage: $0 [--dry-run] <version>"
    echo "Example: $0 0.1.1"
    echo "Example: $0 --dry-run 0.1.1"
    exit 1
fi

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN MODE - No changes will be committed or pushed"
    echo ""
fi

echo "Creating release v${VERSION}..."
echo ""

# Detect sed type for portability (BSD vs GNU)
if sed --version >/dev/null 2>&1; then
    # GNU sed
    SED_INPLACE="sed -i"
else
    # BSD sed (macOS)
    SED_INPLACE="sed -i ''"
fi

# Update version in kcm script
echo "Updating version in kcm script..."
if [ "$DRY_RUN" = true ]; then
    echo "  Would update VERSION and header comment to ${VERSION}"
else
    $SED_INPLACE "s/^VERSION=\".*\"/VERSION=\"${VERSION}\"/" kcm
    $SED_INPLACE "s/^# Version: .*/# Version: ${VERSION}/" kcm
fi

# Generate formula from template with version (SHA256 will be updated later)
echo "Generating Formula/kcm.rb from template..."
if [ "$DRY_RUN" = true ]; then
    echo "  Would generate Formula/kcm.rb with version ${VERSION}"
    sed -e "s/{{VERSION}}/${VERSION}/g" -e "s/{{SHA256}}/PLACEHOLDER/" Formula/kcm.rb.template > /tmp/kcm.rb.dry-run
else
    sed -e "s/{{VERSION}}/${VERSION}/g" -e "s/{{SHA256}}/PLACEHOLDER/" Formula/kcm.rb.template > Formula/kcm.rb
fi

# Commit changes
echo "Committing changes..."
if [ "$DRY_RUN" = true ]; then
    echo "  Would commit: kcm Formula/kcm.rb"
    echo "  Message: Release v${VERSION}"
else
    git add kcm Formula/kcm.rb
    # Check if there are actual changes to commit
    if git diff --cached --quiet; then
        echo "  No changes to commit - files already at version ${VERSION}"
        echo "  Skipping tag creation and push"
        exit 0
    fi
    git commit -m "Release v${VERSION}"
fi

# Create and push tag
echo "Creating and pushing tag..."
if [ "$DRY_RUN" = true ]; then
    echo "  Would create tag: v${VERSION}"
    echo "  Would push: origin main --tags"
else
    git tag -a "v${VERSION}" -m "Release v${VERSION}"
    git push origin main --tags
fi

# Get the SHA256 of the release tarball
echo ""
echo "Calculating SHA256 for release tarball..."

TARBALL_URL="https://github.com/tyom/kcm/archive/refs/tags/v${VERSION}.tar.gz"

if [ "$DRY_RUN" = true ]; then
    echo "  Would download from: $TARBALL_URL"
    echo "  (In dry-run mode, cannot calculate actual SHA256 since tag doesn't exist)"
    SHA256="DRY_RUN_SHA256_PLACEHOLDER"
else
    echo "  Waiting for GitHub to generate the tarball..."
    sleep 2

    echo "  Downloading tarball from: $TARBALL_URL"

    # Download and calculate SHA256
    curl -sL "$TARBALL_URL" -o /tmp/kcm-release.tar.gz
    SHA256=$(shasum -a 256 /tmp/kcm-release.tar.gz | awk '{print $1}')
    rm /tmp/kcm-release.tar.gz
fi

echo "  SHA256: $SHA256"

# Generate final formula from template with correct SHA256
echo "Updating Formula/kcm.rb with SHA256..."
if [ "$DRY_RUN" = true ]; then
    echo "  Would update Formula/kcm.rb with SHA256: $SHA256"
    sed -e "s/{{VERSION}}/${VERSION}/g" -e "s/{{SHA256}}/${SHA256}/g" Formula/kcm.rb.template > /tmp/kcm.rb.final.dry-run
else
    sed -e "s/{{VERSION}}/${VERSION}/g" -e "s/{{SHA256}}/${SHA256}/g" Formula/kcm.rb.template > Formula/kcm.rb
fi

# Commit and push the formula update
echo "Committing formula update..."
if [ "$DRY_RUN" = true ]; then
    echo "  Would commit: Formula/kcm.rb"
    echo "  Message: Update formula SHA256 for v${VERSION}"
    echo "  Would push: origin main"
else
    git add Formula/kcm.rb
    git commit -m "Update formula SHA256 for v${VERSION}"
    git push origin main
fi

echo ""
if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN COMPLETE - No actual changes were made"
    echo ""
    echo "To perform the actual release, run:"
    echo "  $0 ${VERSION}"
else
    echo "Release v${VERSION} created successfully!"
    echo ""
    echo "Users can now install/upgrade with:"
    echo "  brew tap tyom/kcm"
    echo "  brew install kcm"
    echo "  brew upgrade kcm"
fi
