import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:v_video_compressor/v_video_compressor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const inspectionChannel = MethodChannel(
    'v_video_compressor_example/inspection',
  );
  final compressor = VVideoCompressor();
  late Directory directory;
  late String inputPath;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vvc_frame_rate_');
    inputPath = '${directory.path}/source.mp4';
    final fixture = await rootBundle.load(
      'assets/test_videos/quadrants_h264_aac.mp4',
    );
    await File(inputPath).writeAsBytes(fixture.buffer.asUint8List());
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  const cases = <String, ({VVideoAdvancedConfig advanced, double fps})>{
    'frame rate alone': (
      advanced: VVideoAdvancedConfig(frameRate: 24),
      fps: 24,
    ),
    'resize, trim and orientation correction': (
      advanced: VVideoAdvancedConfig(
        customWidth: 320,
        customHeight: 240,
        frameRate: 24,
        trimStartMs: 0,
        trimEndMs: 2000,
        autoCorrectOrientation: true,
      ),
      fps: 24,
    ),
    'rotation': (
      advanced: VVideoAdvancedConfig(frameRate: 10, rotation: 180),
      fps: 10,
    ),
    'crop': (
      advanced: VVideoAdvancedConfig(
        frameRate: 24,
        cropRect: VVideoCropRect(left: 0, top: 0, right: 0.75, bottom: 1),
      ),
      fps: 24,
    ),
    'full-frame crop': (
      advanced: VVideoAdvancedConfig(
        frameRate: 10,
        cropRect: VVideoCropRect(left: 0, top: 0, right: 1, bottom: 1),
      ),
      fps: 10,
    ),
    'fractional rate rounds to an integer': (
      advanced: VVideoAdvancedConfig(frameRate: 23.976),
      fps: 24,
    ),
    'sub-one rate rounds up to one': (
      advanced: VVideoAdvancedConfig(frameRate: 0.5),
      fps: 1,
    ),
    'default without crop': (
      advanced: VVideoAdvancedConfig(autoCorrectOrientation: true),
      fps: 30,
    ),
    'default with crop': (
      advanced: VVideoAdvancedConfig(
        cropRect: VVideoCropRect(left: 0, top: 0, right: 0.75, bottom: 1),
      ),
      fps: 30,
    ),
  };

  for (final entry in cases.entries) {
    testWidgets('iOS frame rate: ${entry.key}', (tester) async {
      final outputPath = '${directory.path}/output';
      final result = await compressor.compressVideo(
        inputPath,
        VVideoCompressionConfig(
          quality: VVideoCompressQuality.high,
          advanced: entry.value.advanced,
          outputPath: outputPath,
          fallbackToOriginalIfNotSmaller: false,
        ),
      );
      expect(result, isNotNull);
      expect(result!.compressedFilePath, startsWith('$outputPath/'));
      final info = await inspectionChannel.invokeMapMethod<String, dynamic>(
        'inspectVideo',
        {'path': result.compressedFilePath},
      );
      expect(info, isNotNull);
      expect(info!['isPlayable'], isTrue);
      expect(info['hasVideo'], isTrue);
      expect(info['videoFrameRate'], closeTo(entry.value.fps, 0.1));
      final trimmed = entry.value.advanced.trimEndMs != null;
      expect(info['durationMillis'], closeTo(trimmed ? 2000 : 4000, 150));
      // ignore: avoid_print
      print('${entry.key}: ${info['videoFrameRate']} fps');
    }, skip: !Platform.isIOS);
  }

  testWidgets('iOS frame-rate-only edit preserves portrait geometry', (
    tester,
  ) async {
    final fixture = await rootBundle.load(
      'assets/test_videos/quadrants_portrait_metadata.mp4',
    );
    await File(inputPath).writeAsBytes(fixture.buffer.asUint8List());
    final before = await inspectionChannel.invokeMapMethod<String, dynamic>(
      'inspectVideo',
      {'path': inputPath},
    );
    final result = await compressor.compressVideo(
      inputPath,
      VVideoCompressionConfig(
        quality: VVideoCompressQuality.high,
        advanced: const VVideoAdvancedConfig(frameRate: 24),
        outputPath: '${directory.path}/portrait',
        fallbackToOriginalIfNotSmaller: false,
      ),
    );
    expect(result, isNotNull);
    final after = await inspectionChannel.invokeMapMethod<String, dynamic>(
      'inspectVideo',
      {'path': result!.compressedFilePath},
    );
    expect(after!['videoFrameRate'], closeTo(24, 0.1));
    expect(after['width'], before!['width']);
    expect(after['height'], before['height']);
    expect(after['isPlayable'], isTrue);
  }, skip: !Platform.isIOS);

  for (final rate in [double.nan, double.infinity, 2147483648.0]) {
    testWidgets('iOS rejects unsafe frame rate $rate', (tester) async {
      final result = await compressor.compressVideo(
        inputPath,
        VVideoCompressionConfig(
          quality: VVideoCompressQuality.high,
          advanced: VVideoAdvancedConfig(frameRate: rate),
          outputPath: '${directory.path}/invalid',
        ),
      );
      expect(result, isNull);
      expect(Directory('${directory.path}/invalid').existsSync(), isFalse);
    }, skip: !Platform.isIOS);
  }
}
