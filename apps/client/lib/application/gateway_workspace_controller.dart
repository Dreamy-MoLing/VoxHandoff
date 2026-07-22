import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/client_event.dart';
import '../domain/client_session.dart';
import '../domain/gateway_sync.dart';
import '../domain/gateway_workspace.dart';
import '../infrastructure/gateway/secure_grpc_gateway_workspace_factory.dart';
import 'client_session_controller.dart';

typedef WorkspaceDirectoryCallback =
    FutureOr<void> Function(ClientGatewayDirectory directory);
typedef WorkspaceConversationCallback =
    FutureOr<void> Function(ClientConversationDirectoryEntry conversation);
typedef WorkspaceEventCallback =
    FutureOr<void> Function(ClientEventRecord event);
typedef WorkspaceStatusCallback =
    FutureOr<void> Function(ClientRequestStatusSnapshot status);
typedef WorkspaceLeaseCallback =
    FutureOr<void> Function(ClientControlLeaseSnapshot lease);

abstract interface class GatewayWorkspaceSession {
  String get deviceId;

  Future<void> run({
    required WorkspaceDirectoryCallback onDirectory,
    required WorkspaceConversationCallback onConversation,
    required WorkspaceEventCallback onEvent,
    required WorkspaceStatusCallback onStatus,
    required WorkspaceLeaseCallback onLease,
  });

  void requestDirectory();
  void createConversation(ClientConversationDirectoryEntry conversation);
  void acquireControl(
    String conversationId, {
    ClientControlLeaseSnapshot? expected,
    required bool explicitTakeover,
  });
  void renewControl(ClientControlLeaseSnapshot lease);
  Future<String> sendConfirmedText({
    required ClientConversationDirectoryEntry conversation,
    required ClientControlLeaseSnapshot lease,
    required String confirmedText,
    required void Function(String requestId) onPrepared,
  });
  void interruptRequest({
    required ClientEventRecord event,
    required ClientControlLeaseSnapshot lease,
  });
  Future<void> resolveApproval({
    required ClientEventRecord event,
    required ClientControlLeaseSnapshot lease,
    required ClientApprovalDecision decision,
  });
  void resolveClarification({
    required ClientEventRecord event,
    required ClientControlLeaseSnapshot lease,
    required String confirmedText,
  });
  Future<List<ClientEventRecord>> listEvents(String conversationId);
  Future<void> markOutstandingUnknown();
  Future<void> close();
}

abstract interface class GatewayWorkspaceSessionFactory {
  Future<GatewayWorkspaceSession> open();
}

final gatewayWorkspaceSessionFactoryProvider =
    Provider<GatewayWorkspaceSessionFactory>(
      (ref) => SecureGrpcGatewayWorkspaceFactory(),
    );

final gatewayWorkspaceProvider =
    NotifierProvider<GatewayWorkspaceController, GatewayWorkspaceState>(
      GatewayWorkspaceController.new,
    );

class GatewayWorkspaceController extends Notifier<GatewayWorkspaceState> {
  GatewayWorkspaceSessionFactory? _factory;
  GatewayWorkspaceSession? _session;
  bool _connecting = false;
  final Map<String, Timer> _leaseRenewalTimers = {};

  String? get deviceId => _session?.deviceId;

  @override
  GatewayWorkspaceState build() {
    _factory = ref.watch(gatewayWorkspaceSessionFactoryProvider);
    ref.onDispose(() {
      _cancelLeaseRenewals();
      final session = _session;
      _session = null;
      if (session != null) unawaited(session.close());
    });
    return const GatewayWorkspaceState();
  }

  Future<void> connect() async {
    if (_connecting || _session != null) return;
    _connecting = true;
    state = state.copyWith(
      connectionPhase: GatewayConnectionPhase.connecting,
      clearError: true,
    );
    ref
        .read(clientSessionProvider.notifier)
        .setConnectionPhase(GatewayConnectionPhase.connecting);
    try {
      final session = await _factory!.open();
      _session = session;
      state = state.copyWith(
        connectionPhase: GatewayConnectionPhase.connected,
        clearError: true,
      );
      ref
          .read(clientSessionProvider.notifier)
          .setConnectionPhase(GatewayConnectionPhase.connected);
      unawaited(
        session
            .run(
              onDirectory: _acceptDirectory,
              onConversation: _acceptConversation,
              onEvent: _acceptEvent,
              onStatus: _acceptStatus,
              onLease: _acceptLease,
            )
            .then<void>((_) => _streamEnded(), onError: _streamFailed),
      );
      session.requestDirectory();
    } on Object {
      await _closeSession();
      _publishConnectionFailure(
        'gateway_connect_failed',
        'The saved Gateway could not be connected securely.',
      );
    } finally {
      _connecting = false;
    }
  }

  Future<void> disconnect() async {
    await _session?.markOutstandingUnknown();
    await _closeSession();
    state = state.copyWith(connectionPhase: GatewayConnectionPhase.offline);
    ref
        .read(clientSessionProvider.notifier)
        .setConnectionPhase(GatewayConnectionPhase.offline);
  }

  Future<void> selectConversation(String conversationId) async {
    final directory = state.directory;
    if (directory == null ||
        !directory.conversations.any(
          (conversation) => conversation.conversationId == conversationId,
        )) {
      throw StateError('The selected conversation is not in the directory.');
    }
    state = state.copyWith(
      selectedConversationId: conversationId,
      events: const [],
    );
    await _reloadEvents(conversationId);
  }

  void createConversation({
    required String conversationId,
    required String title,
    required ClientAgentDirectoryEntry agent,
  }) {
    final session = _requiredSession();
    session.createConversation(
      ClientConversationDirectoryEntry(
        conversationId: conversationId,
        title: title.trim(),
        nodeId: agent.nodeId,
        agentId: agent.agentId,
        capabilityRevision: agent.capabilityRevision,
        revision: BigInt.one,
        lastSequence: BigInt.zero,
      ),
    );
  }

  void acquireSelectedControl({required bool explicitTakeover}) {
    final conversation = state.selectedConversation;
    if (conversation == null) throw StateError('No conversation is selected.');
    _requiredSession().acquireControl(
      conversation.conversationId,
      expected: state.selectedLease,
      explicitTakeover: explicitTakeover,
    );
  }

  Future<void> sendConfirmedText(String text) async {
    final session = _requiredSession();
    final conversation = state.selectedConversation;
    final lease = state.selectedLease;
    if (conversation == null ||
        lease == null ||
        lease.deviceId != session.deviceId) {
      throw StateError('This device does not own the selected control lease.');
    }
    String? requestId;
    try {
      await session.sendConfirmedText(
        conversation: conversation,
        lease: lease,
        confirmedText: text,
        onPrepared: (preparedRequestId) {
          requestId = preparedRequestId;
          ref
              .read(clientSessionProvider.notifier)
              .beginSubmission(preparedRequestId);
        },
      );
    } on Object {
      final preparedRequestId = requestId;
      if (preparedRequestId != null &&
          ref.read(clientSessionProvider).draftPhase == DraftPhase.submitting) {
        ref
            .read(clientSessionProvider.notifier)
            .markAcceptanceUncertain(preparedRequestId);
        state = state.copyWith(
          safeErrorCode: 'submission_outcome_uncertain',
          safeErrorMessage:
              'The submission outcome is uncertain. It was not resent.',
          uncertainRequestId: preparedRequestId,
        );
        return;
      }
      rethrow;
    }
  }

  void interrupt(ClientEventRecord event) {
    final lease = _requiredOwnedLease(event.conversationId);
    _requiredSession().interruptRequest(event: event, lease: lease);
  }

  Future<void> resolveApproval(
    ClientEventRecord event,
    ClientApprovalDecision decision,
  ) async {
    final lease = _requiredOwnedLease(event.conversationId);
    await _requiredSession().resolveApproval(
      event: event,
      lease: lease,
      decision: decision,
    );
  }

  void resolveClarification(ClientEventRecord event, String confirmedText) {
    final lease = _requiredOwnedLease(event.conversationId);
    _requiredSession().resolveClarification(
      event: event,
      lease: lease,
      confirmedText: confirmedText,
    );
  }

  Future<void> _acceptDirectory(ClientGatewayDirectory directory) async {
    final selected = state.selectedConversationId;
    final stillPresent =
        selected != null &&
        directory.conversations.any(
          (conversation) => conversation.conversationId == selected,
        );
    final next = stillPresent
        ? selected
        : directory.conversations.firstOrNull?.conversationId;
    state = state.copyWith(
      directory: directory,
      selectedConversationId: next,
      clearSelection: next == null,
      events: const [],
    );
    if (next != null) await _reloadEvents(next);
  }

  Future<void> _acceptConversation(
    ClientConversationDirectoryEntry conversation,
  ) async {
    final current = state.directory;
    if (current == null) {
      _session?.requestDirectory();
      return;
    }
    final conversations = [...current.conversations];
    final index = conversations.indexWhere(
      (candidate) => candidate.conversationId == conversation.conversationId,
    );
    if (index < 0) {
      conversations.add(conversation);
    } else {
      conversations[index] = conversation;
    }
    state = state.copyWith(
      directory: ClientGatewayDirectory(
        commandId: current.commandId,
        nodes: current.nodes,
        agents: current.agents,
        conversations: List.unmodifiable(conversations),
      ),
      selectedConversationId: conversation.conversationId,
    );
    await _reloadEvents(conversation.conversationId);
  }

  Future<void> _acceptEvent(ClientEventRecord event) async {
    if (event.conversationId == state.selectedConversationId) {
      await _reloadEvents(event.conversationId);
    }
  }

  Future<void> _acceptStatus(ClientRequestStatusSnapshot status) async {
    final client = ref.read(clientSessionProvider);
    if (client.requestId != status.requestId) return;
    if (status.acceptedSequence > BigInt.zero &&
        client.draftPhase == DraftPhase.submitting) {
      ref.read(clientSessionProvider.notifier).markAccepted(status.requestId);
      state = state.copyWith(clearUncertain: true);
    }
  }

  void _acceptLease(ClientControlLeaseSnapshot lease) {
    final previous = state.leases[lease.conversationId];
    if (previous != null && previous.leaseId == lease.leaseId) {
      if (lease.revision < previous.revision) return;
      if (lease.revision == previous.revision &&
          (lease.deviceId != previous.deviceId ||
              lease.expiresAt != previous.expiresAt)) {
        throw StateError(
          'The control lease revision conflicts with prior state.',
        );
      }
    }
    _leaseRenewalTimers.remove(lease.conversationId)?.cancel();
    state = state.copyWith(
      leases: {...state.leases, lease.conversationId: lease},
    );
    final session = _session;
    final delay = _leaseRenewalDelay(lease, session?.deviceId, DateTime.now());
    if (session == null || delay == null) return;
    _leaseRenewalTimers[lease.conversationId] = Timer(
      delay,
      () => _renewLease(session, lease),
    );
  }

  void _renewLease(
    GatewayWorkspaceSession session,
    ClientControlLeaseSnapshot scheduledLease,
  ) {
    _leaseRenewalTimers.remove(scheduledLease.conversationId);
    final current = state.leases[scheduledLease.conversationId];
    if (_session != session ||
        current == null ||
        current.leaseId != scheduledLease.leaseId ||
        current.revision != scheduledLease.revision ||
        current.deviceId != session.deviceId ||
        !current.expiresAt.isAfter(DateTime.now().toUtc())) {
      return;
    }
    try {
      session.renewControl(current);
      final expiryDelay = current.expiresAt.difference(DateTime.now().toUtc());
      if (expiryDelay > Duration.zero) {
        _leaseRenewalTimers[current.conversationId] = Timer(
          expiryDelay,
          () => _expireLease(current),
        );
      }
    } on Object {
      state = state.copyWith(
        safeErrorCode: 'control_lease_renewal_failed',
        safeErrorMessage:
            'The control lease could not be renewed. No Agent command was sent.',
      );
    }
  }

  void _expireLease(ClientControlLeaseSnapshot expiringLease) {
    _leaseRenewalTimers.remove(expiringLease.conversationId);
    final current = state.leases[expiringLease.conversationId];
    if (current == null ||
        current.leaseId != expiringLease.leaseId ||
        current.revision != expiringLease.revision) {
      return;
    }
    final leases = {...state.leases}..remove(expiringLease.conversationId);
    state = state.copyWith(leases: leases);
  }

  Future<void> _reloadEvents(String conversationId) async {
    final session = _session;
    if (session == null) return;
    final events = await session.listEvents(conversationId);
    if (state.selectedConversationId == conversationId) {
      state = state.copyWith(events: events);
    }
  }

  Future<void> _streamFailed(Object _) async {
    final requestId = ref.read(clientSessionProvider).requestId;
    await _session?.markOutstandingUnknown();
    await _closeSession();
    if (requestId != null &&
        ref.read(clientSessionProvider).draftPhase == DraftPhase.submitting) {
      ref
          .read(clientSessionProvider.notifier)
          .markAcceptanceUncertain(requestId);
    }
    state = state.copyWith(
      connectionPhase: GatewayConnectionPhase.offline,
      safeErrorCode: 'gateway_stream_lost',
      safeErrorMessage:
          'The Gateway stream ended. Uncertain submissions were not resent.',
      uncertainRequestId: requestId,
    );
    ref
        .read(clientSessionProvider.notifier)
        .setConnectionPhase(GatewayConnectionPhase.offline);
  }

  Future<void> _streamEnded() => _streamFailed(StateError('stream ended'));

  void _publishConnectionFailure(String code, String message) {
    state = state.copyWith(
      connectionPhase: GatewayConnectionPhase.failed,
      safeErrorCode: code,
      safeErrorMessage: message,
    );
    ref
        .read(clientSessionProvider.notifier)
        .setConnectionPhase(GatewayConnectionPhase.failed);
  }

  GatewayWorkspaceSession _requiredSession() {
    final session = _session;
    if (session == null) throw StateError('The Gateway is not connected.');
    return session;
  }

  ClientControlLeaseSnapshot _requiredOwnedLease(String conversationId) {
    final session = _requiredSession();
    final lease = state.leases[conversationId];
    if (lease == null ||
        lease.deviceId != session.deviceId ||
        !lease.expiresAt.isAfter(DateTime.now().toUtc())) {
      throw StateError('This device does not own the current control lease.');
    }
    return lease;
  }

  Future<void> _closeSession() async {
    _cancelLeaseRenewals();
    final session = _session;
    _session = null;
    if (session != null) await session.close();
  }

  void _cancelLeaseRenewals() {
    for (final timer in _leaseRenewalTimers.values) {
      timer.cancel();
    }
    _leaseRenewalTimers.clear();
  }
}

Duration? _leaseRenewalDelay(
  ClientControlLeaseSnapshot lease,
  String? deviceId,
  DateTime now,
) {
  if (deviceId == null || lease.deviceId != deviceId) return null;
  final remaining = lease.expiresAt.difference(now.toUtc());
  if (remaining <= Duration.zero) return null;
  const normalInterval = Duration(seconds: 10);
  if (remaining > normalInterval) return normalInterval;
  final microseconds = remaining.inMicroseconds ~/ 2;
  return Duration(microseconds: microseconds > 0 ? microseconds : 1);
}
