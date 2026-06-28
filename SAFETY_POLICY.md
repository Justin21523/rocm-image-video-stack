# Safety Policy
## ROCm Image/Video Stack — Protected Paths and Forbidden Operations

---

## Core Principle

This project creates a **parallel ROCm stack** that never interferes with the existing CUDA environment. Every destructive or system-level command requires **explicit written approval** from the user before execution.

---

## Protected Paths — NEVER Modify, Delete, or Overwrite

### AI Tools (CUDA installations)
```
/mnt/c/ai_tools/comfyui/
/mnt/c/ai_tools/Comfy-LTX-Desktop/
/mnt/c/ai_tools/LTX-2/
/mnt/c/ai_tools/LTX-Video/
/mnt/c/ai_tools/LTX-Video-Trainer/
/mnt/c/ai_tools/Wan2.1/
/mnt/c/ai_tools/AnimateDiff/
/mnt/c/ai_tools/RVC/
/mnt/c/ai_tools/GPT-SoVITS/
/mnt/c/ai_tools/kohya_ss/
/mnt/c/ai_tools/stable-diffusion-webui/
/mnt/c/ai_tools/custom_nodes/
/mnt/c/ai_tools/rs-nodes/
/mnt/c/ai_tools/SimpleTuner/
/mnt/c/ai_tools/llama.cpp-rocm/   # already built ROCm server — do not rebuild or modify
```

### Model Storage
```
/mnt/c/ai_models/                  # entire tree
/mnt/c/ai_cache/                   # entire tree
```
Exception: new subdirectories explicitly created by approved scripts are permitted (e.g., new model download dirs).

### Conda Environments — CUDA (never touch)
```
comfyui
kohya_ss
ai_env
audio_env
data_env
base
```

### Project Data
```
/mnt/c/ai_projects/                # all projects except rocm-image-video-stack itself
/mnt/c/Users/                      # Windows user data
```

### Other AI Projects
```
/mnt/c/ai_tools/mcp-automation/
/mnt/c/ai_tools/DiffSynth-Studio/
/mnt/c/ai_tools/CogKit/
/mnt/c/ai_tools/Director/
/mnt/c/ai_tools/FireRed-OpenStoryline/
```

---

## Permitted Write Targets

Scripts in this project may only write to:

```
/mnt/c/ai_projects/rocm-image-video-stack/   # this project
/mnt/c/ai_tools/comfyui-rocm/                 # ROCm ComfyUI (new install only)
/mnt/c/ai_models/<new-subdirs-only>/          # only explicitly approved new download dirs
~/miniconda3/envs/rocm-*-r9700/              # ROCm conda envs only (never CUDA envs)
```

---

## Forbidden Commands

The following command patterns are **never permitted** without explicit step-by-step approval:

| Pattern | Risk |
|---------|------|
| `rm -rf /mnt/c/ai_*` | Destroys CUDA stack |
| `conda remove -n comfyui` | Destroys CUDA ComfyUI env |
| `conda remove -n kohya_ss` | Destroys LoRA training env |
| `pip install torch` (without `--index-url rocm`) | Replaces ROCm torch with CUDA |
| `pip install xformers` | Installs CUDA-only xformers |
| `cp -r ... /mnt/c/ai_tools/comfyui/` | Overwrites CUDA ComfyUI |
| `git reset --hard` in any protected path | Destroys uncommitted work |
| `conda update --all` in CUDA envs | May break CUDA packages |
| `huggingface-cli download` (without approval) | Uncontrolled large downloads |
| `mv /mnt/c/ai_models/...` | Moves model files (breaks symlinks) |

---

## Script Safety Classification

| Script | Risk Level | Approval Required | Reason |
|--------|-----------|-------------------|--------|
| `00_readonly_audit_existing_cuda_stack.sh` | Safe | No | Read-only, no writes except report |
| `01_generate_model_symlink_report.sh` | Safe | No | Read-only, generates report only |
| `02_prepare_rocm_image_video_workspace.sh` | Safe | No | mkdir only, no deletions |
| `03_create_rocm_image_video_conda_envs.sh` | Low | Yes | Creates/modifies conda envs |
| `04_setup_comfyui_rocm.sh` | Medium | Yes | Git clone + pip install |
| `05_setup_comfyui_model_symlinks.sh` | Medium | Yes | Creates symlinks in comfyui-rocm |
| `06_install_safe_comfyui_custom_nodes.sh` | Medium | Yes | pip installs with constraints |
| `07_validate_rocm_pytorch.sh` | Safe | No | Read-only test |
| `08_validate_comfyui_rocm.sh` | Low | No | Import test only (no server) |
| `09_prepare_ltx23_models.sh` | Medium | Yes (download phase) | May trigger large downloads |
| `10_validate_ltx23_comfyui_workflow.sh` | Medium | Yes | Runs model inference |
| `11_setup_video_tools_rocm.sh` | Low | Yes | pip installs in ROCm env |
| `12_validate_video_tools.sh` | Safe | No | Read-only test |
| `99_stop_services.sh` | Low | No | Stops ROCm services only |

---

## Approval Protocol

Before running any script marked "Approval Required":

1. User reads the script source
2. User explicitly types "approved" or "run it"
3. Script is run exactly once per approval
4. Any re-run requires fresh approval

---

## Conda Environment Safety

ROCm environments (`rocm-*-r9700`) are the **only** environments this project modifies.

Before any `conda activate` or `pip install` in a script, the script must verify:
```bash
if [[ "$CONDA_DEFAULT_ENV" == comfyui ]] || \
   [[ "$CONDA_DEFAULT_ENV" == kohya_ss ]] || \
   [[ "$CONDA_DEFAULT_ENV" == ai_env ]] || \
   [[ "$CONDA_DEFAULT_ENV" == audio_env ]] || \
   [[ "$CONDA_DEFAULT_ENV" == data_env ]]; then
  echo "ERROR: Active environment is a protected CUDA env. Aborting."
  exit 1
fi
```

---

## PyTorch Replacement Prevention

All pip installs of custom nodes and packages must use a `constraints.txt` that pins the ROCm torch wheel:

```
# /mnt/c/ai_tools/comfyui-rocm/constraints.txt
torch==2.5.1+rocm6.2
torchvision==0.20.1+rocm6.2
torchaudio==2.5.1+rocm6.2
```

Install command pattern:
```bash
pip install <package> -c /mnt/c/ai_tools/comfyui-rocm/constraints.txt
```

This prevents any custom node's `requirements.txt` from silently replacing the ROCm torch with a CUDA build.
