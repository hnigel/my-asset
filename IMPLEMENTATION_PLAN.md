# Text Export Functionality Implementation Plan

## Overview
Implement comprehensive text export functionality for portfolio summaries that integrates with the existing export system.

## Stage 1: TextExportManager Creation
**Goal**: Create a service class to generate formatted text summaries
**Success Criteria**: TextExportManager can generate clean, readable portfolio summaries
**Tests**: Text format includes all required sections with proper formatting
**Status**: Complete

### Tasks:
- Create TextExportManager.swift with async/await support
- Implement portfolio overview generation (value, dividends, performance)
- Implement individual holdings formatting with stock details
- Add proper currency formatting (no decimals as specified)
- Include dividend information using DividendCalculationService
- Use emojis and clean sectioning for readability

## Stage 2: ShareSheet Component Enhancement
**Goal**: Ensure ShareSheet works for text content sharing
**Success Criteria**: ShareSheet supports all iOS sharing options for text
**Tests**: Can share to Messages, Mail, Copy, Files, etc.
**Status**: Complete - Existing ShareSheet supports file URLs which work for text exports

### Tasks:
- Verify existing ShareSheet supports text content
- Enhance if needed for better text handling
- Ensure proper activity types are enabled

## Stage 3: ExportSheet Integration
**Goal**: Add text export option to existing export interface
**Success Criteria**: Users can select and export text summaries seamlessly
**Tests**: Text export works alongside existing CSV/JSON exports
**Status**: Complete

### Tasks:
- Add "Text Summary" to ExportFormat enum
- Update ExportSheet UI to include text export option
- Integrate TextExportManager for text generation
- Add loading states and error handling
- Ensure proper async/await usage

## Stage 4: Testing and Polish
**Goal**: Ensure robust functionality and user experience
**Success Criteria**: All export formats work reliably with proper error handling
**Tests**: Comprehensive testing of all export paths
**Status**: Ready for Testing

### Tasks:
- Test text export with various portfolio sizes
- Verify proper formatting and currency display
- Test sharing to different platforms
- Ensure proper error handling and loading states
- Performance testing for large portfolios

## Implementation Notes
- Use existing patterns from ExportManager for consistency
- Leverage DividendCalculationService for dividend data
- Follow existing async/await patterns in the codebase
- Maintain consistency with existing UI/UX patterns
- Use proper Core Data threading with @MainActor where needed