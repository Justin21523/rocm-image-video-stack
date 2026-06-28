#!/usr/bin/env python3
"""
API test for Flux.1 Dev GGUF Q4_K_S text-to-image on ROCm R9700.
Uses BasicGuider + SamplerCustomAdvanced (no CFG negative).
Targets ComfyUI at http://127.0.0.1:8189
"""
import json
import time
import uuid
import urllib.request

SERVER = "http://127.0.0.1:8189"
OUTPUT_PREFIX = "ROCM_R9700_Flux1_GGUF"

WORKFLOW = {
    "1": {
        "class_type": "UnetLoaderGGUF",
        "inputs": {
            "unet_name": "flux1-dev-Q4_K_S.gguf"
        }
    },
    "2": {
        "class_type": "DualCLIPLoader",
        "inputs": {
            "clip_name1": "t5xxl_fp8_e4m3fn.safetensors",
            "clip_name2": "clip_l.safetensors",
            "type": "flux",
            "device": "default"
        }
    },
    "3": {
        "class_type": "VAELoader",
        "inputs": {
            "vae_name": "ae.safetensors"
        }
    },
    "4": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "clip": ["2", 0],
            "text": "a majestic snow-capped mountain reflected in a crystal-clear alpine lake at sunrise, photorealistic, cinematic, 8k resolution"
        }
    },
    "5": {
        "class_type": "EmptySD3LatentImage",
        "inputs": {
            "width": 1024,
            "height": 1024,
            "batch_size": 1
        }
    },
    "6": {
        "class_type": "FluxGuidance",
        "inputs": {
            "conditioning": ["4", 0],
            "guidance": 3.5
        }
    },
    "7": {
        "class_type": "RandomNoise",
        "inputs": {
            "noise_seed": 42,
            "control_after_generate": "randomize"
        }
    },
    "8": {
        "class_type": "BasicGuider",
        "inputs": {
            "model": ["1", 0],
            "conditioning": ["6", 0]
        }
    },
    "9": {
        "class_type": "KSamplerSelect",
        "inputs": {
            "sampler_name": "euler"
        }
    },
    "10": {
        "class_type": "BasicScheduler",
        "inputs": {
            "model": ["1", 0],
            "scheduler": "simple",
            "steps": 20,
            "denoise": 1.0
        }
    },
    "11": {
        "class_type": "SamplerCustomAdvanced",
        "inputs": {
            "noise": ["7", 0],
            "guider": ["8", 0],
            "sampler": ["9", 0],
            "sigmas": ["10", 0],
            "latent_image": ["5", 0]
        }
    },
    "12": {
        "class_type": "VAEDecodeTiled",
        "inputs": {
            "samples": ["11", 0],
            "vae": ["3", 0],
            "tile_size": 512,
            "overlap": 64,
            "temporal_size": 64,
            "temporal_overlap": 8
        }
    },
    "13": {
        "class_type": "SaveImage",
        "inputs": {
            "images": ["12", 0],
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
    print(f"[Flux1-GGUF] Queuing prompt to {SERVER}")
    t0 = time.time()
    prompt_id = queue_prompt(WORKFLOW)
    print(f"[Flux1-GGUF] Prompt ID: {prompt_id}")

    result = wait_for_prompt(prompt_id)
    elapsed = time.time() - t0

    outputs = result.get("outputs", {})
    images = []
    for node_output in outputs.values():
        if "images" in node_output:
            images.extend(node_output["images"])

    if images:
        print(f"[Flux1-GGUF] SUCCESS in {elapsed:.1f}s — {len(images)} image(s):")
        for img in images:
            print(f"  {img['filename']}")
    else:
        print(f"[Flux1-GGUF] FAILED after {elapsed:.1f}s — no images in output")
        print(f"  status: {result.get('status', {})}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
