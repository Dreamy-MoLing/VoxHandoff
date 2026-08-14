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
    _deviceName = TextEditingController(text: 'This device');
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
          _localError =
              'That action is no longer valid for the current pairing state.';
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
        setState(
          () => _localError =
              'Certificate file is not valid UTF-8 PEM. Choose a CA certificate.',
        );
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
          eyebrow: '01 / ESTABLISH',
          title: 'Name both ends of the relay',
          body:
              'Only confirmed text crosses this boundary. Pairing creates a '
              'revocable device key; it does not approve future Agent actions.',
        ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('pairing-gateway-field'),
          controller: _gateway,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Gateway HTTPS origin',
            hintText: 'https://gateway.example',
            helperText: 'No path, query, embedded user, or TLS bypass.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('pairing-device-name-field'),
          controller: _deviceName,
          maxLength: 128,
          decoration: const InputDecoration(labelText: 'Device display name'),
        ),
        const SizedBox(height: 8),
        Text('REQUESTED CAPABILITIES', style: _sectionLabel(context)),
        const SizedBox(height: 8),
        const CheckboxListTile(
          value: true,
          onChanged: null,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('Observe complete replies'),
          subtitle: Text('Required; does not grant control.'),
        ),
        CheckboxListTile(
          value: _send,
          onChanged: (value) => setState(() => _send = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Send confirmed text'),
        ),
        CheckboxListTile(
          value: _interrupt,
          onChanged: (value) => setState(() => _interrupt = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Interrupt an active request'),
        ),
        CheckboxListTile(
          value: _approve,
          onChanged: (value) => setState(() => _approve = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Respond to Agent approvals'),
          subtitle: const Text(
            'Every approval still requires an explicit choice.',
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('pairing-import-ca-button'),
            onPressed: _actionPending ? null : _importPrivateCaCertificate,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Import PEM from file'),
          ),
        ),
        const SizedBox(height: 4),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Private CA certificate'),
          subtitle: const Text('Optional PEM for a self-hosted Gateway'),
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
          label: const Text('Create pairing request'),
        ),
      ],
    );
  }

  Widget _buildOwnerApproval(BuildContext context, PairingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PhaseTitle(
          eyebrow: '02 / VERIFY',
          title: 'Compare before you authorize',
          body:
              'On an existing owner device, open the verification address and '
              'approve only if every fingerprint and capability matches.',
        ),
        const SizedBox(height: 24),
        _UserCode(value: state.userCode ?? '—'),
        const SizedBox(height: 20),
        _Fact(
          label: 'Verification address',
          value: state.verificationUri?.toString() ?? '—',
        ),
        _Fact(label: 'Gateway', value: state.gatewayAudience ?? '—'),
        _Fact(
          label: 'Gateway fingerprint',
          value: state.gatewayFingerprint ?? '—',
        ),
        _Fact(
          label: 'Device fingerprint',
          value: state.deviceFingerprint ?? '—',
        ),
        _Fact(
          label: 'Requested capabilities',
          value: state.requestedScopes.join('  /  '),
        ),
        const SizedBox(height: 16),
        _InlineNotice(
          icon: Icons.front_hand_outlined,
          message:
              'VoxHandoff will not click Approve for you. This button only asks '
              'the Gateway whether your separate owner decision is now present.',
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
          child: const Text('I completed the owner-side review'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _actionPending
              ? null
              : () => _run(ref.read(devicePairingProvider.notifier).abandon),
          child: const Text('Abandon local pairing attempt'),
        ),
      ],
    );
  }

  Widget _buildConfirmation(BuildContext context, PairingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PhaseTitle(
          eyebrow: '03 / PROVE',
          title: 'Read back the new credential',
          body:
              'The device will sign a second, independent challenge. Pairing is '
              'not complete until the returned credential is saved locally.',
        ),
        const SizedBox(height: 24),
        _Fact(label: 'Device ID', value: state.deviceId ?? 'Pending'),
        _Fact(label: 'Credential ID', value: state.credentialId ?? 'Pending'),
        _Fact(
          label: 'Approved capabilities',
          value: state.approvedScopes.join('  /  '),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _actionPending
              ? null
              : () => _run(ref.read(devicePairingProvider.notifier).confirm),
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Verify and store credential'),
        ),
      ],
    );
  }

  Widget _buildPaired(BuildContext context, PairingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PhaseTitle(
          eyebrow: 'LINK / SEALED',
          title: 'This device is paired',
          body:
              'The private key and rotating credential are stored by the '
              'operating system. Live session connection is the next stage.',
        ),
        const SizedBox(height: 24),
        _Fact(label: 'Gateway', value: state.gatewayAudience ?? '—'),
        _Fact(label: 'Device ID', value: state.deviceId ?? '—'),
        _Fact(label: 'Capabilities', value: state.approvedScopes.join('  /  ')),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Return to relay'),
        ),
      ],
    );
  }

  Widget _buildFailure(BuildContext context, PairingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhaseTitle(
          eyebrow: 'LINK / STOPPED',
          title: 'Pairing stopped safely',
          body:
              state.safeErrorMessage ??
              'No credential was accepted. Review the local setup and try again.',
        ),
        const SizedBox(height: 20),
        _InlineNotice(
          icon: Icons.error_outline,
          message: 'Code: ${state.safeErrorCode ?? 'pairing_failed'}',
          color: context.visualTokens.danger,
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: _actionPending
              ? null
              : () =>
                    _run(ref.read(devicePairingProvider.notifier).resetFailure),
          child: const Text('Clear failed attempt'),
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
          eyebrow: 'LINK / UNRESOLVED',
          title: 'The Gateway outcome is unknown',
          body:
              state.safeErrorMessage ??
              'Nothing was retried automatically. Choose a recovery action '
                  'after checking the owner device and Gateway.',
        ),
        const SizedBox(height: 20),
        _Fact(
          label: 'Interrupted stage',
          value: state.operation?.name ?? 'unknown',
        ),
        if (canRetry) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _actionPending
                ? null
                : () => _run(
                    ref.read(devicePairingProvider.notifier).retryUncertain,
                  ),
            child: Text(
              mustCommit
                  ? 'Finish local credential storage'
                  : 'Retry the exact saved request',
            ),
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
              title: const Text(
                'I understand the Gateway may hold an active credential',
              ),
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
            child: const Text('Abandon local pairing attempt'),
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
