## Stage 1: Debug Gain/Loss Calculation Discrepancy
**Goal**: Add comprehensive logging to identify why UI and export show different gain/loss values
**Success Criteria**: Clear logs showing the exact values used in each calculation
**Tests**: Compare logged values between UI and export for same holdings
**Status**: In Progress

## Stage 2: Identify Root Cause
**Goal**: Determine the source of the calculation discrepancy
**Success Criteria**: Understand exactly why the calculations differ
**Tests**: Verify which calculation is correct by manual verification
**Status**: Not Started

## Stage 3: Fix UI Calculation
**Goal**: Ensure HoldingRowView uses identical calculation to TextExportManager
**Success Criteria**: UI and export show identical gain/loss values
**Tests**: Compare UI display with export output for multiple holdings
**Status**: Not Started

## Stage 4: Verify Currency Formatting
**Goal**: Ensure display formatting isn't causing visual confusion
**Success Criteria**: Consistent formatting between UI and export
**Tests**: Check decimal places, rounding, and currency symbols
**Status**: Not Started