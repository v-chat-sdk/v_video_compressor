# V Video Compressor

[![pub package](https://img.shields.io/pub/v/v_video_compressor.svg)](https://pub.dev/packages/v_video_compressor)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue.svg)](https://flutter.dev)

A **professional Flutter plugin** for high-quality video compression with real-time progress tracking, thumbnail generation, and comprehensive configuration options.

## ✨ **Key Features**

- 🎬 **Professional Video Compression** - 5 quality levels with native platform APIs (Media3 for Android, AVFoundation for iOS)
- 📊 **Real-Time Progress Tracking** - Smooth progress updates with hybrid estimation algorithm
- 🌐 **Global Progress Stream** - NEW! Typed global stream accessible from anywhere in your app
- 🔧 **Advanced Configuration** - 20+ compression parameters for professional control
- 🖼️ **Thumbnail Generation** - Extract high-quality thumbnails at any timestamp
- 📱 **Cross-Platform** - Full Android & iOS support with hardware acceleration
- 🚀 **Batch Processing** - Compress multiple videos with overall progress tracking
- ⛔ **Cancellation Support** - Cancel operations anytime with automatic cleanup
- 📝 **Comprehensive Logging** - Production-ready error tracking and debugging
- 🧪 **Thoroughly Tested** - 95%+ test coverage with complete mock implementations
- ⚡ **No ffmpeg** - Uses native APIs for optimal performance and smaller app size

## 🎯 **Philosophy**

This plugin **focuses exclusively on video compression and thumbnail generation**. For video selection, use established plugins like [`image_picker`](https://pub.dev/packages/image_picker) or [`file_picker`](https://pub.dev/packages/file_picker).

## 📱 **Platform Support**

| Platform             | Support             | Minimum Version        | Notes                              |
| -------------------- | ------------------- | ---------------------- | ---------------------------------- |
| **Android**          | ✅ **Full Support** | API 21+ (Android 5.0+) | Hardware acceleration available    |
| **iOS (SwiftPM)**    | ✅ **Full Support** | iOS 15.0+              | Current Flutter toolchains         |
| **iOS (CocoaPods)**  | ✅ **Full Support** | iOS 12.0+              | Legacy Flutter toolchain metadata  |

## 🚀 **Quick Start**

### 1. Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  v_video_compressor: ^2.2.0
  file_picker: ^8.0.0 # For video selection
  # OR
  image_picker: ^1.0.7 # Alternative for video selection
```

### 2. Platform Setup

#### Android Setup

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```

#### iOS Setup

The plugin supports both CocoaPods and Swift Package Manager. Flutter selects
the configured dependency manager automatically. SwiftPM consumers must target
iOS 15.0 or newer to match Flutter's framework package. The CocoaPods metadata
retains iOS 12.0 for legacy Flutter toolchains; the effective minimum is the
highest requirement from the app, Flutter SDK, and plugin.

Add permissions to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photo library to compress videos</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs access to save compressed videos to photo library</string>
```

### 3. Basic Usage

```dart
import 'package:v_video_compressor/v_video_compressor.dart';
import 'package:file_picker/file_picker.dart';

class VideoCompressionExample extends StatefulWidget {
  @override
  _VideoCompressionExampleState createState() => _VideoCompressionExampleState();
}

class _VideoCompressionExampleState extends State<VideoCompressionExample> {
  final VVideoCompressor _compressor = VVideoCompressor();

  double _progress = 0.0;
  bool _isCompressing = false;

  Future<void> _compressVideo() async {
    // 1. Pick video using file_picker
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result == null || result.files.single.path == null) return;

    final videoPath = result.files.single.path!;

    setState(() {
      _isCompressing = true;
      _progress = 0.0;
    });

    try {
      // 2. Compress with progress tracking
      final compressionResult = await _compressor.compressVideo(
        videoPath,
        const VVideoCompressionConfig.medium(),
        onProgress: (progress) {
          setState(() => _progress = progress);
        },
      );

      if (compressionResult != null) {
        print('✅ Compression completed!');
        print('Original: ${compressionResult.originalSizeFormatted}');
        print('Compressed: ${compressionResult.compressedSizeFormatted}');
        print('Space saved: ${compressionResult.spaceSavedFormatted}');
        print('Output path: ${compressionResult.outputPath}');
      }
    } catch (e) {
      print('❌ Compression failed: $e');
    } finally {
      setState(() => _isCompressing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Compressor')),
      body: Center(
        child: _isCompressing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(value: _progress),
                  const SizedBox(height: 16),
                  Text('${(_progress * 100).toInt()}%'),
                ],
              )
            : ElevatedButton(
                onPressed: _compressVideo,
                child: const Text('Pick & Compress Video'),
              ),
      ),
    );
  }
}
```

## 🌐 **Global Progress Stream (NEW in v1.2.0)**

Listen to compression progress from anywhere in your app with the new **typed global stream**:

### Basic Global Stream Usage

```dart
import 'package:v_video_compressor/v_video_compressor.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<VVideoProgressEvent>? _progressSubscription;
  VVideoProgressEvent? _currentProgress;

  @override
  void initState() {
    super.initState();
    _setupGlobalProgressListener();
  }

  void _setupGlobalProgressListener() {
    // Listen to global progress stream from anywhere
    _progressSubscription = VVideoCompressor.progressStream.listen(
      (event) {
        setState(() {
          _currentProgress = event;
        });

        print('Progress: ${event.progressFormatted}');
        if (event.isBatchOperation) {
          print('Batch: ${event.batchProgressDescription}');
        }
      },
    );
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}
```

### Convenience Methods

```dart
// Method 1: Simple progress callback
VVideoCompressor.listenToProgress((progress) {
  print('Progress: ${(progress * 100).toInt()}%');
});

// Method 2: Batch progress callback
VVideoCompressor.listenToBatchProgress((progress, currentIndex, total) {
  print('Batch: Video ${currentIndex + 1}/$total - ${(progress * 100).toInt()}%');
});

// Method 3: Full event callback
VVideoCompressor.listen((event) {
  print('Progress: ${event.progressFormatted}');
  print('Video: ${event.videoPath}');
  if (event.isBatchOperation) {
    print('Batch: ${event.batchProgressDescription}');
  }
});
```

### Global Stream Benefits

- ✅ **Fully Typed**: No more `Map` checking - proper `VVideoProgressEvent` type
- ✅ **Global Access**: Listen from anywhere in your app (widgets, services, controllers)
- ✅ **Automatic Management**: Stream lifecycle handled automatically
- ✅ **Multiple Listeners**: Broadcast stream supports multiple listeners
- ✅ **Batch Support**: Built-in batch operation detection and progress
- ✅ **Rich Information**: Access to video path, progress, batch info, and formatted strings

### Use Cases

**In Services/Controllers:**

```dart
class VideoCompressionService {
  static StreamSubscription<VVideoProgressEvent>? _subscription;

  static void startGlobalListener() {
    _subscription = VVideoCompressor.progressStream.listen((event) {
      // Update your state management, emit to other streams, etc.
      print('Service: ${event.progressFormatted}');
    });
  }

  static void stopGlobalListener() {
    _subscription?.cancel();
  }
}
```

**With State Management:**

```dart
class VideoCompressionNotifier extends ChangeNotifier {
  VVideoProgressEvent? _currentProgress;

  VVideoProgressEvent? get currentProgress => _currentProgress;

  void startListening() {
    VVideoCompressor.progressStream.listen((event) {
      _currentProgress = event;
      notifyListeners(); // Notify UI to rebuild
    });
  }
}
```

**Multiple Widgets:**

```dart
// Widget A
class ProgressIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VVideoProgressEvent>(
      stream: VVideoCompressor.progressStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox();
        return LinearProgressIndicator(value: snapshot.data!.progress);
      },
    );
  }
}

// Widget B - completely separate
class ProgressText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VVideoProgressEvent>(
      stream: VVideoCompressor.progressStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Text('Ready');
        return Text(snapshot.data!.progressFormatted);
      },
    );
  }
}
```

## 🎯 **Quality Levels**

Choose the right quality for your use case:

| Quality                          | Resolution | Typical Bitrate | File Size  | Use Case                      |
| -------------------------------- | ---------- | --------------- | ---------- | ----------------------------- |
| `VVideoCompressQuality.high`     | 1080p HD   | 3.5 Mbps        | Larger     | Professional, archival        |
| `VVideoCompressQuality.medium`   | 720p       | 1.8 Mbps        | Balanced   | General purpose, social media |
| `VVideoCompressQuality.low`      | 480p       | 900 kbps        | Smaller    | Quick sharing, messaging      |
| `VVideoCompressQuality.veryLow`  | 360p       | 500 kbps        | Very small | Bandwidth limited             |
| `VVideoCompressQuality.ultraLow` | 240p       | 350 kbps        | Minimal    | Maximum compression           |

## 🔧 **Advanced Configuration**

### Custom Compression Settings

```dart
final advancedConfig = VVideoAdvancedConfig(
  // Resolution & Quality
  customWidth: 1280,
  customHeight: 720,
  videoBitrate: 2000000,        // 2 Mbps
  frameRate: 30.0,              // 30 FPS

  // Codec & Encoding
  videoCodec: VVideoCodec.h265, // Better compression
  audioCodec: VAudioCodec.aac,
  encodingSpeed: VEncodingSpeed.medium,
  crf: 25,                      // Quality factor (lower = better)
  twoPassEncoding: true,        // Better quality
  hardwareAcceleration: true,   // Use GPU

  // Audio Settings
  audioBitrate: 128000,         // 128 kbps
  audioSampleRate: 44100,       // 44.1 kHz
  audioChannels: 2,             // Stereo

  // Video Effects
  brightness: 0.1,              // Slight brightness boost
  contrast: 0.05,               // Slight contrast increase
  saturation: 0.1,              // Slight saturation increase

  // Editing
  trimStartMs: 2000,            // Skip first 2 seconds
  trimEndMs: 60000,             // End at 1 minute
  rotation: 90,                 // Rotate 90 degrees
);

final result = await _compressor.compressVideo(
  videoPath,
  VVideoCompressionConfig(
    quality: VVideoCompressQuality.medium,
    advanced: advancedConfig,
  ),
);
```

### Normalized Crop Coordinates

`VVideoCropRect` selects a real output region; it is not a preview scale or a
letterbox mask. Coordinates are normalized doubles in the inclusive `0.0..1.0`
space of the correctly displayed frame after source orientation metadata and
the requested `0`, `90`, `180`, or `270` degree rotation have been applied.
`left` and `top` are the starting edges and `right` and `bottom` are the ending
edges. Crop-aware rotation values follow `video_editor_3`: `90` is a left
(counter-clockwise) turn and `270` is a right (clockwise) turn.

A crop is valid only when every value is finite and:

- `0 <= left < right <= 1`
- `0 <= top < bottom <= 1`

Invalid values are rejected and are never clamped. `(0, 0, 1, 1)` is a
full-frame no-op; full-frame detection uses a `1e-6` tolerance only for
floating-point round-off.

```dart
const cropRect = VVideoCropRect(
  left: 0.0,
  top: 0.0,
  right: 0.5,
  bottom: 0.5,
);

if (!cropRect.isValid()) {
  throw ArgumentError('Invalid crop coordinates');
}

final result = await compressor.compressVideo(
  inputPath,
  const VVideoCompressionConfig(
    quality: VVideoCompressQuality.medium,
    advanced: VVideoAdvancedConfig(
      trimStartMs: 1000,
      trimEndMs: 5000,
      rotation: 90,
      cropRect: cropRect,
      videoCodec: VVideoCodec.h264,
    ),
  ),
);
```

The native export uses one encoding pass in this deterministic order:

1. Honor source orientation metadata.
2. Apply the requested discrete rotation.
3. Convert the normalized crop to oriented pixels and move it to `(0, 0)`.
4. Apply output sizing without stretching.
5. Encode and mux together with trimming and audio handling.

Coordinates exposed by `video_editor_3` can be mapped directly without adding
that package as a dependency of `v_video_compressor`:

```dart
final cropRect = VVideoCropRect(
  left: controller.minCrop.dx,
  top: controller.minCrop.dy,
  right: controller.maxCrop.dx,
  bottom: controller.maxCrop.dy,
);

final result = await compressor.compressVideo(
  inputPath,
  VVideoCompressionConfig(
    quality: quality,
    fallbackToOriginalIfNotSmaller: false,
    advanced: VVideoAdvancedConfig(
      trimStartMs: controller.startTrim.inMilliseconds,
      trimEndMs: controller.endTrim.inMilliseconds,
      rotation: controller.rotation,
      cropRect: cropRect,
      videoCodec: VVideoCodec.h264,
    ),
  ),
);
```

The example app also includes a focused **Crop, trim & rotate** screen. It uses
`video_trimmer` for the video preview and draggable trim timeline, then passes
the selected millisecond range into `VVideoAdvancedConfig`. The example never
calls `video_trimmer.saveTrimmedVideo`, so trim, crop, rotation, audio handling,
and compression still happen once through `v_video_compressor`.

For crop-aware exports, `autoAlign` chooses the largest aspect-preserving,
encoder-safe output inside the quality or custom bounds. `letterbox` is the
only mode that intentionally centers the crop in a larger canvas with bars.
`exact` accepts even custom dimensions only when they preserve the selected
crop aspect within one output pixel; incompatible or sub-`16x16` outputs are
rejected.

The integration suite includes deterministic quadrant fixtures and an opt-in
iOS network case. The network case downloads Flutter's public H.264/AAC
`bee.mp4` sample inside the simulator, then verifies crop, trim, audio,
dimensions, and playability:

```bash
cd example
flutter test integration_test \
  -d <ios-simulator-id> \
  --dart-define=VVC_RUN_NETWORK_INTEGRATION=true \
  --plain-name "downloads a public Flutter video and exports crop on iOS"
```

An additional opt-in iOS audit exercises every public compression setting and
prints machine-readable `PASS`, `FAIL`, or `UNSUPPORTED` results after
inspecting the encoded tracks and decoded thumbnails:

```bash
cd example
flutter test integration_test/ios_compression_feature_audit_test.dart \
  -d <ios-simulator-id> \
  --dart-define=VVC_RUN_IOS_FEATURE_AUDIT=true
```

### Guarantee an Encoded Output

By default, the plugin returns the original file when encoding saves less than
5% to avoid wasting storage. Disable that fallback when the requested codec or
container is required. The plugin automatically prohibits original-file
fallback whenever an effective crop, trim, nonzero rotation, custom size,
audio removal, or explicit codec request requires the encoded output. This
prevents a successful export from silently discarding edits.

```dart
final result = await _compressor.compressVideo(
  videoPath,
  const VVideoCompressionConfig.medium(
    fallbackToOriginalIfNotSmaller: false,
  ),
);

print('Original returned: ${result?.usedOriginalFile}');
```

### ID-Based Compression Tracking

Track compression operations with custom IDs for better monitoring:

```dart
// Compress with custom ID
final result = await _compressor.compressVideo(
  videoPath,
  const VVideoCompressionConfig.medium(),
  onProgress: (progress) {
    print('Compression progress: ${(progress * 100).toInt()}%');
  },
  id: 'my-video-compression-${DateTime.now().millisecondsSinceEpoch}',
);

// Or let the plugin auto-generate an ID
final result2 = await _compressor.compressVideo(
  videoPath,
  const VVideoCompressionConfig.medium(),
  onProgress: (progress) {
    print('Progress: ${(progress * 100).toInt()}%');
  },
  // No ID provided - will auto-generate one
);
```

**Benefits of ID-based tracking:**

- ✅ **Better Logging**: Each compression operation is logged with its unique ID
- ✅ **Tracking**: Monitor specific compression operations in your app
- ✅ **Debugging**: Easier to identify which compression operation failed
- ✅ **Analytics**: Track compression performance and success rates

### Preset Configurations

```dart
// Maximum compression for smallest files
final maxCompression = VVideoAdvancedConfig.maximumCompression(
  targetBitrate: 300000,  // 300 kbps
  keepAudio: false,       // Remove audio
);

// Social media optimized
final socialMedia = VVideoAdvancedConfig.socialMediaOptimized();

// Mobile optimized
final mobile = VVideoAdvancedConfig.mobileOptimized();

final result = await _compressor.compressVideo(
  videoPath,
  VVideoCompressionConfig(
    quality: VVideoCompressQuality.medium,
    advanced: maxCompression, // Use preset
  ),
);
```

### Advanced Configuration Options

The `VVideoAdvancedConfig` class provides fine-grained control over the compression process:

#### 🔄 **NEW: Automatic Orientation Correction**

```dart
// Fix for vertical videos appearing horizontal after compression
VVideoAdvancedConfig(
  autoCorrectOrientation: true,  // Preserves original video orientation
  videoBitrate: 1500000,
  audioBitrate: 128000,
)
```

**Key Features:**

- ✅ **Automatic Detection**: Detects original video orientation metadata
- ✅ **Vertical Video Fix**: Prevents vertical videos from appearing horizontal
- ✅ **Cross-Platform**: Works on both Android and iOS
- ✅ **No Quality Loss**: Maintains video quality while preserving orientation

#### 🎯 **NEW: Automatic Dimension Alignment (Issue #9 Fix)**

**Problem**: Compressed videos show colored/black smears along edges when input dimensions aren't divisible by 16 (encoder padding artifacts).

**Solution**: Automatic 16-pixel boundary alignment prevents encoder padding:

```dart
// These dimensions will automatically align to 16-pixel boundaries
VVideoAdvancedConfig(
  customWidth: 1082,   // Will align to 1072 (1072 % 16 == 0)
  customHeight: 1278,  // Will align to 1264 (1264 % 16 == 0)
  dimensionHandling: VDimensionHandling.autoAlign,  // Default: smart auto-detection
)
```

**Dimension Handling Options**:

```dart
enum VDimensionHandling {
  autoAlign,   // ✅ Default: Smart alignment, only aligns when needed
  letterbox,   // Adds black bars to maintain aspect ratio during alignment
  exact,       // Keep exact dimensions (may cause artifacts with odd dimensions)
}
```

**How It Works**:

| Input | Aligned | Notes |
|-------|---------|-------|
| 1920  | 1920    | Already 16-aligned, no change |
| 1080  | 1072    | Rounds down to prevent padding |
| 1082  | 1072    | Removes edge artifacts |
| 1278  | 1264    | Fixes chroma padding issues |
| 720   | 720     | Standard width, already aligned |

**Key Benefits**:

- ✅ **Fixes Edge Artifacts**: Eliminates colored/black smears on video edges
- ✅ **Transparent**: Auto-detects and applies only when needed
- ✅ **Cross-Platform**: Works on both Android and iOS
- ✅ **Smart Alignment**: Only adjusts dimensions not divisible by 16
- ✅ **Logging**: Logs dimension adjustments for debugging

#### Other Advanced Options

```dart
VVideoAdvancedConfig(
  videoBitrate: 1500000,        // Custom video bitrate
  audioBitrate: 128000,         // Custom audio bitrate
  customWidth: 1280,            // Custom width (use with height)
  customHeight: 720,            // Custom height (use with width)
  rotation: 90,                 // Manual rotation (0, 90, 180, 270)
  frameRate: 30.0,              // Target frame rate
  removeAudio: false,           // Remove audio track
  brightness: 0.1,              // Brightness adjustment (-1.0 to 1.0)
  contrast: 0.1,                // Contrast adjustment (-1.0 to 1.0)
  autoCorrectOrientation: true, // Auto-correct video orientation
  dimensionHandling: VDimensionHandling.autoAlign, // NEW: Auto-align dimensions to 16-pixel boundaries
  // ... other options
)
```

## 🖼️ **Thumbnail Generation**

### Single Thumbnail

```dart
final thumbnail = await _compressor.getVideoThumbnail(
  videoPath,
  VVideoThumbnailConfig(
    timeMs: 5000,                    // 5 seconds into video
    maxWidth: 300,
    maxHeight: 200,
    format: VThumbnailFormat.jpeg,
    quality: 85,                     // JPEG quality (0-100)
  ),
);

if (thumbnail != null) {
  print('Thumbnail: ${thumbnail.thumbnailPath}');
  print('Size: ${thumbnail.width}x${thumbnail.height}');
  print('File size: ${thumbnail.fileSizeFormatted}');
}
```

### Multiple Thumbnails

```dart
final thumbnails = await _compressor.getVideoThumbnails(
  videoPath,
  [
    VVideoThumbnailConfig(timeMs: 1000, maxWidth: 150),   // 1s
    VVideoThumbnailConfig(timeMs: 5000, maxWidth: 150),   // 5s
    VVideoThumbnailConfig(timeMs: 10000, maxWidth: 150),  // 10s
  ],
);

print('Generated ${thumbnails.length} thumbnails');
for (final thumbnail in thumbnails) {
  print('${thumbnail.timeMs}ms: ${thumbnail.thumbnailPath}');
}
```

## 📊 **Batch Processing**

Compress multiple videos with overall progress tracking:

```dart
final results = await _compressor.compressVideos(
  [videoPath1, videoPath2, videoPath3],
  const VVideoCompressionConfig.medium(),
  onProgress: (progress, currentIndex, total) {
    print('Overall: ${(progress * 100).toInt()}% (${currentIndex + 1}/$total)');
  },
);

print('Successfully compressed ${results.length} videos');
for (final result in results) {
  print('${result.originalPath} → ${result.outputPath}');
  print('Space saved: ${result.spaceSavedFormatted}');
}
```

## 🔍 **Video Information & Compression Estimation**

### Get Video Information

```dart
final videoInfo = await _compressor.getVideoInfo(videoPath);
if (videoInfo != null) {
  print('Duration: ${videoInfo.durationFormatted}');
  print('Resolution: ${videoInfo.width}x${videoInfo.height}');
  print('File size: ${videoInfo.fileSizeFormatted}');
}
```

### Estimate Compression Size

```dart
final estimate = await _compressor.getCompressionEstimate(
  videoPath,
  VVideoCompressQuality.medium,
  advanced: advancedConfig, // Optional
);

if (estimate != null) {
  print('Estimated size: ${estimate.estimatedSizeFormatted}');
  print('Compression ratio: ${(estimate.compressionRatio * 100).toInt()}%');
  print('Expected bitrate: ${estimate.bitrateMbps.toStringAsFixed(1)} Mbps');
}
```

## ⛔ **Cancellation Support**

Cancel operations anytime:

```dart
// Cancel ongoing compression
await _compressor.cancelCompression();

// Check if compression is running
final isActive = await _compressor.isCompressing();

// Handle cancellation in UI
if (isActive) {
  await _compressor.cancelCompression();
  // Files are automatically cleaned up
}
```

## 🧹 **Resource Management**

### Complete Cleanup

```dart
// Clean everything when app closes
@override
void dispose() {
  _compressor.cleanup();
  super.dispose();
}
```

### Selective Cleanup

```dart
// Safe cleanup - keep compressed videos
await _compressor.cleanupFiles(
  deleteThumbnails: true,
  deleteCompressedVideos: false,  // Keep compressed videos
  clearCache: true,
);

// Full cleanup - ⚠️ removes all compressed videos
await _compressor.cleanupFiles(
  deleteThumbnails: true,
  deleteCompressedVideos: true,   // ⚠️ This deletes your videos!
  clearCache: true,
);
```

## 📝 **Complete API Reference**

### Core Methods

```dart
// Video information
Future<VVideoInfo?> getVideoInfo(String videoPath);

// Compression estimation
Future<VVideoCompressionEstimate?> getCompressionEstimate(
  String videoPath,
  VVideoCompressQuality quality,
  {VVideoAdvancedConfig? advanced}
);

// Single video compression
Future<VVideoCompressionResult?> compressVideo(
  String videoPath,
  VVideoCompressionConfig config,
  {Function(double progress)? onProgress, String? id}
);

// Batch compression
Future<List<VVideoCompressionResult>> compressVideos(
  List<String> videoPaths,
  VVideoCompressionConfig config,
  {Function(double progress, int currentIndex, int total)? onProgress}
);

// Control operations
Future<void> cancelCompression();
Future<bool> isCompressing();
```

### Thumbnail Methods

```dart
// Single thumbnail
Future<VVideoThumbnailResult?> getVideoThumbnail(
  String videoPath,
  VVideoThumbnailConfig config
);

// Multiple thumbnails
Future<List<VVideoThumbnailResult>> getVideoThumbnails(
  String videoPath,
  List<VVideoThumbnailConfig> configs
);
```

### Cleanup Methods

```dart
// Complete cleanup
Future<void> cleanup();

// Selective cleanup
Future<void> cleanupFiles({
  bool deleteThumbnails = true,
  bool deleteCompressedVideos = false,
  bool clearCache = true,
});
```

## 🚫 **Error Handling**

The plugin provides comprehensive error handling and logging:

```dart
try {
  final result = await _compressor.compressVideo(videoPath, config);
  if (result == null) {
    print('Compression failed - check logs for details');
  }
} catch (e, stackTrace) {
  print('Error: $e');
  print('Stack trace: $stackTrace');

  // The plugin automatically logs detailed error information
  // Check your development console for full context
}
```

## 📱 **Platform-Specific Notes**

### Android

- **Minimum API**: Android 5.0 (API 21)
- **Hardware Acceleration**: Available on most devices with Media3
- **Permissions**: Automatically handled for Android 13+
- **Background**: Full background compression support

### iOS

- **Minimum Version**: iOS 11.0
- **Hardware Acceleration**: Available with AVFoundation
- **Simulator**: Limited acceleration (test on devices for best results)
- **Background**: May be limited by iOS background execution policies

## 🔧 **Troubleshooting**

### Common Issues

**1. Compression fails silently**

- Check file permissions and paths
- Verify video file is not corrupted
- Check device storage space

**2. Progress not updating**

- Ensure you're calling `setState()` in progress callback
- Check if compression is actually running with `isCompressing()`

**3. iOS simulator issues**

- Hardware acceleration unavailable in simulator
- Test on physical iOS devices for accurate results

**4. Large file handling**

- Very large files (>4GB) may require more memory
- Consider using lower quality settings for large files

### Debug Logging

The plugin provides comprehensive logging:

```dart
// Logs are automatically output to console with tag 'VVideoCompressor'
// Filter logs by tag to see only plugin-related messages
```

## 🎨 **Example Projects**

Check the [example directory](example/) for complete sample applications:

- **Basic compression** with progress tracking
- **Advanced configuration** examples
- **Thumbnail generation** demos
- **Batch processing** implementation
- **UI integration** patterns

## 📚 **Additional Resources**

- **[API Documentation](https://pub.dev/documentation/v_video_compressor)** - Complete API reference
- **[Memory Optimization Guide](MEMORY_OPTIMIZATION_GUIDE.md)** - Critical for production apps
- **[Advanced Features Guide](ADVANCED_FEATURES_SUPPORT.md)** - Detailed feature matrix
- **[Android Quick Fix Guide](ANDROID_QUICK_FIX.md)** - Android-specific issues
- **[iOS Quick Fix Guide](IOS_QUICK_FIX.md)** - iOS-specific issues

## ⚠️ **Important Notes**

### Memory Management

Video compression is memory-intensive. For production apps, please read our [Memory Optimization Guide](MEMORY_OPTIMIZATION_GUIDE.md) to avoid OutOfMemoryError issues. Key recommendations:

- Always check available memory before compression
- Use lower quality settings for devices with < 2GB RAM
- Implement progressive quality fallback
- Process videos in batches for bulk operations

## 🤝 **Contributing**

We welcome contributions! Please see the [repository guidelines](AGENTS.md) for
the project layout, validation commands, and pull request expectations.

### Development Setup

```bash
git clone https://github.com/v-chat-sdk/v_video_compressor.git
cd v_video_compressor
flutter pub get
cd example && flutter pub get
```

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 **Support**

- **Issues**: [GitHub Issues](https://github.com/v-chat-sdk/v_video_compressor/issues)
- **Discussions**: [GitHub Discussions](https://github.com/v-chat-sdk/v_video_compressor/discussions)
- **Documentation**: [pub.dev](https://pub.dev/packages/v_video_compressor)

---

**Made with ❤️ for the Flutter community**
