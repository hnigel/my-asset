import SwiftUI
import CoreData

/**
 * AI Portfolio Analysis View (A1 Page)
 * 
 * This is the main AI analysis page that either shows existing analysis results
 * or guides users to start a new analysis. It integrates with the existing
 * ExportSheet flow while providing a dedicated AI analysis experience.
 */
struct AIPortfolioAnalysisView: View {
    let portfolio: Portfolio
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var viewContext
    
    // State management
    @State private var latestAnalysis: AIAnalysisRecord?
    @State private var showingExportFlow = false
    @State private var isLoadingAnalysis = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoadingAnalysis {
                    loadingView
                } else if let analysis = latestAnalysis {
                    existingAnalysisView(analysis)
                } else {
                    noAnalysisView
                }
            }
            .navigationTitle("AI Portfolio Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if latestAnalysis != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("New Analysis") {
                            showingExportFlow = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportFlow) {
            ModifiedExportSheet(
                portfolio: portfolio,
                onAnalysisComplete: { (result: GeminiAnalysisManager.AnalysisResult) in
                    print("🎉 [AIPortfolioAnalysisView] Analysis completed, saving to Core Data...")
                    saveAnalysisToCoreData(result)
                    showingExportFlow = false
                }
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadLatestAnalysis()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
            
            Text("Loading analysis history...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Analysis View
    
    private var noAnalysisView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("AI Portfolio Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Get AI-powered insights about your portfolio performance, risk analysis, and investment recommendations.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                print("🚀 [AIPortfolioAnalysisView] Starting new AI analysis...")
                showingExportFlow = true
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Start AI Analysis")
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Existing Analysis View
    
    private func existingAnalysisView(_ analysis: AIAnalysisRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 分析資訊卡片
                analysisInfoCard(analysis)
                
                // 分析內容
                analysisContentView(analysis)
                
                // 操作按鈕
                actionButtonsView(analysis)
            }
            .padding()
        }
    }
    
    private func analysisInfoCard(_ analysis: AIAnalysisRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: analysis.analysisTypeEnum.icon)
                    .foregroundColor(.blue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(analysis.displayTitle)
                        .font(.headline)
                    
                    Text("Generated \(analysis.formattedDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if analysis.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
            
            HStack {
                Text("\(analysis.wordCount) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(analysis.analysisTypeEnum.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func analysisContentView(_ analysis: AIAnalysisRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Results")
                .font(.headline)
            
            Text(analysis.aiAnalysisText)
                .font(.body)
                .textSelection(.enabled) // iOS 15+ 允許文字選擇
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private func actionButtonsView(_ analysis: AIAnalysisRecord) -> some View {
        VStack(spacing: 12) {
            // 主要操作按鈕
            HStack(spacing: 12) {
                Button(action: {
                    showingExportFlow = true
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("New Analysis")
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    shareAnalysis(analysis)
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                }
            }
            
            // 次要操作按鈕
            HStack(spacing: 12) {
                Button(action: {
                    toggleFavorite(analysis)
                }) {
                    HStack {
                        Image(systemName: analysis.isFavorite ? "heart.fill" : "heart")
                        Text(analysis.isFavorite ? "Unfavorite" : "Favorite")
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    copyToClipboard(analysis)
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Core Data Operations
    
    private func loadLatestAnalysis() {
        print("📊 [AIPortfolioAnalysisView] Loading latest analysis for portfolio: \(portfolio.name ?? "Unknown")")
        isLoadingAnalysis = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            latestAnalysis = AIAnalysisRecord.fetchLatest(for: portfolio, in: viewContext)
            
            if let analysis = latestAnalysis {
                print("✅ [AIPortfolioAnalysisView] Found existing analysis: \(analysis.displayTitle)")
                analysis.updateLastViewedDate()
                saveContext()
            } else {
                print("ℹ️ [AIPortfolioAnalysisView] No existing analysis found")
            }
            
            isLoadingAnalysis = false
        }
    }
    
    private func saveAnalysisToCoreData(_ result: GeminiAnalysisManager.AnalysisResult) {
        print("💾 [AIPortfolioAnalysisView] Saving analysis to Core Data...")
        
        let newRecord = AIAnalysisRecord.create(from: result, for: portfolio, in: viewContext)
        
        do {
            try viewContext.save()
            print("✅ [AIPortfolioAnalysisView] Analysis saved successfully")
            
            // 重新載入最新分析
            loadLatestAnalysis()
            
        } catch {
            print("❌ [AIPortfolioAnalysisView] Failed to save analysis: \(error)")
            errorMessage = "Failed to save analysis: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("❌ [AIPortfolioAnalysisView] Failed to save context: \(error)")
        }
    }
    
    // MARK: - Action Methods
    
    private func shareAnalysis(_ analysis: AIAnalysisRecord) {
        print("📤 [AIPortfolioAnalysisView] Sharing analysis...")
        // TODO: 實作分享功能
        let activityVC = UIActivityViewController(
            activityItems: [analysis.combinedReport],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func toggleFavorite(_ analysis: AIAnalysisRecord) {
        print("❤️ [AIPortfolioAnalysisView] Toggling favorite status...")
        analysis.isFavorite.toggle()
        saveContext()
    }
    
    private func copyToClipboard(_ analysis: AIAnalysisRecord) {
        print("📋 [AIPortfolioAnalysisView] Copying to clipboard...")
        UIPasteboard.general.string = analysis.combinedReport
        
        // TODO: 顯示成功提示
        print("✅ Analysis copied to clipboard")
    }
}

// MARK: - Preview

struct AIPortfolioAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        let portfolio = Portfolio(context: DataManager.shared.context)
        portfolio.name = "Sample Portfolio"
        portfolio.portfolioID = UUID()
        portfolio.createdDate = Date()
        
        return AIPortfolioAnalysisView(portfolio: portfolio)
            .environment(\.managedObjectContext, DataManager.shared.context)
    }
}