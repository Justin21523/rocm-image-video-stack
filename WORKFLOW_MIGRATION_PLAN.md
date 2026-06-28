# Workflow Migration Plan
## CUDA ComfyUI Workflows → ROCm ComfyUI Adaptation

---

## Principle

Existing CUDA workflows are **never overwritten**. They are copied to the ROCm project directory, then adapted. The originals remain untouched.

```
Source (read-only):
  /mnt/c/ai_tools/comfyui/user/default/workflows/
  /mnt/c/ai_tools/comfyui/workflows/

Target (this project):
  /mnt/c/ai_projects/rocm-image-video-stack/workflows/comfyui-rocm/
```

---

## Migration Steps

### Step 1 — Identify Existing Workflows

Run script 00 to find all existing workflow JSON files:
```bash
find /mnt/c/ai_tools/comfyui/user/default/workflows/ -name "*.json" | sort
find /mnt/c/ai_tools/comfyui/workflows/ -name "*.json" 2>/dev/null | sort
```

### Step 2 — Copy to Migration Directory

```bash
# Copy without overwriting originals
cp -r /mnt/c/ai_tools/comfyui/user/default/workflows/ \
  /mnt/c/ai_projects/rocm-image-video-stack/workflows/comfyui-rocm/cuda_originals/

# Mark as read-only reference copies
chmod -R a-w \
  /mnt/c/ai_projects/rocm-image-video-stack/workflows/comfyui-rocm/cuda_originals/
```

### Step 3 — Audit Node Types in Each Workflow

For each workflow JSON, identify nodes that may be CUDA-specific:
```bash
# Find all node class_type values in a workflow
python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    wf = json.load(f)
nodes = wf.get('nodes', []) or list(wf.values())
for n in nodes:
    ct = n.get('type') or n.get('class_type', '')
    if ct:
        print(ct)
" <workflow.json> | sort -u
```

### Step 4 — Apply Adaptations

Create adapted copy in target directory:
```bash
cp workflows/comfyui-rocm/cuda_originals/<name>.json \
   workflows/comfyui-rocm/<name>_rocm.json
# Then edit the _rocm.json version
```

---

## Node Adaptation Guide

### Nodes That Work As-Is (No Changes Needed)

| Node | Notes |
|------|-------|
| `KSampler` | Standard sampler; ROCm compatible |
| `KSamplerAdvanced` | Same as above |
| `CLIPTextEncode` | Text encoding; ROCm compatible |
| `CheckpointLoaderSimple` | Model loading; ROCm compatible |
| `VAEDecode` | Decoding; ROCm compatible |
| `VAEEncode` | Encoding; ROCm compatible |
| `LoRALoader` | LoRA loading; ROCm compatible |
| `ControlNetLoader` | Loading; ROCm compatible |
| `ControlNetApply` | Application; ROCm compatible |
| `IPAdapterLoader` | IP-Adapter; ROCm compatible |
| `SaveImage` | Saving; no GPU required |
| `LoadImage` | Loading; no GPU required |
| `ImageScale` | CPU resize; no GPU required |

### Nodes to Replace or Disable

| Original Node | ROCm Alternative | Action |
|---------------|-----------------|--------|
| `xformers.*` attention nodes | Remove; use default SDPA | Delete node, rewire |
| Any node with `cuda_` prefix | Inspect and replace | Case by case |
| `BitsAndBytesNF4ModelLoader` | Avoid; use GGUF instead | Replace with UNETLoader+GGUF |
| Nodes requiring `flash_attn` directly | Check ROCm build | Test or skip |

### LTX Video Nodes (From CUDA ComfyUI-LTXVideo)

These nodes should work if ComfyUI-LTXVideo is installed and validated in ROCm ComfyUI:

| Node | Expected Status |
|------|----------------|
| `LTXSampler` | Test required |
| `LTXModelCheckpointLoader` | Test required (FP8 risk) |
| `LTXGemmaTextEncode` | Test required |
| `LTXICLoRALoaderModelOnly` | Test after base workflow works |
| `LTXLatentUpsampler` | Test after base workflow works |

---

## Workflow Categories

### Category 1 — LTX-2.3 Workflows
```
Target: workflows/ltx23/
```
- Copy from CUDA ComfyUI if they exist
- If not: build from scratch using official templates from ComfyUI-LTXVideo
- Start with T2V minimal, then I2V, then upscaler

### Category 2 — Image-to-Video Workflows
```
Target: workflows/image-to-video/
```
- LTX-2.3 I2V workflow
- AnimateDiff I2V (if AnimateDiff ROCm validated)
- Wan2.1 I2V (future)

### Category 3 — Text-to-Video Workflows
```
Target: workflows/text-to-video/
```
- LTX-2.3 T2V (standard)
- LTX-2.3 T2V (two-stage upscaling)
- LTX-2.3 T2V (portrait 9:16)

### Category 4 — Validation Workflows
```
Target: workflows/validation/
```
- Simple SDXL 512×512 (system check)
- LTX-2.3 minimal 256×144 9 frames (smoke test)
- Video export round-trip (FFmpeg check)

---

## Model Path Updates

When copying workflows, model paths referenced inside JSON nodes may need updating if the CUDA install used different symlink names. Check each workflow for:
```json
"model_name": "models/checkpoints/sdxl_base.safetensors"
```

The ROCm ComfyUI uses the same relative `models/` path structure via symlinks, so most paths should work unchanged.

For LTX-specific paths, verify ComfyUI-LTXVideo can auto-discover models from:
- `models/video/ltx-2/` (via symlink)
- `models/text_encoders/gemma-3-12b/` (via symlink)

---

## Workflow JSON Naming Convention

| Type | Format |
|------|--------|
| Original (unmodified copy) | `cuda_originals/<original_name>.json` |
| ROCm adapted version | `<category>/<name>_rocm.json` |
| Validated and working | `<category>/<name>_rocm_validated.json` |
| WIP / experimental | `<category>/<name>_wip.json` |

---

## Do Not Store In This Directory

- Any large binary files (models, videos, images)
- Workflow outputs or generated content
- Log files (use `logs/` instead)
- Scripts (use `scripts/` instead)
