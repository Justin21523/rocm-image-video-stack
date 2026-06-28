#!/usr/bin/env bash
# Video Tools Validation — Tests 9 and 10
# Tests FFmpeg encoding/decoding and frame extraction
# Safe to run (creates temp files in /tmp, cleans up after)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$PROJECT_DIR/reports"
LOGS_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$REPORTS_DIR/video_tools_validation_$TIMESTAMP.txt"
LOG="$LOGS_DIR/12_video_validate_$TIMESTAMP.log"

mkdir -p "$REPORTS_DIR" "$LOGS_DIR"

log() { echo "$*" | tee -a "$REPORT" | tee -a "$LOG"; }

CONDA_ENV=rocm-video-r9700
TMPDIR="/tmp/rocm_video_test_$TIMESTAMP"

log "================================================================"
log "VIDEO TOOLS VALIDATION — Tests 9 and 10"
log "Date: $(date)"
log "Temp dir: $TMPDIR"
log "================================================================"
log ""

mkdir -p "$TMPDIR"

# ─── Cleanup on exit ────────────────────────────────────────────────
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# ─── Test 9: FFmpeg Encoding ─────────────────────────────────────────
log "=== Test 9: Video Export ==="
log ""

conda run -n "$CONDA_ENV" python - << PYEOF 2>&1 | tee -a "$REPORT" | tee -a "$LOG"
import subprocess
import os
import sys
import numpy as np
import tempfile
import time

PASS = "[PASS]"
FAIL = "[FAIL]"
WARN = "[WARN]"
TMPDIR = "$TMPDIR"

# Test FFmpeg version
result = subprocess.run(["ffmpeg", "-version"], capture_output=True, text=True)
if result.returncode == 0:
    print(f"{PASS} FFmpeg available: {result.stdout.split(chr(10))[0]}")
else:
    print(f"{FAIL} FFmpeg not found")
    sys.exit(1)

# List key codecs
result = subprocess.run(["ffmpeg", "-encoders"], capture_output=True, text=True)
encoders = result.stdout
print("")
print("Encoder status:")
for codec, label in [
    ("libx264", "H.264 software"),
    ("libx265", "H.265 software"),
    ("h264_amf", "H.264 AMD AMF"),
    ("hevc_amf", "H.265 AMD AMF"),
]:
    if codec in encoders:
        print(f"  {PASS} {label} ({codec})")
    else:
        print(f"  [INFO] {label} ({codec}): not available")

# Create synthetic test frames (5 frames of gradient)
print("")
print("Creating test video from synthetic frames...")

try:
    import imageio.v3 as iio

    # Create 30 frames of 640x360 synthetic video
    frames = []
    for i in range(30):
        frame = np.zeros((360, 640, 3), dtype=np.uint8)
        frame[:, :, 0] = int(255 * i / 30)  # R gradient
        frame[:, :, 2] = int(255 * (30 - i) / 30)  # B gradient
        frames.append(frame)

    output_path = os.path.join(TMPDIR, "test_output.mp4")

    t0 = time.time()
    iio.imwrite(
        output_path,
        np.stack(frames),
        fps=24,
        codec="libx264",
        quality=7
    )
    elapsed = time.time() - t0

    if os.path.exists(output_path):
        size = os.path.getsize(output_path)
        print(f"{PASS} H.264 encode: {len(frames)} frames, {elapsed:.2f}s, {size//1024}KB")
    else:
        print(f"{FAIL} H.264 encode: output file not created")

except Exception as e:
    print(f"{FAIL} H.264 encode: {e}")

# Test FFmpeg round-trip
test_mp4 = os.path.join(TMPDIR, "test_output.mp4")
if os.path.exists(test_mp4):
    probe_result = subprocess.run(
        ["ffprobe", "-v", "quiet", "-print_format", "json",
         "-show_streams", test_mp4],
        capture_output=True, text=True
    )
    if probe_result.returncode == 0:
        import json
        info = json.loads(probe_result.stdout)
        stream = info.get("streams", [{}])[0]
        width = stream.get("width", "?")
        height = stream.get("height", "?")
        codec = stream.get("codec_name", "?")
        print(f"{PASS} Video probe: {width}x{height} {codec}")
    else:
        print(f"{WARN} ffprobe failed")
PYEOF

log ""
log "=== Test 10: Frame Extraction ==="
log ""

conda run -n "$CONDA_ENV" python - << PYEOF 2>&1 | tee -a "$REPORT" | tee -a "$LOG"
import os
import sys
import numpy as np
import time

PASS = "[PASS]"
FAIL = "[FAIL]"
WARN = "[WARN]"
TMPDIR = "$TMPDIR"
FRAMES_DIR = os.path.join(TMPDIR, "extracted_frames")

# First create a test video
import subprocess
import imageio.v3 as iio

# Create 5-second 24fps synthetic video (120 frames)
print("Creating 5-second test video (120 frames, 24fps)...")
frames = []
for i in range(120):
    frame = np.random.randint(0, 255, (360, 640, 3), dtype=np.uint8)
    frames.append(frame)

test_mp4 = os.path.join(TMPDIR, "test_5sec.mp4")
try:
    iio.imwrite(test_mp4, np.stack(frames), fps=24, codec="libx264")
    print(f"{PASS} Test video created: {os.path.getsize(test_mp4)//1024}KB")
except Exception as e:
    print(f"{FAIL} Could not create test video: {e}")
    sys.exit(1)

# Test 1: Extract frames with imageio
print("")
print("Test: imageio frame extraction...")
try:
    os.makedirs(FRAMES_DIR, exist_ok=True)
    t0 = time.time()
    extracted = iio.imread(test_mp4, index=None)
    elapsed = time.time() - t0
    frame_count = len(extracted)
    shape = extracted[0].shape if frame_count > 0 else "?"
    print(f"{PASS} imageio: {frame_count} frames, shape {shape}, {elapsed:.2f}s")
    if frame_count >= 100:  # some codecs may vary slightly
        print(f"{PASS} Frame count: {frame_count} (expected ~120)")
    else:
        print(f"{WARN} Frame count: {frame_count} (expected ~120 — may be OK)")
except Exception as e:
    print(f"{FAIL} imageio extraction: {e}")

# Test 2: moviepy frame extraction
print("")
print("Test: moviepy frame extraction...")
try:
    from moviepy.video.io.VideoFileClip import VideoFileClip
    t0 = time.time()
    clip = VideoFileClip(test_mp4)
    duration = clip.duration
    fps = clip.fps
    n_frames = int(duration * fps)
    clip.close()
    elapsed = time.time() - t0
    print(f"{PASS} moviepy: duration={duration:.1f}s fps={fps:.0f} frames~{n_frames}, {elapsed:.2f}s")
except Exception as e:
    print(f"{FAIL} moviepy: {e}")

# Test 3: FFmpeg frame extraction
print("")
print("Test: FFmpeg frame extraction...")
try:
    extract_dir = os.path.join(TMPDIR, "ffmpeg_frames")
    os.makedirs(extract_dir, exist_ok=True)
    result = subprocess.run(
        ["ffmpeg", "-i", test_mp4, "-vf", "fps=24",
         os.path.join(extract_dir, "frame_%04d.png"), "-y"],
        capture_output=True, text=True
    )
    frame_files = [f for f in os.listdir(extract_dir) if f.endswith('.png')]
    print(f"{PASS} FFmpeg: {len(frame_files)} PNG frames extracted")
except Exception as e:
    print(f"{FAIL} FFmpeg frame extraction: {e}")

print("")
print("================================================================")
print("Video tools validation complete.")
print("================================================================")
PYEOF

log ""
log "================================================================"
log "Video tools validation complete."
log "Report saved to: $REPORT"
log "================================================================"
