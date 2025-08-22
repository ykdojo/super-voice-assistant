# WhisperKit Custom Vocabulary Research

## Overview
This document summarizes our research into implementing custom vocabulary support in WhisperKit for the Super Voice Assistant project. The goal is to improve transcription accuracy for domain-specific terms using WhisperKit's `promptTokens` parameter.

## Research Findings

### 1. WhisperKit Tokenizer Access ✅
**Finding**: WhisperKit exposes a public tokenizer that can encode text to token IDs.

**Evidence**: Running `TestTokenizer` revealed:
- WhisperKit has a `tokenizer` property of type `Optional<WhisperTokenizer>`
- The tokenizer is implemented as `WhisperTokenizerWrapper`
- It provides full `encode(text: String) -> [Int]` and `decode(tokens: [Int]) -> String` methods

**Key Properties Available**:
```swift
whisperKit.tokenizer              // Direct tokenizer access
whisperKit.textDecoder.tokenizer  // Also available through text decoder
```

### 2. Token Encoding Capabilities ✅
**Finding**: The tokenizer successfully encodes text to token IDs that can be used with `promptTokens`.

**Test Results**:
```swift
// Example encoding
"Hello, this is a test" -> [50258, 50363, 15947, 11, 341, 307, 257, 1500, ...]
"API JSON HTTP REST"    -> [50258, 50363, 4715, 40, 31828, 33283, 497, 14497, ...]
```

**Special Tokens Observed**:
- `50258`: `<|startoftranscript|>`
- `50363`: `<|notimestamps|>`
- `50257`: `<|endoftext|>`

### 3. DecodingOptions Integration
**Finding**: `DecodingOptions` accepts a `promptTokens: [Int]?` parameter.

**Current Implementation** (AudioTranscriptionManager.swift:214-229):
```swift
DecodingOptions(
    // ... other options ...
    promptTokens: nil  // Currently not using custom vocabulary
)
```

**Proposed Enhancement**:
```swift
// Encode custom vocabulary
let customVocab = "Technical terms: API, JSON, GraphQL, WhisperKit"
let promptTokens = whisperKit.tokenizer?.encode(text: customVocab)

// Use in DecodingOptions
DecodingOptions(
    // ... other options ...
    promptTokens: promptTokens
)
```

## Files Created

### 1. TestTokenizerSources/main.swift
**Purpose**: Explore WhisperKit's tokenizer API and confirm accessibility
**Status**: ✅ Tested and working
**Key Discovery**: Successfully accessed and used `whisperKit.tokenizer` to encode/decode text

### 2. TestVocabularySources/main.swift
**Purpose**: Demonstrate custom vocabulary implementation with real transcription
**Status**: ⚠️ Created but not yet tested with real audio
**Features**:
- Shows how to encode custom vocabulary
- Compares transcription with and without promptTokens
- Demonstrates different prompt strategies

### 3. Package.swift (Modified)
**Changes**: Added two new executable targets:
- `TestTokenizer`: For tokenizer exploration
- `TestVocabulary`: For vocabulary testing (not yet added to Package.swift)

## What Has Been Tested

### ✅ Successfully Tested:
1. **Tokenizer Access**: Confirmed `whisperKit.tokenizer` is publicly accessible
2. **Text Encoding**: Successfully encoded various text strings to token arrays
3. **Text Decoding**: Verified round-trip encoding/decoding works correctly
4. **Token Structure**: Identified special tokens added by the tokenizer

### ⚠️ Not Yet Tested:
1. **Real Audio Transcription**: Haven't tested with actual speech audio containing technical terms
2. **Vocabulary Impact**: Haven't measured improvement in transcription accuracy
3. **Production Integration**: Haven't integrated into AudioTranscriptionManager
4. **Performance Impact**: Unknown impact on transcription speed with large prompts
5. **Token Limits**: Haven't tested maximum viable prompt length

## Next Steps

### Immediate Testing Needed:

1. **Create Real Test Audio**
   ```bash
   # Record audio with technical terms
   say -o /tmp/test_tech.aiff "I'm using WhisperKit API with JSON and GraphQL"
   ffmpeg -i /tmp/test_tech.aiff -ar 16000 /tmp/test_tech.wav
   ```

2. **Test Vocabulary Impact**
   ```bash
   # Add TestVocabulary to Package.swift and run
   swift run TestVocabulary /tmp/test_tech.wav
   ```

3. **Measure Accuracy Improvement**
   - Transcribe without promptTokens
   - Transcribe with technical vocabulary promptTokens
   - Compare accuracy for technical terms

### Integration Steps:

1. **Create Vocabulary Manager**
   ```swift
   class VocabularyManager {
       static func getTechnicalVocabulary() -> String {
           return "Terms: API, JSON, HTTP, REST, GraphQL, WebSocket, WhisperKit, CoreML"
       }
   }
   ```

2. **Update AudioTranscriptionManager**
   - Add vocabulary encoding before transcription
   - Make vocabulary configurable via Settings

3. **Add UI Controls**
   - Toggle for enabling/disabling custom vocabulary
   - Text field for user-defined terms

## Prompt Strategy Recommendations

Based on research, these strategies may be effective:

### 1. Direct Listing (Recommended)
```swift
"Technical terms: API, JSON, GraphQL, CoreML, SwiftUI"
```
- Simple and direct
- Low token count
- Easy to maintain

### 2. Context Setting
```swift
"The speaker is discussing software development and iOS programming."
```
- Provides context to the model
- May help with ambiguous terms

### 3. Example Utterances
```swift
"Example: I'm using the WhisperKit API with CoreML models."
```
- Shows the model expected patterns
- Good for specific phrase structures

### 4. Spelling Hints (For Acronyms)
```swift
"API (A-P-I), JSON (J-S-O-N), URL (U-R-L)"
```
- May help with acronym recognition
- Higher token count

## Token Budget Considerations

- WhisperKit uses a context window for decoding
- Recommended to keep promptTokens under 224 tokens
- Each word typically uses 1-3 tokens
- Special tokens are added automatically

## Known Limitations

1. **Performance**: GitHub issue #53 mentions Core ML processes tokens "one at a time", causing slowdown with long prompts
2. **Feature Status**: Full prompt support is planned for WhisperKit v1.0
3. **Token Encoding**: No direct text-to-token method was documented before our discovery

## Testing Commands

```bash
# Build all test tools
swift build

# Test tokenizer access
swift run TestTokenizer

# Test with real audio (once TestVocabulary is added to Package.swift)
swift run TestVocabulary /path/to/audio.wav

# Test in main app with custom vocabulary
swift run SuperVoiceAssistant
```

## Conclusion

We've successfully discovered that WhisperKit's tokenizer is accessible and functional for encoding custom vocabulary. The `promptTokens` parameter in `DecodingOptions` can accept these encoded tokens. The next critical step is testing with real audio to measure the actual impact on transcription accuracy for domain-specific terms.

## References

- WhisperKit GitHub: https://github.com/argmaxinc/WhisperKit
- Original Whisper Paper: https://arxiv.org/abs/2212.04356
- WhisperKit Issues: #53 (Performance), #127 (Prompt support)