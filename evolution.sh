#!/bin/bash

set -e

# ============================================================
# Evolution-X Peridot Build Script
# ============================================================

# -----------------------------
# ROM Configuration
# -----------------------------
ROM_NAME="Evolution-X"
ROM_URL="https://github.com/Evolution-X/manifest"
ROM_BRANCH="cnb"

MANIFEST_URL="https://github.com/ryznstk/manifest.git"

DEVICE="peridot"
BUILD_VARIANT="cp2a-user"

export TZ="Asia/Jakarta"
export BUILD_USERNAME="ryznstk"
export BUILD_HOSTNAME="crave"

# -----------------------------
# Colors
# -----------------------------
RESET='\033[0m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
BOLD='\033[1m'

# -----------------------------
# Runtime variables
# -----------------------------
PIXELDRAIN_URL=""
GOFILE_URL=""

JOB_START=$(date +%s)

# ============================================================
# UI
# ============================================================

banner() {
    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                  EVOLUTION-X BUILDER                    ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║ ROM      : Evolution-X                                   ║"
    echo "║ Device   : peridot                                       ║"
    echo "║ Variant  : cp2a-user                                     ║"
    echo "║ Branch   : cnb                                           ║"
    echo "║ Builder  : dcore                                         ║"
    echo "║ Host     : lake                                          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

section() {
    echo
    echo -e "${CYAN}${BOLD}▶ $1${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${RESET}"
}

ok() {
    echo -e "${GREEN}${BOLD}✔ $1${RESET}"
}

info() {
    echo -e "${BLUE}➜ $1${RESET}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

fail() {
    echo -e "${RED}${BOLD}✖ $1${RESET}"
}

# ============================================================
# Optional .env
# ============================================================

if [[ -f ".env" ]]; then
    source ".env"
    ok ".env loaded"
else
    warn ".env not found - continuing"
fi

# ============================================================
# Telegram
# ============================================================

tg_send() {
    local MESSAGE="$1"

    [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] && return 0
    [[ -z "${TELEGRAM_CHAT_ID:-}" ]] && return 0

    curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${MESSAGE}" \
        >/dev/null 2>&1 || true
}

# ============================================================
# Telegram - Build Started
# ============================================================

notify_build_start() {

    tg_send "🚀 Evolution-X build started

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}
Branch: ${ROM_BRANCH}
Host: ${BUILD_HOSTNAME}
Builder: ${BUILD_USERNAME}

⏳ Build in progress..."
}

# ============================================================
# Telegram - Build Failed
# ============================================================

notify_build_failed() {

    tg_send "❌ Evolution-X build FAILED

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}
Branch: ${ROM_BRANCH}
Host: ${BUILD_HOSTNAME}

⚠️ Check the Crave build output for details."
}

# ============================================================
# Telegram - Artifact
# ============================================================

notify_artifact() {

    local FILE="$1"

    local NAME
    local SIZE

    NAME=$(basename "$FILE")
    SIZE=$(du -h "$FILE" | cut -f1)

    local MESSAGE="📦 Evolution-X

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}

📄 ${NAME}
💾 ${SIZE}"

    if [[ -n "${PIXELDRAIN_URL}" ]]; then

        MESSAGE="${MESSAGE}

🟢 PixelDrain
${PIXELDRAIN_URL}"

    else

        MESSAGE="${MESSAGE}

🔴 PixelDrain
Upload failed/skipped"

    fi

    if [[ -n "${GOFILE_URL}" ]]; then

        MESSAGE="${MESSAGE}

🟢 GoFile
${GOFILE_URL}"

    else

        MESSAGE="${MESSAGE}

🔴 GoFile
Upload failed/skipped"

    fi

    tg_send "$MESSAGE"
}

# ============================================================
# Telegram - Finished
# ============================================================

notify_finished() {

    local MINUTES="$1"

    tg_send "🏁 Evolution-X build finished

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}

⏱ Total time: ${MINUTES} minutes"
}

# ============================================================
# PixelDrain Upload
# ============================================================

upload_pixeldrain() {

    local FILE="$1"

    PIXELDRAIN_URL=""

    if [[ ! -f "$FILE" ]]; then
        fail "File not found: $FILE"
        return 1
    fi

    if [[ -z "${PIXELDRAIN_TOKEN:-}" ]]; then
        warn "PIXELDRAIN_TOKEN not set"
        return 1
    fi

    section "PixelDrain Upload"

    info "File: $(basename "$FILE")"
    info "Size: $(du -h "$FILE" | cut -f1)"

    local RESPONSE
    local FILE_ID

    RESPONSE=$(curl \
        --progress-bar \
        -T "$FILE" \
        -u ":${PIXELDRAIN_TOKEN}" \
        "https://pixeldrain.com/api/file/" 2>/dev/null)

    FILE_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

    if [[ -z "$FILE_ID" ]]; then

        fail "PixelDrain upload failed"

        echo "$RESPONSE"

        return 1

    fi

    PIXELDRAIN_URL="https://pixeldrain.com/u/${FILE_ID}"

    ok "PixelDrain upload complete"
    info "$PIXELDRAIN_URL"
}

# ============================================================
# GoFile Upload
# ============================================================

upload_gofile() {

    local FILE="$1"

    GOFILE_URL=""

    if [[ ! -f "$FILE" ]]; then
        fail "File not found: $FILE"
        return 1
    fi

    section "GoFile Upload"

    info "File: $(basename "$FILE")"
    info "Size: $(du -h "$FILE" | cut -f1)"

    local RESPONSE
    local DOWNLOAD_URL

    RESPONSE=$(curl \
        --progress-bar \
        -X POST \
        -F "file=@${FILE}" \
        "https://upload-ap-sgp.gofile.io/uploadfile" 2>/dev/null)

    DOWNLOAD_URL=$(echo "$RESPONSE" | jq -r '.data.downloadPage // empty')

    if [[ -z "$DOWNLOAD_URL" ]]; then

        fail "GoFile upload failed"

        echo "$RESPONSE"

        return 1

    fi

    GOFILE_URL="$DOWNLOAD_URL"

    ok "GoFile upload complete"
    info "$GOFILE_URL"
}

# ============================================================
# Start
# ============================================================

banner

section "Checking Dependencies"

command -v git >/dev/null || {
    fail "git is missing"
    exit 1
}

command -v repo >/dev/null || {
    fail "repo is missing"
    exit 1
}

command -v curl >/dev/null || {
    fail "curl is missing"
    exit 1
}

command -v jq >/dev/null || {
    fail "jq is missing"
    exit 1
}

ok "Dependencies ready"

# ============================================================
# Prepare Workspace
# ============================================================

section "Preparing Workspace"

rm -rf .repo/local_manifests
rm -rf "device/xiaomi/${DEVICE}"
rm -rf "out/target/product/${DEVICE}"

ok "Workspace cleaned"

# ============================================================
# Repo Init
# ============================================================

section "Initializing Evolution-X"

repo init \
    -u "${ROM_URL}" \
    -b "${ROM_BRANCH}" \
    --git-lfs \
    --depth=1

ok "Evolution-X repository initialized"

# ============================================================
# Local Manifest
# ============================================================

section "Cloning Device Manifest"

git clone \
    --depth=1 \
    "${MANIFEST_URL}" \
    .repo/local_manifests

ok "Device manifest installed"

# ============================================================
# Sync
# ============================================================

section "Syncing Source"

SYNC_START=$(date +%s)

if [[ -x "/opt/crave/resync.sh" ]]; then

    info "Using Crave resync"
    /opt/crave/resync.sh

else

    warn "Crave resync not found"
    info "Using repo sync"

    repo sync \
        -c \
        --force-sync \
        --no-tags \
        --no-clone-bundle \
        --force-remove-dirty

fi

SYNC_END=$(date +%s)

ok "Source sync complete"
info "Sync time: $(((SYNC_END - SYNC_START) / 60)) minutes"

# ============================================================
# Build Environment
# ============================================================

section "Loading Build Environment"

. build/envsetup.sh

ok "Build environment loaded"

# ============================================================
# Load .env Again
# ============================================================

if [[ -f ".env" ]]; then
    source ".env"
fi

# ============================================================
# Lunch
# ============================================================

section "Selecting Build Target"

lunch lineage_peridot-cp2a-user

ok "Target: lineage_peridot-cp2a-user"

# ============================================================
# Telegram
# ============================================================

notify_build_start

# ============================================================
# Install Clean
# ============================================================

section "Running Install Clean"

make installclean

ok "Install clean complete"

# ============================================================
# Build
# ============================================================

section "Building Evolution-X"

BUILD_START=$(date +%s)

if m evolution; then

    BUILD_SUCCESS=1

else

    BUILD_SUCCESS=0

fi

BUILD_END=$(date +%s)
BUILD_MINUTES=$(((BUILD_END - BUILD_START) / 60))

# ============================================================
# Build Failed
# ============================================================

if [[ "${BUILD_SUCCESS}" != "1" ]]; then

    fail "Evolution-X build failed"
    info "Build time: ${BUILD_MINUTES} minutes"

    notify_build_failed

    exit 1

fi

# ============================================================
# Build Successful
# ============================================================

ok "Evolution-X build successful"
info "Build time: ${BUILD_MINUTES} minutes"

# ============================================================
# Find Artifacts
# ============================================================

section "Finding Build Artifacts"

ARTIFACTS=()

# ------------------------------------------------------------
# ROM ZIP
# ------------------------------------------------------------

while IFS= read -r -d '' FILE; do

    ARTIFACTS+=("$FILE")

done < <(
    find "out/target/product/${DEVICE}" \
        -maxdepth 1 \
        -type f \
        -name "*.zip" \
        ! -name "*target_files*" \
        ! -name "*ota*" \
        -print0
)

# ------------------------------------------------------------
# Selected Images ONLY
# ------------------------------------------------------------

SELECTED_IMAGES=(
    "boot.img"
    "vendor_boot.img"
    "dtbo.img"
    "recovery.img"
)

for IMAGE in "${SELECTED_IMAGES[@]}"; do

    IMAGE_PATH="out/target/product/${DEVICE}/${IMAGE}"

    if [[ -f "${IMAGE_PATH}" ]]; then

        ARTIFACTS+=("${IMAGE_PATH}")

    fi

done

# ============================================================
# Artifact Check
# ============================================================

if [[ ${#ARTIFACTS[@]} -eq 0 ]]; then

    warn "No supported artifacts found"

    tg_send "⚠️ Evolution-X build completed

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}

No ROM ZIP or selected images were found."

else

    ok "Found ${#ARTIFACTS[@]} artifact(s)"

    for FILE in "${ARTIFACTS[@]}"; do

        echo
        info "$(basename "$FILE")"
        info "Size: $(du -h "$FILE" | cut -f1)"

    done

    # ========================================================
    # Upload
    # ========================================================

    for FILE in "${ARTIFACTS[@]}"; do

        PIXELDRAIN_URL=""
        GOFILE_URL=""

        echo
        section "Uploading $(basename "$FILE")"

        # -------------------------------
        # PixelDrain
        # -------------------------------

        upload_pixeldrain "$FILE" || true

        # -------------------------------
        # GoFile
        # -------------------------------

        upload_gofile "$FILE" || true

        # -------------------------------
        # Telegram
        # -------------------------------

        notify_artifact "$FILE"

    done

fi

# ============================================================
# Finish
# ============================================================

JOB_END=$(date +%s)
TOTAL_MINUTES=$(((JOB_END - JOB_START) / 60))

section "Job Complete"

ok "Everything finished"
info "Total time: ${TOTAL_MINUTES} minutes"

notify_finished "${TOTAL_MINUTES}"

echo
echo -e "${GREEN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  EVOLUTION-X COMPLETE                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
