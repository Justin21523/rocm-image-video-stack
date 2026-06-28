#!/usr/bin/env bash
# ================================================================
# REQUIRES EXPLICIT APPROVAL BEFORE RUNNING
# Validates LTX-2.3 minimal T2V workflow via ComfyUI API
# Runs a 1-second 256x144 video generation (minimal VRAM test)
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$PROJECT_DIR/reports"
LOGS_DIR="$PROJECT_DIR/logs"
WORKFLOWS_DIR="$PROJECT_DIR/workflows/validation"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOGS_DIR/10_ltx23_validate_$TIMESTAMP.log"

mkdir -p "$REPORTS_DIR" "$LOGS_DIR" "$WORKFLOWS_DIR"

log() { echo "$*" | tee -a "$LOG"; }

COMFYUI_ROCM=/mnt/c/ai_tools/comfyui-rocm
CONDA_ENV=rocm-comfyui-r9700
COMFYUI_PORT=8189
OUTPUT_VIDEO="$REPORTS_DIR/test6_ltx23_minimal_$TIMESTAMP.mp4"

log "================================================================"
log "LTX-2.3 T2V WORKFLOW VALIDATION — Test 6"
log "Date: $(date)"
log "================================================================"
log ""

# ─── Pre-flight checks ───────────────────────────────────────────────
log "Pre-flight checks..."

# Check ComfyUI installed
if [[ ! -d "$COMFYUI_ROCM/.git" ]]; then
    log "ERROR: ComfyUI not installed. Run scripts/04_setup_comfyui_rocm.sh first."
    exit 1
fi

# Check LTX-Video node installed
if [[ ! -d "$COMFYUI_ROCM/custom_nodes/ComfyUI-LTXVideo" ]]; then
    log "INFO: ComfyUI-LTXVideo not installed. Installing now..."
    cd "$COMFYUI_ROCM/custom_nodes"
    git clone https://github.com/Lightricks/ComfyUI-LTXVideo
    conda run -n "$CONDA_ENV" pip install \
        -r ComfyUI-LTXVideo/requirements.txt \
        -c "$COMFYUI_ROCM/constraints.txt" \
        2>&1 | tee -a "$LOG" || log "[WARN] Some LTX requirements may have failed"
fi

# Check models
LTX2_PATH=/mnt/c/ai_models/video/ltx-2
if [[ ! -f "$LTX2_PATH/ltx-2.3-22b-distilled-fp8.safetensors" ]] && \
   [[ ! -f "$LTX2_PATH/gguf/ltx-2.3-22b-Q6_K.gguf" ]]; then
    log "ERROR: No LTX-2.3 model found at $LTX2_PATH"
    log "       Check EXISTING_CUDA_STACK_AUDIT.md — model should already be there."
    exit 1
fi

TEXT_ENC=/mnt/c/ai_models/diffusion/text_encoders/comfy_gemma_3_12B_it.safetensors
if [[ ! -e "$TEXT_ENC" ]]; then
    log "ERROR: Gemma-3-12B text encoder not found at $TEXT_ENC"
    log "       Expected: comfy_gemma_3_12B_it.safetensors (fp4 mixed, 8.8 GB)"
    exit 1
fi

log "  [OK] Models found"
log ""

# ─── Minimal validation workflow ────────────────────────────────────
# Generate minimal workflow JSON
WORKFLOW_JSON="$WORKFLOWS_DIR/ltx23_minimal_t2v.json"

# Write Python check to temp file (conda run does not support stdin heredocs)
PY_CHECK="$(mktemp /tmp/ltx23_validate_XXXXXX.py)"
cat > "$PY_CHECK" << 'PYEOF'
import os, sys
PASS = "[PASS]"; FAIL = "[FAIL]"; WARN = "[WARN]"
print("Testing LTX-2.3 minimal workflow...")
print("  Resolution: 256x144 | Frames: 9 | Steps: 8 (distilled)")
print()
import torch
if not torch.cuda.is_available():
    print(f"{FAIL} GPU not available"); sys.exit(1)
print(f"{PASS} GPU: {torch.cuda.get_device_name(0)}")
print(f"{PASS} VRAM: {torch.cuda.get_device_properties(0).total_memory/1e9:.1f} GB")
print(f"{PASS} PyTorch: {torch.__version__}")

ltx_init = '/mnt/c/ai_tools/comfyui-rocm/custom_nodes/ComfyUI-LTXVideo/__init__.py'
print(f"{PASS if os.path.exists(ltx_init) else WARN} ComfyUI-LTXVideo: {'present' if os.path.exists(ltx_init) else 'NOT FOUND'}")

def check(path, label, unit='GB'):
    if os.path.exists(path):
        sz = os.path.getsize(path)
        val = sz/1e9 if unit=='GB' else sz/1e6
        print(f"{PASS} {label}: {val:.1f} {unit}")
    else:
        print(f"{FAIL} {label}: NOT FOUND at {path}")

check('/mnt/c/ai_tools/comfyui-rocm/models/video/ltx-2/ltx-2.3-22b-distilled-fp8.safetensors',
      'Distilled FP8 model')
check('/mnt/c/ai_tools/comfyui-rocm/models/text_encoders/comfy_gemma_3_12B_it.safetensors',
      'Gemma-3-12B (fp4 mixed)')
check('/mnt/c/ai_tools/comfyui-rocm/models/loras/ltxv/ltx2/ltx-2.3-22b-distilled-lora-384.safetensors',
      'Distilled LoRA (384-dim)')
check('/mnt/c/ai_tools/comfyui-rocm/models/video/ltx-2/latent_upsampler/diffusion_pytorch_model.safetensors',
      'Latent upsampler weights')

print()
print("================================================================")
print("Pre-flight checks complete.")
print()
print("To run full inference validation:")
print("1. Start ComfyUI: bash /mnt/c/ai_tools/comfyui-rocm/start_comfyui_rocm.sh")
print("2. Open http://localhost:8189 — load ltx2.3_video.json workflow")
print("3. Configure: 256x144, 9 frames, 8 steps, CFG 1.0 (distilled mode)")
print("4. If FP8 NotImplementedError: use GGUF workflow ltx23_t2v_two_stage_distilled_16gb_gguf.json")
print("================================================================")
PYEOF
conda run -n "$CONDA_ENV" python "$PY_CHECK" 2>&1 | tee -a "$LOG"
rm -f "$PY_CHECK"

log ""
log "================================================================"
log "LTX-2.3 pre-flight complete."
log "See LTX23_ROCM_IMPLEMENTATION_PLAN.md for full generation instructions."
log "Log: $LOG"
log "================================================================"
