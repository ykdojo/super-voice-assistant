import Foundation

struct ModelInfo {
    let name: String
    let displayName: String
    let whisperKitModelName: String  // Actual model identifier for WhisperKit download
    let size: String
    let speed: String
    let accuracy: String
    let accuracyNote: String
    let languages: String
    let description: String
    let sourceURL: String
}

struct ModelData {
    static var availableModels: [ModelInfo] {
        var models = [
        // Distil-Whisper Large v3
        // Primary Source: https://huggingface.co/distil-whisper/distil-large-v3
        // WhisperKit CoreML: https://huggingface.co/argmaxinc/whisperkit-coreml
        // Performance Citation: HuggingFace model card (accessed Jan 2025)
        // - 756M parameters, English-only specialization
        // - 6.3x faster than large-v3 (source: HF model card)
        // - 2.43% WER on LibriSpeech validation-clean
        // - Within 1.5% WER of large-v3 on short-form, within 1% on long-form
        ModelInfo(
            name: "distil-large-v3",
            displayName: "Distil Large v3",
            whisperKitModelName: "distil-whisper_distil-large-v3",  // Non-turbo version as per display name
            size: "756 MB",
            speed: "6.3x faster",
            accuracy: "97.6%",  // Calculated from 2.43% WER validation-clean
            accuracyNote: "English-only: 2.43% WER LibriSpeech validation-clean (HF model card Jan 2025)",
            languages: "English only",
            description: "Fastest high-accuracy option for English",
            sourceURL: "https://huggingface.co/distil-whisper/distil-large-v3"
        ),
        // Whisper Large v3 Turbo
        // Primary Source: https://huggingface.co/openai/whisper-large-v3-turbo
        // Release Announcement: https://github.com/openai/whisper/discussions/2363 (Oct 1, 2024)
        // WhisperKit Benchmarks: https://twitter.com/zachnagengast (Jan 2025)
        // - 809M parameters (source: HF model card)
        // - Reduced from 32 to 4 decoder layers for significant speed improvement
        // - WhisperKit: 107x real-time on M2 Ultra (processes 10 min audio in <6 seconds)
        // - Performs similarly to large-v2 across languages
        ModelInfo(
            name: "large-v3-turbo",
            displayName: "Large v3 Turbo",
            whisperKitModelName: "openai_whisper-large-v3-v20240930_turbo",  // WhisperKit model identifier
            size: "809 MB",
            speed: "8x faster",
            accuracy: "~96%",  // Similar to large-v2 performance
            accuracyNote: "4 decoder layers, similar to large-v2 accuracy (OpenAI Oct 1, 2024)",
            languages: "99 languages",
            description: "Fast multilingual transcription with minimal accuracy loss",
            sourceURL: "https://huggingface.co/openai/whisper-large-v3-turbo"  // Official model card
        ),
        // Whisper Large v3
        // Primary Source: https://huggingface.co/openai/whisper-large-v3
        // Benchmark Citation: Aqua Voice Blog (Nov 2024): https://withaqua.com/blog/benchmark-nov-2024
        // GitHub announcement: https://github.com/openai/whisper/discussions/1762
        // - 1.54B parameters (source: HF model card)
        // - 1.80% WER on LibriSpeech test-clean (Aqua Voice benchmark Nov 2024)
        // - 10-20% error reduction vs v2 across all languages (OpenAI)
        // - Trained on 5M hours (1M weakly labeled + 4M pseudo-labeled)
        ModelInfo(
            name: "large-v3",
            displayName: "Large v3",
            whisperKitModelName: "openai_whisper-large-v3-v20240930",  // WhisperKit model identifier  
            size: "1.54 GB",
            speed: "Baseline",
            accuracy: "98.2%",  // Calculated from 1.80% WER on LibriSpeech test-clean
            accuracyNote: "State-of-the-art: 1.80% WER LibriSpeech test-clean (Aqua Voice Nov 2024)",
            languages: "99 languages",
            description: "Highest accuracy, best for professional transcription",
            sourceURL: "https://huggingface.co/openai/whisper-large-v3"  // Official model card
        )
    ]
        
        // Add tiny model for testing/development only
        #if DEBUG
        models.append(
            ModelInfo(
                name: "tiny-test",
                displayName: "Tiny (Test Only)",
                whisperKitModelName: "openai_whisper-tiny",
                size: "39 MB",
                speed: "32x faster",
                accuracy: "~87%",
                accuracyNote: "Test model only - not for production use",
                languages: "99 languages",
                description: "⚠️ DEV ONLY: Quick testing model with lower accuracy",
                sourceURL: "https://huggingface.co/openai/whisper-tiny"
            )
        )
        #endif
        
        return models
    }
}
