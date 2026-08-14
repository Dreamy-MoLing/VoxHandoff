import 'dart:async';

import '../domain/client_event.dart';
import '../domain/gateway_sync.dart';

typedef WorkspaceDirectoryCallback =
    FutureOr<void> Function(ClientGatewayDirectory directory);
typedef WorkspaceConversationCallback =
    FutureOr<void> Function(ClientConversationDirectoryEntry conversation);
typedef WorkspaceEventCallback =
    FutureOr<void> Function(ClientEventRecord event, ClientEventOrigin origin);
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
