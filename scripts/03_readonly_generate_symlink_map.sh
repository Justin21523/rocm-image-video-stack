# Read-only Symlink Map Generation
# Maps symlinks in ComfyUI model directories.
#!/bin/bash
set -e
LOG_FILE="/mnt/c/ai_projects/rocm-image-generation-stack/logs/symlink_map.log"
echo "--- Symlink Mapping Starting ---" > "$LOG_FILE"

# Search for symlinks in ComfyUI model folders
find /mnt/c/ai_tools -type l -path "*/models/*" -exec ls -l {} \; >> "$LOG_FILE" 2>&1

echo "--- Mapping Complete ---" >> "$LOG_FILE"
