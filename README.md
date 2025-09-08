# Super Voice Assistant

A native macOS voice assistant with voice-to-text transcription and streaming text-to-speech capabilities.

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

## Requirements

- macOS 14.0 or later
- Xcode 15+ or Xcode Command Line Tools (for Swift 5.9+)
- Gemini API key (for text-to-speech functionality)

## System Permissions Setup

This app requires specific system permissions to function properly:

### 1. Microphone Access
The app will automatically request microphone permission on first launch. If denied, grant it manually:
- Go to **System Settings > Privacy & Security > Microphone**
- Enable access for **Super Voice Assistant**

### 2. Accessibility Access (Required for Global Hotkeys & Auto-Paste)
You must manually grant accessibility permissions for the app to:
- Monitor global keyboard shortcuts (Shift+Alt+Z, Command+Option+A, Escape)
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

## Installation & Running

```bash
# Clone the repository
git clone https://github.com/yourusername/super-voice-assistant.git
cd super-voice-assistant

# Set up environment (for TTS functionality)
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

### Keyboard Shortcuts

- **Command+Option+Z**: Start/stop recording and transcribe
- **Command+Option+S**: Read selected text aloud / Cancel TTS playback
- **Command+Option+A**: Show transcription history window
- **Escape**: Cancel recording (when recording is active)

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
```


## Tech Stack

- **Language**: Swift
- **UI Framework**: AppKit (Cocoa)  
- **Speech Recognition**: [WhisperKit](https://github.com/argmaxinc/WhisperKit)
- **Text-to-Speech**: Gemini Live API with streaming WebSocket
- **Audio Processing**: AVAudioEngine with TimePitch effects
- **Global Hotkeys**: [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)

## Project Structure

- `Sources/` - Main app code with TTS integration
- `SharedSources/` - Shared components (models, TTS, audio management)
  - `GeminiStreamingPlayer.swift` - Streaming TTS playback engine
  - `GeminiAudioCollector.swift` - Audio collection and WebSocket handling
  - `SmartSentenceSplitter.swift` - Text processing for optimal speech
  - `AudioDeviceManager.swift` - Audio device configuration
- Test utilities:
  - `TestSources/` - Model download test
  - `TestStreamingTTSSources/` - TTS functionality test
  - `TestAudioCollectorSources/` - Audio collection test
  - `TestSentenceSplitterSources/` - Sentence splitting test
- Model management utilities:
  - `ListModelsSources/`, `ValidateModelsSources/`, `DeleteModelsSources/`

## License

See [LICENSE](LICENSE) for details.