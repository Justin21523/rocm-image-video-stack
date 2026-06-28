#!/usr/bin/env bash
# ================================================================
# REQUIRES EXPLICIT APPROVAL BEFORE RUNNING
# Clones ComfyUI into /mnt/c/ai_tools/comfyui-rocm/
# Installs requirements with constraints.txt (ROCm torch locked)
# Does NOT install xformers
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOGS_DIR/04_comfyui_rocm_$TIMESTAMP.log"

mkdir -p "$LOGS_DIR"

log() { echo "$*" | tee -a "$LOG"; }

COMFYUI_ROCM=/mnt/c/ai_tools/comfyui-rocm
CONDA_ENV=rocm-comfyui-r9700
COMFYUI_REPO=https://github.com/comfyanonymous/ComfyUI.git
PORT=8189

# ─── Safety: protect CUDA ComfyUI ───────────────────────────────────
if [[ -d /mnt/c/ai_tools/comfyui/.git ]]; then
    cuda_remote=$(git -C /mnt/c/ai_tools/comfyui remote get-url origin 2>/dev/null || echo "")
    log "CUDA ComfyUI detected at /mnt/c/ai_tools/comfyui — will NOT be touched"
fi

# ─── Safety: abort if CUDA env active ───────────────────────────────
current_env="${CONDA_DEFAULT_ENV:-}"
for protected in comfyui kohya_ss ai_env audio_env data_env; do
    if [[ "$current_env" == "$protected" ]]; then
        echo "ERROR: Protected CUDA env '$current_env' is active. Aborting."
        exit 1
    fi
done

log "================================================================"
log "ComfyUI ROCm SETUP"
log "Date: $(date)"
log "Target: $COMFYUI_ROCM"
log "Conda env: $CONDA_ENV"
log "Port: $PORT"
log "================================================================"
log ""

# ─── Clone ComfyUI ──────────────────────────────────────────────────
log "Step 1: Clone ComfyUI..."
if [[ -d "$COMFYUI_ROCM/.git" ]]; then
    log "  [EXISTS] ComfyUI already cloned — pulling latest..."
    git -C "$COMFYUI_ROCM" pull 2>&1 | tee -a "$LOG"
else
    log "  Cloning from $COMFYUI_REPO..."
    # Remove placeholder if empty
    if [[ -d "$COMFYUI_ROCM" ]]; then
        count=$(ls -A "$COMFYUI_ROCM" | wc -l)
        if [[ "$count" -le 2 ]]; then
            rm -rf "$COMFYUI_ROCM"
        fi
    fi
    git clone "$COMFYUI_REPO" "$COMFYUI_ROCM" 2>&1 | tee -a "$LOG"
fi
log "  [OK]"
log ""

# ─── Create constraints.txt ─────────────────────────────────────────
log "Step 2: Create constraints.txt..."
TORCH_VER=$(conda run -n "$CONDA_ENV" python -c \
    "import torch; print(torch.__version__)" 2>/dev/null || echo "2.5.1+rocm6.2")
VISION_VER=$(conda run -n "$CONDA_ENV" python -c \
    "import torchvision; print(torchvision.__version__)" 2>/dev/null || echo "0.20.1+rocm6.2")
AUDIO_VER=$(conda run -n "$CONDA_ENV" python -c \
    "import torchaudio; print(torchaudio.__version__)" 2>/dev/null || echo "2.5.1+rocm6.2")

cat > "$COMFYUI_ROCM/constraints.txt" << EOF
torch==$TORCH_VER
torchvision==$VISION_VER
torchaudio==$AUDIO_VER
EOF
log "  constraints.txt created with:"
cat "$COMFYUI_ROCM/constraints.txt" | tee -a "$LOG"
log ""

# ─── Install requirements ───────────────────────────────────────────
log "Step 3: Install ComfyUI requirements..."
conda run -n "$CONDA_ENV" pip install \
    -r "$COMFYUI_ROCM/requirements.txt" \
    -c "$COMFYUI_ROCM/constraints.txt" \
    2>&1 | tee -a "$LOG"
log "  [OK]"
log ""

# ─── Verify torch still ROCm ────────────────────────────────────────
log "Step 4: Verify ROCm torch not replaced..."
actual_ver=$(conda run -n "$CONDA_ENV" python -c \
    "import torch; print(torch.__version__)" 2>/dev/null)
log "  Current torch: $actual_ver"
if echo "$actual_ver" | grep -qi "rocm\|hip"; then
    log "  [OK] ROCm torch confirmed"
else
    log "  [ERROR] torch version does not look like ROCm: $actual_ver"
    log "  Reinstalling ROCm torch..."
    conda run -n "$CONDA_ENV" pip install torch torchvision torchaudio \
        --index-url "https://download.pytorch.org/whl/rocm7.2" \
        --force-reinstall 2>&1 | tee -a "$LOG"
fi
log ""

# ─── Create launch script ───────────────────────────────────────────
log "Step 5: Create launch script..."
cat > "$COMFYUI_ROCM/start_comfyui_rocm.sh" << 'LAUNCH'
#!/usr/bin/env bash
# ComfyUI ROCm Launch Script — AMD Radeon AI PRO R9700
set -euo pipefail

export HIP_VISIBLE_DEVICES=0
export PYTORCH_HIP_ALLOC_CONF="garbage_collection_threshold:0.7,max_split_size_mb:128"
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
export LIBVA_DRIVER_NAME=radeonsi

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate rocm-comfyui-r9700

cd /mnt/c/ai_tools/comfyui-rocm

exec python main.py \
  --listen 0.0.0.0 \
  --port 8189 \
  --use-pytorch-cross-attention \
  --disable-xformers \
  --normalvram
LAUNCH
chmod +x "$COMFYUI_ROCM/start_comfyui_rocm.sh"
log "  Launch script: $COMFYUI_ROCM/start_comfyui_rocm.sh"
log ""

log "================================================================"
log "ComfyUI ROCm setup complete."
log ""
log "To start ComfyUI ROCm:"
log "  bash $COMFYUI_ROCM/start_comfyui_rocm.sh"
log "  Then open: http://localhost:$PORT"
log ""
log "Next: scripts/05_setup_comfyui_model_symlinks.sh (requires approval)"
log "================================================================"
