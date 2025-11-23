# Super Voice Assistant

macOS voice assistant with global hotkeys - transcribe speech to text with offline models into the current cursor and read selected text out loud with live Gemini models.

## Demo (instant text-to-speech)

https://github.com/user-attachments/assets/c961f0c6-f3b3-49d9-9b42-7a7d93ee6bc8

## Features

**Voice-to-Text Transcription**
- Press Command+Option+Z to record audio and get instant transcription
- Automatic text pasting at cursor position
- Transcription history with Command+Option+A

**Streaming Text-to-Speech**
- Press Command+Option+S to read selected text aloud using Gemini Live API
- Press Command+Option+S again while reading to cancel the operation
- Sequential streaming for smooth, natural speech with minimal latency
- Smart sentence splitting for optimal speech flow

**Screen Recording & Video Transcription**
- Press Command+Option+X to start/stop screen recording
- Automatic video transcription using Gemini 2.5 Flash API
- Transcribed text automatically pastes at cursor position
- Video files auto-deleted after successful transcription
- Mutual exclusion with audio recording for clean operation

## Requirements

- macOS 14.0 or later
- Xcode 15+ or Xcode Command Line Tools (for Swift 5.9+)
- Gemini API key (for text-to-speech and video transcription)
- ffmpeg (for screen recording functionality)

## System Permissions Setup

This app requires specific system permissions to function properly:

### 1. Microphone Access
The app will automatically request microphone permission on first launch. If denied, grant it manually:
- Go to **System Settings > Privacy & Security > Microphone**
- Enable access for **Super Voice Assistant**

### 2. Accessibility Access (Required for Global Hotkeys & Auto-Paste)
You must manually grant accessibility permissions for the app to:
- Monitor global keyboard shortcuts (Command+Option+Z/S/X/A, Escape)
- Automatically paste transcribed text at cursor position

**To enable:**
1. Go to **System Settings > Privacy & Security > Accessibility**
2. Click the lock icon to make changes (enter your password)
3. Click the **+** button to add an application
4. Navigate to the app location:
   - If running via `swift run`: Add **Terminal** or your terminal app (iTerm2, etc.)
   - If running the built binary directly: Add the **SuperVoiceAssistant** executable
5. Ensure the checkbox next to the app is checked

**Important:** Without accessibility access, the app cannot detect global hotkeys or paste text automatically.

### 3. Screen Recording Access (Required for Video Transcription)
The app requires screen recording permission to capture screen content:
- Go to **System Settings > Privacy & Security > Screen Recording**
- Enable access for **Terminal** (if running via `swift run`) or **SuperVoiceAssistant**

## Installation & Running

```bash
# Clone the repository
git clone https://github.com/yourusername/super-voice-assistant.git
cd super-voice-assistant

# Install ffmpeg (required for screen recording)
brew install ffmpeg

# Set up environment (for TTS and video transcription)
cp .env.example .env
# Edit .env and add your GEMINI_API_KEY

# Build the app
swift build

# Run the main app
swift run SuperVoiceAssistant
```

The app will appear in your menu bar as a waveform icon.

## Usage

### Voice-to-Text Transcription
1. Launch the app - it appears in the menu bar
2. Open Settings (click menu bar icon > Settings) to download a WhisperKit model
3. Press **Command+Option+Z** to start recording (menu bar icon shows recording indicator)
4. Press **Command+Option+Z** again to stop recording and transcribe
5. The transcribed text automatically pastes at your cursor position
6. Press **Escape** during recording to cancel without transcribing

### Text-to-Speech
1. Select any text in any application
2. Press **Command+Option+S** to read the selected text aloud
3. Press **Command+Option+S** again while reading to cancel the operation
4. The app uses Gemini Live API for natural, streaming speech synthesis
5. Configure audio devices via Settings for optimal playback

### Screen Recording & Video Transcription
1. Press **Command+Option+X** to start screen recording
2. The menu bar shows "🎥 REC" while recording
3. Press **Command+Option+X** again to stop recording
4. The app automatically transcribes the video using Gemini 2.5 Flash
5. Transcribed text pastes at your cursor position
6. Video file is automatically deleted after successful transcription

**Note:** Audio recording and screen recording are mutually exclusive - you cannot run both simultaneously.

### Keyboard Shortcuts

- **Command+Option+Z**: Start/stop audio recording and transcribe
- **Command+Option+S**: Read selected text aloud / Cancel TTS playback
- **Command+Option+X**: Start/stop screen recording and transcribe
- **Command+Option+A**: Show transcription history window
- **Escape**: Cancel audio recording (when recording is active)

## Available Commands

```bash
# Run the main app
swift run SuperVoiceAssistant

# List all available WhisperKit models
swift run ListModels

# Test downloading a model (currently set to distil-whisper_distil-large-v3)
swift run TestDownload

# Validate downloaded models are complete
swift run ValidateModels

# Delete all downloaded models
swift run DeleteModels

# Delete a specific model
swift run DeleteModel <model-name>
# Example: swift run DeleteModel distil-large-v3

# Test transcription with a sample audio file
swift run TestTranscription

# Test live transcription with microphone input
swift run TestLiveTranscription

# Test streaming TTS functionality
swift run TestStreamingTTS

# Test audio collection for TTS
swift run TestAudioCollector

# Test sentence splitting for TTS
swift run TestSentenceSplitter

# Test screen recording (3-second capture)
swift run RecordScreen

# Test video transcription with Gemini API
swift run TranscribeVideo <path-to-video-file>
# Example: swift run TranscribeVideo ~/Desktop/recording.mp4
```

## Project Structure

- `Sources/` - Main app code with TTS and video transcription
  - `ScreenRecorder.swift` - Screen recording with ffmpeg
- `SharedSources/` - Shared components (models, TTS, audio, video)
  - `GeminiStreamingPlayer.swift` - Streaming TTS playback engine
  - `GeminiAudioCollector.swift` - Audio collection and WebSocket handling
  - `SmartSentenceSplitter.swift` - Text processing for optimal speech
  - `AudioDeviceManager.swift` - Audio device configuration
  - `VideoTranscriber.swift` - Gemini API video transcription
- `tests/` - Test utilities organized by functionality:
  - `test-download/` - Model download test
  - `test-streaming-tts/` - TTS functionality test
  - `test-audio-collector/` - Audio collection test
  - `test-sentence-splitter/` - Sentence splitting test
  - `test-transcription/` - Transcription functionality test
  - `test-live-transcription/` - Live transcription test
  - `test-audio-analysis/` - Audio analysis test
- `tools/` - Utilities for models and media:
  - `list-models/` - List available WhisperKit models
  - `validate-models/` - Validate downloaded models
  - `delete-models/` - Delete all downloaded models
  - `delete-model/` - Delete a specific model
  - `record-screen/` - Screen recording test tool
  - `transcribe-video/` - Video transcription test tool
- `scripts/` - Build and icon generation scripts
- `logos/` - Logo and branding assets

## License

See [LICENSE](LICENSE) for details.
