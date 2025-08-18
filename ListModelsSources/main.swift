#!/usr/bin/env swift

import Foundation
import WhisperKit

print("🔍 Discovering Available WhisperKit Models")
print("==========================================\n")

Task {
    do {
        // Try to fetch available models
        let availableModels = try await WhisperKit.fetchAvailableModels()
        
        print("Found \(availableModels.count) available models:\n")
        
        for (index, model) in availableModels.enumerated() {
            print("\(index + 1). \(model)")
        }
        
        // Look for distil models specifically
        print("\n📦 Distil Models:")
        print("-----------------")
        let distilModels = availableModels.filter { $0.lowercased().contains("distil") }
        if distilModels.isEmpty {
            print("No models with 'distil' in the name found")
        } else {
            for model in distilModels {
                print("  • \(model)")
            }
        }
        
        // Look for v3 models
        print("\n🔢 V3 Models:")
        print("-------------")
        let v3Models = availableModels.filter { $0.lowercased().contains("v3") }
        if v3Models.isEmpty {
            print("No models with 'v3' in the name found")
        } else {
            for model in v3Models {
                print("  • \(model)")
            }
        }
        
        exit(0)
    } catch {
        print("❌ Failed to fetch models: \(error)")
        exit(1)
    }
}

RunLoop.main.run()