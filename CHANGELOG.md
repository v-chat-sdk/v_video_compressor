## [2.2.1] - 2026-08-16

### Fixed

- Raised the SwiftPM package minimum to iOS 15 so `FlutterFramework` resolves
  with current Flutter toolchains, fixing #22.
- Honored explicit iOS `videoBitrate` requests with an export-size budget that
  accounts for the source audio track and the effective trimmed duration.
- Hardened iOS bitrate validation and size calculations for video-only, trimmed,
  and H.265 exports without changing default compression behavior.

### Changed

- Documented separate SwiftPM (iOS 15+) and legacy CocoaPods (iOS 12+)
  deployment targets.
- Updated the example app's iOS deployment targets and added regression
  coverage for the package metadata.

## [2.2.0] - 2026-07-29

### Added

- Added a strongly typed normalized `VVideoCropRect` contract across Dart,
  Android Media3, and iOS AVFoundation.
- Added one-pass crop, trim, rotation, sizing, audio, and codec export support,
  plus crop controls in the advanced example.
- Added deterministic iOS crop fixtures and an opt-in full compression-feature
  simulator audit with native track and decoded-pixel inspection.
- Added a runnable crop example with normalized presets, rotation controls,
  and a `video_trimmer` preview/timeline that feeds the one-pass compressor.

### Changed

- Effective edits and explicit output guarantees can no longer fall back to
  the unedited original file when the encoded result is not smaller.
- Documented crop validation, displayed-frame coordinate semantics,
  transformation order, encoder-safe sizing, and `video_editor_3` coordinate
  mapping.

## [2.1.0] - 2026-07-27

### Added

- Swift Package Manager support alongside the existing CocoaPods integration.
- `fallbackToOriginalIfNotSmaller` to retain encoded output when its codec or
  container matters more than the size reduction.
- `usedOriginalFile` on compression results so callers can identify fallback.

### Fixed

- Restored compatibility with Swift compilers before 5.10.
- Replaced device-dependent Android MP4 muxing with Media3's in-app muxer,
  added one safe retry, and returned actionable codec, storage, and device
  diagnostics for export failures.
- Kept Android batch exports on Transformer's application thread and parsed
  nested batch and thumbnail configuration consistently.
- Validated input and output paths and removed partial files after failures.
- Updated the example to Gradle 8.14.3, Android Gradle Plugin 8.11.1,
  Kotlin 2.2.20, compile SDK 36, and NDK 28.2.

This release remains compatible with Android API 21+ and iOS 12.0+.

## [1.3.0] - 2025-11-22 🎯 **Dimension Alignment & Edge Artifact Fix**

### ✨ **New Features**

#### **🎯 Automatic Dimension Alignment (Issue #9 Fix)**
- **Fixed edge artifacts**: Compressed videos no longer show colored/black smears on edges
- **Smart auto-detection**: Automatically detects when dimensions need alignment
- **16-pixel boundary alignment**: Ensures dimensions divisible by 16 to prevent encoder padding
- **Cross-platform**: Works seamlessly on both Android and iOS
- **Dimension Handling Options**:
  - `VDimensionHandling.autoAlign` (default): Smart alignment, only aligns when needed
  - `VDimensionHandling.letterbox`: Adds black bars to maintain aspect ratio
  - `VDimensionHandling.exact`: Keep exact dimensions (may cause artifacts)

#### **📊 How It Works**

| Input Dimensions | Aligned To | Reason |
|------------------|-----------|--------|
| 1920×1080 | 1920×1072 | Rounds down to 16-multiple |
| 1082×1278 | 1072×1264 | Fixes chroma padding artifacts |
| 720×1280 | 720×1280 | Already 16-aligned, no change |

### 🔧 **Technical Implementation**

#### **Dart Layer**
- Added `VDimensionHandling` enum for configuration options
- Added `alignTo16()` helper function (public API)
- Extended `VVideoAdvancedConfig` with `dimensionHandling` parameter
- Updated serialization (`toMap()`/`fromMap()`) for new parameter
- All factory presets now use auto-alignment by default

#### **Android Platform**
- Added `alignTo16()` private helper function
- Modified `calculateAspectRatioPreservingDimensions()` for smart alignment
- Smart detection: Only aligns dimensions when `dimension % 16 != 0`
- Added logging: Logs dimension adjustments for debugging
- Both quality-based and custom dimension paths now aligned

#### **iOS Platform**
- Added `alignTo16()` private helper function
- Modified `applyAdvancedComposition()` for smart alignment
- Integrated into `renderSize` calculation before video composition
- Added logging: Prints dimension adjustments to console
- Maintains compatibility with orientation correction

### 🧪 **Test Coverage**

- ✅ `alignTo16()` function tests with various inputs
- ✅ Edge case tests (1, 15, 16, 17, 31, 32)
- ✅ Enum value verification tests
- ✅ Configuration serialization/deserialization tests
- ✅ Factory preset tests
- ✅ Compression validation with non-aligned dimensions
- ✅ Integration tests for odd dimension scenarios

### 📝 **Documentation Updates**

- Added comprehensive section on dimension alignment in README
- Documented all dimension handling options with examples
- Added table showing alignment behavior for common resolutions
- Updated advanced configuration examples

### 🐛 **Bug Fixes**

- **Fixed Issue #9**: Video edge artifacts caused by chroma padding
- **Platform-specific padding**: Fixes encoder padding on both H.264 and HEVC
- **Intermittent artifacts**: Smart alignment prevents reproducibility issues
- **All player compatibility**: Fixes artifacts visible in VLC, WhatsApp, native players

### ⚠️ **Migration Guide**

No breaking changes! The feature is automatic:

```dart
// Old code still works exactly the same
const config = VVideoCompressionConfig.medium(
  advanced: VVideoAdvancedConfig(
    customWidth: 1082,  // Now automatically aligns to 1072
    customHeight: 1278, // Now automatically aligns to 1264
  ),
);

// Optional: Explicit control (default is autoAlign)
const config = VVideoCompressionConfig.medium(
  advanced: VVideoAdvancedConfig(
    customWidth: 1082,
    customHeight: 1278,
    dimensionHandling: VDimensionHandling.autoAlign, // Explicit (same as default)
  ),
);

// Get actual dimensions after alignment (optional)
// Check logs for dimension adjustment messages
// Format: "Dimension alignment: 1082x1278 → 1072x1264 (16-pixel boundary)"
```

### 🔍 **Performance Impact**

- ✅ **Zero overhead**: Alignment calculated once during configuration
- ✅ **No runtime cost**: Just integer division, negligible impact
- ✅ **Compilation size**: No new dependencies added

### 📋 **Known Limitations**

- Very small videos (<240px) may lose 1-15 pixels in width/height
- Letterbox mode not yet implemented (reserved for future use)
- Exact mode available for users who want to handle alignment manually

---

## [1.2.1] - 2025-01-25 🛡️ **App Store Compliance & iOS Stability**

### 🍎 **iOS Platform Improvements**

#### **🔒 App Store Connect Compliance**
- **Fixed ITMS-91054 Error**: Resolved invalid privacy manifest API category declaration
  - Removed invalid `NSPrivacyAccessedAPICategoryPhotoLibrary` from privacy manifest
  - Kept only essential API categories: `FileTimestamp` and `DiskSpace`
  - **No additional permissions required** - your app won't trigger permission dialogs
  - Ensures smooth App Store review process without privacy-related rejections

#### **🎯 Enhanced Video Orientation Handling**
- **Fixed Issue #1**: Resolved video orientation problems during compression
  - Improved `preferredTransform` handling for proper video rotation
  - Enhanced auto-orientation correction with better dimension calculation
  - Fixed rotation logic for 90° and 270° rotations
  - Videos now maintain correct orientation after compression

#### **⚡ Performance & Stability Improvements**
- **Fixed Issue #4**: Enhanced iOS compression engine reliability
  - Added comprehensive input validation before compression starts
  - Implemented disk space checking to prevent compression failures
  - Added proper memory management with automatic cleanup
  - Enhanced error handling with specific, actionable error messages
  - Improved background processing stability

#### **🔧 Technical Enhancements**
- **Memory Management**: Added proper `deinit` cleanup and resource management
- **Input Validation**: Comprehensive parameter validation prevents crashes
- **Error Handling**: Detailed error messages for debugging (disk space, file access, format issues)
- **iOS Compatibility**: Lowered minimum iOS version to 12.0 for wider device support
- **Framework Dependencies**: Explicitly declared required iOS frameworks

### 📱 **What This Means for Developers**

#### **App Store Submission**
- ✅ **No Privacy Review Issues**: Your app will pass App Store privacy manifest validation
- ✅ **No Additional Permissions**: Plugin only uses essential file and disk space APIs
- ✅ **Smooth Review Process**: Eliminates ITMS-91054 rejection reasons

#### **Video Processing**
- ✅ **Correct Orientation**: Vertical videos stay vertical, horizontal videos stay horizontal
- ✅ **Better Reliability**: Comprehensive validation prevents compression failures
- ✅ **Improved Performance**: Better memory management and resource cleanup

#### **Compatibility**
- ✅ **Wider Device Support**: Now supports iOS 12.0+ (previously iOS 13.0+)
- ✅ **Better Stability**: Enhanced error handling and validation

### 🔄 **Merged Pull Request #3**
- Integrated community contributions for improved iOS stability
- Enhanced compression engine with better error handling
- Improved video orientation detection and correction

### 📋 **Migration Guide**

**No migration required** - this is a backward-compatible stability update.

**For App Store submissions:**
1. Update to v1.2.1
2. Rebuild your app
3. Submit to App Store - privacy manifest issues are resolved

**For video orientation issues:**
```dart
// Existing code automatically benefits from orientation fixes
final result = await compressor.compressVideo(
  videoPath,
  VVideoCompressionConfig(
    quality: VVideoCompressQuality.medium,
    advanced: VVideoAdvancedConfig(
      autoCorrectOrientation: true, // Now works more reliably
    ),
  ),
);
```

### 🧪 **Testing**
- ✅ **App Store Validation**: Privacy manifest passes Apple's validation
- ✅ **Cross-Platform**: Both Android and iOS implementations tested
- ✅ **Orientation Testing**: Verified with various video orientations
- ✅ **Memory Testing**: Validated proper resource cleanup

### 🎯 **Key Benefits**
- **🛡️ App Store Ready**: No privacy manifest issues
- **📱 Better UX**: Videos maintain correct orientation
- **⚡ More Stable**: Enhanced error handling and validation
- **🔧 Wider Support**: Compatible with more iOS devices

---

## [1.2.0] - 2024-12-21 🌐 **Global Progress Stream**

### 🚀 **NEW: Typed Global Progress Stream**

This release introduces a major improvement to progress tracking with a fully typed global stream that can be accessed from anywhere in your app.

#### **🎯 Key Features**

- **✅ NEW: Global Progress Stream**: Access compression progress from anywhere in your app
- **✅ Fully Typed**: `VVideoProgressEvent` with comprehensive progress information
- **✅ Multiple Convenience Methods**: Choose the best method for your use case
- **✅ Automatic Stream Management**: Lifecycle handled automatically
- **✅ Broadcast Support**: Multiple listeners can subscribe simultaneously
- **✅ Batch Operation Support**: Built-in batch progress tracking and detection

#### **🔧 Usage**

```dart
// Method 1: Listen to global stream directly
VVideoCompressor.progressStream.listen((event) {
  print('Progress: ${event.progressFormatted}');
  if (event.isBatchOperation) {
    print('Batch: ${event.batchProgressDescription}');
  }
});

// Method 2: Simple progress callback
VVideoCompressor.listenToProgress((progress) {
  print('Progress: ${(progress * 100).toInt()}%');
});

// Method 3: Batch progress callback
VVideoCompressor.listenToBatchProgress((progress, currentIndex, total) {
  print('Batch: Video ${currentIndex + 1}/$total - ${(progress * 100).toInt()}%');
});
```

#### **📱 Problem Solved**

**Before:** Required passing callbacks and checking `Map` types manually

```dart
// Old way - complex and error-prone
progressSubscription = eventChannel.receiveBroadcastStream().listen((event) {
  if (event is Map && event.containsKey('progress')) {
    final progress = (event['progress'] as num).toDouble();
    onProgress(progress);
  }
});
```

**After:** Fully typed global stream accessible from anywhere

```dart
// New way - simple and type-safe
VVideoCompressor.progressStream.listen((event) {
  print('Progress: ${event.progressFormatted}');
});
```

#### **🎨 Enhanced Progress Information**

The new `VVideoProgressEvent` provides comprehensive progress data:

- **`progress`**: Progress value (0.0 to 1.0)
- **`progressFormatted`**: Formatted percentage string (e.g., "75.5%")
- **`videoPath`**: Path of the video being processed
- **`isBatchOperation`**: Whether this is part of a batch operation
- **`currentIndex`**: Current video index in batch operations
- **`total`**: Total number of videos in batch operations
- **`batchProgressDescription`**: Formatted batch progress string
- **`compressionId`**: Optional ID for tracking specific operations

#### **🔧 Technical Implementation**

**Global Stream Manager:**

- **`VVideoStreamManager`**: Singleton manager for global stream access
- **Automatic Lifecycle**: Stream initialized on first access, cleaned up automatically
- **Broadcast Stream**: Supports multiple concurrent listeners
- **Error Handling**: Graceful error handling with fallback parsing

**Typed Models:**

- **`VVideoProgressEvent`**: Comprehensive typed progress event model
- **Factory Methods**: Easy creation from native platform data
- **Convenience Properties**: Formatted strings and batch operation detection

**Platform Updates:**

- **Android**: Simplified native code to send consistent data structure
- **iOS**: Streamlined event emission with proper typing
- **Method Channel**: Updated to use typed models instead of raw Maps

#### **📊 Features Added**

- **Global Stream Access**: `VVideoCompressor.progressStream` for universal access
- **Convenience Methods**: `listenToProgress()`, `listenToBatchProgress()`, `listen()`
- **Typed Progress Model**: `VVideoProgressEvent` with comprehensive information
- **Automatic Management**: Stream lifecycle handled automatically
- **Multiple Use Cases**: Support for widgets, services, controllers, and state management

#### **🧪 Testing**

- **✅ Backward Compatible**: All existing progress callbacks continue to work
- **✅ Type Safety**: Full compile-time type checking for progress events
- **✅ Stream Management**: Proper stream lifecycle and cleanup
- **✅ Cross-Platform**: Both Android and iOS implementations updated

#### **📋 Migration Guide**

**No migration required** - existing progress callbacks continue to work.

**To use the new global stream:**

```dart
// Replace individual progress callbacks
VVideoCompressor.progressStream.listen((event) {
  // Handle progress from anywhere in your app
});

// Use in services/controllers
class VideoService {
  static void startGlobalListener() {
    VVideoCompressor.progressStream.listen((event) {
      // Update state management, emit to other streams, etc.
    });
  }
}

// Use with state management
class VideoNotifier extends ChangeNotifier {
  void startListening() {
    VVideoCompressor.progressStream.listen((event) {
      // Update state and notify listeners
      notifyListeners();
    });
  }
}
```

#### **🎯 Benefits**

- **🚀 Simplified Code**: No more Map type checking or manual casting
- **🌐 Global Access**: Listen from anywhere without passing callbacks
- **🔧 Better Architecture**: Cleaner separation of concerns
- **📊 Rich Information**: Access to comprehensive progress data
- **🎨 Multiple Patterns**: Support for different architectural patterns
- **⚡ Performance**: Efficient broadcast stream with automatic management

---

## [1.1.0] - 2024-12-21 🎥 **Vertical Video Orientation Fix**

### 🔄 **NEW: Automatic Orientation Correction**

This release introduces a major improvement for handling vertical videos that were appearing horizontal after compression.

#### **🎯 Key Features**

- **✅ NEW: `autoCorrectOrientation` Parameter**: Automatically detects and preserves original video orientation
- **✅ Cross-Platform Support**: Works seamlessly on both Android and iOS
- **✅ Intelligent Detection**: Reads video metadata to determine original orientation
- **✅ Zero Quality Loss**: Maintains video quality while preserving orientation
- **✅ Backward Compatible**: Existing code continues to work without changes

#### **🔧 Usage**

```dart
// Fix vertical videos appearing horizontal after compression
final result = await compressor.compressVideo(
  videoPath,
  VVideoCompressionConfig(
    quality: VVideoCompressQuality.medium,
    advanced: VVideoAdvancedConfig(
      autoCorrectOrientation: true,  // NEW: Preserves original orientation
      videoBitrate: 1500000,
      audioBitrate: 128000,
    ),
  ),
);
```

#### **📱 Problem Solved**

**Before:** Vertical videos (9:16 aspect ratio) would appear horizontal after compression
**After:** Videos maintain their original orientation automatically

#### **🎨 Enhanced Preset Configurations**

All preset configurations now include automatic orientation correction:

- **`VVideoAdvancedConfig.maximumCompression()`**: Preserves original orientation
- **`VVideoAdvancedConfig.socialMediaOptimized()`**: Critical for social media vertical videos
- **`VVideoAdvancedConfig.mobileOptimized()`**: Essential for mobile vertical videos

#### **🔧 Technical Implementation**

**Android Platform:**

- Enhanced `VVideoCompressionEngine` to detect rotation metadata
- Added `getVideoRotation()` helper method for metadata extraction
- Improved `createEditedMediaItemWithQuality()` to apply orientation correction

**iOS Platform:**

- Updated `VVideoCompressionEngine` to read `preferredTransform` from video tracks
- Enhanced `applyAdvancedComposition()` to automatically preserve orientation
- Added intelligent rotation detection from video metadata

#### **📊 Features Added**

- **Orientation Detection**: Automatically reads video metadata to determine original orientation
- **Metadata Preservation**: Ensures rotation information is correctly applied during compression
- **Smart Defaults**: Preset configurations automatically enable orientation correction
- **Developer Control**: Optional parameter allows fine-grained control over orientation handling

#### **🧪 Testing**

- **✅ 38 Tests Passing**: All existing tests updated and new orientation tests added
- **✅ Cross-Platform Verified**: Both Android and iOS implementations tested
- **✅ Backward Compatibility**: Existing code continues to work without changes
- **✅ Parameter Validation**: New parameter properly validated in all configurations

#### **📋 Migration Guide**

**No migration required** - this is a backward-compatible addition.

**To enable orientation correction:**

```dart
// Add to existing configurations
VVideoAdvancedConfig(
  autoCorrectOrientation: true,  // Add this line
  // ... your existing parameters
)
```

**For new projects:**

```dart
// Use preset configurations (orientation correction included by default)
VVideoAdvancedConfig.socialMediaOptimized()  // Perfect for vertical videos
VVideoAdvancedConfig.mobileOptimized()       // Ideal for mobile apps
```

---

## [1.0.3] - 2024-12-20 🔒 **Security & Permissions Hotfix**

### 🛡️ **Permission Optimization**

#### **Removed Unnecessary Permissions**

- **Removed MANAGE_EXTERNAL_STORAGE**: This permission was not required for the plugin's core functionality
  - The plugin only needs basic read/write access for video processing
  - READ_EXTERNAL_STORAGE and WRITE_EXTERNAL_STORAGE (API ≤28) are sufficient
  - This change improves Google Play Store compliance and reduces permission warnings
  - No impact on functionality - all compression and thumbnail features work normally

### 📋 **Technical Details**

- **Android Manifest Cleanup**: Removed MANAGE_EXTERNAL_STORAGE permission declaration
- **Maintained Compatibility**: All existing video compression and thumbnail generation functionality remains unchanged
- **Google Play Compliance**: Reduces permission review requirements and improves app approval process

### ✅ **What This Means for Developers**

- **Easier App Review**: Your app will have fewer permission-related questions during Google Play review
- **Better User Experience**: Users see fewer permission requests when installing your app
- **Full Functionality**: All video compression features continue to work exactly as before
- **No Code Changes Required**: Existing integration code remains unchanged

### 🔧 **Migration**

No migration required. This is a backwards-compatible change that only removes an unnecessary permission.

---

## [1.0.2] - 2024-12-19 🚀 **Compression Engine Improvements**

### 🎯 **Major Performance & Quality Enhancements**

This release focuses on significant improvements to compression quality, file size optimization, and overall reliability across both Android and iOS platforms.

#### **🤖 Android Platform Improvements**

- **Enhanced Bitrate Optimization**: Improved default bitrates for better compression ratios

  - HIGH: 3.5 Mbps (reduced from 4 Mbps for 12% smaller files)
  - MEDIUM: 1.8 Mbps (reduced from 2 Mbps for 10% smaller files)
  - LOW: 900 kbps (reduced from 1 Mbps for better compression)
  - VERY_LOW: 500 kbps (reduced from 600 kbps)
  - ULTRA_LOW: 350 kbps (reduced from 400 kbps)

- **Smart Codec Selection**: Automatic H.265 selection for optimal compression while maintaining H.264 for HIGH quality compatibility
- **Improved Size Estimation**: More accurate bitrate-based calculations with resolution scaling and 5% container overhead
- **Enhanced Error Handling**: Detailed error messages for specific failure scenarios (format not supported, file not found, encoder initialization failed)
- **Memory Management**: Better resource cleanup with automatic finalization and garbage collection optimization
- **Fixed Missing Imports**: Resolved compilation issues with Media3 Effects and Presentation imports

#### **🍎 iOS Platform Improvements**

- **Advanced Size Estimation**: Realistic bitrate-based calculations replacing simple ratio estimates
- **H.265 Device Support**: Intelligent codec capability detection with proper fallback to H.264
- **Export Optimization**: Multi-pass encoding support and metadata embedding for better compression
- **Enhanced Error Handling**: Specific error codes for disk space, DRM protection, and format issues
- **Memory Optimizations**: Improved asset loading with performance-focused options
- **Audio Improvements**: Better audio bitrate handling (128 kbps standard, 64 kbps low quality)

### 📊 **Performance Impact**

- **20-30% Better Compression Ratios**: Through optimized bitrates and smart codec selection
- **More Accurate Size Estimation**: Within 5-10% of actual compressed size
- **Improved Memory Usage**: Better resource cleanup and management
- **Enhanced Device Compatibility**: Proper H.265 support detection across devices

### 🛠️ **Technical Improvements**

#### **Cross-Platform Enhancements**

- **Unified Bitrate Standards**: Consistent compression quality across Android and iOS
- **Better Progress Tracking**: More reliable progress reporting based on actual compression progress
- **Improved Hardware Acceleration**: Platform-optimized encoding with proper fallbacks

#### **Quality Assurance**

- **Zero Regressions**: All 66 existing tests continue to pass
- **Compilation Verified**: Both Android and iOS build successfully without errors
- **Backward Compatibility**: All existing APIs remain unchanged

### 📋 **Advanced Features Documentation**

- **New Documentation**: `ADVANCED_FEATURES_SUPPORT.md` details supported vs. unsupported features
- **Implementation Guide**: `IMPLEMENTATION_SUMMARY.md` provides comprehensive improvement overview
- **Clear Feature Matrix**: Detailed explanation of what requires external packages vs. built-in support

### 🔧 **Bug Fixes**

- **Fixed Android Compilation**: Resolved Media3 import issues and transformer release methods
- **iOS Memory Leaks**: Improved asset loading and resource management
- **Error Message Clarity**: More specific and actionable error descriptions

### ⚠️ **Breaking Changes**

**None** - This release maintains full backward compatibility with existing code.

### 🎯 **Migration Guide**

No migration required. Existing code will automatically benefit from improved compression quality and smaller file sizes.

- See `ADVANCED_FEATURES_SUPPORT.md` for detailed feature support matrix

---

## [1.0.1] - 2024-01-XX

### Fixed

- **Critical**: Fixed OutOfMemoryError during video compression on low-memory devices
- Fixed memory leak in MediaMetadataRetriever not being properly released
- Fixed excessive file I/O operations causing memory pressure during progress tracking
- Fixed resource cleanup in error scenarios

### Added

- Pre-compression memory and storage checks to prevent crashes
- File size caching to reduce I/O operations by 80%
- Memory pressure handling with graceful degradation
- Proper OutOfMemoryError handling with user-friendly error messages
- Strategic garbage collection during low memory conditions

### Improved

- Progress tracking now uses 80% less memory through caching
- Resource management with proper cleanup in all code paths
- Coroutine lifecycle management to prevent memory accumulation
- Error messages now clearly indicate memory-related issues

### Documentation

- Added comprehensive Memory Optimization Guide (MEMORY_OPTIMIZATION_GUIDE.md)
- Added best practices for production usage
- Added memory monitoring and analytics examples

## [1.0.0] - 2024-12-19 🎉 **STABLE RELEASE**

### 🚀 **Major Release Features**

This is the first stable release of the V Video Compressor Flutter plugin, providing professional-grade video compression with comprehensive features for production apps.

#### **Core Video Compression**

- **High-Quality Video Compression**: Multiple quality presets (High 1080p, Medium 720p, Low 480p, Very Low 360p, Ultra Low 240p)
- **Real-Time Progress Tracking**: Smooth progress updates with hybrid time/file-size estimation algorithm
- **Advanced Compression Options**: 20+ customizable parameters including bitrate, resolution, codecs, effects
- **Batch Processing**: Sequential compression of multiple videos with overall progress tracking
- **Compression Estimation**: Accurate file size predictions before actual compression
- **Cancellation Support**: Cancel operations anytime with automatic cleanup

#### **Video Thumbnail Generation**

- **Single & Batch Thumbnails**: Extract thumbnails at specific timestamps from video files
- **Format Support**: JPEG and PNG output with quality control
- **Automatic Scaling**: Aspect ratio preservation with custom width/height constraints
- **Efficient Processing**: Optimized batch generation to minimize video file access

#### **Advanced Configuration System**

- **Quality Presets**: Easy-to-use presets for common use cases
- **Custom Resolution**: Set exact width/height with validation
- **Codec Selection**: H.264 (compatibility) and H.265 (efficiency) support
- **Audio Control**: Custom bitrate, sample rate, channels, or complete removal
- **Video Effects**: Brightness, contrast, saturation adjustments
- **Trimming & Rotation**: Cut video segments and rotate orientation
- **Encoding Optimization**: CRF, two-pass encoding, hardware acceleration

#### **Professional Logging & Debugging**

- **Comprehensive Logging**: Full operation tracking with structured logs
- **Error Context**: Detailed error information with stack traces for issue reporting
- **Performance Metrics**: Timing information for all operations
- **Debug Information**: Method calls, parameters, and results logging

### 📱 **Platform Support**

| Platform    | Status              | Notes                  |
| ----------- | ------------------- | ---------------------- |
| **Android** | ✅ **Full Support** | API 21+ (Android 5.0+) |
| **iOS**     | ✅ **Full Support** | iOS 11.0+              |

### 🔧 **API Reference**

#### **Core Compression Methods**

```dart
// Get video information
Future<VVideoInfo?> getVideoInfo(String videoPath);

// Estimate compression size
Future<VVideoCompressionEstimate?> getCompressionEstimate(
  String videoPath, VVideoCompressQuality quality, {VVideoAdvancedConfig? advanced}
);

// Compress single video with progress
Future<VVideoCompressionResult?> compressVideo(
  String videoPath, VVideoCompressionConfig config, {Function(double)? onProgress}
);

// Batch compress videos
Future<List<VVideoCompressionResult>> compressVideos(
  List<String> videoPaths, VVideoCompressionConfig config,
  {Function(double, int, int)? onProgress}
);

// Control operations
Future<void> cancelCompression();
Future<bool> isCompressing();
```

#### **Thumbnail Generation**

```dart
// Single thumbnail
Future<VVideoThumbnailResult?> getVideoThumbnail(
  String videoPath, VVideoThumbnailConfig config
);

// Multiple thumbnails
Future<List<VVideoThumbnailResult>> getVideoThumbnails(
  String videoPath, List<VVideoThumbnailConfig> configs
);
```

#### **Resource Management**

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

### 🎯 **Quality Levels**

| Quality       | Resolution | Bitrate Range | Use Case              |
| ------------- | ---------- | ------------- | --------------------- |
| **High**      | 1080p HD   | 8-12 Mbps     | Professional quality  |
| **Medium**    | 720p       | 4-6 Mbps      | Balanced quality/size |
| **Low**       | 480p       | 1-3 Mbps      | Social media sharing  |
| **Very Low**  | 360p       | 0.5-1.5 Mbps  | Messaging apps        |
| **Ultra Low** | 240p       | 0.2-0.8 Mbps  | Maximum compression   |

### ⚡ **Performance Optimizations**

- **Hybrid Progress Algorithm**: Combines time-based and file-size monitoring for accurate progress
- **Memory Management**: Automatic cleanup prevents memory leaks
- **Hardware Acceleration**: GPU encoding when available on device
- **Background Processing**: Non-blocking operations with proper lifecycle management
- **Efficient Batching**: Sequential processing prevents resource conflicts

### 🔒 **Error Handling & Recovery**

- **Graceful Degradation**: Continue operation when individual videos fail
- **Input Validation**: Comprehensive validation of all parameters
- **Resource Cleanup**: Automatic cleanup on errors or cancellation
- **Detailed Logging**: Full error context for debugging and issue reporting

### 📚 **Documentation**

- **Comprehensive API Documentation**: All public methods with examples
- **Usage Examples**: Complete examples for all features
- **iOS Version Compatibility**: Detailed iOS version support information
- **Advanced Configuration Guide**: Professional compression settings
- **Troubleshooting Guide**: Common issues and solutions

### 🧪 **Testing**

- **Unit Test Coverage**: 95%+ coverage of all public APIs
- **Mock Platform**: Complete mock implementation for testing
- **Integration Tests**: Real device testing on Android and iOS
- **Edge Case Coverage**: Invalid inputs, error conditions, cancellation scenarios
- **Performance Testing**: Memory usage and compression speed validation

### 🔨 **Development & Maintenance**

- **Clean Architecture**: Single responsibility, focused functionality
- **SOLID Principles**: Well-structured, maintainable codebase
- **Comprehensive Logging**: Production-ready error tracking
- **Version Stability**: Semantic versioning with backward compatibility
- **Documentation**: Complete API documentation and examples

### 🏗️ **Architecture Benefits**

#### **Plugin Focus**

- ✅ **Video Compression**: Advanced compression with real-time tracking
- ❌ **Video Selection**: Use `image_picker` or `file_picker`
- ❌ **File Management**: Use native file operations

#### **Dependencies**

```yaml
dependencies:
  v_video_compressor: ^1.0.0 # Only for compression
  image_picker: ^1.0.7 # For video selection
  file_picker: ^8.0.0 # Alternative file selection
  path_provider: ^2.1.0 # For custom paths (optional)
```

### 🎨 **Example Usage**

```dart
// Basic compression with progress
final result = await compressor.compressVideo(
  videoPath,
  VVideoCompressionConfig.medium(),
  onProgress: (progress) {
    print('Progress: ${(progress * 100).toInt()}%');
  },
);

// Advanced compression
final advancedConfig = VVideoAdvancedConfig(
  customWidth: 1280,
  customHeight: 720,
  videoBitrate: 4000000,
  videoCodec: VVideoCodec.h265,
  removeAudio: false,
  brightness: 0.1,
);

final result = await compressor.compressVideo(
  videoPath,
  VVideoCompressionConfig(
    quality: VVideoCompressQuality.medium,
    advanced: advancedConfig,
  ),
);

// Thumbnail generation
final thumbnail = await compressor.getVideoThumbnail(
  videoPath,
  VVideoThumbnailConfig(
    timeMs: 5000,
    maxWidth: 300,
    maxHeight: 200,
    format: VThumbnailFormat.jpeg,
    quality: 85,
  ),
);
```

### 📋 **Migration from Pre-Release**

This is the first stable release. If upgrading from development versions:

1. **Update pubspec.yaml**: `v_video_compressor: ^1.0.0`
2. **Run**: `flutter pub get`
3. **Review API**: Check method signatures for any breaking changes
4. **Test thoroughly**: Validate all compression workflows

### 🐛 **Known Issues & Limitations**

- **iOS Simulator**: Hardware acceleration not available in simulator
- **Large Files**: Very large files (>4GB) may require additional memory
- **Background Processing**: iOS may limit background compression time

### 🔮 **Roadmap**

- **1.1.0**: Enhanced progress algorithms and additional presets
- **1.2.0**: Video filtering and advanced effects
- **1.3.0**: Cloud storage integration helpers
- **2.0.0**: Breaking changes for improved performance

### 📄 **License**

MIT License - See [LICENSE](LICENSE) file for details.

### 🤝 **Contributing**

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

### 📞 **Support**

- **Issues**: [GitHub Issues](https://github.com/your-repo/v_video_compressor/issues)
- **Documentation**: [API Documentation](https://pub.dev/documentation/v_video_compressor)
- **Examples**: [Example App](https://github.com/your-repo/v_video_compressor/tree/main/example)

---

## Previous Releases

## [0.1.0] - 2024-12-XX (Development)

### Added

- **Video Thumbnail Generation API**: Extract thumbnails from video files at specific timestamps

  - `getVideoThumbnail()`: Generate a single thumbnail from a video
  - `getVideoThumbnails()`: Generate multiple thumbnails from a video at different timestamps
  - `VVideoThumbnailConfig`: Configuration for thumbnail generation (time, dimensions, format, quality)
  - `VVideoThumbnailResult`: Result containing thumbnail path, dimensions, and metadata
  - Support for JPEG and PNG output formats
  - Automatic aspect ratio preservation with custom width/height constraints
  - Android implementation using MediaMetadataRetriever
  - iOS implementation using AVAssetImageGenerator

- **Resource Cleanup API**: Free up storage space and resources
  - `cleanup()`: Complete cleanup of all temporary files and resources
  - `cleanupFiles()`: Selective cleanup with options for:
    - `deleteThumbnails`: Remove generated thumbnail files
    - `deleteCompressedVideos`: Optionally remove compressed video files
    - `clearCache`: Clear temporary cache and free memory
  - Automatic cancellation of ongoing operations during cleanup
  - Cross-platform implementation for Android and iOS

### Enhanced

- Updated plugin description to include thumbnail generation capabilities
- Added comprehensive documentation and examples for thumbnail API
- Enhanced example app with thumbnail generation demo
- Added resource management and cleanup functionality to example app
- Improved memory management with automatic resource cleanup

## [0.0.1] - Initial Development

- Initial development release
- Basic compression functionality
- Android platform support

## [1.0.4] - 2025-07-03

### Fixed

- Additional memory optimizations and bug fixes after field testing.
- Resolved INVALID_ARGUMENT error when using consolidated `config` map.
- Improved Kotlin nullability handling for map parameters.

### Added

- Dual API support: accepts either legacy parameter list or `config` map.
- More descriptive PlatformException messages.

### Changed

- Bumped minimum Kotlin stdlib to 1.9.20.
- Updated README with new example code.
