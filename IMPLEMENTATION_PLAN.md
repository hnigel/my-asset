# Total Gain/Loss Implementation Plan

## 需求分析
在投資組合的 Total Value 下方新增 Total Gain/Loss 金額顯示，幫助用戶快速了解整體投資績效。

## 當前實現分析

### 現有架構 (`PortfolioDetailView.swift:325-390`)
- `PortfolioSummaryCard` 顯示 Total Value 和 Holdings 數量
- Total Value 計算：`currentPrice * quantity` 總和
- 個別持股的 gain/loss 已在 `HoldingRowView` 中實現

### 資料模型 (Core Data)
- `Holding` 實體包含：
  - `pricePerShare`: 購買時每股價格 (Decimal)
  - `quantity`: 持股數量 (Int32)  
  - `datePurchased`: 購買日期
- `Stock` 實體包含：
  - `currentPrice`: 當前股價 (Decimal)

### 現有計算邏輯 (`PortfolioDetailView.swift:522-528`)
```swift
private var gainLoss: Decimal {
    currentValue - purchaseValue
}
```

## 實現方案

### Stage 1: 在 PortfolioSummaryCard 添加總損益計算
**目標**: 實現投資組合總損益計算邏輯  
**成功標準**: 正確計算所有持股的總損益  
**測試**: 驗證計算準確性，包括正負值情況  
**狀態**: ✅ Complete

### Stage 2: 修改 UI 佈局
**目標**: 在 Total Value 下方添加 Total Gain/Loss 顯示  
**成功標準**: UI 排版美觀，與現有設計風格一致  
**測試**: 不同金額和正負值的視覺效果  
**狀態**: ✅ Complete

### Stage 3: 添加視覺化指示
**目標**: 根據損益狀態顯示顏色和圖標  
**成功標準**: 盈利顯示綠色上箭頭，虧損顯示紅色下箭頭  
**測試**: 各種損益情況的視覺反饋  
**狀態**: ✅ Complete

## 技術細節

### 計算邏輯
```swift
private var totalGainLoss: Decimal {
    holdings.reduce(0) { total, holding in
        let currentPrice = holding.stock?.effectiveCurrentPrice ?? 0
        let purchasePrice = holding.pricePerShare?.decimalValue ?? 0
        let quantity = Decimal(holding.quantity)
        let currentValue = currentPrice * quantity
        let purchaseValue = purchasePrice * quantity
        return total + (currentValue - purchaseValue)
    }
}
```

### UI 組件修改位置
- 文件：`PortfolioDetailView.swift`
- 組件：`PortfolioSummaryCard` (第 325-390 行)
- 修改位置：在 Total Value VStack 下方添加新的 VStack

### 設計模式
- 遵循現有的 HStack 佈局結構
- 使用與 Total Value 相同的字體和樣式層次
- 保持與現有組件的視覺一致性

## 風險評估
- **低風險**: 僅在現有 UI 添加顯示，不修改資料模型
- **無破壞性**: 不影響現有功能和資料流
- **向後兼容**: 對現有持股資料完全兼容

## 狀態：✅ 所有階段完成

### 實現摘要
1. ✅ **Stage 1**: 添加了 `totalGainLoss` 和 `totalPurchaseValue` 計算邏輯
2. ✅ **Stage 2**: 將 `PortfolioSummaryCard` 重構為垂直佈局，添加了第二行顯示總損益
3. ✅ **Stage 3**: 實現了視覺化指示器：
   - 綠色上箭頭表示盈利
   - 紅色下箭頭表示虧損
   - 金額顏色根據盈虧狀態動態變化
   - 添加了 Purchase Value 作為參考

### 技術實現細節
- 保持了與現有設計風格的一致性
- 使用了與 `HoldingRowView` 相同的計算模式
- 非破壞性實現，完全向後兼容
- 遵循了 SwiftUI 最佳實踐