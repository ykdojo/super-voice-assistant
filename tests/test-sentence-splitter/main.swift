import Foundation
import SharedModels

@main
struct TestSentenceSplitter {
    static func main() {
        print("🧪 Testing Smart Sentence Splitter\n")
        
        let testCases = [
            // Basic sentences
            "This is the first sentence. This is the second sentence.",
            
            // Abbreviations
            "Dr. Smith went to the U.S. yesterday. He met with Prof. Johnson at 3 p.m. They discussed the project.",
            
            // Short fragments that should be combined
            "Yes. I agree. We should proceed with the plan immediately.",
            
            // Complex punctuation
            "What?! Are you serious? That's incredible! I can't believe it.",
            
            // Mixed length sentences
            "Short one. This is a much longer sentence that contains multiple clauses and should stand alone. Another short. Final long sentence with detailed information.",
            
            // Single sentence (should not be split)
            "This is just one sentence without any splits needed.",
            
            // Quotes and parentheses
            "He said, 'This is important.' The result (as expected) was positive. We're done!",
            
            // Numbers and decimals
            "The temperature was 98.6 degrees. The pH level measured 7.2 exactly. Everything looked normal."
        ]
        
        for (index, testCase) in testCases.enumerated() {
            print("📝 Test Case \(index + 1):")
            print("Original: \(testCase)")
            
            let analysis = SmartSentenceSplitter.analyzeText(testCase)
            
            print("Split into \(analysis.sentences.count) sentences:")
            for (i, sentence) in analysis.sentences.enumerated() {
                print("  \(i + 1). [\(analysis.wordCounts[i]) words] \(sentence)")
            }
            print("---")
        }
        
        // Test edge cases
        print("\n🔍 Testing Edge Cases:")
        
        let edgeCases = [
            "",
            "   ",
            "Single.",
            "No punctuation here",
            "Multiple...ellipses...here.",
            "Acronyms like NASA, FBI, and CIA are common. They shouldn't split incorrectly."
        ]
        
        for edgeCase in edgeCases {
            let result = SmartSentenceSplitter.splitIntoSentences(edgeCase)
            print("'\(edgeCase)' -> \(result.count) sentences: \(result)")
        }
        
        print("\n✅ Sentence splitter testing complete!")
    }
}