# Super Voice Assistant

A native macOS dictation app with global hotkey support for instant voice-to-text transcription.

## Current Status

A macOS menu bar app that transcribes voice to text using WhisperKit. Press Shift+Alt+Z to record, and the transcribed text automatically pastes at your cursor position. Press Shift+Alt+A to view transcription history.

**[See TODO.md](TODO.md)** for planned features and ongoing tasks.

## Requirements

- macOS 14.0 or later
- Xcode 15+ or Xcode Command Line Tools (for Swift 5.9+)
- Microphone permissions

## Installation & Running

```bash
# Clone the repository
git clone https://github.com/yourusername/super-voice-assistant.git
cd super-voice-assistant

# Build the app
swift build

# Run the main app
swift run SuperVoiceAssistant
```

The app will appear in your menu bar as a waveform icon.

## Usage

1. Launch the app - it appears in the menu bar
2. Open Settings (click menu bar icon > Settings) to download a WhisperKit model
3. Press **Shift+Alt+Z** to start recording (the menu bar icon changes to show a recording indicator and live audio level meter)
4. Press **Shift+Alt+Z** again to stop recording and transcribe
5. The transcribed text will automatically be pasted at your cursor position
6. Press **Escape** during recording to cancel without transcribing

### Keyboard Shortcuts

- **Shift+Alt+Z**: Start/stop recording and transcribe
- **Shift+Alt+A**: Show transcription history window
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
```


## Tech Stack

- **Language**: Swift
- **UI Framework**: AppKit (Cocoa)
- **Speech Recognition**: [WhisperKit](https://github.com/argmaxinc/WhisperKit)
- **Global Hotkeys**: [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)

## Project Structure

- `Sources/` - Main app code
- `SharedSources/` - Shared model management code
- `TestSources/` - Model download test utility
- `ListModelsSources/` - Model listing utility
- `ValidateModelsSources/` - Model validation utility
- `DeleteModelsSources/` - Bulk model deletion utility
- `DeleteModelSources/` - Single model deletion utility

## License

See [LICENSE](LICENSE) for details.