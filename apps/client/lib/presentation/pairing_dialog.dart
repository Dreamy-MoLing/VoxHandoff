import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/device_pairing_controller.dart';
import '../domain/device_pairing.dart';
import '../infrastructure/security/private_ca_certificate_picker.dart';
import 'design/agent_talk_theme.dart';

part 'pairing_dialog_widgets.dart';

Future<void> showDevicePairingDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => const DevicePairingDialog(),
);

class DevicePairingDialog extends ConsumerStatefulWidget {
  const DevicePairingDialog({
    super.key,
    this.restoreOnOpen = true,
    this.certificatePicker = const PlatformPrivateCaCertificatePicker(),
  });

  final bool restoreOnOpen;
  final PrivateCaCertificatePicker certificatePicker;

  @override
  ConsumerState<DevicePairingDialog> createState() =>
      _DevicePairingDialogState();
}

class _DevicePairingDialogState extends ConsumerState<DevicePairingDialog> {
  late final TextEditingController _gateway;
  late final TextEditingController _deviceName;
  late final TextEditingController _certificate;
  bool _send = true;
  bool _interrupt = false;
  bool _approve = false;
  bool _acknowledgeRemoteCredential = false;
  bool _actionPending = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _gateway = TextEditingController();
    _deviceName = TextEditingController(text: '此设备');
    _certificate = TextEditingController();
    if (widget.restoreOnOpen) {
      Future<void>.microtask(
        () => ref.read(devicePairingProvider.notifier).restore(),
      );
    }
  }

  @override
  void dispose() {
    _gateway.dispose();
    _deviceName.dispose();
    _certificate.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_actionPending) return;
    setState(() {
      _actionPending = true;
      _localError = null;
    });
    try {
      await action();
    } on StateError {
      if (mounted) {
        setState(() {
          _localError = '此操作已不适用于当前配对状态。';
        });
      }
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _begin() => _run(() async {
    final scopes = <String>[
      'observe',
      if (_send) 'send',
      if (_interrupt) 'interrupt',
      if (_approve) 'approve',
    ];
    final certificateText = _certificate.text.trim();
    await ref
        .read(devicePairingProvider.notifier)
        .begin(
          deviceDisplayName: _deviceName.text,
          gatewayAudience: _gateway.text.trim(),
          requestedScopes: scopes,
          trustedRootCertificates: certificateText.isEmpty
              ? null
              : utf8.encode(certificateText),
        );
  });

  Future<void> _importPrivateCaCertificate() async {
    if (_actionPending) return;
    setState(() {
      _actionPending = true;
      _localError = null;
    });
    try {
      final certificate = await widget.certificatePicker.pick();
      if (!mounted || certificate == null) return;
      _certificate.value = TextEditingValue(
        text: certificate,
        selection: TextSelection.collapsed(offset: certificate.length),
      );
    } on PrivateCaCertificatePickerException catch (error) {
      if (mounted) setState(() => _localError = error.message);
    } on FormatException {
      if (mounted) {
        setState(() => _localError = '证书文件不是有效的 UTF-8 PEM。请选择 CA 证书。');
      }
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(devicePairingProvider);
    final tokens = context.visualTokens;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: tokens.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: tokens.structureLine),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 760),
        child: Column(
          children: [
            _PairingHeader(phase: state.phase),
            Divider(height: 1, color: tokens.structureLine),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showRail = constraints.maxWidth >= 660;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showRail) _PairingProgressRail(phase: state.phase),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _buildPhase(context, state),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhase(BuildContext context, PairingState state) {
    final content = switch (state.phase) {
      PairingPhase.idle => _buildSetup(context),
      PairingPhase.beginning ||
      PairingPhase.completing ||
      PairingPhase.confirming => _BusyPairingPhase(phase: state.phase),
      PairingPhase.awaitingOwnerApproval => _buildOwnerApproval(context, state),
      PairingPhase.awaitingConfirmation => _buildConfirmation(context, state),
      PairingPhase.paired => _buildPaired(context, state),
      PairingPhase.failed => _buildFailure(context, state),
      PairingPhase.uncertain => _buildUncertain(context, state),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        if (_localError != null) ...[
          const SizedBox(height: 16),
          _InlineNotice(
            icon: Icons.error_outline,
            message: _localError!,
            color: context.visualTokens.danger,
          ),
        ],
      ],
    );
  }

  Widget _buildSetup(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PhaseTitle(
          eyebrow: '01 / 建立连接',
          title: '为中继两端命名',
          body:
              '只有已确认文本会跨过这条边界。配对会创建可撤销的设备密钥；'
              '不会批准未来的 Agent 操作。',
        ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('pairing-gateway-field'),
          controller: _gateway,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Gateway HTTPS 地址',
            hintText: 'https://gateway.example',
            helperText: '不允许路径、查询参数、嵌入式用户或绕过 TLS。',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('pairing-device-name-field'),
          controller: _deviceName,
          maxLength: 128,
          decoration: const InputDecoration(labelText: '设备显示名称'),
        ),
        const SizedBox(height: 8),
        Text('请求的能力', style: _sectionLabel(context)),
        const SizedBox(height: 8),
        const CheckboxListTile(
          value: true,
          onChanged: null,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('查看完整回复'),
          subtitle: Text('必需；不会授予控制权。'),
        ),
        CheckboxListTile(
          value: _send,
          onChanged: (value) => setState(() => _send = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('发送已确认文本'),
        ),
        CheckboxListTile(
          value: _interrupt,
          onChanged: (value) => setState(() => _interrupt = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('中断活动请求'),
        ),
        CheckboxListTile(
          value: _approve,
          onChanged: (value) => setState(() => _approve = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('响应 Agent 审批'),
          subtitle: const Text('每次审批仍需明确选择。'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('pairing-import-ca-button'),
            onPressed: _actionPending ? null : _importPrivateCaCertificate,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('从文件导入 PEM'),
          ),
        ),
        const SizedBox(height: 4),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('私有 CA 证书'),
          subtitle: const Text('自托管 Gateway 可选的 PEM'),
          children: [
            TextField(
              key: const Key('pairing-certificate-field'),
              controller: _certificate,
              minLines: 3,
              maxLines: 6,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: '-----BEGIN CERTIFICATE-----',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('pairing-begin-button'),
          onPressed: _actionPending ? null : _begin,
          icon: const Icon(Icons.key_outlined),
          label: const Text('创建配对请求'),
        ),
      ],
    );
  }

  Widget _buildOwnerApproval(BuildContext context, PairingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PhaseTitle(
          eyebrow: '02 / 验证',
          title: '授权前进行比对',
          body: '请在已有的所有者设备上打开验证地址，仅当所有指纹和能力都匹配时才批准。',
        ),
        const SizedBox(height: 24),
        _UserCode(value: state.userCode ?? '—'),
        const SizedBox(height: 20),
        _Fact(label: '验证地址', value: state.verificationUri?.toString() ?? '—'),
        _Fact(label: 'Gateway', value: state.gatewayAudience ?? '—'),
        _Fact(label: 'Gateway 指纹', value: state.gatewayFingerprint ?? '—'),
        _Fact(label: '设备指纹', value: state.deviceFingerprint ?? '—'),
        _Fact(label: '请求的能力', value: state.requestedScopes.join('  /  ')),
        const SizedBox(height: 16),
        _InlineNotice(
          icon: Icons.front_hand_outlined,
          message:
              'VoxHandoff 不会替你点击“批准”。此按钮只会询问 Gateway 是否已经记录了你在另一台所有者设备上的决定。',
          color: context.visualTokens.attention,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _actionPending
              ? null
              : () => _run(
                  ref
                      .read(devicePairingProvider.notifier)
                      .completeAfterOwnerApproval,
                ),
          child: const Text('我已完成所有者端审核'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _actionPending
              ? null
              : () => _run(ref.read(devicePairingProvider.notifier).abandon),
          child: const Text('放弃本地配对尝试'),
        ),
      ],
    );
  }

  Widget _buildConfirmation(BuildContext context, PairingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PhaseTitle(
          eyebrow: '03 / 证明',
          title: '回读新凭据',
          body: '设备将对第二个独立挑战进行签名。只有保存返回的凭据后，配对才算完成。',
        ),
        const SizedBox(height: 24),
        _Fact(label: '设备 ID', value: state.deviceId ?? '待定'),
        _Fact(label: '凭据 ID', value: state.credentialId ?? '待定'),
        _Fact(label: '已批准的能力', value: state.approvedScopes.join('  /  ')),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _actionPending
              ? null
              : () => _run(ref.read(devicePairingProvider.notifier).confirm),
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('验证并保存凭据'),
        ),
      ],
    );
  }

  Widget _buildPaired(BuildContext context, PairingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PhaseTitle(
          eyebrow: '连接 / 已封存',
          title: '此设备已配对',
          body: '私钥和轮换凭据由操作系统保存。下一步是建立实时会话连接。',
        ),
        const SizedBox(height: 24),
        _Fact(label: 'Gateway', value: state.gatewayAudience ?? '—'),
        _Fact(label: '设备 ID', value: state.deviceId ?? '—'),
        _Fact(label: '能力', value: state.approvedScopes.join('  /  ')),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('返回中继'),
        ),
      ],
    );
  }

  Widget _buildFailure(BuildContext context, PairingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhaseTitle(
          eyebrow: '连接 / 已停止',
          title: '配对已安全停止',
          body: state.safeErrorMessage ?? '未接受任何凭据。请检查本地设置后重试。',
        ),
        const SizedBox(height: 20),
        _InlineNotice(
          icon: Icons.error_outline,
          message: '代码：${state.safeErrorCode ?? 'pairing_failed'}',
          color: context.visualTokens.danger,
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: _actionPending
              ? null
              : () =>
                    _run(ref.read(devicePairingProvider.notifier).resetFailure),
          child: const Text('清除失败尝试'),
        ),
      ],
    );
  }

  Widget _buildUncertain(BuildContext context, PairingState state) {
    final canRetry = state.operation != PairingOperation.begin;
    final mustCommit = state.operation == PairingOperation.credentialCommit;
    final confirmMayExist = state.operation == PairingOperation.confirm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhaseTitle(
          eyebrow: '连接 / 未决',
          title: 'Gateway 结果未知',
          body: state.safeErrorMessage ?? '未自动重试。请检查所有者设备和 Gateway 后选择恢复操作。',
        ),
        const SizedBox(height: 20),
        _Fact(label: '中断阶段', value: state.operation?.name ?? 'unknown'),
        if (canRetry) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _actionPending
                ? null
                : () => _run(
                    ref.read(devicePairingProvider.notifier).retryUncertain,
                  ),
            child: Text(mustCommit ? '完成本地凭据保存' : '重试已保存的原请求'),
          ),
        ],
        if (!mustCommit) ...[
          if (confirmMayExist) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _acknowledgeRemoteCredential,
              onChanged: (value) =>
                  setState(() => _acknowledgeRemoteCredential = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('我了解 Gateway 可能仍持有有效凭据'),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed:
                _actionPending ||
                    (confirmMayExist && !_acknowledgeRemoteCredential)
                ? null
                : () => _run(
                    () => ref
                        .read(devicePairingProvider.notifier)
                        .abandon(
                          acknowledgeRemoteCredentialMayExist:
                              _acknowledgeRemoteCredential,
                        ),
                  ),
            child: const Text('放弃本地配对尝试'),
          ),
        ],
      ],
    );
  }

  TextStyle _sectionLabel(BuildContext context) => TextStyle(
    color: context.visualTokens.signal,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.7,
  );
}
