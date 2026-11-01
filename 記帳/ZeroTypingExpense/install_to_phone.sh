#!/bin/bash
set -e

DEVICE_ID="00008130-00045D4036E0001C"
APP_PATH="/Users/harryng/Library/Developer/Xcode/DerivedData/ZeroTypingExpense-agrrtbazebvaqxhkohtzgsshepbr/Build/Products/Debug-iphoneos/零打字記帳.app"

echo "=================================================="
echo "📱 正在安裝「零打字記帳」至你的 iPhone 15 Pro..."
echo "=================================================="

if ! xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"; then
    echo ""
    echo "⚠️ 安裝失敗：請確認你的 iPhone 螢幕已解鎖（輸入密碼或 Face ID），並確認已透過 USB 傳輸線或同網段 Wi-Fi 連線至 Mac。"
    exit 1
fi

echo ""
echo "✅ 成功安裝「零打字記帳」至你的 iPhone！"
echo "請在手機主畫面上查看剛配置的 App 圖示與應用標籤。"
