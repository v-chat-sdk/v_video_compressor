import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:v_video_compressor/v_video_compressor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const runNetworkIntegration = bool.fromEnvironment(
    'VVC_RUN_NETWORK_INTEGRATION',
  );
  // Public H.264/AAC sample used by Flutter's video_player documentation.
  const publicVideoUrl =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
  const inspectionChannel = MethodChannel(
    'v_video_compressor_example/inspection',
  );
  final compressor = VVideoCompressor();
  final generatedFiles = <String>{};

  Future<String> copyFixture(String assetName) async {
    final bytes = await rootBundle.load(assetName);
    final file = File(
      '${Directory.systemTemp.path}/${assetName.split('/').last}',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    generatedFiles.add(file.path);
    return file.path;
  }

  Future<String> downloadPublicVideo() async {
    final output = File(
      '${Directory.systemTemp.path}/flutter_public_bee_'
      '${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    generatedFiles.add(output.path);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(publicVideoUrl));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'v_video_compressor integration test',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'video/mp4');
      if (response.contentLength >= 0) {
        expect(response.contentLength, inInclusiveRange(1000000, 3000000));
      }

      final bytes = BytesBuilder(copy: false);
      await response.timeout(const Duration(seconds: 30)).forEach(bytes.add);
      final downloaded = bytes.takeBytes();
      expect(downloaded.length, inInclusiveRange(1000000, 3000000));
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
    return result ?? <String, dynamic>{};
  }

  Future<VVideoCompressionResult> crop(
    String input,
    VVideoCropRect cropRect, {
    int? rotation,
    int? trimStartMs,
    int? trimEndMs,
    bool removeAudio = false,
  }) async {
    final result = await compressor.compressVideo(
      input,
      VVideoCompressionConfig(
        quality: VVideoCompressQuality.high,
        fallbackToOriginalIfNotSmaller: true,
        advanced: VVideoAdvancedConfig(
          cropRect: cropRect,
          rotation: rotation,
          trimStartMs: trimStartMs,
          trimEndMs: trimEndMs,
          removeAudio: removeAudio,
          videoCodec: VVideoCodec.h264,
        ),
      ),
    );
    expect(result, isNotNull);
    expect(result!.usedOriginalFile, isFalse);
    generatedFiles.add(result.compressedFilePath);
    return result;
  }

  Future<Uint8List> thumbnailPixel(
    String videoPath, {
    double normalizedX = 0.5,
    double normalizedY = 0.5,
  }) async {
    final thumbnail = await compressor.getVideoThumbnail(
      videoPath,
      const VVideoThumbnailConfig(
        timeMs: 250,
        maxWidth: 96,
        maxHeight: 96,
        format: VThumbnailFormat.png,
        quality: 100,
      ),
    );
    expect(thumbnail, isNotNull);
    generatedFiles.add(thumbnail!.thumbnailPath);
    final bytes = await File(thumbnail.thumbnailPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(data, isNotNull);
    final x = ((image.width - 1) * normalizedX)
        .round()
        .clamp(0, image.width - 1)
        .toInt();
    final y = ((image.height - 1) * normalizedY)
        .round()
        .clamp(0, image.height - 1)
        .toInt();
    final offset = (y * image.width + x) * 4;
    final pixel = Uint8List.fromList([
      data!.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
      data.getUint8(offset + 3),
    ]);
    image.dispose();
    codec.dispose();
    return pixel;
  }

  bool isExpectedColor(Uint8List rgba, String color) {
    final red = rgba[0];
    final green = rgba[1];
    final blue = rgba[2];
    return switch (color) {
      'red' => red > 170 && green < 90 && blue < 90,
      'green' => red < 90 && green > 80 && blue < 90,
      'blue' => red < 90 && green < 90 && blue > 150,
      'yellow' => red > 170 && green > 120,
      _ => false,
    };
  }

  void expectEncoderSafeDimensions(
    Map<String, dynamic> info,
    int plannedWidth,
    int plannedHeight,
  ) {
    final width = info['width'] as int;
    final height = info['height'] as int;
    final plannedAspect = plannedWidth / plannedHeight;
    final actualAspect = width / height;

    expect(width.isEven, isTrue);
    expect(height.isEven, isTrue);
    expect(
      width,
      inInclusiveRange(
        (plannedWidth - 32).clamp(16, plannedWidth).toInt(),
        plannedWidth + 32,
      ),
    );
    expect(
      height,
      inInclusiveRange(
        (plannedHeight - 32).clamp(16, plannedHeight).toInt(),
        plannedHeight + 32,
      ),
    );
    expect(
      ((actualAspect - plannedAspect) / plannedAspect).abs(),
      lessThan(0.01),
      reason:
          'The platform encoder materially changed the selected crop aspect',
    );
  }

  setUpAll(() async {
    await copyFixture('assets/test_videos/quadrants_h264_aac.mp4');
    await copyFixture('assets/test_videos/quadrants_portrait_metadata.mp4');
  });

  tearDownAll(() async {
    for (final path in generatedFiles) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  });

  testWidgets('each visible quadrant crops independently', (tester) async {
    final input = '${Directory.systemTemp.path}/quadrants_h264_aac.mp4';
    final cases = <(VVideoCropRect, String)>[
      (const VVideoCropRect(left: 0, top: 0, right: 0.5, bottom: 0.5), 'red'),
      (const VVideoCropRect(left: 0.5, top: 0, right: 1, bottom: 0.5), 'green'),
      (const VVideoCropRect(left: 0, top: 0.5, right: 0.5, bottom: 1), 'blue'),
      (
        const VVideoCropRect(left: 0.5, top: 0.5, right: 1, bottom: 1),
        'yellow',
      ),
    ];

    for (final (rect, color) in cases) {
      final result = await crop(input, rect);
      final info = await inspect(result.compressedFilePath);
      expect(info['hasVideo'], isTrue);
      expect(
        isExpectedColor(await thumbnailPixel(result.compressedFilePath), color),
        isTrue,
        reason: '$color crop did not contain the expected visible region',
      );
      expectEncoderSafeDimensions(info, 160, 120);
    }
  });

  testWidgets('center crop has expected region, dimensions, and audio', (
    tester,
  ) async {
    final result = await crop(
      '${Directory.systemTemp.path}/quadrants_h264_aac.mp4',
      const VVideoCropRect(left: 0.25, top: 0.25, right: 0.75, bottom: 0.75),
      trimStartMs: 500,
      trimEndMs: 2500,
    );
    final info = await inspect(result.compressedFilePath);
    expect(info['hasVideo'], isTrue);
    expect(info['hasAudio'], isTrue);
    expectEncoderSafeDimensions(info, 160, 120);
    expect(info['durationMillis'] as int, closeTo(2000, 300));
    for (final (x, y, color) in <(double, double, String)>[
      (0.25, 0.25, 'red'),
      (0.75, 0.25, 'green'),
      (0.25, 0.75, 'blue'),
      (0.75, 0.75, 'yellow'),
    ]) {
      final pixel = await thumbnailPixel(
        result.compressedFilePath,
        normalizedX: x,
        normalizedY: y,
      );
      expect(
        isExpectedColor(pixel, color),
        isTrue,
        reason: 'Centered crop did not retain its $color region: $pixel',
      );
    }
  });

  testWidgets('portrait metadata and crop plus rotation use displayed space', (
    tester,
  ) async {
    final portrait = await crop(
      '${Directory.systemTemp.path}/quadrants_portrait_metadata.mp4',
      const VVideoCropRect(left: 0, top: 0, right: 1, bottom: 0.5),
    );
    final portraitInfo = await inspect(portrait.compressedFilePath);
    expect(portraitInfo['hasVideo'], isTrue);
    expectEncoderSafeDimensions(portraitInfo, 240, 160);
    for (final (x, color) in <(double, String)>[
      (0.25, 'green'),
      (0.75, 'yellow'),
    ]) {
      expect(
        isExpectedColor(
          await thumbnailPixel(portrait.compressedFilePath, normalizedX: x),
          color,
        ),
        isTrue,
        reason:
            'Portrait metadata crop did not retain its visible $color region',
      );
    }

    final rotated = await crop(
      '${Directory.systemTemp.path}/quadrants_h264_aac.mp4',
      const VVideoCropRect(left: 0, top: 0, right: 0.5, bottom: 1),
      rotation: 90,
    );
    final rotatedInfo = await inspect(rotated.compressedFilePath);
    expect(rotatedInfo['hasVideo'], isTrue);
    expectEncoderSafeDimensions(rotatedInfo, 120, 320);
    for (final (y, color) in <(double, String)>[
      (0.25, 'green'),
      (0.75, 'red'),
    ]) {
      expect(
        isExpectedColor(
          await thumbnailPixel(rotated.compressedFilePath, normalizedY: y),
          color,
        ),
        isTrue,
        reason: 'Crop plus 90-degree rotation lost its $color orientation',
      );
    }
  });

  testWidgets('audio removal still produces a playable cropped video', (
    tester,
  ) async {
    final result = await crop(
      '${Directory.systemTemp.path}/quadrants_h264_aac.mp4',
      const VVideoCropRect(left: 0, top: 0, right: 0.5, bottom: 0.5),
      removeAudio: true,
    );
    final info = await inspect(result.compressedFilePath);
    expect(info['hasVideo'], isTrue);
    expect(info['hasAudio'], isFalse);
    expect(await thumbnailPixel(result.compressedFilePath), hasLength(4));
  });

  testWidgets('downloads a public Flutter video and exports crop on iOS', (
    tester,
  ) async {
    final input = await downloadPublicVideo();
    final sourceInfo = await inspect(input);
    expect(sourceInfo['hasVideo'], isTrue);
    expect(sourceInfo['hasAudio'], isTrue);
    expect(sourceInfo['durationMillis'] as int, closeTo(4037, 300));

    final result = await crop(
      input,
      const VVideoCropRect(left: 0.1, top: 0.1, right: 0.9, bottom: 0.9),
      trimStartMs: 500,
      trimEndMs: 2500,
    );
    final outputInfo = await inspect(result.compressedFilePath);
    expect(outputInfo['hasVideo'], isTrue);
    expect(outputInfo['hasAudio'], isTrue);
    expectEncoderSafeDimensions(outputInfo, 1024, 576);
    expect(outputInfo['durationMillis'] as int, closeTo(2000, 300));
    expect(await thumbnailPixel(result.compressedFilePath), hasLength(4));
  }, skip: !runNetworkIntegration || !Platform.isIOS);
}
