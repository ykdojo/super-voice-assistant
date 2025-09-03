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

## Documentation in Progress

### Gemini Live TTS Integration

**Status**: Complete TTS system ✅ ready for main app integration  
**Branch**: `gemini-text-to-speech`  
**Key Files**:
- `GEMINI_TTS_PLAN.md` - Technical specifications and implementation roadmap
- `SharedSources/GeminiTTS.swift` - Reusable TTS component with AVAudioEngine
- `TestGeminiLiveSources/main.swift` - Simple test executable using shared component
- `.env.example` - API key configuration template

**Progress**:
- ✅ API research and technical planning completed
- ✅ Complete WebSocket connection with JSON parsing and base64 audio decoding
- ✅ AVAudioEngine playback pipeline with 15% speed boost via TimePitch effect
- ✅ Shared GeminiTTS component extracted for main app reuse
- 🔄 Next: Add Cmd+Opt+S keyboard shortcut for selected text speech

**Test Command**: `swift run TestGeminiLive`

**Keyboard Shortcut Implementation**:
- **Target**: Cmd+Opt+S for reading selected text aloud
- **Feasible**: ✅ Yes - app already has Cmd+Opt+Z/A shortcuts using KeyboardShortcuts library
- **Integration**: Add GeminiTTS to main app, capture selected text via accessibility APIs, trigger TTS
- **Reference**: See existing shortcuts in `Sources/main.swift:45-49`

