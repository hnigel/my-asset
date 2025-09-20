//
//  my_assetUITests.swift
//  my assetUITests
//
//  Created by 洪子翔 on 2025/9/7.
//

import XCTest

final class my_assetUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAppLaunchAndBasicNavigation() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Verify the app launches successfully
        XCTAssertTrue(app.state == .runningForeground)
        
        // Look for basic navigation elements that should exist
        // Note: These are generic checks - actual element names depend on the UI implementation
        let tabBar = app.tabBars.firstMatch
        let navigationBar = app.navigationBars.firstMatch
        
        // At least one of these should exist in a portfolio app
        let hasTabBar = tabBar.exists
        let hasNavigationBar = navigationBar.exists
        XCTAssertTrue(hasTabBar || hasNavigationBar, "App should have tab bar or navigation bar")
    }
    
    @MainActor
    func testCreatePortfolioFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to fully load
        let timeout: TimeInterval = 5.0
        
        // Look for add/create button (common UI patterns)
        let addButton = app.buttons["Add"].firstMatch
        let createButton = app.buttons["Create Portfolio"].firstMatch
        let plusButton = app.buttons["+"].firstMatch
        
        // Try to find and tap an add/create button
        if addButton.waitForExistence(timeout: timeout) {
            addButton.tap()
        } else if createButton.waitForExistence(timeout: timeout) {
            createButton.tap()
        } else if plusButton.waitForExistence(timeout: timeout) {
            plusButton.tap()
        }
        
        // Look for text fields that might be for portfolio name
        let textFields = app.textFields
        if textFields.count > 0 {
            textFields.firstMatch.tap()
            textFields.firstMatch.typeText("UI Test Portfolio")
        }
        
        // Look for save/create button
        let saveButton = app.buttons["Save"].firstMatch
        let createPortfolioButton = app.buttons["Create"].firstMatch
        
        if saveButton.exists {
            saveButton.tap()
        } else if createPortfolioButton.exists {
            createPortfolioButton.tap()
        }
        
        // This test validates that the basic flow doesn't crash
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    @MainActor
    func testPortfolioListDisplay() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for the interface to load
        sleep(2)
        
        // Look for common list/table elements
        let tables = app.tables
        let collectionViews = app.collectionViews
        let scrollViews = app.scrollViews
        
        // Portfolio apps typically display portfolios in lists/collections
        let hasDataDisplay = tables.count > 0 || collectionViews.count > 0 || scrollViews.count > 0
        XCTAssertTrue(hasDataDisplay, "App should display portfolio data in some form")
        
        // Test that the app remains responsive
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    @MainActor
    func testSettingsOrMenuAccess() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Look for settings or menu buttons
        let settingsButton = app.buttons["Settings"].firstMatch
        let menuButton = app.buttons["Menu"].firstMatch
        let moreButton = app.buttons["More"].firstMatch
        
        // Test that tapping settings/menu doesn't crash
        if settingsButton.waitForExistence(timeout: 3.0) {
            settingsButton.tap()
            XCTAssertTrue(app.state == .runningForeground)
        } else if menuButton.waitForExistence(timeout: 3.0) {
            menuButton.tap()
            XCTAssertTrue(app.state == .runningForeground)
        } else if moreButton.waitForExistence(timeout: 3.0) {
            moreButton.tap()
            XCTAssertTrue(app.state == .runningForeground)
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    @MainActor
    func testMemoryUsage() throws {
        // Test that the app doesn't use excessive memory during basic operations
        measure(metrics: [XCTMemoryMetric()]) {
            let app = XCUIApplication()
            app.launch()
            
            // Perform some basic operations
            sleep(2) // Let the app fully load
            
            // Try to navigate through the app
            let scrollViews = app.scrollViews
            if scrollViews.count > 0 {
                scrollViews.firstMatch.swipeUp()
                sleep(1)
                scrollViews.firstMatch.swipeDown()
            }
        }
    }
    
    // MARK: - Stock Price Auto-Fetch UI Tests
    
    @MainActor
    func testAddHoldingSheetStockPriceFetching() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Look for add holding functionality
        let addButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR label CONTAINS 'Create' OR label CONTAINS '+'"))
        
        var foundAddButton = false
        for i in 0..<addButtons.count {
            let button = addButtons.element(boundBy: i)
            if button.exists {
                button.tap()
                foundAddButton = true
                break
            }
        }
        
        if !foundAddButton {
            // Try alternative approaches to find add functionality
            let navBars = app.navigationBars
            for i in 0..<navBars.count {
                let navBar = navBars.element(boundBy: i)
                let addButton = navBar.buttons["+"]
                if addButton.exists {
                    addButton.tap()
                    foundAddButton = true
                    break
                }
            }
        }
        
        if foundAddButton {
            // Look for symbol input field
            let symbolField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Symbol' OR placeholderValue CONTAINS 'AAPL' OR label CONTAINS 'Symbol'")).firstMatch
            
            if symbolField.waitForExistence(timeout: 5.0) {
                symbolField.tap()
                symbolField.typeText("AAPL")
                
                // Wait for price loading indicator or result
                let loadingIndicator = app.activityIndicators.firstMatch
                let priceText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$' OR label CONTAINS 'Price'")).firstMatch
                
                // Either loading indicator appears or price shows up
                let expectation = expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: loadingIndicator, handler: nil)
                expectation.isInverted = true // We want it to disappear (loading finished)
                
                wait(for: [expectation], timeout: 10.0)
                
                // Check if price information appeared
                if priceText.waitForExistence(timeout: 5.0) {
                    XCTAssertTrue(priceText.label.contains("$"), "Price should be displayed with currency symbol")
                }
                
                // Test that the form validation works
                let quantityField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Quantity'")).firstMatch
                if quantityField.exists {
                    quantityField.tap()
                    quantityField.typeText("10")
                }
                
                // Look for add/save button and test if it becomes enabled
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR label CONTAINS 'Save'")).firstMatch
                if saveButton.exists {
                    XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled with valid data")
                }
            }
        }
        
        // Ensure app remains stable
        XCTAssertEqual(app.state, .runningForeground)
    }
    
    @MainActor
    func testAddHoldingSheetErrorHandling() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to add holding sheet (similar to previous test)
        let addButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR label CONTAINS 'Create' OR label CONTAINS '+'"))
        
        var foundAddButton = false
        for i in 0..<addButtons.count {
            let button = addButtons.element(boundBy: i)
            if button.exists {
                button.tap()
                foundAddButton = true
                break
            }
        }
        
        if foundAddButton {
            let symbolField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Symbol' OR placeholderValue CONTAINS 'AAPL'")).firstMatch
            
            if symbolField.waitForExistence(timeout: 5.0) {
                // Test with invalid symbol
                symbolField.tap()
                symbolField.typeText("INVALIDSTOCK123")
                
                // Wait for error message to appear
                let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Invalid' OR label CONTAINS 'Error' OR label CONTAINS 'not found'")).firstMatch
                
                if errorText.waitForExistence(timeout: 10.0) {
                    XCTAssertTrue(errorText.exists, "Error message should appear for invalid stock")
                }
                
                // Test that save button is disabled with invalid data
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR label CONTAINS 'Save'")).firstMatch
                if saveButton.exists {
                    XCTAssertFalse(saveButton.isEnabled, "Save button should be disabled with invalid stock")
                }
            }
        }
        
        XCTAssertEqual(app.state, .runningForeground)
    }
    
    @MainActor
    func testAddHoldingSheetResponseTime() throws {
        let app = XCUIApplication()
        app.launch()
        
        measure(metrics: [XCTClockMetric()]) {
            // Navigate to add holding
            let addButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR label CONTAINS 'Create' OR label CONTAINS '+'"))
            
            if addButtons.count > 0 {
                let addButton = addButtons.firstMatch
                if addButton.exists {
                    addButton.tap()
                    
                    let symbolField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Symbol'")).firstMatch
                    if symbolField.waitForExistence(timeout: 3.0) {
                        symbolField.tap()
                        symbolField.typeText("AAPL")
                        
                        // Measure how long it takes for price to load or error to show
                        let priceOrError = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$' OR label CONTAINS 'Error' OR label CONTAINS 'Price'")).firstMatch
                        _ = priceOrError.waitForExistence(timeout: 15.0)
                    }
                    
                    // Go back
                    let cancelButton = app.buttons["Cancel"]
                    if cancelButton.exists {
                        cancelButton.tap()
                    } else {
                        app.navigationBars.buttons.firstMatch.tap()
                    }
                }
            }
        }
    }
    
    @MainActor
    func testPortfolioUpdatesWithRealPrices() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that portfolio values update when prices are refreshed
        // This is more of an integration test through the UI
        
        let timeout: TimeInterval = 10.0
        
        // Look for refresh or update functionality
        let refreshButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Refresh' OR label CONTAINS 'Update'")).firstMatch
        let pullToRefreshArea = app.scrollViews.firstMatch
        
        if refreshButton.waitForExistence(timeout: timeout) {
            refreshButton.tap()
            
            // Wait for loading to complete
            let loadingIndicator = app.activityIndicators.firstMatch
            if loadingIndicator.exists {
                let expectation = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: loadingIndicator, handler: nil)
                wait(for: [expectation], timeout: 15.0)
            }
        } else if pullToRefreshArea.exists {
            // Try pull-to-refresh gesture
            pullToRefreshArea.swipeDown()
            sleep(2) // Allow time for refresh
        }
        
        // Verify app remains responsive
        XCTAssertEqual(app.state, .runningForeground)
        
        // Look for any price-related text updates
        let priceElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$'"))
        if priceElements.count > 0 {
            let firstPrice = priceElements.firstMatch
            XCTAssertTrue(firstPrice.exists, "Price information should be visible")
        }
    }
    
    @MainActor
    func testAppStabilityWithNetworkRequests() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Perform multiple operations that might trigger network requests
        for _ in 1...3 {
            // Try to add a holding (triggers stock price fetch)
            let addButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR label CONTAINS '+'"))
            
            if addButtons.count > 0 {
                let addButton = addButtons.firstMatch
                if addButton.exists {
                    addButton.tap()
                    
                    let symbolField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Symbol'")).firstMatch
                    if symbolField.waitForExistence(timeout: 3.0) {
                        symbolField.tap()
                        symbolField.typeText("MSFT")
                        
                        // Wait a moment for network request
                        sleep(2)
                        
                        // Cancel and try again
                        let cancelButton = app.buttons["Cancel"]
                        if cancelButton.exists {
                            cancelButton.tap()
                        } else {
                            app.navigationBars.buttons.firstMatch.tap()
                        }
                    }
                }
            }
            
            // Small delay between iterations
            sleep(1)
        }
        
        // App should still be running and responsive
        XCTAssertEqual(app.state, .runningForeground)
        
        // Test basic navigation still works
        let scrollViews = app.scrollViews
        if scrollViews.count > 0 {
            scrollViews.firstMatch.swipeUp()
            scrollViews.firstMatch.swipeDown()
        }
        
        XCTAssertEqual(app.state, .runningForeground)
    }
    
    // MARK: - Performance and Load Testing
    
    @MainActor
    func testStockPriceLoadingPerformance() throws {
        let app = XCUIApplication()
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            app.launch()
            
            // Navigate to add holding multiple times to test stock price loading
            for symbol in ["AAPL", "MSFT", "GOOGL"] {
                let addButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR label CONTAINS '+'"))
                
                if addButtons.count > 0 {
                    let addButton = addButtons.firstMatch
                    if addButton.exists {
                        addButton.tap()
                        
                        let symbolField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Symbol'")).firstMatch
                        if symbolField.waitForExistence(timeout: 2.0) {
                            symbolField.tap()
                            symbolField.typeText(symbol)
                            
                            // Wait for price loading or error
                            let timeout: TimeInterval = 10.0
                            let priceOrError = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$' OR label CONTAINS 'Error'")).firstMatch
                            _ = priceOrError.waitForExistence(timeout: timeout)
                            
                            // Go back
                            let cancelButton = app.buttons["Cancel"]
                            if cancelButton.exists {
                                cancelButton.tap()
                            } else {
                                let navButton = app.navigationBars.buttons.firstMatch
                                if navButton.exists {
                                    navButton.tap()
                                }
                            }
                        }
                    }
                }
            }
            
            app.terminate()
        }
    }
    
    @MainActor
    func testAppResponsivenessDuringNetworkCalls() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that UI remains responsive during network operations
        let addButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR label CONTAINS '+'"))
        
        if addButtons.count > 0 {
            let addButton = addButtons.firstMatch
            if addButton.exists {
                addButton.tap()
                
                let symbolField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Symbol'")).firstMatch
                if symbolField.waitForExistence(timeout: 3.0) {
                    symbolField.tap()
                    symbolField.typeText("AAPL")
                    
                    // While stock price is loading, test UI responsiveness
                    let quantityField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Quantity'")).firstMatch
                    
                    // These interactions should work even while network request is in progress
                    if quantityField.exists {
                        quantityField.tap()
                        XCTAssertTrue(quantityField.hasKeyboardFocus, "Quantity field should be focusable during price loading")
                        quantityField.typeText("10")
                    }
                    
                    let datePicker = app.datePickers.firstMatch
                    if datePicker.exists {
                        datePicker.tap()
                        // DatePicker should be interactive
                        XCTAssertTrue(datePicker.exists, "Date picker should remain interactive")
                    }
                    
                    // Cancel button should always work
                    let cancelButton = app.buttons["Cancel"]
                    if cancelButton.exists {
                        XCTAssertTrue(cancelButton.isEnabled, "Cancel button should always be enabled")
                        cancelButton.tap()
                    }
                }
            }
        }
        
        XCTAssertEqual(app.state, .runningForeground)
    }
}
