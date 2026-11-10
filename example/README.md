# Video Compressor Example

A simple, clean example app demonstrating how to use the `v_video_compressor` plugin.

The example uses the local 3.0.1 plugin. On Android, progress comes from
Media3 when available, with elapsed-time and output-size estimation as a
fallback. Progress never moves backwards, and 100% is reserved for completion.
The callbacks and global progress stream share this behavior.

## Features

- **Simple Interface**: Single page with clean, intuitive design
- **File Picker**: Easy video selection using `file_picker` package
- **Video Information**: Shows detailed video metadata before compression
- **Thumbnail Generation**: Automatic thumbnail generation and display from selected video
- **Quality Options**: Four compression quality levels (High, Medium, Low, Very Low)
- **Progress Tracking**: Real-time compression progress with cancel option
- **Results Display**: Shows compression statistics and space saved
- **Error Handling**: Clean error messages and recovery

## How to Use

1. **Select Video**: Tap "Choose Video" to select a video file from your device
2. **View Information**: See video details and auto-generated thumbnail (extracted at 2 seconds)
3. **Choose Quality**: Select your preferred compression quality:
   - **High Quality (1080p)**: Best quality, larger file size
   - **Medium Quality (720p)**: Good balance of quality and size
   - **Low Quality (480p)**: Smaller file size, lower quality
   - **Very Low Quality (360p)**: Smallest file size, lowest quality
4. **Compress**: The app will show progress and allow cancellation
5. **View Results**: See compression statistics and start again

## Code Structure

The app is built with clean, readable code following Flutter best practices:

- **Single Page**: All functionality in one `VideoCompressorPage`
- **Clean State Management**: Simple `setState` for UI updates
- **Proper Error Handling**: User-friendly error messages
- **Responsive Design**: Works on all screen sizes
- **Material 3**: Modern UI following Material Design principles

## Key Implementation Examples

### Video Selection with File Picker

```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.video,
  allowMultiple: false,
);
```

### Video Information Loading

```dart
final videoInfo = await _compressor.getVideoInfo(videoPath);
setState(() => _videoInfo = videoInfo);

// Generate thumbnail automatically after video info is loaded
await _generateThumbnail(videoPath);
```

### Thumbnail Generation

```dart
final config = const VVideoThumbnailConfig.defaults(
  timeMs: 2000, // Extract thumbnail at 2 seconds
  maxWidth: 300,
  maxHeight: 300,
  format: VThumbnailFormat.jpeg,
  quality: 85,
);

final thumbnail = await _compressor.getVideoThumbnail(videoPath, config);
```

### Video Compression with Progress

```dart
final result = await _compressor.compressVideo(
  videoPath,
  VVideoCompressionConfig(quality: quality, saveToGallery: true),
  onProgress: (progress) {
    setState(() => _compressionProgress = progress);
  },
);
```

## Dependencies

- `flutter`: Flutter SDK
- `v_video_compressor`: The video compression plugin
- `file_picker`: For selecting video files

## Running the Example

```bash
cd example
flutter pub get
flutter devices
flutter run -d <physical-device-id>
```

## Requirements

- **Flutter**: 3.47.0 or newer, with Dart 3.13.0 or newer
- **Android**: API level 21 (Android 5.0) or higher
- **iOS**: iOS 15.0 or higher for this example, with CocoaPods or SwiftPM
- **Permissions**: Storage access for file picking and saving

This example demonstrates how to integrate video compression into your Flutter app with minimal code and maximum clarity.
