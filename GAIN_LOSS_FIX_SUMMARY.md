# Gain/Loss Calculation Discrepancy Fix Summary

## Issue Description
The gain/loss values shown in green text in the holdings UI list were different from the values shown in the export functionality, causing user confusion about which values were correct.

## Root Cause Analysis

### Initial Investigation
- Both UI and export used mathematically identical calculations:
  - **Formula**: `currentValue - purchaseValue`  
  - **Where**: `currentValue = currentPrice * quantity` and `purchaseValue = purchasePrice * quantity`

### Key Discovery
The issue was **not** in the calculation logic but in the **display formatting**:

- **UI Formatting**: Used SwiftUI's `.currency(code: "USD")` format showing decimal places (e.g., `$123.45`)
- **Export Formatting**: Used `NumberFormatter` with `maximumFractionDigits = 0` showing whole dollars (e.g., `$123`)

## Solution Implemented

### 1. Created Centralized Calculator (`HoldingGainLossCalculator`)
- Unified calculation logic for both UI and export
- Added comprehensive debug logging
- Added formatting comparison utilities
- Ensured identical data access patterns

### 2. Standardized Formatting
- Updated `HoldingRowView` to use the same currency formatting as `TextExportManager`
- Both now display whole dollars without decimal places
- Consistent currency formatting across all value displays (current value, gain/loss, current price)

### 3. Files Modified
- `PortfolioDetailView.swift` - Updated HoldingRowView formatting
- `TextExportManager.swift` - Added centralized calculator usage  
- `HoldingGainLossCalculator.swift` - New utility class (created)

## Technical Changes

### Before
```swift
// UI
Text(gainLoss, format: .currency(code: "USD"))  // Shows $123.45

// Export  
formatter.maximumFractionDigits = 0             // Shows $123
```

### After
```swift
// Both UI and Export use identical formatting
private func formatGainLoss(_ amount: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "en_US")
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0"
}
```

## Verification
- UI now displays gain/loss values identically to export
- Both use whole dollar formatting (no decimal places)
- Calculation logic is centralized and identical
- Debug logging available to verify data consistency

## Result
✅ **Issue Resolved**: UI and export now show identical gain/loss values using consistent formatting and calculation logic.

The discrepancy was purely cosmetic due to different number formatting, not actual calculation errors. Users will now see consistent values across both interfaces.