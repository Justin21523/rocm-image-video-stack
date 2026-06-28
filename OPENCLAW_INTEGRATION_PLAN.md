# OpenClaw ComfyUI Integration Plan

## Overview

This document outlines three approaches to integrate ComfyUI (running on AMD R9700/ROCm) with OpenClaw for automated image, video, and music generation.

---

## Approach 1: OpenClaw Built-in Comfy Plugin (⭐ Recommended)

**Source:** OpenClaw official docs (`docs.openclaw.ai/providers/comfy`)

### Pros
- No extra installation needed — OpenClaw already has the `comfy` plugin
- Supports `image_generate`, `video_generate`, `music_generate` tools
- Simple configuration: just set `workflowPath`, `promptNodeId`, `outputNodeId`
- Supports both local ComfyUI and Comfy Cloud

### Configuration Example
```json5
{
  plugins: {
    entries: {
      comfy: {
        config: {
          mode: "local",
          baseUrl: "http://127.0.0.1:8188",
          image: {
            workflowPath: "/mnt/c/ai_projects/rocm-image-generation-stack/workflows/flux-t2i.json",
            promptNodeId: "6",
            outputNodeId: "9",
          },
          video: {
            workflowPath: "/mnt/c/ai_projects/rocm-image-generation-stack/workflows/wan-t2v.json",
            promptNodeId: "12",
            outputNodeId: "21",
          },
        },
      },
    },
  },
  agents: {
    defaults: {
      imageGenerationModel: { primary: "comfy/workflow" },
      videoGenerationModel: { primary: "comfy/workflow" },
    },
  },
}
```

### Setup Steps
1. Ensure ComfyUI is running on `http://127.0.0.1:8188`
2. Export workflow JSONs from ComfyUI (API format)
3. Identify `promptNodeId` and `outputNodeId` in each workflow
4. Add config to `~/.openclaw/config.json`
5. Test with: `openclaw models list --provider comfy`

---

## Approach 2: ComfyUI Skills for OpenClaw (Community Skill)

**Source:** [HuangYuChuh/ComfyUI_Skills_OpenClaw](https://github.com/HuangYuChuh/ComfyUI_Skills_OpenClaw)

### Pros
- CLI tool `comfyui-skill` for workflow management
- Schema-based parameter mapping
- Optional Web UI for visual management
- Multi-server support

### Installation
```bash
cd ~/.openclaw/workspace/skills
git clone https://github.com/HuangYuChuh/ComfyUI_Skills_OpenClaw.git comfyui-skill-openclaw
cd comfyui-skill-openclaw
pip install comfyui-skill-cli
cp config.example.json config.json
```

---

## Approach 3: ComfyUI-OpenClaw (Custom Node)

**Source:** [rookiestar28/ComfyUI-OpenClaw](https://github.com/rookiestar28/ComfyUI-OpenClaw)

### Pros
- Full ComfyUI custom node with admin console
- LLM-assisted nodes (planner/refiner/vision/batch)
- 8 messaging platform support (Discord, Telegram, WhatsApp, etc.)
- Security features (RBAC, CSRF, HMAC, audit)

### Installation
```bash
cd /mnt/c/ai_tools/comfyui-rocm/custom_nodes
git clone https://github.com/rookiestar28/ComfyUI-OpenClaw.git
```

---

## Automation Scripts

### 1. Systemd Service
- File: `scripts/comfyui-rocm.service`
- Install: `sudo bash scripts/install-comfyui-service.sh`
- Manages: auto-start, restart on failure, resource limits

### 2. VRAM Manager
- File: `scripts/vram-manager.sh`
- Usage: `bash scripts/vram-manager.sh [start|stop|status|switch-to-image|switch-to-text]`
- Features: intelligent switching between llama-server and ComfyUI

### 3. Cron Jobs
- File: `scripts/comfyui-cron-jobs.sh`
- Usage: `bash scripts/comfyui-cron-jobs.sh [install|remove|list]`
- Jobs: GPU health check, ComfyUI monitor, VRAM cleanup reminder

### 4. OpenClaw Integration Setup
- File: `scripts/setup-openclaw-comfy-integration.sh`
- Usage: `bash scripts/setup-openclaw-comfy-integration.sh`
- Guides: step-by-step OpenClaw config setup

---

## Next Steps

1. [ ] Choose integration approach (recommendation: Approach 1)
2. [ ] Export API-format workflow JSONs from ComfyUI
3. [ ] Configure OpenClaw comfy plugin
4. [ ] Install systemd service for ComfyUI
5. [ ] Set up VRAM manager for intelligent switching
6. [ ] Configure cron jobs for monitoring
7. [ ] Test end-to-end: OpenClaw → ComfyUI → R9700 → Output

---

## References

- OpenClaw ComfyUI docs: https://docs.openclaw.ai/providers/comfy
- ComfyUI Skills: https://github.com/HuangYuChuh/ComfyUI_Skills_OpenClaw
- ComfyUI-OpenClaw: https://github.com/rookiestar28/ComfyUI-OpenClaw
- ClawHub ComfyUI Skill: https://clawhub.ai/salmonrk/openclaw-comfyui
