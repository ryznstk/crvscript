#!/bin/bash

set -e

# Configuration
ROM_URL="https://github.com/Lunaris-AOSP/android"
ROM_BRANCH="16.2"
MANIFEST_URL="https://github.com/ryznstk/manifest.git"

DEVICE="peridot"
LUNCH_TARGET="lineage_peridot-bp4a-user"

export TZ="Asia/Jakarta"
export BUILD_USERNAME="ZXStk"
export BUILD_HOSTNAME="zen"

log() {
    echo
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# Cleanup
log "Cleaning previous source"

rm -rf .repo/local_manifests
rm -rf "device/xiaomi/$DEVICE"

# Repo init
log "Initializing ROM"

repo init \
    -u "$ROM_URL" \
    -b "$ROM_BRANCH" \
    --git-lfs \
    --depth=1

# Local manifest
log "Cloning local manifest"

git clone --depth=1 \
    "$MANIFEST_URL" \
    .repo/local_manifests

# Sync
log "Running Crave resync"

/opt/crave/resync.sh

log "Syncing repositories"

repo sync \
    -c \
    --no-clone-bundle \
    --no-tags \
    --optimized-fetch \
    --prune \
    --force-sync

# Build environment
log "Preparing build environment"

. b*/env*

lunch "$LUNCH_TARGET"

make installclean

# Build
log "Building ROM"

START=$(date +%s)

m bacon

END=$(date +%s)

echo
echo "Build completed successfully!"
echo "Build time: $(((END - START) / 60)) minutes"

log "Done!"
