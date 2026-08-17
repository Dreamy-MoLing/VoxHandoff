import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android main manifest keeps the mobile MVP permissions', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue);

    final source = manifest.readAsStringSync();
    expect(source, contains('android.permission.INTERNET'));
    expect(source, contains('android.permission.CAMERA'));
    expect(source, contains('android.permission.RECORD_AUDIO'));
    expect(source, contains('android:allowBackup="false"'));
  });
}
