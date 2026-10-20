#!/usr/bin/env bash
set -euo pipefail

SCHEME="HybridTrainingApp"
DEVICE_UDID="00008130-00045D4036E0001C"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "📱 目標實體設備 UDID: $DEVICE_UDID"

echo "⚙️ 正在重新生成 Xcode 專案配置..."
cd "$PROJECT_DIR"
xcodegen generate

echo "🔨 正在編譯專案 ($SCHEME)..."
xcodebuild -scheme "$SCHEME" \
    -destination "generic/platform=iOS" \
    -configuration Debug \
    -allowProvisioningUpdates \
    build

APP_PATH="/Users/harryng/Library/Developer/Xcode/DerivedData/HybridTrainingApp-fkaujmoeolpdrjghpnmlhjsvrwlb/Build/Products/Debug-iphoneos/HybridTrainingApp.app"

echo "📦 正在推送安裝至實體設備 ($APP_PATH)..."
xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"

echo "🚀 正在重啟 App (com.vibe.HybridTrainingApp)..."
xcrun devicectl device process launch --device "$DEVICE_UDID" --terminate-existing com.vibe.HybridTrainingApp

echo "✅ 部署完成！新版 App Icon 與最新介面已成功在 iPhone 上啟動。"
