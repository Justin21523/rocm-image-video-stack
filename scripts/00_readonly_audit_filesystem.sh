# Read-only Filesystem Audit
# This script scans for OpenClaw and AI tool configurations.
#!/bin/bash
set -e
LOG_FILE="/mnt/c/ai_projects/rocm-image-generation-stack/logs/audit_filesystem.log"
echo "--- Filesystem Audit Starting ---" > "$LOG_FILE"

echo "[1/3] Scanning /home/justin for AI configs..." >> "$LOG_FILE"
find /home/justin -maxdepth 3 -name "*openclaw*" -o -name "*.json" -o -name "*.yaml" -o -name "*.toml" >> "$LOG_FILE" 2>&1

echo "[2/3] Scanning for ComfyUI shortcuts/desktop entries..." >> "$LOG_FILE"
find /home/justin -name "*.desktop" | grep -i "comfyui" >> "$LOG_FILE" 2>&1

echo "[3/3] Scanning /mnt/c/ai_tools for existing installations..." >> "$LOG_FILE"
ls -R /mnt/c/ai_tools >> "$LOG_FILE" 2>&1

echo "--- Audit Complete ---" >> "$LOG_FILE"
