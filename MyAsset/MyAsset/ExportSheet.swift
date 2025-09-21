import SwiftUI
import UniformTypeIdentifiers

struct ExportSheet: View {
    let portfolio: Portfolio
    let exportManager: ExportManager
    
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
                        Text("Editable Preview")
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
                            Text("Generating preview...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        TextEditor(text: $editableText)
                            .font(.system(size: 14, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGroupedBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .padding(.horizontal)
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Export buttons section
                VStack(spacing: 12) {
                    Divider()
                    
                    // Text Export Button
                    Button(action: {
                        Task {
                            await exportPortfolio()
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Text Summary")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .background(isExporting || isLoadingPreview ? Color.gray : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(isExporting || isLoadingPreview)
                    .padding(.horizontal)
                    
                    // AI Analysis Button
                    Button(action: {
                        showingAIOptions = true
                    }) {
                        HStack {
                            Image(systemName: "brain")
                            Text("AI Portfolio Analysis")
                            if isGeneratingAIAnalysis {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .background(isGeneratingAIAnalysis || isExporting || isLoadingPreview ? Color.gray : Color.green)
                        .cornerRadius(10)
                    }
                    .disabled(isGeneratingAIAnalysis || isExporting || isLoadingPreview)
                    .padding(.horizontal)
                    
                    // Progress indicators
                    if isExporting {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                            Text("Preparing export...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if isGeneratingAIAnalysis {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                .scaleEffect(0.8)
                            Text(aiAnalysisProgress.isEmpty ? "Generating AI analysis..." : aiAnalysisProgress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Export Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await generatePreview()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Export Result", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingAIOptions) {
                AIAnalysisOptionsSheet(
                    portfolio: portfolio,
                    analysisManager: geminiAnalysisManager,
                    selectedAnalysisType: $selectedAnalysisType,
                    selectedPrivacySettings: $selectedPrivacySettings,
                    includeTextSummary: $includeTextSummary,
                    onAnalysisComplete: { result in
                        print("🎉 [ExportSheet] Analysis completed successfully!")
                        print("📊 [ExportSheet] Analysis type: \(result.analysisType.rawValue)")
                        print("📊 [ExportSheet] Combined report length: \(result.combinedReport.count) characters")
                        print("📊 [ExportSheet] AI analysis preview: \(String(result.aiAnalysis.prefix(100)))...")
                        
                        aiAnalysisResult = result
                        editableText = result.combinedReport
                        showingAIOptions = false
                        
                        print("✅ [ExportSheet] Analysis result set to editableText")
                    }
                )
            }
            .onReceive(geminiAnalysisManager.$isAnalyzing) { isAnalyzing in
                isGeneratingAIAnalysis = isAnalyzing
            }
            .onReceive(geminiAnalysisManager.$analysisProgress) { progress in
                aiAnalysisProgress = progress
            }
            .sheet(isPresented: $showingShareSheet) {
                if let exportURL = exportURL {
                    ShareSheet(activityItems: [exportURL])
                }
            }
        }
    }
    
    private func exportPortfolio() async {
        isExporting = true
        
        do {
            // Create a temporary text file with the edited content
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName: String
            
            if let analysisResult = aiAnalysisResult {
                fileName = "\(portfolio.name ?? "Portfolio")_AI_Analysis_\(analysisResult.analysisType.rawValue.replacingOccurrences(of: " ", with: "_")).txt"
            } else {
                fileName = "\(portfolio.name ?? "Portfolio")_Export.txt"
            }
            
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            try editableText.write(to: fileURL, atomically: true, encoding: .utf8)
            
            exportURL = fileURL
            showingShareSheet = true
        } catch {
            alertMessage = "Export failed: \(error.localizedDescription)"
            showingAlert = true
        }
        
        isExporting = false
    }
    
    private func generatePreview() async {
        isLoadingPreview = true
        editableText = await textExportManager.generatePortfolioTextSummary(portfolio)
        isLoadingPreview = false
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ExportSheet_Previews: PreviewProvider {
    static var previews: some View {
        let portfolio = Portfolio(context: DataManager.shared.context)
        portfolio.name = "Sample Portfolio"
        portfolio.portfolioID = UUID()
        portfolio.createdDate = Date()
        
        return ExportSheet(portfolio: portfolio, exportManager: ExportManager())
    }
}