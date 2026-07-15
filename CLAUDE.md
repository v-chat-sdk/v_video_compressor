# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**v_video_compressor** is a professional Flutter plugin for high-quality video compression with real-time progress tracking and thumbnail generation. The plugin uses native platform APIs (Media3 for Android, AVFoundation for iOS) rather than ffmpeg for optimal performance and smaller app size.

**Version**: 3.0.0
**Platforms**: Android (API 21+), iOS (13.0+ — Swift Package Manager only, requires Flutter 3.38+)
**Key Features**: Multi-quality compression, real-time progress, global progress stream, thumbnail generation, batch processing

## Architecture

### Plugin Structure (Platform Channels)

The plugin follows Flutter's platform channel pattern with three layers:

1. **Dart Layer** (`lib/`):
   - `v_video_compressor.dart` - Main API facade with logging and validation
   - `v_video_compressor_platform_interface.dart` - Abstract platform interface
   - `v_video_compressor_method_channel.dart` - MethodChannel implementation
   - `src/v_video_models.dart` - All data models, enums, and configurations
   - `src/v_video_stream_manager.dart` - Global progress event stream manager (v1.2.0+)
   - `src/v_video_logger.dart` - Comprehensive logging system

2. **Android Native** (`android/src/main/kotlin/`):
   - `VVideoCompressorPlugin.kt` - MethodChannel handler and lifecycle management
   - `VVideoCompressionEngine.kt` - Core compression using Media3, handles progress calculation
   - `VVideoMediaLoader.kt` - Video metadata extraction
   - `VVideoModels.kt` - Kotlin data classes mirroring Dart models

3. **iOS Native** (`ios/v_video_compressor/Sources/v_video_compressor/`):
   - `VVideoCompressorPlugin.swift` - MethodChannel handler
   - `VVideoCompressionEngine.swift` - Core compression using AVFoundation
   - `VVideoMediaLoader.swift` - Video metadata extraction
   - `VVideoModels.swift` - Swift data classes

### Progress Tracking Architecture

**v1.2.0+** introduced a global progress stream accessible from anywhere:

- **Dart**: `VVideoStreamManager` manages EventChannel → StreamController broadcast
- **Native**: Platforms emit progress events via `v_video_compressor/progress` EventChannel
- **Event Flow**: Native → EventChannel → StreamController → Multiple Listeners
- **Type Safety**: All events use typed `VVideoProgressEvent` model (no raw Maps)

### Key Design Patterns

- **Platform Interface Pattern**: Abstract `VVideoCompressorPlatform` with MethodChannel implementation
- **Singleton Stream Manager**: Global progress stream accessible via static methods
- **Broadcast Stream**: Multiple widgets/services can listen to progress simultaneously
- **Facade Pattern**: `VVideoCompressor` class provides simple API over complex platform logic
- **Data Transfer Objects**: All communication uses immutable data classes with `toMap()`/`fromMap()`
- **Validation at Boundaries**: Dart validates configurations before platform call
- **Comprehensive Logging**: Optional detailed logging with configurable levels

## Common Development Commands

### Flutter/Dart Commands

```bash
# Get dependencies
flutter pub get

# Analyze code (DO NOT build APK or run on device)
flutter analyze

# Run tests
flutter test

# Format code
dart format .

# Check for lints
flutter analyze

# Run example app (if needed for testing)
cd example
flutter pub get
flutter run
```

### Android-Specific

```bash
# Compile Android code only (no APK build)
cd example/android
./gradlew assembleDebug

# Check for Android issues
./gradlew lintDebug
```

### iOS-Specific

iOS uses Swift Package Manager only (no CocoaPods, no `pod install`). The Flutter
tool resolves the package in `ios/v_video_compressor/` automatically.

```bash
# Compile iOS code (requires macOS)
cd example
flutter build ios --no-codesign
```

### Platform Testing

**IMPORTANT**: For development speed, use `flutter analyze` instead of building APKs or running on devices. Full builds are time-consuming and only needed for final validation.

## Code Modification Guidelines

### When Adding New Features

1. **Check Existing Implementation First**: Search for similar features in both Dart and native code
2. **Update All Three Layers**: Dart interface → Android implementation → iOS implementation
3. **Mirror Data Models**: Keep Dart, Kotlin, and Swift models in sync
4. **Validate Configurations**: Add validation to `isValid()` methods in model classes
5. **Add Logging**: Use `VVideoLogger` for all method calls and important events
6. **Document Public APIs**: Add comprehensive dartdoc comments

### Platform-Specific Compression Logic

**Android** (`VVideoCompressionEngine.kt`):

- Uses Media3 `Transformer` API
- Hardware acceleration via `DefaultEncoderFactory`
- Progress calculation: estimated based on bitrate and duration
- Output: MP4 with H.264/H.265 video, AAC audio

**iOS** (`VVideoCompressionEngine.swift`):

- Uses AVFoundation `AVAssetExportSession`
- Quality presets: `.AVAssetExportPresetHighestQuality`, `.AVAssetExportPreset1920x1080`, etc.
- Progress via `exportSession.progress` KVO observation
- Output: MP4 with H.264/HEVC video, AAC audio

### Global Progress Stream (v1.2.0+)

When working with progress tracking:

- **Dart Side**: Events flow through `VVideoStreamManager.progressStream`
- **Native Side**: Emit events via EventChannel `v_video_compressor/progress`
- **Event Structure**: `{ progress: 0.0-1.0, videoPath?, currentIndex?, total?, compressionId? }`
- **Type Safety**: Always use `VVideoProgressEvent` for type-safe access
- **Broadcast Support**: Multiple listeners supported, stream auto-initializes on first listen

### Model Synchronization

When modifying data models, update **all three**:

1. `lib/src/v_video_models.dart` - Dart model with `toMap()`/`fromMap()`
2. `android/.../VVideoModels.kt` - Kotlin data class with `toMap()`/`fromMap()`
3. `ios/v_video_compressor/Sources/v_video_compressor/VVideoModels.swift` - Swift struct with dictionary conversion

**Example**: Adding a new compression parameter requires:

- Add to `VVideoAdvancedConfig` in all three files
- Update `toMap()` and `fromMap()` methods
- Update validation in `isValid()` method
- Update compression engines to handle new parameter

### Testing Approach

The plugin has comprehensive test coverage (95%+):

- `test/v_video_compressor_test.dart` - Core functionality tests
- `test/v_video_compressor_comprehensive_test.dart` - Edge cases and validation
- `test/v_video_compressor_method_channel_test.dart` - Platform channel tests
- `example/integration_test/` - Integration tests (requires device/simulator)

**Testing Strategy**:

1. Unit tests mock platform calls via `MethodChannelMock`
2. Integration tests verify actual compression on real videos
3. Model tests validate serialization/deserialization
4. Run `flutter test` to verify changes don't break existing functionality

### Logging System

Configure logging for different environments:

```dart
// Production: minimal logging
VVideoCompressor.configureLogging(VVideoLogConfig.production());

// Development: verbose logging
VVideoCompressor.configureLogging(VVideoLogConfig.development());

// Custom
VVideoCompressor.configureLogging(VVideoLogConfig(
  enabled: true,
  level: VVideoLogLevel.info,
  showProgress: true,
  showParameters: true,
));
```

When adding new methods:

- Use `VVideoLogger.methodCall()` at entry
- Use `VVideoLogger.success()` on completion
- Use `VVideoLogger.error()` for exceptions
- Use `VVideoLogger.progress()` for progress updates

## Important Implementation Notes

### Memory Management

Video compression is memory-intensive. Key considerations:

- **Android**: Media3 handles memory automatically, but large videos may cause OOM
- **iOS**: AVFoundation is memory-efficient, but 4K+ videos need optimization
- **Guidance**: See `MEMORY_OPTIMIZATION_GUIDE.md` for production best practices

### Orientation Handling (v1.1.0+)

The `autoCorrectOrientation` feature fixes vertical video issues:

- **Android**: Reads rotation metadata, applies transform in Media3
- **iOS**: Uses `AVAssetTrack.preferredTransform` to preserve orientation
- **Critical for**: Social media apps, mobile video capture

### Configuration Validation

All configurations validate at the Dart level before platform calls:

- `VVideoCompressionConfig.isValid()` - Checks base configuration
- `VVideoAdvancedConfig.isValid()` - Validates advanced parameters
- **Common Issues**: Resolution must be even numbers, rotation in [0,90,180,270], CRF 0-51

### Platform Channel Communication

Method calls use string-based channel names:

- `v_video_compressor` - Main MethodChannel
- `v_video_compressor/progress` - EventChannel for progress

**Adding New Methods**:

1. Define in `VVideoCompressorPlatform` interface
2. Implement in `MethodChannelVVideoCompressor`
3. Handle in native `VVideoCompressorPlugin` (both platforms)
4. Add corresponding native implementation

## Example App Structure

The `example/` app demonstrates all features:

- `main.dart` - Home screen with feature navigation
- `advanced_compression_page.dart` - Full configuration example
- `global_stream_example.dart` - Global progress stream demo
- `4k_test_page.dart` - High-resolution video testing
- `logging_example.dart` - Logging configuration examples

## Critical Files for Common Tasks

### Adding a Compression Parameter

1. `lib/src/v_video_models.dart` → `VVideoAdvancedConfig`
2. `android/.../VVideoModels.kt` → `VVideoAdvancedConfig`
3. `ios/v_video_compressor/Sources/v_video_compressor/VVideoModels.swift` → `VVideoAdvancedConfig`
4. `android/.../VVideoCompressionEngine.kt` → Apply parameter
5. `ios/v_video_compressor/Sources/v_video_compressor/VVideoCompressionEngine.swift` → Apply parameter

### Modifying Progress Tracking

1. `lib/src/v_video_stream_manager.dart` → Stream management
2. `lib/src/v_video_models.dart` → `VVideoProgressEvent`
3. `android/.../VVideoCompressorPlugin.kt` → EventChannel emission
4. `ios/v_video_compressor/Sources/v_video_compressor/VVideoCompressorPlugin.swift` → EventChannel emission

### Changing Compression Engine Logic

- **Android**: `VVideoCompressionEngine.kt` → `compressVideo()` method
- **iOS**: `VVideoCompressionEngine.swift` → `compressVideo()` method

### Adding Thumbnail Extraction Options

1. `lib/src/v_video_models.dart` → `VVideoThumbnailConfig`
2. Native implementations in both platforms
3. Update `getVideoThumbnail()` and `getVideoThumbnails()` methods

## Plugin Philosophy

This plugin is **focused exclusively** on video compression and thumbnails:

- **Does NOT**: Handle video selection (use `file_picker` or `image_picker`)
- **Does NOT**: Provide video playback (use `video_player`)
- **Does NOT**: Include UI components (developers build their own)

**Focus Areas**:

- Professional-grade compression quality
- Real-time progress with global stream access
- Advanced configuration for power users
- Production-ready error handling and logging
- Cross-platform consistency

## Version History

- **v1.2.1**: App Store compliance, iOS stability improvements
- **v1.2.0**: Global progress stream with full typing support
- **v1.1.0**: Added `autoCorrectOrientation` feature
- **v1.0.0**: Initial release with comprehensive compression

## Additional Resources

- `README.md` - User-facing documentation and API reference
- `MEMORY_OPTIMIZATION_GUIDE.md` - Production memory management
- `ADVANCED_FEATURES_SUPPORT.md` - Feature matrix and platform support
- `ANDROID_QUICK_FIX.md` - Android troubleshooting
- `IOS_QUICK_FIX.md` - iOS troubleshooting
