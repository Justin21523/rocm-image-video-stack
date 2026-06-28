#!/usr/bin/env bash
# ================================================================
# REQUIRES EXPLICIT APPROVAL BEFORE RUNNING
# Installs video processing tools in rocm-video-r9700 env
# FFmpeg (conda-forge), OpenCV, imageio, moviepy, av
# Does NOT require ROCm-specific compilation
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$LOGS_DIR/11_video_tools_$TIMESTAMP.log"

mkdir -p "$LOGS_DIR"

log() { echo "$*" | tee -a "$LOG"; }

CONDA_ENV=rocm-video-r9700

log "================================================================"
log "VIDEO TOOLS SETUP — $CONDA_ENV"
log "Date: $(date)"
log "================================================================"
log ""

# ─── Safety: verify not in CUDA env ─────────────────────────────────
current_env="${CONDA_DEFAULT_ENV:-}"
for protected in comfyui kohya_ss ai_env audio_env data_env; do
    if [[ "$current_env" == "$protected" ]]; then
        echo "ERROR: Protected CUDA env '$current_env' active. Aborting."
        exit 1
    fi
done

# ─── Check env exists ────────────────────────────────────────────────
if ! conda info --envs 2>/dev/null | grep -q "^$CONDA_ENV "; then
    log "ERROR: Conda env $CONDA_ENV not found."
    log "       Run scripts/03_create_rocm_image_video_conda_envs.sh first."
    exit 1
fi

log "Installing video tools in $CONDA_ENV..."
log ""

# ─── FFmpeg via conda-forge ──────────────────────────────────────────
log "Step 1: Install FFmpeg (conda-forge)..."
conda install -n "$CONDA_ENV" -c conda-forge ffmpeg -y \
    2>&1 | tee -a "$LOG"

# Verify FFmpeg AMF support
log "  Checking AMF (AMD hardware encoder) support..."
conda run -n "$CONDA_ENV" ffmpeg -encoders 2>/dev/null | \
    grep -i amf | tee -a "$LOG" || log "  [INFO] AMF not found in this FFmpeg build (software encoding will be used)"
log ""

# ─── Python packages ────────────────────────────────────────────────
log "Step 2: Install Python video packages..."

# Use constraints.txt if it exists (to protect any ROCm torch)
CONSTRAINTS=/mnt/c/ai_tools/comfyui-rocm/constraints.txt
CONSTRAINTS_ARG=""
if [[ -f "$CONSTRAINTS" ]]; then
    CONSTRAINTS_ARG="-c $CONSTRAINTS"
    log "  Using constraints: $CONSTRAINTS"
fi

conda run -n "$CONDA_ENV" pip install \
    opencv-python \
    "imageio[ffmpeg]" \
    moviepy \
    av \
    ffmpeg-python \
    imageio \
    Pillow \
    numpy \
    $CONSTRAINTS_ARG \
    2>&1 | tee -a "$LOG"

log ""

# ─── Install frame interpolation utilities ──────────────────────────
log "Step 3: Basic frame processing utilities..."
conda run -n "$CONDA_ENV" pip install \
    scikit-image \
    tqdm \
    $CONSTRAINTS_ARG \
    2>&1 | tee -a "$LOG"

log ""

# ─── Verify installations ────────────────────────────────────────────
log "=== Installation Verification ==="

conda run -n "$CONDA_ENV" python - << 'PYEOF' 2>&1 | tee -a "$LOG"
PASS = "[PASS]"
FAIL = "[FAIL]"

def check_import(name, import_name=None):
    import_name = import_name or name
    try:
        mod = __import__(import_name)
        ver = getattr(mod, '__version__', 'unknown')
        print(f"{PASS} {name}: {ver}")
        return True
    except ImportError as e:
        print(f"{FAIL} {name}: {e}")
        return False

check_import("opencv-python", "cv2")
check_import("imageio")
check_import("moviepy", "moviepy")
check_import("av")
check_import("ffmpeg")
check_import("PIL", "PIL")
check_import("numpy")

# Check FFmpeg binary
import subprocess
result = subprocess.run(["ffmpeg", "-version"], capture_output=True, text=True)
if result.returncode == 0:
    ver_line = result.stdout.split('\n')[0]
    print(f"{PASS} ffmpeg binary: {ver_line}")
else:
    print(f"{FAIL} ffmpeg binary not found in PATH")

# Check codecs
result = subprocess.run(["ffmpeg", "-encoders"], capture_output=True, text=True)
encoders = result.stdout
if "libx264" in encoders:
    print(f"{PASS} H.264 encoder: libx264")
else:
    print(f"{FAIL} H.264 encoder: libx264 not found")

if "libx265" in encoders:
    print(f"{PASS} H.265 encoder: libx265")
elif "hevc" in encoders.lower():
    print(f"[INFO] H.265 encoder: some hevc encoder found")
else:
    print(f"[INFO] H.265 encoder: not found (may need separate package)")

if "amf" in encoders.lower():
    print(f"{PASS} AMD AMF hardware encoder: found")
else:
    print(f"[INFO] AMD AMF hardware encoder: not in this FFmpeg build (OK — use software)")
PYEOF

log ""
log "================================================================"
log "Video tools setup complete."
log "Next: bash scripts/12_validate_video_tools.sh"
log "================================================================"
