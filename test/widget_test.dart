// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_video/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is displayed
    expect(find.text('AI Video App'), findsOneWidget);

    // Verify that main navigation buttons are present
    expect(find.text('下載影片 (YouTube/M3U8)'), findsOneWidget);
    expect(find.text('提取字幕 (Whisper AI)'), findsOneWidget);
    expect(find.text('加字幕入影片'), findsOneWidget);
  });
}
