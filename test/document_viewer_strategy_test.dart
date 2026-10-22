import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline webview viewer assets and dependency are configured', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('flutter_inappwebview:'),
        reason: 'The app should declare the in-app webview dependency for local offline rendering.');
    expect(File('assets/html/docx_viewer.html').existsSync(), isTrue,
        reason: 'DOCX HTML template should be bundled.');
    expect(File('assets/html/pptx_viewer.html').existsSync(), isTrue,
        reason: 'PPTX HTML template should be bundled.');
    expect(pubspec, contains('assets/html/'),
        reason: 'The HTML asset bundle should be registered.');
  });
}
