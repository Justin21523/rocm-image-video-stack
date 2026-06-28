#!/usr/bin/env bash
# Post-upgrade verification: confirms old PyTorch removed, new version active
# Safe to run multiple times (read-only checks + cleanup of stale dist-info only)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOGS_DIR/03b_verify_pytorch_$TIMESTAMP.log"

mkdir -p "$LOGS_DIR"
log() { echo "$*" | tee -a "$LOG"; }

ROCM_ENVS=(
    "rocm-comfyui-r9700"
    "rocm-diffusers-r9700"
    "rocm-video-r9700"
    "rocm-lora-r9700"
    "rocm-pytorch-r9700"
    "rocm-ltx23-r9700"
)
EXPECTED_VER="2.11.0"
OLD_VER="2.5.1"

log "================================================================"
log "PyTorch Upgrade Verification"
log "Expected: $EXPECTED_VER+rocm7.2   Old: $OLD_VER+rocm6.2"
log "Date: $(date)"
log "================================================================"
log ""

PASS_COUNT=0
FAIL_COUNT=0

for env_name in "${ROCM_ENVS[@]}"; do
    log "--- $env_name ---"

    if ! conda info --envs 2>/dev/null | grep -q "^$env_name "; then
        log "  [SKIP] env not found"
        continue
    fi

    ENV_PATH=$(conda info --envs 2>/dev/null | grep "^$env_name " | awk '{print $NF}')

    # ── Check active torch version ────────────────────────────────
    torch_ver=$(conda run -n "$env_name" python -c \
        "import torch; print(torch.__version__)" 2>/dev/null || echo "IMPORT_ERROR")
    log "  Active torch: $torch_ver"

    if [[ "$torch_ver" == *"$EXPECTED_VER"* ]] && [[ "$torch_ver" == *"rocm7"* ]]; then
        log "  [PASS] New version confirmed"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        log "  [FAIL] Expected $EXPECTED_VER+rocm7.2, got: $torch_ver"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    # ── Check old dist-info is gone ───────────────────────────────
    OLD_DISTINFO="$ENV_PATH/lib/python3.12/site-packages/torch-${OLD_VER}+rocm6.2.dist-info"
    if [[ -d "$OLD_DISTINFO" ]]; then
        log "  [WARN] Old dist-info still present: $OLD_DISTINFO"
        log "         Removing stale metadata..."
        rm -rf "$OLD_DISTINFO"
        log "         [CLEANED]"
    else
        log "  [OK]   Old dist-info not present (correctly removed)"
    fi

    # ── Check for any other rocm6.2 dist-info files ───────────────
    OLD_FILES=$(find "$ENV_PATH/lib" -maxdepth 3 -name "*rocm6.2*" -type d 2>/dev/null)
    if [[ -n "$OLD_FILES" ]]; then
        log "  [WARN] Other rocm6.2 artifacts found:"
        echo "$OLD_FILES" | while read f; do
            log "         $f"
            rm -rf "$f"
            log "         [CLEANED]"
        done
    else
        log "  [OK]   No rocm6.2 artifacts remaining"
    fi

    # ── Show env disk size ────────────────────────────────────────
    env_size=$(du -sh "$ENV_PATH" 2>/dev/null | awk '{print $1}')
    log "  Env size: $env_size"
    log ""
done

log "================================================================"
log "Summary: $PASS_COUNT PASSED, $FAIL_COUNT FAILED"
if [[ $FAIL_COUNT -eq 0 ]]; then
    log "All ROCm environments successfully upgraded to $EXPECTED_VER+rocm7.2"
else
    log "WARNING: $FAIL_COUNT environment(s) may need manual attention"
    log "Re-run: bash scripts/03_create_rocm_image_video_conda_envs.sh --upgrade-pytorch"
fi
log "Log: $LOG"
log "================================================================"
