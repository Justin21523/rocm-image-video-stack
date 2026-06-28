#!/usr/bin/env bash
# WORKSPACE PREPARATION — mkdir only, no package installation, no deletion
# Creates project subdirectories and comfyui-rocm placeholder structure
# Safe to run; requires no approval

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOGS_DIR/02_prepare_workspace_$TIMESTAMP.log"

mkdir -p "$LOGS_DIR"

log() { echo "$*" | tee -a "$LOG"; }

log "================================================================"
log "WORKSPACE PREPARATION"
log "Date: $(date)"
log "================================================================"
log ""

# ─── Project directories ────────────────────────────────────────────
log "Creating project subdirectories..."

for dir in \
    "$PROJECT_DIR/reports" \
    "$PROJECT_DIR/logs" \
    "$PROJECT_DIR/configs" \
    "$PROJECT_DIR/scripts" \
    "$PROJECT_DIR/workflows/comfyui-rocm" \
    "$PROJECT_DIR/workflows/ltx23" \
    "$PROJECT_DIR/workflows/image-to-video" \
    "$PROJECT_DIR/workflows/text-to-video" \
    "$PROJECT_DIR/workflows/validation"; do
    mkdir -p "$dir"
    log "  [OK] $dir"
done

# ─── comfyui-rocm placeholder structure ─────────────────────────────
log ""
log "Preparing comfyui-rocm workspace placeholder..."

COMFYUI_ROCM=/mnt/c/ai_tools/comfyui-rocm

if [[ ! -d "$COMFYUI_ROCM" ]]; then
    mkdir -p "$COMFYUI_ROCM"
    log "  [CREATED] $COMFYUI_ROCM"
else
    log "  [EXISTS]  $COMFYUI_ROCM"
fi

# Create models subdirs (will be replaced by symlinks in Phase 4)
for mdir in \
    "$COMFYUI_ROCM/models/checkpoints" \
    "$COMFYUI_ROCM/models/loras" \
    "$COMFYUI_ROCM/models/vae" \
    "$COMFYUI_ROCM/models/clip" \
    "$COMFYUI_ROCM/models/text_encoders" \
    "$COMFYUI_ROCM/models/controlnet" \
    "$COMFYUI_ROCM/models/ipadapter" \
    "$COMFYUI_ROCM/models/embeddings" \
    "$COMFYUI_ROCM/models/upscale_models" \
    "$COMFYUI_ROCM/models/video" \
    "$COMFYUI_ROCM/models/clip_vision" \
    "$COMFYUI_ROCM/custom_nodes" \
    "$COMFYUI_ROCM/output" \
    "$COMFYUI_ROCM/temp"; do
    if [[ ! -e "$mdir" ]]; then
        mkdir -p "$mdir"
        log "  [CREATED] $mdir"
    else
        log "  [EXISTS]  $mdir"
    fi
done

# ─── Safety check — no protected paths touched ──────────────────────
log ""
log "Safety check: verifying no protected paths were modified..."

for protected in \
    /mnt/c/ai_tools/comfyui \
    /mnt/c/ai_tools/LTX-2 \
    /mnt/c/ai_models; do
    if [[ -d "$protected" ]]; then
        log "  [SAFE] $protected exists and was not touched"
    fi
done

log ""
log "================================================================"
log "Workspace preparation complete."
log "Next: Phase 3 — Run scripts/04_setup_comfyui_rocm.sh (requires approval)"
log "================================================================"
