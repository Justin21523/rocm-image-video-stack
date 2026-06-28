#!/bin/bash
# comfyui-cron-jobs.sh
# 設定 OpenClaw Cron 排程任務
# 使用方式：bash comfyui-cron-jobs.sh [install|remove|list]

set -euo pipefail

echo "🔧 OpenClaw Cron 排程設定"
echo ""

case "${1:-install}" in
    "install")
        echo "安裝以下 Cron 任務："
        echo ""
        echo "1. GPU 健康檢查（每 2 小時）"
        openclaw cron add \
          --name "GPU Health Check" \
          --cron "0 */2 * * *" \
          --tz "Asia/Taipei" \
          --session isolated \
          --message "執行 rocm-smi 檢查 R9700 溫度與 VRAM 使用，如果有異常請通知使用者" \
          --tools exec,read \
          --light-context
        echo ""

        echo "2. ComfyUI 服務監控（每 30 分鐘）"
        openclaw cron add \
          --name "ComfyUI Monitor" \
          --cron "*/30 * * * *" \
          --tz "Asia/Taipei" \
          --session isolated \
          --message "檢查 ComfyUI 服務是否運行正常，如果當機請嘗試重啟" \
          --tools exec,read \
          --light-context
        echo ""

        echo "3. VRAM 清理提醒（每天早上 8 點）"
        openclaw cron add \
          --name "VRAM Cleanup Reminder" \
          --cron "0 8 * * *" \
          --tz "Asia/Taipei" \
          --session main \
          --system-event "檢查 VRAM 使用狀況，如果 llama-server 佔用太多 VRAM，提醒使用者" \
          --wake now
        echo ""

        echo "✅ Cron 任務已安裝！"
        echo ""
        echo "查看任務列表：openclaw cron list"
        ;;

    "remove")
        echo "移除 Cron 任務..."
        echo "請執行：openclaw cron list"
        echo "然後使用：openclaw cron delete <job-id>"
        ;;

    "list")
        openclaw cron list
        ;;

    *)
        echo "用法：$0 [install|remove|list]"
        ;;
esac
