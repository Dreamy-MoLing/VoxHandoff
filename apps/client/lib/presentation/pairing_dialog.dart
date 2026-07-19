import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/device_pairing_controller.dart';
import '../domain/device_pairing.dart';
import 'design/agent_talk_theme.dart';

Future<void> showDevicePairingDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => const DevicePairingDialog(),
);

class DevicePairingDialog extends ConsumerStatefulWidget {
  const DevicePairingDialog({super.key, this.restoreOnOpen = true});

  final bool restoreOnOpen;

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
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Private CA certificate'),
          subtitle: const Text('Optional PEM for a self-hosted Gateway'),
          children: [
            TextField(
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
              'Agent Talk will not click Approve for you. This button only asks '
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

class _PairingHeader extends StatelessWidget {
  const _PairingHeader({required this.phase});

  final PairingPhase phase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
      child: Row(
        children: [
          Icon(Icons.hub_outlined, color: context.visualTokens.signal),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'GATEWAY PAIRING / MANUAL LINK',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.4),
            ),
          ),
          Text(
            phase.name.toUpperCase(),
            style: TextStyle(
              color: context.visualTokens.textMuted,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          IconButton(
            tooltip: 'Close pairing panel',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _PairingProgressRail extends StatelessWidget {
  const _PairingProgressRail({required this.phase});

  final PairingPhase phase;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final activeStep = switch (phase) {
      PairingPhase.idle || PairingPhase.beginning => 0,
      PairingPhase.awaitingOwnerApproval || PairingPhase.completing => 1,
      PairingPhase.awaitingConfirmation || PairingPhase.confirming => 2,
      PairingPhase.paired => 3,
      PairingPhase.failed || PairingPhase.uncertain => -1,
    };
    return Container(
      width: 176,
      padding: const EdgeInsets.fromLTRB(20, 28, 16, 24),
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(right: BorderSide(color: tokens.structureLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LINK MAP',
            style: TextStyle(color: tokens.signal, letterSpacing: 1.8),
          ),
          const SizedBox(height: 24),
          for (final step in const [
            ('01', 'Establish'),
            ('02', 'Verify'),
            ('03', 'Prove'),
            ('04', 'Sealed'),
          ]) ...[
            _RailStep(
              number: step.$1,
              label: step.$2,
              active: int.parse(step.$1) - 1 == activeStep,
              complete: int.parse(step.$1) - 1 < activeStep,
            ),
            if (step.$1 != '04')
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.only(left: 9),
                color: tokens.structureLine,
              ),
          ],
          const Spacer(),
          Text(
            'NO AUTO-APPROVAL\nNO SILENT RETRY',
            style: TextStyle(
              color: tokens.attention,
              fontSize: 10,
              height: 1.5,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailStep extends StatelessWidget {
  const _RailStep({
    required this.number,
    required this.label,
    required this.active,
    required this.complete,
  });

  final String number;
  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final color = active || complete ? tokens.signal : tokens.textMuted;
    return Row(
      children: [
        Container(
          width: 19,
          height: 19,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: complete ? tokens.signal : Colors.transparent,
            border: Border.all(color: color),
          ),
          child: complete
              ? Icon(Icons.check, size: 13, color: tokens.ink)
              : Text(number, style: TextStyle(color: color, fontSize: 9)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: active ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhaseTitle extends StatelessWidget {
  const _PhaseTitle({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: context.visualTokens.signal,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text(
          body,
          style: TextStyle(color: context.visualTokens.textMuted, height: 1.45),
        ),
      ],
    );
  }
}

class _BusyPairingPhase extends StatelessWidget {
  const _BusyPairingPhase({required this.phase});

  final PairingPhase phase;

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      PairingPhase.beginning => 'Preparing a local device key',
      PairingPhase.completing => 'Verifying the owner decision',
      PairingPhase.confirming => 'Reading back the credential',
      _ => 'Working',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhaseTitle(
          eyebrow: 'LINK / IN PROGRESS',
          title: label,
          body:
              'This is one bounded request. A lost response will stop as unresolved.',
        ),
        const SizedBox(height: 28),
        const LinearProgressIndicator(),
      ],
    );
  }
}

class _UserCode extends StatelessWidget {
  const _UserCode({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(left: BorderSide(color: tokens.attention, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ONE-TIME CODE',
            style: TextStyle(color: tokens.textMuted, letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: context.visualTokens.textMuted,
              fontSize: 10,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value.isEmpty ? '—' : value),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.08),
          context.visualTokens.panel,
        ),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
