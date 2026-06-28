#!/usr/bin/env bash
# ================================================================
# REQUIRES EXPLICIT APPROVAL BEFORE RUNNING
# Creates symlinks from /mnt/c/ai_models/ into comfyui-rocm/models/
# Use --dry-run to preview without changes
# Never overwrites real model files
# ================================================================

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY RUN MODE] No changes will be made"
    echo ""
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOGS_DIR/05_symlinks_$TIMESTAMP.log"

mkdir -p "$LOGS_DIR"

log() { echo "$*" | tee -a "$LOG"; }

AI_MODELS=/mnt/c/ai_models
COMFYUI_MODELS=/mnt/c/ai_tools/comfyui-rocm/models

log "================================================================"
log "ComfyUI ROCm MODEL SYMLINKS"
log "Date: $(date)"
log "Dry run: $DRY_RUN"
log "================================================================"
log ""

# Check ComfyUI ROCm exists
if [[ ! -d /mnt/c/ai_tools/comfyui-rocm ]]; then
    log "ERROR: /mnt/c/ai_tools/comfyui-rocm not found."
    log "       Run scripts/04_setup_comfyui_rocm.sh first."
    exit 1
fi

# ─── Safe symlink creation function ─────────────────────────────────
make_symlink() {
    local source="$1"
    local target="$2"
    local label="$3"

    log "--- $label ---"
    log "  Source: $source"
    log "  Target: $target"

    # Check source exists
    if [[ ! -d "$source" ]] && [[ ! -f "$source" ]]; then
        log "  [SKIP] Source does not exist"
        return
    fi

    # Check target
    if [[ -L "$target" ]]; then
        existing=$(readlink -f "$target" 2>/dev/null || echo "broken")
        if [[ "$existing" == "$source" ]]; then
            log "  [OK] Symlink already correct"
            return
        else
            log "  [UPDATE] Existing symlink points to: $existing"
        fi
    elif [[ -d "$target" ]]; then
        item_count=$(find "$target" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
        if [[ "$item_count" -gt 0 ]]; then
            log "  [SKIP] Target is non-empty directory — manual inspection required"
            return
        else
            log "  [REPLACE] Empty directory will be removed and replaced with symlink"
            if [[ "$DRY_RUN" == "false" ]]; then
                rmdir "$target"
            fi
        fi
    elif [[ -f "$target" ]]; then
        log "  [SKIP] Target is a real file — will NOT overwrite"
        return
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "  [DRY RUN] Would create: ln -sfn $source $target"
    else
        ln -sfn "$source" "$target"
        # Verify
        if [[ -L "$target" ]]; then
            log "  [CREATED] Symlink created successfully"
        else
            log "  [ERROR] Failed to create symlink"
        fi
    fi
    log ""
}

# ─── Create symlinks ────────────────────────────────────────────────
make_symlink \
    "$AI_MODELS/diffusion/stable-diffusion/checkpoints" \
    "$COMFYUI_MODELS/checkpoints" \
    "Checkpoints"

make_symlink \
    "$AI_MODELS/diffusion/lora" \
    "$COMFYUI_MODELS/loras" \
    "LoRA"

make_symlink \
    "$AI_MODELS/diffusion/stable-diffusion/vae" \
    "$COMFYUI_MODELS/vae" \
    "VAE"

make_symlink \
    "$AI_MODELS/diffusion/clip" \
    "$COMFYUI_MODELS/clip" \
    "CLIP"

make_symlink \
    "$AI_MODELS/diffusion/text_encoders" \
    "$COMFYUI_MODELS/text_encoders" \
    "Text Encoders"

make_symlink \
    "$AI_MODELS/diffusion/controlnet" \
    "$COMFYUI_MODELS/controlnet" \
    "ControlNet"

make_symlink \
    "$AI_MODELS/diffusion/ipadapter" \
    "$COMFYUI_MODELS/ipadapter" \
    "IP-Adapter"

make_symlink \
    "$AI_MODELS/diffusion/embeddings" \
    "$COMFYUI_MODELS/embeddings" \
    "Embeddings"

make_symlink \
    "$AI_MODELS/diffusion/model_patches" \
    "$COMFYUI_MODELS/upscale_models" \
    "Upscale Models"

make_symlink \
    "$AI_MODELS/video" \
    "$COMFYUI_MODELS/video" \
    "Video Models (LTX-2.3, Wan2.1, AnimateDiff)"

make_symlink \
    "$AI_MODELS/vision" \
    "$COMFYUI_MODELS/clip_vision" \
    "Vision / CLIP Vision"

# ─── Verify all symlinks ─────────────────────────────────────────────
if [[ "$DRY_RUN" == "false" ]]; then
    log "=== Symlink Verification ==="
    ls -la "$COMFYUI_MODELS/" 2>/dev/null | tee -a "$LOG"

    log ""
    log "LTX-2.3 models accessible via symlink:"
    ls -lh "$COMFYUI_MODELS/video/ltx-2/" 2>/dev/null | head -10 | tee -a "$LOG" || \
        log "  [WARN] video/ltx-2/ not accessible yet"
fi

log ""
log "================================================================"
if [[ "$DRY_RUN" == "true" ]]; then
    log "Dry run complete. Run without --dry-run to apply changes."
else
    log "Symlinks created. Next: scripts/06_install_safe_comfyui_custom_nodes.sh"
fi
log "================================================================"
