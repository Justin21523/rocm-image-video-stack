# LTX 2.3 Research Report
## AMD ROCm Deployment Analysis for Radeon AI PRO R9700

*Research date: 2026-05-06 | Sources: official documentation, GitHub, Hugging Face, AMD ROCm docs*

---

## Executive Summary

LTX-2.3 is Lightricks' flagship 22-billion-parameter video generation model. It generates synchronized video and audio in a single forward pass. As of May 2026, it is the recommended local video generation model and is officially supported in ComfyUI.

For AMD gfx1201 (R9700 32 GB):
- **FP8 models are already downloaded** locally — but FP8 *compute* is broken on gfx1201. ComfyUI-LTXVideo likely dequantizes weights to BF16 on load; this needs validation.
- **Fallback**: GGUF variants from QuantStack work via ComfyUI-GGUF and llama.cpp (fully ROCm compatible)
- **Missing**: Gemma-3-12B text encoder (24.4 GB) — must download before first generation
- **First workflow**: Distilled T2V at 1216×704, 8 steps, BF16 compute mode

---

## 1. Official Sources

### Primary Documentation
- **LTX Documentation Portal**: https://docs.ltx.video
- **LTX Model Overview**: https://ltx.io/model/ltx-2-3
- **System Requirements**: https://docs.ltx.video/open-source-model/getting-started/system-requirements
- **ComfyUI Integration Guide**: https://docs.ltx.video/open-source-model/integration-tools/comfy-ui
- **LoRA Training Guide**: https://docs.ltx.video/open-source-model/usage-guides/lo-ra

### GitHub Repositories
- **LTX-2 (main)**: https://github.com/Lightricks/LTX-2
- **ComfyUI-LTXVideo (official)**: https://github.com/Lightricks/ComfyUI-LTXVideo
- **Awesome LTX-2 community index**: https://github.com/wildminder/awesome-ltx2

### Hugging Face
- **Lightricks organization**: https://huggingface.co/Lightricks
- **LTX-2.3 collection**: https://huggingface.co/collections/Lightricks/ltx-23
- **Primary model card**: https://huggingface.co/Lightricks/LTX-2.3

### ComfyUI Official Tutorials
- **LTX-2.3 tutorial**: https://docs.comfy.org/tutorials/video/ltx/ltx-2-3
- **Example workflows**: https://github.com/Lightricks/ComfyUI-LTXVideo/tree/master/example_workflows/2.3

### AMD ROCm Official
- **LTX-Video on ROCm**: https://rocm.docs.amd.com/projects/ai-developer-hub/en/latest/notebooks/inference/t2v_comfyui_radeon.html

---

## 2. Architecture

### Core Design
| Component | Details |
|-----------|---------|
| Model type | Diffusion Transformer (DiT) |
| Total parameters | 22 billion |
| Video stream | ~14B parameters |
| Audio stream | ~5B parameters |
| Coupling | Bidirectional cross-attention between video and audio streams |
| Timestep conditioning | Shared across both streams |
| Text encoder | Google Gemma-3-12B instruction-tuned |
| VAE | Redesigned (v2 latent space — incompatible with LTX 2.0) |
| Precision | BF16 native, FP8 quantized variants available |

### Key Innovation: Gated Attention Text Connector
- 4× larger than the text connector in LTX 2.0
- Dramatically improves prompt adherence
- Architecture introduced in LTX 2.3, not present in LTX 2.0

### Supported Resolutions
| Aspect | Resolutions |
|--------|------------|
| Landscape | 1280×720, 1920×1080, 2560×1440, 3840×2160 |
| Portrait | 720×1280, 1080×1920 (native 9:16, not cropped) |
| Cinema | 1216×704 (recommended for local inference) |

### Supported Frame Rates
- 24, 25, 48, 50 fps (new in 2.3: 24/48 fps options)

### Frame Count Formula
- Must be: `(N × 8) + 1` — e.g., 9, 17, 25, 33, 41, 49, 57, 65 frames
- Violating this causes silent generation failure

### Maximum Duration
- Up to 20 seconds continuous per generation

---

## 3. Model Files

### Complete Model Manifest

| Model | File | Size | HF Source | Local Status | Priority |
|-------|------|------|-----------|--------------|----------|
| LTX-2.3 Dev FP8 | `ltx-2.3-22b-dev-fp8.safetensors` | 29 GB | Lightricks/LTX-2.3 | **DOWNLOADED** | 1 |
| LTX-2.3 Distilled FP8 | `ltx-2.3-22b-distilled-fp8.safetensors` | 29.5 GB | Lightricks/LTX-2.3 | **DOWNLOADED** | 1 |
| Audio VAE | `audio_vae/` | ~1 GB | Lightricks/LTX-2.3 | **DOWNLOADED** | 1 |
| Connectors | `connectors/` | ~0.5 GB | Lightricks/LTX-2.3 | **DOWNLOADED** | 1 |
| Latent Upsampler | `latent_upsampler/` | ~0.5 GB | Lightricks/LTX-2.3 | **DOWNLOADED** (verify files) | 1 |
| Gemma-3-12B Text Encoder | `gemma_3_12B_it.safetensors` | 24.4 GB | Comfy-Org/ltx-2 | **MISSING — REQUIRED** | 1 |
| Distilled LoRA | `ltx-2.3-22b-distilled-lora-384.safetensors` | ~384 MB | Lightricks/LTX-2.3 | **MISSING** | 2 |
| Spatial Upscaler x2 | `ltx-2.3-spatial-upscaler-x2-1.1.safetensors` | ~1 GB | Lightricks/LTX-2.3 | Unknown | 3 |
| Spatial Upscaler x1.5 | `ltx-2.3-spatial-upscaler-x1.5-1.0.safetensors` | ~0.5 GB | Lightricks/LTX-2.3 | Unknown | 3 |
| Temporal Upscaler x2 | `ltx-2.3-temporal-upscaler-x2-1.0.safetensors` | ~0.5 GB | Lightricks/LTX-2.3 | Unknown | 4 |
| BF16 Full Model | `ltx-2.3-22b.safetensors` | ~46 GB | Lightricks/LTX-2.3 | Not downloaded (too large) | — |
| NV FP4 | `ltx-2.3-22b-nvfp4.safetensors` | ~8–12 GB | Lightricks/LTX-2.3 | Not downloaded | — |

### IC-LoRAs (Image Conditioning)

| LoRA | Source | Use Case | Size |
|------|--------|----------|------|
| Motion Track Control | `Lightricks/LTX-2.3-22b-IC-LoRA-Motion-Track-Control` | Guide motion with sparse point trajectories | ~1 GB |
| Union Control | `Lightricks/LTX-2.3` | Combined depth + canny edge control | ~1 GB |
| HDR IC-LoRA | `Lightricks/LTX-2.3` | ARRI LogC3 linear HDR output | ~1 GB |

### ID-LoRAs (Identity Preservation)

| LoRA | Source | Use Case |
|------|--------|----------|
| CelebV-HQ | `AviadDahan/LTX-2.3-ID-LoRA-CelebVHQ` | Face/appearance transfer |
| TalkVid-3K | `AviadDahan/LTX-2.3-ID-LoRA-TalkVid-3K` | Talking video generation |

### GGUF Variants (ROCm Fallback)

| Source | Quantization | Size | Notes |
|--------|-------------|------|-------|
| `QuantStack/LTX-2.3-GGUF` | Q4_K_M | ~8 GB | Good quality, fast |
| `QuantStack/LTX-2.3-GGUF` | Q6_K | ~12 GB | Higher quality |
| `QuantStack/LTX-2.3-GGUF` | Q8_0 | ~17 GB | Near-lossless |
| `unsloth/LTX-2.3-GGUF` | Various | 8–17 GB | Alternative source |

GGUF variants work via `ComfyUI-GGUF` node, using llama.cpp compute path (fully ROCm compatible on gfx1201).

---

## 4. Workflow Types

### Text-to-Video (T2V)
- Primary workflow; recommended starting point
- Input: text prompt
- Node: `LTXSampler`
- Recommended settings for R9700:
  - Resolution: 1216×704
  - FPS: 24
  - Steps: 8 (distilled model) or 30–50 (full model)
  - CFG: 1.0 (distilled) or 5.0–7.0 (full model)
  - Frames: 49 (5 seconds) or 97 (9.5 seconds)
- Source: https://docs.comfy.org/tutorials/video/ltx/ltx-2-3

### Image-to-Video (I2V)
- Input: reference image + text prompt
- Uses image conditioning to guide first frame
- Node: image input to `LTXSampler` with conditioning strength
- Typically takes same time as T2V

### Audio-Video Generation
- LTX-2.3 can generate synchronized audio natively
- Requires: `audio_vae/` directory (already downloaded)
- Output: MP4 with audio track
- Not all community workflows enable audio output

### Portrait Video (9:16)
- Native support in LTX-2.3 (not cropped from landscape)
- Resolution: 720×1280 or 1080×1920
- Fewer community workflow examples than landscape
- Standard `LTXSampler` with portrait resolution settings

### Latent Upscaling (2-Stage Pipeline)
- Stage 1: Generate at lower resolution (e.g., 768×448)
- Stage 2: Run `LTXLatentUpsampler` to 2× size (1536×896)
- Benefits: faster stage 1, better coherence than direct high-res
- Requires: `ltx-2.3-spatial-upscaler-x2-1.1.safetensors`

### IC-LoRA: Motion Track Control
- Input: sparse point trajectories on video frames
- LoRA guides motion to follow specified paths
- Node: `LTXICLoRALoaderModelOnly` + `LTXAddVideoICLoRAGuide`
- Use case: control camera motion, object movement

### IC-LoRA: Union Control
- Input: depth map + canny edge map
- Combines structural control with semantic content
- Higher quality than single-control IC-LoRA

### IC-LoRA: HDR Output
- Output: ARRI LogC3 linear HDR video (EXR format)
- Use case: professional post-production, color grading

### ID-LoRA: Identity Preservation
- Input: reference face/person image
- Maintains appearance across video frames
- Node: same as IC-LoRA but with identity conditioning

---

## 5. ComfyUI Integration

### Status
As of May 2026, LTX-2 is **officially integrated** into ComfyUI core and supported via `ComfyUI-LTXVideo`.

### Installation
```bash
# Via ComfyUI-Manager: search "LTXVideo" → Install
# Or manual:
git clone https://github.com/Lightricks/ComfyUI-LTXVideo \
  ComfyUI/custom_nodes/ComfyUI-LTXVideo
pip install -r ComfyUI/custom_nodes/ComfyUI-LTXVideo/requirements.txt \
  -c constraints.txt
```

### Key Nodes

| Node | Function |
|------|---------|
| `LTXSampler` | Main inference: T2V and I2V |
| `LTXModelCheckpointLoader` | Load .safetensors model |
| `LTXICLoRALoaderModelOnly` | Load IC-LoRA with reference downscale factor |
| `LTXAddVideoICLoRAGuide` | Apply IC-LoRA control signal |
| `LTXLatentUpsampler` | Spatial upscale in latent space |
| `LTXTemporalUpsampler` | Temporal upscale (double FPS) |
| `LTXGemmaTextEncode` | Encode text with Gemma-3-12B |

### Templates Available in ComfyUI
After installing ComfyUI-LTXVideo, load from ComfyUI Templates menu:
- LTX-2.3 → Text to Video
- LTX-2.3 → Image to Video
- LTX-2.3 → Two-Stage Upscaling

---

## 6. LTX 2.0 vs 2.3 Breaking Changes

### Architecture Changes

| Aspect | LTX 2.0 | LTX 2.3 |
|--------|---------|---------|
| Parameters | ~8B | 22B (2.75× larger) |
| Architecture | Standard DiT | Dual-stream: video + audio |
| VAE | v1 | v2 (redesigned) |
| Text encoder | Smaller connector | Gemma-3-12B + 4× larger connector |
| Latent space | v1 | v2 (incompatible with v1) |
| Audio | No | Native synchronized audio |
| Portrait | Cropped from landscape | Native 9:16 training |

### LoRA Compatibility

**LTX 2.0 LoRAs are COMPLETELY INCOMPATIBLE with LTX 2.3.**

There is no conversion script, no workaround, no compatibility layer. Attempting to use a LTX 2.0 LoRA on LTX 2.3 produces garbage output because:
1. The latent space dimensions and encoding are different
2. The transformer architecture is different
3. The text encoder is different

**Action required**: All custom LoRAs trained for LTX 2.0 must be retrained from scratch using LTX-2.3 checkpoints.

Note: The existing LoRA files in `/mnt/c/ai_models/diffusion/lora/ltx/` and `ltxv/` were likely trained on LTX 2.0. They will not work on LTX 2.3.

### Quality Improvements
- PSNR improvement: ~2.5 dB (visibly sharper)
- Better prompt following (larger text connector)
- Cleaner frame consistency
- Less temporal artifacts

---

## 7. VRAM Requirements

| Configuration | VRAM | Notes |
|---------------|------|-------|
| BF16 full model | ~46 GB | Does not fit in 32 GB VRAM |
| FP8 model (if weights dequantize to BF16 compute) | ~17–24 GB | R9700 32 GB: should fit |
| Distilled FP8 | ~17–24 GB | Same as FP8 + faster inference |
| GGUF Q4_K_M | ~8–12 GB | Very comfortable for 32 GB |
| + Gemma-3-12B text encoder | +12–24 GB additional | Loads alongside main model |

**R9700 32 GB estimate**: FP8 model (~24 GB) + Gemma-3-12B loaded partially (~8 GB active) = ~32 GB total. May be tight; expect auto-offloading to system RAM for parts of Gemma.

---

## 8. ROCm Risk Analysis

### gfx1201 (R9700) FP8 Issue

**Issue**: PyTorch ROCm on gfx1201 does not support FP8 *compute* operations.

```
NotImplementedError: "aten::mm": not implemented for 'Float8_e4m3fn'
```

Source: https://github.com/ROCm/ROCm/issues/6019

**What this means for LTX 2.3**:
- The downloaded models store weights in FP8 format (file extension reveals nothing — it's the internal dtype)
- If ComfyUI-LTXVideo dequantizes these weights to BF16/FP16 on load: **models will work**
- If ComfyUI-LTXVideo attempts to run FP8 matrix multiplications: **error**

**How to determine**: Run `10_validate_ltx23_comfyui_workflow.sh` and observe the error output.

**Fallback plan (if FP8 load fails)**:
1. Install `ComfyUI-GGUF` custom node
2. Download `QuantStack/LTX-2.3-GGUF` Q4_K_M or Q6_K variant
3. Use GGUF model instead (llama.cpp compute path, fully ROCm compatible)
4. Alternatively, download the BF16 base checkpoint (46 GB — too large for VRAM, but can use --cpu offload for Gemma)

### xformers
**Status**: Disabled. Use `--disable-xformers --use-pytorch-cross-attention` flags.
PyTorch's SDPA (scaled dot-product attention) is the safe alternative on ROCm.

### Flash Attention
**Status**: ComfyUI-LTXVideo may require flash-attn. Build from `ROCm/flash-attention` source.
PyTorch 2.5+ includes native Flash Attention on ROCm backend as fallback.

### bitsandbytes
**Status**: Untested on gfx1201. Avoid 4-bit/8-bit quantization until validated.

### Triton
**Status**: Safe. Bundled with PyTorch ROCm. AOTriton 0.11b supports gfx1201.

### torch.compile
**Status**: Needs testing on gfx1201. `backend='aot_eager'` is safer than `backend='inductor'`.

---

## 9. Recommended R9700 32 GB Starting Settings

### First Generation (Distilled T2V)

```
Model:      ltx-2.3-22b-distilled-fp8.safetensors
Sampler:    LTXSampler (distilled mode)
Scheduler:  flow_match (LTX default)
Steps:      8
CFG scale:  1.0
Resolution: 1216 × 704
FPS:        24
Frames:     49 (5 seconds)
Seed:       random
```

### After Validation (Full Dev Model)

```
Model:      ltx-2.3-22b-dev-fp8.safetensors
Steps:      30–50
CFG scale:  5.0–7.0
Resolution: 1216 × 704
FPS:        24
Frames:     49–97
```

### VRAM Management Settings
```bash
export PYTORCH_HIP_ALLOC_CONF="garbage_collection_threshold:0.7,max_split_size_mb:128"
# If running tight: garbage_collection_threshold:0.5,max_split_size_mb:64
```

### Fallback: GGUF Workflow
```
Model:      LTX-2.3-Q4_K_M.gguf (from QuantStack)
Node:       ComfyUI-GGUF → LTXGGUFModelLoader
Steps:      8 (distilled) or 30 (full)
Resolution: 1216 × 704
Expected VRAM: ~8 GB model + ~12 GB Gemma = ~20 GB total
```

---

## 10. Validation Order

1. **ROCm PyTorch test** — verify GPU and BF16 compute before loading any model
2. **ComfyUI startup** — verify ComfyUI starts clean on port 8189
3. **SDXL test** — verify standard image generation works (simpler than video)
4. **LTX 2.3 model audit** — run script 09 in read-only mode to check what's missing
5. **Download Gemma-3-12B** — required before any generation (after approval)
6. **Install ComfyUI-LTXVideo** — with constraints.txt
7. **LTX 2.3 minimal T2V** — `256×144`, 9 frames (1 second), 8 steps
8. **LTX 2.3 standard T2V** — `1216×704`, 49 frames, 8 steps
9. **LTX 2.3 I2V** — with reference image
10. **LTX 2.3 upscaler** — 2-stage pipeline

---

## 11. Fallback Plan

If `ComfyUI-LTXVideo` fails on ROCm gfx1201:

### Option A — GGUF via ComfyUI-GGUF
1. Install `ComfyUI-GGUF` custom node (ROCm compatible via llama.cpp)
2. Download `QuantStack/LTX-2.3-GGUF` Q6_K variant
3. Use `LTXGGUFModelLoader` instead of `LTXModelCheckpointLoader`
4. Same workflow structure, different model loader node

### Option B — LTX-2 Python Package Directly
Use `/mnt/c/ai_tools/LTX-2/` Python package in `rocm-ltx23-r9700` env:
```bash
conda activate rocm-ltx23-r9700
cd /mnt/c/ai_tools/LTX-2
pip install -e .[inference] -c constraints.txt
python -m ltx_pipelines.text_to_video \
  --model /mnt/c/ai_models/video/ltx-2/ltx-2.3-22b-distilled-fp8.safetensors \
  --prompt "A man playing guitar" \
  --output output.mp4
```
This bypasses ComfyUI entirely and uses the official Python API.

### Option C — ROCm Offload Mode
If full model doesn't fit, use `--cpu-vae` or manual model offloading flags in ComfyUI to move VAE to CPU.

---

## 12. Community Resources

- **Awesome LTX-2**: https://github.com/wildminder/awesome-ltx2 — model index, desktop configs, community LoRAs
- **ComfyUI official LTX tutorials**: https://docs.comfy.org/tutorials/video/ltx/ltx-2-3
- **WaveSpeed LTX 2.0→2.3 upgrade guide**: https://wavespeed.ai/blog/posts/ltx-2-to-2-3-upgrade-guide-2026/
- **AMD ROCm ComfyUI blog**: https://rocm.blogs.amd.com/artificial-intelligence/comfyui-radeon-9000/README.html
- **ROCm WSL2 setup guide**: https://craftrigs.com/guides/rocm-on-wsl2-amd-gpu-setup-that-actually-works/
- **TheROCk LTX-2 discussion (Strix Halo success)**: https://github.com/ROCm/TheRock/discussions/2845

---

## 13. Important Caveats

1. **FP8 compute broken on gfx1201** — test before assuming failure; weights may dequantize to BF16
2. **English-only prompts** — model trained on English; other languages degrade quality
3. **Frame count formula strictly enforced** — `(N×8)+1` only; invalid counts cause silent failure
4. **CFG scale sensitivity** — distilled model is very sensitive to CFG; 0.5 difference is significant
5. **First Gemma load is slow** — 24.4 GB loads in several minutes; subsequent loads are instant (cached)
6. **VRAM overhead** — LTX 2.3 uses ~1 GB more VRAM than LTX 2.0 at identical settings
7. **Audio generation** — requires audio_vae/ directory; not all workflows enable audio output
8. **ROCm + WSL2 driver sync** — AMD Adrenalin driver and ROCm version must be compatible; mismatches cause device init failures
