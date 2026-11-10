/// V Video Compressor - A focused Flutter plugin for efficient video compression
///
/// This plugin provides:
/// - High-quality video compression with multiple quality levels
/// - Real-time progress tracking with smooth updates
/// - Advanced customization options for professional use
/// - Thumbnail generation from video files
/// - Batch compression capabilities
/// - Comprehensive error handling and configurable logging
/// - Optional ID-based compression tracking
///
/// Version: 3.0.1
/// Author: V Chat SDK Team
/// License: MIT
library;

import 'dart:async';

import 'src/v_video_logger.dart';
import 'src/v_video_models.dart';
import 'src/v_video_stream_manager.dart';
import 'v_video_compressor_platform_interface.dart';

// Export all public APIs
export 'src/v_video_logger.dart' show VVideoLogConfig, VVideoLogLevel;
export 'src/v_video_models.dart'
    show
        VVideoCompressQuality,
        VVideoCodec,
        VAudioCodec,
        VEncodingSpeed,
        VThumbnailFormat,
        VDimensionHandling,
        VVideoCropRect,
        VVideoAdvancedConfig,
        VVideoInfo,
        VVideoCompressionConfig,
        VVideoCompressionEstimate,
        VVideoCompressionResult,
        VVideoThumbnailConfig,
        VVideoThumbnailResult,
        VVideoProgressEvent,
        alignTo16;
export 'src/v_video_stream_manager.dart' show VVideoStreamManager;

/// V Video Compressor - A focused Flutter plugin for efficient video compression
///
/// This plugin provides comprehensive video compression capabilities with:
/// - Multiple quality levels and advanced customization
/// - Real-time progress tracking with smooth updates
/// - Thumbnail generation at specific timestamps
/// - Batch compression with progress tracking
/// - Comprehensive error handling and configurable logging
/// - Automatic cleanup and resource management
/// - Optional ID-based compression tracking
class VVideoCompressor {
  /// Generate a unique compression ID
  static String _generateCompressionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return 'compression_${timestamp}_$random';
  }

  /// Configure logging for the V Video Compressor
  ///
  /// This method allows you to configure how the plugin logs information:
  /// - Enable/disable logging entirely
  /// - Set log levels (none, error, warning, info, debug, verbose)
  /// - Control what types of logs are shown
  /// - Use console output or structured logging
  ///
  /// Example configurations:
  /// ```dart
  /// // Production: minimal logging
  /// VVideoCompressor.configureLogging(VVideoLogConfig.production());
  ///
  /// // Development: verbose logging
  /// VVideoCompressor.configureLogging(VVideoLogConfig.development());
  ///
  /// // Custom configuration
  /// VVideoCompressor.configureLogging(VVideoLogConfig(
  ///   enabled: true,
  ///   level: VVideoLogLevel.info,
  ///   showProgress: true,
  ///   showParameters: true,
  /// ));
  ///
  /// // Disable all logging
  /// VVideoCompressor.configureLogging(VVideoLogConfig.disabled());
  /// ```
  static void configureLogging(VVideoLogConfig config) {
    VVideoLogger.configure(config);
    VVideoLogger.info('Logging configured with level: ${config.level.name}');
  }

  /// Get current logging configuration
  static VVideoLogConfig get loggingConfig => VVideoLogger.config;

  /// Global progress stream - accessible from anywhere in your app
  ///
  /// This stream provides real-time progress updates for all video compression operations.
  /// You can listen to this stream from any part of your app without needing to pass
  /// callbacks through method parameters.
  ///
  /// Example:
  /// ```dart
  /// // Listen to all compression progress
  /// VVideoCompressor.progressStream.listen((event) {
  ///   print('Progress: ${event.progressFormatted}');
  ///   if (event.isBatchOperation) {
  ///     print('Batch: ${event.batchProgressDescription}');
  ///   }
  /// });
  ///
  /// // Or use the convenience methods
  /// VVideoCompressor.listenToProgress((progress) {
  ///   print('Progress: ${(progress * 100).toInt()}%');
  /// });
  /// ```
  static Stream<VVideoProgressEvent> get progressStream =>
      VVideoStreamManager.progressStream;

  /// Convenience method to listen to progress with typed callback
  static StreamSubscription<VVideoProgressEvent> listen(
    void Function(VVideoProgressEvent event) onProgress, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => VVideoStreamManager.listen(
    onProgress,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  /// Convenience method to listen to progress with simple callback
  static StreamSubscription<VVideoProgressEvent> listenToProgress(
    void Function(double progress) onProgress, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => VVideoStreamManager.listenToProgress(
    onProgress,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  /// Convenience method to listen to batch progress
  static StreamSubscription<VVideoProgressEvent> listenToBatchProgress(
    void Function(double progress, int currentIndex, int total) onProgress, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => VVideoStreamManager.listenToBatchProgress(
    onProgress,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  /// Get platform version (for testing and debugging)
  ///
  /// Returns the platform version string or null if unavailable.
  /// This method is primarily used for testing and debugging purposes.
  Future<String?> getPlatformVersion() async {
    try {
      VVideoLogger.methodCall('getPlatformVersion', null);
      final version = await VVideoCompressorPlatform.instance
          .getPlatformVersion();
      VVideoLogger.success('getPlatformVersion', {
        'version': version ?? 'unknown',
      });
      return version;
    } catch (error, stackTrace) {
      VVideoLogger.error('Failed to get platform version', error, stackTrace);
      return null;
    }
  }

  /// Get comprehensive video information from file path
  ///
  /// Returns detailed video metadata including:
  /// - File size, duration, and resolution
  /// - Video name and file path
  /// - Formatted duration and file size strings
  ///
  /// Returns null if the video file is invalid or inaccessible.
  ///
  /// Example:
  /// ```dart
  /// final info = await compressor.getVideoInfo('/path/to/video.mp4');
  /// if (info != null) {
  ///   print('Duration: ${info.durationFormatted}');
  ///   print('Size: ${info.fileSizeFormatted}');
  ///   print('Resolution: ${info.width}x${info.height}');
  /// }
  /// ```
  Future<VVideoInfo?> getVideoInfo(String videoPath) async {
    try {
      VVideoLogger.methodCall('getVideoInfo', {'videoPath': videoPath});

      if (videoPath.isEmpty) {
        VVideoLogger.warning('Empty video path provided to getVideoInfo');
        return null;
      }

      final info = await VVideoCompressorPlatform.instance.getVideoInfo(
        videoPath,
      );

      if (info != null) {
        VVideoLogger.success('getVideoInfo', {
          'name': info.name,
          'duration': info.durationFormatted,
          'size': info.fileSizeFormatted,
          'resolution': '${info.width}x${info.height}',
        });
      } else {
        VVideoLogger.warning(
          'Failed to get video info - file may be invalid or inaccessible',
        );
      }

      return info;
    } catch (error, stackTrace) {
      VVideoLogger.error(
        'Failed to get video info for path: $videoPath',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Estimate compression size and ratio before actual compression
  ///
  /// This method provides accurate estimates for:
  /// - Final compressed file size
  /// - Compression ratio percentage
  /// - Expected bitrate after compression
  ///
  /// Useful for UI feedback and storage planning.
  ///
  /// Example:
  /// ```dart
  /// final estimate = await compressor.getCompressionEstimate(
  ///   videoPath,
  ///   VVideoCompressQuality.medium,
  ///   advanced: advancedConfig,
  /// );
  ///
  /// if (estimate != null) {
  ///   print('Estimated size: ${estimate.estimatedSizeFormatted}');
  ///   print('Compression ratio: ${estimate.compressionRatio}');
  /// }
  /// ```
  Future<VVideoCompressionEstimate?> getCompressionEstimate(
    String videoPath,
    VVideoCompressQuality quality, {
    VVideoAdvancedConfig? advanced,
  }) async {
    try {
      VVideoLogger.methodCall('getCompressionEstimate', {
        'videoPath': videoPath,
        'quality': quality.value,
        'hasAdvanced': advanced != null,
      });

      if (videoPath.isEmpty) {
        VVideoLogger.warning(
          'Empty video path provided to getCompressionEstimate',
        );
        return null;
      }

      final estimate = await VVideoCompressorPlatform.instance
          .getCompressionEstimate(videoPath, quality, advanced: advanced);

      if (estimate != null) {
        VVideoLogger.success('getCompressionEstimate', {
          'estimatedSize': estimate.estimatedSizeFormatted,
          'compressionRatio':
              '${(estimate.compressionRatio * 100).toStringAsFixed(1)}%',
          'bitrate': '${estimate.bitrateMbps.toStringAsFixed(2)} Mbps',
        });
      } else {
        VVideoLogger.warning(
          'Failed to get compression estimate - video may be invalid',
        );
      }

      return estimate;
    } catch (error, stackTrace) {
      VVideoLogger.error(
        'Failed to get compression estimate for: $videoPath',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Compress a single video with real-time progress tracking
  ///
  /// This is the core compression method that provides:
  /// - High-quality video compression with configurable quality levels
  /// - Real-time progress updates via callback
  /// - Advanced compression options support
  /// - Automatic error handling and recovery
  /// - Comprehensive logging for debugging
  /// - Optional ID-based tracking for monitoring
  ///
  /// The [onProgress] callback receives values from 0.0 to 1.0 representing
  /// compression progress percentage.
  ///
  /// The [id] parameter allows tracking this compression operation.
  /// If not provided, a unique ID will be auto-generated.
  ///
  /// Example:
  /// ```dart
  /// final result = await compressor.compressVideo(
  ///   videoPath,
  ///   VVideoCompressionConfig.medium(),
  ///   onProgress: (progress) {
  ///     print('Progress: ${(progress * 100).toInt()}%');
  ///   },
  ///   id: 'my-compression',
  /// );
  ///
  /// if (result != null) {
  ///   print('Compressed from ${result.originalSizeFormatted} to ${result.compressedSizeFormatted}');
  ///   print('Space saved: ${result.spaceSavedFormatted}');
  /// }
  /// ```
  Future<VVideoCompressionResult?> compressVideo(
    String videoPath,
    VVideoCompressionConfig config, {
    void Function(double progress)? onProgress,
    String? id,
  }) async {
    final compressionId = id ?? _generateCompressionId();

    try {
      VVideoLogger.methodCall('compressVideo', {
        'videoPath': videoPath,
        'id': compressionId,
        'quality': config.quality.value,
        'hasAdvanced': config.advanced != null,
        'deleteOriginal': config.deleteOriginal,
      });

      if (videoPath.isEmpty) {
        VVideoLogger.error('Empty video path provided to compressVideo');
        return null;
      }

      if (!config.isValid()) {
        VVideoLogger.error('Invalid compression configuration provided');
        return null;
      }

      VVideoLogger.info('Starting video compression with ID: $compressionId');
      final startTime = DateTime.now();

      final result = await VVideoCompressorPlatform.instance.compressVideo(
        videoPath,
        config,
        onProgress: onProgress != null
            ? (progress) {
                VVideoLogger.progress('Compression', progress);
                onProgress(progress);
              }
            : null,
      );

      if (result != null) {
        final endTime = DateTime.now();
        final totalTime = endTime.difference(startTime);

        VVideoLogger.success('compressVideo', {
          'id': compressionId,
          'originalSize': result.originalSizeFormatted,
          'compressedSize': result.compressedSizeFormatted,
          'spaceSaved': result.spaceSavedFormatted,
          'compressionRatio': '${result.compressionPercentage}%',
          'timeTaken': result.timeTakenFormatted,
          'totalTime': '${totalTime.inSeconds}s',
        });
      } else {
        VVideoLogger.error('Compression failed - no result returned');
      }

      return result;
    } catch (error, stackTrace) {
      VVideoLogger.error(
        'Video compression failed for: $videoPath',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Compress multiple videos with batch processing
  ///
  /// This method provides efficient batch compression of multiple videos with:
  /// - Sequential processing to manage memory and resources
  /// - Progress tracking for overall batch and individual videos
  /// - Automatic error handling and recovery for failed videos
  /// - Comprehensive logging for debugging
  ///
  /// The [onProgress] callback receives batch progress (0.0 to 1.0), current video index,
  /// and total video count.
  ///
  /// Example:
  /// ```dart
  /// final results = await compressor.compressVideos(
  ///   ['/path/to/video1.mp4', '/path/to/video2.mp4'],
  ///   VVideoCompressionConfig.medium(),
  ///   onProgress: (progress, currentIndex, total) {
  ///     print('Batch progress: ${(progress * 100).toInt()}% ($currentIndex/$total)');
  ///   },
  /// );
  ///
  /// print('Compressed ${results.length} videos');
  /// ```
  Future<List<VVideoCompressionResult>> compressVideos(
    List<String> videoPaths,
    VVideoCompressionConfig config, {
    void Function(double progress, int currentIndex, int total)? onProgress,
  }) async {
    try {
      VVideoLogger.methodCall('compressVideos', {
        'videoCount': videoPaths.length,
        'quality': config.quality.value,
        'hasAdvanced': config.advanced != null,
        'deleteOriginal': config.deleteOriginal,
      });

      if (videoPaths.isEmpty) {
        VVideoLogger.warning('Empty video paths list provided');
        return [];
      }

      return await VVideoCompressorPlatform.instance.compressVideos(
        videoPaths,
        config,
        onProgress: onProgress,
      );
    } catch (error, stackTrace) {
      VVideoLogger.error('Batch video compression failed', error, stackTrace);
      return [];
    }
  }

  /// Cancel current compression operation
  ///
  /// This method attempts to cancel any ongoing compression operation.
  /// Note that cancellation may not be immediate and depends on the
  /// platform implementation.
  ///
  /// Example:
  /// ```dart
  /// await compressor.cancelCompression();
  /// ```
  Future<void> cancelCompression() async {
    try {
      VVideoLogger.methodCall('cancelCompression', null);
      await VVideoCompressorPlatform.instance.cancelCompression();
      VVideoLogger.success('cancelCompression', null);
    } catch (error, stackTrace) {
      VVideoLogger.error('Failed to cancel compression', error, stackTrace);
    }
  }

  /// Check if compression is currently in progress
  ///
  /// Returns true if a compression operation is currently active.
  ///
  /// Example:
  /// ```dart
  /// final isCompressing = await compressor.isCompressing();
  /// if (isCompressing) {
  ///   print('Compression is in progress');
  /// }
  /// ```
  Future<bool> isCompressing() async {
    try {
      VVideoLogger.methodCall('isCompressing', null);
      final isCompressing = await VVideoCompressorPlatform.instance
          .isCompressing();
      VVideoLogger.success('isCompressing', {'result': isCompressing});
      return isCompressing;
    } catch (error, stackTrace) {
      VVideoLogger.error(
        'Failed to check compression status',
        error,
        stackTrace,
      );
      return false;
    }
  }

  /// Generate a thumbnail from a video at a specific timestamp
  ///
  /// This method extracts a single thumbnail image from a video at the
  /// specified timestamp with configurable quality and dimensions.
  ///
  /// The [config] parameter allows you to specify:
  /// - Timestamp to extract thumbnail from
  /// - Maximum width and height
  /// - Image format (JPEG or PNG)
  /// - Quality (for JPEG format)
  ///
  /// Returns null if the video is invalid or thumbnail generation fails.
  ///
  /// Example:
  /// ```dart
  /// final thumbnail = await compressor.getVideoThumbnail(
  ///   videoPath,
  ///   VVideoThumbnailConfig(
  ///     timeMs: 5000, // 5 seconds
  ///     maxWidth: 300,
  ///     maxHeight: 200,
  ///     format: VThumbnailFormat.jpeg,
  ///     quality: 85,
  ///   ),
  /// );
  ///
  /// if (thumbnail != null) {
  ///   print('Thumbnail saved to: ${thumbnail.thumbnailPath}');
  /// }
  /// ```
  Future<VVideoThumbnailResult?> getVideoThumbnail(
    String videoPath,
    VVideoThumbnailConfig config,
  ) async {
    try {
      VVideoLogger.methodCall('getVideoThumbnail', {
        'videoPath': videoPath,
        'timeMs': config.timeMs,
        'maxWidth': config.maxWidth,
        'maxHeight': config.maxHeight,
        'format': config.format.value,
        'quality': config.quality,
      });

      if (videoPath.isEmpty) {
        VVideoLogger.warning('Empty video path provided to getVideoThumbnail');
        return null;
      }

      final result = await VVideoCompressorPlatform.instance.getVideoThumbnail(
        videoPath,
        config,
      );

      if (result != null) {
        VVideoLogger.success('getVideoThumbnail', {
          'thumbnailPath': result.thumbnailPath,
          'size': '${result.width}x${result.height}',
          'fileSize': '${(result.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
        });
      } else {
        VVideoLogger.warning(
          'Failed to generate thumbnail - video may be invalid',
        );
      }

      return result;
    } catch (error, stackTrace) {
      VVideoLogger.error(
        'Failed to generate thumbnail for: $videoPath',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Generate multiple thumbnails from a video
  ///
  /// This method generates multiple thumbnails from a single video using
  /// different configurations. This is more efficient than calling
  /// [getVideoThumbnail] multiple times.
  ///
  /// Each configuration in [configs] specifies different parameters
  /// like timestamp, dimensions, and quality.
  ///
  /// Returns a list of thumbnail results in the same order as the configs.
  /// Failed thumbnails will be omitted from the results.
  ///
  /// Example:
  /// ```dart
  /// final thumbnails = await compressor.getVideoThumbnails(
  ///   videoPath,
  ///   [
  ///     VVideoThumbnailConfig(timeMs: 1000, maxWidth: 150),
  ///     VVideoThumbnailConfig(timeMs: 5000, maxWidth: 150),
  ///     VVideoThumbnailConfig(timeMs: 10000, maxWidth: 150),
  ///   ],
  /// );
  ///
  /// print('Generated ${thumbnails.length} thumbnails');
  /// ```
  Future<List<VVideoThumbnailResult>> getVideoThumbnails(
    String videoPath,
    List<VVideoThumbnailConfig> configs,
  ) async {
    try {
      VVideoLogger.methodCall('getVideoThumbnails', {
        'videoPath': videoPath,
        'configCount': configs.length,
      });

      if (videoPath.isEmpty) {
        VVideoLogger.warning('Empty video path provided to getVideoThumbnails');
        return [];
      }

      if (configs.isEmpty) {
        VVideoLogger.warning(
          'Empty configs list provided to getVideoThumbnails',
        );
        return [];
      }

      final results = await VVideoCompressorPlatform.instance
          .getVideoThumbnails(videoPath, configs);

      VVideoLogger.success('getVideoThumbnails', {
        'generatedCount': results.length,
        'requestedCount': configs.length,
      });

      return results;
    } catch (error, stackTrace) {
      VVideoLogger.error(
        'Failed to generate thumbnails for: $videoPath',
        error,
        stackTrace,
      );
      return [];
    }
  }

  /// Perform cleanup of temporary files and resources
  ///
  /// This method cleans up temporary files, cached data, and other resources
  /// created during compression operations. It's recommended to call this
  /// method periodically or when your app is being closed.
  ///
  /// Example:
  /// ```dart
  /// await compressor.cleanup();
  /// ```
  Future<void> cleanup() async {
    try {
      VVideoLogger.methodCall('cleanup', null);
      await VVideoCompressorPlatform.instance.cleanup();
      VVideoLogger.success('cleanup', null);
    } catch (error, stackTrace) {
      VVideoLogger.error('Failed to perform cleanup', error, stackTrace);
    }
  }

  /// Perform selective cleanup of files and resources
  ///
  /// This method allows you to selectively clean up specific types of files:
  /// - [deleteThumbnails]: Delete generated thumbnail files
  /// - [deleteCompressedVideos]: Delete compressed video files
  /// - [clearCache]: Clear internal caches
  ///
  /// Use this method when you need fine-grained control over cleanup operations.
  ///
  /// Example:
  /// ```dart
  /// await compressor.cleanupFiles(
  ///   deleteThumbnails: true,
  ///   deleteCompressedVideos: false,
  ///   clearCache: true,
  /// );
  /// ```
  Future<void> cleanupFiles({
    bool deleteThumbnails = true,
    bool deleteCompressedVideos = false,
    bool clearCache = true,
  }) async {
    try {
      VVideoLogger.methodCall('cleanupFiles', {
        'deleteThumbnails': deleteThumbnails,
        'deleteCompressedVideos': deleteCompressedVideos,
        'clearCache': clearCache,
      });

      await VVideoCompressorPlatform.instance.cleanupFiles(
        deleteThumbnails: deleteThumbnails,
        deleteCompressedVideos: deleteCompressedVideos,
        clearCache: clearCache,
      );

      VVideoLogger.success('cleanupFiles', {
        'deleteThumbnails': deleteThumbnails,
        'deleteCompressedVideos': deleteCompressedVideos,
        'clearCache': clearCache,
      });
    } catch (error, stackTrace) {
      VVideoLogger.error(
        'Failed to perform selective cleanup',
        error,
        stackTrace,
      );
    }
  }
}
