# Super Voice Assistant

A simple macOS dictation app with global hotkey support for voice transcription.

## Goal

Press a global hotkey → Speak → Text appears at cursor position.

## Core Features
- Global hotkey (e.g., Cmd+Shift+Space) to start/stop recording
- Transcribe speech using Whisper or different models
- Insert text at cursor position
- Runs fully offline

## Tech Stack
- **Language**: Swift (possibly C++ for Whisper integration)

## Model Options

### Recommended: Whisper-based Models
Based on 2024 benchmarks, Whisper models dominate in accuracy, especially for noisy environments and diverse accents.

#### WhisperKit (Best for Mac)
**Pros**: Native Swift, optimized for Apple Silicon, Core ML acceleration
**Cons**: Newer, less tested
**Recommendation**: Start here for Mac-native performance

#### Whisper.cpp
**Pros**: Fast C++ implementation, good Apple Silicon support
**Cons**: Requires C++ integration
**Recommendation**: Alternative if WhisperKit has issues

#### Distil-Whisper (English-only speed)
**Pros**: 6x faster than original, 49% smaller, only 1% accuracy loss
**Cons**: English only
**Recommendation**: Best for English-only dictation with speed priority

#### OpenAI Whisper (Original)
**Pros**: Best accuracy, widely supported, many model sizes
**Cons**: Can be slower, larger models need more RAM
**Model sizes**: Base (150MB), Small (500MB), Medium (1.5GB), Large (3GB)

### Not Recommended: Non-Whisper Alternatives
These alternatives generally underperform Whisper for dictation use cases:

- **Vosk**: 2-3x higher error rate, too inaccurate for dictation
- **SpeechBrain/Kaldi**: Too complex for simple app
- **Wav2vec 2.0**: Not optimized for real-time
- **NeMo**: Requires NVIDIA GPU (Macs don't have them)

## License

Closed source - All rights reserved.