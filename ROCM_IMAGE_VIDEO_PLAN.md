# ROCm Image/Video Stack — Staged Implementation Plan
## 10-Phase Rollout for AMD Radeon AI PRO R9700

---

## Overview

This plan converts the existing CUDA image/video stack into a parallel ROCm deployment. Each phase is independently deployable and reversible. No phase modifies or deletes any existing CUDA component.

**Current state as of 2026-05-06:**
- Phases 0–2: Pre-conditions satisfied (ROCm 7.2.3, 6 ROCm conda envs, LTX-2.3 models downloaded)
- Phase 3 onwards: Pending implementation

---

## Phase 0 — Read-Only Audit
**Status**: Can run now (no approval needed)
**Scripts**: `00_readonly_audit_existing_cuda_stack.sh`, `01_generate_model_symlink_report.sh`

### Scope
- Inventory all existing CUDA tools, models, conda envs, workflows
- Generate proposed model symlink map
- Save reports to `reports/`

### Expected Outcomes
- `reports/audit_YYYYMMDD.txt` — complete inventory
- `reports/symlink_report_YYYYMMDD.txt` — proposed symlinks

### Failure Handling
- Read-only scripts cannot cause damage
- Re-run anytime to refresh reports

---

## Phase 1 — Workspace Preparation
**Status**: Complete (directory tree already created)
**Scripts**: `02_prepare_rocm_image_video_workspace.sh`

### Scope
- Create project subdirectories
- Verify no protected paths are modified

### Expected Outcomes
- All directories under `rocm-image-video-stack/` exist
- `logs/`, `reports/`, `workflows/` ready for use

---

## Phase 2 — ROCm Conda Environment Validation / Upgrade
**Status**: Envs exist; validation + optional upgrade pending
**Scripts**: `03_create_rocm_image_video_conda_envs.sh`
**Approval required**: Yes

### Scope
- Verify all 6 ROCm conda envs exist and have correct PyTorch
- Optionally upgrade PyTorch from 2.5.1+rocm6.2 to 2.9+rocm7.2
- Create any missing envs (`rocm-ltx23-r9700` if not yet present)
- Never modify CUDA envs

### Conda Environments

| Name | Python | Purpose | Status |
|------|--------|---------|--------|
| `rocm-comfyui-r9700` | 3.12 | ComfyUI + LTX workflows | Exists |
| `rocm-diffusers-r9700` | 3.12 | HuggingFace Diffusers | Exists |
| `rocm-video-r9700` | 3.12 | Video tools (Wan, FFmpeg) | Exists |
| `rocm-lora-r9700` | 3.12 | LTX-2 LoRA training | Exists |
| `rocm-llamacpp-r9700` | 3.12 | llama.cpp Python bindings | Exists |
| `rocm-pytorch-r9700` | 3.12 | General ROCm base | Exists |
| `rocm-ltx23-r9700` | 3.12 | LTX-2 Python package | May be missing |

### Expected Outcomes
- All envs validated; PyTorch version logged
- Upgrade decision recorded in logs

### Failure Handling
- If PyTorch upgrade breaks something: `conda install torch==2.5.1+rocm6.2` to rollback

---

## Phase 3 — ComfyUI ROCm Installation
**Status**: Pending
**Scripts**: `04_setup_comfyui_rocm.sh`
**Approval required**: Yes

### Scope
- Clone ComfyUI into `/mnt/c/ai_tools/comfyui-rocm/`
- Activate `rocm-comfyui-r9700`
- Install requirements with `constraints.txt` (locks ROCm torch)
- Create launch script with correct env vars
- Port: 8189 (CUDA ComfyUI stays on 8188)

### Required Environment Variables
```bash
export HIP_VISIBLE_DEVICES=0
export PYTORCH_HIP_ALLOC_CONF="garbage_collection_threshold:0.7,max_split_size_mb:128"
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
```

### Launch Command
```bash
python main.py \
  --listen 0.0.0.0 \
  --port 8189 \
  --use-pytorch-cross-attention \
  --disable-xformers
```

### Expected Outcomes
- ComfyUI starts on port 8189 without import errors
- GPU detected: `torch.cuda.get_device_name(0)` returns R9700
- `torch.version.hip` is not None

### Failure Handling
- Import errors: check `logs/04_comfyui_install.log` for pip conflicts
- GPU not detected: verify `HIP_VISIBLE_DEVICES=0` and ROCm device files

---

## Phase 4 — Model Symlinks
**Status**: Pending
**Scripts**: `05_setup_comfyui_model_symlinks.sh`
**Approval required**: Yes

### Scope
- Create symlinks from `/mnt/c/ai_models/` into `comfyui-rocm/models/`
- Dry-run mode available before actual execution
- Never overwrite real files; only replace empty dirs

### Key Symlinks

| Source | Target |
|--------|--------|
| `/mnt/c/ai_models/diffusion/stable-diffusion/checkpoints/` | `comfyui-rocm/models/checkpoints/` |
| `/mnt/c/ai_models/diffusion/lora/` | `comfyui-rocm/models/loras/` |
| `/mnt/c/ai_models/video/ltx-2/` | `comfyui-rocm/models/video/ltx-2/` |
| `/mnt/c/ai_models/diffusion/clip/` | `comfyui-rocm/models/clip/` |
| `/mnt/c/ai_models/diffusion/text_encoders/` | `comfyui-rocm/models/text_encoders/` |
| `/mnt/c/ai_models/diffusion/controlnet/` | `comfyui-rocm/models/controlnet/` |
| `/mnt/c/ai_models/diffusion/ipadapter/` | `comfyui-rocm/models/ipadapter/` |
| `/mnt/c/ai_models/diffusion/vae/` | `comfyui-rocm/models/vae/` |

### Expected Outcomes
- All symlinks verified with `ls -la comfyui-rocm/models/`
- No model files duplicated

---

## Phase 5 — Safe Custom Nodes (Green Tier)
**Status**: Pending
**Scripts**: `06_install_safe_comfyui_custom_nodes.sh`
**Approval required**: Yes

### Nodes to Install (Green Tier Only)
1. `ComfyUI-Manager` (ltdrdata) — node management
2. `rgthree-comfy` — utility nodes
3. `ComfyUI-Custom-Scripts` — UI scripts
4. `ComfyUI_essentials` — essential node pack
5. `ComfyUI-VideoHelperSuite` — FFmpeg video wrapper

### Installation Pattern
```bash
git clone <repo> custom_nodes/<name>
pip install -r custom_nodes/<name>/requirements.txt \
  -c /mnt/c/ai_tools/comfyui-rocm/constraints.txt
```

### Deferred to Phase 6
- `ComfyUI-LTXVideo` (Yellow risk — install after research review)
- `ComfyUI-GGUF` (Yellow risk — install with LTX nodes)

---

## Phase 6 — LTX 2.3 Base Text-to-Video Workflow
**Status**: Pending (depends on Phases 3–5)
**Scripts**: `07_validate_rocm_pytorch.sh`, `08_validate_comfyui_rocm.sh`, `09_prepare_ltx23_models.sh`, `10_validate_ltx23_comfyui_workflow.sh`
**Approval required**: Yes (model download + inference)

### Sub-phases

#### 6a — Validate ROCm PyTorch
Run `07_validate_rocm_pytorch.sh` — tests GPU tensor ops, BF16 matmul, FP8 (expected failure — logged only).

#### 6b — Validate ComfyUI Import
Run `08_validate_comfyui_rocm.sh` — one-shot import check without starting server.

#### 6c — Prepare LTX 2.3 Models
Run `09_prepare_ltx23_models.sh`:
- Audit mode: check what's local vs what's needed (safe, no approval)
- Download mode: fetch Gemma-3-12B (24.4 GB) and distilled LoRA (~384 MB) — **requires approval**

**Already downloaded:**
- `ltx-2.3-22b-dev-fp8.safetensors` (29 GB)
- `ltx-2.3-22b-distilled-fp8.safetensors` (29.5 GB)
- `audio_vae/`, `connectors/`, `latent_upsampler/` directories

**Missing (must download):**
- Gemma-3-12B text encoder (24.4 GB) — from `Comfy-Org/ltx-2`
- Distilled LoRA safetensors (~384 MB) — from `Lightricks/LTX-2.3`

#### 6d — Install ComfyUI-LTXVideo
```bash
git clone https://github.com/Lightricks/ComfyUI-LTXVideo \
  custom_nodes/ComfyUI-LTXVideo
pip install -r custom_nodes/ComfyUI-LTXVideo/requirements.txt \
  -c constraints.txt
```

#### 6e — First T2V Generation
Run `10_validate_ltx23_comfyui_workflow.sh`:
- Load minimal T2V workflow via ComfyUI API
- Settings: 1216×704, 24 fps, 8 steps, CFG 1.0, distilled model
- Expected output: 5-second video file in `workflows/validation/`

### FP8 Model Risk
The downloaded models are in FP8 format. gfx1201 FP8 *compute* is broken (torch.mm in fp8 dtype). However, ComfyUI-LTXVideo likely dequantizes weights to BF16 on load, in which case the FP8 files work normally.

**If FP8 loading fails:**
1. Check error: `NotImplementedError: "aten::mm": not implemented for 'Float8_e4m3fn'`
2. Fallback: install `ComfyUI-GGUF` and download GGUF variant from `QuantStack/LTX-2.3-GGUF` (8–17 GB depending on quantization level)

---

## Phase 7 — LTX 2.3 Image-to-Video Workflow
**Status**: Pending (depends on Phase 6)

### Scope
- Add I2V workflow using `LTXImageToVideoSampler` node (if available in ComfyUI-LTXVideo)
- Or use `LTXSampler` with image conditioning input
- Test with reference image from `/mnt/c/ai_models/` or user-provided
- Settings: same as T2V + `strength` parameter for conditioning

### Expected Outcomes
- I2V workflow JSON saved to `workflows/image-to-video/`
- 5-second video generated from reference image

---

## Phase 8 — LTX 2.3 IC-LoRA / ID-LoRA / Control Experiments
**Status**: Pending (depends on Phase 7)

### IC-LoRA (Image Conditioning)
- Motion Track Control: `LTX-2.3-22b-IC-LoRA-Motion-Track-Control` — guide motion with sparse point trajectories
- Union Control: depth + canny edge combined

### ID-LoRA (Identity Preservation)
- CelebV-HQ: face appearance transfer across video
- TalkVid-3K: talking video generation with identity preservation

### Training Consideration
- All IC/ID LoRAs must be trained specifically on LTX 2.3 latent space
- LTX 2.0 LoRAs are **completely incompatible** (different architecture)
- Use `rocm-lora-r9700` env with LTX-2 trainer package for custom LoRA training

---

## Phase 9 — Video Processing Tools
**Status**: Pending
**Scripts**: `11_setup_video_tools_rocm.sh`, `12_validate_video_tools.sh`
**Approval required**: Yes

### Tools to Install in `rocm-video-r9700`

| Tool | Purpose | Install Method |
|------|---------|----------------|
| ffmpeg | Encode/decode video (H.264, H.265, AV1) | conda-forge |
| opencv-python | Image/frame processing | pip |
| imageio[ffmpeg] | Video I/O | pip |
| moviepy | Video composition | pip |
| av | Low-level video codec | pip |
| ffmpeg-python | FFmpeg Python binding | pip |

### AMD FFmpeg Encoding
FFmpeg supports AMD AMF (Advanced Media Framework) encoding natively:
```bash
ffmpeg -i input.mp4 -c:v hevc_amf -quality balanced output.mp4
```
No special compilation needed for conda-forge FFmpeg.

### Expected Outcomes
- Frame extraction: extract frames from video at target FPS
- Video composition: assemble frames into video
- Format conversion: convert between MP4, WebM, GIF

---

## Phase 10 — Validation and Benchmark Reports
**Status**: Pending (depends on all prior phases)

### Validation Suite
See `VALIDATION_PLAN.md` for 10-test suite covering:
- ROCm PyTorch
- ComfyUI startup
- SDXL generation
- LoRA generation
- LTX 2.3 T2V, I2V, upscaler
- Video export and frame extraction

### Benchmark Targets

| Benchmark | Expected Range (R9700 32GB) |
|-----------|----------------------------|
| SDXL 1024×1024 (50 steps) | 3–8 seconds |
| LTX 2.3 T2V 1216×704 24fps 10s (8 steps distilled) | 3–6 minutes |
| LTX 2.3 T2V 1216×704 24fps 10s (full model) | 8–15 minutes |
| Frame extraction 10s video | <5 seconds |
| H.265 encoding (AMF) 1080p | <30 seconds |

### Report Outputs
- `reports/validation_report_YYYYMMDD.txt`
- `reports/benchmark_report_YYYYMMDD.txt`
