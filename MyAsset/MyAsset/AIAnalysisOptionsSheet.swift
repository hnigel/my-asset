import SwiftUI

/**
 * AI Analysis Options Sheet
 * 
 * This sheet allows users to configure AI analysis options including
 * analysis type, privacy settings, and other preferences.
 */
struct AIAnalysisOptionsSheet: View {
    let portfolio: Portfolio
    let analysisManager: GeminiAnalysisManager
    
    @Binding var selectedAnalysisType: GeminiAnalysisManager.AnalysisType
    @Binding var selectedPrivacySettings: PortfolioAnalysisFormatter.PrivacySettings
    @Binding var includeTextSummary: Bool
    
    let onAnalysisComplete: (GeminiAnalysisManager.AnalysisResult) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var isGeneratingAnalysis = false
    @State private var analysisProgress = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isGeminiConfigured = false
    @State private var isCheckingConfiguration = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isCheckingConfiguration {
                    configurationCheckView
                } else if !isGeminiConfigured {
                    configurationRequiredView
                } else {
                    analysisOptionsView
                }
            }
            .navigationTitle("AI Portfolio Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if isGeminiConfigured && !isGeneratingAnalysis {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Analyze") {
                            Task {
                                await generateAnalysis()
                            }
                        }
                        .disabled(isGeneratingAnalysis)
                    }
                }
            }
            .task {
                await checkGeminiConfiguration()
            }
            .alert("Analysis Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var configurationCheckView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
            
            Text("Checking Gemini AI configuration...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var configurationRequiredView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            VStack(spacing: 16) {
                Text("Gemini AI Not Configured")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("To use AI portfolio analysis, you need to configure your Google Gemini API key.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Text("Setup Instructions:")
                    .font(.headline)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Get a free API key from Google AI Studio")
                    Text("2. Go to app Settings")
                    Text("3. Add your Gemini API key")
                    Text("4. Return here to start analysis")
                }
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            
            Button(action: {
                // In a real app, this would open settings
                // For now, we'll just show an alert
                errorMessage = "Please configure your Gemini API key in the app settings."
                showingError = true
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Spacer()
        }
        .padding()
    }
    
    private var analysisOptionsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isGeneratingAnalysis {
                    analysisProgressView
                } else {
                    analysisTypeSection
                    privacySettingsSection
                    additionalOptionsSection
                }
            }
            .padding()
        }
    }
    
    private var analysisProgressView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                .scaleEffect(1.5)
            
            Text("Generating AI Analysis")
                .font(.headline)
            
            Text(analysisProgress.isEmpty ? "Preparing analysis..." : analysisProgress)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("This may take a few moments...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var analysisTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis Type")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(GeminiAnalysisManager.AnalysisType.allCases, id: \.self) { analysisType in
                    analysisTypeCard(analysisType)
                }
            }
        }
    }
    
    private func analysisTypeCard(_ analysisType: GeminiAnalysisManager.AnalysisType) -> some View {
        Button(action: {
            selectedAnalysisType = analysisType
        }) {
            VStack(spacing: 8) {
                Image(systemName: analysisType.icon)
                    .font(.title2)
                    .foregroundColor(selectedAnalysisType == analysisType ? .white : .blue)
                
                Text(analysisType.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(selectedAnalysisType == analysisType ? .white : .primary)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(selectedAnalysisType == analysisType ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var privacySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy Settings")
                .font(.headline)
            
            VStack(spacing: 12) {
                privacyOptionRow(
                    title: "Standard Privacy",
                    description: "Anonymize dollar amounts, keep company names",
                    isSelected: selectedPrivacySettings.anonymizeAmounts && !selectedPrivacySettings.anonymizeCompanyNames
                ) {
                    selectedPrivacySettings = .default
                }
                
                privacyOptionRow(
                    title: "Maximum Privacy",
                    description: "Anonymize all sensitive data including amounts and names",
                    isSelected: selectedPrivacySettings.anonymizeAmounts && selectedPrivacySettings.anonymizeCompanyNames
                ) {
                    selectedPrivacySettings = .maxPrivacy
                }
                
                privacyOptionRow(
                    title: "No Anonymization",
                    description: "Include exact amounts and names (less private)",
                    isSelected: !selectedPrivacySettings.anonymizeAmounts && !selectedPrivacySettings.anonymizeCompanyNames
                ) {
                    selectedPrivacySettings = PortfolioAnalysisFormatter.PrivacySettings(
                        anonymizeAmounts: false,
                        anonymizeCompanyNames: false,
                        anonymizeDates: false,
                        includePurchaseDates: true,
                        includeExactQuantities: true
                    )
                }
            }
        }
    }
    
    private func privacyOptionRow(
        title: String,
        description: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
    }
    
    private var additionalOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Options")
                .font(.headline)
            
            Toggle("Include Portfolio Summary", isOn: $includeTextSummary)
                .font(.body)
        }
    }
    
    // MARK: - Private Methods
    
    private func checkGeminiConfiguration() async {
        isCheckingConfiguration = true
        isGeminiConfigured = await analysisManager.isGeminiConfigured()
        isCheckingConfiguration = false
    }
    
    private func generateAnalysis() async {
        print("🚀 [AIAnalysisOptionsSheet] Starting AI analysis...")
        isGeneratingAnalysis = true
        
        let options = GeminiAnalysisManager.AnalysisOptions(
            analysisType: selectedAnalysisType,
            privacySettings: selectedPrivacySettings,
            includeTextSummary: includeTextSummary,
            customPrompt: nil
        )
        
        print("📋 [AIAnalysisOptionsSheet] Analysis options: \(selectedAnalysisType.rawValue)")
        
        do {
            print("🔄 [AIAnalysisOptionsSheet] Calling analysisManager.analyzePortfolio...")
            let result = try await analysisManager.analyzePortfolio(portfolio, options: options)
            
            print("✅ [AIAnalysisOptionsSheet] Analysis completed successfully!")
            print("📊 [AIAnalysisOptionsSheet] Result preview: \(String(result.aiAnalysis.prefix(100)))...")
            
            await MainActor.run {
                onAnalysisComplete(result)
                presentationMode.wrappedValue.dismiss()
            }
            
        } catch {
            print("❌ [AIAnalysisOptionsSheet] Analysis failed with error: \(error)")
            print("❌ [AIAnalysisOptionsSheet] Error details: \(error.localizedDescription)")
            
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isGeneratingAnalysis = false
            }
        }
    }
}

// MARK: - Preview

struct AIAnalysisOptionsSheet_Previews: PreviewProvider {
    static var previews: some View {
        let portfolio = Portfolio(context: DataManager.shared.context)
        portfolio.name = "Sample Portfolio"
        portfolio.portfolioID = UUID()
        portfolio.createdDate = Date()
        
        return AIAnalysisOptionsSheet(
            portfolio: portfolio,
            analysisManager: GeminiAnalysisManager(),
            selectedAnalysisType: .constant(.comprehensive),
            selectedPrivacySettings: .constant(.default),
            includeTextSummary: .constant(true),
            onAnalysisComplete: { _ in }
        )
    }
}