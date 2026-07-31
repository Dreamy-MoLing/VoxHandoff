import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/voice_provider_settings_controller.dart';
import '../domain/voice_provider_settings.dart';
import 'direct_llm_settings_sheet.dart';

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
  late final TextEditingController _speed;

  @override
  void initState() {
    super.initState();
    final tts = ref.read(voiceProviderSettingsProvider).settings.tts;
    _piperOrigin = TextEditingController(
      text: tts.kind == TtsProviderKind.piperHttp
          ? tts.origin.toString()
          : 'http://127.0.0.1:5000',
    );
    _voice = TextEditingController(text: tts.voice ?? '');
    _speed = TextEditingController(text: tts.lengthScale.toString());
  }

  @override
  void dispose() {
    _piperOrigin.dispose();
    _voice.dispose();
    _speed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceProviderSettingsProvider);
    final settings = state.settings;
    final sttEnabled = settings.stt.kind != SttProviderKind.disabled;
    final tts = settings.tts;
    final piperEnabled = tts.kind == TtsProviderKind.piperHttp;
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
              const Divider(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Local faster-whisper STT',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Switch(
                    value: sttEnabled,
                    onChanged: (enabled) => ref
                        .read(voiceProviderSettingsProvider.notifier)
                        .saveStt(
                          settings.stt.copyWith(
                            kind: enabled
                                ? SttProviderKind.bundledFasterWhisper
                                : SttProviderKind.disabled,
                          ),
                        ),
                  ),
                ],
              ),
              const Text(
                'The app only probes its versioned bundled-sidecar interface. It never downloads a model or accepts a command from this form.',
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tts.kind == TtsProviderKind.gptSoVits
                          ? 'Local GPT-SoVITS TTS'
                          : 'Local Piper TTS',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Switch(
                    value: ttsEnabled,
                    onChanged: (enabled) async {
                      if (!enabled) {
                        await ref
                            .read(voiceProviderSettingsProvider.notifier)
                            .saveTts(const TtsProviderConfiguration.disabled());
                        return;
                      }
                      if (tts.kind == TtsProviderKind.disabled) {
                        await _savePiper();
                      }
                    },
                  ),
                ],
              ),
              const Text(
                'Piper is a user-installed local service. The standard preset probes /info and synthesizes WAV with /synthesize on an exact loopback origin.',
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
                  controller: _speed,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Speech speed'),
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
    await ref
        .read(voiceProviderSettingsProvider.notifier)
        .saveTts(
          TtsProviderConfiguration.piper(
            origin: origin,
            voice: _voice.text.trim().isEmpty ? null : _voice.text.trim(),
            lengthScale: double.tryParse(_speed.text.trim()) ?? 0,
          ),
        );
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
