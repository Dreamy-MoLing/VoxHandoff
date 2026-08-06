import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/client_event.dart';
import '../domain/desktop_capabilities.dart';
import '../domain/gateway_workspace.dart';

final desktopIntegrationPortProvider = Provider<DesktopIntegrationPort>(
  (_) => const UnavailableDesktopIntegration(),
);

final desktopIntegrationProvider =
    NotifierProvider<DesktopIntegrationController, DesktopCapabilitySnapshot>(
      DesktopIntegrationController.new,
    );

class DesktopIntegrationController extends Notifier<DesktopCapabilitySnapshot> {
  static const _maxRememberedConversations = 256;
  final LinkedHashMap<String, BigInt> _seenSequenceByConversation =
      LinkedHashMap();
  final Set<String> _hydratedConversations = {};
  bool _initialized = false;
  bool _ready = false;
  bool _notificationInFlight = false;
  DesktopAttentionKind? _pendingAttention;

  @override
  DesktopCapabilitySnapshot build() {
    final port = ref.watch(desktopIntegrationPortProvider);
    ref.onDispose(() {
      unawaited(port.close());
    });
    return const DesktopCapabilitySnapshot.unsupported();
  }

  Future<void> initialize({
    required DesktopVoiceToggle onVoiceToggle,
    required GatewayWorkspaceState workspace,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _synchronizeDirectory(workspace);
    if (workspace.selectedEventsHydrated) {
      _primeSelectedConversation(workspace);
    }
    state = await ref
        .read(desktopIntegrationPortProvider)
        .initialize(onVoiceToggle: onVoiceToggle);
    _ready = true;
    await _drainAttention();
  }

  Future<void> observeWorkspace(GatewayWorkspaceState workspace) async {
    if (!_initialized) return;
    _synchronizeDirectory(workspace);
    final selectedConversationId = workspace.selectedConversationId;
    if (selectedConversationId == null || !workspace.selectedEventsHydrated) {
      return;
    }
    if (!_hydratedConversations.contains(selectedConversationId)) {
      _primeSelectedConversation(workspace);
      return;
    }
    final event = workspace.latestLiveEvent;
    if (event == null || event.conversationId != selectedConversationId) return;
    final seen =
        _seenSequenceByConversation[event.conversationId] ?? BigInt.zero;
    if (event.sequence <= seen) return;
    _rememberSequence(event.conversationId, event.sequence);
    final attention = _attentionFor(event);
    if (attention == null) return;
    _pendingAttention = attention;
    await _drainAttention();
  }

  Future<void> _drainAttention() async {
    if (!_ready || _notificationInFlight) return;
    _notificationInFlight = true;
    try {
      while (_pendingAttention != null) {
        final attention = _pendingAttention!;
        _pendingAttention = null;
        await ref.read(desktopIntegrationPortProvider).showAttention(attention);
      }
    } finally {
      _notificationInFlight = false;
    }
  }

  void _primeSelectedConversation(GatewayWorkspaceState workspace) {
    final conversationId = workspace.selectedConversationId;
    if (conversationId == null) return;
    _hydratedConversations.add(conversationId);
    if (!_seenSequenceByConversation.containsKey(conversationId)) {
      _rememberSequence(conversationId, BigInt.zero);
    }
    for (final event in workspace.events) {
      if (event.conversationId != conversationId) continue;
      final seen =
          _seenSequenceByConversation[event.conversationId] ?? BigInt.zero;
      if (event.sequence > seen) {
        _rememberSequence(event.conversationId, event.sequence);
      }
    }
    _trimRememberedConversations();
  }

  void _synchronizeDirectory(GatewayWorkspaceState workspace) {
    final directory = workspace.directory;
    if (directory == null) return;
    final activeIds = directory.conversations
        .map((conversation) => conversation.conversationId)
        .toSet();
    _seenSequenceByConversation.removeWhere(
      (conversationId, _) => !activeIds.contains(conversationId),
    );
    _hydratedConversations.removeWhere(
      (conversationId) => !activeIds.contains(conversationId),
    );
  }

  void _rememberSequence(String conversationId, BigInt sequence) {
    _seenSequenceByConversation.remove(conversationId);
    _seenSequenceByConversation[conversationId] = sequence;
    _trimRememberedConversations();
  }

  void _trimRememberedConversations() {
    while (_seenSequenceByConversation.length > _maxRememberedConversations) {
      final oldest = _seenSequenceByConversation.keys.first;
      _seenSequenceByConversation.remove(oldest);
      _hydratedConversations.remove(oldest);
    }
  }

  DesktopAttentionKind? _attentionFor(ClientEventRecord event) {
    return switch (event.kind) {
      ClientEventKind.approvalRequired => DesktopAttentionKind.approval,
      ClientEventKind.clarificationRequired =>
        DesktopAttentionKind.clarification,
      ClientEventKind.requestCompleted => DesktopAttentionKind.completed,
      ClientEventKind.requestFailed => DesktopAttentionKind.failed,
      _ => null,
    };
  }
}

class UnavailableDesktopIntegration implements DesktopIntegrationPort {
  const UnavailableDesktopIntegration();

  @override
  Future<DesktopCapabilitySnapshot> initialize({
    required DesktopVoiceToggle onVoiceToggle,
  }) async => const DesktopCapabilitySnapshot.unsupported();

  @override
  Future<void> showAttention(DesktopAttentionKind kind) async {}

  @override
  Future<void> showWindow() async {}

  @override
  Future<void> close() async {}
}
