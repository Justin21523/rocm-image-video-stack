#!/usr/bin/env bash
# ================================================================
# REQUIRES EXPLICIT APPROVAL BEFORE RUNNING
# Creates or validates ROCm conda environments
# NEVER modifies CUDA environments
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOGS_DIR/03_conda_envs_$TIMESTAMP.log"

mkdir -p "$LOGS_DIR"

log() { echo "$*" | tee -a "$LOG"; }

# ─── Parse flags ────────────────────────────────────────────────────
UPGRADE_PYTORCH=false
CREATE_MISSING=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --upgrade-pytorch) UPGRADE_PYTORCH=true; shift;;
        --no-create) CREATE_MISSING=false; shift;;
        *) echo "Unknown flag: $1"; exit 1;;
    esac
done

# ─── Safety: abort if a CUDA env is active ──────────────────────────
CUDA_ENVS=("comfyui" "kohya_ss" "ai_env" "audio_env" "data_env")
current_env="${CONDA_DEFAULT_ENV:-}"
for protected in "${CUDA_ENVS[@]}"; do
    if [[ "$current_env" == "$protected" ]]; then
        echo "ERROR: Active environment '$current_env' is a protected CUDA env. Aborting."
        exit 1
    fi
done

log "================================================================"
log "ROCm CONDA ENVIRONMENT SETUP"
log "Date: $(date)"
log "Upgrade PyTorch: $UPGRADE_PYTORCH"
log "================================================================"
log ""
log "Protected CUDA envs (will NOT be touched):"
for e in "${CUDA_ENVS[@]}"; do log "  - $e"; done
log ""

ROCM_ENVS=(
    "rocm-comfyui-r9700"
    "rocm-diffusers-r9700"
    "rocm-video-r9700"
    "rocm-lora-r9700"
    "rocm-llamacpp-r9700"
    "rocm-pytorch-r9700"
    "rocm-ltx23-r9700"
)

ROCM_INDEX_URL="https://download.pytorch.org/whl/rocm6.2"
UPGRADE_INDEX_URL="https://download.pytorch.org/whl/rocm7.2"
UPGRADE_VERSION="2.11.0+rocm7.2"

for env_name in "${ROCM_ENVS[@]}"; do
    log "--- $env_name ---"

    if conda info --envs 2>/dev/null | grep -q "^$env_name "; then
        log "  Status: EXISTS"

        # Check PyTorch version
        torch_ver=$(conda run -n "$env_name" python -c \
            "import torch; print(torch.__version__)" 2>/dev/null || echo "unknown")
        log "  PyTorch: $torch_ver"

        if [[ "$UPGRADE_PYTORCH" == "true" ]] && ! [[ "$torch_ver" == *"rocm7"* ]]; then
            log "  Upgrading PyTorch to $UPGRADE_VERSION..."
            conda run -n "$env_name" pip install \
                torch torchvision torchaudio \
                --index-url "$UPGRADE_INDEX_URL" \
                --force-reinstall \
                2>&1 | tee -a "$LOG" || log "  [ERROR] Upgrade failed for $env_name"
        fi
    else
        log "  Status: MISSING"
        if [[ "$CREATE_MISSING" == "true" ]] && [[ "$env_name" != "rocm-llamacpp-r9700" ]]; then
            log "  Creating env with Python 3.12..."
            conda create -n "$env_name" python=3.12 -y 2>&1 | tee -a "$LOG"
            log "  Installing ROCm PyTorch..."
            conda run -n "$env_name" pip install \
                torch torchvision torchaudio \
                --index-url "$ROCM_INDEX_URL" \
                2>&1 | tee -a "$LOG" || log "  [ERROR] PyTorch install failed"
        elif [[ "$env_name" == "rocm-llamacpp-r9700" ]]; then
            log "  SKIP: rocm-llamacpp-r9700 — managed by gpu-migration-r9700 project"
        else
            log "  SKIP: --no-create flag set"
        fi
    fi
    log ""
done

# ─── Summary ────────────────────────────────────────────────────────
log "=== Final Environment Summary ==="
conda env list 2>/dev/null | grep "rocm-" | tee -a "$LOG" || true
log ""

# Verify CUDA envs are untouched
log "=== CUDA Environment Safety Check ==="
for e in "${CUDA_ENVS[@]}"; do
    if conda info --envs 2>/dev/null | grep -q "^$e "; then
        log "  [SAFE] $e still exists"
    fi
done

log ""
log "================================================================"
log "Done. Next: scripts/04_setup_comfyui_rocm.sh (requires approval)"
log "================================================================"
