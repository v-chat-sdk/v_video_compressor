// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:v_video_compressor_example/main.dart';

void main() {
  testWidgets('Video Compressor App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is displayed
    expect(find.text('V Video Compressor Example'), findsOneWidget);

    // Verify that the video selection step is displayed
    expect(find.text('Step 1: Select Video'), findsOneWidget);

    // Verify that the select video button is displayed
    expect(find.text('Select Video File'), findsOneWidget);
  });
}
