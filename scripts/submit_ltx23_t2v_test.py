#!/usr/bin/env python3
"""
Phase 6e: LTX-2.3 T2V minimal inference test via ComfyUI API.
Resolution: 512x288, 9 frames, 8 steps (distilled model)
"""
import json
import time
import uuid
import urllib.request
import urllib.error

COMFYUI_URL = "http://127.0.0.1:8189"
CLIENT_ID = str(uuid.uuid4())

# Model filenames (must exist in ComfyUI folder paths)
LTX_DISTILLED_FP8 = "ltx-2.3-22b-distilled-fp8.safetensors"
GEMMA_TEXT_ENC   = "comfy_gemma_3_12B_it.safetensors"

POSITIVE_PROMPT = (
    "A majestic red fox runs through a snowy forest at dawn, breath visible in cold air, "
    "cinematic lighting, shallow depth of field, high detail, 4K quality"
)
NEGATIVE_PROMPT = "low quality, blurry, distorted, ugly, cartoon, watermark, text, static"

# Minimal resolution: width and height must be multiples of 32
# length must satisfy (length - 1) % 8 == 0  → 1, 9, 17, 25, 33...
WIDTH  = 512
HEIGHT = 288   # 288/32 = 9  ✓
FRAMES = 9     # (9-1) % 8 = 0  ✓
STEPS  = 8
SEED   = 42
FPS    = 24

workflow = {
    # ── 1. Load diffusion model (MODEL + VAE) ──────────────────────────────
    "1": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {"ckpt_name": LTX_DISTILLED_FP8}
    },
    # ── 2. Load Gemma CLIP for text encoding ─────────────────────────────
    "2": {
        "class_type": "LTXAVTextEncoderLoader",
        "inputs": {
            "text_encoder": GEMMA_TEXT_ENC,
            "ckpt_name":    LTX_DISTILLED_FP8,
            "device":       "default"
        }
    },
    # ── 3 & 4. Encode prompts ─────────────────────────────────────────────
    "3": {
        "class_type": "CLIPTextEncode",
        "inputs": {"text": POSITIVE_PROMPT, "clip": ["2", 0]}
    },
    "4": {
        "class_type": "CLIPTextEncode",
        "inputs": {"text": NEGATIVE_PROMPT, "clip": ["2", 0]}
    },
    # ── 5. LTX conditioning (add frame_rate) ──────────────────────────────
    "5": {
        "class_type": "LTXVConditioning",
        "inputs": {
            "positive":   ["3", 0],
            "negative":   ["4", 0],
            "frame_rate": float(FPS)
        }
    },
    # ── 6. Empty video latent ─────────────────────────────────────────────
    "6": {
        "class_type": "EmptyLTXVLatentVideo",
        "inputs": {
            "width":      WIDTH,
            "height":     HEIGHT,
            "length":     FRAMES,
            "batch_size": 1
        }
    },
    # ── 7. Apply LTXV model sampling params ──────────────────────────────
    "7": {
        "class_type": "ModelSamplingLTXV",
        "inputs": {
            "model":      ["1", 0],
            "max_shift":  2.05,
            "base_shift": 0.95,
            "latent":     ["6", 0]
        }
    },
    # ── 8. CFG Guider (simpler than STG, no skip_block_list required) ────
    "8": {
        "class_type": "CFGGuider",
        "inputs": {
            "model":    ["7", 0],
            "positive": ["5", 0],
            "negative": ["5", 1],
            "cfg":      1.0
        }
    },
    # ── 9. Sampler ────────────────────────────────────────────────────────
    "9": {
        "class_type": "KSamplerSelect",
        "inputs": {"sampler_name": "euler_ancestral_cfg_pp"}
    },
    # ── 10. Sigmas (LTX scheduler, distilled-friendly) ───────────────────
    "10": {
        "class_type": "LTXVScheduler",
        "inputs": {
            "steps":      STEPS,
            "max_shift":  2.05,
            "base_shift": 0.95,
            "stretch":    True,
            "terminal":   0.1,
            "latent":     ["6", 0]
        }
    },
    # ── 11. Noise ─────────────────────────────────────────────────────────
    "11": {
        "class_type": "RandomNoise",
        "inputs": {"noise_seed": SEED}
    },
    # ── 12. Sample ────────────────────────────────────────────────────────
    "12": {
        "class_type": "SamplerCustomAdvanced",
        "inputs": {
            "noise":        ["11", 0],
            "guider":       ["8", 0],
            "sampler":      ["9", 0],
            "sigmas":       ["10", 0],
            "latent_image": ["6", 0]
        }
    },
    # ── 13. Decode VAE (tiled for LTX) ───────────────────────────────────
    "13": {
        "class_type": "LTXVTiledVAEDecode",
        "inputs": {
            "vae":              ["1", 2],
            "latents":          ["12", 0],
            "horizontal_tiles": 1,
            "vertical_tiles":   1,
            "overlap":          1,
            "last_frame_fix":   False
        }
    },
    # ── 14. Save video ────────────────────────────────────────────────────
    "14": {
        "class_type": "VHS_VideoCombine",
        "inputs": {
            "images":          ["13", 0],
            "frame_rate":      FPS,
            "loop_count":      0,
            "filename_prefix": "ltx23_phase6e",
            "format":          "video/h264-mp4",
            "pingpong":        False,
            "save_output":     True
        }
    }
}

def api(method, path, data=None):
    url = COMFYUI_URL + path
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body,
                                  headers={"Content-Type": "application/json"})
    req.get_method = lambda: method
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

def queue_prompt(workflow):
    return api("POST", "/api/prompt", {
        "prompt": workflow,
        "client_id": CLIENT_ID
    })

def get_queue():
    return api("GET", "/api/queue")

def get_history(prompt_id):
    return api("GET", f"/api/history/{prompt_id}")

def main():
    print("=" * 60)
    print("Phase 6e: LTX-2.3 T2V minimal test")
    print(f"  Resolution : {WIDTH}x{HEIGHT}")
    print(f"  Frames     : {FRAMES}")
    print(f"  Steps      : {STEPS}")
    print(f"  Model      : {LTX_DISTILLED_FP8}")
    print(f"  Text enc   : {GEMMA_TEXT_ENC}")
    print("=" * 60)

    # Check ComfyUI is up
    try:
        api("GET", "/api/queue")
    except Exception as e:
        print(f"ERROR: ComfyUI not reachable at {COMFYUI_URL}: {e}")
        return

    print("\nSubmitting prompt...")
    resp = queue_prompt(workflow)
    prompt_id = resp.get("prompt_id")
    if not prompt_id:
        print(f"ERROR: No prompt_id in response: {resp}")
        return
    print(f"  prompt_id: {prompt_id}")

    print("\nWaiting for completion (check logs at /mnt/c/ai_tools/comfyui-rocm/logs/)...")
    start = time.time()
    poll_interval = 10
    while True:
        elapsed = int(time.time() - start)
        queue = get_queue()
        running = queue.get("queue_running", [])
        pending = queue.get("queue_pending", [])

        if not running and not pending:
            # Check history
            hist = get_history(prompt_id)
            if prompt_id in hist:
                result = hist[prompt_id]
                status = result.get("status", {})
                if status.get("completed"):
                    print(f"\n[DONE] Completed in {elapsed}s")
                    outputs = result.get("outputs", {})
                    for node_id, out in outputs.items():
                        if "gifs" in out:
                            for g in out["gifs"]:
                                print(f"  Output: {g.get('filename')} ({g.get('type')})")
                        if "images" in out:
                            for img in out["images"]:
                                print(f"  Output: {img.get('filename')}")
                    break
                msgs = status.get("messages", [])
                errors = [m for m in msgs if m[0] == "execution_error"]
                if errors:
                    print(f"\n[ERROR] after {elapsed}s:")
                    for e in errors:
                        print(f"  {e}")
                    break

        print(f"  [{elapsed:4d}s] running={len(running)} pending={len(pending)}", end="\r")
        time.sleep(poll_interval)

    print("\nDone. Check /mnt/c/ai_tools/comfyui-rocm/output/ for the video.")

if __name__ == "__main__":
    main()
