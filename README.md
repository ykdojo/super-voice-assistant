# Super Voice Assistant

A simple macOS dictation app with global hotkey support, powered by OpenAI's Whisper.

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

### OpenAI Whisper
**Pros**: Best accuracy, widely supported, many model sizes
**Cons**: Can be slower, larger models need more RAM

### Whisper.cpp
**Pros**: Fast C++ implementation, good Apple Silicon support
**Cons**: Requires C++ integration

### WhisperKit
**Pros**: Native Swift, optimized for Apple Silicon, Core ML acceleration
**Cons**: Newer, less tested

### Distil-Whisper
**Pros**: 6x faster than original, 49% smaller
**Cons**: English only, slightly less accurate

## License

Closed source - All rights reserved.