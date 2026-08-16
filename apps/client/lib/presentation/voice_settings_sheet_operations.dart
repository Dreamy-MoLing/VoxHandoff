part of 'voice_settings_sheet.dart';

// These operations remain part of the State library and intentionally call
// its protected setState method.
// ignore_for_file: invalid_use_of_protected_member

extension _VoiceSettingsSheetOperations on _VoiceSettingsSheetState {
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
        setState(() => _gatewayTrustMessage = '已导入受信任的 CA。请再次测试 STT 就绪状态。');
      }
    } on PrivateCaCertificatePickerException catch (error) {
      if (mounted) setState(() => _gatewayTrustMessage = error.message);
    } on GatewayTrustedRootCertificateImportException catch (error) {
      if (mounted) setState(() => _gatewayTrustMessage = error.message);
    } on FormatException {
      if (mounted) {
        setState(() => _gatewayTrustMessage = '证书文件不是有效的 UTF-8 PEM。请选择 CA 证书。');
      }
    } on Object {
      if (mounted) {
        setState(() => _gatewayTrustMessage = '无法更新 Gateway 信任证书。已保留现有配置。');
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
      setState(() => _remoteSttDisclosureError = '获取披露前，请输入精确的 HTTPS 地址。');
      return;
    }
    if (providerId.isEmpty) {
      setState(() => _remoteSttDisclosureError = '获取披露前，请输入远程来源 ID。');
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
        setState(() => _remoteSttDisclosureError = '远程 STT 披露无效或过大。');
      }
    } on Object {
      if (mounted) {
        setState(() => _remoteSttDisclosureError = '无法获取远程 STT 披露。请检查地址和令牌。');
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
        _microphoneLoadMessage = '麦克风：系统默认（无法枚举设备或未报告任何设备）。';
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
          status.phase == VoiceProviderTestPhase.testing ? '测试中…' : label,
        ),
      ),
      if (status.phase == VoiceProviderTestPhase.ready)
        const Text('已就绪', style: TextStyle(color: Colors.green)),
      if (status.safeMessage != null)
        Text(
          status.safeMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
