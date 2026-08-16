import 'package:flutter_test/flutter_test.dart';
import 'package:v_video_compressor/v_video_compressor.dart';
import 'package:v_video_compressor/v_video_compressor_platform_interface.dart';
import 'package:v_video_compressor/v_video_compressor_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Mock implementation of VVideoCompressorPlatform for testing
class MockVVideoCompressorPlatform
    with MockPlatformInterfaceMixin
    implements VVideoCompressorPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<VVideoInfo?> getVideoInfo(String videoPath) async {
    if (videoPath.isEmpty || videoPath == '/invalid/path') {
      return null;
    }

    return VVideoInfo(
      path: videoPath,
      name: 'test_video.mp4',
      fileSizeBytes: 10485760, // 10MB
      durationMillis: 30000, // 30 seconds
      width: 1920,
      height: 1080,
      thumbnailPath: '/path/to/thumbnail.jpg',
    );
  }

  @override
  Future<VVideoCompressionEstimate?> getCompressionEstimate(
    String videoPath,
    VVideoCompressQuality quality, {
    VVideoAdvancedConfig? advanced,
  }) async {
    if (videoPath.isEmpty || videoPath == '/invalid/path') {
      return null;
    }

    return VVideoCompressionEstimate(
      estimatedSizeBytes: 5242880, // 5MB
      estimatedSizeFormatted: '5.0 MB',
      compressionRatio: 0.5,
      bitrateMbps: 2.5,
    );
  }

  @override
  Future<VVideoCompressionResult?> compressVideo(
    String videoPath,
    VVideoCompressionConfig config, {
    void Function(double progress)? onProgress,
  }) async {
    if (videoPath.isEmpty || videoPath == '/invalid/path') {
      return null;
    }

    // Simulate progress updates
    if (onProgress != null) {
      for (double progress = 0.0; progress <= 1.0; progress += 0.25) {
        onProgress(progress);
        await Future.delayed(Duration(milliseconds: 10));
      }
    }

    final originalInfo = VVideoInfo(
      path: videoPath,
      name: 'test_video.mp4',
      fileSizeBytes: 10485760,
      durationMillis: 30000,
      width: 1920,
      height: 1080,
    );

    return VVideoCompressionResult(
      originalVideo: originalInfo,
      compressedFilePath: '/path/to/compressed_video.mp4',
      galleryUri: 'content://media/external/video/123',
      originalSizeBytes: 10485760,
      compressedSizeBytes: 5242880,
      compressionRatio: 0.5,
      timeTaken: 5000,
      quality: config.quality,
      originalResolution: '1920x1080',
      compressedResolution: '1920x1080',
      spaceSaved: 5242880,
    );
  }

  @override
  Future<List<VVideoCompressionResult>> compressVideos(
    List<String> videoPaths,
    VVideoCompressionConfig config, {
    void Function(double progress, int currentIndex, int total)? onProgress,
  }) async {
    final results = <VVideoCompressionResult>[];

    for (int i = 0; i < videoPaths.length; i++) {
      final path = videoPaths[i];

      if (path.isEmpty || path == '/invalid/path') {
        continue;
      }

      // Simulate progress
      if (onProgress != null) {
        final progress = (i + 0.5) / videoPaths.length;
        onProgress(progress, i, videoPaths.length);
      }

      final result = await compressVideo(path, config);
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  @override
  Future<void> cancelCompression() => Future.value();

  @override
  Future<bool> isCompressing() => Future.value(false);

  @override
  Future<VVideoThumbnailResult?> getVideoThumbnail(
    String videoPath,
    VVideoThumbnailConfig config,
  ) async {
    if (videoPath.isEmpty || videoPath == '/invalid/path') {
      return null;
    }

    return VVideoThumbnailResult(
      thumbnailPath: '/path/to/thumbnail.jpg',
      width: config.maxWidth ?? 200,
      height: config.maxHeight ?? 200,
      fileSizeBytes: 15360, // 15KB
      format: config.format,
      timeMs: config.timeMs,
    );
  }

  @override
  Future<List<VVideoThumbnailResult>> getVideoThumbnails(
    String videoPath,
    List<VVideoThumbnailConfig> configs,
  ) async {
    if (videoPath.isEmpty || videoPath == '/invalid/path') {
      return [];
    }

    final results = <VVideoThumbnailResult>[];

    for (final config in configs) {
      final result = await getVideoThumbnail(videoPath, config);
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  @override
  Future<void> cleanup() => Future.value();

  @override
  Future<void> cleanupFiles({
    bool deleteThumbnails = true,
    bool deleteCompressedVideos = false,
    bool clearCache = true,
  }) =>
      Future.value();
}

void main() {
  final VVideoCompressorPlatform initialPlatform =
      VVideoCompressorPlatform.instance;

  group('VVideoCompressor Tests', () {
    late VVideoCompressor compressor;
    late MockVVideoCompressorPlatform mockPlatform;

    setUpAll(() {
      mockPlatform = MockVVideoCompressorPlatform();
      VVideoCompressorPlatform.instance = mockPlatform;
      compressor = VVideoCompressor();
    });

    tearDownAll(() {
      VVideoCompressorPlatform.instance = initialPlatform;
    });

    group('Platform Version', () {
      test('should return platform version', () async {
        final version = await compressor.getPlatformVersion();
        expect(version, '42');
      });
    });

    group('Video Info', () {
      test('should return video info for valid path', () async {
        const videoPath = '/path/to/video.mp4';
        final info = await compressor.getVideoInfo(videoPath);

        expect(info, isNotNull);
        expect(info!.path, videoPath);
        expect(info.name, 'test_video.mp4');
        expect(info.fileSizeBytes, 10485760);
        expect(info.durationMillis, 30000);
        expect(info.width, 1920);
        expect(info.height, 1080);
        expect(info.fileSizeMB, closeTo(10.0, 0.1));
        expect(info.durationFormatted, '00:30');
        expect(info.fileSizeFormatted, '10.0 MB');
      });

      test('should return null for empty path', () async {
        final info = await compressor.getVideoInfo('');
        expect(info, isNull);
      });

      test('should return null for invalid path', () async {
        final info = await compressor.getVideoInfo('/invalid/path');
        expect(info, isNull);
      });
    });

    group('Compression Estimation', () {
      test('should return compression estimate for valid video', () async {
        const videoPath = '/path/to/video.mp4';
        final estimate = await compressor.getCompressionEstimate(
          videoPath,
          VVideoCompressQuality.medium,
        );

        expect(estimate, isNotNull);
        expect(estimate!.estimatedSizeBytes, 5242880);
        expect(estimate.estimatedSizeFormatted, '5.0 MB');
        expect(estimate.compressionRatio, 0.5);
        expect(estimate.bitrateMbps, 2.5);
      });

      test('should return estimate with advanced config', () async {
        const videoPath = '/path/to/video.mp4';
        final advanced = VVideoAdvancedConfig(
          videoBitrate: 2000000,
          customWidth: 1280,
          customHeight: 720,
          autoCorrectOrientation: true,
        );

        final estimate = await compressor.getCompressionEstimate(
          videoPath,
          VVideoCompressQuality.medium,
          advanced: advanced,
        );

        expect(estimate, isNotNull);
      });

      test('should return null for empty path', () async {
        final estimate = await compressor.getCompressionEstimate(
          '',
          VVideoCompressQuality.medium,
        );
        expect(estimate, isNull);
      });
    });

    group('Single Video Compression', () {
      test('should compress video successfully', () async {
        const videoPath = '/path/to/video.mp4';
        final config = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
        );

        final result = await compressor.compressVideo(videoPath, config);

        expect(result, isNotNull);
        expect(result!.originalVideo.path, videoPath);
        expect(result.compressedFilePath, '/path/to/compressed_video.mp4');
        expect(result.originalSizeBytes, 10485760);
        expect(result.compressedSizeBytes, 5242880);
        expect(result.compressionRatio, 0.5);
        expect(result.compressionPercentage, 50);
        expect(result.spaceSaved, 5242880);
      });

      test('should track compression progress', () async {
        const videoPath = '/path/to/video.mp4';
        final config = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
        );

        final progressValues = <double>[];

        final result = await compressor.compressVideo(
          videoPath,
          config,
          onProgress: (progress) {
            progressValues.add(progress);
          },
        );

        expect(result, isNotNull);
        expect(progressValues, isNotEmpty);
        expect(progressValues.first, 0.0);
        expect(progressValues.last, 1.0);
      });

      test('should return null for empty path', () async {
        final config = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
        );

        final result = await compressor.compressVideo('', config);
        expect(result, isNull);
      });
    });

    group('Batch Video Compression', () {
      test('should compress multiple videos', () async {
        final videoPaths = [
          '/path/to/video1.mp4',
          '/path/to/video2.mp4',
          '/path/to/video3.mp4',
        ];
        final config = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
        );

        final results = await compressor.compressVideos(videoPaths, config);

        expect(results, hasLength(3));
        for (int i = 0; i < results.length; i++) {
          expect(results[i].originalVideo.path, videoPaths[i]);
        }
      });

      test('should track batch compression progress', () async {
        final videoPaths = [
          '/path/to/video1.mp4',
          '/path/to/video2.mp4',
        ];
        final config = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
        );

        final progressUpdates = <Map<String, dynamic>>[];

        final results = await compressor.compressVideos(
          videoPaths,
          config,
          onProgress: (progress, currentIndex, total) {
            progressUpdates.add({
              'progress': progress,
              'currentIndex': currentIndex,
              'total': total,
            });
          },
        );

        expect(results, hasLength(2));
        expect(progressUpdates, isNotEmpty);
        expect(progressUpdates.last['total'], 2);
      });

      test('should skip invalid videos', () async {
        final videoPaths = [
          '/path/to/video1.mp4',
          '/invalid/path',
          '/path/to/video3.mp4',
        ];
        final config = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
        );

        final results = await compressor.compressVideos(videoPaths, config);

        expect(results, hasLength(2)); // Should skip the invalid path
      });

      test('should return empty list for empty input', () async {
        final config = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
        );

        final results = await compressor.compressVideos([], config);
        expect(results, isEmpty);
      });
    });

    group('Compression Control', () {
      test('should cancel compression', () async {
        await expectLater(
          () => compressor.cancelCompression(),
          returnsNormally,
        );
      });

      test('should check compression status', () async {
        final isCompressing = await compressor.isCompressing();
        expect(isCompressing, isFalse);
      });
    });

    group('Thumbnail Generation', () {
      test('should generate single thumbnail', () async {
        const videoPath = '/path/to/video.mp4';
        final config = VVideoThumbnailConfig(
          timeMs: 5000,
          maxWidth: 300,
          maxHeight: 200,
          format: VThumbnailFormat.jpeg,
          quality: 85,
        );

        final result = await compressor.getVideoThumbnail(videoPath, config);

        expect(result, isNotNull);
        expect(result!.thumbnailPath, '/path/to/thumbnail.jpg');
        expect(result.width, 300);
        expect(result.height, 200);
        expect(result.format, VThumbnailFormat.jpeg);
        expect(result.timeMs, 5000);
        expect(result.fileSizeBytes, 15360);
      });

      test('should generate multiple thumbnails', () async {
        const videoPath = '/path/to/video.mp4';
        final configs = [
          VVideoThumbnailConfig(timeMs: 1000, maxWidth: 150),
          VVideoThumbnailConfig(timeMs: 5000, maxWidth: 150),
          VVideoThumbnailConfig(timeMs: 10000, maxWidth: 150),
        ];

        final results = await compressor.getVideoThumbnails(videoPath, configs);

        expect(results, hasLength(3));
        expect(results[0].timeMs, 1000);
        expect(results[1].timeMs, 5000);
        expect(results[2].timeMs, 10000);
      });

      test('should return null for invalid video path', () async {
        final config = VVideoThumbnailConfig();
        final result =
            await compressor.getVideoThumbnail('/invalid/path', config);
        expect(result, isNull);
      });

      test('should return empty list for empty configs', () async {
        const videoPath = '/path/to/video.mp4';
        final results = await compressor.getVideoThumbnails(videoPath, []);
        expect(results, isEmpty);
      });
    });

    group('Cleanup Operations', () {
      test('should perform complete cleanup', () async {
        await expectLater(
          () => compressor.cleanup(),
          returnsNormally,
        );
      });

      test('should perform selective cleanup', () async {
        await expectLater(
          () => compressor.cleanupFiles(
            deleteThumbnails: true,
            deleteCompressedVideos: false,
            clearCache: true,
          ),
          returnsNormally,
        );
      });
    });

    group('Configuration Validation', () {
      test('should validate basic compression config', () {
        final config = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
        );
        expect(config.isValid(), isTrue);
      });

      test('should validate advanced compression config', () {
        final advanced = VVideoAdvancedConfig(
          customWidth: 1280,
          customHeight: 720,
          frameRate: 30.0,
          crf: 23,
          autoCorrectOrientation: true,
        );
        expect(advanced.isValid(), isTrue);

        final config = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
          advanced: advanced,
        );
        expect(config.isValid(), isTrue);
      });

      test('should reject non-positive video and audio bitrates', () {
        expect(
          const VVideoAdvancedConfig(videoBitrate: 0).isValid(),
          isFalse,
        );
        expect(
          const VVideoAdvancedConfig(videoBitrate: -1).isValid(),
          isFalse,
        );
        expect(
          const VVideoAdvancedConfig(audioBitrate: 0).isValid(),
          isFalse,
        );
        expect(
          const VVideoAdvancedConfig(audioBitrate: -1).isValid(),
          isFalse,
        );
        expect(
          const VVideoAdvancedConfig(videoBitrate: 0x80000000).isValid(),
          isFalse,
        );
        expect(
          const VVideoAdvancedConfig(audioBitrate: 0x80000000).isValid(),
          isFalse,
        );
        expect(
          const VVideoAdvancedConfig(
            videoBitrate: 250000,
            audioBitrate: 128000,
          ).isValid(),
          isTrue,
        );
      });

      test('should validate autoCorrectOrientation parameter', () {
        final advancedWithOrientation = VVideoAdvancedConfig(
          autoCorrectOrientation: true,
          videoBitrate: 1500000,
        );
        expect(advancedWithOrientation.isValid(), isTrue);
        expect(advancedWithOrientation.autoCorrectOrientation, isTrue);

        final advancedWithoutOrientation = VVideoAdvancedConfig(
          autoCorrectOrientation: false,
          videoBitrate: 1500000,
        );
        expect(advancedWithoutOrientation.isValid(), isTrue);
        expect(advancedWithoutOrientation.autoCorrectOrientation, isFalse);

        final advancedNullOrientation = VVideoAdvancedConfig(
          videoBitrate: 1500000,
        );
        expect(advancedNullOrientation.isValid(), isTrue);
        expect(advancedNullOrientation.autoCorrectOrientation, isNull);
      });

      test('should compress video with orientation correction', () async {
        const videoPath = '/path/to/vertical_video.mp4';
        final config = VVideoCompressionConfig(
          quality: VVideoCompressQuality.medium,
          advanced: VVideoAdvancedConfig(
            autoCorrectOrientation: true,
            videoBitrate: 1500000,
            audioBitrate: 128000,
          ),
        );

        final result = await compressor.compressVideo(videoPath, config);

        expect(result, isNotNull);
        expect(result!.originalVideo.path, videoPath);
        expect(result.compressedFilePath, '/path/to/compressed_video.mp4');
        expect(result.originalResolution, '1920x1080');
      });

      test('should validate thumbnail config', () {
        final config = VVideoThumbnailConfig(
          timeMs: 5000,
          maxWidth: 300,
          maxHeight: 200,
          quality: 85,
        );
        expect(config.isValid(), isTrue);
      });

      test('should reject invalid thumbnail config', () {
        final config = VVideoThumbnailConfig(
          timeMs: -1000, // Invalid time
          quality: 150, // Invalid quality
        );
        expect(config.isValid(), isFalse);
      });

      test('should reject invalid advanced config', () {
        final advanced = VVideoAdvancedConfig(
          customWidth: 1280,
          // Missing height - should be invalid
          frameRate: -1.0, // Invalid frame rate
        );
        expect(advanced.isValid(), isFalse);
      });
    });

    group('Data Model Tests', () {
      test('compression fallback remains enabled for legacy configurations',
          () {
        final config = VVideoCompressionConfig.fromMap({
          'quality': VVideoCompressQuality.medium.value,
        });

        expect(config.fallbackToOriginalIfNotSmaller, isTrue);
        expect(
          const VVideoCompressionConfig.medium()
              .toMap()['fallbackToOriginalIfNotSmaller'],
          isTrue,
        );
      });

      test('compression fallback can be disabled and round-tripped', () {
        const config = VVideoCompressionConfig.medium(
          fallbackToOriginalIfNotSmaller: false,
        );

        final decoded = VVideoCompressionConfig.fromMap(config.toMap());

        expect(decoded.fallbackToOriginalIfNotSmaller, isFalse);
      });

      test('should format video info correctly', () {
        final info = VVideoInfo(
          path: '/path/to/video.mp4',
          name: 'test_video.mp4',
          fileSizeBytes: 52428800, // 50MB
          durationMillis: 125000, // 2:05
          width: 1920,
          height: 1080,
        );

        expect(info.fileSizeMB, closeTo(50.0, 0.1));
        expect(info.durationFormatted, '02:05');
        expect(info.fileSizeFormatted, '50.0 MB');
      });

      test('should format compression result correctly', () {
        final originalInfo = VVideoInfo(
          path: '/path/to/video.mp4',
          name: 'test_video.mp4',
          fileSizeBytes: 52428800,
          durationMillis: 125000,
          width: 1920,
          height: 1080,
        );

        final result = VVideoCompressionResult(
          originalVideo: originalInfo,
          compressedFilePath: '/path/to/compressed.mp4',
          originalSizeBytes: 52428800,
          compressedSizeBytes: 26214400,
          compressionRatio: 0.5,
          timeTaken: 45000,
          quality: VVideoCompressQuality.medium,
          originalResolution: '1920x1080',
          compressedResolution: '1920x1080',
          spaceSaved: 26214400,
        );

        expect(result.compressionPercentage, 50);
        expect(result.originalSizeFormatted, '50.0 MB');
        expect(result.compressedSizeFormatted, '25.0 MB');
        expect(result.spaceSavedFormatted, '25.0 MB');
        expect(result.timeTakenFormatted, '45s');
      });

      test('compression result reports when the original file was used', () {
        final originalInfo = VVideoInfo(
          path: '/path/to/video.mp4',
          name: 'test_video.mp4',
          fileSizeBytes: 1024,
          durationMillis: 1000,
          width: 100,
          height: 100,
        );
        final result = VVideoCompressionResult(
          originalVideo: originalInfo,
          compressedFilePath: originalInfo.path,
          originalSizeBytes: 1024,
          compressedSizeBytes: 1024,
          compressionRatio: 1,
          timeTaken: 100,
          quality: VVideoCompressQuality.medium,
          originalResolution: '100x100',
          compressedResolution: '100x100',
          spaceSaved: 0,
          usedOriginalFile: true,
        );

        expect(
          VVideoCompressionResult.fromMap(result.toMap()).usedOriginalFile,
          isTrue,
        );

        final legacyMap = result.toMap()..remove('usedOriginalFile');
        expect(
          VVideoCompressionResult.fromMap(legacyMap).usedOriginalFile,
          isFalse,
        );
      });

      test('should format thumbnail result correctly', () {
        final result = VVideoThumbnailResult(
          thumbnailPath: '/path/to/thumb.jpg',
          width: 300,
          height: 200,
          fileSizeBytes: 25600, // 25KB
          format: VThumbnailFormat.jpeg,
          timeMs: 5000,
        );

        expect(result.fileSizeFormatted, '25.0 KB');
      });
    });

    group('Enum Tests', () {
      test('should have correct quality enum values', () {
        expect(VVideoCompressQuality.high.value, 'HIGH');
        expect(VVideoCompressQuality.medium.value, 'MEDIUM');
        expect(VVideoCompressQuality.low.value, 'LOW');
        expect(VVideoCompressQuality.veryLow.value, 'VERY_LOW');
        expect(VVideoCompressQuality.ultraLow.value, 'ULTRA_LOW');
      });

      test('should have correct codec enum values', () {
        expect(VVideoCodec.h264.value, 'H264');
        expect(VVideoCodec.h265.value, 'H265');
      });

      test('should have correct thumbnail format enum values', () {
        expect(VThumbnailFormat.jpeg.value, 'JPEG');
        expect(VThumbnailFormat.png.value, 'PNG');
        expect(VThumbnailFormat.jpeg.extension, '.jpg');
        expect(VThumbnailFormat.png.extension, '.png');
      });
    });

    group('Preset Configurations', () {
      test('should create maximum compression config', () {
        final config = VVideoAdvancedConfig.maximumCompression();

        expect(config.videoCodec, VVideoCodec.h265);
        expect(config.removeAudio, isTrue);
        expect(config.aggressiveCompression, isTrue);
        expect(config.twoPassEncoding, isTrue);
      });

      test('should create social media optimized config', () {
        final config = VVideoAdvancedConfig.socialMediaOptimized();

        expect(config.videoCodec, VVideoCodec.h265);
        expect(config.aggressiveCompression, isTrue);
        expect(config.audioChannels, 2);
      });

      test('should create mobile optimized config', () {
        final config = VVideoAdvancedConfig.mobileOptimized();

        expect(config.videoCodec, VVideoCodec.h264);
        expect(config.hardwareAcceleration, isTrue);
        expect(config.audioChannels, 2);
      });
    });
  });

  group('MethodChannelVVideoCompressor Tests', () {
    test('should be the default instance', () {
      expect(initialPlatform, isInstanceOf<MethodChannelVVideoCompressor>());
    });
  });
}
