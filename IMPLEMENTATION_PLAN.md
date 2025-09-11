# Implementation Plan: Eliminate Demo Data & Implement Manual Input

## Overview
Remove all hallucinated/demo data generation from the stock price service and implement proper N/A handling with manual input functionality for prices and dividends.

## Stage 1: Remove All Demo/Hallucinated Data Generation
**Goal**: Completely eliminate all demo data generation methods from StockPriceService
**Success Criteria**: 
- No more demo data generation methods in StockPriceService.swift
- APIs return nil/proper errors when they fail
- No fake/random numbers generated anywhere
**Tests**: 
- Verify fetchStockPrice throws proper errors when APIs fail
- Confirm no demo data appears in UI when APIs are unavailable
- Test fetchDistributionInfo returns proper nil values
**Status**: Complete

## Stage 2: Update Data Models for N/A Handling  
**Goal**: Modify Core Data models to handle missing data gracefully
**Success Criteria**:
- Add optional user-provided price/dividend fields to Stock entity
- Add flags to distinguish API vs user-provided data
- Ensure all price calculations handle nil values properly
**Tests**:
- Test Core Data schema migration
- Verify calculations work with missing data
- Confirm N/A values display correctly
**Status**: Complete

## Stage 3: Implement Manual Input UI
**Goal**: Add UI components for manual data entry
**Success Criteria**:
- "Add manually" buttons when data is N/A
- Edit sheets for price and dividend input
- Clear indication of data source (API vs manual)
- User data persists in Core Data
**Tests**:
- Test manual price input functionality
- Test manual dividend input functionality  
- Verify data source indicators work correctly
- Test data persistence across app sessions
**Status**: Complete

## Stage 4: Update Stock Price Service N/A Handling
**Goal**: Implement proper error handling and N/A returns
**Success Criteria**:
- Return nil or throw errors instead of demo data
- Clear error messages for users
- Proper fallback to user-provided data when available
**Tests**:
- Test all API failure scenarios
- Verify proper error propagation to UI
- Test fallback to manual data works correctly
**Status**: Complete

## Stage 5: Integration Testing & UI Updates
**Goal**: Ensure all components work together properly
**Success Criteria**:
- All existing functionality preserved
- N/A states display correctly throughout app
- Manual input integrates seamlessly
- No demo data appears anywhere
**Tests**:
- End-to-end testing of stock addition with API failures
- Test portfolio calculations with mixed API/manual data
- Verify export functionality works with new data model
- Test background updates respect manual overrides
**Status**: Not Started