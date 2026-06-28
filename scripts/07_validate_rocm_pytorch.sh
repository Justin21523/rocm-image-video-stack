#!/usr/bin/env bash
# ROCm PyTorch Validation — Test 1
# Safe to run; no modifications to any environment
# Logs results to reports/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$PROJECT_DIR/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$REPORTS_DIR/rocm_pytorch_validation_$TIMESTAMP.txt"

mkdir -p "$REPORTS_DIR"

log() { echo "$*" | tee -a "$REPORT"; }

CONDA_ENV=rocm-comfyui-r9700

log "================================================================"
log "ROCm PyTorch VALIDATION — Test 1"
log "Date: $(date)"
log "Conda env: $CONDA_ENV"
log "================================================================"
log ""

conda run -n "$CONDA_ENV" python - << 'PYEOF' 2>&1 | tee -a "$REPORT"
import sys
import time
import traceback

PASS = "[PASS]"
FAIL = "[FAIL]"
WARN = "[WARN]"

def check(label, fn):
    try:
        result = fn()
        print(f"{PASS} {label}: {result}")
        return True
    except Exception as e:
        print(f"{FAIL} {label}: {e}")
        return False

import torch

# Test 1: ROCm build
hip_ver = torch.version.hip
if hip_ver:
    print(f"{PASS} torch.version.hip: {hip_ver}")
else:
    print(f"{FAIL} torch.version.hip: None — this is NOT a ROCm build")
    sys.exit(1)

# Test 2: CUDA API (ROCm uses CUDA API)
if torch.cuda.is_available():
    print(f"{PASS} torch.cuda.is_available(): True")
else:
    print(f"{FAIL} torch.cuda.is_available(): False")
    print(f"       Check HIP_VISIBLE_DEVICES and /dev/dri/ device files")
    sys.exit(1)

# Test 3: GPU name
name = torch.cuda.get_device_name(0)
print(f"{PASS} GPU name: {name}")

# Test 4: VRAM
vram = torch.cuda.get_device_properties(0).total_memory / 1e9
if vram >= 30:
    print(f"{PASS} VRAM: {vram:.1f} GB")
else:
    print(f"{WARN} VRAM: {vram:.1f} GB (expected ~32 GB — wrong GPU?)")

# Test 5: Float32 matmul
t0 = time.time()
a = torch.randn(1024, 1024, device='cuda', dtype=torch.float32)
b = torch.randn(1024, 1024, device='cuda', dtype=torch.float32)
c = torch.mm(a, b)
torch.cuda.synchronize()
elapsed = (time.time() - t0) * 1000
print(f"{PASS} Float32 matmul 1024x1024: {elapsed:.0f} ms")

# Test 6: BF16 matmul
try:
    t0 = time.time()
    a = torch.randn(1024, 1024, device='cuda', dtype=torch.bfloat16)
    b = torch.randn(1024, 1024, device='cuda', dtype=torch.bfloat16)
    c = torch.mm(a, b)
    torch.cuda.synchronize()
    elapsed = (time.time() - t0) * 1000
    print(f"{PASS} BF16 matmul 1024x1024: {elapsed:.0f} ms")
except Exception as e:
    print(f"{FAIL} BF16 matmul: {e}")

# Test 7: FP8 (expected to fail on gfx1201 — logged as warning only)
try:
    if hasattr(torch, 'float8_e4m3fn'):
        a = torch.randn(64, 64, device='cuda').to(torch.float8_e4m3fn)
        b = torch.randn(64, 64, device='cuda').to(torch.float8_e4m3fn)
        c = torch.mm(a.float(), b.float())
        print(f"{PASS} FP8 operations: supported on gfx1201 (unexpected — update plan)")
    else:
        print(f"{WARN} FP8 dtype not available in this PyTorch build")
except Exception as e:
    print(f"{WARN} FP8 operations: {type(e).__name__} — expected on gfx1201")
    print(f"       LTX models should still work if ComfyUI-LTXVideo dequantizes to BF16")

# Test 8: SDPA (scaled dot-product attention)
try:
    q = torch.randn(1, 8, 128, 64, device='cuda', dtype=torch.bfloat16)
    k = torch.randn(1, 8, 128, 64, device='cuda', dtype=torch.bfloat16)
    v = torch.randn(1, 8, 128, 64, device='cuda', dtype=torch.bfloat16)
    out = torch.nn.functional.scaled_dot_product_attention(q, k, v)
    print(f"{PASS} PyTorch SDPA (scaled dot-product attention): OK")
except Exception as e:
    print(f"{FAIL} PyTorch SDPA: {e}")

print("")
print("================================================================")
print("Validation complete. Check [FAIL] lines above for issues.")
print("================================================================")
PYEOF

log ""
log "Report saved to: $REPORT"
