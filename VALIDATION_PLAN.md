# Validation Plan
## 10-Test Suite for ROCm Image/Video Stack

---

## Overview

Tests run in order: each depends on the previous. A failure at test N should be resolved before running test N+1.

All test outputs and logs are saved to `reports/` with timestamps.

---

## Test 1 — ROCm PyTorch Baseline
**Script**: `07_validate_rocm_pytorch.sh`
**Phase**: After Phase 2 (conda envs)
**Approval**: Not required (read-only test)

### What It Tests
- `torch.version.hip` is not None (confirms ROCm build)
- `torch.cuda.is_available()` returns True (ROCm uses CUDA API)
- GPU name contains "Radeon" or "AMD"
- VRAM ≥ 30 GB (confirms R9700 detected, not integrated GPU)
- Float32 tensor matmul (1024×1024): completes without error
- BF16 tensor matmul (1024×1024): completes without error
- FP8 tensor operation: expected to fail on gfx1201 — logs warning, does NOT cause test failure

### Expected Output
```
[PASS] torch.version.hip: 7.2.3.xx
[PASS] torch.cuda.is_available(): True
[PASS] GPU: AMD Radeon AI PRO R9700
[PASS] VRAM: 32.0 GB
[PASS] Float32 matmul: OK (elapsed: ~50ms)
[PASS] BF16 matmul: OK (elapsed: ~30ms)
[WARN] FP8 matmul: NotImplementedError (expected on gfx1201)
[PASS] Overall: PASS
```

### Failure Handling
- `torch.cuda.is_available()` False: check `/dev/dri/`, `rocm-smi`, `HIP_VISIBLE_DEVICES`
- VRAM < 1 GB: wrong GPU selected; check `HIP_VISIBLE_DEVICES=0`
- BF16 error: check ROCm version (needs 7.x for gfx1201 BF16)

---

## Test 2 — ComfyUI Startup
**Script**: `08_validate_comfyui_rocm.sh`
**Phase**: After Phase 3 (ComfyUI ROCm installed)
**Approval**: Not required (import test only, no server)

### What It Tests
- ComfyUI imports without errors
- `comfy.model_management.get_torch_device()` returns a CUDA device
- No critical ImportError in startup log
- Custom nodes directory accessible

### Expected Output
```
[PASS] ComfyUI imports OK
[PASS] Torch device: cuda:0
[PASS] No critical import errors
[PASS] Custom nodes dir: /mnt/c/ai_tools/comfyui-rocm/custom_nodes/
[PASS] Overall: PASS
```

### Failure Handling
- `ImportError: torch`: conda env not activated; check `conda activate rocm-comfyui-r9700`
- `ImportError: xformers`: `--disable-xformers` flag not set; add to launch command
- Custom node import error: check specific node log; may need `pip install -r requirements.txt`

---

## Test 3 — SDXL Simple Generation
**Phase**: After Phase 4 (model symlinks) + Phase 5 (basic nodes)
**Approval**: Not required (standard inference)

### What It Tests
- SDXL checkpoint loads from symlinked `models/checkpoints/`
- KSampler runs at 512×512, 20 steps
- VAE decodes output
- Image saved to `reports/test3_sdxl.png`

### Expected Output
```
[PASS] Checkpoint loaded: <sdxl_model>.safetensors
[PASS] Sampler ran: 20 steps, 512x512
[PASS] VAE decode: OK
[PASS] Image saved: reports/test3_sdxl.png
[PASS] Time: <30 seconds
[PASS] Overall: PASS
```

### Failure Handling
- Checkpoint not found: verify `models/checkpoints/` symlink points to correct source
- OOM: reduce to 256×256 for test; check VRAM with `rocm-smi`
- Black image: check CFG scale (should be >1.0 for SDXL)

---

## Test 4 — LoRA Simple Generation
**Phase**: After Test 3
**Approval**: Not required

### What It Tests
- LoRA loads from symlinked `models/loras/`
- Applied to SDXL base model
- Generation completes (any LoRA, style test only)

### Expected Output
```
[PASS] LoRA loaded: <any_lora>.safetensors
[PASS] LoRA applied without errors
[PASS] Generation completed
[PASS] Overall: PASS
```

### Failure Handling
- LoRA not found: verify `models/loras/` symlink; check for SDXL-compatible LoRA
- Note: LTX 2.0 LoRAs in `loras/ltx/` will NOT work for LTX 2.3 — this test uses SDXL LoRAs only

---

## Test 5 — ControlNet Test
**Phase**: After Test 3
**Approval**: Not required

### What It Tests
- ControlNet model loads from `models/controlnet/`
- Preprocessor runs on test image
- Controlled generation completes

### Expected Output
```
[PASS] ControlNet loaded
[PASS] Preprocessor: OK
[PASS] Controlled generation: OK
[PASS] Overall: PASS
```

### Failure Handling
- Missing model: verify `models/controlnet/` symlink; check file exists in source
- Preprocessor error: some preprocessors require specific pip packages; install with constraints.txt

---

## Test 6 — LTX 2.3 T2V Minimal
**Script**: `10_validate_ltx23_comfyui_workflow.sh`
**Phase**: After Phase 6 (LTX models + ComfyUI-LTXVideo installed)
**Approval**: Required (model inference)

### What It Tests
- Gemma-3-12B text encoder loads
- LTX-2.3 distilled model loads (FP8 or GGUF)
- LTXSampler runs minimal generation: 256×144, 9 frames (1 second)
- VAE decode runs
- Video file saved to `reports/test6_ltx23_minimal.mp4`

### Expected Output
```
[PASS] Gemma-3-12B text encoder loaded
[PASS] LTX model loaded (FP8 dequantize or GGUF)
[PASS] LTXSampler: 8 steps, 256x144, 9 frames
[PASS] VAE decode: OK
[PASS] Video saved: reports/test6_ltx23_minimal.mp4
[PASS] Time: <60 seconds
[PASS] Overall: PASS
```

### Failure Handling
- Gemma not found: run `09_prepare_ltx23_models.sh --download` to fetch it
- FP8 error (`NotImplementedError: aten::mm Float8_e4m3fn`): use GGUF fallback
- OOM: reduce to `128×72`, 9 frames; check VRAM; may need Gemma partial offload
- Corrupt video: check frame count (must be `N×8+1`; 9 frames = `1×8+1` ✓)

---

## Test 7 — LTX 2.3 I2V Minimal
**Phase**: After Test 6 passes
**Approval**: Required (model inference)

### What It Tests
- Image-to-video conditioning works
- `LTXSampler` accepts image input
- Output video shows motion from reference image
- Settings: 1216×704, 25 frames, 8 steps

### Expected Output
```
[PASS] Reference image loaded
[PASS] Image conditioning applied
[PASS] LTXSampler (I2V): 8 steps, 1216x704, 25 frames
[PASS] Video saved: reports/test7_ltx23_i2v.mp4
[PASS] Overall: PASS
```

### Failure Handling
- Image conditioning not available in node: check ComfyUI-LTXVideo version; update if needed
- Output ignores reference image: check `strength` parameter (default 0.85)

---

## Test 8 — LTX 2.3 Upscaler
**Phase**: After Test 7 passes + spatial upscaler downloaded
**Approval**: Required

### What It Tests
- Spatial upscaler model loads
- `LTXLatentUpsampler` runs on output from Test 6
- 2× upscale: 256×144 → 512×288
- Upscaled video saved

### Expected Output
```
[PASS] Spatial upscaler loaded
[PASS] LTXLatentUpsampler: 2x scale, 256x144 → 512x288
[PASS] Upscaled video saved: reports/test8_ltx23_upscaled.mp4
[PASS] Overall: PASS
```

### Failure Handling
- Upscaler not found: download from `Lightricks/LTX-2.3` via script 09
- Upscale produces artifacts: normal at very small resolution; test with standard 1216×704 input

---

## Test 9 — Video Export
**Script**: `12_validate_video_tools.sh`
**Phase**: After Phase 9 (video tools installed)
**Approval**: Not required

### What It Tests
- FFmpeg available in PATH
- H.264 codec available: `ffmpeg -encoders | grep h264`
- H.265/HEVC codec available: `ffmpeg -encoders | grep hevc`
- AMF hardware encoder available: `ffmpeg -encoders | grep amf`
- Round-trip test: encode 5-frame PNG sequence → H.264 MP4 → re-extract → compare
- Video export time for 5-second 1080p clip: <30 seconds

### Expected Output
```
[PASS] FFmpeg version: x.x.x
[PASS] H.264 encoder: libx264
[PASS] H.265 encoder: libx265
[PASS] AMF hardware encoder: h264_amf, hevc_amf
[PASS] Round-trip: 5 frames encoded and re-extracted successfully
[PASS] 1080p H.265 encode: <30 seconds
[PASS] Overall: PASS
```

### Failure Handling
- AMF not found: conda FFmpeg may not include AMF; use `libx264`/`libx265` for software encoding
- Round-trip mismatch: check color space conversion; use `-pix_fmt yuv420p` for compatibility

---

## Test 10 — Frame Extraction
**Script**: `12_validate_video_tools.sh` (same script, different test section)
**Phase**: After Phase 9
**Approval**: Not required

### What It Tests
- Extract frames from test MP4 at 24 fps using moviepy
- Extract frames using imageio
- Frame count matches expected (5 seconds × 24 fps = 120 frames)
- Frame shape matches source resolution

### Expected Output
```
[PASS] moviepy extraction: 120 frames from 5s 24fps video
[PASS] imageio extraction: 120 frames
[PASS] Frame shape: (1080, 1920, 3)
[PASS] Dataset preparation: frames saved to reports/test10_frames/
[PASS] Overall: PASS
```

### Failure Handling
- moviepy ImportError: re-install in `rocm-video-r9700` env with constraints.txt
- Frame count mismatch: check video FPS metadata with `ffprobe`; specify fps explicitly in moviepy

---

## Full Validation Report

After all 10 tests pass:
```bash
cat reports/validation_report_*.txt
```

Expected summary:
```
ROCm Image/Video Stack Validation Report
========================================
Date: YYYY-MM-DD
GPU: AMD Radeon AI PRO R9700 (gfx1201)
ROCm: 7.2.3
PyTorch: 2.5.1+rocm6.2

Test 01 - ROCm PyTorch:        PASS
Test 02 - ComfyUI Startup:     PASS
Test 03 - SDXL Generation:     PASS
Test 04 - LoRA Generation:     PASS
Test 05 - ControlNet:          PASS
Test 06 - LTX 2.3 T2V:        PASS (model: distilled-fp8 or GGUF)
Test 07 - LTX 2.3 I2V:        PASS
Test 08 - LTX 2.3 Upscaler:   PASS
Test 09 - Video Export:        PASS
Test 10 - Frame Extraction:    PASS

Overall: 10/10 PASS
Stack is ready for production workflows.
```
