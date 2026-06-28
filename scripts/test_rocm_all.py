#!/usr/bin/env python3
"""
Master test runner for all ROCm R9700 ComfyUI workflows.
Runs tests sequentially (models are too large to run concurrently).
Each test queues one generation and waits for completion.

Usage:
    python test_rocm_all.py              # run all tests
    python test_rocm_all.py --image      # image tests only
    python test_rocm_all.py --video      # video tests only
    python test_rocm_all.py sdxl flux1   # specific tests by name

Available test names:
    sdxl, flux1, qwen, z_image,
    ltx_distilled, ltx_dev, ltx_gguf,
    ltx_i2v, ltx_2frame, ltx_3frame
"""
import argparse
import importlib.util
import sys
import time
import urllib.request
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent

TESTS = {
    "sdxl":          ("test_rocm_sdxl",                      "image"),
    "flux1":         ("test_rocm_flux1_gguf",                 "image"),
    "qwen":          ("test_rocm_qwen_image",                 "image"),
    "z_image":       ("test_rocm_z_image",                    "image"),
    "ltx_distilled": ("test_rocm_ltx23_distilled",           "video"),
    "ltx_dev":       ("test_rocm_ltx23_dev",                 "video"),
    "ltx_gguf":      ("test_rocm_ltx23_gguf",                "video"),
    "ltx_i2v":       ("test_rocm_ltx23_i2v_distilled",       "video"),
    "ltx_2frame":    ("test_rocm_ltx23_2frame_distilled",    "video"),
    "ltx_3frame":    ("test_rocm_ltx23_3frame_dev",          "video"),
}

SERVER = "http://127.0.0.1:8189"


def server_is_up() -> bool:
    try:
        with urllib.request.urlopen(f"{SERVER}/system_stats", timeout=5) as resp:
            return resp.status == 200
    except Exception:
        return False


def load_and_run(module_name: str) -> int:
    spec = importlib.util.spec_from_file_location(
        module_name, SCRIPTS_DIR / f"{module_name}.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.main()


def main():
    parser = argparse.ArgumentParser(description="ROCm ComfyUI test runner")
    parser.add_argument("tests", nargs="*", help="Test names to run (default: all)")
    parser.add_argument("--image", action="store_true", help="Run image tests only")
    parser.add_argument("--video", action="store_true", help="Run video tests only")
    args = parser.parse_args()

    if not server_is_up():
        print(f"ERROR: ComfyUI server not reachable at {SERVER}")
        print("Start it first: conda activate rocm-comfyui-r9700 && python main.py ...")
        return 1

    if args.tests:
        selected = {k: v for k, v in TESTS.items() if k in args.tests}
        unknown = set(args.tests) - set(TESTS)
        if unknown:
            print(f"Unknown test(s): {', '.join(sorted(unknown))}")
            print(f"Valid names: {', '.join(TESTS)}")
            return 1
    elif args.image:
        selected = {k: v for k, v in TESTS.items() if v[1] == "image"}
    elif args.video:
        selected = {k: v for k, v in TESTS.items() if v[1] == "video"}
    else:
        selected = TESTS

    print(f"\n{'='*60}")
    print(f"ROCm R9700 ComfyUI Test Suite — {len(selected)} test(s)")
    print(f"{'='*60}\n")

    results = {}
    suite_start = time.time()

    for name, (module, category) in selected.items():
        print(f"\n[{category.upper()}] Running: {name}")
        print("-" * 40)
        t0 = time.time()
        try:
            rc = load_and_run(module)
            elapsed = time.time() - t0
            results[name] = ("PASS" if rc == 0 else "FAIL", elapsed)
        except Exception as e:
            elapsed = time.time() - t0
            print(f"  EXCEPTION: {e}")
            results[name] = ("ERROR", elapsed)

    suite_elapsed = time.time() - suite_start

    print(f"\n{'='*60}")
    print("RESULTS SUMMARY")
    print(f"{'='*60}")
    passed = 0
    for name, (status, elapsed) in results.items():
        icon = "✓" if status == "PASS" else "✗"
        print(f"  {icon} {name:<20} {status:<6} ({elapsed:.0f}s)")
        if status == "PASS":
            passed += 1

    print(f"\n{passed}/{len(results)} passed  |  Total time: {suite_elapsed:.0f}s")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
