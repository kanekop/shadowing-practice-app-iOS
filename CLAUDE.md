# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ShadowingPractice is an iOS app for English language learning through shadowing and reading practice. The app records users' speech, performs speech recognition, and provides accuracy feedback by comparing against reference text.

## Build and Run Commands

This is an Xcode project that requires Xcode IDE:
- Open `ShadowingPractice.xcodeproj` in Xcode
- Build: `Cmd+B` in Xcode
- Run: `Cmd+R` in Xcode (requires iOS Simulator or device)
- Clean: `Cmd+Shift+K` in Xcode

No command-line build tools, external dependencies, or package managers are used.

## Architecture

### Core Services Pattern
The app uses a service-oriented architecture with ObservableObject services:

1. **AudioRecorder** (`Services/AudioRecorder.swift`)
   - Manages AVAudioSession and AVAudioRecorder
   - Saves recordings to Documents directory as .m4a files
   - Has completion handler for `stopRecording(completion:)` to ensure recording finalization
   - Automatically triggers transcription after recording

2. **SpeechRecognizer** (`Services/SpeechRecognizer.swift`)
   - Wraps Apple's Speech framework for English-only recognition
   - Provides `recognizeFromFile(url:completion:)` for async recognition
   - Publishes recognition progress via Combine

3. **TextComparisonService** (`Services/TextComparisonService.swift`)
   - Implements Levenshtein distance algorithm for word-level comparison
   - Returns accuracy percentage and detailed error breakdown
   - Provides feedback based on accuracy thresholds

### Data Flow
1. User records audio → AudioRecorder saves .m4a file
2. Recording completion triggers → SpeechRecognizer transcribes audio
3. Transcription result → TextComparisonService compares with reference
4. Comparison result → PracticeSession saved with score and feedback

### State Management
- Views use @StateObject for service instances
- Services expose @Published properties for reactive UI updates
- No separate ViewModels - views directly observe services

## Key Implementation Details

### Audio Recording
- Format: MPEG4 AAC, 44.1kHz, 2 channels, high quality
- Files saved to: `Documents/[UUID].m4a`
- Transcriptions saved alongside: `Documents/[UUID].txt`

### Speech Recognition
- Language: Hardcoded to "en-US"
- Requires explicit user permission (Info.plist keys configured)
- Handles file-based recognition, not streaming

### Practice Flow
1. **PracticeView** manages the practice session lifecycle
2. Uses `currentRecordingURL` @State to track active recording
3. Implements debug logging for troubleshooting recording/recognition issues
4. Waits for recording completion before starting recognition

## Common Issues and Solutions

### Recording/Recognition Timing
- The app uses completion handlers to ensure recording files are fully written before recognition
- Debug statements track the recording → recognition pipeline
- File existence checks prevent recognition on missing files

### SwiftUI Considerations
- PracticeView is a struct, so no `[weak self]` in closures
- Use `self` directly in completion handlers
- Timer cleanup in `stopRecording()` prevents memory issues

## Testing
- Test structure exists but no tests implemented
- Run tests in Xcode: `Cmd+U`
- Test files located in `ShadowingPracticeTests/` and `ShadowingPracticeUITests/`

## Permissions
The app requires these Info.plist permissions:
- Microphone: "音声入力のためにマイクを使用します"
- Speech Recognition: "文字に変換するために使用します"