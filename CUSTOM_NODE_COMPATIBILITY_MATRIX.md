# Custom Node Compatibility Matrix
## ROCm/AMD gfx1201 Risk Classification

*Based on ROCm 7.2.3, PyTorch 2.5.1+rocm6.2, gfx1201 (RDNA4 R9700)*

---

## Risk Tiers

| Tier | Color | Meaning |
|------|-------|---------|
| Green | Safe | Pure Python or explicitly ROCm-supported; install freely |
| Yellow | Needs testing | May have ROCm-compatible path; test before production use |
| Orange | Known issues | Works with specific workarounds or env var settings |
| Red | Avoid initially | CUDA-only dependencies or known failures on ROCm/gfx1201 |

---

## Green Tier — Safe to Install

| Node | Reason | Phase to Install |
|------|--------|-----------------|
| **ComfyUI-Manager** | Pure Python; only manages other nodes; no GPU code | Phase 5 |
| **rgthree-comfy** | Utility nodes; no GPU-specific code | Phase 5 |
| **ComfyUI-Custom-Scripts** | UI scripts and utilities; no GPU code | Phase 5 |
| **ImageMetaHub-ComfyUI-Save** | Image save utilities; no GPU code | Phase 5 |
| **ComfyUI_IPAdapter_plus** | Explicit ROCm support added; tests confirm working | Phase 5 |
| **ComfyUI-VideoHelperSuite** | Wraps FFmpeg for video I/O; FFmpeg has AMF/ROCm support | Phase 5 |
| **websocket_image_save.py** | Simple script; no GPU code | Phase 5 |

### Why They Are Safe
- No direct CUDA API calls
- No `import xformers` or `import flash_attn` in core paths
- No bitsandbytes dependency
- FFmpeg wrapper nodes use subprocess, not GPU compute directly

---

## Yellow Tier — Needs Testing

| Node | Risk Reason | Mitigation | Phase |
|------|------------|-----------|-------|
| **ComfyUI-LTXVideo** | May require flash-attn; FP8 compute paths | Build flash-attn from ROCm/flash-attention source; or patch import; or use GGUF path | Phase 6 |
| **ComfyUI-GGUF** | Depends on llama-cpp-python ROCm build | Build llama-cpp-python with `CMAKE_ARGS="-DGGML_HIPBLAS=ON"`; or use pre-built ROCm binary | Phase 6 |
| **ComfyUI_essentials** | Potential dependencies on PyTorch-specific ops | Test basic workflow; report any `aten::` errors | Phase 5 |
| **ComfyUI-KJNodes** | Unknown PyTorch ops; no ROCm-specific testing found | Test node by node; skip problematic ones | Phase 7 |
| **ComfyUI-WanVideoWrapper** | Wan2.1 video wrapper; may have custom CUDA kernels | Check requirements.txt; test with Wan2.1 model | Phase 9 |
| **comfyui_controlnet_aux** | Depth estimation models; some use custom ops | Most preprocessors are pure PyTorch; test each | Phase 7 |
| **ComfyUI-Frame-Interpolation** | RIFE interpolation may have CUDA-specific code | Check for `cupy` dependency; RIFE PyTorch version should work | Phase 9 |
| **ComfyUI-CogVideoXWrapper** | CogVideo model wrapper; unknown ROCm status | Test after other workflows established | Later |
| **RES4LYF** | Large custom node pack; unknown ROCm testing | Test specific workflows only | Later |
| **rs-nodes** | Unknown dependencies | Review requirements.txt before installing | Later |
| **ComfyUI-InstantID** | Face identity; depends on insightface | insightface has no GPU-specific ROCm issues; test | Phase 8 |

---

## Orange Tier — Known Issues with Workarounds

| Node | Known Issue | Workaround | Severity |
|------|------------|-----------|---------|
| **ComfyUI-AnimateDiff-Evolved** | VRAM fragmentation on ROCm; memory hits 100% on second run | Set `PYTORCH_HIP_ALLOC_CONF=garbage_collection_threshold:0.7,max_split_size_mb:128`; restart between runs if VRAM stuck | Medium |
| **ComfyUI-CameraPack** | May use xformers attention | Launch ComfyUI with `--disable-xformers`; use `--use-pytorch-cross-attention` | Low |
| **ComfyUI-KwaiKolorsWrapper** | Kolors model may have BF16 issues | Test with `--force-fp16`; if failures persist, defer | Low |

---

## Red Tier — Avoid Initially

| Node / Package | Reason | Alternative |
|----------------|--------|------------|
| **xformers** (standalone install) | CUDA-only binary; ROCm build requires compiling from source with `PYTORCH_ROCM_ARCH=gfx1201` | Use `--use-pytorch-cross-attention` instead |
| Any node requiring **bitsandbytes 4-bit/8-bit** | Not tested on gfx1201; may fail silently | Use GGUF quantization instead (ComfyUI-GGUF) |
| **ComfyUI-Impact-Pack subgraph** with **segment anything** | SAM models may use CUDA-specific ops | Test basic workflow; skip SAM if it fails |
| Nodes requiring standalone **Triton** package | Conflicts with bundled pytorch-triton-rocm | Use PyTorch's bundled Triton only |
| Any node doing **FP8 matmul explicitly** | gfx1201 FP8 compute broken | Use BF16 or GGUF |

---

## Constraints Pattern (Critical for All Installs)

Every pip install for custom nodes must use constraints to prevent CUDA torch from replacing ROCm torch:

```bash
pip install -r custom_nodes/<name>/requirements.txt \
  -c /mnt/c/ai_tools/comfyui-rocm/constraints.txt
```

Contents of `constraints.txt`:
```
torch==2.5.1+rocm6.2
torchvision==0.20.1+rocm6.2
torchaudio==2.5.1+rocm6.2
```

### Why This Is Critical

Many custom nodes include `requirements.txt` like:
```
torch>=2.0.0
torchvision>=0.15.0
```

Without constraints, `pip` may download and install a CUDA-only `torch` wheel that satisfies these requirements but breaks the ROCm environment. The constraints file forces pip to use the already-installed ROCm torch.

---

## Installation Verification Pattern

After installing any new custom node, always verify ROCm torch was not replaced:

```bash
conda activate rocm-comfyui-r9700
python -c "import torch; print(torch.__version__)"
# Expected: 2.5.1+rocm6.2 (or 2.9.x+rocm7.2 if upgraded)
# NOT: 2.x.x+cu118 or similar
```

If CUDA version appears:
```bash
pip install torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/rocm6.2 \
  --force-reinstall
```

---

## Testing Checklist for Yellow-Tier Nodes

Before using a Yellow-tier node in production:

1. Install with constraints.txt
2. Restart ComfyUI
3. Verify torch version still ROCm
4. Load a minimal workflow using only that node
5. Run with a very small input (e.g., 64×64 image, 1 frame)
6. Check for:
   - `NotImplementedError: not implemented for 'Float8_e4m3fn'` → FP8 issue
   - `CUDA error: invalid device function` → CUDA kernel compiled for wrong arch
   - `ImportError: libcuda.so.1` → CUDA-only binary dependency
   - `hipErrorNoBinaryForGpu` → CUDA kernel not compiled for gfx1201
7. If successful at small scale, test at target resolution/frame count

---

## ComfyUI-LTXVideo Specific Notes

This is the most important Yellow-tier node for this stack.

**Dependencies to watch:**
- `flash-attn` — may be required; build from ROCm/flash-attention if needed
- `sage-attention` — Python 3.12+ only; may work on ROCm with pip install
- `xformers` — should not be a hard dependency; if it is, patch the import

**Flash Attention build for ROCm:**
```bash
git clone https://github.com/ROCm/flash-attention
cd flash-attention
# Set target arch
export PYTORCH_ROCM_ARCH=gfx1201
# Build and install
pip install -e . -c /mnt/c/ai_tools/comfyui-rocm/constraints.txt
```

**If ComfyUI-LTXVideo fails entirely:**
Use the fallback GGUF path described in `LTX23_ROCM_IMPLEMENTATION_PLAN.md`.
