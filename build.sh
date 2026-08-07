#!/bin/bash

set -euo pipefail

# ========= Configuration =========
ROM_URL="https://github.com/Lunaris-AOSP/android"
ROM_BRANCH="16.2"
MANIFEST_URL="https://github.com/ryznstk/manifest.git"

LUNCH_TARGET="lineage_peridot-bp4a-user"

export TZ="Asia/Jakarta"
export BUILD_USERNAME="ZXStk"
export BUILD_HOSTNAME="zen"

# ========= Helper =========
log() {
    echo
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# ========= Cleanup =========
log "Cleaning previous trees"

rm -rf .repo/local_manifests
rm -rf device/xiaomi/peridot

# ========= Initialize =========
log "Initializing ROM"

repo init \
    -u "$ROM_URL" \
    -b "$ROM_BRANCH" \
    --git-lfs \
    --depth=1

# ========= Local Manifest =========
log "Cloning local manifest"

git clone --depth=1 \
    "$MANIFEST_URL" \
    .repo/local_manifests

# ========= Sync =========
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

# ========= Build =========
log "Setting up build environment"

. b*/env*

lunch "$LUNCH_TARGET"

make installclean

log "Starting build"

m bacon

log "Build completed successfully!"