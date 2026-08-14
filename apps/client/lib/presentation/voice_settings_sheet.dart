import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/voice_session_controller.dart';
import '../application/voice_provider_settings_controller.dart';
import '../domain/voice_provider_settings.dart';
import '../domain/voice.dart';
import '../infrastructure/security/flutter_secure_value_store.dart';
import '../infrastructure/security/gateway_trusted_root_certificate_importer.dart';
import '../infrastructure/security/private_ca_certificate_picker.dart';
import '../infrastructure/security/secure_pairing_stores.dart';
import '../infrastructure/stt/remote_stt_port.dart';
import 'direct_llm_settings_sheet.dart';

final gatewayTrustedRootCertificateImporterProvider =
    Provider<GatewayTrustedRootCertificateImporter>(
      (_) => SecureGatewayTrustedRootCertificateImporter(
        profileStore: SecureGatewayConnectionProfileStore(
          FlutterSecureValueStore(),
        ),
        certificatePicker: const PlatformPrivateCaCertificatePicker(),
      ),
    );

typedef RemoteSttTransportFactory =
    RemoteSttTransport Function(RemoteSttTokenProvider tokenProvider);

final remoteSttTransportFactoryProvider = Provider<RemoteSttTransportFactory>(
  (_) =>
      (tokenProvider) =>
          JsonHttpRemoteSttTransport(tokenProvider: tokenProvider),
);

Future<void> showVoiceSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _VoiceSettingsSheet(),
    );

class _VoiceSettingsSheet extends ConsumerStatefulWidget {
  const _VoiceSettingsSheet();

  @override
  ConsumerState<_VoiceSettingsSheet> createState() =>
      _VoiceSettingsSheetState();
}

class _VoiceSettingsSheetState extends ConsumerState<_VoiceSettingsSheet> {
  late final TextEditingController _piperOrigin;
  late final TextEditingController _voice;
  late final TextEditingController _speaker;
  late final TextEditingController _speakerId;
  late final TextEditingController _speed;
  late final TextEditingController _gptOrigin;
  late final TextEditingController _gptReferenceAudio;
  late final TextEditingController _gptPromptText;
  late final TextEditingController _gptTextLanguage;
  late final TextEditingController _gptPromptLanguage;
  late final TextEditingController _sttLanguage;
  late final TextEditingController _sttModelPath;
  late final TextEditingController _remoteSttProviderId;
  late final TextEditingController _remoteSttOrigin;
  late final TextEditingController _remoteSttTlsPolicy;
  late final TextEditingController _remoteSttRetentionPolicy;
  late final TextEditingController _remoteSttRevision;
  late final TextEditingController _remoteSttToken;
  var _selectedSttKind = SttProviderKind.disabled;
  var _sttKindDirty = false;
  var _remoteSttConsent = false;
  var _remoteSttDisclosurePending = false;
  String? _remoteSttDisclosureError;
  var _selectedTtsKind = TtsProviderKind.disabled;
  var _lastEnabledTtsKind = TtsProviderKind.piperHttp;
  var _ttsKindDirty = false;
  List<AudioInputDevice> _microphones = const [];
  String? _microphoneLoadMessage;
  bool _gatewayTrustImportPending = false;
  String? _gatewayTrustMessage;

  @override
  void initState() {
    super.initState();
    final tts = ref.read(voiceProviderSettingsProvider).settings.tts;
    _selectedTtsKind = tts.kind;
    if (tts.kind != TtsProviderKind.disabled) {
      _lastEnabledTtsKind = tts.kind;
    }
    _piperOrigin = TextEditingController(
      text: tts.kind == TtsProviderKind.piperHttp
          ? tts.origin.toString()
          : 'http://127.0.0.1:5000',
    );
    _voice = TextEditingController(text: tts.voice ?? '');
    _speaker = TextEditingController(text: tts.speaker ?? '');
    _speakerId = TextEditingController(text: tts.speakerId?.toString() ?? '');
    _speed = TextEditingController(
      text: speechRateForPiperLengthScale(tts.lengthScale).toStringAsFixed(2),
    );
    _gptOrigin = TextEditingController(
      text: tts.kind == TtsProviderKind.gptSoVits
          ? tts.origin.toString()
          : 'http://127.0.0.1:9880',
    );
    _gptReferenceAudio = TextEditingController(
      text: tts.referenceAudioPath ?? '',
    );
    _gptPromptText = TextEditingController(text: tts.promptText ?? '');
    _gptTextLanguage = TextEditingController(text: tts.textLanguage);
    _gptPromptLanguage = TextEditingController(text: tts.promptLanguage);
    final stt = ref.read(voiceProviderSettingsProvider).settings.stt;
    final remote = stt.remote;
    _selectedSttKind = stt.kind;
    _sttLanguage = TextEditingController(text: stt.language);
    _sttModelPath = TextEditingController(text: stt.modelPath);
    _remoteSttProviderId = TextEditingController(
      text: remote?.providerId ?? 'voxhandoff-stt',
    );
    _remoteSttOrigin = TextEditingController(
      text: remote?.origin.toString() ?? 'https://stt.example.com',
    );
    _remoteSttTlsPolicy = TextEditingController(
      text: remote?.tlsPolicy ?? 'system-roots-hostname-verified',
    );
    _remoteSttRetentionPolicy = TextEditingController(
      text: remote?.retentionPolicy ?? 'Provider retention must be reviewed',
    );
    _remoteSttRevision = TextEditingController(text: remote?.revision ?? 'v1');
    _remoteSttToken = TextEditingController();
    _remoteSttConsent = remote?.consentedAt != null;
    unawaited(_loadMicrophones());
  }

  @override
  void dispose() {
    _piperOrigin.dispose();
    _voice.dispose();
    _speaker.dispose();
    _speakerId.dispose();
    _speed.dispose();
    _gptOrigin.dispose();
    _gptReferenceAudio.dispose();
    _gptPromptText.dispose();
    _gptTextLanguage.dispose();
    _gptPromptLanguage.dispose();
    _sttLanguage.dispose();
    _sttModelPath.dispose();
    _remoteSttProviderId.dispose();
    _remoteSttOrigin.dispose();
    _remoteSttTlsPolicy.dispose();
    _remoteSttRetentionPolicy.dispose();
    _remoteSttRevision.dispose();
    _remoteSttToken.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceProviderSettingsProvider);
    final settings = state.settings;
    final selectedSttKind = _sttKindDirty
        ? _selectedSttKind
        : settings.stt.kind;
    final sttEnabled = selectedSttKind != SttProviderKind.disabled;
    final localSttEnabled =
        selectedSttKind == SttProviderKind.bundledFasterWhisper;
    final remoteSttEnabled = selectedSttKind == SttProviderKind.remoteHttps;
    final tts = settings.tts;
    final selectedTtsKind = _ttsKindDirty ? _selectedTtsKind : tts.kind;
    final piperEnabled = selectedTtsKind == TtsProviderKind.piperHttp;
    final gptSoVitsEnabled = selectedTtsKind == TtsProviderKind.gptSoVits;
    final ttsEnabled = tts.kind != TtsProviderKind.disabled;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sources and voice',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Each source has a separate test. No provider test logs text, audio, or credentials.',
              ),
              const Divider(height: 28),
              const Text(
                'Hermes',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Hermes uses the paired Gateway workspace. Connect or disconnect it from the workspace; direct LLM settings never alter its permissions or uncertain-submission recovery.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  showDirectLlmSettingsSheet(navigator.context);
                },
                icon: const Icon(Icons.key_outlined),
                label: const Text('Configure direct LLM API'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('gateway-import-ca-button'),
                onPressed: _gatewayTrustImportPending
                    ? null
                    : _importGatewayTrustCertificate,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(
                  _gatewayTrustImportPending
                      ? 'Importing trusted CA…'
                      : 'Re-import trusted CA',
                ),
              ),
              if (_gatewayTrustMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _gatewayTrustMessage!,
                    key: const Key('gateway-import-ca-message'),
                    style: TextStyle(
                      color: _gatewayTrustMessage!.startsWith('Trusted CA')
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const Divider(height: 28),
              const Text(
                'Local faster-whisper STT',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<SttProviderKind>(
                key: const Key('stt-provider-kind'),
                initialValue: selectedSttKind,
                decoration: const InputDecoration(labelText: 'STT provider'),
                items: const [
                  DropdownMenuItem(
                    value: SttProviderKind.disabled,
                    child: Text('Disabled'),
                  ),
                  DropdownMenuItem(
                    value: SttProviderKind.bundledFasterWhisper,
                    child: Text('Local faster-whisper STT'),
                  ),
                  DropdownMenuItem(
                    value: SttProviderKind.remoteHttps,
                    child: Text('Consented HTTPS provider (Android)'),
                  ),
                ],
                onChanged: (kind) {
                  if (kind == null) return;
                  setState(() {
                    _sttKindDirty = true;
                    _selectedSttKind = kind;
                    if (kind != SttProviderKind.remoteHttps) {
                      _remoteSttConsent = false;
                    }
                  });
                },
              ),
              Text(
                remoteSttEnabled
                    ? 'Audio is buffered in memory and uploaded only after you stop recording and accept this exact provider disclosure.'
                    : 'The local option probes only its versioned bundled-sidecar interface. It never downloads a model or accepts a command from this form.',
              ),
              const SizedBox(height: 8),
              if (_microphones.isEmpty)
                Text(
                  _microphoneLoadMessage ??
                      'Microphone: system default (this platform did not expose selectable input devices).',
                )
              else
                DropdownButtonFormField<String?>(
                  initialValue: settings.microphoneId,
                  decoration: const InputDecoration(labelText: 'Microphone'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('System default'),
                    ),
                    for (final microphone in _microphones)
                      DropdownMenuItem<String?>(
                        value: microphone.id,
                        child: Text(microphone.label),
                      ),
                  ],
                  onChanged: (value) => ref
                      .read(voiceProviderSettingsProvider.notifier)
                      .saveMicrophoneId(value),
                ),
              const SizedBox(height: 8),
              if (sttEnabled)
                TextField(
                  controller: _sttLanguage,
                  decoration: InputDecoration(
                    labelText: 'STT language',
                    helperText: remoteSttEnabled
                        ? 'Sent as metadata to the exact HTTPS provider.'
                        : 'Passed to the local sidecar, for example zh or en.',
                  ),
                ),
              if (localSttEnabled)
                TextField(
                  controller: _sttModelPath,
                  decoration: const InputDecoration(
                    labelText: 'Local faster-whisper model directory',
                    helperText:
                        'Absolute existing directory; no model download is allowed.',
                  ),
                ),
              if (remoteSttEnabled) ...[
                TextField(
                  controller: _remoteSttProviderId,
                  onChanged: (_) => _invalidateRemoteSttConsent(),
                  decoration: const InputDecoration(
                    labelText: 'Remote provider ID',
                    helperText:
                        'Opaque ID used only to select its secure token.',
                  ),
                ),
                TextField(
                  controller: _remoteSttOrigin,
                  onChanged: (_) => _invalidateRemoteSttConsent(),
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Remote HTTPS origin',
                    helperText:
                        'Exact https://host root; redirects, paths, queries, and fragments are rejected.',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('remote-stt-fetch-disclosure-button'),
                  onPressed: _remoteSttDisclosurePending
                      ? null
                      : _fetchRemoteSttDisclosure,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                    _remoteSttDisclosurePending
                        ? 'Fetching disclosure…'
                        : 'Fetch disclosure',
                  ),
                ),
                if (_remoteSttDisclosureError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _remoteSttDisclosureError!,
                      key: const Key('remote-stt-disclosure-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                TextField(
                  controller: _remoteSttTlsPolicy,
                  onChanged: (_) => _invalidateRemoteSttConsent(),
                  decoration: const InputDecoration(
                    labelText: 'TLS policy disclosure',
                  ),
                ),
                TextField(
                  controller: _remoteSttRetentionPolicy,
                  onChanged: (_) => _invalidateRemoteSttConsent(),
                  decoration: const InputDecoration(
                    labelText: 'Retention policy disclosure',
                  ),
                ),
                TextField(
                  controller: _remoteSttRevision,
                  onChanged: (_) => _invalidateRemoteSttConsent(),
                  decoration: const InputDecoration(
                    labelText: 'Provider contract revision',
                  ),
                ),
                TextField(
                  controller: _remoteSttToken,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Remote provider token',
                    helperText:
                        'Stored separately in OS secure storage and never included in settings diagnostics.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _remoteSttConsent,
                  onChanged: (value) =>
                      setState(() => _remoteSttConsent = value ?? false),
                  title: const Text(
                    'I consent to this exact upload disclosure',
                  ),
                  subtitle: const Text(
                    'Changing origin, TLS, retention, streaming, or revision requires consent again.',
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saveStt,
                  child: const Text('Save STT settings'),
                ),
              ),
              const SizedBox(height: 8),
              _TestRow(
                label: 'Test STT readiness',
                status: state.sttTest,
                onTest:
                    sttEnabled &&
                        state.sttTest.phase != VoiceProviderTestPhase.testing
                    ? () => ref
                          .read(voiceProviderSettingsProvider.notifier)
                          .testStt()
                    : null,
              ),
              const Divider(height: 28),
              DropdownButtonFormField<TtsProviderKind>(
                initialValue: selectedTtsKind,
                decoration: const InputDecoration(labelText: 'TTS provider'),
                items: const [
                  DropdownMenuItem(
                    value: TtsProviderKind.disabled,
                    child: Text('Disabled'),
                  ),
                  DropdownMenuItem(
                    value: TtsProviderKind.piperHttp,
                    child: Text('Local Piper HTTP'),
                  ),
                  DropdownMenuItem(
                    value: TtsProviderKind.gptSoVits,
                    child: Text('Local GPT-SoVITS'),
                  ),
                ],
                onChanged: (kind) {
                  if (kind == null) return;
                  setState(() {
                    _ttsKindDirty = true;
                    _selectedTtsKind = kind;
                    if (kind != TtsProviderKind.disabled) {
                      _lastEnabledTtsKind = kind;
                    }
                  });
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedTtsKind == TtsProviderKind.gptSoVits
                          ? 'Local GPT-SoVITS TTS'
                          : 'Local Piper TTS',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Switch(
                    value: ttsEnabled,
                    onChanged: (enabled) async {
                      if (!enabled) {
                        setState(() {
                          _ttsKindDirty = true;
                          if (tts.kind != TtsProviderKind.disabled) {
                            _lastEnabledTtsKind = tts.kind;
                          }
                          _selectedTtsKind = TtsProviderKind.disabled;
                        });
                        await ref
                            .read(voiceProviderSettingsProvider.notifier)
                            .saveTts(const TtsProviderConfiguration.disabled());
                        return;
                      }
                      final kind = selectedTtsKind == TtsProviderKind.disabled
                          ? _lastEnabledTtsKind
                          : selectedTtsKind;
                      setState(() {
                        _ttsKindDirty = true;
                        _selectedTtsKind = kind;
                      });
                      if (kind == TtsProviderKind.gptSoVits) {
                        await _saveGptSoVits();
                      } else if (tts.kind == TtsProviderKind.disabled) {
                        await _savePiper();
                      }
                    },
                  ),
                ],
              ),
              Text(
                piperEnabled
                    ? 'Piper is a user-installed local service. The standard preset probes /info and synthesizes WAV with /synthesize on an exact loopback origin.'
                    : 'GPT-SoVITS is a user-installed local service. The adapter sends only the configured reference and language fields to an exact loopback origin.',
              ),
              if (piperEnabled) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _piperOrigin,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Piper HTTP origin',
                  ),
                ),
                TextField(
                  controller: _voice,
                  decoration: const InputDecoration(
                    labelText: 'Optional voice name',
                  ),
                ),
                TextField(
                  controller: _speaker,
                  decoration: const InputDecoration(
                    labelText: 'Optional speaker name',
                  ),
                ),
                TextField(
                  controller: _speakerId,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Optional speaker ID',
                  ),
                ),
                TextField(
                  controller: _speed,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Speech speed (0.5–2.0; 1.0 normal)',
                    helperText:
                        'Higher is faster; Piper length_scale is converted internally.',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _savePiper,
                    child: const Text('Save Piper settings'),
                  ),
                ),
              ],
              if (gptSoVitsEnabled) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _gptOrigin,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'GPT-SoVITS HTTP origin',
                  ),
                ),
                TextField(
                  controller: _gptReferenceAudio,
                  decoration: const InputDecoration(
                    labelText: 'Reference audio path',
                    helperText: 'Absolute path owned by the local user.',
                  ),
                ),
                TextField(
                  controller: _gptPromptText,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reference prompt text',
                  ),
                ),
                TextField(
                  controller: _gptTextLanguage,
                  decoration: const InputDecoration(labelText: 'Text language'),
                ),
                TextField(
                  controller: _gptPromptLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Prompt language',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _saveGptSoVits,
                    child: const Text('Save GPT-SoVITS settings'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _TestRow(
                label: 'Test TTS readiness',
                status: state.ttsTest,
                onTest:
                    ttsEnabled &&
                        state.ttsTest.phase != VoiceProviderTestPhase.testing
                    ? () => ref
                          .read(voiceProviderSettingsProvider.notifier)
                          .testTts()
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePiper() async {
    final origin = Uri.tryParse(_piperOrigin.text.trim());
    if (origin == null) return;
    final speed = double.tryParse(_speed.text.trim());
    final speakerIdText = _speakerId.text.trim();
    final speakerId = speakerIdText.isEmpty
        ? null
        : int.tryParse(speakerIdText);
    await ref
        .read(voiceProviderSettingsProvider.notifier)
        .saveTts(
          TtsProviderConfiguration.piper(
            origin: origin,
            voice: _voice.text.trim().isEmpty ? null : _voice.text.trim(),
            speaker: _speaker.text.trim().isEmpty ? null : _speaker.text.trim(),
            speakerId: speakerIdText.isEmpty ? null : speakerId,
            lengthScale: speed == null || !isSupportedSpeechRate(speed)
                ? 0
                : piperLengthScaleForSpeechRate(speed),
          ),
        );
  }

  Future<void> _saveGptSoVits() async {
    final origin = Uri.tryParse(_gptOrigin.text.trim());
    if (origin == null) return;
    await ref
        .read(voiceProviderSettingsProvider.notifier)
        .saveTts(
          TtsProviderConfiguration.gptSoVits(
            origin: origin,
            referenceAudioPath: _gptReferenceAudio.text.trim(),
            promptText: _gptPromptText.text.trim(),
            textLanguage: _gptTextLanguage.text.trim(),
            promptLanguage: _gptPromptLanguage.text.trim(),
          ),
        );
  }

  Future<void> _importGatewayTrustCertificate() async {
    setState(() {
      _gatewayTrustImportPending = true;
      _gatewayTrustMessage = null;
    });
    try {
      final imported = await ref
          .read(gatewayTrustedRootCertificateImporterProvider)
          .import();
      if (mounted && imported) {
        setState(
          () => _gatewayTrustMessage =
              'Trusted CA imported. Test STT readiness again.',
        );
      }
    } on PrivateCaCertificatePickerException catch (error) {
      if (mounted) setState(() => _gatewayTrustMessage = error.message);
    } on GatewayTrustedRootCertificateImportException catch (error) {
      if (mounted) setState(() => _gatewayTrustMessage = error.message);
    } on FormatException {
      if (mounted) {
        setState(
          () => _gatewayTrustMessage =
              'Certificate file is not valid UTF-8 PEM. Choose a CA certificate.',
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _gatewayTrustMessage =
              'The Gateway trust certificate could not be updated. The existing profile was kept.',
        );
      }
    } finally {
      if (mounted) setState(() => _gatewayTrustImportPending = false);
    }
  }

  Future<void> _saveStt() {
    final controller = ref.read(voiceProviderSettingsProvider.notifier);
    final language = _sttLanguage.text.trim();
    final selectedSttKind = _sttKindDirty
        ? _selectedSttKind
        : ref.read(voiceProviderSettingsProvider).settings.stt.kind;
    if (selectedSttKind == SttProviderKind.remoteHttps) {
      final origin = Uri.tryParse(_remoteSttOrigin.text.trim());
      final remote = RemoteSttProviderConfiguration(
        providerId: _remoteSttProviderId.text.trim(),
        origin: origin ?? Uri(scheme: 'https'),
        tlsPolicy: _remoteSttTlsPolicy.text.trim(),
        retentionPolicy: _remoteSttRetentionPolicy.text.trim(),
        streaming: false,
        revision: _remoteSttRevision.text.trim(),
        consentedAt: _remoteSttConsent ? DateTime.now().toUtc() : null,
      );
      return controller.saveRemoteStt(remote, _remoteSttToken.text);
    }
    return controller.saveStt(
      SttProviderConfiguration(
        kind: selectedSttKind,
        language: language,
        modelPath: selectedSttKind == SttProviderKind.bundledFasterWhisper
            ? _sttModelPath.text.trim()
            : '',
      ),
    );
  }

  Future<void> _fetchRemoteSttDisclosure() async {
    final origin = Uri.tryParse(_remoteSttOrigin.text.trim());
    final providerId = _remoteSttProviderId.text.trim();
    if (origin == null || !RemoteSttDisclosure.isSecureOriginUri(origin)) {
      setState(
        () => _remoteSttDisclosureError =
            'Enter an exact HTTPS origin before fetching disclosure.',
      );
      return;
    }
    if (providerId.isEmpty) {
      setState(
        () => _remoteSttDisclosureError =
            'Enter the remote provider ID before fetching disclosure.',
      );
      return;
    }

    setState(() {
      _remoteSttDisclosurePending = true;
      _remoteSttDisclosureError = null;
    });

    final inputToken = _remoteSttToken.text.trim();
    final secrets = ref
        .read(voiceProviderSettingsStoreProvider)
        .remoteSttSecrets;
    RemoteSttTransport? transport;
    try {
      transport = ref.read(remoteSttTransportFactoryProvider)((
        requestedProviderId,
      ) async {
        if (requestedProviderId == providerId && inputToken.isNotEmpty) {
          return inputToken;
        }
        return await secrets.read(requestedProviderId) ?? '';
      });
      final disclosure = await transport.fetchDisclosure(origin, providerId);
      if (!mounted) return;
      final disclosureChanged =
          _remoteSttProviderId.text.trim() != disclosure.providerId ||
          _remoteSttOrigin.text.trim() != disclosure.origin.toString() ||
          _remoteSttTlsPolicy.text.trim() != disclosure.tlsPolicy ||
          _remoteSttRetentionPolicy.text.trim() != disclosure.retentionPolicy ||
          _remoteSttRevision.text.trim() != disclosure.revision ||
          disclosure.streaming;
      _remoteSttProviderId.text = disclosure.providerId;
      _remoteSttOrigin.text = disclosure.origin.toString();
      _remoteSttTlsPolicy.text = disclosure.tlsPolicy;
      _remoteSttRetentionPolicy.text = disclosure.retentionPolicy;
      _remoteSttRevision.text = disclosure.revision;
      setState(() {
        if (disclosureChanged) _remoteSttConsent = false;
        _remoteSttDisclosureError = null;
      });
    } on VoicePortException catch (error) {
      if (mounted) {
        setState(() => _remoteSttDisclosureError = error.failure.safeMessage);
      }
    } on FormatException {
      if (mounted) {
        setState(
          () => _remoteSttDisclosureError =
              'The remote STT disclosure is invalid or too large.',
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _remoteSttDisclosureError =
              'The remote STT disclosure could not be fetched. Check the origin and token.',
        );
      }
    } finally {
      await transport?.close();
      if (mounted) {
        setState(() => _remoteSttDisclosurePending = false);
      }
    }
  }

  void _invalidateRemoteSttConsent() {
    if (_remoteSttConsent) {
      setState(() => _remoteSttConsent = false);
    }
  }

  Future<void> _loadMicrophones() async {
    final microphones = await ref
        .read(audioInputDeviceEnumeratorProvider)
        .listInputDevices();
    if (!mounted) return;
    setState(() {
      _microphones = microphones;
      if (microphones.isEmpty) {
        _microphoneLoadMessage =
            'Microphone: system default (enumeration unavailable or no devices reported).';
      }
    });
  }
}

class _TestRow extends StatelessWidget {
  const _TestRow({
    required this.label,
    required this.status,
    required this.onTest,
  });

  final String label;
  final VoiceProviderTestStatus status;
  final VoidCallback? onTest;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton(
        onPressed: onTest,
        child: Text(
          status.phase == VoiceProviderTestPhase.testing ? 'Testing…' : label,
        ),
      ),
      if (status.phase == VoiceProviderTestPhase.ready)
        const Text('Ready', style: TextStyle(color: Colors.green)),
      if (status.safeMessage != null)
        Text(
          status.safeMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
