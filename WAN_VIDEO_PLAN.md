# Wan Video Implementation Plan (Research In Progress)

## Model Requirements
- **Main Weights:** `wan2.1_t2v_1.3B_fp16.safetensors` (Existing), `wan2.1-i2v-14b-480p-Q5_K_M.gguf` (Existing)
- **VAE:** `wan_2.1_vae.safetensors` (Existing)
- **Text Encoder:** `umt5_xxl_fp8_e4m3fn_scaled.safetensors` (Existing)
- **Clip Vision:** `clip_vision_h.safetensors` (Existing)

## ROCm Specifics
- **Node:** `ComfyUI-WanVideoWrapper`
- **VRAM:** 14B GGUF should fit comfortably in 32GB VRAM.
