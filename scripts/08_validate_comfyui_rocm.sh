#!/usr/bin/env bash
# ComfyUI ROCm Import Validation — Test 2
# Runs ComfyUI import check without starting persistent server
# Use --server flag to start the actual server instead

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOGS_DIR/08_comfyui_validate_$TIMESTAMP.log"

mkdir -p "$LOGS_DIR"

log() { echo "$*" | tee -a "$LOG"; }

COMFYUI_ROCM=/mnt/c/ai_tools/comfyui-rocm
CONDA_ENV=rocm-comfyui-r9700
START_SERVER=false

if [[ "${1:-}" == "--server" ]]; then
    START_SERVER=true
fi

log "================================================================"
log "ComfyUI ROCm VALIDATION — Test 2"
log "Date: $(date)"
log "Mode: $(if $START_SERVER; then echo "server"; else echo "import-check"; fi)"
log "================================================================"
log ""

if [[ ! -d "$COMFYUI_ROCM/.git" ]]; then
    log "ERROR: ComfyUI not found at $COMFYUI_ROCM"
    log "       Run scripts/04_setup_comfyui_rocm.sh first."
    exit 1
fi

if [[ "$START_SERVER" == "true" ]]; then
    log "Starting ComfyUI ROCm server on port 8189..."
    log "Access at: http://localhost:8189"
    log ""

    export HIP_VISIBLE_DEVICES=0
    export PYTORCH_HIP_ALLOC_CONF="garbage_collection_threshold:0.7,max_split_size_mb:128"
    export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

    cd "$COMFYUI_ROCM"
    conda run -n "$CONDA_ENV" python main.py \
        --listen 0.0.0.0 \
        --port 8189 \
        --use-pytorch-cross-attention \
        --disable-xformers \
        --normalvram \
        2>&1 | tee -a "$LOG"
else
    log "Running ComfyUI import check..."
    log ""

    conda run -n "$CONDA_ENV" python - << PYEOF 2>&1 | tee -a "$LOG"
import sys
import os

sys.path.insert(0, '$COMFYUI_ROCM')
os.chdir('$COMFYUI_ROCM')

PASS = "[PASS]"
FAIL = "[FAIL]"
WARN = "[WARN]"

# Check ComfyUI imports
try:
    import comfy.model_management
    print(f"{PASS} comfy.model_management: imported")
except Exception as e:
    print(f"{FAIL} comfy.model_management: {e}")
    sys.exit(1)

try:
    import comfy.sd
    print(f"{PASS} comfy.sd: imported")
except Exception as e:
    print(f"{FAIL} comfy.sd: {e}")

try:
    device = comfy.model_management.get_torch_device()
    print(f"{PASS} torch device: {device}")
except Exception as e:
    print(f"{WARN} get_torch_device: {e}")

# Check custom nodes dir
import os
cn_dir = '$COMFYUI_ROCM/custom_nodes'
if os.path.isdir(cn_dir):
    nodes = [d for d in os.listdir(cn_dir) if os.path.isdir(os.path.join(cn_dir, d))]
    print(f"{PASS} custom_nodes dir: {len(nodes)} entries")
    for n in sorted(nodes):
        print(f"       - {n}")
else:
    print(f"{WARN} custom_nodes dir not found")

# Check models dir
models_dir = '$COMFYUI_ROCM/models'
if os.path.isdir(models_dir):
    entries = os.listdir(models_dir)
    symlinks = [e for e in entries if os.path.islink(os.path.join(models_dir, e))]
    dirs = [e for e in entries if os.path.isdir(os.path.join(models_dir, e))]
    print(f"{PASS} models dir: {len(dirs)} entries, {len(symlinks)} symlinks")
else:
    print(f"[INFO] models dir not yet populated (run script 05 to add symlinks)")

print("")
print("================================================================")
print("ComfyUI import check complete.")
print("To start server: bash $SCRIPT_DIR/08_validate_comfyui_rocm.sh --server")
print("================================================================")
PYEOF
fi

log ""
log "Log saved to: $LOG"
