#!/usr/bin/env python3
"""
API test for SDXL text-to-image on ROCm R9700.
Targets ComfyUI at http://127.0.0.1:8189
"""
import json
import time
import uuid
import urllib.request
import urllib.parse

SERVER = "http://127.0.0.1:8189"
OUTPUT_PREFIX = "ROCM_R9700_SDXL"

WORKFLOW = {
    "1": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {
            "ckpt_name": "sd_xl_base_1.0.safetensors"
        }
    },
    "2": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "clip": ["1", 1],
            "text": "a majestic snow-capped mountain reflected in a crystal-clear alpine lake at sunrise, photorealistic, cinematic, 8k resolution"
        }
    },
    "3": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "clip": ["1", 1],
            "text": "low quality, blurry, distorted, ugly, watermark, text, overexposed"
        }
    },
    "4": {
        "class_type": "EmptyLatentImage",
        "inputs": {
            "width": 1024,
            "height": 1024,
            "batch_size": 1
        }
    },
    "5": {
        "class_type": "KSampler",
        "inputs": {
            "model": ["1", 0],
            "positive": ["2", 0],
            "negative": ["3", 0],
            "latent_image": ["4", 0],
            "seed": 42,
            "control_after_generate": "randomize",
            "steps": 20,
            "cfg": 7.0,
            "sampler_name": "dpmpp_2m",
            "scheduler": "karras",
            "denoise": 1.0
        }
    },
    "6": {
        "class_type": "VAEDecodeTiled",
        "inputs": {
            "samples": ["5", 0],
            "vae": ["1", 2],
            "tile_size": 512,
            "overlap": 64,
            "temporal_size": 64,
            "temporal_overlap": 8
        }
    },
    "7": {
        "class_type": "SaveImage",
        "inputs": {
            "images": ["6", 0],
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
    print(f"[SDXL] Queuing prompt to {SERVER}")
    t0 = time.time()
    prompt_id = queue_prompt(WORKFLOW)
    print(f"[SDXL] Prompt ID: {prompt_id}")

    result = wait_for_prompt(prompt_id)
    elapsed = time.time() - t0

    outputs = result.get("outputs", {})
    images = []
    for node_output in outputs.values():
        if "images" in node_output:
            images.extend(node_output["images"])

    if images:
        print(f"[SDXL] SUCCESS in {elapsed:.1f}s — {len(images)} image(s):")
        for img in images:
            print(f"  {img['filename']}")
    else:
        print(f"[SDXL] FAILED after {elapsed:.1f}s — no images in output")
        print(f"  status: {result.get('status', {})}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
