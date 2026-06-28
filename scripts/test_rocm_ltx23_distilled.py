#!/usr/bin/env python3
"""
API test for LTX-2.3 22B Distilled FP8 text-to-video on ROCm R9700.
8 steps, CFG=1.0, 768x512 25 frames @ 24fps (~1s video).
FP8 weights are auto-dequantized to BF16 for compute on gfx1201.
Targets ComfyUI at http://127.0.0.1:8189
"""
import json
import time
import uuid
import urllib.request

SERVER = "http://127.0.0.1:8189"
OUTPUT_PREFIX = "ROCM_R9700_LTX23_Distilled"

WORKFLOW = {
    "1": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {
            "ckpt_name": "ltx-2.3-22b-distilled-fp8.safetensors"
        }
    },
    "2": {
        "class_type": "LTXAVTextEncoderLoader",
        "inputs": {
            "text_encoder": "comfy_gemma_3_12B_it.safetensors",
            "ckpt_name": "ltx-2.3-22b-distilled-fp8.safetensors",
            "device": "default"
        }
    },
    "3": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "clip": ["2", 0],
            "text": "A majestic red fox runs through a snowy forest at dawn, breath visible in cold air, cinematic lighting, shallow depth of field, high detail, photorealistic"
        }
    },
    "4": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "clip": ["2", 0],
            "text": "low quality, blurry, distorted, ugly, watermark, text, static, noisy"
        }
    },
    "5": {
        "class_type": "LTXVConditioning",
        "inputs": {
            "positive": ["3", 0],
            "negative": ["4", 0],
            "frame_rate": 24.0
        }
    },
    "6": {
        "class_type": "EmptyLTXVLatentVideo",
        "inputs": {
            "width": 768,
            "height": 512,
            "length": 25,
            "batch_size": 1
        }
    },
    "7": {
        "class_type": "ModelSamplingLTXV",
        "inputs": {
            "model": ["1", 0],
            "max_shift": 2.05,
            "base_shift": 0.95,
            "latent": ["6", 0]
        }
    },
    "8": {
        "class_type": "CFGGuider",
        "inputs": {
            "model": ["7", 0],
            "positive": ["5", 0],
            "negative": ["5", 1],
            "cfg": 1.0
        }
    },
    "9": {
        "class_type": "KSamplerSelect",
        "inputs": {
            "sampler_name": "euler_ancestral_cfg_pp"
        }
    },
    "10": {
        "class_type": "LTXVScheduler",
        "inputs": {
            "steps": 8,
            "max_shift": 2.05,
            "base_shift": 0.95,
            "stretch": True,
            "terminal": 0.1,
            "latent": ["6", 0]
        }
    },
    "11": {
        "class_type": "RandomNoise",
        "inputs": {
            "noise_seed": 42,
            "control_after_generate": "randomize"
        }
    },
    "12": {
        "class_type": "SamplerCustomAdvanced",
        "inputs": {
            "noise": ["11", 0],
            "guider": ["8", 0],
            "sampler": ["9", 0],
            "sigmas": ["10", 0],
            "latent_image": ["6", 0]
        }
    },
    "13": {
        "class_type": "LTXVTiledVAEDecode",
        "inputs": {
            "vae": ["1", 2],
            "latents": ["12", 0],
            "horizontal_tiles": 1,
            "vertical_tiles": 1,
            "overlap": 1,
            "last_frame_fix": False
        }
    },
    "14": {
        "class_type": "VHS_VideoCombine",
        "inputs": {
            "images": ["13", 0],
            "frame_rate": 24,
            "loop_count": 0,
            "filename_prefix": OUTPUT_PREFIX,
            "format": "video/h264-mp4",
            "pingpong": False,
            "save_output": True
        }
    }
}


def queue_prompt(workflow: dict) -> str:
    client_id = str(uuid.uuid4())
    payload = json.dumps({"prompt": workflow, "client_id": client_id}).encode()
    req = urllib.request.Request(f"{SERVER}/prompt", data=payload,
                                  headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())["prompt_id"]


def wait_for_prompt(prompt_id: str, poll_interval: float = 5.0) -> dict:
    while True:
        with urllib.request.urlopen(f"{SERVER}/history/{prompt_id}") as resp:
            history = json.loads(resp.read())
        if prompt_id in history:
            return history[prompt_id]
        time.sleep(poll_interval)


def main():
    print(f"[LTX23-Distilled] Queuing prompt to {SERVER}")
    print("[LTX23-Distilled] 22B model — expect 5-15 minutes on first run (model load + 8 steps)")
    t0 = time.time()
    prompt_id = queue_prompt(WORKFLOW)
    print(f"[LTX23-Distilled] Prompt ID: {prompt_id}")

    result = wait_for_prompt(prompt_id)
    elapsed = time.time() - t0

    outputs = result.get("outputs", {})
    videos = []
    for node_output in outputs.values():
        if "gifs" in node_output:
            videos.extend(node_output["gifs"])

    if videos:
        print(f"[LTX23-Distilled] SUCCESS in {elapsed:.1f}s — {len(videos)} video(s):")
        for v in videos:
            print(f"  {v.get('filename', v)}")
    else:
        print(f"[LTX23-Distilled] FAILED after {elapsed:.1f}s — no videos in output")
        print(f"  status: {result.get('status', {})}")
        errors = result.get("status", {}).get("messages", [])
        for msg in errors:
            print(f"  {msg}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
