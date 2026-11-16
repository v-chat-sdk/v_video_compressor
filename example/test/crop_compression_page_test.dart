import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_video_compressor/v_video_compressor.dart';
import 'package:v_video_compressor_example/crop_compression_page.dart';

void main() {
  const videoInfo = VVideoInfo(
    path: '/tmp/input.mp4',
    name: 'input.mp4',
    fileSizeBytes: 1024,
    durationMillis: 4000,
    width: 1280,
    height: 720,
  );

  Widget app({required ValueChanged<VVideoCompressionConfig> onCompress}) {
    return MaterialApp(
      home: CropCompressionPage(
        videoPath: videoInfo.path,
        videoInfo: videoInfo,
        onCompress: onCompress,
      ),
    );
  }

  testWidgets('exports a normalized quadrant crop configuration', (
    tester,
  ) async {
    VVideoCompressionConfig? exported;
    await tester.pumpWidget(app(onCompress: (value) => exported = value));

    expect(find.text('Full frame — crop is a no-op'), findsOneWidget);
    final topLeftPreset = find.text('Top left');
    await tester.scrollUntilVisible(
      topLeftPreset,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(topLeftPreset);
    await tester.pump();
    await tester.tap(topLeftPreset);
    await tester.pump();

    final previewDescriptionFinder = find.byKey(
      const Key('cropPreviewDescription'),
    );
    await tester.scrollUntilVisible(
      previewDescriptionFinder,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    final previewDescription = tester.widget<Text>(previewDescriptionFinder);
    expect(
      previewDescription.data,
      'Selected 50% × 50% of the rotated video preview',
    );

    final exportButton = find.byKey(const Key('exportCropButton'));
    await tester.scrollUntilVisible(
      exportButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(exportButton);
    await tester.pump();
    await tester.tap(exportButton);
    await tester.pumpAndSettle();

    expect(exported, isNotNull);
    expect(exported!.fallbackToOriginalIfNotSmaller, isFalse);
    expect(exported!.includeAudio, isTrue);
    expect(exported!.advanced?.videoCodec, VVideoCodec.h264);
    expect(
      exported!.advanced?.cropRect,
      const VVideoCropRect(left: 0, top: 0, right: 0.5, bottom: 0.5),
    );
  });

  testWidgets('shows invalid crop coordinates without exporting', (
    tester,
  ) async {
    VVideoCompressionConfig? exported;
    await tester.pumpWidget(app(onCompress: (value) => exported = value));

    await tester.scrollUntilVisible(
      find.byKey(const Key('cropLeftField')),
      300,
    );
    await tester.enterText(find.byKey(const Key('cropLeftField')), '0.8');
    await tester.enterText(find.byKey(const Key('cropRightField')), '0.2');

    final exportButton = find.byKey(const Key('exportCropButton'));
    await tester.ensureVisible(exportButton);
    await tester.tap(exportButton);
    await tester.pump();

    expect(find.byKey(const Key('cropValidationError')), findsOneWidget);
    expect(exported, isNull);
  });
}
