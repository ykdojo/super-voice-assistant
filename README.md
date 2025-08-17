# Super Voice Assistant

A simple macOS dictation app with global hotkey support for voice transcription.

## Goal

Press a global hotkey → Speak → Text appears at cursor position.

## Core Features
- Global hotkey (Shift+Alt+Z) to start/stop recording
- Transcribe speech using Whisper or different models
- Insert text at cursor position
- Runs fully offline

## Tech Stack
- **Language**: Swift
- **Speech Recognition**: WhisperKit (native Swift package)

## Model Strategy

### Implementation: WhisperKit
Native Swift implementation optimized for Apple Silicon. Can run any Whisper-compatible model.

### Models to Use
1. **Start with**: Whisper Base (150MB) - Fast, good for testing
2. **For English speed**: Distil-Whisper (6x faster, English only)
3. **For best quality**: Whisper Small (500MB) or Medium (1.5GB)

All models work with the same WhisperKit code - just swap the model file.

### Why Not Others?
- **whisper.cpp**: Requires C++ bridging, WhisperKit is native Swift
- **Original Whisper**: Python-based, too slow for real-time
- **Non-Whisper models** (Vosk, Kaldi, etc.): Lower accuracy based on 2024 benchmarks

## License

All rights reserved.