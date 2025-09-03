# Gemini Live TTS Integration Plan

## API Details
- **Model**: `gemini-2.0-flash-live-001` 
- **WebSocket URL**: `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent`
- **Auth**: `GEMINI_API_KEY` header
- **Free Tier**: 3 concurrent sessions, unlimited daily usage, 1M TPM

## Swift Components

### 1. WebSocket Client
- **API**: `URLSessionWebSocketTask` (iOS 13+)
- **Messages**: JSON with base64 audio/video data
- **Pattern**: AsyncThrowingStream for receive loop

### 2. Audio Pipeline  
- **Record**: `AVAudioEngine.inputNode` + installTap
- **Format**: 16kHz PCM input, 24kHz PCM output
- **Playback**: `AVAudioEngine.mainMixerNode`
- **Buffers**: 1024 samples, real-time processing

### 3. Video Capture (Optional)
- **API**: `AVCaptureSession` + `AVCaptureVideoDataOutput` 
- **Format**: JPEG frames, base64 encoded
- **Rate**: 1fps for efficiency

### 4. Architecture
```
AudioEngine → WebSocket → Gemini Live API
     ↑                          ↓
  Microphone              Audio Response
```

## Key Configuration
```swift
speech_config: {
  language_code: "en-US",
  voice_config: { voice_name: "Aoede" }
}
```

## Implementation Order
1. WebSocket connection + auth
2. Audio recording pipeline 
3. Audio playback pipeline
4. Response handling + text display
5. Video capture (if needed)