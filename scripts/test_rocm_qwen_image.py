#!/usr/bin/env python3
"""
API test for Qwen Image 2512 FP8 text-to-image on ROCm R9700.
Uses AuraFlow-style sampler (ModelSamplingAuraFlow shift=3.1).
Targets ComfyUI at http://127.0.0.1:8189
"""
import json
import time
import uuid
import urllib.request

SERVER = "http://127.0.0.1:8189"
OUTPUT_PREFIX = "ROCM_R9700_Qwen_Image"

WORKFLOW = {
    "1": {
        "class_type": "UNETLoader",
        "inputs": {
            "unet_name": "qwen_image_2512_fp8_e4m3fn.safetensors",
            "weight_dtype": "default"
        }
    },
    "2": {
        "class_type": "CLIPLoader",
        "inputs": {
            "clip_name": "qwen_2.5_vl_7b_fp8_scaled.safetensors",
            "type": "qwen_image",
            "device": "default"
        }
    },
    "3": {
        "class_type": "VAELoader",
        "inputs": {
            "vae_name": "qwen_image_vae.safetensors"
        }
    },
    "4": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "clip": ["2", 0],
            "text": "A photorealistic portrait of a young woman with flowing auburn hair, standing in a sunlit garden. She wears an elegant floral dress. Shallow depth of field, bokeh background with colorful flowers. Professional photography, high detail, 4K."
        }
    },
    "5": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "clip": ["2", 0],
            "text": "low resolution, low quality, deformed limbs, deformed face, over-smooth, wax-like skin, too much noise"
        }
    },
    "6": {
        "class_type": "EmptySD3LatentImage",
        "inputs": {
            "width": 1328,
            "height": 1328,
            "batch_size": 1
        }
    },
    "7": {
        "class_type": "ModelSamplingAuraFlow",
        "inputs": {
            "model": ["1", 0],
            "shift": 3.1
        }
    },
    "8": {
        "class_type": "KSampler",
        "inputs": {
            "model": ["7", 0],
            "positive": ["4", 0],
            "negative": ["5", 0],
            "latent_image": ["6", 0],
            "seed": 42,
            "control_after_generate": "randomize",
            "steps": 28,
            "cfg": 4.0,
            "sampler_name": "euler",
            "scheduler": "simple",
            "denoise": 1.0
        }
    },
    "9": {
        "class_type": "VAEDecodeTiled",
        "inputs": {
            "samples": ["8", 0],
            "vae": ["3", 0],
            "tile_size": 768,
            "overlap": 64,
            "temporal_size": 64,
            "temporal_overlap": 8
        }
    },
    "10": {
        "class_type": "SaveImage",
        "inputs": {
            "images": ["9", 0],
            "filename_prefix": OUTPUT_PREFIX
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


def wait_for_prompt(prompt_id: str, poll_interval: float = 2.0) -> dict:
    while True:
        with urllib.request.urlopen(f"{SERVER}/history/{prompt_id}") as resp:
            history = json.loads(resp.read())
        if prompt_id in history:
            return history[prompt_id]
        time.sleep(poll_interval)


def main():
    print(f"[Qwen-Image] Queuing prompt to {SERVER}")
    t0 = time.time()
    prompt_id = queue_prompt(WORKFLOW)
    print(f"[Qwen-Image] Prompt ID: {prompt_id}")

    result = wait_for_prompt(prompt_id)
    elapsed = time.time() - t0

    outputs = result.get("outputs", {})
    images = []
    for node_output in outputs.values():
        if "images" in node_output:
            images.extend(node_output["images"])

    if images:
        print(f"[Qwen-Image] SUCCESS in {elapsed:.1f}s — {len(images)} image(s):")
        for img in images:
            print(f"  {img['filename']}")
    else:
        print(f"[Qwen-Image] FAILED after {elapsed:.1f}s — no images in output")
        print(f"  status: {result.get('status', {})}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
