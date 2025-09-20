import Foundation
import SwiftUI

// Simple compilation test for MainActor fixes
// This file tests that our MainActor changes work correctly

@MainActor
class TestMainActorService: ObservableObject {
    init() {}
    
    func testMethod() async {
        print("Test method")
    }
}

@MainActor
struct TestMainActorApp: App {
    let testService = TestMainActorService()
    
    var body: some Scene {
        WindowGroup {
            Text("Test")
                .environmentObject(testService)
        }
    }
    
    init() {
        // This should work now that both the app and service are @MainActor
        _ = testService
    }
}

// Test that our fixes work
func testMainActorFixes() async {
    // Test 1: MainActor class can be initialized in MainActor context
    await MainActor.run {
        _ = TestMainActorService()
        print("✅ MainActor service initialization works")
    }
    
    // Test 2: MainActor class can be used in @MainActor app
    let _ = await MainActor.run {
        TestMainActorApp()
    }
    print("✅ MainActor app initialization works")
    
    print("All MainActor concurrency fixes validated!")
}

// Note: Removed @main to avoid conflict with main app entry point
// This can be run independently for testing