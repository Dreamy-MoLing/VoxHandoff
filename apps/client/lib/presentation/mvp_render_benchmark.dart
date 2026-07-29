import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/agent_talk_app.dart';
import '../application/gateway_workspace_controller.dart';
import '../application/speech_playback_controller.dart';
import '../application/voice_session_controller.dart';
import '../domain/client_event.dart';
import '../domain/client_session.dart';
import '../domain/conversation_timeline.dart';
import '../domain/gateway_sync.dart';
import '../domain/gateway_workspace.dart';
import '../domain/speech.dart';
import '../domain/voice.dart';

const bool mvpRenderBenchmarkBuildEnabled = bool.fromEnvironment(
  'VOXHANDOFF_MVP_RENDER_BENCHMARK',
);

bool shouldRunMvpRenderBenchmark(
  Map<String, String> environment, {
  bool buildEnabled = mvpRenderBenchmarkBuildEnabled,
}) => buildEnabled || environment['VOXHANDOFF_MVP_RENDER_BENCHMARK'] == '1';

Future<void> runMvpRenderBenchmark() async {
  final completed = Completer<void>();
  runApp(
    ProviderScope(
      overrides: [
        gatewayWorkspaceProvider.overrideWith(
          BenchmarkGatewayWorkspaceController.new,
        ),
        voiceSessionProvider.overrideWith(BenchmarkVoiceController.new),
        speechPlaybackProvider.overrideWith(BenchmarkSpeechController.new),
      ],
      child: _MvpBenchmarkDriver(onComplete: completed.complete),
    ),
  );
  await completed.future;
}

class _MvpBenchmarkDriver extends ConsumerStatefulWidget {
  const _MvpBenchmarkDriver({required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<_MvpBenchmarkDriver> createState() =>
      _MvpBenchmarkDriverState();
}

class _MvpBenchmarkDriverState extends ConsumerState<_MvpBenchmarkDriver>
    with SingleTickerProviderStateMixin {
  static const _warmupFrames = 10;
  static const _stressFrames = 120;
  static const _idleFrames = 60;

  late final Ticker _ticker;
  final List<Map<String, Object>> _samples = [];
  var _receivedFrames = 0;
  var _stressTick = 0;
  var _collecting = false;
  var _idle = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _collecting = true;
      SchedulerBinding.instance.addTimingsCallback(_acceptTimings);
    });
  }

  void _tick(Duration elapsed) {
    if (!_collecting || _idle) return;
    _stressTick += 1;
    final wave = (0.5 + 0.5 * math.sin(_stressTick / 4)).clamp(0.0, 1.0);
    (ref.read(voiceSessionProvider.notifier) as BenchmarkVoiceController)
        .setBenchmarkLevel(wave);
    (ref.read(speechPlaybackProvider.notifier) as BenchmarkSpeechController)
        .setBenchmarkLevel(1 - wave * 0.72);
    if (_stressTick.isEven) {
      (ref.read(gatewayWorkspaceProvider.notifier)
              as BenchmarkGatewayWorkspaceController)
          .appendBenchmarkDelta();
    }
  }

  void _acceptTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _receivedFrames += 1;
      if (_receivedFrames <= _warmupFrames) continue;
      final phase = _idle ? 'idle' : 'stress';
      _samples.add({
        'sample': _samples.length + 1,
        'phase': phase,
        'history_events': 2000,
        'build_us': timing.buildDuration.inMicroseconds,
        'raster_us': timing.rasterDuration.inMicroseconds,
        'total_us': timing.totalSpan.inMicroseconds,
        'rss_bytes': ProcessInfo.currentRss,
      });
      if (!_idle && _samples.length == _stressFrames) {
        _idle = true;
        (ref.read(voiceSessionProvider.notifier) as BenchmarkVoiceController)
            .setBenchmarkIdle();
        (ref.read(speechPlaybackProvider.notifier) as BenchmarkSpeechController)
            .setBenchmarkIdle();
        (ref.read(gatewayWorkspaceProvider.notifier)
                as BenchmarkGatewayWorkspaceController)
            .finishBenchmarkRequest();
      } else if (_idle && _samples.length == _stressFrames + _idleFrames) {
        _finish();
      }
    }
  }

  void _finish() {
    if (!_collecting) return;
    _collecting = false;
    SchedulerBinding.instance.removeTimingsCallback(_acceptTimings);
    _ticker.stop();
    final refreshRate = View.of(context).display.refreshRate;
    debugPrintSynchronously(
      jsonEncode({
        'benchmark': 'mvp_home_screen',
        'status': 'completed',
        'warmup_frames': _warmupFrames,
        'stress_frames': _stressFrames,
        'idle_frames': _idleFrames,
        'history_events': 2000,
        'refresh_rate_hz': refreshRate,
        'profile': refreshRate >= 100 ? 'highRefresh120' : 'balanced60',
      }),
    );
    for (final sample in _samples) {
      debugPrintSynchronously(jsonEncode(sample));
    }
    widget.onComplete();
  }

  @override
  void dispose() {
    if (_collecting) {
      SchedulerBinding.instance.removeTimingsCallback(_acceptTimings);
    }
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const AgentTalkApp();
}

class BenchmarkGatewayWorkspaceController extends GatewayWorkspaceController {
  var _nextSequence = 2001;
  var _revision = 1;

  @override
  GatewayWorkspaceState build() => _benchmarkWorkspace();

  void appendBenchmarkDelta() {
    final event = _messageEvent(_nextSequence++, _revision++, '·');
    state = state.copyWith(
      events: [...state.events, event],
      turns: appendConversationTurnEvent(state.turns, event),
      latestLiveEvent: event,
    );
  }

  void finishBenchmarkRequest() {
    final event = _terminalEvent(_nextSequence++, requestId: 'request-active');
    state = state.copyWith(
      events: [...state.events, event],
      turns: appendConversationTurnEvent(state.turns, event),
      latestLiveEvent: event,
    );
  }
}

class BenchmarkVoiceController extends VoiceSessionController {
  @override
  VoiceSessionState build() => const VoiceSessionState(
    phase: VoiceInputPhase.recording,
    sessionId: 'benchmark-voice',
    audioLevel: 0.5,
  );

  void setBenchmarkLevel(double level) {
    state = state.copyWith(audioLevel: level);
  }

  void setBenchmarkIdle() {
    state = const VoiceSessionState();
  }
}

class BenchmarkSpeechController extends SpeechPlaybackController {
  @override
  SpeechPlaybackState build() => SpeechPlaybackState(
    phase: SpeechPhase.playing,
    playbackLevel: 0.5,
    segment: _benchmarkSegment,
  );

  void setBenchmarkLevel(double level) {
    state = SpeechPlaybackState(
      phase: SpeechPhase.playing,
      playbackLevel: level,
      segment: _benchmarkSegment,
    );
  }

  void setBenchmarkIdle() {
    state = const SpeechPlaybackState();
  }
}

final _benchmarkSegment = SpeechSegment(
  conversationId: 'conversation-1',
  requestId: 'request-active',
  messageRevision: BigInt.one,
  index: 0,
  text: 'Synthetic benchmark speech.',
);

GatewayWorkspaceState _benchmarkWorkspace() {
  final events = <ClientEventRecord>[
    for (var index = 0; index < 1999; index += 1)
      _terminalEvent(index + 1, requestId: 'request-$index'),
    _progressEvent(2000, requestId: 'request-active'),
  ];
  return GatewayWorkspaceState(
    connectionPhase: GatewayConnectionPhase.connected,
    directory: ClientGatewayDirectory(
      commandId: 'benchmark-directory',
      nodes: const [
        ClientNodeDirectoryEntry(
          nodeId: 'node-1',
          displayName: 'Benchmark Node',
          platform: 'benchmark',
          version: '1',
        ),
      ],
      agents: const [
        ClientAgentDirectoryEntry(
          agentId: 'hermes-1',
          nodeId: 'node-1',
          displayName: 'Hermes',
          adapter: 'hermes',
          version: 'benchmark',
          capabilityRevision: 'benchmark-capability',
          supportsInterrupt: true,
          supportsApprovals: true,
          supportsClarifications: false,
        ),
      ],
      conversations: [
        ClientConversationDirectoryEntry(
          conversationId: 'conversation-1',
          title: 'MVP performance probe',
          nodeId: 'node-1',
          agentId: 'hermes-1',
          capabilityRevision: 'benchmark-capability',
          revision: BigInt.one,
          lastSequence: BigInt.from(2000),
        ),
      ],
    ),
    selectedConversationId: 'conversation-1',
    events: events,
    turns: aggregateConversationTurns(events),
    selectedEventsHydrated: true,
  );
}

ClientEventRecord _terminalEvent(int sequence, {required String requestId}) =>
    ClientEventRecord(
      eventId: 'benchmark-event-$sequence',
      connectionId: 'benchmark-connection',
      originDeviceId: 'benchmark-device',
      conversationId: 'conversation-1',
      requestId: requestId,
      sequence: BigInt.from(sequence),
      occurredAt: DateTime.utc(2030).add(Duration(seconds: sequence)),
      kind: ClientEventKind.requestCompleted,
      content: const TerminalClientEventContent(null),
      envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
    );

ClientEventRecord _progressEvent(int sequence, {required String requestId}) =>
    ClientEventRecord(
      eventId: 'benchmark-event-$sequence',
      connectionId: 'benchmark-connection',
      originDeviceId: 'benchmark-device',
      conversationId: 'conversation-1',
      requestId: requestId,
      sequence: BigInt.from(sequence),
      occurredAt: DateTime.utc(2030).add(Duration(seconds: sequence)),
      kind: ClientEventKind.agentWorking,
      content: const SafeMessageClientEventContent('Hermes is working.'),
      envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
    );

ClientEventRecord _messageEvent(int sequence, int revision, String text) =>
    ClientEventRecord(
      eventId: 'benchmark-event-$sequence',
      connectionId: 'benchmark-connection',
      originDeviceId: 'benchmark-device',
      conversationId: 'conversation-1',
      requestId: 'request-active',
      sequence: BigInt.from(sequence),
      occurredAt: DateTime.utc(2030).add(Duration(seconds: sequence)),
      kind: ClientEventKind.messageDelta,
      content: MessageClientEventContent(
        text: text,
        revision: BigInt.from(revision),
      ),
      envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
    );
