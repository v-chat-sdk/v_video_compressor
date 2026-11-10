import 'package:flutter_test/flutter_test.dart';
import 'package:v_video_compressor/v_video_compressor.dart';

void main() {
  group('VVideoCropRect', () {
    const crop = VVideoCropRect(
      left: 0.125,
      top: 0.25,
      right: 0.875,
      bottom: 0.75,
    );

    test('serializes and deserializes exactly', () {
      final decoded = VVideoCropRect.fromMap(crop.toMap());

      expect(decoded, crop);
      expect(decoded.hashCode, crop.hashCode);
      expect(
        decoded.toString(),
        'VVideoCropRect(left: 0.125, top: 0.25, right: 0.875, bottom: 0.75)',
      );
    });

    test('full frame is valid and a no-op', () {
      const fullFrame = VVideoCropRect(left: 0, top: 0, right: 1, bottom: 1);
      const roundedFullFrame = VVideoCropRect(
        left: 0.0000005,
        top: 0,
        right: 0.9999995,
        bottom: 1,
      );

      expect(fullFrame.isValid(), isTrue);
      expect(fullFrame.isFullFrame(), isTrue);
      expect(roundedFullFrame.isFullFrame(), isTrue);
      expect(crop.isFullFrame(), isFalse);
    });

    test('rejects every malformed coordinate shape', () {
      final invalid = <VVideoCropRect>[
        const VVideoCropRect(left: double.nan, top: 0, right: 1, bottom: 1),
        const VVideoCropRect(
          left: 0,
          top: 0,
          right: double.infinity,
          bottom: 1,
        ),
        const VVideoCropRect(left: -0.1, top: 0, right: 1, bottom: 1),
        const VVideoCropRect(left: 0, top: 0, right: 1.1, bottom: 1),
        const VVideoCropRect(left: 0.5, top: 0, right: 0.5, bottom: 1),
        const VVideoCropRect(left: 0, top: 0.5, right: 1, bottom: 0.5),
        const VVideoCropRect(left: 0.75, top: 0, right: 0.25, bottom: 1),
        const VVideoCropRect(left: 0, top: 0.75, right: 1, bottom: 0.25),
      ];

      for (final rect in invalid) {
        expect(rect.isValid(), isFalse, reason: rect.toString());
      }
    });

    test('advanced validation includes crop validation', () {
      expect(const VVideoAdvancedConfig(cropRect: crop).isValid(), isTrue);
      expect(
        const VVideoAdvancedConfig(
          cropRect: VVideoCropRect(left: 0.5, top: 0, right: 0.5, bottom: 1),
        ).isValid(),
        isFalse,
      );
    });

    test('advanced serialization omits crop when absent', () {
      final legacyMap = const VVideoAdvancedConfig(rotation: 90).toMap();
      expect(legacyMap.containsKey('cropRect'), isFalse);

      final decoded = VVideoAdvancedConfig.fromMap(legacyMap);
      expect(decoded.cropRect, isNull);
      expect(decoded.rotation, 90);
    });

    test('advanced serialization contains exact nested crop map', () {
      final map = const VVideoAdvancedConfig(cropRect: crop).toMap();
      expect(map['cropRect'], crop.toMap());

      final decoded = VVideoAdvancedConfig.fromMap(map);
      expect(decoded.cropRect, crop);
    });
  });
}
