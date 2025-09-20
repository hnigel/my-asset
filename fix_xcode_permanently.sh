#!/bin/bash

# 永久修復 Xcode 開發者目錄問題
echo "🔧 修復 Xcode 開發者目錄設定..."

# 設定正確的環境變數
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

# 添加到用戶的 shell 配置檔案
SHELL_CONFIG=""
if [ -f ~/.zshrc ]; then
    SHELL_CONFIG=~/.zshrc
elif [ -f ~/.bash_profile ]; then
    SHELL_CONFIG=~/.bash_profile
elif [ -f ~/.bashrc ]; then
    SHELL_CONFIG=~/.bashrc
fi

if [ -n "$SHELL_CONFIG" ]; then
    if ! grep -q "DEVELOPER_DIR.*Xcode.app" "$SHELL_CONFIG"; then
        echo "" >> "$SHELL_CONFIG"
        echo "# Fix Xcode developer directory" >> "$SHELL_CONFIG"
        echo 'export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"' >> "$SHELL_CONFIG"
        echo "✅ 已添加 DEVELOPER_DIR 到 $SHELL_CONFIG"
    else
        echo "✅ DEVELOPER_DIR 已存在於 $SHELL_CONFIG"
    fi
fi

# 測試 xcodebuild
echo "🧪 測試 xcodebuild..."
xcodebuild -version

# 清理快取
echo "🧹 清理 Xcode 快取..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode*
rm -rf "my asset/my asset.xcodeproj/xcuserdata"

# 嘗試打開專案
echo "📱 嘗試打開專案..."
open "my asset/my asset.xcodeproj"

echo "✨ 修復完成！請重新啟動終端機以確保環境變數生效。"