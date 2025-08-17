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

### Whisper-based Models

#### OpenAI Whisper
**Pros**: Best accuracy, widely supported, many model sizes
**Cons**: Can be slower, larger models need more RAM

#### Whisper.cpp
**Pros**: Fast C++ implementation, good Apple Silicon support
**Cons**: Requires C++ integration

#### WhisperKit
**Pros**: Native Swift, optimized for Apple Silicon, Core ML acceleration
**Cons**: Newer, less tested

#### Distil-Whisper
**Pros**: 6x faster than original, 49% smaller
**Cons**: English only, slightly less accurate

### Non-Whisper Alternatives

#### Vosk
**Pros**: Lightweight (50MB), real-time processing, low CPU usage, no GPU needed
**Cons**: Lower accuracy than Whisper, basic features only

#### SpeechBrain
**Pros**: PyTorch-based, comprehensive toolkit, many pretrained models
**Cons**: Resource intensive, steep learning curve

#### Wav2vec 2.0 (Meta)
**Pros**: Self-supervised learning, excellent on clean audio
**Cons**: Complex setup, not optimized for real-time

#### Kaldi
**Pros**: Highly customizable, great for research, multi-language
**Cons**: Very complex setup, requires expertise, not user-friendly

#### NeMo (NVIDIA)
**Pros**: GPU optimized, great for real-time, strong performance
**Cons**: Best with NVIDIA hardware

## License

Closed source - All rights reserved.