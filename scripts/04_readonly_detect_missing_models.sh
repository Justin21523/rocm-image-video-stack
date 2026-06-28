# Read-only Missing Model Detection
# Cross-references found models against a target list (placeholder logic).
#!/bin/bash
set -e
LOG_FILE="/mnt/c/ai_projects/rocm-image-generation-stack/logs/gap_report.log"
echo "--- Gap Analysis Starting ---" > "$LOG_FILE"

echo "Checking for FLUX models..." >> "$LOG_FILE"
grep -ri "flux" /mnt/c/ai_models >> "$LOG_FILE" 2>&1

echo "Checking for Wan video models..." >> "$LOG_FILE"
grep -ri "wan" /mnt/c/ai_models >> "$LOG_FILE" 2>&1

echo "--- Gap Analysis Complete ---" >> "$LOG_FILE"
