#!/usr/bin/env python3
"""
API test for LTX-2.3 22B Distilled FP8 Image-to-Video on ROCm R9700.
Generates a test image (red→black gradient), uploads it, then runs I2V.
8 steps, CFG=1.0, 768x512 25 frames @ 24fps (~1s video).
Targets ComfyUI at http://127.0.0.1:8189
"""
import io
import json
import struct
import time
import uuid
import zlib
import urllib.request

SERVER = "http://127.0.0.1:8189"
OUTPUT_PREFIX = "ROCM_R9700_LTX23_I2V_Distilled"


def make_gradient_png(width: int = 512, height: int = 512) -> bytes:
    """Generate a simple RGB gradient PNG using only stdlib."""
    raw = b""
    for y in range(height):
        row = bytes([0])  # filter type = None
        for x in range(width):
            r = int(255 * (1 - x / width))
            g = int(128 * (y / height))
            b = int(200 * (x / width) * (1 - y / height))
            row += bytes([r, g, b])
        raw += row

    def make_chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    idat = zlib.compress(raw)
    return (
        b"\x89PNG\r\n\x1a\n"
        + make_chunk(b"IHDR", ihdr)
        + make_chunk(b"IDAT", idat)
        + make_chunk(b"IEND", b"")
    )


def upload_image(png_bytes: bytes, filename: str = "test_i2v_input.png") -> str:
    """Upload image to ComfyUI /upload/image, returns filename used."""
    boundary = "----FormBoundary" + uuid.uuid4().hex
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="image"; filename="{filename}"\r\n'
        f"Content-Type: image/png\r\n\r\n"
    ).encode() + png_bytes + (
        f"\r\n--{boundary}\r\n"
        f'Content-Disposition: form-data; name="type"\r\n\r\ninput'
        f"\r\n--{boundary}\r\n"
        f'Content-Disposition: form-data; name="overwrite"\r\n\r\ntrue'
        f"\r\n--{boundary}--\r\n"
    ).encode()

    req = urllib.request.Request(
        f"{SERVER}/upload/image",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read())
        return result["name"]


def build_workflow(image_filename: str) -> dict:
    return {
        "1": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": "ltx-2.3-22b-distilled-fp8.safetensors"}
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
            "class_type": "LoadImage",
            "inputs": {"image": image_filename, "upload": "image"}
        },
        "4": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["2", 0],
                "text": "A majestic red fox runs through a snowy forest at dawn, breath visible in cold air, cinematic lighting, shallow depth of field, photorealistic"
            }
        },
        "5": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["2", 0],
                "text": "low quality, blurry, distorted, ugly, watermark, text, static, noisy"
            }
        },
        "6": {
            "class_type": "LTXVConditioning",
            "inputs": {
                "positive": ["4", 0],
                "negative": ["5", 0],
                "frame_rate": 24.0
            }
        },
        "7": {
            "class_type": "LTXVImgToVideoAdvanced",
            "inputs": {
                "positive": ["6", 0],
                "negative": ["6", 1],
                "vae": ["1", 2],
                "image": ["3", 0],
                "width": 768,
                "height": 512,
                "length": 25,
                "batch_size": 1,
                "crf": 29,
                "blur_radius": 0,
                "interpolation": "lanczos",
                "crop": "disabled",
                "strength": 0.9
            }
        },
        "8": {
            "class_type": "ModelSamplingLTXV",
            "inputs": {
                "model": ["1", 0],
                "max_shift": 2.05,
                "base_shift": 0.95,
                "latent": ["7", 2]
            }
        },
        "9": {
            "class_type": "CFGGuider",
            "inputs": {
                "model": ["8", 0],
                "positive": ["7", 0],
                "negative": ["7", 1],
                "cfg": 1.0
            }
        },
        "10": {
            "class_type": "KSamplerSelect",
            "inputs": {"sampler_name": "euler_ancestral_cfg_pp"}
        },
        "11": {
            "class_type": "LTXVScheduler",
            "inputs": {
                "steps": 8,
                "max_shift": 2.05,
                "base_shift": 0.95,
                "stretch": True,
                "terminal": 0.1,
                "latent": ["7", 2]
            }
        },
        "12": {
            "class_type": "RandomNoise",
            "inputs": {"noise_seed": 42, "control_after_generate": "randomize"}
        },
        "13": {
            "class_type": "SamplerCustomAdvanced",
            "inputs": {
                "noise": ["12", 0],
                "guider": ["9", 0],
                "sampler": ["10", 0],
                "sigmas": ["11", 0],
                "latent_image": ["7", 2]
            }
        },
        "14": {
            "class_type": "LTXVTiledVAEDecode",
            "inputs": {
                "vae": ["1", 2],
                "latents": ["13", 0],
                "horizontal_tiles": 1,
                "vertical_tiles": 1,
                "overlap": 1,
                "last_frame_fix": False
            }
        },
        "15": {
            "class_type": "VHS_VideoCombine",
            "inputs": {
                "images": ["14", 0],
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
    req = urllib.request.Request(
        f"{SERVER}/prompt", data=payload,
        headers={"Content-Type": "application/json"}
    )
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
    print(f"[LTX23-I2V-Distilled] Generating test image and uploading to {SERVER}")
    png = make_gradient_png(512, 512)
    filename = upload_image(png, "test_i2v_input.png")
    print(f"[LTX23-I2V-Distilled] Uploaded: {filename}")

    print("[LTX23-I2V-Distilled] Queuing I2V prompt (8 steps, 25 frames)...")
    t0 = time.time()
    prompt_id = queue_prompt(build_workflow(filename))
    print(f"[LTX23-I2V-Distilled] Prompt ID: {prompt_id}")

    result = wait_for_prompt(prompt_id)
    elapsed = time.time() - t0

    outputs = result.get("outputs", {})
    videos = []
    for node_output in outputs.values():
        if "gifs" in node_output:
            videos.extend(node_output["gifs"])

    if videos:
        print(f"[LTX23-I2V-Distilled] SUCCESS in {elapsed:.1f}s — {len(videos)} video(s):")
        for v in videos:
            print(f"  {v.get('filename', v)}")
    else:
        print(f"[LTX23-I2V-Distilled] FAILED after {elapsed:.1f}s — no videos in output")
        print(f"  status: {result.get('status', {})}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
