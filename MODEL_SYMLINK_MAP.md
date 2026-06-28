# Model Symlink Map
## `/mnt/c/ai_models/` → `comfyui-rocm/models/` Mapping

*Commands listed here are for reference. Execute only via approved script 05.*

---

## Strategy

- All model files reside in `/mnt/c/ai_models/` (never duplicated)
- ComfyUI ROCm gets symlinks pointing to the shared model tree
- If a ComfyUI model directory is empty: replace it with a symlink
- If it contains real files: do not overwrite; investigate first
- Run `--dry-run` before applying any symlinks

```bash
COMFYUI_MODELS=/mnt/c/ai_tools/comfyui-rocm/models
AI_MODELS=/mnt/c/ai_models
```

---

## Symlink Map

### Checkpoints (SDXL, SD 1.5, etc.)

| Source | Target | Command |
|--------|--------|---------|
| `/mnt/c/ai_models/diffusion/stable-diffusion/checkpoints/` | `$COMFYUI_MODELS/checkpoints/` | `ln -sfn $AI_MODELS/diffusion/stable-diffusion/checkpoints $COMFYUI_MODELS/checkpoints` |

### LoRA

| Source | Target | Command |
|--------|--------|---------|
| `/mnt/c/ai_models/diffusion/lora/` | `$COMFYUI_MODELS/loras/` | `ln -sfn $AI_MODELS/diffusion/lora $COMFYUI_MODELS/loras` |

Note: existing LTX LoRAs in `lora/ltx/` and `lora/ltxv/` were trained for LTX 2.0 and **will not work** with LTX 2.3. They will appear in ComfyUI but produce garbage output if applied to LTX 2.3 model.

### VAE

| Source | Target | Command |
|--------|--------|---------|
| `/mnt/c/ai_models/diffusion/stable-diffusion/vae/` | `$COMFYUI_MODELS/vae/` | `ln -sfn $AI_MODELS/diffusion/stable-diffusion/vae $COMFYUI_MODELS/vae` |

### CLIP / Text Encoders

| Source | Target | Command |
|--------|--------|---------|
| `/mnt/c/ai_models/diffusion/clip/` | `$COMFYUI_MODELS/clip/` | `ln -sfn $AI_MODELS/diffusion/clip $COMFYUI_MODELS/clip` |
| `/mnt/c/ai_models/diffusion/text_encoders/` | `$COMFYUI_MODELS/text_encoders/` | `ln -sfn $AI_MODELS/diffusion/text_encoders $COMFYUI_MODELS/text_encoders` |

Gemma-3-12B will be downloaded into `/mnt/c/ai_models/diffusion/text_encoders/gemma-3-12b/` and will be accessible via the `text_encoders/` symlink.

### ControlNet

| Source | Target | Command |
|--------|--------|---------|
| `/mnt/c/ai_models/diffusion/controlnet/` | `$COMFYUI_MODELS/controlnet/` | `ln -sfn $AI_MODELS/diffusion/controlnet $COMFYUI_MODELS/controlnet` |

### IP-Adapter

| Source | Target | Command |
|--------|--------|---------|
| `/mnt/c/ai_models/diffusion/ipadapter/` | `$COMFYUI_MODELS/ipadapter/` | `ln -sfn $AI_MODELS/diffusion/ipadapter $COMFYUI_MODELS/ipadapter` |

### Embeddings / Textual Inversions

| Source | Target | Command |
|--------|--------|---------|
| `/mnt/c/ai_models/diffusion/embeddings/` | `$COMFYUI_MODELS/embeddings/` | `ln -sfn $AI_MODELS/diffusion/embeddings $COMFYUI_MODELS/embeddings` |

### Upscalers

| Source | Target | Command |
|--------|--------|---------|
| `/mnt/c/ai_models/diffusion/model_patches/` | `$COMFYUI_MODELS/upscale_models/` | `ln -sfn $AI_MODELS/diffusion/model_patches $COMFYUI_MODELS/upscale_models` |

### Video Models

| Source | Target | Command |
|--------|--------|---------|
| `/mnt/c/ai_models/video/` | `$COMFYUI_MODELS/video/` | `ln -sfn $AI_MODELS/video $COMFYUI_MODELS/video` |

This covers LTX-2.3 (`video/ltx-2/`), Wan2.1 (`video/wan2.1/`), AnimateDiff (`video/animatediff/`), CogVideo (`video/CogVideo/`), and frame interpolation models.

### LTX-2.3 Specific (via video/ symlink above)

After the `video/` symlink is created, LTX-2.3 models are accessible at:
- `$COMFYUI_MODELS/video/ltx-2/ltx-2.3-22b-dev-fp8.safetensors`
- `$COMFYUI_MODELS/video/ltx-2/ltx-2.3-22b-distilled-fp8.safetensors`
- `$COMFYUI_MODELS/video/ltx-2/audio_vae/`
- `$COMFYUI_MODELS/video/ltx-2/connectors/`
- `$COMFYUI_MODELS/video/ltx-2/latent_upsampler/`

### Vision Models (CLIP Vision, BLIP, DINO)

| Source | Target | Command |
|--------|--------|---------|
| `/mnt/c/ai_models/vision/` | `$COMFYUI_MODELS/clip_vision/` | `ln -sfn $AI_MODELS/vision $COMFYUI_MODELS/clip_vision` |

---

## Existing Symlinks in ai_models

These symlinks already exist and must be preserved:

| Symlink | Points To |
|---------|----------|
| `/mnt/c/ai_cache/huggingface` | `/mnt/c/ai_models/huggingface` |
| `/mnt/c/ai_models/diffusion/lora/ltx-2.3-22b-distilled-lora-384.safetensors` | `ltxv/ltx2/ltx-2.3-22b-distilled-lora-384.safetensors` |

---

## Dry Run Command

Before applying symlinks, preview with:
```bash
bash scripts/05_setup_comfyui_model_symlinks.sh --dry-run
```

Output shows exactly what would be created or skipped.

---

## Safety Checks in Script 05

1. Check that source path exists and is non-empty
2. Check that target path either does not exist, or is an empty directory
3. If target contains real files: skip with warning, log for manual review
4. Never use `-f` flag on non-empty directories
5. Verify symlink after creation: `readlink -e <target>` must return source

---

## After Applying Symlinks

Verify:
```bash
ls -la /mnt/c/ai_tools/comfyui-rocm/models/
# All entries should show as symlinks (→) pointing to /mnt/c/ai_models/...

# Check LTX-2.3 specifically
ls /mnt/c/ai_tools/comfyui-rocm/models/video/ltx-2/
# Should list: ltx-2.3-22b-dev-fp8.safetensors, etc.
```

In ComfyUI model browser (http://localhost:8189):
- Checkpoints: should show SDXL and other models
- Video: should show ltx-2 folder
- text_encoders: should show gemma-3-12b folder (after download)
