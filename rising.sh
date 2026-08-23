#!/bin/bash

set -e

# ============================================================
# RisingOS Peridot Build Script
# ============================================================

# -----------------------------
# ROM Configuration
# -----------------------------
ROM_NAME="RisingOS"
ROM_URL="https://github.com/RisingOS-Revived/android"
ROM_BRANCH="seventeen"

MANIFEST_URL="https://github.com/ryznstk/manifest.git"

DEVICE="peridot"
BUILD_VARIANT="user"

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
SOURCEFORGE_URL=""

JOB_START=$(date +%s)

# ============================================================
# UI
# ============================================================

banner() {
    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                  RISINGOS BUILDER                      ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║ ROM      : RisingOS                                    ║"
    echo "║ Device   : peridot                                        ║"
    echo "║ Variant  : cp2a-user                                      ║"
    echo "║ Branch   : cnb                                            ║"
    echo "║ Builder  : ryznstk                                        ║"
    echo "║ Host     : crave                                          ║"
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

    tg_send "🚀 RisingOS build started

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

    tg_send "❌ RisingOS build FAILED

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

    local MESSAGE="📦 RisingOS

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}

📄 ${NAME}
💾 ${SIZE}"

    # -------------------------------
    # PixelDrain
    # -------------------------------

    if [[ -n "${PIXELDRAIN_URL}" ]]; then

        MESSAGE="${MESSAGE}

🟢 PixelDrain
${PIXELDRAIN_URL}"

    else

        MESSAGE="${MESSAGE}

🔴 PixelDrain
Upload failed/skipped"

    fi

    # -------------------------------
    # GoFile
    # -------------------------------

    if [[ -n "${GOFILE_URL}" ]]; then

        MESSAGE="${MESSAGE}

🟢 GoFile
${GOFILE_URL}"

    else

        MESSAGE="${MESSAGE}

🔴 GoFile
Upload failed/skipped"

    fi

    # -------------------------------
    # SourceForge
    # -------------------------------

    if [[ -n "${SOURCEFORGE_URL}" ]]; then

        MESSAGE="${MESSAGE}

🟢 SourceForge
${SOURCEFORGE_URL}"

    else

        MESSAGE="${MESSAGE}

🔴 SourceForge
Upload failed/skipped"

    fi

    tg_send "$MESSAGE"
}

# ============================================================
# Telegram - Finished
# ============================================================

notify_finished() {

    local MINUTES="$1"

    tg_send "🏁 RisingOS build finished

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
# SourceForge Upload
# ============================================================

upload_sourceforge() {

    local FILE="$1"

    SOURCEFORGE_URL=""

    if [[ ! -f "$FILE" ]]; then
        fail "File not found: $FILE"
        return 1
    fi

    if [[ -z "${SOURCEFORGE_USERNAME:-}" ]]; then
        warn "SOURCEFORGE_USERNAME not set"
        return 1
    fi

    if [[ -z "${SOURCEFORGE_PROJECT:-}" ]]; then
        warn "SOURCEFORGE_PROJECT not set"
        return 1
    fi

    if ! command -v scp >/dev/null 2>&1; then
        fail "scp is missing"
        return 1
    fi

    section "SourceForge Upload"

    info "File: $(basename "$FILE")"
    info "Size: $(du -h "$FILE" | cut -f1)"
    info "Project: ${SOURCEFORGE_PROJECT}"

    local UPLOAD_PATH

    UPLOAD_PATH="${SOURCEFORGE_USERNAME}@frs.sourceforge.net:/home/frs/project/${SOURCEFORGE_PROJECT}"

    if scp \
        -o StrictHostKeyChecking=accept-new \
        "$FILE" \
        "$UPLOAD_PATH"
    then

        SOURCEFORGE_URL="https://sourceforge.net/projects/${SOURCEFORGE_PROJECT}/files/"

        ok "SourceForge upload complete"
        info "$SOURCEFORGE_URL"

    else

        fail "SourceForge upload failed"
        return 1

    fi
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

command -v scp >/dev/null || {
    fail "scp is missing"
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

section "Initializing RisingOS"

repo init \
    -u "${ROM_URL}" \
    -b "${ROM_BRANCH}" \
    --git-lfs

ok "RisingOS repository initialized"

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

    if /opt/crave/resync.sh; then

        ok "Crave resync complete"

    else

        warn "Crave resync returned an error"
        warn "Starting forced repo sync..."

        repo sync \
            -c \
            --force-sync \
            --force-remove-dirty \
            --no-tags \
            --no-clone-bundle \
            || {
                warn "Forced repo sync returned an error"
                warn "Continuing build anyway..."
            }

    fi

else

    warn "Crave resync not found"
    info "Using forced repo sync"

    repo sync \
        -c \
        --force-sync \
        --force-remove-dirty \
        --no-tags \
        --no-clone-bundle \
        || {
            warn "Repo sync returned an error"
            warn "Continuing build anyway..."
        }

fi

SYNC_END=$(date +%s)

ok "Source sync stage finished"
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

lunch riseup peridot user

ok "Target: riseup peridot user"

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

section "Building RisingOS"

BUILD_START=$(date +%s)

if rise b; then

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

    fail "RisingOS build failed"
    info "Build time: ${BUILD_MINUTES} minutes"

    notify_build_failed

    exit 1

fi

# ============================================================
# Build Successful
# ============================================================

ok "RisingOS build successful"
info "Build time: ${BUILD_MINUTES} minutes"

# ============================================================
# Find Artifacts
# ============================================================

section "Finding Build ZIP"

ARTIFACTS=()

# ------------------------------------------------------------
# ROM ZIP ONLY
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

# ============================================================
# Artifact Check
# ============================================================

if [[ ${#ARTIFACTS[@]} -eq 0 ]]; then

    warn "No ROM ZIP found"

    tg_send "⚠️ RisingOS build completed

Device: ${DEVICE}
Variant: ${BUILD_VARIANT}

❌ No ROM ZIP was found.
Upload skipped."

else

    ok "Found ${#ARTIFACTS[@]} ROM ZIP(s)"

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
        SOURCEFORGE_URL=""

        echo

        section "Uploading $(basename "$FILE")"

        info "ZIP only"

        # -------------------------------
        # PixelDrain
        # -------------------------------

        upload_pixeldrain "$FILE" || true

        # -------------------------------
        # GoFile
        # -------------------------------

        upload_gofile "$FILE" || true

        # -------------------------------
        # SourceForge
        # -------------------------------

        upload_sourceforge "$FILE" || true

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
echo "║                  RISINGOS COMPLETE                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
