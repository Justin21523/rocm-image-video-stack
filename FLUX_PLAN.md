# FLUX Implementation Plan (Research In Progress)

## Model Requirements
- **Checkpoints:** `flux2_dev_fp8mixed.safetensors`, `flux1-dev-Q4_K_S.gguf` (Existing)
- **VAE:** `flux2-vae.safetensors` (Existing)
- **Text Encoders:** `clip_l.safetensors`, `t5xxl_fp8_e4m3fn.safetensors` (Existing)

## R9700 Optimization
- **Weight Loading:** Prefer GGUF for the main transformer to save VRAM.
- **VRAM Target:** 32GB allows for high-res generation, but FP8 is recommended for speed.
