import SwiftUI
import UniformTypeIdentifiers

/**
 * Modified Export Sheet
 * 
 * This is a modified version of ExportSheet that supports custom analysis completion callbacks.
 * It maintains all the original functionality while allowing external components to handle
 * analysis results (e.g., saving to Core Data).
 */
struct ModifiedExportSheet: View {
    let portfolio: Portfolio
    let onAnalysisComplete: (GeminiAnalysisManager.AnalysisResult) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isExporting = false
    @State private var editableText = ""
    @State private var isLoadingPreview = true
    @StateObject private var textExportManager = TextExportManager()
    @StateObject private var geminiAnalysisManager = GeminiAnalysisManager()
    
    // AI Analysis states
    @State private var showingAIOptions = false
    @State private var selectedAnalysisType: GeminiAnalysisManager.AnalysisType = .comprehensive
    @State private var selectedPrivacySettings: PortfolioAnalysisFormatter.PrivacySettings = .default
    @State private var includeTextSummary = true
    @State private var aiAnalysisResult: GeminiAnalysisManager.AnalysisResult?
    @State private var isGeneratingAIAnalysis = false
    @State private var aiAnalysisProgress = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Editable text area with scrolling
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Portfolio Export Preview")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        if isLoadingPreview {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    if isLoadingPreview {
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            Text("Generating portfolio summary...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else {
                        ScrollView {
                            TextEditor(text: $editableText)
                                .font(.system(.body, design: .default))
                                .padding(.horizontal)
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // AI Analysis Button
                if !isLoadingPreview {
                    VStack(spacing: 8) {
                        if isGeneratingAIAnalysis {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                    .scaleEffect(0.8)
                                
                                VStack(alignment: .leading) {
                                    Text("Generating AI Analysis...")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    if !aiAnalysisProgress.isEmpty {
                                        Text(aiAnalysisProgress)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                        } else {
                            Button(action: {
                                print("🧠 [ModifiedExportSheet] AI Portfolio Analysis button tapped")
                                showingAIOptions = true
                            }) {
                                HStack {
                                    Image(systemName: "brain")
                                        .foregroundColor(.white)
                                    Text("AI Portfolio Analysis")
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Export buttons
                if !isLoadingPreview {
                    HStack(spacing: 12) {
                        // 其他匯出按鈕可以在這裡添加
                        Button(action: {
                            // 簡單的文字匯出功能
                            exportAsText()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Text")
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
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Export Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAIOptions) {
            AIAnalysisOptionsSheet(
                portfolio: portfolio,
                analysisManager: geminiAnalysisManager,
                selectedAnalysisType: $selectedAnalysisType,
                selectedPrivacySettings: $selectedPrivacySettings,
                includeTextSummary: $includeTextSummary,
                onAnalysisComplete: { result in
                    print("🎉 [ModifiedExportSheet] Analysis completed successfully!")
                    print("📊 [ModifiedExportSheet] Analysis type: \(result.analysisType.rawValue)")
                    print("📊 [ModifiedExportSheet] Combined report length: \(result.combinedReport.count) characters")
                    print("📊 [ModifiedExportSheet] AI analysis preview: \(String(result.aiAnalysis.prefix(100)))...")
                    
                    // 設定本地狀態（保持原有功能）
                    aiAnalysisResult = result
                    editableText = result.combinedReport
                    showingAIOptions = false
                    
                    // 呼叫外部回調（新功能）
                    onAnalysisComplete(result)
                    
                    print("✅ [ModifiedExportSheet] Analysis result processed and callback executed")
                }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Export Status", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onReceive(geminiAnalysisManager.$isAnalyzing) { isAnalyzing in
            isGeneratingAIAnalysis = isAnalyzing
        }
        .onReceive(geminiAnalysisManager.$analysisProgress) { progress in
            aiAnalysisProgress = progress
        }
        .task {
            await loadPreview()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadPreview() async {
        print("📄 [ModifiedExportSheet] Loading portfolio preview...")
        isLoadingPreview = true
        
        let summary = await textExportManager.generatePortfolioTextSummary(portfolio)
        
        await MainActor.run {
            editableText = summary
            isLoadingPreview = false
            print("✅ [ModifiedExportSheet] Portfolio preview loaded")
        }
    }
    
    private func exportAsText() {
        print("📤 [ModifiedExportSheet] Exporting as text...")
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("portfolio_export.txt")
        
        do {
            try editableText.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showingShareSheet = true
            print("✅ [ModifiedExportSheet] Text export successful")
        } catch {
            print("❌ [ModifiedExportSheet] Text export failed: \(error)")
            alertMessage = "Failed to export text: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}


// MARK: - Preview

struct ModifiedExportSheet_Previews: PreviewProvider {
    static var previews: some View {
        let portfolio = Portfolio(context: DataManager.shared.context)
        portfolio.name = "Sample Portfolio"
        portfolio.portfolioID = UUID()
        portfolio.createdDate = Date()
        
        return ModifiedExportSheet(
            portfolio: portfolio,
            onAnalysisComplete: { result in
                print("Preview: Analysis completed with type \(result.analysisType.rawValue)")
            }
        )
    }
}