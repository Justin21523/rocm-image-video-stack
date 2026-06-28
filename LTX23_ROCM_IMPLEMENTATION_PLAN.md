# LTX 2.3 ROCm Implementation Plan
## Practical Step-by-Step Guide for AMD Radeon AI PRO R9700

---

## Pre-Conditions

Before beginning LTX 2.3 implementation, the following must be complete:

- [ ] Phase 3: ComfyUI ROCm installed at `/mnt/c/ai_tools/comfyui-rocm/`
- [ ] Phase 4: Model symlinks created (video/ directory linked)
- [ ] Phase 5: ComfyUI-Manager and Green-tier nodes installed
- [ ] PyTorch validation: `torch.cuda.is_available()` returns True

---

## Step 1 — Model Audit (Safe, No Approval)

Run script 09 in audit mode:
```bash
bash scripts/09_prepare_ltx23_models.sh --audit-only
```

This checks local paths and generates a checklist. Expected output:

```
[OK]     /mnt/c/ai_models/video/ltx-2/ltx-2.3-22b-dev-fp8.safetensors (29 GB)
[OK]     /mnt/c/ai_models/video/ltx-2/ltx-2.3-22b-distilled-fp8.safetensors (29.5 GB)
[OK]     /mnt/c/ai_models/video/ltx-2/audio_vae/ (directory)
[OK]     /mnt/c/ai_models/video/ltx-2/connectors/ (directory)
[OK]     /mnt/c/ai_models/video/ltx-2/latent_upsampler/ (directory, verify contents)
[MISSING] Gemma-3-12B text encoder (~24.4 GB) — REQUIRED
[MISSING] ltx-2.3-22b-distilled-lora-384.safetensors (~384 MB) — recommended
[MISSING] ltx-2.3-spatial-upscaler-x2-1.1.safetensors (~1 GB) — optional
```

---

## Step 2 — Download Missing Models (Requires Approval)

After explicit approval, run:
```bash
bash scripts/09_prepare_ltx23_models.sh --download
```

### Downloads Required

#### Priority 1 — Gemma-3-12B Text Encoder (REQUIRED, 24.4 GB)
```bash
conda activate rocm-comfyui-r9700
huggingface-cli download Comfy-Org/ltx-2 \
  split_files/text_encoders/gemma_3_12B_it.safetensors \
  --local-dir /mnt/c/ai_models/diffusion/text_encoders/gemma-3-12b/
```

#### Priority 2 — Distilled LoRA (~384 MB)
```bash
huggingface-cli download Lightricks/LTX-2.3 \
  ltx-2.3-22b-distilled-lora-384.safetensors \
  --local-dir /mnt/c/ai_models/video/ltx-2/
```

#### Priority 3 — Spatial Upscaler (~1 GB)
```bash
huggingface-cli download Lightricks/LTX-2.3 \
  ltx-2.3-spatial-upscaler-x2-1.1.safetensors \
  --local-dir /mnt/c/ai_models/video/ltx-2/
```

---

## Step 3 — Install ComfyUI-LTXVideo (Requires Approval)

```bash
conda activate rocm-comfyui-r9700
cd /mnt/c/ai_tools/comfyui-rocm/custom_nodes

git clone https://github.com/Lightricks/ComfyUI-LTXVideo
pip install -r ComfyUI-LTXVideo/requirements.txt \
  -c /mnt/c/ai_tools/comfyui-rocm/constraints.txt
```

### If Flash Attention Required
ComfyUI-LTXVideo may import `flash_attn`. If it fails on ROCm:

**Option A — Build from source:**
```bash
git clone https://github.com/ROCm/flash-attention
cd flash-attention
PYTORCH_ROCM_ARCH=gfx1201 pip install -e . \
  -c /mnt/c/ai_tools/comfyui-rocm/constraints.txt
export FLASH_ATTENTION_TRITON_AMD_AUTOTUNE=TRUE
```

**Option B — Patch the import:**
```python
# In ComfyUI-LTXVideo, find lines like:
# from flash_attn import flash_attn_func
# Replace with:
flash_attn_func = None  # Fallback to PyTorch SDPA
```

**Option C — Use GGUF model path** (avoids flash-attn requirement in some nodes):
See Step 6b below.

---

## Step 4 — Verify ComfyUI-LTXVideo Loaded

Start ComfyUI and check:
```bash
conda activate rocm-comfyui-r9700
cd /mnt/c/ai_tools/comfyui-rocm
python main.py --listen 0.0.0.0 --port 8189 \
  --use-pytorch-cross-attention --disable-xformers 2>&1 | head -50
```

Look for:
```
[LTXVideo] Loaded successfully
```
Or errors indicating what's missing.

---

## Step 5 — Symlink Gemma-3-12B to ComfyUI text_encoders

After download, verify symlink is correct:
```bash
ls /mnt/c/ai_tools/comfyui-rocm/models/text_encoders/
# Should show gemma-3-12b/ directory (via symlink from /mnt/c/ai_models/diffusion/text_encoders/)
```

---

## Step 6a — First LTX 2.3 T2V Generation (FP8 Path)

Load the official T2V template in ComfyUI (http://localhost:8189):

1. Templates → LTX-2.3 → Text to Video
2. Configure nodes:

```
LTXModelCheckpointLoader:
  model_path: models/video/ltx-2/ltx-2.3-22b-distilled-fp8.safetensors

LTXGemmaTextEncode:
  model_path: models/text_encoders/gemma-3-12b/gemma_3_12B_it.safetensors
  prompt: "A golden retriever running on a beach, waves in background, cinematic lighting"
  negative_prompt: "blurry, low quality, static, frozen"

LTXSampler:
  steps: 8
  cfg: 1.0
  width: 1216
  height: 704
  frames: 49
  fps: 24
  seed: <random>
```

3. Click Queue Prompt
4. Expected: ~3–6 minutes for 5-second video

### If FP8 Compute Error
Watch for:
```
NotImplementedError: "aten::mm": not implemented for 'Float8_e4m3fn'
```

This means FP8 *compute* was attempted. Proceed to Step 6b.

---

## Step 6b — Fallback: GGUF Model Path

If FP8 loading fails, install GGUF support:

```bash
cd /mnt/c/ai_tools/comfyui-rocm/custom_nodes
git clone https://github.com/city96/ComfyUI-GGUF
pip install -r ComfyUI-GGUF/requirements.txt \
  -c /mnt/c/ai_tools/comfyui-rocm/constraints.txt
```

Download GGUF model:
```bash
huggingface-cli download QuantStack/LTX-2.3-GGUF \
  ltx-2.3-22b-Q6_K.gguf \
  --local-dir /mnt/c/ai_models/video/ltx-2/gguf/
```

Then use `ComfyUI-GGUF → UNETLoader` instead of `LTXModelCheckpointLoader` in the workflow.

---

## Step 7 — Image-to-Video Workflow

After T2V works:

1. Load Template → LTX-2.3 → Image to Video
2. Connect a reference image to the image input of `LTXSampler`
3. Adjust `strength` parameter (0.7–0.9 for strong conditioning)
4. Use same settings as T2V otherwise

Expected: video that animates from the reference image.

---

## Step 8 — Two-Stage Upscaling

After I2V works:

Stage 1 (low resolution):
```
Resolution: 768 × 448
Frames: 49
Steps: 8
```

Stage 2 (latent upscale):
```
LTXLatentUpsampler:
  model: models/video/ltx-2/ltx-2.3-spatial-upscaler-x2-1.1.safetensors
  scale_factor: 2
  frames: same 49
```

Output: 1536×896 video with 2× spatial detail.

---

## R9700 32 GB Specific Settings Reference

| Parameter | Minimal Test | Standard | High Quality |
|-----------|-------------|----------|--------------|
| Model | distilled-fp8 | distilled-fp8 | dev-fp8 |
| Steps | 8 | 8 | 30–50 |
| CFG | 1.0 | 1.0 | 5.0–7.0 |
| Resolution | 256×144 | 1216×704 | 1920×1080 |
| Frames | 9 | 49 | 97 |
| FPS | 24 | 24 | 24 |
| Expected VRAM | ~10 GB | ~28 GB | ~32 GB (tight) |
| Expected time | ~30s | ~3–6 min | ~15–25 min |

**Note**: For 1920×1080 you may hit VRAM limits. Use `--normalvram` flag and add `PYTORCH_HIP_ALLOC_CONF=garbage_collection_threshold:0.5` for aggressive cleanup.

---

## Debug Flowchart

```
[Start]
  │
  ▼
torch.cuda.is_available() == True?
  No → Check HIP_VISIBLE_DEVICES, rocm-smi, /dev/dri/
  Yes ↓
  │
  ▼
ComfyUI starts on port 8189?
  No → Check conda env, import errors in log
  Yes ↓
  │
  ▼
LTXVideo nodes appear in ComfyUI?
  No → Check custom_nodes/ComfyUI-LTXVideo install, restart ComfyUI
  Yes ↓
  │
  ▼
Gemma-3-12B loads?
  No → Verify text_encoders/ symlink, re-download if corrupt
  Yes ↓
  │
  ▼
LTX model loads?
  FP8 error → Go to GGUF fallback (Step 6b)
  OOM → Reduce resolution/frames, add --lowvram
  Yes ↓
  │
  ▼
Sampler runs?
  NaN outputs → Check CFG scale (distilled needs CFG 1.0)
  Slow → Expected; 32GB R9700 takes 3–6 min for 5s video
  Yes ↓
  │
  ▼
VAE decode → video file
  Corrupt video → Check frame count (must be N×8+1)
  Yes ↓
  │
  ▼
[SUCCESS] Save workflow to workflows/ltx23/
```

---

## Expected Performance on R9700 32 GB

| Task | Estimated Time | Notes |
|------|---------------|-------|
| First model load (Gemma-3-12B) | 3–8 minutes | One-time; cached after |
| Subsequent model loads | 30–60 seconds | From SSD cache |
| T2V 1216×704 5s distilled (8 steps) | 3–6 minutes | Main use case |
| T2V 1216×704 10s distilled (8 steps) | 6–12 minutes | |
| T2V 1216×704 5s full dev (30 steps) | 10–20 minutes | |
| I2V 1216×704 5s distilled | ~same as T2V | |
| Spatial upscale 2× | +1–2 minutes | Incremental |
| GGUF Q6_K 5s distilled | ~same or faster | Less VRAM pressure |
