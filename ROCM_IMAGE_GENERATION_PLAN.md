# Phase 3: ROCm Image/Video Generation Stack Implementation Plan

This plan outlines the transition from CUDA to ROCm for image and video generation on the AMD Radeon AI PRO R9700 (32GB VRAM).

## 1. Environment Strategy
To avoid corrupting existing environments, we will use a dedicated, clean environment.

- **Target Environment:** `rocm-image-stack-r9700`
- **Base:** Python 3.11 / 3.12
- **Core Stack:**
    - PyTorch Nightly (ROCm 6.x/7.x compatible)
    - torchvision, torchaudio (ROCm versions)
    - `bitsandbytes` (ROCm version) for FP8/Int8 quantization.
    - `triton` (ROCm version).
- **Optimization:** Integrate `rocm-tunableop-optimizer` into the startup sequence.

## 2. Model Symlink Mapping (The "Clean Slate" Approach)
We will not move files. We will create a standardized `extra_model_paths.yaml` for ComfyUI ROCm to map `/mnt/c/ai_models` correctly.

| ComfyUI Folder | Source Path (in /mnt/c/ai_models) | Note |
| :--- | :--- | :--- |
| `checkpoints` | `diffusion/stable-diffusion/checkpoints` | SD1.5, SDXL, Pony, Illustrious |
| `vae` | `diffusion/stable-diffusion/vae` | All VAEs |
| `loras` | `diffusion/lora` | General LoRAs |
| `loras_sdxl` | `diffusion/lora/sdxl` | SDXL specific LoRAs |
| `clip` | `diffusion/clip` | Text encoders |
| `diffusion_models`| `diffusion/diffusion_models` | FLUX, Qwen, Z-Image, LTX |
| `controlnet` | `diffusion/controlnet` | All ControlNets |
| `upscale_models` | `vision/upscale` | RealESRGAN, etc. |
| `video` | `video` | Wan, LTX, CogVideo |

## 3. Step-by-Step Execution Pipeline

### Step A: Workspace Setup (Phase 4.1)
- Create `/mnt/c/ai_tools/comfyui-rocm-stack` (Fresh clone of ComfyUI).
- Generate the `extra_model_paths.yaml` based on the mapping above.

### Step B: Environment Activation (Phase 4.2)
- Create `rocm-image-stack-r9700` conda env.
- Install PyTorch ROCm $\rightarrow$ Install ComfyUI dependencies $\rightarrow$ Install `bitsandbytes-rocm`.

### Step C: Custom Node Migration (Phase 4.3)
- Symlink existing `custom_nodes` from the CUDA stack to the ROCm stack to avoid re-downloading.
- Specifically ensure `ComfyUI-GGUF`, `ComfyUI-WanVideoWrapper`, and `ComfyUI-LTXVideo` are present.

### Step D: Validation Sequence (Phase 4.4)
We will run a "VRAM Ladder" to test stability:
1. **SDXL Basic:** 1024x1024 $\rightarrow$ Verify basic ROCm torch.
2. **FLUX GGUF:** Verify 32GB VRAM handling of large transformers.
3. **Qwen Image:** Verify VLM integration and FP8 loading.
4. **LTX 2.3:** Verify 22B model loading and video VAE.
5. **Wan 2.1 (14B):** Final stress test for high-resolution video generation.

## 4. OpenClaw & Model Control UI Integration
- **Service:** Create a systemd service for ComfyUI ROCm.
- **API:** Configure OpenClaw to send prompts to the ComfyUI API.
- **UI:** Map the Model Control UI to toggle between the different model families (Flux vs Wan vs Qwen).

## 5. Rollback Plan
- Since we are using a fresh directory and a new conda environment, the rollback is simple:
    - `conda env remove -n rocm-image-stack-r9700`
    - `rm -rf /mnt/c/ai_tools/comfyui-rocm-stack`
- Zero impact on existing CUDA setup.
