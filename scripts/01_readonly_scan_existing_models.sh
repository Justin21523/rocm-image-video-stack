# Read-only Model Inventory Scan
# This script scans /mnt/c/ai_models to identify existing weights.
#!/bin/bash
set -e
LOG_FILE="/mnt/c/ai_projects/rocm-image-generation-stack/logs/model_inventory.log"
MODEL_ROOT="/mnt/c/ai_models"
echo "--- Model Inventory Scan Starting ---" > "$LOG_FILE"

echo "Scanning $MODEL_ROOT..." >> "$LOG_FILE"
find "$MODEL_ROOT" -type f \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.bin" -o -name "*.gguf" \) >> "$LOG_FILE" 2>&1

echo "--- Scan Complete ---" >> "$LOG_FILE"
