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

## Code Quality

- When completing coding tasks, always run lint and typecheck commands if available
- If unable to find the correct commands, ask the user and suggest adding them to this file for future reference