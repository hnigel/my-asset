// This is a clean version of the body with modifiers applied to mainScrollView
// to avoid compiler complexity issues

    private var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Portfolio Summary Card
                PortfolioSummaryCard(portfolio: portfolio, portfolioManager: portfolioManager, holdings: holdings, dividendService: dividendService)
                    .id(portfolioSummaryId)
                
                // Holdings List
                HoldingsListView(
                    holdings: holdings,
                    portfolioManager: portfolioManager,
                    onHoldingDeleted: loadHoldings,
                    onDeleteRequested: { holding in
                        holdingToDelete = holding
                        showingDeleteConfirmation = true
                    },
                    onEditRequested: { holding in
                        // Validate holding before opening edit sheet with thread-safe check
                        let symbol = holding.stock?.symbol ?? "Unknown"
                        print("🎯 [HOLDING EDIT REQUEST] User tapped holding: \(symbol)")
                        print("🎯 [HOLDING EDIT REQUEST] Holding ObjectID: \(holding.objectID)")
                        
                        print("🔄 [HOLDING EDIT REQUEST] Starting validation for \(symbol)...")
                        
                        // First set the holding to edit immediately
                        print("📝 [HOLDING EDIT REQUEST] Setting holdingToEdit to: \(holding.objectID)")
                        holdingToEdit = holding
                        print("📝 [HOLDING EDIT REQUEST] holdingToEdit set to: \(holdingToEdit?.objectID.description ?? "nil")")
                        
                        Task { @MainActor in
                            if await isHoldingValidForEditing(holding) {
                                print("✅ [HOLDING EDIT REQUEST] Validation successful, opening edit sheet for \(symbol)")
                                print("📝 [HOLDING EDIT REQUEST] Setting showingEditHolding to true")
                                showingEditHolding = true
                                print("📝 [HOLDING EDIT REQUEST] showingEditHolding set to: \(showingEditHolding)")
                                print("📝 [HOLDING EDIT REQUEST] Final holdingToEdit: \(holdingToEdit?.objectID.description ?? "nil")")
                                
                                // Force a small delay to ensure state propagation
                                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                                print("📝 [HOLDING EDIT REQUEST] After delay - showingEditHolding: \(showingEditHolding), holdingToEdit: \(holdingToEdit?.objectID.description ?? "nil")")
                            } else {
                                print("❌ [HOLDING EDIT REQUEST] Validation failed for \(symbol)")
                                print("🔄 [HOLDING EDIT REQUEST] Clearing holdingToEdit and refreshing holdings...")
                                
                                // Clear the holding and refresh
                                holdingToEdit = nil
                                loadHoldings()
                                print("⚠️ [HOLDING EDIT REQUEST] Edit sheet will not be shown due to validation failure")
                            }
                        }
                    }
                )
                
                // Performance Chart - Coming Soon
                // if !holdings.isEmpty {
                //     PortfolioChartView(portfolio: portfolio)
                // }
                
            }
            .padding()
        }
        .modifier(PortfolioSheetsModifier(
            showingAddHolding: $showingAddHolding,
            showingExportSheet: $showingExportSheet,
            showingAIAnalysis: $showingAIAnalysis,
            editHoldingBinding: editHoldingBinding,
            showingDeleteConfirmation: $showingDeleteConfirmation,
            holdingToEdit: $holdingToEdit,
            holdingToDelete: $holdingToDelete,
            portfolio: portfolio,
            exportManager: exportManager,
            portfolioManager: portfolioManager,
            onHoldingAdded: loadHoldings,
            onHoldingDeleted: loadHoldings,
            refreshDividendData: refreshDividendData
        ))
        .modifier(PortfolioLifecycleModifier(
            onAppear: {
                loadHoldings()
                setupChangeNotifications()
            },
            onDisappear: {
                changeNotificationCancellable?.cancel()
            }
        ))
    }

    var body: some View {
        mainScrollView
            .navigationTitle(portfolio.name ?? "Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navigationToolbar }
    }