import 'dart:io';

import 'stdio_stt_port.dart';

/// Resolves only application-owned sidecar locations. It never searches PATH
/// and never accepts a command supplied by UI or remote data.
SttSidecarLauncher bundledSttLauncher({required String modelPath}) => () async {
  if (modelPath.trim().isEmpty) {
    throw const ProcessException(
      'voxhandoff-stt',
      <String>[],
      'The configured local STT model directory does not exist.',
    );
  }
  final model = Directory(modelPath);
  if (!await model.exists()) {
    throw const ProcessException(
      'voxhandoff-stt',
      <String>[],
      'The configured local STT model directory does not exist.',
    );
  }
  final canonicalModel = await model.resolveSymbolicLinks();
  final executable = File(Platform.resolvedExecutable);
  final executableDirectory = executable.parent;
  final candidates = <File>[
    File(
      '${executableDirectory.path}${Platform.pathSeparator}libexec'
      '${Platform.pathSeparator}voxhandoff-stt',
    ),
    if (Platform.isMacOS)
      File(
        '${executableDirectory.parent.path}${Platform.pathSeparator}Resources'
        '${Platform.pathSeparator}libexec${Platform.pathSeparator}voxhandoff-stt',
      ),
  ];
  for (final candidate in candidates) {
    if (await candidate.exists()) {
      final canonical = await candidate.resolveSymbolicLinks();
      final allowedRoot = await executableDirectory.resolveSymbolicLinks();
      if (!_within(canonical, allowedRoot) && Platform.isMacOS) {
        final appRoot = await executableDirectory.parent.resolveSymbolicLinks();
        if (!_within(canonical, appRoot)) continue;
      } else if (!_within(canonical, allowedRoot)) {
        continue;
      }
      return Process.start(canonical, <String>[
        '--model',
        canonicalModel,
      ], runInShell: false);
    }
  }
  throw const ProcessException(
    'voxhandoff-stt',
    <String>[],
    'Bundled STT sidecar not found.',
  );
};

bool _within(String candidate, String root) =>
    candidate == root || candidate.startsWith('$root${Platform.pathSeparator}');
