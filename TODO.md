# Super Voice Assistant - TODO List

## Current Features

- Voice recording with Shift+Alt+Z hotkey
- WhisperKit transcription with auto-paste
- Transcription history window (Shift+Alt+A)
- Copy fallback window when paste fails

## TODO Tasks

### Code Refactoring
- [ ] **Split main.swift** (531 lines) to keep files under 300 lines

### Model Management
- [ ] Improve model download/loading state management
  - [ ] Better handling of incomplete/partial downloads
  - [ ] Add ability to clean up corrupted/incomplete model files
  - [ ] Better error recovery for failed downloads

### Model Memory Requirements
- [ ] Add information about how much memory each WhisperKit model takes
- [ ] Research public information or run experiments to test memory usage