# Claude Development Notes for Super Voice Assistant

## Project Guidelines

- Follow the roadmap and tech choices outlined in README.md

## Background Process Management

- When developing and testing changes, run the app in background using: `swift build && swift run SuperVoiceAssistant` with `run_in_background: true`
- Keep the app running in background while the user tests functionality
- Only kill and restart the background instance when making code changes that require a fresh build
- Allow the user to continue using the running instance between agent sessions
- The user prefers to keep the app running for continuous testing

## Git Commit Guidelines

- Never include Claude attribution or Co-Author information in git commits
- Keep commit messages clean and professional without AI-related references

## Completed Features

### Gemini Live TTS Integration

**Status**: ✅ Complete and integrated into main app
**Key Files**:
- `SharedSources/GeminiStreamingPlayer.swift` - Streaming TTS playback engine
- `SharedSources/GeminiAudioCollector.swift` - Audio collection and WebSocket handling
- `SharedSources/SmartSentenceSplitter.swift` - Text processing for optimal speech

**Features**:
- ✅ Cmd+Opt+S keyboard shortcut for reading selected text aloud
- ✅ Sequential streaming for smooth, natural speech with minimal latency
- ✅ Smart sentence splitting for optimal speech flow
- ✅ 15% speed boost via TimePitch effect

### Gemini Audio Transcription

**Status**: ✅ Complete and integrated into main app
**Branch**: `gemini-audio-feature`
**Key Files**:
- `SharedSources/GeminiAudioTranscriber.swift` - Gemini API audio transcription
- `Sources/GeminiAudioRecordingManager.swift` - Audio recording manager for Gemini

**Features**:
- ✅ Cmd+Opt+X keyboard shortcut for Gemini audio recording and transcription
- ✅ Cloud-based transcription using Gemini 2.5 Flash API
- ✅ WAV audio conversion and base64 encoding
- ✅ Silence detection and automatic filtering
- ✅ Mutual exclusion with WhisperKit recording and screen recording
- ✅ Transcription history integration

**Keyboard Shortcuts**:
- **Cmd+Opt+Z**: WhisperKit audio recording (offline)
- **Cmd+Opt+X**: Gemini audio recording (cloud)
- **Cmd+Opt+S**: Text-to-speech with Gemini
- **Cmd+Opt+C**: Screen recording with video transcription
- **Cmd+Opt+A**: Show transcription history
- **Cmd+Opt+V**: Paste last transcription at cursor

