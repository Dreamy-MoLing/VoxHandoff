import 'package:agent_talk_client/application/device_pairing_controller.dart';
import 'package:agent_talk_client/application/device_pairing_workflow.dart';
import 'package:agent_talk_client/domain/device_pairing.dart';
import 'package:agent_talk_client/infrastructure/security/private_ca_certificate_picker.dart';
import 'package:agent_talk_client/presentation/design/agent_talk_theme.dart';
import 'package:agent_talk_client/presentation/pairing_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class PairingDialogTestWorkflow implements DevicePairingWorkflow {
  PairingDialogTestWorkflow(this.publish, {PairingState? initial})
    : _state = initial ?? PairingState();

  final void Function(PairingState state) publish;
  PairingState _state;
  var beginCalls = 0;
  var completeCalls = 0;
  var confirmCalls = 0;
  var retryCalls = 0;
  var abandonCalls = 0;
  var acknowledged = false;
  String? gateway;
  List<String> requestedScopes = const [];

  @override
  PairingState get state => _state;

  @override
  Future<void> restore() async => publish(_state);

  @override
  Future<void> begin({
    required String deviceDisplayName,
    required String expectedGatewayAudience,
    required Iterable<String> requestedScopes,
  }) async {
    beginCalls += 1;
    gateway = expectedGatewayAudience;
    this.requestedScopes = List.of(requestedScopes);
    _set(
      PairingState(
        phase: PairingPhase.awaitingOwnerApproval,
        deviceDisplayName: deviceDisplayName,
        pairingId: 'pairing-1',
        userCode: 'ABCD-EFGH',
        verificationUri: Uri.parse('https://gateway.example/pair'),
        deviceFingerprint: 'sha256:${List.filled(64, 'a').join()}',
        gatewayFingerprint: 'sha256:${List.filled(64, 'b').join()}',
        gatewayAudience: expectedGatewayAudience,
        requestedScopes: this.requestedScopes,
      ),
    );
  }

  @override
  Future<void> completeAfterOwnerApproval() async {
    completeCalls += 1;
    _set(
      PairingState(
        phase: PairingPhase.awaitingConfirmation,
        gatewayAudience: gateway,
        requestedScopes: requestedScopes,
        approvedScopes: const ['observe'],
        deviceId: 'device-1',
        credentialId: 'credential-1',
      ),
    );
  }

  @override
  Future<void> confirm() async {
    confirmCalls += 1;
    _set(
      PairingState(
        phase: PairingPhase.paired,
        gatewayAudience: gateway,
        approvedScopes: const ['observe'],
        deviceId: 'device-1',
        credentialId: 'credential-1',
      ),
    );
  }

  @override
  Future<void> retryUncertain() async {
    retryCalls += 1;
  }

  @override
  Future<void> abandon({
    bool acknowledgeRemoteCredentialMayExist = false,
  }) async {
    abandonCalls += 1;
    acknowledged = acknowledgeRemoteCredentialMayExist;
    _set(PairingState());
  }

  void _set(PairingState next) {
    _state = next;
    publish(next);
  }
}

class PairingDialogTestFactory implements DevicePairingWorkflowFactory {
  PairingDialogTestFactory({this.restoredState});

  final PairingState? restoredState;
  PairingDialogTestWorkflow? workflow;
  var closeCalls = 0;

  @override
  Future<DevicePairingWorkflowSession> create({
    required String gatewayAudience,
    required void Function(PairingState state) onStateChanged,
    List<int>? trustedRootCertificates,
  }) async {
    final created = PairingDialogTestWorkflow(onStateChanged);
    workflow = created;
    return _session(created);
  }

  @override
  Future<DevicePairingWorkflowSession?> restore({
    required void Function(PairingState state) onStateChanged,
  }) async {
    final restored = restoredState;
    if (restored == null) return null;
    final created = PairingDialogTestWorkflow(
      onStateChanged,
      initial: restored,
    );
    workflow = created;
    onStateChanged(restored);
    return _session(created);
  }

  DevicePairingWorkflowSession _session(PairingDialogTestWorkflow workflow) =>
      DevicePairingWorkflowSession(
        workflow: workflow,
        closeCallback: () => closeCalls += 1,
      );
}

class TestPrivateCaCertificatePicker implements PrivateCaCertificatePicker {
  TestPrivateCaCertificatePicker(this.certificate);

  final String? certificate;
  var calls = 0;

  @override
  Future<String?> pick() async {
    calls += 1;
    return certificate;
  }
}

Widget pairingHarness(
  PairingDialogTestFactory factory, {
  PrivateCaCertificatePicker? certificatePicker,
}) => ProviderScope(
  overrides: [pairingWorkflowFactoryProvider.overrideWithValue(factory)],
  child: MaterialApp(
    theme: buildAgentTalkDarkTheme(),
    home: Scaffold(
      body: DevicePairingDialog(
        certificatePicker:
            certificatePicker ?? const PlatformPrivateCaCertificatePicker(),
      ),
    ),
  ),
);

void main() {
  testWidgets('keeps setup explicit and advances through all signed phases', (
    tester,
  ) async {
    final factory = PairingDialogTestFactory();
    await tester.pumpWidget(pairingHarness(factory));
    await tester.pumpAndSettle();

    expect(find.text('为中继两端命名'), findsOneWidget);
    expect(find.textContaining('不会批准未来的 Agent 操作'), findsOneWidget);
    expect(find.text('不自动批准\n不静默重试'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('pairing-gateway-field')),
      'https://gateway.example',
    );
    await tester.ensureVisible(find.byKey(const Key('pairing-begin-button')));
    await tester.tap(find.byKey(const Key('pairing-begin-button')));
    await tester.pumpAndSettle();

    expect(factory.workflow!.beginCalls, 1);
    expect(factory.workflow!.requestedScopes, ['observe', 'send']);
    expect(find.text('ABCD-EFGH'), findsOneWidget);
    expect(find.text('授权前进行比对'), findsOneWidget);
    expect(find.textContaining('不会替你点击“批准”'), findsOneWidget);

    final ownerReview = find.widgetWithText(FilledButton, '我已完成所有者端审核');
    await tester.ensureVisible(ownerReview);
    await tester.tap(ownerReview);
    await tester.pumpAndSettle();
    expect(factory.workflow!.completeCalls, 1);
    expect(find.text('回读新凭据'), findsOneWidget);

    final confirmation = find.widgetWithText(FilledButton, '验证并保存凭据');
    await tester.ensureVisible(confirmation);
    await tester.tap(confirmation);
    await tester.pumpAndSettle();
    expect(factory.workflow!.confirmCalls, 1);
    expect(factory.closeCalls, 1);
    expect(find.text('此设备已配对'), findsOneWidget);
  });

  testWidgets('requires acknowledgement before abandoning uncertain Confirm', (
    tester,
  ) async {
    final factory = PairingDialogTestFactory(
      restoredState: PairingState(
        phase: PairingPhase.uncertain,
        operation: PairingOperation.confirm,
        safeErrorCode: 'outcome_uncertain',
      ),
    );
    await tester.pumpWidget(pairingHarness(factory));
    await tester.pumpAndSettle();

    expect(find.text('Gateway 结果未知'), findsOneWidget);
    expect(find.text('重试已保存的原请求'), findsOneWidget);
    final abandonBefore = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '放弃本地配对尝试'),
    );
    expect(abandonBefore.onPressed, isNull);

    final acknowledgement = find.text('我了解 Gateway 可能仍持有有效凭据');
    await tester.ensureVisible(acknowledgement);
    await tester.tap(acknowledgement);
    await tester.pump();
    final abandonAfter = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '放弃本地配对尝试'),
    );
    expect(abandonAfter.onPressed, isNotNull);
    final abandon = find.widgetWithText(OutlinedButton, '放弃本地配对尝试');
    await tester.ensureVisible(abandon);
    await tester.tap(abandon);
    await tester.pumpAndSettle();

    expect(factory.workflow!.acknowledged, isTrue);
    expect(factory.closeCalls, 1);
    expect(find.text('为中继两端命名'), findsOneWidget);
  });

  testWidgets('can abandon a pending owner approval locally', (tester) async {
    final factory = PairingDialogTestFactory();
    await tester.pumpWidget(pairingHarness(factory));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('pairing-gateway-field')),
      'https://gateway.example',
    );
    await tester.ensureVisible(find.byKey(const Key('pairing-begin-button')));
    await tester.tap(find.byKey(const Key('pairing-begin-button')));
    await tester.pumpAndSettle();

    final abandon = find.widgetWithText(OutlinedButton, '放弃本地配对尝试');
    await tester.ensureVisible(abandon);
    await tester.tap(abandon);
    await tester.pumpAndSettle();

    expect(factory.workflow!.abandonCalls, 1);
    expect(factory.workflow!.acknowledged, isFalse);
    expect(factory.closeCalls, 1);
    expect(find.text('为中继两端命名'), findsOneWidget);
  });

  testWidgets('imports a PEM certificate without multiline text injection', (
    tester,
  ) async {
    const certificate = '''-----BEGIN CERTIFICATE-----
ZmFrZS1jZXJ0aWZpY2F0ZQ==
-----END CERTIFICATE-----''';
    final picker = TestPrivateCaCertificatePicker(certificate);
    await tester.pumpWidget(
      pairingHarness(PairingDialogTestFactory(), certificatePicker: picker),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('pairing-import-ca-button')),
    );
    await tester.tap(find.byKey(const Key('pairing-import-ca-button')));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    final caSection = find.text('私有 CA 证书');
    await tester.ensureVisible(caSection);
    await tester.tap(caSection);
    await tester.pumpAndSettle();
    final certificateField = tester.widget<TextField>(
      find.byKey(const Key('pairing-certificate-field')),
    );
    expect(certificateField.controller!.text, certificate);
  });

  testWidgets('has no overflow on a phone viewport and meets tap semantics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(pairingHarness(PairingDialogTestFactory()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });
}
