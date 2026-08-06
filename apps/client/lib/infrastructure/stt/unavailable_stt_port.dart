import '../../domain/voice.dart';

class UnavailableSttPort implements SttPort {
  const UnavailableSttPort({
    this.safeMessage =
        'Local speech recognition is not installed in this application build.',
  });

  final String safeMessage;

  VoicePortException get _error => VoicePortException(
    VoiceStageFailure(
      stage: VoiceFailureStage.configuration,
      code: 'local_stt_not_installed',
      safeMessage: safeMessage,
      retryable: false,
    ),
  );

  @override
  Future<void> warmUp() => Future.error(_error);

  @override
  Future<SttSessionPort> start({
    required String sessionId,
    required AudioCaptureConfig audio,
    String? language,
  }) => Future.error(_error);

  @override
  Future<void> close() async {}
}
