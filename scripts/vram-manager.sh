#!/bin/bash
# vram-manager.sh
# VRAM 智能管理工具 - 在 llama-server 與 ComfyUI 之間切換
# 使用方式：bash vram-manager.sh [start|stop|status|switch-to-image|switch-to-text]

set -euo pipefail

COMFYUI_SERVICE="comfyui-rocm"
LLAMA_PROCESS="llama-server"
LOG_DIR="/mnt/c/ai_projects/rocm-image-generation-stack/logs"

# 顏色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}"
}

# 顯示 VRAM 狀態
show_status() {
    echo "=== VRAM 使用狀態 ==="
    if command -v rocm-smi &> /dev/null; then
        rocm-smi -a 2>/dev/null | grep -E "(GPU use|Memory Allocated|PROCESS NAME|VRAM USED|GPU Temp|Fan Speed)" || echo "無法讀取 rocm-smi"
    else
        echo "rocm-smi 未安裝"
    fi
    echo ""
    
    # 檢查 ComfyUI 服務狀態
    if systemctl is-active --quiet "$COMFYUI_SERVICE" 2>/dev/null; then
        echo -e "ComfyUI: ${GREEN}運行中${NC}"
    else
        echo -e "ComfyUI: ${RED}未運行${NC}"
    fi
    
    # 檢查 llama-server 狀態
    if pgrep -f "$LLAMA_PROCESS" > /dev/null 2>&1; then
        echo -e "llama-server: ${GREEN}運行中 (PID: $(pgrep -f "$LLAMA_PROCESS" | head -1))${NC}"
    else
        echo -e "llama-server: ${RED}未運行${NC}"
    fi
}

# 啟動 ComfyUI
start_comfyui() {
    if systemctl is-active --quiet "$COMFYUI_SERVICE" 2>/dev/null; then
        warn "ComfyUI 已在運行"
        return 0
    fi
    
    # 檢查 llama-server 的 VRAM 使用
    local llama_vram=0
    if pgrep -f "$LLAMA_PROCESS" > /dev/null 2>&1; then
        llama_vram=$(rocm-smi --showmemused -a 2>/dev/null | grep -A1 "llama-server" | awk '{print $NF}' | head -1 || echo 0)
        llama_vram=${llama_vram%%.*}  # 去掉小數點
        
        if [ "${llama_vram:-0}" -gt 28000 ]; then
            warn "llama-server 正在使用 ~${llama_vram}MB VRAM"
            warn "建議先關閉 llama-server 或準備 OOM"
            read -p "繼續啟動 ComfyUI? (y/N): " confirm
            [ "$confirm" != "y" ] && return 1
        fi
    fi
    
    sudo systemctl start "$COMFYUI_SERVICE"
    success "ComfyUI 已啟動"
}

# 停止 ComfyUI
stop_comfyui() {
    if ! systemctl is-active --quiet "$COMFYUI_SERVICE" 2>/dev/null; then
        warn "ComfyUI 未運行"
        return 0
    fi
    
    sudo systemctl stop "$COMFYUI_SERVICE"
    success "ComfyUI 已停止"
}

# 切換到圖像/影片生成模式
switch_to_image() {
    echo "🖼️  切換到 圖像/影片生成模式..."
    
    # 如果 llama-server 在運行，溫和終止
    if pgrep -f "$LLAMA_PROCESS" > /dev/null 2>&1; then
        warn "正在停止 llama-server..."
        pkill -INT -f "$LLAMA_PROCESS" 2>/dev/null || true
        sleep 3
        
        # 確認是否已停止
        if pgrep -f "$LLAMA_PROCESS" > /dev/null 2>&1; then
            warn "llama-server 未回應 INT 訊號，發送 KILL..."
            pkill -9 -f "$LLAMA_PROCESS" 2>/dev/null || true
            sleep 2
        fi
        
        success "llama-server 已停止，VRAM 已釋放"
    fi
    
    # 啟動 ComfyUI
    start_comfyui
}

# 切換到 LLM 模式
switch_to_text() {
    echo "📝 切換到 LLM 模式..."
    
    # 停止 ComfyUI
    stop_comfyui
    
    success "ComfyUI 已停止，VRAM 已釋放"
    warn "請手動啟動 llama-server"
}

# 主程式
case "${1:-status}" in
    "start")
        start_comfyui
        ;;
    "stop")
        stop_comfyui
        ;;
    "status")
        show_status
        ;;
    "switch-to-image")
        switch_to_image
        ;;
    "switch-to-text")
        switch_to_text
        ;;
    *)
        echo "用法：$0 [start|stop|status|switch-to-image|switch-to-text]"
        echo ""
        echo "  start           - 啟動 ComfyUI"
        echo "  stop            - 停止 ComfyUI"
        echo "  status          - 顯示 VRAM 狀態"
        echo "  switch-to-image - 切換到圖像/影片生成模式（停止 llama-server）"
        echo "  switch-to-text  - 切換到 LLM 模式（停止 ComfyUI）"
        ;;
esac
