import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'v_video_compressor_platform_interface.dart';
import 'v_video_compressor.dart';
import 'src/v_video_models.dart';
import 'src/v_video_logger.dart';

/// An implementation of [VVideoCompressorPlatform] that uses method channels.
class MethodChannelVVideoCompressor extends VVideoCompressorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('v_video_compressor');

  /// The event channel for progress updates
  final eventChannel = const EventChannel('v_video_compressor/progress');

  Map<String, dynamic> _compressionConfigForChannel(
    VVideoCompressionConfig config,
  ) {
    final map = config.toMap();
    final advanced = config.advanced;
    final requiresEncodedOutput =
        !config.includeAudio ||
        (advanced != null &&
            ((advanced.cropRect != null && !advanced.cropRect!.isFullFrame()) ||
                (advanced.trimStartMs ?? 0) > 0 ||
                advanced.trimEndMs != null ||
                (advanced.rotation ?? 0) != 0 ||
                advanced.customWidth != null ||
                advanced.customHeight != null ||
                advanced.removeAudio == true ||
                advanced.videoCodec != null ||
                advanced.audioCodec != null));
    if (requiresEncodedOutput) {
      map['fallbackToOriginalIfNotSmaller'] = false;
    }
    return map;
  }

  @override
  Future<String?> getPlatformVersion() async {
    final stopwatch = Stopwatch()..start();
    try {
      VVideoLogger.methodCall('getPlatformVersion', null);

      final version = await methodChannel.invokeMethod<String>(
        'getPlatformVersion',
      );

      stopwatch.stop();
      VVideoLogger.info(
        'getPlatformVersion completed (${stopwatch.elapsedMilliseconds}ms)',
      );

      return version;
    } catch (error, stackTrace) {
      stopwatch.stop();
      VVideoLogger.error('Failed to get platform version', error, stackTrace);
      return null;
    }
  }

  /// Helper method to convert Map\<Object?, Object?\> to Map\<String, dynamic\>
  /// Recursively handles nested maps and lists
  Map<String, dynamic> _convertToStringMap(Map<Object?, Object?> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      final stringKey = key.toString();
      if (value is Map<Object?, Object?>) {
        result[stringKey] = _convertToStringMap(value);
      } else if (value is List) {
        result[stringKey] = value.map((item) {
          if (item is Map<Object?, Object?>) {
            return _convertToStringMap(item);
          }
          return item;
        }).toList();
      } else {
        result[stringKey] = value;
      }
    });
    return result;
  }

  @override
  Future<VVideoInfo?> getVideoInfo(String videoPath) async {
    final stopwatch = Stopwatch()..start();
    try {
      VVideoLogger.methodCall('getVideoInfo', {'videoPath': videoPath});

      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getVideoInfo',
        {'videoPath': videoPath},
      );

      stopwatch.stop();

      if (result != null) {
        final videoInfo = VVideoInfo.fromMap(_convertToStringMap(result));
        VVideoLogger.info(
          'getVideoInfo completed (${stopwatch.elapsedMilliseconds}ms) - ${videoInfo.name} (${videoInfo.fileSizeFormatted}, ${videoInfo.durationFormatted})',
        );
        return videoInfo;
      } else {
        VVideoLogger.warning('No video info returned for path: $videoPath');
        return null;
      }
    } catch (error, stackTrace) {
      stopwatch.stop();
      VVideoLogger.error(
        'Error getting video info for path: $videoPath',
        error,
        stackTrace,
      );
      return null;
    }
  }

  @override
  Future<VVideoCompressionEstimate?> getCompressionEstimate(
    String videoPath,
    VVideoCompressQuality quality, {
    VVideoAdvancedConfig? advanced,
  }) async {
    try {
      final params = <String, dynamic>{
        'videoPath': videoPath,
        'quality': quality.value,
      };

      // Add advanced configuration if provided
      if (advanced != null) {
        params['advanced'] = advanced.toMap();
      }

      VVideoLogger.methodCall('getCompressionEstimate', params);
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getCompressionEstimate',
        params,
      );

      if (result != null) {
        final estimate = VVideoCompressionEstimate.fromMap(
          _convertToStringMap(result),
        );
        VVideoLogger.success('getCompressionEstimate', {
          'estimatedSize': estimate.estimatedSizeFormatted,
          'compressionRatio':
              '${(estimate.compressionRatio * 100).toStringAsFixed(1)}%',
        });
        return estimate;
      }
      VVideoLogger.warning('No compression estimate returned');
      return null;
    } catch (error, stackTrace) {
      VVideoLogger.error(
        'Error getting compression estimate',
        error,
        stackTrace,
      );
      return null;
    }
  }

  @override
  Future<VVideoCompressionResult?> compressVideo(
    String videoPath,
    VVideoCompressionConfig config, {
    void Function(double progress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    StreamSubscription<dynamic>? progressSubscription;

    try {
      VVideoLogger.methodCall('compressVideo', {
        'videoPath': videoPath,
        'quality': config.quality.value,
        'hasAdvanced': config.advanced != null,
        'hasProgressCallback': onProgress != null,
      });

      // Validate configuration before proceeding
      if (!config.isValid()) {
        throw ArgumentError('Invalid compression configuration');
      }

      // Set up progress listener if callback provided
      if (onProgress != null) {
        VVideoLogger.info('Setting up progress listener for compression');
        progressSubscription = eventChannel.receiveBroadcastStream().listen(
          (event) {
            final progressEvent = VVideoProgressEvent.fromMap(
              Map<String, dynamic>.from(event as Map),
            );
            VVideoLogger.progress('Compression', progressEvent.progress);
            onProgress(progressEvent.progress);
          },
          onError: (error) {
            VVideoLogger.error('Progress subscription error', error, null);
          },
        );
      }

      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'compressVideo',
        {
          'videoPath': videoPath,
          'config': _compressionConfigForChannel(config),
        },
      );

      // Cancel progress subscription
      await progressSubscription?.cancel();
      stopwatch.stop();

      if (result != null) {
        final compressionResult = VVideoCompressionResult.fromMap(
          _convertToStringMap(result),
        );
        VVideoLogger.success('compressVideo', {
          'originalSize': compressionResult.originalSizeFormatted,
          'compressedSize': compressionResult.compressedSizeFormatted,
          'reduction': '${compressionResult.compressionPercentage}%',
        });
        return compressionResult;
      } else {
        VVideoLogger.warning('No compression result returned');
        return null;
      }
    } catch (error, stackTrace) {
      await progressSubscription?.cancel();
      stopwatch.stop();
      VVideoLogger.error(
        'Video compression failed for: $videoPath',
        error,
        stackTrace,
      );
      return null;
    }
  }

  @override
  Future<List<VVideoCompressionResult>> compressVideos(
    List<String> videoPaths,
    VVideoCompressionConfig config, {
    void Function(double progress, int currentIndex, int total)? onProgress,
  }) async {
    try {
      VVideoLogger.methodCall('compressVideos', {
        'videoCount': videoPaths.length,
        'quality': config.quality.value,
      });

      // Validate configuration before proceeding
      if (!config.isValid()) {
        throw ArgumentError('Invalid compression configuration');
      }

      // Set up progress listener if callback provided
      StreamSubscription<dynamic>? progressSubscription;
      if (onProgress != null) {
        progressSubscription = eventChannel.receiveBroadcastStream().listen((
          event,
        ) {
          final progressEvent = VVideoProgressEvent.fromMap(
            Map<String, dynamic>.from(event as Map),
          );
          if (progressEvent.isBatchOperation) {
            onProgress(
              progressEvent.progress,
              progressEvent.currentIndex!,
              progressEvent.total!,
            );
          }
        });
      }

      final result = await methodChannel.invokeMethod<List<Object?>>(
        'compressVideos',
        {
          'videoPaths': videoPaths,
          'config': _compressionConfigForChannel(config),
        },
      );

      // Cancel progress subscription
      await progressSubscription?.cancel();

      if (result != null) {
        final results = result
            .cast<Map<Object?, Object?>>()
            .map(
              (map) =>
                  VVideoCompressionResult.fromMap(_convertToStringMap(map)),
            )
            .toList();
        VVideoLogger.success('compressVideos', {'count': results.length});
        return results;
      }
      return [];
    } catch (error, stackTrace) {
      VVideoLogger.error('Error compressing videos', error, stackTrace);
      return [];
    }
  }

  @override
  Future<void> cancelCompression() async {
    try {
      VVideoLogger.methodCall('cancelCompression', null);
      await methodChannel.invokeMethod('cancelCompression');
      VVideoLogger.success('cancelCompression', null);
    } catch (error, stackTrace) {
      VVideoLogger.error('Error canceling compression', error, stackTrace);
    }
  }

  @override
  Future<bool> isCompressing() async {
    try {
      VVideoLogger.methodCall('isCompressing', null);
      final result = await methodChannel.invokeMethod<bool>('isCompressing');
      VVideoLogger.success('isCompressing', {'result': result ?? false});
      return result ?? false;
    } catch (error, stackTrace) {
      VVideoLogger.error(
        'Error checking compression status',
        error,
        stackTrace,
      );
      return false;
    }
  }

  @override
  Future<VVideoThumbnailResult?> getVideoThumbnail(
    String videoPath,
    VVideoThumbnailConfig config,
  ) async {
    try {
      VVideoLogger.methodCall('getVideoThumbnail', {
        'videoPath': videoPath,
        'timeMs': config.timeMs,
      });

      // Validate configuration before proceeding
      if (!config.isValid()) {
        throw ArgumentError('Invalid thumbnail configuration');
      }

      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getVideoThumbnail',
        {'videoPath': videoPath, 'config': config.toMap()},
      );

      if (result != null) {
        final thumbnail = VVideoThumbnailResult.fromMap(
          _convertToStringMap(result),
        );
        VVideoLogger.success('getVideoThumbnail', {
          'path': thumbnail.thumbnailPath,
          'size': '${thumbnail.width}x${thumbnail.height}',
        });
        return thumbnail;
      }
      VVideoLogger.warning('No thumbnail result returned');
      return null;
    } catch (error, stackTrace) {
      VVideoLogger.error('Error generating video thumbnail', error, stackTrace);
      return null;
    }
  }

  @override
  Future<List<VVideoThumbnailResult>> getVideoThumbnails(
    String videoPath,
    List<VVideoThumbnailConfig> configs,
  ) async {
    try {
      VVideoLogger.methodCall('getVideoThumbnails', {
        'videoPath': videoPath,
        'configCount': configs.length,
      });

      // Validate all configurations before proceeding
      for (final config in configs) {
        if (!config.isValid()) {
          throw ArgumentError('Invalid thumbnail configuration');
        }
      }

      final result = await methodChannel.invokeMethod<List<Object?>>(
        'getVideoThumbnails',
        {
          'videoPath': videoPath,
          'configs': configs.map((config) => config.toMap()).toList(),
        },
      );

      if (result != null) {
        final thumbnails = result
            .cast<Map<Object?, Object?>>()
            .map(
              (map) => VVideoThumbnailResult.fromMap(_convertToStringMap(map)),
            )
            .toList();
        VVideoLogger.success('getVideoThumbnails', {
          'count': thumbnails.length,
        });
        return thumbnails;
      }
      return [];
    } catch (error, stackTrace) {
      VVideoLogger.error(
        'Error generating video thumbnails',
        error,
        stackTrace,
      );
      return [];
    }
  }

  @override
  Future<void> cleanup() async {
    try {
      VVideoLogger.methodCall('cleanup', null);
      await methodChannel.invokeMethod('cleanup');
      VVideoLogger.success('cleanup', null);
    } catch (error, stackTrace) {
      VVideoLogger.error('Error during cleanup', error, stackTrace);
    }
  }

  @override
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
      await methodChannel.invokeMethod('cleanupFiles', {
        'deleteThumbnails': deleteThumbnails,
        'deleteCompressedVideos': deleteCompressedVideos,
        'clearCache': clearCache,
      });
      VVideoLogger.success('cleanupFiles', {
        'deleteThumbnails': deleteThumbnails,
        'deleteCompressedVideos': deleteCompressedVideos,
        'clearCache': clearCache,
      });
    } catch (error, stackTrace) {
      VVideoLogger.error('Error during cleanup files', error, stackTrace);
    }
  }
}
