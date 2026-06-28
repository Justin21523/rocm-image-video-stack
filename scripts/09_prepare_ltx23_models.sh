#!/usr/bin/env bash
# LTX-2.3 Model Preparation
# Default mode: --audit-only (safe, read-only)
# Download mode: --download (REQUIRES EXPLICIT APPROVAL)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$PROJECT_DIR/reports"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$REPORTS_DIR" "$LOGS_DIR"

MODE="audit"
if [[ "${1:-}" == "--download" ]]; then
    MODE="download"
    echo "================================================================"
    echo "DOWNLOAD MODE — This will download large model files"
    echo "Gemma-3-12B: ~24.4 GB"
    echo "Distilled LoRA: ~384 MB"
    echo "================================================================"
    echo ""
fi

REPORT="$REPORTS_DIR/ltx23_model_audit_$TIMESTAMP.txt"
LOG="$LOGS_DIR/09_ltx23_models_$TIMESTAMP.log"

log() { echo "$*" | tee -a "$REPORT" | tee -a "$LOG"; }

AI_MODELS=/mnt/c/ai_models
LTX2_PATH="$AI_MODELS/video/ltx-2"
TEXT_ENC_PATH="$AI_MODELS/diffusion/text_encoders"
CONDA_ENV=rocm-comfyui-r9700

log "================================================================"
log "LTX-2.3 MODEL PREPARATION"
log "Date: $(date)"
log "Mode: $MODE"
log "================================================================"
log ""

# ─── Audit: check what exists ───────────────────────────────────────
log "=== Model Inventory ==="
log ""

check_model() {
    local path="$1"
    local label="$2"
    local required="${3:-optional}"
    local size_expected="${4:-}"

    if [[ -f "$path" ]]; then
        actual_size=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "N/A")
        log "  [OK]      [$required] $label ($actual_size)"
    elif [[ -d "$path" ]]; then
        count=$(ls -1 "$path" 2>/dev/null | wc -l)
        log "  [OK-DIR]  [$required] $label/ ($count files)"
    else
        if [[ "$required" == "required" ]]; then
            log "  [MISSING] [$required] $label — MUST DOWNLOAD BEFORE GENERATION"
        else
            log "  [MISSING] [$required] $label"
        fi
        if [[ -n "$size_expected" ]]; then
            log "            Expected size: $size_expected"
        fi
    fi
}

check_model \
    "$LTX2_PATH/ltx-2.3-22b-dev-fp8.safetensors" \
    "LTX-2.3 Dev FP8" "required" "~29 GB"

check_model \
    "$LTX2_PATH/ltx-2.3-22b-distilled-fp8.safetensors" \
    "LTX-2.3 Distilled FP8" "required" "~29.5 GB"

check_model \
    "$LTX2_PATH/audio_vae" \
    "Audio VAE directory" "required"

check_model \
    "$LTX2_PATH/connectors" \
    "Connectors directory" "required"

check_model \
    "$LTX2_PATH/latent_upsampler" \
    "Latent Upsampler directory" "required"

log ""
log "--- Text Encoder (REQUIRED — separate download) ---"
# Accessible as comfy_gemma_3_12B_it.safetensors (symlink → fp4_mixed, 8.8 GB)
check_model \
    "$TEXT_ENC_PATH/comfy_gemma_3_12B_it.safetensors" \
    "Gemma-3-12B text encoder (comfy_gemma_3_12B_it.safetensors)" "required" "~8.8 GB (fp4 mixed)"

log ""
log "--- Supplementary Models ---"
# Check if distilled LoRA exists in any known location
if [[ -f "$LTX2_PATH/ltx-2.3-22b-distilled-lora-384.safetensors" ]]; then
    check_model "$LTX2_PATH/ltx-2.3-22b-distilled-lora-384.safetensors" \
        "Distilled LoRA" "recommended"
elif [[ -f "$AI_MODELS/diffusion/lora/ltxv/ltx2/ltx-2.3-22b-distilled-lora-384.safetensors" ]]; then
    log "  [OK-SYMLINK] Distilled LoRA (in lora/ltxv/ltx2/ — may already be symlinked)"
else
    check_model "$LTX2_PATH/ltx-2.3-22b-distilled-lora-384.safetensors" \
        "Distilled LoRA" "recommended" "~384 MB"
fi

check_model \
    "$LTX2_PATH/ltx-2.3-spatial-upscaler-x2-1.1.safetensors" \
    "Spatial Upscaler x2 v1.1" "optional" "~1 GB"

check_model \
    "$LTX2_PATH/gguf/ltx-2.3-22b-Q6_K.gguf" \
    "GGUF Q6_K fallback" "fallback" "~12 GB"

log ""

# ─── Download mode ──────────────────────────────────────────────────
if [[ "$MODE" == "download" ]]; then
    log "=== Download Phase ==="
    log ""

    # Verify huggingface-cli available
    if ! conda run -n "$CONDA_ENV" huggingface-cli --version &>/dev/null; then
        log "Installing huggingface-hub..."
        conda run -n "$CONDA_ENV" pip install huggingface-hub[cli] 2>&1 | tee -a "$LOG"
    fi

    # Gemma-3-12B (already present as fp4 mixed symlink — skip download)
    if [[ -e "$TEXT_ENC_PATH/comfy_gemma_3_12B_it.safetensors" ]]; then
        log "  [SKIP] Gemma-3-12B already accessible: $TEXT_ENC_PATH/comfy_gemma_3_12B_it.safetensors"
    else
        log "  [WARN] comfy_gemma_3_12B_it.safetensors not found — check text_encoders symlink"
        log "         Expected at: $TEXT_ENC_PATH/comfy_gemma_3_12B_it.safetensors"
    fi

    # Download distilled LoRA (if not found)
    distilled_path="$LTX2_PATH/ltx-2.3-22b-distilled-lora-384.safetensors"
    if [[ ! -f "$distilled_path" ]]; then
        log "Downloading distilled LoRA (~384 MB)..."
        conda run -n "$CONDA_ENV" huggingface-cli download \
            Lightricks/LTX-2.3 \
            ltx-2.3-22b-distilled-lora-384.safetensors \
            --local-dir "$LTX2_PATH/" \
            2>&1 | tee -a "$LOG"
        log "  [DONE] Distilled LoRA downloaded"
    else
        log "  [SKIP] Distilled LoRA already exists"
    fi
fi

log ""
log "================================================================"
log "LTX-2.3 model audit complete."
if [[ "$MODE" == "audit" ]]; then
    log ""
    log "To download missing models (requires approval):"
    log "  bash $SCRIPT_DIR/09_prepare_ltx23_models.sh --download"
fi
log ""
log "Report saved to: $REPORT"
log "================================================================"
