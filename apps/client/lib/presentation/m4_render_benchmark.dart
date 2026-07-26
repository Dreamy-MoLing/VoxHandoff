import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../domain/signal_core.dart';
import 'design/agent_talk_theme.dart';
import 'signal_core_view.dart';

const bool m4RenderBenchmarkBuildEnabled = bool.fromEnvironment(
  'VOXHANDOFF_M4_RENDER_BENCHMARK',
);

bool shouldRunM4RenderBenchmark(
  Map<String, String> environment, {
  bool buildEnabled = m4RenderBenchmarkBuildEnabled,
}) {
  return buildEnabled || environment['VOXHANDOFF_M4_RENDER_BENCHMARK'] == '1';
}

/// Runs the opt-in M4 frame probe and returns after 5 warmup frames plus five
/// measured shader frames for each of the 11 states. The JSONL output contains
/// timing facts only.
Future<void> runM4RenderBenchmark() async {
  final completed = Completer<void>();
  runApp(_M4RenderBenchmark(onComplete: completed.complete));
  await completed.future;
}

class _M4RenderBenchmark extends StatefulWidget {
  const _M4RenderBenchmark({required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<_M4RenderBenchmark> createState() => _M4RenderBenchmarkState();
}

class _M4RenderBenchmarkState extends State<_M4RenderBenchmark> {
  static const _warmupFrames = 5;
  static const _framesPerState = 5;

  final List<Map<String, Object>> _samples = [];
  int _receivedFrames = 0;
  int _stateIndex = 0;
  int _framesInState = 0;
  bool _collecting = false;

  static const _states = SignalCoreState.values;

  @override
  void dispose() {
    if (_collecting) {
      SchedulerBinding.instance.removeTimingsCallback(_acceptTimings);
    }
    super.dispose();
  }

  Future<ui.FragmentProgram> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/signal_core.frag',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCollection());
      return program;
    } on Object catch (error) {
      // Android profile processes exit immediately after this probe. Emit
      // synchronously through Flutter logging so the final record is not lost.
      debugPrintSynchronously(
        jsonEncode({
          'benchmark': 'm4_signal_core',
          'status': 'failed',
          'safe_error': error.runtimeType.toString(),
        }),
      );
      exitCode = 1;
      widget.onComplete();
      rethrow;
    }
  }

  void _startCollection() {
    if (!mounted || _collecting) return;
    _collecting = true;
    SchedulerBinding.instance.addTimingsCallback(_acceptTimings);
  }

  void _acceptTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _receivedFrames += 1;
      if (_receivedFrames > _warmupFrames) {
        _samples.add({
          'sample': _samples.length + 1,
          'state': _states[_stateIndex].name,
          'build_us': timing.buildDuration.inMicroseconds,
          'raster_us': timing.rasterDuration.inMicroseconds,
          'total_us': timing.totalSpan.inMicroseconds,
        });
        _framesInState += 1;
      }
      if (_framesInState == _framesPerState) {
        if (_stateIndex == _states.length - 1) {
          _finish();
        } else if (mounted) {
          _framesInState = 0;
          setState(() => _stateIndex += 1);
        }
        return;
      }
    }
  }

  void _finish() {
    if (!_collecting) return;
    _collecting = false;
    SchedulerBinding.instance.removeTimingsCallback(_acceptTimings);
    final refreshRate = View.of(context).display.refreshRate;
    debugPrintSynchronously(
      jsonEncode({
        'benchmark': 'm4_signal_core',
        'status': 'completed',
        'warmup_frames': _warmupFrames,
        'measured_frames': _samples.length,
        'refresh_rate_hz': refreshRate,
        'profile': signalRenderProfileForRefreshRate(refreshRate).name,
      }),
    );
    for (final sample in _samples) {
      debugPrintSynchronously(jsonEncode(sample));
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final state = _states[_stateIndex];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAgentTalkDarkTheme(),
      home: Scaffold(
        body: Center(
          child: SignalCoreView(
            snapshot: SignalCoreSnapshot(
              state: state,
              label: 'M4 frame probe ${state.name}',
              conversationId: 'benchmark-conversation',
              requestId: 'benchmark-request',
              sourceIdentity: 'benchmark-${state.name}',
              audioLevel: state == SignalCoreState.recording ? 0.72 : 0,
              playbackLevel: state == SignalCoreState.speaking ? 0.64 : 0,
            ),
            dimension: 280,
            shaderLoader: _loadShader,
          ),
        ),
      ),
    );
  }
}
