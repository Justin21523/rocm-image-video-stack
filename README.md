# ROCm Image/Video AI Stack
## AMD Radeon AI PRO R9700 — Parallel Stack for Image and Video Generation

---

## Purpose

This project builds a **complete AMD ROCm image and video AI pipeline** for the Radeon AI PRO R9700 (gfx1201, 32GB HBM) running alongside an existing NVIDIA/CUDA stack on the same machine.

The stack is **parallel and non-destructive**: it never modifies, deletes, or overwrites any existing CUDA tools, conda environments, model files, workflows, or project data under `/mnt/c`.

---

## System Context

| Item | Detail |
|------|--------|
| GPU | AMD Radeon AI PRO R9700 (gfx1201, RDNA4, 64 CUs, 32 GB HBM) |
| ROCm | 7.2.3 at `/opt/rocm` |
| PyTorch | 2.5.1+rocm6.2 (upgrade to 2.9+rocm7.2 recommended in Phase 2) |
| OS | Ubuntu 24.04 (WSL2) |
| Prior GPU | NVIDIA RTX 5080 (replaced; CUDA stack preserved read-only) |
| Project root | `/mnt/c/ai_projects/rocm-image-video-stack/` |

---

## What This Stack Builds

| Component | Target Path | Conda Env |
|-----------|-------------|-----------|
| ComfyUI ROCm | `/mnt/c/ai_tools/comfyui-rocm/` | `rocm-comfyui-r9700` |
| Diffusers ROCm | (Python package) | `rocm-diffusers-r9700` |
| LTX-2.3 direct | (Python package) | `rocm-ltx23-r9700` |
| Video tools | (Python packages) | `rocm-video-r9700` |
| LoRA training | (Python packages) | `rocm-lora-r9700` |

All model files are shared via symlinks from `/mnt/c/ai_models/`. No large files are duplicated.

---

## CUDA Preservation Guarantee

The following are **never modified** by any script in this project:

- `/mnt/c/ai_tools/comfyui` (CUDA ComfyUI)
- `/mnt/c/ai_tools/LTX-2`, `/mnt/c/ai_tools/LTX-Video`, `/mnt/c/ai_tools/LTX-Video-Trainer`
- `/mnt/c/ai_tools/Comfy-LTX-Desktop`
- `/mnt/c/ai_models/` (all model files)
- All existing conda environments: `comfyui`, `kohya_ss`, `ai_env`, `audio_env`, `data_env`
- Any existing project data, images, videos, Blender assets, or datasets

See `SAFETY_POLICY.md` for the complete policy and forbidden command list.

---

## Phase System

| Phase | Description | Script(s) | Approval Required |
|-------|-------------|-----------|-------------------|
| 0 | Read-only audit of existing CUDA stack | 00, 01 | No (read-only) |
| 1 | Workspace preparation | 02 | No (mkdir only) |
| 2 | ROCm conda env validation / upgrade | 03 | Yes |
| 3 | ComfyUI ROCm installation | 04 | Yes |
| 4 | Model symlinks | 05 | Yes |
| 5 | Safe custom nodes | 06 | Yes |
| 6 | LTX 2.3 base T2V workflow | 07–10 | Yes |
| 7 | LTX 2.3 image-to-video workflow | — | Yes |
| 8 | LTX 2.3 IC-LoRA / ID-LoRA / control | — | Yes |
| 9 | Video processing tools | 11, 12 | Yes |
| 10 | Validation and benchmark reports | all validate | No (read tests) |

---

## Quick Start

### Phase 0 — Read-Only Audit (safe, no approval needed)
```bash
bash scripts/00_readonly_audit_existing_cuda_stack.sh
bash scripts/01_generate_model_symlink_report.sh
# Review reports/ folder for findings
```

### Phase 3 — ComfyUI ROCm (requires approval)
```bash
# After explicit approval:
bash scripts/04_setup_comfyui_rocm.sh
# ComfyUI ROCm will be at: /mnt/c/ai_tools/comfyui-rocm/
# Launch on port 8189 (CUDA ComfyUI stays on 8188)
```

### Phase 6 — First LTX 2.3 Generation
```bash
# After ComfyUI ROCm + model symlinks are ready:
bash scripts/09_prepare_ltx23_models.sh   # audit mode (safe)
# Then approve download of Gemma-3-12B (24.4 GB)
# Then:
bash scripts/10_validate_ltx23_comfyui_workflow.sh
```

---

## Key Documents

| Document | Purpose |
|----------|---------|
| `SAFETY_POLICY.md` | Protected paths, forbidden commands |
| `EXISTING_CUDA_STACK_AUDIT.md` | Inventory of existing tools and models |
| `ROCM_IMAGE_VIDEO_PLAN.md` | Full 10-phase staged plan |
| `LTX23_RESEARCH_REPORT.md` | LTX 2.3 research: architecture, models, ROCm risks |
| `LTX23_ROCM_IMPLEMENTATION_PLAN.md` | Practical implementation for R9700 |
| `COMFYUI_ROCM_IMPLEMENTATION.md` | ComfyUI ROCm setup details |
| `MODEL_SYMLINK_MAP.md` | Model symlink strategy (commands, not executed) |
| `CUSTOM_NODE_COMPATIBILITY_MATRIX.md` | Node risk classification |
| `WORKFLOW_MIGRATION_PLAN.md` | How to migrate CUDA workflows to ROCm |
| `VALIDATION_PLAN.md` | 10-test validation suite |

---

## Language Policy

- All code, scripts, configs, comments, and documentation: **English**
- Progress explanations to user: Traditional Chinese permitted
