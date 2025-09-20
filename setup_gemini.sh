#!/bin/bash

echo "🔧 Gemini API Key 設定工具"
echo "=========================="

# 檢查是否已有 API Key
if [ -n "$GEMINI_API_KEY" ]; then
    echo "✅ 目前已設定 GEMINI_API_KEY"
    echo "Key 長度: ${#GEMINI_API_KEY} 字元"
    echo "Key 預覽: ${GEMINI_API_KEY:0:8}..."
else
    echo "❌ GEMINI_API_KEY 尚未設定"
    echo ""
    echo "請設定您的 Gemini API Key："
    echo "export GEMINI_API_KEY=\"您的API Key\""
    echo ""
    echo "取得 API Key 的步驟："
    echo "1. 前往 https://aistudio.google.com/app/apikey"
    echo "2. 創建新的 API Key"
    echo "3. 複製 API Key"
    echo "4. 執行上述 export 命令"
fi

echo ""
echo "💡 提示："
echo "- API Key 通常以 'AIzaSy' 開頭"
echo "- 長度約 39 個字元"
echo "- 設定後請重新啟動 app"