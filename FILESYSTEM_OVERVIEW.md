# Filesystem Overview
Detailed mapping of the host filesystem based on audit logs.

## AI Infrastructure Paths
- **Primary Model Root:** `/mnt/c/ai_models/diffusion/diffusion_models/`
- **Tools Root:** `/mnt/c/ai_tools`
- **Projects Root:** `/mnt/c/ai_projects`
- **Cache Root:** `/mnt/c/ai_cache`
- **Data Root:** `/mnt/data`
- **User Configs:** `/home/justin`

## Notable Configurations Found
- **OpenClaw:** `/home/justin/.openclaw/openclaw.json`
- **Qwen Configs:** `/home/justin/.qwen/settings.json`
- **LTX Desktop:** `/home/justin/.LTXDesktop/comfyui-settings.json`
- **LLMProvider Settings:** `/home/justin/.llm_provider/settings.json`

## System Structure Summary
The environment is a hybrid Windows/Linux (WSL2) setup where heavy assets reside on the C: drive (`/mnt/c`) for persistence and accessibility, while configurations and environments are managed within the Linux home directory.
