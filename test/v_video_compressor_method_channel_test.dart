import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_video_compressor/v_video_compressor.dart';
import 'package:v_video_compressor/v_video_compressor_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelVVideoCompressor platform = MethodChannelVVideoCompressor();
  const MethodChannel channel = MethodChannel('v_video_compressor');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test(
    'compressVideo sends fallback option and decodes original-file flag',
    () async {
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            capturedCall = methodCall;
            return {
              'originalVideo': {
                'path': '/input.mov',
                'name': 'input.mov',
                'fileSizeBytes': 100,
                'durationMillis': 1000,
                'width': 100,
                'height': 100,
              },
              'compressedFilePath': '/input.mov',
              'originalSizeBytes': 100,
              'compressedSizeBytes': 100,
              'compressionRatio': 1.0,
              'timeTaken': 10,
              'quality': 'MEDIUM',
              'originalResolution': '100x100',
              'compressedResolution': '100x100',
              'spaceSaved': 0,
              'usedOriginalFile': true,
            };
          });

      final result = await platform.compressVideo(
        '/input.mov',
        const VVideoCompressionConfig.medium(
          fallbackToOriginalIfNotSmaller: false,
        ),
      );

      final arguments = capturedCall!.arguments as Map<Object?, Object?>;
      final config = arguments['config'] as Map<Object?, Object?>;
      expect(config['fallbackToOriginalIfNotSmaller'], isFalse);
      expect(result!.usedOriginalFile, isTrue);
    },
  );

  test(
    'compressVideo sends nested crop and suppresses edited fallback',
    () async {
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            capturedCall = methodCall;
            return null;
          });

      await platform.compressVideo(
        '/input.mp4',
        const VVideoCompressionConfig.medium(
          fallbackToOriginalIfNotSmaller: true,
          advanced: VVideoAdvancedConfig(
            trimStartMs: 100,
            rotation: 90,
            cropRect: VVideoCropRect(
              left: 0,
              top: 0.25,
              right: 0.5,
              bottom: 0.75,
            ),
          ),
        ),
      );

      final arguments = capturedCall!.arguments as Map<Object?, Object?>;
      final config = arguments['config'] as Map<Object?, Object?>;
      final advanced = config['advanced'] as Map<Object?, Object?>;
      expect(config['fallbackToOriginalIfNotSmaller'], isFalse);
      expect(advanced['cropRect'], {
        'left': 0.0,
        'top': 0.25,
        'right': 0.5,
        'bottom': 0.75,
      });
    },
  );

  test('full-frame crop preserves requested fallback', () async {
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          capturedCall = methodCall;
          return null;
        });

    await platform.compressVideo(
      '/input.mp4',
      const VVideoCompressionConfig.medium(
        advanced: VVideoAdvancedConfig(
          rotation: 0,
          cropRect: VVideoCropRect(left: 0, top: 0, right: 1, bottom: 1),
        ),
      ),
    );

    final arguments = capturedCall!.arguments as Map<Object?, Object?>;
    final config = arguments['config'] as Map<Object?, Object?>;
    expect(config['fallbackToOriginalIfNotSmaller'], isTrue);
  });
}
