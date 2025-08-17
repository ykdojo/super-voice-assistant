# Super Voice Assistant

A simple macOS dictation app with global hotkey support for voice transcription.

## Goal

Press a global hotkey → Speak → Text appears at cursor position.

## Core Features
- Global hotkey (Shift+Alt+Z) to start/stop recording
- Transcribe speech using WhisperKit
- Insert text at cursor position
- Runs fully offline

## Tech Stack
- **Language**: Swift
- **UI Framework**: Cocoa (AppKit)
- **Speech Recognition**: WhisperKit (native Swift package)
- **Global Hotkeys**: KeyboardShortcuts library

## Building and Running

```bash
# Build the app
swift build

# Run the app
swift run
```

The app runs in the menu bar (look for the waveform icon).

## Project Structure
- `Sources/main.swift` - Main app entry point with menu bar implementation
- `Package.swift` - Swift package configuration

## License

All rights reserved.