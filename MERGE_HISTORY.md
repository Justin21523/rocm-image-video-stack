# Merge History

## 2026-05-08: Merged `rocm-image-generation-stack` into `rocm-image-video-stack`

### Background

Two ROCm migration projects existed under `/mnt/c/ai_projects/`:
- **`rocm-image-generation-stack`** (41MB) — earlier version, mostly plan documents (PLAN), limited execution
- **`rocm-image-video-stack`** (560KB → ~5MB post-merge) — later version, implementation-focused, full phase system, execution logs

`rocm-image-video-stack` was the advanced version with more complete documentation, scripts, and execution history.

### What Was Merged

| Source | Destination | Action |
|--------|-------------|--------|
| 7 shared files | video-stack originals | **Kept video-stack versions** (all 7 were more complete) |
| 17 unique .md files | video-stack root | **Copied** (FLUX_PLAN, WAN_VIDEO_PLAN, Z_IMAGE_PLAN, etc.) |
| scripts/ (10 files) | video-stack/scripts/ | **Merged** — no name conflicts, all 10 unique |
| workflows/ (5 unique dirs) | video-stack/workflows/ | **Merged** — flux, qwen-image, stable-diffusion, wan-video, z-image |
| configs/model_roots.yaml | video-stack/configs/ | **Copied** (unique) |
| configs/protected_paths.yaml | — | **Skipped** (video-stack version 2763B vs gen 75B) |
| logs/ (7 files) | video-stack/logs/ | **Copied** |
| reports/ (empty) | — | **Skipped** |

### Shared Files — Version Decision

All 7 shared files were significantly larger/more complete in `rocm-image-video-stack`:

| File | gen-stack | video-stack | Decision |
|------|-----------|-------------|----------|
| README.md | 538B / 12 lines | 4,370B / 122 lines | ✅ video |
| SAFETY_POLICY.md | 759B / 18 lines | 5,401B / 165 lines | ✅ video |
| CUSTOM_NODE_COMPATIBILITY_MATRIX.md | 64B / 2 lines | 7,132B / 165 lines | ✅ video |
| EXISTING_CUDA_STACK_AUDIT.md | 1,094B / 30 lines | 8,780B / 206 lines | ✅ video |
| MODEL_SYMLINK_MAP.md | 85B / 2 lines | 5,337B / 150 lines | ✅ video |
| VALIDATION_PLAN.md | 47B / 2 lines | 9,330B / 312 lines | ✅ video |
| WORKFLOW_MIGRATION_PLAN.md | 55B / 2 lines | 5,293B / 181 lines | ✅ video |

### Post-Merge State

`rocm-image-video-stack` now contains:
- **29 scripts** (Phase 0-13 + utility scripts)
- **10 workflow directories** (comfyui-rocm, flux, image-to-video, ltx23, qwen-image, stable-diffusion, text-to-video, validation, wan-video, z-image)
- **7 config files**
- **26 log files**
- **5 report files**
- **~30 documentation files**

`rocm-image-generation-stack` was deleted after verified merge.
