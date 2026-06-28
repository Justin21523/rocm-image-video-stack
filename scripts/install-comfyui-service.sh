#!/bin/bash
# install-comfyui-service.sh
# 安裝 ComfyUI ROCm 為 systemd service
# 使用方式：sudo bash install-comfyui-service.sh

set -euo pipefail

echo "🔧 安裝 ComfyUI ROCm systemd service..."

# 複製 service 檔案
sudo cp "$(dirname "$0")/comfyui-rocm.service" /etc/systemd/system/comfyui-rocm.service

# 重新載入 systemd
sudo systemctl daemon-reload

# 啟用開機啟動
sudo systemctl enable comfyui-rocm.service

echo "✅ ComfyUI ROCm service 已安裝！"
echo ""
echo "管理指令："
echo "  啟動：   sudo systemctl start comfyui-rocm"
echo "  停止：   sudo systemctl stop comfyui-rocm"
echo "  重啟：   sudo systemctl restart comfyui-rocm"
echo "  狀態：   sudo systemctl status comfyui-rocm"
echo "  日誌：   sudo journalctl -u comfyui-rocm -f"
echo "  取消開機啟動：sudo systemctl disable comfyui-rocm"
