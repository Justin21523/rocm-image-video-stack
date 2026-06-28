#!/usr/bin/env bash
# Stop ROCm services (ComfyUI ROCm tmux session)
# Does NOT stop llamacpp-rocm — that is managed separately
# Safe to run; idempotent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOGS_DIR/99_stop_services_$TIMESTAMP.log"

mkdir -p "$LOGS_DIR"

log() { echo "$*" | tee -a "$LOG"; }

log "================================================================"
log "STOP ROCm SERVICES"
log "Date: $(date)"
log "================================================================"
log ""

# ─── Stop comfyui-rocm tmux session ─────────────────────────────────
if tmux has-session -t comfyui-rocm 2>/dev/null; then
    log "Stopping tmux session: comfyui-rocm..."
    tmux send-keys -t comfyui-rocm C-c 2>/dev/null || true
    sleep 2
    tmux kill-session -t comfyui-rocm 2>/dev/null || true
    log "  [STOPPED] comfyui-rocm"
else
    log "  [NOT RUNNING] comfyui-rocm tmux session"
fi

# ─── Explicitly do NOT stop llamacpp-rocm ────────────────────────────
if tmux has-session -t llamacpp-rocm 2>/dev/null; then
    log "  [PRESERVED] llamacpp-rocm — NOT stopped (managed by gpu-migration-r9700 project)"
else
    log "  [NOT RUNNING] llamacpp-rocm (no action)"
fi

# ─── List remaining active sessions ─────────────────────────────────
log ""
log "Remaining tmux sessions:"
tmux list-sessions 2>/dev/null | sed 's/^/  /' | tee -a "$LOG" || log "  (none)"

log ""
log "================================================================"
log "Services stopped. CUDA services (if any) are unaffected."
log "================================================================"
