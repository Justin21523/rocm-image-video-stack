#!/usr/bin/env bash
# READ-ONLY AUDIT — No modifications to any existing path
# Inspects the CUDA AI stack and saves a report
# Safe to run at any time; requires no approval

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$PROJECT_DIR/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$REPORTS_DIR/audit_$TIMESTAMP.txt"

mkdir -p "$REPORTS_DIR"

log() { echo "$*" | tee -a "$REPORT"; }

log "================================================================"
log "EXISTING CUDA STACK AUDIT — READ ONLY"
log "Date: $(date)"
log "GPU: AMD Radeon AI PRO R9700 (gfx1201)"
log "================================================================"
log ""

# ─── 1. AI Tools ────────────────────────────────────────────────────
log "=== /mnt/c/ai_tools/ ==="
if [[ -d /mnt/c/ai_tools ]]; then
    log "Top-level directories:"
    ls -1 /mnt/c/ai_tools/ 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT"
else
    log "  [NOT FOUND] /mnt/c/ai_tools"
fi
log ""

# ─── 2. ComfyUI Installs ────────────────────────────────────────────
log "=== ComfyUI Installations ==="
for dir in comfyui Comfy-LTX-Desktop ComfyUI-RookieUI comfyui-rocm; do
    path="/mnt/c/ai_tools/$dir"
    if [[ -d "$path" ]]; then
        size=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "N/A")
        remote=""
        if [[ -d "$path/.git" ]]; then
            remote=$(git -C "$path" remote get-url origin 2>/dev/null || echo "no remote")
        fi
        log "  [FOUND] $dir  size=$size  remote=$remote"
        # List custom_nodes if present
        if [[ -d "$path/custom_nodes" ]]; then
            count=$(ls -1 "$path/custom_nodes" 2>/dev/null | wc -l)
            log "    custom_nodes: $count entries"
        fi
    else
        log "  [NOT FOUND] $dir"
    fi
done
log ""

# ─── 3. Custom Nodes ────────────────────────────────────────────────
log "=== Custom Nodes (/mnt/c/ai_tools/comfyui/custom_nodes/) ==="
if [[ -d /mnt/c/ai_tools/comfyui/custom_nodes ]]; then
    ls -1 /mnt/c/ai_tools/comfyui/custom_nodes/ 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT"
else
    log "  [NOT FOUND]"
fi
log ""

# ─── 4. LTX and Video Tools ─────────────────────────────────────────
log "=== Video AI Tools ==="
for dir in LTX-2 LTX-Video LTX-Video-Trainer Wan2.1 AnimateDiff; do
    path="/mnt/c/ai_tools/$dir"
    if [[ -d "$path" ]]; then
        size=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "N/A")
        log "  [FOUND] $dir  size=$size"
    else
        log "  [NOT FOUND] $dir"
    fi
done
log ""

# ─── 5. Models ──────────────────────────────────────────────────────
log "=== /mnt/c/ai_models/ (top-level structure) ==="
if [[ -d /mnt/c/ai_models ]]; then
    du -sh /mnt/c/ai_models/*/ 2>/dev/null | sort -hr | sed 's/^/  /' | tee -a "$REPORT" || true
else
    log "  [NOT FOUND] /mnt/c/ai_models"
fi
log ""

# ─── 6. LTX-2.3 Models ──────────────────────────────────────────────
log "=== LTX-2.3 Models (/mnt/c/ai_models/video/ltx-2/) ==="
if [[ -d /mnt/c/ai_models/video/ltx-2 ]]; then
    ls -lh /mnt/c/ai_models/video/ltx-2/ 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT"
    total=$(du -sh /mnt/c/ai_models/video/ltx-2/ 2>/dev/null | cut -f1 || echo "N/A")
    log "  Total: $total"
else
    log "  [NOT FOUND] /mnt/c/ai_models/video/ltx-2"
fi
log ""

# ─── 7. Existing Symlinks in ai_models ──────────────────────────────
log "=== Existing Symlinks in /mnt/c/ai_models/ ==="
find /mnt/c/ai_models -maxdepth 4 -type l 2>/dev/null | head -20 | while read -r link; do
    target=$(readlink -f "$link" 2>/dev/null || echo "broken")
    log "  $link -> $target"
done || true
log ""

# ─── 8. Conda Environments ──────────────────────────────────────────
log "=== Conda Environments ==="
if command -v conda &>/dev/null; then
    conda env list 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT"
else
    log "  [conda not found in PATH]"
fi
log ""

# ─── 9. ROCm Status ─────────────────────────────────────────────────
log "=== ROCm Installation ==="
if [[ -d /opt/rocm ]]; then
    rocm_ver=$(cat /opt/rocm/.info/version 2>/dev/null || cat /opt/rocm/VERSION 2>/dev/null || echo "unknown")
    log "  ROCm version: $rocm_ver"
    log "  Path: /opt/rocm"
else
    log "  [NOT FOUND] /opt/rocm"
fi
log ""

# ─── 10. PyTorch ROCm Check ─────────────────────────────────────────
log "=== PyTorch ROCm Check (rocm-comfyui-r9700) ==="
if conda info --envs 2>/dev/null | grep -q rocm-comfyui-r9700; then
    conda run -n rocm-comfyui-r9700 python -c "
import torch
print(f'  PyTorch: {torch.__version__}')
print(f'  CUDA available (ROCm): {torch.cuda.is_available()}')
print(f'  HIP version: {torch.version.hip}')
if torch.cuda.is_available():
    print(f'  GPU: {torch.cuda.get_device_name(0)}')
" 2>/dev/null | tee -a "$REPORT" || log "  [ERROR] Failed to check PyTorch"
else
    log "  [NOT FOUND] conda env rocm-comfyui-r9700"
fi
log ""

# ─── 11. llama.cpp-rocm Status ──────────────────────────────────────
log "=== llama.cpp-rocm Status ==="
if [[ -f /mnt/c/ai_tools/llama.cpp-rocm/build/bin/llama-server ]]; then
    log "  [FOUND] llama-server binary"
    if tmux list-sessions 2>/dev/null | grep -q llamacpp-rocm; then
        log "  [RUNNING] tmux session: llamacpp-rocm"
    else
        log "  [STOPPED] tmux session not found"
    fi
else
    log "  [NOT FOUND] llama.cpp-rocm build"
fi
log ""

# ─── 12. Workflow Files ──────────────────────────────────────────────
log "=== Existing CUDA ComfyUI Workflows ==="
for wf_dir in \
    "/mnt/c/ai_tools/comfyui/user/default/workflows" \
    "/mnt/c/ai_tools/comfyui/workflows"; do
    if [[ -d "$wf_dir" ]]; then
        count=$(find "$wf_dir" -name "*.json" 2>/dev/null | wc -l)
        log "  $wf_dir: $count workflow files"
    fi
done
log ""

# ─── 13. rocm-image-video-stack Status ──────────────────────────────
log "=== rocm-image-video-stack Project ==="
if [[ -d /mnt/c/ai_projects/rocm-image-video-stack ]]; then
    count=$(find /mnt/c/ai_projects/rocm-image-video-stack -type f 2>/dev/null | wc -l)
    log "  [EXISTS] $count files"
    ls /mnt/c/ai_projects/rocm-image-video-stack/ 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT"
else
    log "  [NOT FOUND]"
fi
log ""

log "================================================================"
log "Audit complete. Report saved to: $REPORT"
log "================================================================"

echo ""
echo "Report saved to: $REPORT"
