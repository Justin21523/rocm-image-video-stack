# Read-only ComfyUI CUDA Stack Audit
# Scans existing ComfyUI folders and conda environments.
#!/bin/bash
set -e
LOG_FILE="/mnt/c/ai_projects/rocm-image-generation-stack/logs/cuda_stack_audit.log"
echo "--- CUDA Stack Audit Starting ---" > "$LOG_FILE"

echo "[1/2] Listing Conda Environments..." >> "$LOG_FILE"
conda env list >> "$LOG_FILE" 2>&1

echo "[2/2] Checking /mnt/c/ai_tools for ComfyUI installations..." >> "$LOG_FILE"
find /mnt/c/ai_tools -maxdepth 2 -name "ComfyUI" >> "$LOG_FILE" 2>&1

echo "--- Audit Complete ---" >> "$LOG_FILE"
