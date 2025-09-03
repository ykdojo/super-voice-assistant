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

**Status**: Initial connection test ✅ complete  
**Branch**: `gemini-text-to-speech`  
**Key Files**:
- `GEMINI_TTS_PLAN.md` - Technical specifications and implementation roadmap
- `TestGeminiLiveSources/main.swift` - Minimal WebSocket connection test
- `.env.example` - API key configuration template

**Progress**:
- ✅ API research and technical planning completed
- ✅ Swift WebSocket connection test implemented and verified
- ✅ Automatic .env file loading for secure API key management
- ✅ Successful connection to Gemini Live API with Aoede voice config
- 🔄 Next: Implement audio recording/playback pipeline

**Test Command**: `swift run TestGeminiLive`

