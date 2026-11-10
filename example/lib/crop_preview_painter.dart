import 'package:flutter/material.dart';
import 'package:v_video_compressor/v_video_compressor.dart';

class CropPreviewPainter extends CustomPainter {
  const CropPreviewPainter({required this.cropRect, required this.colorScheme});

  final VVideoCropRect cropRect;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var index = 1; index < 3; index++) {
      final x = size.width * index / 3;
      final y = size.height * index / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final selected = Rect.fromLTRB(
      cropRect.left * size.width,
      cropRect.top * size.height,
      cropRect.right * size.width,
      cropRect.bottom * size.height,
    );
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.48);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, selected.top), shade);
    canvas.drawRect(
      Rect.fromLTRB(0, selected.bottom, size.width, size.height),
      shade,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, selected.top, selected.left, selected.bottom),
      shade,
    );
    canvas.drawRect(
      Rect.fromLTRB(selected.right, selected.top, size.width, selected.bottom),
      shade,
    );

    final border = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(selected, border);
  }

  @override
  bool shouldRepaint(covariant CropPreviewPainter oldDelegate) {
    return cropRect != oldDelegate.cropRect ||
        colorScheme != oldDelegate.colorScheme;
  }
}
