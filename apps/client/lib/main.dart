import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/agent_talk_app.dart';
import 'infrastructure/security/flutter_secure_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.environment['VOXHANDOFF_SECURE_STORAGE_SELF_TEST'] == '1') {
    await _runSecureStorageSelfTest();
    exit(exitCode);
  }
  runApp(const ProviderScope(child: AgentTalkApp()));
}

Future<void> _runSecureStorageSelfTest() async {
  const key = 'voxhandoff.v1.platform-self-test';
  const expected = 'non-secret-round-trip';
  final store = FlutterSecureValueStore();
  try {
    await store.write(key, expected);
    if (await store.read(key) != expected) {
      stderr.writeln('secure storage self-test failed at read-back');
      exitCode = 1;
      return;
    }
  } finally {
    await store.delete(key);
  }
  if (await store.read(key) != null) {
    stderr.writeln('secure storage self-test failed at cleanup');
    exitCode = 1;
    return;
  }
  stdout.writeln('secure storage self-test passed');
}
