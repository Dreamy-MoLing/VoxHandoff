import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/client_session.dart';
import '../domain/interaction_mode.dart';
import '../domain/voice.dart';
import 'voice_provider_settings_controller.dart';
import 'client_session_controller.dart';
import 'speech_playback_controller.dart';

final audioCapturePortProvider = Provider<AudioCapturePort>(
  (_) => throw StateError('No production AudioCapturePort is configured.'),
);

final audioInputDeviceEnumeratorProvider = Provider<AudioInputDeviceEnumerator>(
  (ref) {
    AudioCapturePort capture;
    try {
      capture = ref.read(audioCapturePortProvider);
    } on Object {
      return const _UnavailableAudioInputDeviceEnumerator();
    }
    if (capture is AudioInputDeviceEnumerator) {
      return capture as AudioInputDeviceEnumerator;
    }
    return const _UnavailableAudioInputDeviceEnumerator();
  },
);

final sttPortProvider = Provider<SttPort>((ref) {
  final configuration = ref.watch(
    voiceProviderSettingsProvider.select((value) => value.settings.stt),
  );
  final port = ref.watch(voicePortFactoryProvider).createStt(configuration);
  ref.onDispose(() => unawaited(port.close()));
  return port;
});

final speechStopPortProvider = Provider<SpeechStopPort>(
  (ref) => _SpeechControllerStopPort(ref),
);

final localTranscriptStoreProvider = Provider<LocalTranscriptStore>(
  (_) => _MemoryTranscriptStore(),
);

final voiceSessionProvider =
    NotifierProvider<VoiceSessionController, VoiceSessionState>(
      VoiceSessionController.new,
    );

/// Presentation-owned Call-mode send: the handler binds a confirmation
/// snapshot for the current draft through the existing ChatSource abstraction
/// and dispatches the confirmed text. Hermes transport is M1's scope; this
/// port keeps the voice controller independent from Gateway/Direct details.
typedef VoiceCallSendHandler = Future<void> Function(String confirmedText);

class VoiceCallSendHandlers extends Notifier<VoiceCallSendHandler?> {
  @override
  VoiceCallSendHandler? build() => null;

  void register(VoiceCallSendHandler handler) {
    state = handler;
  }

  void clear() {
    state = null;
  }
}

final voiceCallSendHandlerProvider =
    NotifierProvider<VoiceCallSendHandlers, VoiceCallSendHandler?>(
      VoiceCallSendHandlers.new,
    );

class VoiceSessionController extends Notifier<VoiceSessionState> {
  AudioCaptureSession? _capture;
  SttSessionPort? _stt;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<double>? _levelSubscription;
  StreamSubscription<TranscriptUpdate>? _transcriptSubscription;
  Future<void> _pushes = Future.value();
  Completer<void>? _audioDone;
  Timer? _callConfirmTimer;
  int _generation = 0;
  int _lastTranscriptSequence = 0;
  // Diagnostic counters (never audio content).
  int _audioChunkCount = 0;
  int _audioChunkBytes = 0;

  /// Lifetime of the lightweight Call-mode echo before it auto-discards
  /// without sending. Overridable so tests can exercise the timeout.
  Duration callConfirmTimeout = const Duration(seconds: 15);

  @override
  VoiceSessionState build() {
    ref.onDispose(() {
      _callConfirmTimer?.cancel();
      _generation += 1;
      unawaited(_cancelPorts());
    });
    return const VoiceSessionState();
  }

  Future<void> warmUp() async {
    try {
      await ref.read(sttPortProvider).warmUp();
    } on Object catch (error) {
      _fail(_safeFailure(error, VoiceFailureStage.stt, 'stt_warmup_failed'));
    }
  }

  Future<void> startRecording({String? language}) async {
    unawaited(ref.read(speechPlaybackProvider.notifier).interruptSpeech());
    if (!state.canStart) {
      throw StateError('Voice input is already active.');
    }
    final draft = ref.read(clientSessionProvider);
    if (draft.draftPhase != DraftPhase.editing) {
      _fail(
        const VoiceStageFailure(
          stage: VoiceFailureStage.configuration,
          code: 'voice_draft_not_editable',
          safeMessage:
              'Start a new editable draft before recording another request.',
          retryable: false,
        ),
      );
      return;
    }

    final configuredLanguage =
        language ??
        ref.read(voiceProviderSettingsProvider).settings.stt.language;
    final generation = ++_generation;
    _lastTranscriptSequence = 0;
    final sessionId = _newOpaqueId();
    final interactionMode = ref
        .read(voiceProviderSettingsProvider)
        .settings
        .interactionMode;
    state = state.copyWith(
      phase: VoiceInputPhase.requestingPermission,
      sessionId: sessionId,
      interactionMode: interactionMode,
      clearTranscript: true,
      clearFailure: true,
      clearStorageWarning: true,
      audioLevel: 0,
    );
    try {
      await ref.read(speechStopPortProvider).stopSpeech();
      if (generation != _generation) return;
      final config = AudioCaptureConfig(
        microphoneId: ref
            .read(voiceProviderSettingsProvider)
            .settings
            .microphoneId,
      );
      final stt = await ref
          .read(sttPortProvider)
          .start(
            sessionId: sessionId,
            audio: config,
            language: configuredLanguage,
          );
      if (generation != _generation) {
        await stt.cancel();
        return;
      }
      _stt = stt;
      _transcriptSubscription = stt.updates.listen(
        (update) => _acceptProvisional(generation, update),
        onError: (Object error) => _streamFailed(generation, error),
      );
      final capture = await ref.read(audioCapturePortProvider).start(config);
      if (generation != _generation) {
        await capture.cancel();
        await stt.cancel();
        return;
      }
      _capture = capture;
      _audioDone = Completer<void>();
      _audioSubscription = capture.audioChunks.listen(
        (chunk) {
          // Diagnostic only: counts and sizes, never audio content.
          _audioChunkCount += 1;
          _audioChunkBytes += chunk.length;
          if (_audioChunkCount <= 3 ||
              _audioChunkCount % 200 == 0 ||
              (_audioChunkCount > 0 && _audioChunkBytes < 6400)) {
            // ignore: avoid_print
            print(
              'VoxHandoffDartCtrl chunks=$_audioChunkCount '
              'bytes=$_audioChunkBytes chunkLen=${chunk.length}',
            );
          }
          _enqueueAudioPush(generation, stt, chunk);
        },
        onError: (Object error) {
          if (!(_audioDone?.isCompleted ?? true)) {
            _audioDone!.completeError(error);
          }
          _streamFailed(generation, error);
        },
        onDone: () {
          if (!(_audioDone?.isCompleted ?? true)) _audioDone!.complete();
        },
      );
      _levelSubscription = capture.levels.listen((level) {
        if (generation != _generation ||
            state.phase != VoiceInputPhase.recording) {
          return;
        }
        state = state.copyWith(audioLevel: level.clamp(0, 1));
      });
      state = state.copyWith(phase: VoiceInputPhase.recording);
    } on Object catch (error) {
      if (generation != _generation) return;
      await _cancelPorts();
      _fail(
        _safeFailure(
          error,
          VoiceFailureStage.recording,
          'recording_start_failed',
        ),
      );
    }
  }

  Future<void> stopRecording() async {
    if (!state.canStop) {
      throw StateError('Voice input is not recording.');
    }
    final generation = _generation;
    final capture = _capture!;
    final stt = _stt!;
    state = state.copyWith(phase: VoiceInputPhase.transcribing, audioLevel: 0);
    try {
      await capture.stop();
      await _flushAudioPushes();
      if (generation != _generation) return;
      final transcript = await stt.finish();
      if (generation != _generation) return;
      final text = transcript.text.trim();
      if (text.isEmpty) {
        throw const VoicePortException(
          VoiceStageFailure(
            stage: VoiceFailureStage.stt,
            code: 'stt_empty_transcript',
            safeMessage: 'No speech was detected in the recording.',
            retryable: true,
          ),
        );
      }
      ref.read(clientSessionProvider.notifier).editDraft(text);
      final forcedCommand =
          state.interactionMode == InteractionMode.call &&
          containsSensitiveInstruction(text);
      if (state.interactionMode == InteractionMode.command || forcedCommand) {
        state = state.copyWith(
          phase: VoiceInputPhase.awaitingConfirmation,
          provisionalTranscript: text,
          finalTranscript: text,
          originalTranscript: text,
          audioLevel: 0,
          clearFailure: true,
        );
      } else {
        state = state.copyWith(
          phase: VoiceInputPhase.awaitingCallConfirm,
          provisionalTranscript: text,
          finalTranscript: text,
          originalTranscript: text,
          audioLevel: 0,
          clearFailure: true,
        );
        _startCallConfirmTimeout();
      }
      await _persistTranscript(
        sessionId: state.sessionId!,
        transcript: transcript,
      );
    } on Object catch (error) {
      if (generation != _generation) return;
      try {
        await stt.cancel();
      } on Object {
        // Preserve the finalization failure while requesting audio cleanup.
      }
      _fail(_safeFailure(error, VoiceFailureStage.stt, 'stt_final_failed'));
    } finally {
      if (generation == _generation) await _releasePortsAfterFinish();
    }
  }

  Future<void> cancelRecording() async {
    if (!state.canCancel) return;
    _generation += 1;
    await _cancelPorts();
    state = state.copyWith(
      phase: VoiceInputPhase.cancelled,
      clearSession: true,
      clearTranscript: true,
      clearFailure: true,
      audioLevel: 0,
    );
  }

  Future<void> discardTranscript() async {
    if (state.phase != VoiceInputPhase.awaitingConfirmation &&
        state.phase != VoiceInputPhase.awaitingCallConfirm) {
      return;
    }
    _cancelCallConfirmTimeout();
    final transcriptId = state.sessionId;
    final original = state.finalTranscript;
    final draft = ref.read(clientSessionProvider);
    if (original != null && draft.canEditDraft && draft.draftText == original) {
      ref.read(clientSessionProvider.notifier).editDraft('');
    }
    if (transcriptId != null) {
      try {
        await ref.read(localTranscriptStoreProvider).delete(transcriptId);
      } on Object {
        state = state.copyWith(
          storageWarning: const VoiceStageFailure(
            stage: VoiceFailureStage.storage,
            code: 'stt_transcript_delete_failed',
            safeMessage: 'The local transcript could not be deleted.',
            retryable: true,
          ),
        );
      }
    }
    state = state.copyWith(
      phase: VoiceInputPhase.idle,
      clearSession: true,
      clearTranscript: true,
      clearFailure: true,
      audioLevel: 0,
    );
  }

  void _startCallConfirmTimeout() {
    _callConfirmTimer?.cancel();
    _callConfirmTimer = Timer(callConfirmTimeout, () {
      _callConfirmTimer = null;
      unawaited(discardTranscript());
    });
  }

  void _cancelCallConfirmTimeout() {
    _callConfirmTimer?.cancel();
    _callConfirmTimer = null;
  }

  /// Switches the current voice session's interaction mode. Call mode sends
  /// after a lightweight echo; Command mode always requires explicit text
  /// confirmation. The persisted default is seeded at each startRecording.
  void setInteractionMode(InteractionMode mode) {
    if (state.interactionMode == mode) return;
    state = state.copyWith(interactionMode: mode);
  }

  /// Confirms and sends a Call-mode echo through the registered
  /// ChatSource-backed handler. Without a handler (M1 not merged) it fails
  /// safe and keeps the editable transcript for a manual Command confirm.
  Future<void> confirmCallSend() async {
    if (state.phase != VoiceInputPhase.awaitingCallConfirm) return;
    _cancelCallConfirmTimeout();
    final text = state.finalTranscript?.trim() ?? '';
    if (text.isEmpty) {
      _fail(
        const VoiceStageFailure(
          stage: VoiceFailureStage.configuration,
          code: 'call_confirm_missing_transcript',
          safeMessage: 'No speech was captured for the call preview.',
          retryable: true,
        ),
      );
      return;
    }
    final generation = _generation;
    final handler = ref.read(voiceCallSendHandlerProvider);
    if (handler == null) {
      // TODO(M1): the Hermes send path arrives with the merged M1 adapter.
      // Until then Call mode cannot auto-send; it fails safe so the editable
      // transcript remains available for a manual Command-mode confirm.
      _fail(
        const VoiceStageFailure(
          stage: VoiceFailureStage.configuration,
          code: 'call_send_unavailable',
          safeMessage:
              'Call-mode send is not wired yet. Review the transcript and confirm in text mode.',
          retryable: true,
        ),
      );
      return;
    }
    try {
      await handler(text);
    } on Object catch (error) {
      if (generation != _generation) return;
      _fail(
        _safeFailure(
          error,
          VoiceFailureStage.configuration,
          'call_send_failed',
        ),
      );
      return;
    }
    if (generation != _generation) return;
    state = state.copyWith(
      phase: VoiceInputPhase.idle,
      clearSession: true,
      clearTranscript: true,
      clearFailure: true,
      audioLevel: 0,
    );
  }

  void _acceptProvisional(int generation, TranscriptUpdate update) {
    if (generation != _generation || state.phase != VoiceInputPhase.recording) {
      return;
    }
    if (update.sequence <= _lastTranscriptSequence) return;
    _lastTranscriptSequence = update.sequence;
    state = state.copyWith(provisionalTranscript: update.text);
  }

  void _enqueueAudioPush(int generation, SttSessionPort stt, Uint8List chunk) {
    final push = _pushes.then((_) => stt.push(chunk));
    _pushes = push;
    unawaited(
      push.catchError((Object error) {
        _streamFailed(generation, error);
      }),
    );
  }

  Future<void> _flushAudioPushes() async {
    await _audioDone?.future;
    final pushes = _pushes;
    await pushes;
  }

  void _streamFailed(int generation, Object error) {
    if (generation != _generation || !state.canCancel) return;
    _generation += 1;
    unawaited(_cancelPorts());
    _fail(_safeFailure(error, VoiceFailureStage.stt, 'stt_stream_failed'));
  }

  Future<void> _persistTranscript({
    required String sessionId,
    required FinalTranscript transcript,
  }) async {
    try {
      final store = ref.read(localTranscriptStoreProvider);
      await store.pruneBefore(
        DateTime.now().toUtc().subtract(const Duration(days: 7)),
      );
      await store.save(
        StoredTranscript(
          transcriptId: sessionId,
          createdAt: DateTime.now().toUtc(),
          originalText: transcript.text,
          provider: 'local-stt',
          audioDuration: transcript.audioDuration,
          transcriptionDuration: transcript.transcriptionDuration,
        ),
      );
    } on Object {
      state = state.copyWith(
        storageWarning: const VoiceStageFailure(
          stage: VoiceFailureStage.storage,
          code: 'stt_transcript_store_failed',
          safeMessage:
              'The editable transcript is available, but its local diagnostic copy was not saved.',
          retryable: true,
        ),
      );
    }
  }

  Future<void> _releasePortsAfterFinish() async {
    await _audioSubscription?.cancel();
    await _levelSubscription?.cancel();
    await _transcriptSubscription?.cancel();
    _audioSubscription = null;
    _levelSubscription = null;
    _transcriptSubscription = null;
    _capture = null;
    _stt = null;
    _audioDone = null;
    _pushes = Future.value();
  }

  Future<void> _cancelPorts() async {
    final capture = _capture;
    final stt = _stt;
    _capture = null;
    _stt = null;
    await _audioSubscription?.cancel();
    await _levelSubscription?.cancel();
    await _transcriptSubscription?.cancel();
    _audioSubscription = null;
    _levelSubscription = null;
    _transcriptSubscription = null;
    _audioDone = null;
    _pushes = Future.value();
    try {
      await capture?.cancel();
    } on Object {
      // The original stage failure remains the actionable result.
    }
    try {
      await stt?.cancel();
    } on Object {
      // Cancellation never becomes a successful transcript or Agent action.
    }
  }

  void _fail(VoiceStageFailure failure) {
    state = state.copyWith(
      phase: VoiceInputPhase.failed,
      failure: failure,
      audioLevel: 0,
    );
  }
}

VoiceStageFailure _safeFailure(
  Object error,
  VoiceFailureStage fallbackStage,
  String fallbackCode,
) => switch (error) {
  VoicePortException() => error.failure,
  _ => VoiceStageFailure(
    stage: fallbackStage,
    code: fallbackCode,
    safeMessage: switch (fallbackStage) {
      VoiceFailureStage.recording =>
        'Recording could not start or the microphone became unavailable.',
      VoiceFailureStage.stt => 'Speech recognition could not complete.',
      _ => 'The voice stage could not complete.',
    },
    retryable: true,
  ),
};

String _newOpaqueId() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return 'voice-${bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
}

class _SpeechControllerStopPort implements SpeechStopPort {
  const _SpeechControllerStopPort(this._ref);

  final Ref _ref;

  @override
  Future<void> stopSpeech() =>
      _ref.read(speechPlaybackProvider.notifier).stopSpeech();
}

class _UnavailableAudioInputDeviceEnumerator
    implements AudioInputDeviceEnumerator {
  const _UnavailableAudioInputDeviceEnumerator();

  @override
  Future<List<AudioInputDevice>> listInputDevices() async => const [];
}

class _MemoryTranscriptStore implements LocalTranscriptStore {
  final Map<String, StoredTranscript> _values = {};

  @override
  Future<void> delete(String transcriptId) async {
    _values.remove(transcriptId);
  }

  @override
  Future<void> pruneBefore(DateTime cutoff) async {
    _values.removeWhere(
      (_, transcript) => transcript.createdAt.isBefore(cutoff),
    );
  }

  @override
  Future<void> save(StoredTranscript transcript) async {
    _values[transcript.transcriptId] = transcript;
  }
}
