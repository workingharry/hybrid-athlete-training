#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_ID="00008130-00045D4036E0001C"
PROJECT_PATH="$SCRIPT_DIR/ZeroTypingExpense.xcodeproj"

echo "=================================================="
echo "📱 正在執行「零打字記帳」7 天自動續簽與真機安裝 (方案 B)"
echo "=================================================="

# 1. 檢查 iPhone 連線狀態
echo "🔍 [1/3] 正在檢測 iPhone 15 Pro 連線狀態..."
DEVICE_STATUS=$(xcrun devicectl list devices 2>/dev/null | grep "$DEVICE_ID" || true)
if [ -z "$DEVICE_STATUS" ]; then
    echo "⚠️ 未檢測到 iPhone 15 Pro ($DEVICE_ID)。"
    echo "請確認 iPhone 已接上 USB 傳輸線（或處於同一 Wi-Fi），且螢幕已解鎖。"
    exit 1
fi

if echo "$DEVICE_STATUS" | grep -q "unavailable"; then
    echo "⚠️ 偵測到 iPhone 螢幕處於鎖定狀態。"
    echo "請先解鎖 iPhone 螢幕（輸入密碼或 Face ID），並點擊「信任這部電腦」。"
    exit 1
fi
echo "✅ iPhone 狀態正常：$DEVICE_STATUS"

# 2. 自動向 Apple 申請最新 7 天憑證並重新編譯
echo "🔨 [2/3] 正在編譯最新代碼並自動更新 7 天免費開發者憑證..."
DERIVED_DATA_DIR="/tmp/ZeroTypingExpenseDerivedData"

if ! xcodebuild -project "$PROJECT_PATH" \
    -scheme ZeroTypingExpense \
    -configuration Debug \
    -destination "id=$DEVICE_ID" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -allowProvisioningUpdates build; then
    echo ""
    echo "⚠️ 編譯或憑證續簽失敗。"
    echo "可能原因：Xcode 帳號登入狀態過期。請在 Xcode 頂部功能表「Settings ➔ Accounts」登入你的 Apple ID 後重試。"
    exit 1
fi

APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug-iphoneos/零打字記帳.app"

# 3. 透過 devicectl 安裝至 iPhone
echo "📲 [3/3] 正在將最新 App 寫入 iPhone 15 Pro..."
if ! xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"; then
    echo ""
    echo "⚠️ 安裝失敗：請確認 iPhone 螢幕維持解鎖狀態。"
    exit 1
fi

echo ""
echo "=================================================="
echo "🎉 成功安裝！7 天免費開發者憑證已刷新並重設倒數計時！"
echo "沙盒記帳資料 100% 完整保留，請在手機主畫面開啟使用。"
echo "=================================================="
