import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/voice_session_controller.dart';
import '../application/chat_source_controller.dart';
import '../application/voice_provider_settings_controller.dart';
import '../domain/interaction_mode.dart';
import '../domain/voice_provider_settings.dart';
import '../domain/voice.dart';
import '../infrastructure/security/flutter_secure_value_store.dart';
import '../infrastructure/security/gateway_trusted_root_certificate_importer.dart';
import '../infrastructure/security/private_ca_certificate_picker.dart';
import '../infrastructure/security/remote_stt_trusted_root_certificate_store.dart';
import '../infrastructure/security/secure_pairing_stores.dart';
import '../infrastructure/stt/remote_stt_port.dart';
import 'direct_llm_settings_sheet.dart';
import 'hermes_conversation_settings_sheet.dart';

part 'voice_settings_sheet_operations.dart';

final gatewayTrustedRootCertificateImporterProvider =
    Provider<GatewayTrustedRootCertificateImporter>(
      (_) => SecureGatewayTrustedRootCertificateImporter(
        profileStore: SecureGatewayConnectionProfileStore(
          FlutterSecureValueStore(),
        ),
        certificatePicker: const PlatformPrivateCaCertificatePicker(),
        remoteSttCertificateStore: SecureRemoteSttTrustedRootCertificateStore(
          FlutterSecureValueStore(),
        ),
      ),
    );

typedef RemoteSttTransportFactory =
    RemoteSttTransport Function(RemoteSttTokenProvider tokenProvider);

final remoteSttTransportFactoryProvider = Provider<RemoteSttTransportFactory>(
  (_) =>
      (tokenProvider) => JsonHttpRemoteSttTransport(
        tokenProvider: tokenProvider,
        trustedRootCertificatesProvider: () async {
          try {
            return loadRemoteSttTrustedRootCertificates(
              FlutterSecureValueStore(),
            );
          } on Object {
            return null;
          }
        },
      ),
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
      text: remote?.retentionPolicy ?? '必须审查来源保留策略',
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
                '语音与来源',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('每个来源都有独立的测试。来源测试不会记录文本、音频或凭据。'),
              const Divider(height: 28),
              const Text(
                'Hermes',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Hermes 对话是 v0.1.0 的主链路。在下方配置后即可连接；Direct LLM 为延后可选能力，其设置不会改变 Hermes 的权限或提交结果不确定时的恢复流程。',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => unawaited(_openHermesConversation()),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('使用 Hermes 对话（Chat Completions）'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  showDirectLlmSettingsSheet(navigator.context);
                },
                icon: const Icon(Icons.key_outlined),
                label: const Text('配置 Direct LLM 接口'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('gateway-import-ca-button'),
                onPressed: _gatewayTrustImportPending
                    ? null
                    : _importGatewayTrustCertificate,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(
                  _gatewayTrustImportPending ? '正在导入受信任的 CA…' : '重新导入受信任的 CA',
                ),
              ),
              if (_gatewayTrustMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _gatewayTrustMessage!,
                    key: const Key('gateway-import-ca-message'),
                    style: TextStyle(
                      color: _gatewayTrustMessage!.startsWith('已导入')
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const Divider(height: 28),
              const Text(
                '本地 faster-whisper STT',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<SttProviderKind>(
                key: const Key('stt-provider-kind'),
                initialValue: selectedSttKind,
                decoration: const InputDecoration(labelText: 'STT 来源'),
                items: const [
                  DropdownMenuItem(
                    value: SttProviderKind.disabled,
                    child: Text('已禁用'),
                  ),
                  DropdownMenuItem(
                    value: SttProviderKind.bundledFasterWhisper,
                    child: Text('本地 faster-whisper STT'),
                  ),
                  DropdownMenuItem(
                    value: SttProviderKind.remoteHttps,
                    child: Text('已同意的 HTTPS 来源（Android）'),
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
                    ? '音频会暂存在内存中，只有在停止录音并接受此来源的完整披露后才会上传。'
                    : '本地选项只探测版本化的 sidecar 接口，不会下载模型，也不会接受此表单发出的命令。',
              ),
              const SizedBox(height: 8),
              if (_microphones.isEmpty)
                Text(_microphoneLoadMessage ?? '麦克风：系统默认（此平台未提供可选的输入设备）。')
              else
                DropdownButtonFormField<String?>(
                  initialValue: settings.microphoneId,
                  decoration: const InputDecoration(labelText: '麦克风'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('系统默认'),
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
                    labelText: 'STT 语言',
                    helperText: remoteSttEnabled
                        ? '会作为元数据发送给指定的 HTTPS 来源。'
                        : '会传给本地 sidecar，例如 zh 或 en。',
                  ),
                ),
              if (localSttEnabled)
                TextField(
                  controller: _sttModelPath,
                  decoration: const InputDecoration(
                    labelText: '本地 faster-whisper 模型目录',
                    helperText: '必须是已存在的绝对路径；不允许下载模型。',
                  ),
                ),
              if (remoteSttEnabled) ...[
                TextField(
                  controller: _remoteSttOrigin,
                  onChanged: (_) => _invalidateRemoteSttConsent(),
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '远程 HTTPS 地址',
                    helperText: '必须是精确的 https://host 根地址；会拒绝重定向、路径、查询参数和片段。',
                  ),
                ),
                TextField(
                  controller: _remoteSttToken,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '远程来源令牌',
                    helperText: '单独存储在操作系统安全存储中，绝不会包含在设置诊断中。',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('remote-stt-fetch-disclosure-button'),
                  onPressed: _remoteSttDisclosurePending
                      ? null
                      : _fetchRemoteSttDisclosure,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(_remoteSttDisclosurePending ? '正在获取披露…' : '获取披露'),
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
                ExpansionTile(
                  key: const Key('remote-stt-advanced-disclosure'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text('高级来源披露'),
                  subtitle: const Text('由来源声明自动填充。'),
                  children: [
                    TextField(
                      controller: _remoteSttProviderId,
                      onChanged: (_) => _invalidateRemoteSttConsent(),
                      decoration: const InputDecoration(
                        labelText: '远程来源 ID',
                        helperText: '仅用于选择安全令牌的不透明 ID。',
                      ),
                    ),
                    TextField(
                      controller: _remoteSttTlsPolicy,
                      onChanged: (_) => _invalidateRemoteSttConsent(),
                      decoration: const InputDecoration(labelText: 'TLS 策略披露'),
                    ),
                    TextField(
                      controller: _remoteSttRetentionPolicy,
                      onChanged: (_) => _invalidateRemoteSttConsent(),
                      decoration: const InputDecoration(labelText: '保留策略披露'),
                    ),
                    TextField(
                      controller: _remoteSttRevision,
                      onChanged: (_) => _invalidateRemoteSttConsent(),
                      decoration: const InputDecoration(labelText: '来源契约版本'),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _remoteSttConsent,
                  onChanged: (value) =>
                      setState(() => _remoteSttConsent = value ?? false),
                  title: const Text('我同意按这份完整披露上传'),
                  subtitle: const Text('更改地址、TLS、保留策略、流式设置或版本后，需要重新同意。'),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saveStt,
                  child: const Text('保存 STT 设置'),
                ),
              ),
              const SizedBox(height: 8),
              _TestRow(
                label: '测试 STT 就绪状态',
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
                decoration: const InputDecoration(labelText: 'TTS 来源'),
                items: const [
                  DropdownMenuItem(
                    value: TtsProviderKind.disabled,
                    child: Text('已禁用'),
                  ),
                  DropdownMenuItem(
                    value: TtsProviderKind.piperHttp,
                    child: Text('本地 Piper HTTP'),
                  ),
                  DropdownMenuItem(
                    value: TtsProviderKind.gptSoVits,
                    child: Text('本地 GPT-SoVITS'),
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
                          ? '本地 GPT-SoVITS TTS'
                          : '本地 Piper TTS',
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
                    ? 'Piper 是用户安装的本地服务。标准预设会在精确的回环地址上探测 /info，并通过 /synthesize 合成 WAV。'
                    : 'GPT-SoVITS 是用户安装的本地服务。适配器只会向精确的回环地址发送已配置的参考音频和语言字段。',
              ),
              if (piperEnabled) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _piperOrigin,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Piper HTTP 地址'),
                ),
                TextField(
                  controller: _voice,
                  decoration: const InputDecoration(labelText: '可选的声音名称'),
                ),
                TextField(
                  controller: _speaker,
                  decoration: const InputDecoration(labelText: '可选的说话人名称'),
                ),
                TextField(
                  controller: _speakerId,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '可选的说话人 ID'),
                ),
                TextField(
                  controller: _speed,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '语速（0.5–2.0；1.0 为正常）',
                    helperText: '数值越大语速越快；Piper length_scale 会在内部转换。',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _savePiper,
                    child: const Text('保存 Piper 设置'),
                  ),
                ),
              ],
              if (gptSoVitsEnabled) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _gptOrigin,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'GPT-SoVITS HTTP 地址',
                  ),
                ),
                TextField(
                  controller: _gptReferenceAudio,
                  decoration: const InputDecoration(
                    labelText: '参考音频路径',
                    helperText: '必须是本地用户拥有的绝对路径。',
                  ),
                ),
                TextField(
                  controller: _gptPromptText,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '参考提示词文本'),
                ),
                TextField(
                  controller: _gptTextLanguage,
                  decoration: const InputDecoration(labelText: '文本语言'),
                ),
                TextField(
                  controller: _gptPromptLanguage,
                  decoration: const InputDecoration(labelText: '提示词语言'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _saveGptSoVits,
                    child: const Text('保存 GPT-SoVITS 设置'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _TestRow(
                label: '测试 TTS 就绪状态',
                status: state.ttsTest,
                onTest:
                    ttsEnabled &&
                        state.ttsTest.phase != VoiceProviderTestPhase.testing
                    ? () => ref
                          .read(voiceProviderSettingsProvider.notifier)
                          .testTts()
                    : null,
              ),
              const Divider(height: 28),
              const Text(
                '语音交互模式',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<InteractionMode>(
                key: const Key('voice-interaction-mode'),
                initialValue: settings.interactionMode,
                decoration: const InputDecoration(
                  labelText: '交互模式',
                  helperText: '通话模式在一句话预览后发送；指令模式先确认可编辑的转写文本。工作类指令始终按指令模式确认。',
                ),
                items: const [
                  DropdownMenuItem(
                    value: InteractionMode.command,
                    child: Text('指令模式（先确认）'),
                  ),
                  DropdownMenuItem(
                    value: InteractionMode.call,
                    child: Text('通话模式（预览后发送）'),
                  ),
                ],
                onChanged: (mode) {
                  if (mode == null) return;
                  ref
                      .read(voiceProviderSettingsProvider.notifier)
                      .saveInteractionMode(mode);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openHermesConversation() async {
    await ref
        .read(chatSourceProvider.notifier)
        .select(ChatSource.hermesConversation);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    await showHermesConversationSettingsSheet(navigator.context);
  }
}
