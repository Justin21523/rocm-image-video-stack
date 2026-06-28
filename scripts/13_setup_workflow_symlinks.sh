#!/usr/bin/env bash
# ================================================================
# REQUIRES EXPLICIT APPROVAL BEFORE RUNNING
# Creates workflow symlinks in comfyui-rocm pointing to the same
# targets as CUDA ComfyUI (resolves existing symlinks directly).
# Pattern mirrors model symlinks: per-item symlinks to real sources.
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOGS_DIR/13_workflow_symlinks_$TIMESTAMP.log"

mkdir -p "$LOGS_DIR"

log() { echo "$*" | tee -a "$LOG"; }

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true && log "[DRY-RUN mode]"

SRC_DIR="/mnt/c/ai_tools/comfyui/user/default/workflows"
DST_DIR="/mnt/c/ai_tools/comfyui-rocm/user/default/workflows"

# ─── Safety: source must exist ──────────────────────────────────────
if [[ ! -d "$SRC_DIR" ]]; then
    echo "ERROR: CUDA ComfyUI workflows not found at $SRC_DIR"
    exit 1
fi

log "================================================================"
log "WORKFLOW SYMLINK SETUP"
log "Date: $(date)"
log "Source:  $SRC_DIR"
log "Target:  $DST_DIR"
log "================================================================"
log ""

mkdir -p "$DST_DIR"

LINKED=0
SKIPPED=0
ERRORS=0

make_symlink() {
    local name="$1"
    local target="$2"
    local dst="$DST_DIR/$name"

    if [[ -L "$dst" ]]; then
        current="$(readlink "$dst")"
        if [[ "$current" == "$target" ]]; then
            log "  [OK]   $name"
            SKIPPED=$((SKIPPED + 1))
        else
            log "  [UPDATE] $name"
            log "           old -> $current"
            log "           new -> $target"
            if [[ "$DRY_RUN" == "false" ]]; then
                ln -sf "$target" "$dst"
            fi
            LINKED=$((LINKED + 1))
        fi
    elif [[ -e "$dst" ]] && [[ ! -L "$dst" ]]; then
        log "  [WARN]  $name is a real file/dir — skipping to avoid overwrite"
        SKIPPED=$((SKIPPED + 1))
    else
        log "  [LINK]  $name -> $target"
        if [[ "$DRY_RUN" == "false" ]]; then
            ln -s "$target" "$dst" || { log "  [ERROR] Failed: $name"; ERRORS=$((ERRORS + 1)); return; }
        fi
        LINKED=$((LINKED + 1))
    fi
}

# ─── Process all entries in CUDA workflows dir ──────────────────────
while IFS= read -r -d '' src_entry; do
    name="$(basename "$src_entry")"

    # Skip hidden files/dirs (e.g. .llm_provider/)
    [[ "$name" == .* ]] && continue

    if [[ -L "$src_entry" ]]; then
        # Resolve the symlink target (absolute path)
        target="$(readlink -f "$src_entry" 2>/dev/null || readlink "$src_entry")"
        make_symlink "$name" "$target"
    elif [[ -f "$src_entry" ]]; then
        # Real file — symlink to it directly
        make_symlink "$name" "$src_entry"
    fi
    # Skip real directories (shouldn't exist, but guard against it)

done < <(find "$SRC_DIR" -maxdepth 1 -mindepth 1 \( -name "*.json" -o -type l \) -print0 | sort -z)

# ─── Summary ─────────────────────────────────────────────────────────
log ""
log "================================================================"
log "Workflow symlinks: $LINKED created/updated, $SKIPPED already correct, $ERRORS errors"
log "Log: $LOG"
if [[ "$DRY_RUN" == "false" ]]; then
    log ""
    log "Verify:"
    log "  ls -la $DST_DIR"
fi
log "================================================================"

if [[ $ERRORS -gt 0 ]]; then
    exit 1
fi
