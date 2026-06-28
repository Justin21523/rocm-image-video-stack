#!/usr/bin/env bash
# ================================================================
# REQUIRES EXPLICIT APPROVAL BEFORE RUNNING
# Installs Green-tier custom nodes only (Phase 5)
# All pip installs use constraints.txt to lock ROCm torch
# ComfyUI-LTXVideo is deferred to Phase 6
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOGS_DIR/06_custom_nodes_$TIMESTAMP.log"

mkdir -p "$LOGS_DIR"

log() { echo "$*" | tee -a "$LOG"; }

COMFYUI_ROCM=/mnt/c/ai_tools/comfyui-rocm
CUSTOM_NODES="$COMFYUI_ROCM/custom_nodes"
CONSTRAINTS="$COMFYUI_ROCM/constraints.txt"
CONDA_ENV=rocm-comfyui-r9700

# ─── Pre-flight checks ───────────────────────────────────────────────
if [[ ! -d "$COMFYUI_ROCM/.git" ]]; then
    echo "ERROR: ComfyUI ROCm not installed at $COMFYUI_ROCM"
    echo "       Run scripts/04_setup_comfyui_rocm.sh first."
    exit 1
fi
if [[ ! -f "$CONSTRAINTS" ]]; then
    echo "ERROR: constraints.txt not found at $CONSTRAINTS"
    exit 1
fi

log "================================================================"
log "GREEN-TIER CUSTOM NODE INSTALLATION"
log "Date: $(date)"
log "Conda env: $CONDA_ENV"
log "================================================================"
log ""
log "Constraints file:"
cat "$CONSTRAINTS" | tee -a "$LOG"
log ""

install_node() {
    local name="$1"
    local repo="$2"
    local has_requirements="${3:-true}"

    log "--- Installing: $name ---"

    if [[ -d "$CUSTOM_NODES/$name" ]]; then
        log "  [EXISTS] Already installed — pulling latest..."
        git -C "$CUSTOM_NODES/$name" pull 2>&1 | tee -a "$LOG" || true
    else
        log "  Cloning $repo..."
        git clone "$repo" "$CUSTOM_NODES/$name" 2>&1 | tee -a "$LOG"
    fi

    if [[ "$has_requirements" == "true" ]] && [[ -f "$CUSTOM_NODES/$name/requirements.txt" ]]; then
        log "  Installing requirements with constraints..."
        conda run -n "$CONDA_ENV" pip install \
            -r "$CUSTOM_NODES/$name/requirements.txt" \
            -c "$CONSTRAINTS" \
            2>&1 | tee -a "$LOG" || log "  [WARN] Some requirements may have failed"
    else
        log "  No requirements.txt needed"
    fi

    # Verify ROCm torch not replaced
    actual_ver=$(conda run -n "$CONDA_ENV" python -c \
        "import torch; print(torch.__version__)" 2>/dev/null || echo "unknown")
    if echo "$actual_ver" | grep -qi "rocm\|hip"; then
        log "  [OK] ROCm torch confirmed: $actual_ver"
    else
        log "  [ERROR] ROCm torch was replaced: $actual_ver — reinstalling..."
        conda run -n "$CONDA_ENV" pip install torch torchvision torchaudio \
            --index-url "https://download.pytorch.org/whl/rocm7.2" \
            --force-reinstall 2>&1 | tee -a "$LOG"
    fi
    log ""
}

# ─── Phase 5: Green-tier nodes ──────────────────────────────────────
install_node "ComfyUI-Manager" \
    "https://github.com/ltdrdata/ComfyUI-Manager"

install_node "rgthree-comfy" \
    "https://github.com/rgthree/rgthree-comfy"

install_node "ComfyUI-Custom-Scripts" \
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts" \
    "false"

install_node "ComfyUI_essentials" \
    "https://github.com/cubiq/ComfyUI_essentials"

install_node "ComfyUI-VideoHelperSuite" \
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"

# ─── Final torch check ──────────────────────────────────────────────
log "=== Final torch version check ==="
conda run -n "$CONDA_ENV" python -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
print(f'HIP: {torch.version.hip}')
" 2>/dev/null | tee -a "$LOG"

log ""
log "================================================================"
log "Green-tier nodes installed."
log ""
log "DO NOT install ComfyUI-LTXVideo yet."
log "First validate ComfyUI startup and SDXL generation (Tests 2 and 3)."
log "Then run scripts/09_prepare_ltx23_models.sh to install LTX nodes."
log "================================================================"
