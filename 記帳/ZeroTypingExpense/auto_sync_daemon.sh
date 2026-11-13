#!/bin/bash
# ==============================================================================
# ZeroTypingExpense - iPhone Auto-Update Background Daemon
# Automatically detects connected & unlocked iPhone and installs latest app build
# ==============================================================================

PROJECT_DIR="/Users/harryng/Desktop/Vibe coding/記帳/ZeroTypingExpense"
INSTALL_SCRIPT="$PROJECT_DIR/install_to_phone.sh"
DEVICE_ID="00008130-00045D4036E0001C"
LAST_SYNC_FILE="$HOME/.zerotyping_last_sync"
LOCK_FILE="/tmp/zerotyping_autosync.lock"
LOG_FILE="$HOME/Library/Logs/zerotyping_autoupdate.log"
SYNC_INTERVAL_HOURS=24
POLL_SLEEP_SEC=30

mkdir -p "$HOME/Library/Logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

notify() {
    local title="$1"
    local message="$2"
    local sound="${3:-default}"
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"$sound\"" 2>/dev/null || true
}

cleanup() {
    rm -f "$LOCK_FILE"
    log "Auto-update daemon stopped."
    exit 0
}

trap cleanup SIGINT SIGTERM

log "🚀 零打字記帳 自動同步服務運行中 (目標設備: iPhone 15 Pro - $DEVICE_ID)"

while true; do
    # 1. 檢測設備狀態
    DEVICE_LINE=$(xcrun devicectl list devices --search "$DEVICE_ID" 2>/dev/null | grep "$DEVICE_ID" || true)

    if [ -n "$DEVICE_LINE" ]; then
        # 判斷是否處於可用/已解鎖狀態 (connected 或 available)
        if echo "$DEVICE_LINE" | grep -q -E "available|connected"; then
            # 2. 檢查上次同步時間
            NOW=$(date +%s)
            LAST_SYNC=0
            if [ -f "$LAST_SYNC_FILE" ]; then
                LAST_SYNC=$(cat "$LAST_SYNC_FILE" 2>/dev/null || echo 0)
            fi

            DIFF_HOURS=$(( (NOW - LAST_SYNC) / 3600 ))

            if [ "$DIFF_HOURS" -ge "$SYNC_INTERVAL_HOURS" ]; then
                # 防止並發
                if [ -f "$LOCK_FILE" ]; then
                    log "⚠️ 另一個同步程序正在執行中，跳過本次觸發。"
                else
                    touch "$LOCK_FILE"
                    log "📱 偵測到 iPhone 15 Pro 已連線且解鎖 (距離上次更新已過 ${DIFF_HOURS} 小時)。準備執行自動更新..."
                    notify "零打字記帳 自動同步" "📱 偵測到 iPhone 已連線，正在自動更新並刷新 7 天憑證..." "default"

                    # 3. 呼叫安裝腳本
                    if bash "$INSTALL_SCRIPT" >> "$LOG_FILE" 2>&1; then
                        echo "$NOW" > "$LAST_SYNC_FILE"
                        log "✅ 自動更新完成！7 天憑證已重設。"
                        notify "零打字記帳 自動同步" "🎉 已成功將最新版本安裝至 iPhone！7 天憑證已重設。" "Glass"
                    else
                        log "❌ 自動更新執行失敗，請檢查日誌: $LOG_FILE"
                        notify "零打字記帳 自動同步" "⚠️ 自動更新遇到問題，請確認手機已解鎖或 Xcode 憑證已授權。" "Basso"
                    fi

                    rm -f "$LOCK_FILE"
                fi
            fi
        fi
    fi

    sleep "$POLL_SLEEP_SEC"
done
