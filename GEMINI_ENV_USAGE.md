# Gemini API Environment Variable Integration

## Overview
The AI Portfolio Analysis feature now uses the `GEMINI_API_KEY` environment variable directly instead of requiring keychain configuration through the APIKeyManager.

## Setup Instructions

### 1. Get Your Gemini API Key
- Visit [Google AI Studio](https://aistudio.google.com/app/apikey)
- Create a new API key or use an existing one
- Copy the API key (it should look like: `AIzaSy...`)

### 2. Configure API Key (Multiple Options)

#### Option A: .env File (推薦 - Recommended)
創建或編輯 `/Users/hnigel/coding/my asset/.env` 檔案：
```
GEMINI_API_KEY=your_actual_api_key_here
```

#### Option B: Environment Variable
```bash
export GEMINI_API_KEY="your_actual_api_key_here"
```

#### For Xcode Development:
1. Open your Xcode project
2. Go to Product → Scheme → Edit Scheme
3. Select "Run" from the left sidebar
4. Go to the "Arguments" tab
5. Under "Environment Variables", add:
   - Name: `GEMINI_API_KEY`
   - Value: `your_actual_api_key_here`

#### For Production Deployment:
Set the environment variable in your deployment environment according to your platform's documentation.

### 3. Verify Setup
You can test if the environment variable is properly set by running:
```bash
echo $GEMINI_API_KEY
```

## Usage in the App

### Direct AI Analysis
When you click the "AI Portfolio Analysis" button:
1. The app will automatically check for the `GEMINI_API_KEY` environment variable
2. If found, it will proceed with the analysis
3. If not found, you'll see an error message about missing API key configuration

### No Additional Configuration Needed
- No need to enter API keys in app settings
- No keychain storage required
- Direct environment variable access for immediate use

## Code Changes Made

### Modified Files:
- `GeminiService.swift`: Updated to read API key from .env file or environment variables
  - Added `getAPIKeyFromEnvironment()` method with .env file support
  - Added `readAPIKeyFromEnvFile()` method for parsing .env files
  - Added direct `validateAPIKey()` method
  - Removed dependency on `APIKeyManager.shared`
  - Priority: .env file first, then environment variables as fallback

### Key Methods Updated:
- `analyzePortfolio()`: Now uses environment variable
- `generateContent()`: Now uses environment variable  
- `validateConfiguration()`: Now validates environment variable directly
- `testConnection()`: Works with environment variable

## Benefits

1. **Immediate Usage**: Set environment variable and use immediately
2. **Security**: No API keys stored in code or keychain
3. **Flexibility**: Easy to change API keys without app rebuild
4. **CI/CD Friendly**: Works well with deployment pipelines
5. **Development Friendly**: Easy setup for multiple developers

## Troubleshooting

### "Gemini API key not configured" Error
- Verify the environment variable is set: `echo $GEMINI_API_KEY`
- Ensure the variable name is exactly `GEMINI_API_KEY`
- Restart your app/Xcode after setting the environment variable

### API Key Validation Fails
- Check that your API key is valid at [Google AI Studio](https://aistudio.google.com/)
- Ensure the API key has the necessary permissions
- Verify your internet connection

### Environment Variable Not Found in Xcode
- Check Xcode scheme environment variables (Product → Scheme → Edit Scheme)
- Ensure you're running the correct scheme
- Try setting the variable in your shell before launching Xcode

## Example Usage

```swift
// The GeminiService will automatically use the environment variable
let geminiService = GeminiService()

// Check if properly configured
let isConfigured = await geminiService.validateConfiguration()

if isConfigured {
    // Proceed with analysis
    let result = try await geminiService.generateContent(prompt: "Analyze this portfolio...")
} else {
    // Handle missing API key
    print("Please set GEMINI_API_KEY environment variable")
}
```

## Security Notes

- Never commit API keys to version control
- Use environment variables or secure secret management
- Rotate API keys regularly
- Monitor API usage and billing

---

**Ready to use!** 🚀 Simply set your `GEMINI_API_KEY` environment variable and start using AI portfolio analysis.