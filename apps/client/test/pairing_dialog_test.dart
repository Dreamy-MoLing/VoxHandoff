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

    expect(find.text('Name both ends of the relay'), findsOneWidget);
    expect(
      find.textContaining('does not approve future Agent actions'),
      findsOneWidget,
    );
    expect(find.text('NO AUTO-APPROVAL\nNO SILENT RETRY'), findsOneWidget);
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
    expect(find.text('Compare before you authorize'), findsOneWidget);
    expect(
      find.textContaining('will not click Approve for you'),
      findsOneWidget,
    );

    final ownerReview = find.widgetWithText(
      FilledButton,
      'I completed the owner-side review',
    );
    await tester.ensureVisible(ownerReview);
    await tester.tap(ownerReview);
    await tester.pumpAndSettle();
    expect(factory.workflow!.completeCalls, 1);
    expect(find.text('Read back the new credential'), findsOneWidget);

    final confirmation = find.widgetWithText(
      FilledButton,
      'Verify and store credential',
    );
    await tester.ensureVisible(confirmation);
    await tester.tap(confirmation);
    await tester.pumpAndSettle();
    expect(factory.workflow!.confirmCalls, 1);
    expect(factory.closeCalls, 1);
    expect(find.text('This device is paired'), findsOneWidget);
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

    expect(find.text('The Gateway outcome is unknown'), findsOneWidget);
    expect(find.text('Retry the exact saved request'), findsOneWidget);
    final abandonBefore = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Abandon local pairing attempt'),
    );
    expect(abandonBefore.onPressed, isNull);

    final acknowledgement = find.text(
      'I understand the Gateway may hold an active credential',
    );
    await tester.ensureVisible(acknowledgement);
    await tester.tap(acknowledgement);
    await tester.pump();
    final abandonAfter = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Abandon local pairing attempt'),
    );
    expect(abandonAfter.onPressed, isNotNull);
    final abandon = find.widgetWithText(
      OutlinedButton,
      'Abandon local pairing attempt',
    );
    await tester.ensureVisible(abandon);
    await tester.tap(abandon);
    await tester.pumpAndSettle();

    expect(factory.workflow!.acknowledged, isTrue);
    expect(factory.closeCalls, 1);
    expect(find.text('Name both ends of the relay'), findsOneWidget);
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

    final abandon = find.widgetWithText(
      OutlinedButton,
      'Abandon local pairing attempt',
    );
    await tester.ensureVisible(abandon);
    await tester.tap(abandon);
    await tester.pumpAndSettle();

    expect(factory.workflow!.abandonCalls, 1);
    expect(factory.workflow!.acknowledged, isFalse);
    expect(factory.closeCalls, 1);
    expect(find.text('Name both ends of the relay'), findsOneWidget);
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
    final caSection = find.text('Private CA certificate');
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
