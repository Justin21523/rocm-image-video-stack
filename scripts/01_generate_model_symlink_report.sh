#!/usr/bin/env bash
# READ-ONLY — Generates proposed model symlink map
# Does NOT create any symlinks — report only
# Safe to run at any time; requires no approval

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$PROJECT_DIR/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$REPORTS_DIR/symlink_report_$TIMESTAMP.txt"

mkdir -p "$REPORTS_DIR"

log() { echo "$*" | tee -a "$REPORT"; }

AI_MODELS=/mnt/c/ai_models
COMFYUI_MODELS=/mnt/c/ai_tools/comfyui-rocm/models

log "================================================================"
log "MODEL SYMLINK REPORT — READ ONLY"
log "Date: $(date)"
log "Source: $AI_MODELS"
log "Target: $COMFYUI_MODELS"
log "================================================================"
log ""
log "NOTE: These are proposed symlinks. No symlinks are created here."
log "      Run scripts/05_setup_comfyui_model_symlinks.sh (with approval) to apply."
log ""

check_symlink() {
    local source="$1"
    local target="$2"
    local name="$3"

    log "--- $name ---"

    if [[ -d "$source" || -f "$source" ]]; then
        source_size=$(du -sh "$source" 2>/dev/null | cut -f1 || echo "N/A")
        log "  Source:   $source  [EXISTS, $source_size]"
    else
        log "  Source:   $source  [NOT FOUND — symlink would be broken]"
    fi

    if [[ -L "$target" ]]; then
        existing=$(readlink -f "$target" 2>/dev/null || echo "broken")
        log "  Target:   $target  [ALREADY A SYMLINK -> $existing]"
        if [[ "$existing" == "$source" ]]; then
            log "  Status:   ALREADY CORRECT — no action needed"
        else
            log "  Status:   POINTS TO WRONG TARGET — update needed"
        fi
    elif [[ -d "$target" ]]; then
        item_count=$(ls -1 "$target" 2>/dev/null | wc -l)
        if [[ "$item_count" -eq 0 ]]; then
            log "  Target:   $target  [EMPTY DIR — safe to replace with symlink]"
            log "  Status:   REPLACE WITH SYMLINK"
            log "  Command:  rmdir '$target' && ln -s '$source' '$target'"
        else
            log "  Target:   $target  [NON-EMPTY DIR — DO NOT OVERWRITE]"
            log "  Status:   SKIP — manual inspection required"
        fi
    elif [[ -f "$target" ]]; then
        log "  Target:   $target  [REAL FILE — DO NOT OVERWRITE]"
        log "  Status:   SKIP — file exists, cannot create symlink"
    else
        log "  Target:   $target  [DOES NOT EXIST — safe to create]"
        log "  Status:   CREATE SYMLINK"
        log "  Command:  ln -sfn '$source' '$target'"
    fi
    log ""
}

log "=== Proposed Symlink Map ==="
log ""

check_symlink \
    "$AI_MODELS/diffusion/stable-diffusion/checkpoints" \
    "$COMFYUI_MODELS/checkpoints" \
    "Checkpoints (SDXL, SD 1.5)"

check_symlink \
    "$AI_MODELS/diffusion/lora" \
    "$COMFYUI_MODELS/loras" \
    "LoRA"

check_symlink \
    "$AI_MODELS/diffusion/stable-diffusion/vae" \
    "$COMFYUI_MODELS/vae" \
    "VAE"

check_symlink \
    "$AI_MODELS/diffusion/clip" \
    "$COMFYUI_MODELS/clip" \
    "CLIP"

check_symlink \
    "$AI_MODELS/diffusion/text_encoders" \
    "$COMFYUI_MODELS/text_encoders" \
    "Text Encoders (incl. Gemma-3-12B after download)"

check_symlink \
    "$AI_MODELS/diffusion/controlnet" \
    "$COMFYUI_MODELS/controlnet" \
    "ControlNet"

check_symlink \
    "$AI_MODELS/diffusion/ipadapter" \
    "$COMFYUI_MODELS/ipadapter" \
    "IP-Adapter"

check_symlink \
    "$AI_MODELS/diffusion/embeddings" \
    "$COMFYUI_MODELS/embeddings" \
    "Embeddings / Textual Inversions"

check_symlink \
    "$AI_MODELS/diffusion/model_patches" \
    "$COMFYUI_MODELS/upscale_models" \
    "Upscale Models"

check_symlink \
    "$AI_MODELS/video" \
    "$COMFYUI_MODELS/video" \
    "Video Models (LTX-2.3, Wan2.1, AnimateDiff, etc.)"

check_symlink \
    "$AI_MODELS/vision" \
    "$COMFYUI_MODELS/clip_vision" \
    "Vision / CLIP Vision"

# ─── LTX-2.3 Specific Check ─────────────────────────────────────────
log "=== LTX-2.3 Specific Model Inventory ==="
ltx_path="$AI_MODELS/video/ltx-2"
if [[ -d "$ltx_path" ]]; then
    log "Directory: $ltx_path"
    ls -lh "$ltx_path" 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT"

    log ""
    log "Required files check:"
    for f in \
        "ltx-2.3-22b-dev-fp8.safetensors" \
        "ltx-2.3-22b-distilled-fp8.safetensors"; do
        fpath="$ltx_path/$f"
        if [[ -f "$fpath" ]]; then
            fsize=$(du -sh "$fpath" 2>/dev/null | cut -f1)
            log "  [OK]      $f ($fsize)"
        else
            log "  [MISSING] $f"
        fi
    done
    for d in "audio_vae" "connectors" "latent_upsampler"; do
        dpath="$ltx_path/$d"
        if [[ -d "$dpath" ]]; then
            count=$(ls -1 "$dpath" 2>/dev/null | wc -l)
            log "  [OK]      $d/ ($count files)"
        else
            log "  [MISSING] $d/"
        fi
    done
else
    log "  [NOT FOUND] $ltx_path"
fi

log ""
log "Gemma-3-12B text encoder check:"
gemma_path="$AI_MODELS/diffusion/text_encoders/gemma-3-12b/gemma_3_12B_it.safetensors"
if [[ -f "$gemma_path" ]]; then
    gsize=$(du -sh "$gemma_path" 2>/dev/null | cut -f1)
    log "  [OK]      Gemma-3-12B found ($gsize)"
else
    log "  [MISSING] Gemma-3-12B text encoder — REQUIRED before first LTX generation"
    log "            Download ~24.4 GB from: Comfy-Org/ltx-2 on Hugging Face"
fi

log ""
log "================================================================"
log "Report complete. No symlinks were created."
log "To apply symlinks: bash scripts/05_setup_comfyui_model_symlinks.sh"
log "Report saved to: $REPORT"
log "================================================================"

echo ""
echo "Report saved to: $REPORT"
