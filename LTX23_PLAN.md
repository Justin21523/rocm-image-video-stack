# LTX 2.3 Implementation Plan (Research In Progress)

## Model Requirements
- **Main Weights:** `ltx-2.3-22b-dev-fp8.safetensors`, `ltx-2.3-22b-distilled-fp8.safetensors` (Existing)
- **Text Projection:** `ltx-2.3_text_projection_bf16.safetensors` (Existing)
- **Upscalers:** Spatial/Temporal x2 (Existing)
- **VAE:** Audio/Video VAE (Existing)

## ROCm Specifics
- **Node:** `ComfyUI-LTXVideo`
- **Risk:** 22B parameter size is heavy; GGUF/FP8 is mandatory for 32GB VRAM.
