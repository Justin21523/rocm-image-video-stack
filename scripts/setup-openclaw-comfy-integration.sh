#!/bin/bash
# setup-openclaw-comfy-integration.sh
# 設定 OpenClaw 的 ComfyUI 整合（內建 comfy plugin）
# 使用方式：bash setup-openclaw-comfy-integration.sh

set -euo pipefail

echo "🔧 設定 OpenClaw ComfyUI 整合..."
echo ""

OPENCLAW_CONFIG="${HOME}/.openclaw/config.json"
PROJECT_DIR="/mnt/c/ai_projects/rocm-image-generation-stack"
BLUEPRINTS_DIR="/mnt/c/ai_tools/comfyui-rocm/blueprints"

# 檢查 ComfyUI 是否在運行
if curl -s http://127.0.0.1:8188/system_stats > /dev/null 2>&1; then
    echo "✅ ComfyUI 正在運行 (http://127.00.1:8188)"
else
    echo "⚠️  ComfyUI 未運行，請先啟動 ComfyUI"
    echo "   指令：sudo systemctl start comfyui-rocm"
    exit 1
fi

# 建立 workflow 目錄
WORKFLOW_DIR="${PROJECT_DIR}/workflows"
mkdir -p "${WORKFLOW_DIR}"

echo "📁 建立 workflow 目錄：${WORKFLOW_DIR}"

# 複製 blueprints 到 workflow 目錄（作為範本）
if [ -d "${BLUEPRINTS_DIR}" ]; then
    cp "${BLUEPRINTS_DIR}"/*.json "${WORKFLOW_DIR}/" 2>/dev/null || true
    echo "✅ 已複製 blueprints 到 workflow 目錄"
fi

echo ""
echo "📝 請手動編輯 OpenClaw 配置："
echo "   ${OPENCLAW_CONFIG}"
echo ""
echo "或執行以下指令自動設定："
echo "   openclaw config set plugins.entries.comfy.config.mode 'local'"
echo "   openclaw config set plugins.entries.comfy.config.baseUrl 'http://127.0.0.1:8188'"
echo "   openclaw config set agents.defaults.imageGenerationModel.primary 'comfy/workflow'"
echo "   openclaw config set agents.defaults.videoGenerationModel.primary 'comfy/workflow'"
echo ""
echo "📋 需要設定的 workflow 路徑："
ls -la "${WORKFLOW_DIR}"/*.json 2>/dev/null || echo "   (目錄為空)"
echo ""
echo "🔗 參考文件：https://docs.openclaw.ai/providers/comfy"
