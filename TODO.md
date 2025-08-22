# Super Voice Assistant - TODO List

## Current Features

- Voice recording with Shift+Alt+Z hotkey
- WhisperKit transcription with auto-paste
- Transcription history window (Shift+Alt+A) - also shown automatically when paste fails in certain apps

## TODO Tasks

### System Permissions
- [ ] Add code to check accessibility permissions at startup
  - [ ] Check if app has accessibility access for global hotkeys
  - [ ] Check if app has accessibility access for automated paste
- [ ] Show user-friendly alerts when permissions are missing
  - [ ] Explain why each permission is needed
  - [ ] Show which features won't work without permissions
- [ ] Add option to open System Settings directly from permission alerts
  - [ ] Deep link to Privacy & Security > Accessibility settings

### Model Management
- [ ] Overhaul model state management architecture
  - [ ] Better handling of incomplete/partial downloads
  - [ ] Add ability to clean up corrupted/incomplete model files
  - [ ] Better error recovery for failed downloads
  - [ ] Unified state management for downloading, verifying, and loading

### Model Memory Requirements
- [ ] Add information about how much memory each WhisperKit model takes
- [ ] Research public information or run experiments to test memory usage