# Roadmap & Known Constraints

## Dependency Pinning

### FluidAudio is pinned to 0.12.x (`.upToNextMinor(from: "0.12.6")`)

Do **not** loosen this to `from:` or bump to 0.13+ without a code change.

- **Why 0.12.6 (floor):** Swift 6.3 (Xcode 26) makes the region-based `sending`
  data-race check a hard error. FluidAudio ≤0.10.x (built in Swift 6 language mode)
  fails to compile because `StreamingAsrManager` (an actor) sends a self-isolated
  `AsrManager` *class* into nonisolated async calls. FluidAudio 0.12.6 fixes this by
  converting `AsrManager` to an `actor` (upstream PR #419).
- **Why not 0.13+ (ceiling):** 0.13.0 changed the `transcribe()` API to require an
  `inout TdtDecoderState` and removed the simple `transcribe(_ audioSamples:)`
  convenience overload that `SharedSources/ParakeetTranscriber.swift` relies on.
  Moving past 0.12.x means rewriting the Parakeet transcription path to create and
  manage decoder state.

### Coupled upgrade: WhisperKit 1.0.0 + swift-transformers 1.3.3

FluidAudio 0.12.6 requires `swift-transformers ≥ 1.2.0`, which the old WhisperKit
(0.13.1, on swift-transformers 0.1.x) capped below. They must move together:

- WhisperKit `0.13.1` → `1.0.0`
- swift-transformers `0.1.15` → `1.3.3`

WhisperKit 1.0.0 API changes that were applied:
- `DecodingOptions` removed `usePrefillCache`.
- `DecodingOptions` renamed `supressTokens` → `suppressTokens` (fixed the old typo).

## To verify

- [x] Runtime smoke test of WhisperKit transcription (Cmd+Opt+Z) after the major
      WhisperKit 0.13.1 → 1.0.0 bump. — passed initial smoke test.
- [x] Runtime smoke test of Parakeet transcription (FluidAudio 0.12.6 actor change +
      `ParakeetTranscriber.isReady` now derived from local `loadingState`). — passed
      initial smoke test.

> Note: these were quick happy-path smoke tests. A longer real-world soak is still
> recommended given the major WhisperKit / swift-transformers version jumps.
