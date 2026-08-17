import 'package:flutter/material.dart';

import '../application/onboarding_pairing_controller.dart';
import '../domain/onboarding_pairing.dart';
import 'qr_pairing_scanner_page.dart';

typedef OnboardingQrScanner = Future<String?> Function(BuildContext context);

Future<void> showOnboardingPairingPage(
  BuildContext context, {
  required OnboardingPairingController controller,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => OnboardingPairingPage(controller: controller),
  ),
);

class OnboardingPairingPage extends StatefulWidget {
  const OnboardingPairingPage({
    required this.controller,
    this.scanQr = showQrPairingScanner,
    super.key,
  });

  final OnboardingPairingController controller;
  final OnboardingQrScanner scanQr;

  @override
  State<OnboardingPairingPage> createState() => _OnboardingPairingPageState();
}

class _OnboardingPairingPageState extends State<OnboardingPairingPage> {
  late final TextEditingController _deviceName;
  var _actionPending = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _deviceName = TextEditingController(text: '此设备');
  }

  @override
  void dispose() {
    _deviceName.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_actionPending) return;
    setState(() {
      _actionPending = true;
      _localError = null;
    });
    try {
      widget.controller.startScanning();
      final encoded = await widget.scanQr(context);
      if (!mounted) return;
      if (encoded == null) {
        widget.controller.abortScanning();
        return;
      }
      await widget.controller.acceptQrCode(
        encoded,
        deviceName: _deviceName.text,
      );
    } on OnboardingPairingException catch (error) {
      if (mounted) setState(() => _localError = error.message);
    } on Object {
      if (mounted) setState(() => _localError = '扫描未完成，请稍后重试。');
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _refresh() async {
    await _run(widget.controller.refreshHostStatus);
  }

  Future<void> _cancel() async {
    await _run(widget.controller.cancel);
  }

  Future<void> _reset() async {
    await _run(widget.controller.reset);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_actionPending) return;
    setState(() {
      _actionPending = true;
      _localError = null;
    });
    try {
      await action();
    } on OnboardingPairingException catch (error) {
      if (mounted) setState(() => _localError = error.message);
    } on Object {
      if (mounted) setState(() => _localError = '操作未完成，请稍后重试。');
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('手机安全配对')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              child: _buildContent(context, widget.controller.state),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildContent(BuildContext context, OnboardingPairingState state) {
    final error = state.safeErrorMessage ?? _localError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '连接 Companion Bridge',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          '二维码只用于找到并认证主机。设备密钥由本机安全硬件生成，私钥不会离开手机。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        switch (state.phase) {
          OnboardingPairingPhase.pending => _buildPending(context),
          OnboardingPairingPhase.scanning => _buildBusy('等待扫描二维码'),
          OnboardingPairingPhase.keygen => _buildBusy('正在生成设备密钥'),
          OnboardingPairingPhase.exchange => _buildBusy('正在向主机发起配对'),
          OnboardingPairingPhase.waitingHostConfirmation => _buildWaiting(
            context,
            state,
            error,
          ),
          OnboardingPairingPhase.confirmed => _buildTerminal(
            context,
            Icons.verified_outlined,
            '主机已确认这台设备',
            '设备身份已绑定。后续长期凭据将保持每台手机独立、可撤销。',
            null,
          ),
          OnboardingPairingPhase.expired => _buildTerminal(
            context,
            Icons.timer_off_outlined,
            '二维码已过期',
            '请回到主机重新生成二维码。',
            _resetButton('重新开始', _reset),
          ),
          OnboardingPairingPhase.cancelled => _buildTerminal(
            context,
            Icons.cancel_outlined,
            '配对已取消',
            '本机生成的待配对密钥已清理。',
            _resetButton('重新开始', _reset),
          ),
          OnboardingPairingPhase.failed => _buildTerminal(
            context,
            Icons.error_outline,
            '配对未完成',
            error ?? '请检查设备状态后重试。',
            _resetButton('重新开始', _reset),
          ),
          OnboardingPairingPhase.uncertain => _buildTerminal(
            context,
            Icons.warning_amber_outlined,
            '配对结果待确认',
            error ?? '请先在主机查看配对状态，再决定是否处理这次请求。',
            _resetButton('清理本次请求', _reset),
          ),
        },
        if (error != null &&
            state.phase != OnboardingPairingPhase.failed &&
            state.phase != OnboardingPairingPhase.uncertain) ...[
          const SizedBox(height: 20),
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildPending(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const Key('onboarding-device-name-field'),
        controller: _deviceName,
        maxLength: 64,
        decoration: const InputDecoration(
          labelText: '设备名称',
          hintText: '例如：vivo V2359A',
          helperText: '主机会显示这个名称，并要求你确认。',
        ),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        key: const Key('onboarding-scan-button'),
        onPressed: _actionPending ? null : _scan,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('扫描主机二维码'),
      ),
    ],
  );

  Widget _buildBusy(String message) => Column(
    children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 18),
      Text(message, textAlign: TextAlign.center),
    ],
  );

  Widget _buildWaiting(
    BuildContext context,
    OnboardingPairingState state,
    String? error,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.desktop_windows_outlined, size: 52),
      const SizedBox(height: 16),
      Text(
        '请在主机上确认这台设备',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        state.deviceName ?? '此设备',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 22),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
          child: Column(
            children: [
              const Text('主机确认码'),
              const SizedBox(height: 8),
              SelectableText(
                state.confirmationCode ?? '------',
                key: const Key('onboarding-confirmation-code'),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  letterSpacing: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 16),
        Text(
          error,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 22),
      FilledButton.icon(
        key: const Key('onboarding-refresh-button'),
        onPressed: _actionPending ? null : _refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('刷新主机状态'),
      ),
      const SizedBox(height: 10),
      TextButton(
        key: const Key('onboarding-cancel-button'),
        onPressed: _actionPending ? null : _cancel,
        child: const Text('取消配对'),
      ),
    ],
  );

  Widget _buildTerminal(
    BuildContext context,
    IconData icon,
    String title,
    String body,
    Widget? action,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(icon, size: 56),
      const SizedBox(height: 18),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 10),
      Text(body, textAlign: TextAlign.center),
      if (action != null) ...[const SizedBox(height: 24), action],
    ],
  );

  Widget _resetButton(String label, Future<void> Function() action) =>
      FilledButton(
        onPressed: _actionPending ? null : action,
        child: Text(label),
      );
}
