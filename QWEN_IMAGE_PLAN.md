# Qwen Image Implementation Plan

## Model Requirements
- **Diffusion Model:** `qwen_image_2512_fp8_e4m3fn.safetensors` (Existing)
- **Text Encoder:** `qwen_2.5_vl_7b_fp8_scaled.safetensors` (Existing)
- **VAE:** `qwen_image_vae.safetensors` (Existing)
- **LoRA:** `Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors` (Existing)

## ComfyUI Configuration
- **Required Nodes:** `ComfyUI-GGUF` or specific Qwen-Image custom nodes.
- **VRAM Strategy:** Use FP8/GGUF to fit within 32GB VRAM. Utilize `bitsandbytes` for ROCm.
- **Workflow:** Text-to-Image $\rightarrow$ ControlNet (Union) $\rightarrow$ Upscale.

## ROCm R9700 Specifics
- **Driver/Torch:** Recommend ROCm 7.0+ and PyTorch Nightly for better stability.
- **Known Issues:** Potential slowness in KSampler; monitor VRAM spikes during VAE decoding.
