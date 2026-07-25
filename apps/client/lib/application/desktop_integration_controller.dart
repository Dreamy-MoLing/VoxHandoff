import 'dart:async';

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
  final Set<String> _seenEventIds = {};
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
    _remember(workspace.events);
    state = await ref
        .read(desktopIntegrationPortProvider)
        .initialize(onVoiceToggle: onVoiceToggle);
    _ready = true;
    await _drainAttention();
  }

  Future<void> observeWorkspace(GatewayWorkspaceState workspace) async {
    if (!_initialized) return;
    final selectedConversationId = workspace.selectedConversationId;
    final newEvents = workspace.events
        .where((event) => _seenEventIds.add(event.eventId))
        .where(
          (event) =>
              selectedConversationId == null ||
              event.conversationId == selectedConversationId,
        )
        .toList(growable: false);
    _trimSeenEvents(workspace.events);
    if (newEvents.isEmpty) return;

    DesktopAttentionKind? attention;
    for (final event in newEvents) {
      attention = _attentionFor(event) ?? attention;
    }
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

  void _remember(List<ClientEventRecord> events) {
    _seenEventIds.addAll(events.map((event) => event.eventId));
    _trimSeenEvents(events);
  }

  void _trimSeenEvents(List<ClientEventRecord> currentEvents) {
    if (_seenEventIds.length <= 512) return;
    final retained = currentEvents.reversed
        .take(256)
        .map((event) => event.eventId)
        .toSet();
    _seenEventIds
      ..clear()
      ..addAll(retained);
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
