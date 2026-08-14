import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:cryptography/cryptography.dart';

import '../../application/client_event_convergence.dart';
import '../../application/gateway_frame_router.dart';
import '../../application/gateway_workspace_controller.dart';
import '../../domain/client_event.dart';
import '../../domain/device_pairing.dart';
import '../../domain/gateway_sync.dart';
import '../security/flutter_secure_value_store.dart';
import '../security/device_key_vault.dart';
import '../security/secure_pairing_stores.dart';
import '../storage/drift_client_event_ledger.dart';
import 'gateway_frame_mapper.dart';
import 'gateway_grpc_channel_factory.dart';
import 'grpc_gateway_command_port.dart';
import 'grpc_gateway_live_transport.dart';
import 'grpc_pairing_gateway.dart';

class SecureGrpcGatewayWorkspaceFactory
    implements GatewayWorkspaceSessionFactory {
  SecureGrpcGatewayWorkspaceFactory({
    SecureValueStore? secureValueStore,
    GatewayGrpcChannelFactory? channelFactory,
  }) : _store = secureValueStore ?? FlutterSecureValueStore(),
       _channelFactory = channelFactory ?? GatewayGrpcChannelFactory();

  final SecureValueStore _store;
  final GatewayGrpcChannelFactory _channelFactory;

  @override
  Future<GatewayWorkspaceSession> open() async {
    final credential = await SecureDeviceCredentialStore(_store).loadActive();
    final profile = await SecureGatewayConnectionProfileStore(_store).load();
    if (credential == null || profile == null) {
      throw StateError('The secure Gateway pairing is incomplete.');
    }
    if (credential.gatewayAudience != profile.gatewayAudience) {
      throw StateError('The Gateway credential and trust profile disagree.');
    }

    final channel = _channelFactory.create(
      gatewayAudience: profile.gatewayAudience,
      trustedRootCertificates: profile.trustedRootCertificates,
    );
    final credentialStore = SecureDeviceCredentialStore(_store);
    final keyVault = DeviceKeyVault(store: _store);
    var activeCredential = credential;
    DriftClientEventLedger? ledger;
    try {
      if (!activeCredential.accessExpiresAt.toUtc().isAfter(
        DateTime.now().toUtc(),
      )) {
        final nonce = List<int>.generate(
          32,
          (_) => Random.secure().nextInt(256),
        );
        final refreshTokenDigest = await Sha256().hash(
          utf8.encode(activeCredential.refreshToken),
        );
        final payload = credentialRefreshPayload(
          credentialId: activeCredential.credentialId,
          deviceId: activeCredential.deviceId,
          gatewayAudience: activeCredential.gatewayAudience,
          refreshTokenSha256: _hex(refreshTokenDigest.bytes),
          generation: activeCredential.generation,
          nonce: nonce,
        );
        final signature = await keyVault.sign(
          activeCredential.keyReference,
          payload,
        );
        activeCredential =
            await GrpcPairingGateway(
              GeneratedPairingUnaryRpc(PairingServiceClient(channel)),
            ).refresh(
              activeCredential,
              DeviceSignatureProof(
                credentialId: activeCredential.credentialId,
                nonce: nonce,
                signature: signature,
              ),
            );
        await credentialStore.save(activeCredential);
      }
      final connection = await GrpcGatewayLiveTransport(
        GeneratedGatewayControlStreamingRpc(
          GatewayControlServiceClient(channel),
        ),
      ).open(activeCredential);
      ledger = await DriftClientEventLedger.forApplication();
      return _SecureGrpcGatewayWorkspaceSession(
        activeCredential,
        profile.gatewayAudience,
        keyVault,
        connection,
        ledger,
        channel.shutdown,
      );
    } on Object {
      await ledger?.close();
      await channel.shutdown();
      rethrow;
    }
  }
}

class _SecureGrpcGatewayWorkspaceSession implements GatewayWorkspaceSession {
  _SecureGrpcGatewayWorkspaceSession(
    this._credential,
    this._gatewayAudience,
    this._keyVault,
    this._connection,
    this._ledger,
    this._shutdownChannel,
  ) : _commands = GrpcGatewayCommandPort(_connection);

  @override
  String get deviceId => _credential.deviceId;
  final DeviceCredentialBundle _credential;
  final String _gatewayAudience;
  final DeviceKeyVault _keyVault;
  final GatewayLiveEventConnection _connection;
  final DriftClientEventLedger _ledger;
  final Future<void> Function() _shutdownChannel;
  final GrpcGatewayCommandPort _commands;
  final Set<String> _outstandingRequestIds = {};
  bool _closed = false;

  @override
  Future<void> run({
    required WorkspaceDirectoryCallback onDirectory,
    required WorkspaceConversationCallback onConversation,
    required WorkspaceEventCallback onEvent,
    required WorkspaceStatusCallback onStatus,
    required WorkspaceLeaseCallback onLease,
  }) async {
    final router = GatewayFrameRouter(
      ledger: _ledger,
      convergence: ClientEventConvergence(ledger: _ledger),
      onDirectory: onDirectory,
      onConversation: onConversation,
      onCommitted: onEvent,
      onControlLease: onLease,
      onRequestStatus: (status) async {
        await _ledger.trackRequest(status.toTrackedRequest());
        _outstandingRequestIds.remove(status.requestId);
        await onStatus(status);
      },
    );
    await router.run(
      _connection.frames.asyncMap(GatewayFrameMapper().map),
      _commands,
    );
  }

  @override
  void requestDirectory() => _commands.requestDirectory(
    commandId: _opaqueId('directory-command'),
    idempotencyKey: _opaqueId('directory-idempotency'),
  );

  @override
  void createConversation(ClientConversationDirectoryEntry conversation) {
    _commands.createConversation(
      commandId: _opaqueId('conversation-command'),
      idempotencyKey: _opaqueId('conversation-idempotency'),
      conversation: conversation,
    );
  }

  @override
  void acquireControl(
    String conversationId, {
    ClientControlLeaseSnapshot? expected,
    required bool explicitTakeover,
  }) {
    _commands.acquireControl(
      commandId: _opaqueId('lease-command'),
      idempotencyKey: _opaqueId('lease-idempotency'),
      conversationId: conversationId,
      expectedLeaseId: expected?.leaseId,
      expectedRevision: expected?.revision,
      explicitTakeover: explicitTakeover,
    );
  }

  @override
  void renewControl(ClientControlLeaseSnapshot lease) {
    _commands.renewControl(
      commandId: _opaqueId('lease-renewal-command'),
      idempotencyKey: _opaqueId('lease-renewal-idempotency'),
      lease: lease,
    );
  }

  @override
  Future<String> sendConfirmedText({
    required ClientConversationDirectoryEntry conversation,
    required ClientControlLeaseSnapshot lease,
    required String confirmedText,
    required void Function(String requestId) onPrepared,
  }) async {
    if (_closed ||
        lease.conversationId != conversation.conversationId ||
        lease.deviceId != deviceId ||
        !lease.expiresAt.isAfter(DateTime.now().toUtc()) ||
        confirmedText.trim().isEmpty ||
        utf8.encode(confirmedText).length > 1048576) {
      throw StateError('The confirmed submission is not eligible for send.');
    }
    final requestId = _opaqueId('request');
    final commandId = _opaqueId('send-command');
    final idempotencyKey = _opaqueId('send-idempotency');
    final digest = await Sha256().hash(utf8.encode(confirmedText));
    await _ledger.prepareLocalSubmission(
      TrackedClientRequest(
        originDeviceId: deviceId,
        conversationId: conversation.conversationId,
        sessionId: conversation.sessionId,
        requestId: requestId,
        nodeId: conversation.nodeId,
        agentId: conversation.agentId,
        capabilityRevision: conversation.capabilityRevision,
      ),
      LocalClientSubmission(
        requestId: requestId,
        originDeviceId: deviceId,
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        confirmedTextSha256: _hex(digest.bytes),
        disposition: LocalClientSubmissionDisposition.prepared,
      ),
    );
    _outstandingRequestIds.add(requestId);
    try {
      onPrepared(requestId);
      _commands.sendConfirmedText(
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        requestId: requestId,
        conversation: conversation,
        lease: lease,
        confirmedText: confirmedText,
      );
    } on Object {
      await _markUnknown(requestId);
      rethrow;
    }
    return requestId;
  }

  @override
  void interruptRequest({
    required ClientEventRecord event,
    required ClientControlLeaseSnapshot lease,
  }) {
    _commands.interruptRequest(
      commandId: _opaqueId('interrupt-command'),
      idempotencyKey: _opaqueId('interrupt-idempotency'),
      conversationId: event.conversationId,
      requestId: event.requestId,
      lease: lease,
    );
  }

  @override
  Future<void> resolveApproval({
    required ClientEventRecord event,
    required ClientControlLeaseSnapshot lease,
    required ClientApprovalDecision decision,
  }) async {
    final approval = event.content;
    if (event.kind != ClientEventKind.approvalRequired ||
        approval is! ApprovalClientEventContent ||
        !_credential.scopes.contains('approve')) {
      throw StateError('The approval event or device scope is invalid.');
    }
    final route = await _ledger.readRequest(event.requestId);
    if (route == null || route.conversationId != event.conversationId) {
      throw StateError('The approval request route is unavailable.');
    }
    final nonce = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final payload = approvalDecisionPayload(
      credentialId: _credential.credentialId,
      deviceId: deviceId,
      hostIdentity: route.nodeId,
      gatewayAudience: _gatewayAudience,
      requestId: event.requestId,
      approvalId: approval.approvalId,
      decision: decision == ClientApprovalDecision.approve ? 'approve' : 'deny',
      operationSummarySha256: approval.operationSummarySha256,
      nonce: nonce,
    );
    final signature = await _keyVault.sign(_credential.keyReference, payload);
    _commands.resolveApproval(
      commandId: _opaqueId('approval-command'),
      idempotencyKey: _opaqueId('approval-idempotency'),
      conversationId: event.conversationId,
      requestId: event.requestId,
      approvalId: approval.approvalId,
      operationSummarySha256: approval.operationSummarySha256,
      decision: decision,
      deviceSignature: ClientDeviceSignature(
        credentialId: _credential.credentialId,
        nonce: nonce,
        signature: signature,
      ),
      lease: lease,
    );
  }

  @override
  void resolveClarification({
    required ClientEventRecord event,
    required ClientControlLeaseSnapshot lease,
    required String confirmedText,
  }) {
    final clarification = event.content;
    if (event.kind != ClientEventKind.clarificationRequired ||
        clarification is! ClarificationClientEventContent ||
        confirmedText.trim().isEmpty) {
      throw StateError('The clarification response is invalid.');
    }
    _commands.resolveClarification(
      commandId: _opaqueId('clarification-command'),
      idempotencyKey: _opaqueId('clarification-idempotency'),
      conversationId: event.conversationId,
      requestId: event.requestId,
      clarificationId: clarification.clarificationId,
      confirmedText: confirmedText.trim(),
      lease: lease,
    );
  }

  @override
  Future<List<ClientEventRecord>> listEvents(String conversationId) =>
      _ledger.listConversationEvents(conversationId);

  @override
  Future<void> markOutstandingUnknown() async {
    for (final requestId in _outstandingRequestIds.toList(growable: false)) {
      await _markUnknown(requestId);
    }
  }

  Future<void> _markUnknown(String requestId) async {
    final submission = await _ledger.readLocalSubmission(requestId);
    if (submission?.disposition == LocalClientSubmissionDisposition.prepared) {
      await _ledger.advanceLocalSubmission(
        requestId,
        expectedDisposition: LocalClientSubmissionDisposition.prepared,
        nextDisposition: LocalClientSubmissionDisposition.outcomeUnknown,
      );
    }
    _outstandingRequestIds.remove(requestId);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await markOutstandingUnknown();
    await _connection.close();
    await _ledger.close();
    await _shutdownChannel();
  }
}

String _opaqueId(String purpose) {
  final random = Random.secure();
  final suffix = List<int>.generate(
    16,
    (_) => random.nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '$purpose-$suffix';
}

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
