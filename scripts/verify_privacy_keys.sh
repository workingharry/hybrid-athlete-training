#!/bin/bash
set -euo pipefail

# TDD Verification Script: Privacy Keys in Info.plist
INFO_PLIST="HybridTrainingApp/Resources/Info.plist"

echo "🧪 [TDD Test] Checking mandatory privacy keys in $INFO_PLIST..."

MISSING=0
for KEY in NSCameraUsageDescription NSPhotoLibraryUsageDescription; do
    if /usr/libexec/PlistBuddy -c "Print :$KEY" "$INFO_PLIST" > /dev/null 2>&1; then
        VAL=$(/usr/libexec/PlistBuddy -c "Print :$KEY" "$INFO_PLIST")
        echo "  ✅ Found $KEY: \"$VAL\""
    else
        echo "  ❌ MISSING mandatory key: $KEY (causes SIGABRT / SpringBoard crash)"
        MISSING=$((MISSING + 1))
    fi
done

if [ "$MISSING" -gt 0 ]; then
    echo "❌ [TDD RED] $MISSING privacy keys missing from Info.plist."
    exit 1
else
    echo "✅ [TDD GREEN] All camera and photo library privacy keys verified."
    exit 0
fi
