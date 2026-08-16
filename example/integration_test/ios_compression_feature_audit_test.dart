import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:v_video_compressor/v_video_compressor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const enabled = bool.fromEnvironment('VVC_RUN_IOS_FEATURE_AUDIT');
  const publicVideoUrl =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
  const inspectionChannel = MethodChannel(
    'v_video_compressor_example/inspection',
  );
  const requiredBitrateFeatures = <String>{
    'video bitrate',
    'video bitrate without audio',
    'trimmed video bitrate',
    'trimmed video bitrate without audio',
    'H.265 video bitrate',
  };
  final compressor = VVideoCompressor();
  final generatedFiles = <String>{};
  final generatedDirectories = <String>{};
  final audit = <Map<String, String>>[];
  late String quadrantPath;
  late String portraitPath;
  late String metadataPath;
  late String publicPath;

  Future<String> copyFixture(String assetName) async {
    final data = await rootBundle.load(assetName);
    final output = File(
      '${Directory.systemTemp.path}/'
      '${DateTime.now().microsecondsSinceEpoch}_'
      '${assetName.split('/').last}',
    );
    await output.writeAsBytes(data.buffer.asUint8List(), flush: true);
    generatedFiles.add(output.path);
    return output.path;
  }

  Future<String> downloadPublicVideo() async {
    final output = File(
      '${Directory.systemTemp.path}/vvc_public_bee_'
      '${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    generatedFiles.add(output.path);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(publicVideoUrl));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'v_video_compressor iOS feature audit',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Public fixture returned HTTP ${response.statusCode}',
          uri: Uri.parse(publicVideoUrl),
        );
      }
      final bytes = BytesBuilder(copy: false);
      await response.timeout(const Duration(seconds: 30)).forEach(bytes.add);
      final downloaded = bytes.takeBytes();
      if (downloaded.length < 1000000) {
        throw StateError(
          'Public fixture was unexpectedly small: ${downloaded.length}',
        );
      }
      await output.writeAsBytes(downloaded, flush: true);
      return output.path;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> inspect(String path) async {
    final result = await inspectionChannel.invokeMapMethod<String, dynamic>(
      'inspectVideo',
      {'path': path},
    );
    if (result == null) {
      throw StateError('Native inspection returned null for $path');
    }
    return result;
  }

  double averageTotalBitrate(Map<String, dynamic> info) {
    final durationMillis = (info['durationMillis'] as num).toDouble();
    final fileSizeBytes = (info['fileSizeBytes'] as num).toDouble();
    return fileSizeBytes * 8 * 1000 / durationMillis;
  }

  int maximumBudgetedFileSize(
    Map<String, dynamic> info, {
    required int videoBitrate,
    required double audioBitrate,
  }) {
    final durationSeconds = (info['durationMillis'] as num).toDouble() / 1000;
    final requestedBytes = (videoBitrate + audioBitrate) * durationSeconds / 8;
    // AVAssetExportSession can exceed fileLengthLimit, especially on short
    // clips. Keep the audit bounded while allowing container/startup overhead.
    return (requestedBytes * 1.10 + 64 * 1024).ceil();
  }

  Future<VVideoCompressionResult> compress(
    String input, {
    VVideoCompressQuality quality = VVideoCompressQuality.high,
    VVideoAdvancedConfig? advanced,
    String? outputPath,
    bool deleteOriginal = false,
    bool fallback = false,
    bool saveToGallery = false,
    bool includeAudio = true,
    bool includeMetadata = true,
    bool optimizeForStreaming = true,
    bool copyMetadata = true,
    bool useHardwareAcceleration = true,
    bool useFastStart = true,
    bool useTwoPassEncoding = false,
    bool useVariableBitrate = true,
  }) async {
    final result = await compressor.compressVideo(
      input,
      VVideoCompressionConfig(
        quality: quality,
        advanced: advanced,
        outputPath: outputPath,
        deleteOriginal: deleteOriginal,
        fallbackToOriginalIfNotSmaller: fallback,
        saveToGallery: saveToGallery,
        includeAudio: includeAudio,
        includeMetadata: includeMetadata,
        optimizeForStreaming: optimizeForStreaming,
        copyMetadata: copyMetadata,
        useHardwareAcceleration: useHardwareAcceleration,
        useFastStart: useFastStart,
        useTwoPassEncoding: useTwoPassEncoding,
        useVariableBitrate: useVariableBitrate,
      ),
    );
    if (result == null) {
      throw StateError('Compression returned null');
    }
    if (result.compressedFilePath != input) {
      generatedFiles.add(result.compressedFilePath);
    }
    return result;
  }

  Future<_ImageStats> imageStats(String videoPath) async {
    final thumbnail = await compressor.getVideoThumbnail(
      videoPath,
      const VVideoThumbnailConfig(
        timeMs: 500,
        maxWidth: 96,
        maxHeight: 96,
        format: VThumbnailFormat.png,
        quality: 100,
      ),
    );
    if (thumbnail == null) {
      throw StateError('Thumbnail generation failed');
    }
    generatedFiles.add(thumbnail.thumbnailPath);
    final bytes = await File(thumbnail.thumbnailPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      throw StateError('Thumbnail pixel decoding failed');
    }
    var lumaTotal = 0.0;
    var lumaSquaredTotal = 0.0;
    var saturationTotal = 0.0;
    final pixelCount = image.width * image.height;
    for (var offset = 0; offset < data.lengthInBytes; offset += 4) {
      final red = data.getUint8(offset).toDouble();
      final green = data.getUint8(offset + 1).toDouble();
      final blue = data.getUint8(offset + 2).toDouble();
      final luma = red * 0.2126 + green * 0.7152 + blue * 0.0722;
      lumaTotal += luma;
      lumaSquaredTotal += luma * luma;
      final maximum = [red, green, blue].reduce((a, b) => a > b ? a : b);
      final minimum = [red, green, blue].reduce((a, b) => a < b ? a : b);
      saturationTotal += maximum - minimum;
    }
    final mean = lumaTotal / pixelCount;
    final variance = lumaSquaredTotal / pixelCount - mean * mean;
    image.dispose();
    codec.dispose();
    return _ImageStats(
      luma: mean,
      contrast: variance > 0 ? variance.sqrt() : 0,
      saturation: saturationTotal / pixelCount,
    );
  }

  int atomOffset(Uint8List bytes, String atom) {
    final target = ascii.encode(atom);
    for (var index = 0; index <= bytes.length - target.length; index++) {
      var matches = true;
      for (var offset = 0; offset < target.length; offset++) {
        if (bytes[index + offset] != target[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) return index;
    }
    return -1;
  }

  void outcome(String feature, String status, String expected, String actual) {
    final entry = {
      'feature': feature,
      'status': status,
      'expected': expected,
      'actual': actual,
    };
    audit.add(entry);
    // Intentionally machine-readable for the opt-in simulator audit command.
    // ignore: avoid_print
    print('VVC_IOS_AUDIT|${jsonEncode(entry)}');
  }

  Future<void> verify(
    String feature,
    String expected,
    Future<({bool passed, String actual})> Function() body,
  ) async {
    try {
      final result = await body();
      outcome(
        feature,
        result.passed ? 'PASS' : 'FAIL',
        expected,
        result.actual,
      );
    } catch (error) {
      outcome(feature, 'FAIL', expected, '$error');
    }
  }

  Future<void> unsupportedSmoke(
    String feature,
    String expected,
    VVideoAdvancedConfig advanced,
  ) async {
    try {
      final result = await compress(publicPath, advanced: advanced);
      final info = await inspect(result.compressedFilePath);
      outcome(
        feature,
        'UNSUPPORTED',
        expected,
        'Configuration was accepted and produced playable=${info['isPlayable']}, '
            'but the iOS encoder has no implementation for this field',
      );
    } catch (error) {
      outcome(
        feature,
        'FAIL',
        expected,
        'Configuration caused export failure: $error',
      );
    }
  }

  setUpAll(() async {
    if (!enabled || !Platform.isIOS) return;
    quadrantPath = await copyFixture(
      'assets/test_videos/quadrants_h264_aac.mp4',
    );
    portraitPath = await copyFixture(
      'assets/test_videos/quadrants_portrait_metadata.mp4',
    );
    metadataPath = await copyFixture(
      'assets/test_videos/quadrants_metadata_h264_aac.mp4',
    );
    publicPath = await downloadPublicVideo();
  });

  tearDownAll(() async {
    for (final path in generatedFiles) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    for (final path in generatedDirectories) {
      final directory = Directory(path);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });

  testWidgets(
    'audits every iOS compression configuration feature',
    (tester) async {
      final source = await inspect(publicPath);
      outcome(
        'public simulator download',
        source['hasVideo'] == true && source['hasAudio'] == true
            ? 'PASS'
            : 'FAIL',
        'The iOS simulator downloads a playable public H.264/AAC video',
        '$source',
      );

      for (final quality in VVideoCompressQuality.values) {
        await verify(
          'quality ${quality.value}',
          'Export is playable with video and audio',
          () async {
            final result = await compress(publicPath, quality: quality);
            final info = await inspect(result.compressedFilePath);
            final passed =
                info['isPlayable'] == true &&
                info['hasVideo'] == true &&
                info['hasAudio'] == true;
            return (
              passed: passed,
              actual:
                  '${info['width']}x${info['height']}, ${info['fileSizeBytes']} B',
            );
          },
        );
      }

      await verify(
        'compressedResolution result',
        'Result metadata reports the actual encoded dimensions',
        () async {
          final result = await compress(
            publicPath,
            quality: VVideoCompressQuality.low,
          );
          final info = await inspect(result.compressedFilePath);
          final actualDimensions = '${info['width']}x${info['height']}';
          return (
            passed: result.compressedResolution == actualDimensions,
            actual:
                'result=${result.compressedResolution}, encoded=$actualDimensions',
          );
        },
      );

      await verify(
        'custom output directory',
        'Output is created inside the requested directory',
        () async {
          final directory = Directory(
            '${Directory.systemTemp.path}/vvc_custom_output_'
            '${DateTime.now().microsecondsSinceEpoch}',
          );
          await directory.create(recursive: true);
          generatedDirectories.add(directory.path);
          final result = await compress(
            quadrantPath,
            outputPath: directory.path,
          );
          final passed =
              File(result.compressedFilePath).parent.path == directory.path;
          return (passed: passed, actual: result.compressedFilePath);
        },
      );

      await verify(
        'deleteOriginal',
        'Successful export deletes the copied source file',
        () async {
          final input = await File(quadrantPath).copy(
            '${Directory.systemTemp.path}/vvc_delete_source_'
            '${DateTime.now().microsecondsSinceEpoch}.mp4',
          );
          generatedFiles.add(input.path);
          final result = await compress(input.path, deleteOriginal: true);
          return (
            passed: !await input.exists(),
            actual:
                'inputExists=${await input.exists()}, output=${result.compressedFilePath}',
          );
        },
      );

      await verify(
        'fallback without edits',
        'A non-beneficial no-edit export may return the original',
        () async {
          final result = await compress(quadrantPath, fallback: true);
          return (
            passed: result.usedOriginalFile,
            actual:
                'usedOriginalFile=${result.usedOriginalFile}, ratio=${result.compressionRatio}',
          );
        },
      );

      await verify(
        'fallback with trim',
        'A time edit can never return the unedited original',
        () async {
          final result = await compress(
            quadrantPath,
            fallback: true,
            advanced: const VVideoAdvancedConfig(
              trimStartMs: 500,
              trimEndMs: 2500,
            ),
          );
          final info = await inspect(result.compressedFilePath);
          return (
            passed:
                !result.usedOriginalFile &&
                ((info['durationMillis'] as int) - 2000).abs() <= 300,
            actual:
                'usedOriginalFile=${result.usedOriginalFile}, duration=${info['durationMillis']}ms',
          );
        },
      );

      for (final entry in <(String, bool, VVideoAdvancedConfig?)>[
        ('includeAudio=false', false, null),
        (
          'removeAudio=true',
          true,
          const VVideoAdvancedConfig(removeAudio: true),
        ),
      ]) {
        await verify(entry.$1, 'Output has no audio track', () async {
          final result = await compress(
            quadrantPath,
            includeAudio: entry.$1 != 'includeAudio=false',
            advanced: entry.$3,
          );
          final info = await inspect(result.compressedFilePath);
          return (
            passed: info['hasAudio'] == false,
            actual: 'hasAudio=${info['hasAudio']}',
          );
        });
      }

      await verify(
        'audio preservation',
        'Default export preserves AAC audio',
        () async {
          final result = await compress(publicPath);
          final info = await inspect(result.compressedFilePath);
          return (
            passed: info['hasAudio'] == true && info['audioCodec'] == 'aac ',
            actual: 'hasAudio=${info['hasAudio']}, codec=${info['audioCodec']}',
          );
        },
      );

      for (final codec in VVideoCodec.values) {
        await verify(
          'video codec ${codec.value}',
          'Encoded video uses the requested codec',
          () async {
            final result = await compress(
              publicPath,
              advanced: VVideoAdvancedConfig(videoCodec: codec),
            );
            final info = await inspect(result.compressedFilePath);
            final actual = info['videoCodec'];
            final expected = codec == VVideoCodec.h264 ? 'avc1' : 'hvc1';
            return (
              passed:
                  actual == expected ||
                  (codec == VVideoCodec.h265 && actual == 'hev1'),
              actual: 'codec=$actual',
            );
          },
        );
      }

      for (final codec in VAudioCodec.values) {
        await verify(
          'audio codec ${codec.value}',
          'Encoded audio uses the requested codec',
          () async {
            final result = await compress(
              publicPath,
              advanced: VVideoAdvancedConfig(audioCodec: codec),
            );
            final info = await inspect(result.compressedFilePath);
            final actual = info['audioCodec'];
            final expected = codec == VAudioCodec.aac ? 'aac ' : '.mp3';
            return (passed: actual == expected, actual: 'codec=$actual');
          },
        );
      }

      await verify(
        'video bitrate',
        'A 250 kbps request materially lowers output video bitrate',
        () async {
          final result = await compress(
            publicPath,
            quality: VVideoCompressQuality.low,
            advanced: const VVideoAdvancedConfig(videoBitrate: 250000),
          );
          final info = await inspect(result.compressedFilePath);
          final bitrate = (info['videoEstimatedDataRate'] as num).toDouble();
          final totalBitrate = averageTotalBitrate(info);
          final maximumFileSize = maximumBudgetedFileSize(
            info,
            videoBitrate: 250000,
            audioBitrate: (source['audioEstimatedDataRate'] as num).toDouble(),
          );
          return (
            passed: (info['fileSizeBytes'] as num) <= maximumFileSize,
            actual:
                'estimatedDataRate=${bitrate.round()} bps, '
                'averageTotalBitrate=${totalBitrate.round()} bps, '
                'fileSize=${info['fileSizeBytes']} B, '
                'maximumFileSize=$maximumFileSize B',
          );
        },
      );

      await verify(
        'video bitrate without audio',
        'A video-only 250 kbps request does not reserve an audio budget',
        () async {
          final result = await compress(
            publicPath,
            quality: VVideoCompressQuality.low,
            advanced: const VVideoAdvancedConfig(
              videoBitrate: 250000,
              removeAudio: true,
            ),
          );
          final info = await inspect(result.compressedFilePath);
          final bitrate = (info['videoEstimatedDataRate'] as num).toDouble();
          final totalBitrate = averageTotalBitrate(info);
          final maximumFileSize = maximumBudgetedFileSize(
            info,
            videoBitrate: 250000,
            audioBitrate: 0,
          );
          return (
            passed:
                info['hasAudio'] == false &&
                (info['fileSizeBytes'] as num) <= maximumFileSize,
            actual:
                'hasAudio=${info['hasAudio']}, '
                'estimatedDataRate=${bitrate.round()} bps, '
                'averageTotalBitrate=${totalBitrate.round()} bps, '
                'fileSize=${info['fileSizeBytes']} B, '
                'maximumFileSize=$maximumFileSize B',
          );
        },
      );

      await verify(
        'trimmed video bitrate',
        'A trimmed 250 kbps request budgets only the exported duration',
        () async {
          final result = await compress(
            publicPath,
            quality: VVideoCompressQuality.low,
            advanced: const VVideoAdvancedConfig(
              videoBitrate: 250000,
              trimStartMs: 500,
              trimEndMs: 2500,
            ),
          );
          final info = await inspect(result.compressedFilePath);
          final bitrate = (info['videoEstimatedDataRate'] as num).toDouble();
          final durationMs = (info['durationMillis'] as num).toInt();
          final totalBitrate = averageTotalBitrate(info);
          final maximumFileSize = maximumBudgetedFileSize(
            info,
            videoBitrate: 250000,
            audioBitrate: (source['audioEstimatedDataRate'] as num).toDouble(),
          );
          return (
            passed:
                (info['fileSizeBytes'] as num) <= maximumFileSize &&
                durationMs >= 1700 &&
                durationMs <= 2300,
            actual:
                'durationMs=$durationMs, '
                'estimatedDataRate=${bitrate.round()} bps, '
                'averageTotalBitrate=${totalBitrate.round()} bps, '
                'fileSize=${info['fileSizeBytes']} B, '
                'maximumFileSize=$maximumFileSize B',
          );
        },
      );

      await verify(
        'trimmed video bitrate without audio',
        'A trimmed composition uses its exported duration and no audio budget',
        () async {
          final result = await compress(
            publicPath,
            quality: VVideoCompressQuality.low,
            advanced: const VVideoAdvancedConfig(
              videoBitrate: 250000,
              removeAudio: true,
              trimStartMs: 500,
              trimEndMs: 2500,
            ),
          );
          final info = await inspect(result.compressedFilePath);
          final durationMs = (info['durationMillis'] as num).toInt();
          final totalBitrate = averageTotalBitrate(info);
          final maximumFileSize = maximumBudgetedFileSize(
            info,
            videoBitrate: 250000,
            audioBitrate: 0,
          );
          return (
            passed:
                info['hasAudio'] == false &&
                (info['fileSizeBytes'] as num) <= maximumFileSize &&
                durationMs >= 1700 &&
                durationMs <= 2300,
            actual:
                'hasAudio=${info['hasAudio']}, durationMs=$durationMs, '
                'averageTotalBitrate=${totalBitrate.round()} bps, '
                'fileSize=${info['fileSizeBytes']} B, '
                'maximumFileSize=$maximumFileSize B',
          );
        },
      );

      await verify(
        'H.265 video bitrate',
        'A 1 Mbps explicit bitrate budget also applies to H.265 exports',
        () async {
          final result = await compress(
            publicPath,
            advanced: const VVideoAdvancedConfig(
              videoBitrate: 1000000,
              videoCodec: VVideoCodec.h265,
            ),
          );
          final info = await inspect(result.compressedFilePath);
          final bitrate = (info['videoEstimatedDataRate'] as num).toDouble();
          final totalBitrate = averageTotalBitrate(info);
          final codec = info['videoCodec'];
          final maximumFileSize = maximumBudgetedFileSize(
            info,
            videoBitrate: 1000000,
            audioBitrate: (source['audioEstimatedDataRate'] as num).toDouble(),
          );
          return (
            passed:
                (codec == 'hvc1' || codec == 'hev1') &&
                (info['fileSizeBytes'] as num) <= maximumFileSize,
            actual:
                'codec=$codec, estimatedDataRate=${bitrate.round()} bps, '
                'averageTotalBitrate=${totalBitrate.round()} bps, '
                'fileSize=${info['fileSizeBytes']} B, '
                'maximumFileSize=$maximumFileSize B',
          );
        },
      );

      await verify(
        'audio bitrate',
        'A 32000 bps request produces low-bitrate audio',
        () async {
          final result = await compress(
            publicPath,
            advanced: const VVideoAdvancedConfig(audioBitrate: 32000),
          );
          final info = await inspect(result.compressedFilePath);
          final bitrate = (info['audioEstimatedDataRate'] as num).toDouble();
          return (
            passed: bitrate <= 48000,
            actual: 'estimatedDataRate=${bitrate.round()} bps',
          );
        },
      );

      await verify(
        'frameRate with crop',
        'A 10 fps crop-aware export has approximately 10 fps',
        () async {
          final result = await compress(
            quadrantPath,
            advanced: const VVideoAdvancedConfig(
              frameRate: 10,
              cropRect: VVideoCropRect(left: 0, top: 0, right: 0.75, bottom: 1),
            ),
          );
          final info = await inspect(result.compressedFilePath);
          final fps = (info['videoFrameRate'] as num).toDouble();
          return (passed: (fps - 10).abs() <= 1, actual: 'fps=$fps');
        },
      );

      await verify(
        'frameRate without crop',
        'A standalone 10 fps request has approximately 10 fps',
        () async {
          final result = await compress(
            publicPath,
            advanced: const VVideoAdvancedConfig(frameRate: 10),
          );
          final info = await inspect(result.compressedFilePath);
          final fps = (info['videoFrameRate'] as num).toDouble();
          return (passed: (fps - 10).abs() <= 1, actual: 'fps=$fps');
        },
      );

      await verify(
        'custom dimensions autoAlign',
        'Crop is aspect-preserving, even, and within the custom bounds',
        () async {
          final result = await compress(
            publicPath,
            advanced: const VVideoAdvancedConfig(
              cropRect: VVideoCropRect(
                left: 0.1,
                top: 0.1,
                right: 0.9,
                bottom: 0.9,
              ),
              customWidth: 640,
              customHeight: 360,
              dimensionHandling: VDimensionHandling.autoAlign,
            ),
          );
          final info = await inspect(result.compressedFilePath);
          final width = info['width'] as int;
          final height = info['height'] as int;
          return (
            passed:
                width <= 640 &&
                height <= 360 &&
                width.isEven &&
                height.isEven &&
                ((width / height) - (16 / 9)).abs() < 0.02,
            actual: '${width}x$height',
          );
        },
      );

      await verify(
        'dimension handling exact',
        'Compatible exact dimensions are retained without stretching',
        () async {
          final result = await compress(
            quadrantPath,
            advanced: const VVideoAdvancedConfig(
              cropRect: VVideoCropRect(left: 0, top: 0, right: 0.75, bottom: 1),
              customWidth: 240,
              customHeight: 240,
              dimensionHandling: VDimensionHandling.exact,
            ),
          );
          final info = await inspect(result.compressedFilePath);
          return (
            passed: info['width'] == 240 && info['height'] == 240,
            actual: '${info['width']}x${info['height']}',
          );
        },
      );

      await verify(
        'dimension handling letterbox',
        'Selected crop is centered in a square output canvas',
        () async {
          final result = await compress(
            quadrantPath,
            advanced: const VVideoAdvancedConfig(
              cropRect: VVideoCropRect(left: 0, top: 0, right: 1, bottom: 0.75),
              customWidth: 320,
              customHeight: 320,
              dimensionHandling: VDimensionHandling.letterbox,
            ),
          );
          final info = await inspect(result.compressedFilePath);
          return (
            passed: info['width'] == 320 && info['height'] == 320,
            actual: '${info['width']}x${info['height']}',
          );
        },
      );

      for (final rotation in [0, 90, 180, 270]) {
        await verify(
          'explicit rotation $rotation',
          'Output is playable with the expected displayed dimensions',
          () async {
            final result = await compress(
              quadrantPath,
              advanced: VVideoAdvancedConfig(
                rotation: rotation,
                cropRect: const VVideoCropRect(
                  left: 0,
                  top: 0,
                  right: 0.8,
                  bottom: 0.8,
                ),
              ),
            );
            final info = await inspect(result.compressedFilePath);
            final swaps = rotation == 90 || rotation == 270;
            return (
              passed:
                  info['isPlayable'] == true &&
                  (swaps
                      ? (info['height'] as int) > (info['width'] as int)
                      : (info['width'] as int) > (info['height'] as int)),
              actual:
                  '${info['width']}x${info['height']}, rotation=${info['rotation']}',
            );
          },
        );
      }

      await verify(
        'preferred-transform orientation',
        'Portrait metadata remains portrait and playable',
        () async {
          final result = await compress(
            portraitPath,
            advanced: const VVideoAdvancedConfig(autoCorrectOrientation: true),
          );
          final info = await inspect(result.compressedFilePath);
          return (
            passed:
                info['isPlayable'] == true &&
                (info['height'] as int) > (info['width'] as int),
            actual:
                '${info['width']}x${info['height']}, rotation=${info['rotation']}',
          );
        },
      );

      for (final trim in <(String, int?, int?, int)>[
        ('trim start and end', 500, 2500, 2000),
        ('trim start only', 1000, null, 3000),
        ('trim end only', null, 2000, 2000),
      ]) {
        await verify(trim.$1, 'Output duration is ${trim.$4}ms', () async {
          final result = await compress(
            quadrantPath,
            advanced: VVideoAdvancedConfig(
              trimStartMs: trim.$2,
              trimEndMs: trim.$3,
            ),
          );
          final info = await inspect(result.compressedFilePath);
          final duration = info['durationMillis'] as int;
          return (
            passed: (duration - trim.$4).abs() <= 300,
            actual: 'duration=${duration}ms',
          );
        });
      }

      final baseline = await compress(
        quadrantPath,
        advanced: const VVideoAdvancedConfig(rotation: 0),
      );
      final baselineStats = await imageStats(baseline.compressedFilePath);
      for (final adjustment
          in <(String, VVideoAdvancedConfig, bool Function(_ImageStats))>[
            (
              'brightness positive',
              const VVideoAdvancedConfig(brightness: 0.5),
              (value) => value.luma > baselineStats.luma + 5,
            ),
            (
              'brightness negative',
              const VVideoAdvancedConfig(brightness: -0.5),
              (value) => value.luma < baselineStats.luma - 5,
            ),
            (
              'contrast',
              const VVideoAdvancedConfig(contrast: 0.5),
              (value) => value.contrast > baselineStats.contrast * 1.1,
            ),
            (
              'saturation',
              const VVideoAdvancedConfig(saturation: -1),
              (value) => value.saturation < baselineStats.saturation * 0.3,
            ),
          ]) {
        await verify(
          adjustment.$1,
          'Requested color adjustment measurably changes decoded pixels',
          () async {
            final result = await compress(
              quadrantPath,
              advanced: adjustment.$2,
            );
            final stats = await imageStats(result.compressedFilePath);
            return (
              passed: adjustment.$3(stats),
              actual: 'baseline=$baselineStats, output=$stats',
            );
          },
        );
      }

      await verify(
        'audio sample rate',
        'Requested 22050 Hz audio is encoded at approximately 22050 Hz',
        () async {
          final result = await compress(
            publicPath,
            advanced: const VVideoAdvancedConfig(audioSampleRate: 22050),
          );
          final info = await inspect(result.compressedFilePath);
          final rate = (info['audioSampleRate'] as num).toDouble();
          return (passed: (rate - 22050).abs() < 100, actual: 'rate=$rate');
        },
      );

      for (final request in <(String, VVideoAdvancedConfig)>[
        ('audioChannels=1', const VVideoAdvancedConfig(audioChannels: 1)),
        ('monoAudio=true', const VVideoAdvancedConfig(monoAudio: true)),
      ]) {
        await verify(request.$1, 'Output audio has one channel', () async {
          final result = await compress(publicPath, advanced: request.$2);
          final info = await inspect(result.compressedFilePath);
          return (
            passed: info['audioChannels'] == 1,
            actual: 'channels=${info['audioChannels']}',
          );
        });
      }

      await verify(
        'metadata inclusion disabled',
        'Output does not contain compressor metadata when disabled',
        () async {
          final result = await compress(
            metadataPath,
            includeMetadata: false,
            copyMetadata: false,
          );
          final info = await inspect(result.compressedFilePath);
          final values = (info['metadataValues'] as List<Object?>)
              .map((value) => '$value')
              .toList();
          return (
            passed: !values.contains('Compressed with V Video Compressor'),
            actual: 'metadata=$values',
          );
        },
      );

      await verify(
        'metadata copy',
        'Source title metadata survives when copying is enabled',
        () async {
          final result = await compress(
            metadataPath,
            includeMetadata: true,
            copyMetadata: true,
          );
          final info = await inspect(result.compressedFilePath);
          final values = (info['metadataValues'] as List<Object?>)
              .map((value) => '$value')
              .toList();
          return (
            passed: values.contains('VVC_SOURCE_METADATA'),
            actual: 'metadata=$values',
          );
        },
      );

      await verify(
        'saveToGallery',
        'Result contains a gallery URI after gallery export',
        () async {
          final result = await compress(publicPath, saveToGallery: true);
          return (
            passed: result.galleryUri != null,
            actual: 'galleryUri=${result.galleryUri}',
          );
        },
      );

      await verify(
        'fast start enabled',
        'moov atom precedes mdat for streaming playback',
        () async {
          final result = await compress(publicPath, useFastStart: true);
          final bytes = await File(result.compressedFilePath).readAsBytes();
          final moov = atomOffset(bytes, 'moov');
          final mdat = atomOffset(bytes, 'mdat');
          return (
            passed: moov >= 0 && mdat >= 0 && moov < mdat,
            actual: 'moov=$moov, mdat=$mdat',
          );
        },
      );

      await verify(
        'fast start disabled',
        'Disabling fast start does not force network optimization',
        () async {
          final result = await compress(
            publicPath,
            optimizeForStreaming: false,
            useFastStart: false,
          );
          final bytes = await File(result.compressedFilePath).readAsBytes();
          final moov = atomOffset(bytes, 'moov');
          final mdat = atomOffset(bytes, 'mdat');
          return (
            passed: moov >= 0 && mdat >= 0 && moov > mdat,
            actual: 'moov=$moov, mdat=$mdat',
          );
        },
      );

      for (final unsupported in <(String, String, VVideoAdvancedConfig)>[
        (
          'encodingSpeed',
          'Encoding speed changes the native encoder policy',
          const VVideoAdvancedConfig(encodingSpeed: VEncodingSpeed.fast),
        ),
        (
          'CRF',
          'CRF controls encoded video quality',
          const VVideoAdvancedConfig(crf: 35),
        ),
        (
          'advanced twoPassEncoding',
          'The export honors two-pass encoding',
          const VVideoAdvancedConfig(twoPassEncoding: true),
        ),
        (
          'advanced hardwareAcceleration',
          'The export honors the hardware acceleration selection',
          const VVideoAdvancedConfig(hardwareAcceleration: false),
        ),
        (
          'variableBitrate',
          'The export honors variable versus constant bitrate',
          const VVideoAdvancedConfig(variableBitrate: false),
        ),
        (
          'keyframeInterval',
          'The output uses the requested keyframe interval',
          const VVideoAdvancedConfig(keyframeInterval: 10),
        ),
        (
          'bFrames',
          'The output uses the requested B-frame count',
          const VVideoAdvancedConfig(bFrames: 0),
        ),
        (
          'reducedFrameRate',
          'The output uses the requested reduced frame rate',
          const VVideoAdvancedConfig(reducedFrameRate: 10),
        ),
        (
          'aggressiveCompression',
          'Aggressive compression changes native encoding settings',
          const VVideoAdvancedConfig(aggressiveCompression: true),
        ),
        (
          'noiseReduction',
          'Noise reduction preprocessing is applied',
          const VVideoAdvancedConfig(noiseReduction: true),
        ),
      ]) {
        await unsupportedSmoke(unsupported.$1, unsupported.$2, unsupported.$3);
      }

      outcome(
        'top-level two-pass encoding',
        'UNSUPPORTED',
        'useTwoPassEncoding controls native export passes',
        'The iOS configuration model does not decode this field',
      );
      outcome(
        'top-level hardware acceleration',
        'UNSUPPORTED',
        'useHardwareAcceleration controls native encoding',
        'The iOS configuration model does not decode this field',
      );
      outcome(
        'top-level variable bitrate',
        'UNSUPPORTED',
        'useVariableBitrate controls native rate mode',
        'The iOS configuration model does not decode this field',
      );

      await verify(
        'batch compression',
        'Two inputs produce two playable outputs and reach full progress',
        () async {
          var latestProgress = 0.0;
          final results = await compressor.compressVideos(
            [quadrantPath, portraitPath],
            const VVideoCompressionConfig(
              quality: VVideoCompressQuality.medium,
              fallbackToOriginalIfNotSmaller: false,
            ),
            onProgress: (progress, current, total) {
              latestProgress = progress;
            },
          );
          generatedFiles.addAll(
            results
                .map((result) => result.compressedFilePath)
                .where((path) => path != quadrantPath && path != portraitPath),
          );
          var playable = results.length == 2;
          for (final result in results) {
            playable =
                playable &&
                (await inspect(result.compressedFilePath))['isPlayable'] ==
                    true;
          }
          return (
            passed: playable && latestProgress >= 0.99,
            actual: 'results=${results.length}, latestProgress=$latestProgress',
          );
        },
      );

      await verify(
        'progress and isCompressing',
        'Compression reports active state and emits progress through completion',
        () async {
          final progress = <double>[];
          final subscription = VVideoCompressor.progressStream.listen(
            (event) => progress.add(event.progress),
          );
          var completed = false;
          final future = compress(
            publicPath,
            quality: VVideoCompressQuality.low,
          ).whenComplete(() => completed = true);
          var active = false;
          while (!completed && !active) {
            active = await compressor.isCompressing();
            if (!active) {
              await Future<void>.delayed(const Duration(milliseconds: 2));
            }
          }
          await future;
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await subscription.cancel();
          return (
            passed: active && progress.isNotEmpty && progress.last >= 0.99,
            actual:
                'activeDuringExport=$active, events=${progress.length}, last=${progress.isEmpty ? null : progress.last}',
          );
        },
      );

      await verify(
        'cancellation',
        'An active export can be cancelled and leaves no successful result',
        () async {
          final future = compressor.compressVideo(
            publicPath,
            const VVideoCompressionConfig(
              quality: VVideoCompressQuality.low,
              fallbackToOriginalIfNotSmaller: false,
            ),
          );
          var activeBeforeCancel = false;
          final deadline = DateTime.now().add(const Duration(seconds: 2));
          while (!activeBeforeCancel && DateTime.now().isBefore(deadline)) {
            activeBeforeCancel = await compressor.isCompressing();
            if (!activeBeforeCancel) {
              await Future<void>.delayed(const Duration(milliseconds: 2));
            }
          }
          await compressor.cancelCompression();
          final result = await future;
          final activeAfterCancel = await compressor.isCompressing();
          return (
            passed: activeBeforeCancel && !activeAfterCancel && result == null,
            actual:
                'activeBefore=$activeBeforeCancel, activeAfter=$activeAfterCancel, result=$result',
          );
        },
      );

      final summary = <String, int>{};
      for (final entry in audit) {
        summary.update(
          entry['status']!,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      final bitrateResults = audit
          .where((entry) => requiredBitrateFeatures.contains(entry['feature']))
          .toList();
      final bitrateFailures = bitrateResults
          .where((entry) => entry['status'] != 'PASS')
          .toList();
      expect(bitrateResults, hasLength(requiredBitrateFeatures.length));
      expect(
        bitrateFailures,
        isEmpty,
        reason:
            'Required bitrate regressions failed: ${jsonEncode(bitrateFailures)}',
      );
      // Intentionally machine-readable for the opt-in simulator audit command.
      // ignore: avoid_print
      print('VVC_IOS_AUDIT_SUMMARY|${jsonEncode(summary)}');
      expect(audit.length, greaterThanOrEqualTo(45));
    },
    skip: !enabled || !Platform.isIOS,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

class _ImageStats {
  const _ImageStats({
    required this.luma,
    required this.contrast,
    required this.saturation,
  });

  final double luma;
  final double contrast;
  final double saturation;

  @override
  String toString() {
    return 'luma=${luma.toStringAsFixed(2)}, '
        'contrast=${contrast.toStringAsFixed(2)}, '
        'saturation=${saturation.toStringAsFixed(2)}';
  }
}

extension on double {
  double sqrt() {
    if (this <= 0) return 0;
    var estimate = this;
    for (var index = 0; index < 10; index++) {
      estimate = (estimate + this / estimate) / 2;
    }
    return estimate;
  }
}
