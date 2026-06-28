# Existing CUDA Stack Audit
## Read-Only Inventory for ROCm Migration Reference

*Audit date: 2026-05-06 | Source: automated read-only scan*

---

## Summary

The existing CUDA stack is extensive and in active use. It must be treated as read-only reference material. All ROCm components are built in parallel, sharing model files via symlinks.

**Good news**: Many of the required components already exist:
- 6 ROCm conda environments already created (from prior migration phases)
- LTX-2.3 model files already downloaded (57 GB)
- llama.cpp built with ROCm/HIP and running
- ROCm 7.2.3 installed and verified on gfx1201

---

## 1. AI Tools (`/mnt/c/ai_tools/`)

### ComfyUI Installations

| Installation | Path | Git Remote | Size | Notes |
|---|---|---|---|---|
| comfyui | `/mnt/c/ai_tools/comfyui/` | github.com/comfyanonymous/ComfyUI | 3.8 GB | Main CUDA ComfyUI — **PROTECTED** |
| Comfy-LTX-Desktop | `/mnt/c/ai_tools/Comfy-LTX-Desktop/` | github.com/richservo/Comfy-LTX-Desktop | 8.3 GB | LTX specialization — **PROTECTED** |
| ComfyUI-RookieUI | `/mnt/c/ai_tools/ComfyUI-RookieUI/` | — | ~50 MB | Custom frontend — **PROTECTED** |
| comfyui-rocm | `/mnt/c/ai_tools/comfyui-rocm/` | — | empty | ROCm target — this project fills it |

### Video and Image Generation

| Tool | Path | Size | Status |
|---|---|---|---|
| LTX-Video | `/mnt/c/ai_tools/LTX-Video/` | 5.6 GB | CUDA — **PROTECTED** |
| LTX-2 | `/mnt/c/ai_tools/LTX-2/` | 7.8 GB | CUDA — **PROTECTED** |
| LTX-Video-Trainer | `/mnt/c/ai_tools/LTX-Video-Trainer/` | 13 GB | CUDA training — **PROTECTED** |
| Wan2.1 | `/mnt/c/ai_tools/Wan2.1/` | 160 MB | CUDA — **PROTECTED** |
| AnimateDiff | `/mnt/c/ai_tools/AnimateDiff/` | 360 MB | CUDA — **PROTECTED** |

### Audio Tools (reference only)

| Tool | Path | Size |
|---|---|---|
| RVC | `/mnt/c/ai_tools/RVC/` | 15 GB |
| GPT-SoVITS | `/mnt/c/ai_tools/GPT-SoVITS/` | 5.2 GB |
| seed-vc | `/mnt/c/ai_tools/seed-vc/` | 1.6 GB |
| demucs | `/mnt/c/ai_tools/demucs/` | 79 MB |

### Training Tools

| Tool | Path | Size |
|---|---|---|
| kohya_ss | `/mnt/c/ai_tools/kohya_ss/` | — | CUDA LoRA training — **PROTECTED** |
| SimpleTuner | `/mnt/c/ai_tools/SimpleTuner/` | 6.8 GB | CUDA — **PROTECTED** |

### Already-Built ROCm Tools

| Tool | Path | Status |
|---|---|---|
| llama.cpp-rocm | `/mnt/c/ai_tools/llama.cpp-rocm/` | Built with HIP; server running on port 8080; **do not rebuild** |

---

## 2. ComfyUI Custom Nodes

All 28 custom nodes reside at `/mnt/c/ai_tools/comfyui/custom_nodes/` (and mirrored at `/mnt/c/ai_tools/custom_nodes/`).

| Node | Path | ROCm Relevance |
|---|---|---|
| ComfyUI-LTXVideo | custom_nodes/ComfyUI-LTXVideo | Required for LTX 2.3 workflows — install in comfyui-rocm |
| ComfyUI-VideoHelperSuite | custom_nodes/ComfyUI-VideoHelperSuite | FFmpeg wrapper — safe on ROCm |
| ComfyUI-AnimateDiff-Evolved | custom_nodes/ComfyUI-AnimateDiff-Evolved | Known VRAM leak on ROCm — needs config |
| ComfyUI-GGUF | custom_nodes/ComfyUI-GGUF | GGUF inference — works on ROCm via llama.cpp |
| ComfyUI_IPAdapter_plus | custom_nodes/ComfyUI_IPAdapter_plus | Explicit ROCm support |
| ComfyUI-Manager | custom_nodes/ComfyUI-Manager | Pure Python — safe |
| ComfyUI-KJNodes | custom_nodes/ComfyUI-KJNodes | Needs testing |
| ComfyUI-WanVideoWrapper | custom_nodes/ComfyUI-WanVideoWrapper | Needs testing |
| comfyui_controlnet_aux | custom_nodes/comfyui_controlnet_aux | Likely safe |
| ComfyUI_essentials | custom_nodes/ComfyUI_essentials | Likely safe |
| ComfyUI-Frame-Interpolation | custom_nodes/ComfyUI-Frame-Interpolation | Needs testing |
| ComfyUI-InstantID | custom_nodes/ComfyUI-InstantID | Needs testing |
| ComfyUI-CogVideoXWrapper | custom_nodes/ComfyUI-CogVideoXWrapper | Needs testing |
| RES4LYF | custom_nodes/RES4LYF | Unknown risk |
| rs-nodes | custom_nodes/rs-nodes | Unknown risk |

See `CUSTOM_NODE_COMPATIBILITY_MATRIX.md` for complete classification.

---

## 3. Model Storage (`/mnt/c/ai_models/`)

### Top-Level Size Summary

| Category | Size | Notes |
|---|---|---|
| diffusion/ | 613 GB | SDXL, ControlNet, LoRA, IP-Adapter, VAE |
| huggingface/ | 316 GB | HF hub cache (also at /mnt/c/ai_cache/huggingface via symlink) |
| language/ | 130 GB | LLMs for captioning and text encoding |
| video/ | 158 GB | LTX-2.3, Wan2.1, AnimateDiff, CogVideo |
| audio/ | 22 GB | TTS, voice models |
| vision/ | 11 GB | CLIP, DINO, SigLIP, BLIP2 |
| **Total** | **~1.25 TB** | |

### LTX-2.3 Models (Already Downloaded)

**Location**: `/mnt/c/ai_models/video/ltx-2/`

| File | Size | Status |
|---|---|---|
| `ltx-2.3-22b-dev-fp8.safetensors` | 29 GB | Downloaded |
| `ltx-2.3-22b-distilled-fp8.safetensors` | 29.5 GB | Downloaded |
| `audio_vae/` | — | Downloaded (directory) |
| `connectors/` | — | Downloaded (directory) |
| `latent_upsampler/` | — | Downloaded (directory, contents TBD) |

**What still needs to be downloaded** (see `configs/ltx23_model_manifest.yaml`):
- Gemma-3-12B text encoder (~24.4 GB) — **required before first generation**
- Distilled LoRA file (~384 MB) — recommended
- Spatial upscaler safetensors — optional

### Diffusion Models (Reference for Symlinks)

| Category | Path | ROCm Symlink Target |
|---|---|---|
| Checkpoints | `/mnt/c/ai_models/diffusion/stable-diffusion/checkpoints/` | `comfyui-rocm/models/checkpoints/` |
| LoRA | `/mnt/c/ai_models/diffusion/lora/` | `comfyui-rocm/models/loras/` |
| VAE | `/mnt/c/ai_models/diffusion/stable-diffusion/vae/` | `comfyui-rocm/models/vae/` |
| ControlNet | `/mnt/c/ai_models/diffusion/controlnet/` | `comfyui-rocm/models/controlnet/` |
| CLIP | `/mnt/c/ai_models/diffusion/clip/` | `comfyui-rocm/models/clip/` |
| Text encoders | `/mnt/c/ai_models/diffusion/text_encoders/` | `comfyui-rocm/models/text_encoders/` |
| IP-Adapter | `/mnt/c/ai_models/diffusion/ipadapter/` | `comfyui-rocm/models/ipadapter/` |
| Video | `/mnt/c/ai_models/video/` | `comfyui-rocm/models/video/` |

See `MODEL_SYMLINK_MAP.md` for exact `ln -s` commands (not executed yet).

---

## 4. Conda Environments

### CUDA Environments (Protected — Never Modify)

| Name | Purpose |
|---|---|
| `comfyui` | CUDA ComfyUI image/video generation |
| `kohya_ss` | CUDA LoRA training |
| `ai_env` | General CUDA AI/ML |
| `audio_env` | CUDA TTS and voice |
| `data_env` | Data science |
| `base` | Miniconda base |

### ROCm Environments (Already Created — Ready to Use)

| Name | Purpose | PyTorch |
|---|---|---|
| `rocm-pytorch-r9700` | General ROCm base | 2.5.1+rocm6.2 |
| `rocm-comfyui-r9700` | ComfyUI ROCm + LTX | 2.5.1+rocm6.2 |
| `rocm-diffusers-r9700` | HuggingFace Diffusers | 2.5.1+rocm6.2 |
| `rocm-video-r9700` | Video tools (Wan2.1, etc.) | 2.5.1+rocm6.2 |
| `rocm-lora-r9700` | LoRA training | 2.5.1+rocm6.2 |
| `rocm-llamacpp-r9700` | llama.cpp Python bindings | 2.5.1+rocm6.2 |

**Note**: PyTorch 2.5.1+rocm6.2 works but upgrading to 2.9+rocm7.2 is recommended for better gfx1201 support. Script 03 handles the upgrade decision.

---

## 5. Existing Launcher Scripts (Reference)

These CUDA launcher scripts can be referenced for ROCm equivalents:

| Script | Path | Reference Use |
|---|---|---|
| start_comfyui.sh | `/mnt/c/ai_tools/comfyui/start_comfyui.sh` | Port, env activation pattern |
| start_comfyui_detached.sh | `/mnt/c/ai_tools/comfyui/start_comfyui_detached.sh` | tmux session pattern |
| setup_models.sh | `/mnt/c/ai_tools/comfyui/setup_models.sh` | Symlink strategy reference |

---

## 6. Existing Workflows (Reference for Migration)

| Location | Notes |
|---|---|
| `/mnt/c/ai_tools/comfyui/workflows/` | Main workflow directory |
| `/mnt/c/ai_tools/comfyui/user/default/workflows/` | User-saved workflows |
| `/mnt/c/ai_tools/comfyui/custom_nodes/RES4LYF/workflows/` | RES4LYF example workflows |
| `/mnt/c/ai_tools/comfyui/custom_nodes/ComfyUI-UniRig/workflows/` | UniRig example workflows |

Migration process: copy JSON files to `workflows/comfyui-rocm/` → audit node types → adapt for ROCm. See `WORKFLOW_MIGRATION_PLAN.md`.

---

## 7. What Can Be Referenced for ROCm Migration

| Item | How to Reference |
|---|---|
| All model files | Symlinks from `/mnt/c/ai_models/` |
| Custom node source code | Copy or re-clone into `comfyui-rocm/custom_nodes/` |
| CUDA workflow JSON files | Copy to `workflows/comfyui-rocm/` and adapt |
| CUDA launch scripts | Read and adapt env var patterns |
| LTX-2 Python package | `/mnt/c/ai_tools/LTX-2/` — reference for Python API, fallback if ComfyUI-LTXVideo fails |

## 8. What Must Never Be Touched

- Any file or directory listed in Section 1–3 above
- Any conda environment not prefixed with `rocm-`
- The llama.cpp-rocm server (already running on port 8080 — stop with `99_stop_services.sh` only if needed, restart with its own script)
