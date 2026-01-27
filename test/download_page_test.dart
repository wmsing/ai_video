import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_video/features/download/download_page.dart';

void main() {
  testWidgets('DownloadPage renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(
      home: DownloadPage(),
    ));

    // Verify that the page title is displayed
    expect(find.text('Download'), findsOneWidget);

    // Verify that the URL input field is present
    expect(find.byType(TextField), findsNWidgets(2)); // URL and name fields

    // Verify that the submit button is present
    expect(find.text('下載'), findsOneWidget);

    // No scroll view in this UI
  });

  testWidgets('DownloadPage URL input works', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DownloadPage(),
    ));

    // Find the URL text field
    final urlField = find.byType(TextField).first;

    // Enter a test URL
    await tester.enterText(urlField, 'https://example.com/test.mp4');

    // Verify the text was entered
    expect(find.text('https://example.com/test.mp4'), findsOneWidget);
  });
}