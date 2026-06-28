#!/usr/bin/env python3
"""
API test for LTX-2.3 22B Distilled FP8 2-Frame injection on ROCm R9700.
Uploads two test images (start=warm red, end=cool blue gradient), generates
a video that interpolates between them.
8 steps, CFG=1.0, 768x512 25 frames @ 24fps.
Targets ComfyUI at http://127.0.0.1:8189
"""
import json
import struct
import time
import uuid
import zlib
import urllib.request

SERVER = "http://127.0.0.1:8189"
OUTPUT_PREFIX = "ROCM_R9700_LTX23_2Frame_Distilled"


def make_solid_png(r: int, g: int, b: int, width: int = 512, height: int = 512) -> bytes:
    raw = b""
    for _ in range(height):
        row = bytes([0]) + bytes([r, g, b] * width)
        raw += row

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


def upload_image(png_bytes: bytes, filename: str) -> str:
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
        f"{SERVER}/upload/image", data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())["name"]


def build_workflow(start_img: str, end_img: str) -> dict:
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
            "inputs": {"image": start_img, "upload": "image"}
        },
        "4": {
            "class_type": "LoadImage",
            "inputs": {"image": end_img, "upload": "image"}
        },
        "5": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["2", 0],
                "text": "A majestic red fox runs through a snowy forest at dawn, breath visible in cold air, cinematic lighting, high detail, photorealistic"
            }
        },
        "6": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["2", 0],
                "text": "low quality, blurry, distorted, ugly, watermark, text, static, noisy"
            }
        },
        "7": {
            "class_type": "LTXVConditioning",
            "inputs": {
                "positive": ["5", 0],
                "negative": ["6", 0],
                "frame_rate": 24.0
            }
        },
        "8": {
            "class_type": "LTXVImgToVideoAdvanced",
            "inputs": {
                "positive": ["7", 0],
                "negative": ["7", 1],
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
        "9": {
            "class_type": "LTXVAddGuideAdvanced",
            "inputs": {
                "positive": ["8", 0],
                "negative": ["8", 1],
                "vae": ["1", 2],
                "latent": ["8", 2],
                "image": ["4", 0],
                "frame_idx": -1,
                "strength": 1.0,
                "crf": 29,
                "blur_radius": 0,
                "interpolation": "lanczos",
                "crop": "disabled"
            }
        },
        "10": {
            "class_type": "ModelSamplingLTXV",
            "inputs": {
                "model": ["1", 0],
                "max_shift": 2.05,
                "base_shift": 0.95,
                "latent": ["9", 2]
            }
        },
        "11": {
            "class_type": "CFGGuider",
            "inputs": {
                "model": ["10", 0],
                "positive": ["9", 0],
                "negative": ["9", 1],
                "cfg": 1.0
            }
        },
        "12": {
            "class_type": "KSamplerSelect",
            "inputs": {"sampler_name": "euler_ancestral_cfg_pp"}
        },
        "13": {
            "class_type": "LTXVScheduler",
            "inputs": {
                "steps": 8,
                "max_shift": 2.05,
                "base_shift": 0.95,
                "stretch": True,
                "terminal": 0.1,
                "latent": ["9", 2]
            }
        },
        "14": {
            "class_type": "RandomNoise",
            "inputs": {"noise_seed": 42, "control_after_generate": "randomize"}
        },
        "15": {
            "class_type": "SamplerCustomAdvanced",
            "inputs": {
                "noise": ["14", 0],
                "guider": ["11", 0],
                "sampler": ["12", 0],
                "sigmas": ["13", 0],
                "latent_image": ["9", 2]
            }
        },
        "16": {
            "class_type": "LTXVTiledVAEDecode",
            "inputs": {
                "vae": ["1", 2],
                "latents": ["15", 0],
                "horizontal_tiles": 1,
                "vertical_tiles": 1,
                "overlap": 1,
                "last_frame_fix": False
            }
        },
        "17": {
            "class_type": "VHS_VideoCombine",
            "inputs": {
                "images": ["16", 0],
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
    print(f"[LTX23-2Frame] Uploading start (warm red) and end (cool blue) frames to {SERVER}")
    start_png = make_solid_png(200, 80, 40)
    end_png = make_solid_png(40, 80, 200)
    start_name = upload_image(start_png, "test_2frame_start.png")
    end_name = upload_image(end_png, "test_2frame_end.png")
    print(f"[LTX23-2Frame] start={start_name}  end={end_name}")

    print("[LTX23-2Frame] Queuing 2-frame injection prompt (8 steps, 25 frames)...")
    t0 = time.time()
    prompt_id = queue_prompt(build_workflow(start_name, end_name))
    print(f"[LTX23-2Frame] Prompt ID: {prompt_id}")

    result = wait_for_prompt(prompt_id)
    elapsed = time.time() - t0

    outputs = result.get("outputs", {})
    videos = [v for nout in outputs.values() for v in nout.get("gifs", [])]

    if videos:
        print(f"[LTX23-2Frame] SUCCESS in {elapsed:.1f}s — {len(videos)} video(s):")
        for v in videos:
            print(f"  {v.get('filename', v)}")
    else:
        print(f"[LTX23-2Frame] FAILED after {elapsed:.1f}s")
        print(f"  status: {result.get('status', {})}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
