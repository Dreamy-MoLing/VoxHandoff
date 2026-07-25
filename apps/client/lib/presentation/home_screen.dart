import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/client_session_controller.dart';
import '../application/desktop_integration_controller.dart';
import '../application/device_pairing_controller.dart';
import '../application/gateway_workspace_controller.dart';
import '../application/speech_playback_controller.dart';
import '../application/voice_session_controller.dart';
import '../domain/client_event.dart';
import '../domain/client_session.dart';
import '../domain/desktop_capabilities.dart';
import '../domain/device_pairing.dart';
import '../domain/gateway_sync.dart';
import '../domain/gateway_workspace.dart';
import '../domain/signal_core.dart';
import '../domain/speech.dart';
import '../domain/voice.dart';
import 'design/agent_talk_theme.dart';
import 'pairing_dialog.dart';
import 'signal_core_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _composer;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(devicePairingProvider.notifier).restore();
      unawaited(
        ref
            .read(desktopIntegrationProvider.notifier)
            .initialize(
              onVoiceToggle: _toggleVoiceDraft,
              workspace: ref.read(gatewayWorkspaceProvider),
            ),
      );
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _confirmDraft() {
    ref.read(clientSessionProvider.notifier).confirmDraft();
    final confirmedText = ref.read(clientSessionProvider).draftText;
    _composer.value = TextEditingValue(
      text: confirmedText,
      selection: TextSelection.collapsed(offset: confirmedText.length),
    );
  }

  Future<void> _openPairing() => showDevicePairingDialog(context);

  Future<void> _send() async {
    final text = ref.read(clientSessionProvider).draftText;
    await ref.read(gatewayWorkspaceProvider.notifier).sendConfirmedText(text);
  }

  void _startNextDraft() {
    ref.read(clientSessionProvider.notifier).startNextDraft();
    _composer.clear();
  }

  Future<void> _startVoice() =>
      ref.read(voiceSessionProvider.notifier).startRecording();

  Future<void> _stopVoice() async {
    await ref.read(voiceSessionProvider.notifier).stopRecording();
    final draft = ref.read(clientSessionProvider).draftText;
    _composer.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  Future<void> _cancelVoice() =>
      ref.read(voiceSessionProvider.notifier).cancelRecording();

  Future<void> _discardVoice() async {
    await ref.read(voiceSessionProvider.notifier).discardTranscript();
    _composer.clear();
  }

  Future<void> _toggleVoiceDraft() async {
    final voice = ref.read(voiceSessionProvider);
    if (voice.canStop) {
      await _stopVoice();
    } else if (voice.canStart) {
      await _startVoice();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(clientSessionProvider);
    final controller = ref.read(clientSessionProvider.notifier);
    final pairing = ref.watch(devicePairingProvider);
    final workspace = ref.watch(gatewayWorkspaceProvider);
    ref.listen(gatewayWorkspaceProvider, (_, next) {
      unawaited(
        ref.read(desktopIntegrationProvider.notifier).observeWorkspace(next),
      );
    });
    final workspaceController = ref.read(gatewayWorkspaceProvider.notifier);
    final voice = ref.watch(voiceSessionProvider);
    final speech = ref.watch(speechPlaybackProvider);
    final desktop = ref.watch(desktopIntegrationProvider);
    final signalCore = resolveSignalCore(
      workspace: workspace,
      session: session,
      voice: voice,
      speech: speech,
    );
    final ownsLease = workspace.ownsSelectedLease(
      workspaceController.deviceId,
      DateTime.now(),
    );
    final compactAppBar = MediaQuery.sizeOf(context).width < 480;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.space,
          control: true,
          shift: true,
        ): () =>
            unawaited(_toggleVoiceDraft()),
      },
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(
            header: true,
            label: 'VoxHandoff',
            child: const Text(
              'VOX / HANDOFF',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2.2),
            ),
          ),
          actions: [
            if (desktop.isDesktop) _DesktopCapabilityIcon(snapshot: desktop),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: compactAppBar
                  ? _ConnectionStatusIcon(phase: session.connectionPhase)
                  : _ConnectionChip(phase: session.connectionPhase),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final showNavigation = constraints.maxWidth >= 900;
            final banner = _LocalOnlyBanner(
              pairing: pairing,
              workspace: workspace,
              onOpenPairing: _openPairing,
              onConnect: workspaceController.connect,
              onDisconnect: workspaceController.disconnect,
            );
            final conversation = workspace.selectedConversation == null
                ? const _EmptyConversation()
                : _ConversationView(
                    workspace: workspace,
                    signalCore: signalCore,
                    ownsLease: ownsLease,
                    onAcquire: () => workspaceController.acquireSelectedControl(
                      explicitTakeover: workspace.selectedLease != null,
                    ),
                    onApproval: workspaceController.resolveApproval,
                    onClarification: workspaceController.resolveClarification,
                    onInterrupt: workspaceController.interrupt,
                  );
            final composer = _Composer(
              textController: _composer,
              session: session,
              voice: voice,
              onChanged: controller.editDraft,
              onConfirm: _confirmDraft,
              onReopen: controller.reopenDraft,
              onSend: _send,
              onNextDraft: _startNextDraft,
              sendEnabled: ownsLease,
              onStartVoice: _startVoice,
              onStopVoice: _stopVoice,
              onCancelVoice: _cancelVoice,
              onDiscardVoice: _discardVoice,
            );
            if (!showNavigation) {
              return Column(
                children: [
                  Expanded(
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                        SliverToBoxAdapter(child: banner),
                        if (workspace.directory != null)
                          SliverToBoxAdapter(
                            child: _ConversationPicker(
                              workspace: workspace,
                              onSelect: workspaceController.selectConversation,
                              onCreate: () => _showCreateConversationDialog(
                                context,
                                workspace,
                                workspaceController,
                              ),
                            ),
                          ),
                      ],
                      body: conversation,
                    ),
                  ),
                  composer,
                ],
              );
            }
            return Row(
              children: [
                _NavigationPane(
                  workspace: workspace,
                  onSelect: workspaceController.selectConversation,
                  onCreate: () => _showCreateConversationDialog(
                    context,
                    workspace,
                    workspaceController,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      banner,
                      Expanded(child: conversation),
                      composer,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DesktopCapabilityIcon extends StatelessWidget {
  const _DesktopCapabilityIcon({required this.snapshot});

  final DesktopCapabilitySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final degraded = snapshot.hasDegradedCapability;
    return Tooltip(
      message: snapshot.safeSummary,
      child: Semantics(
        label: degraded
            ? 'Desktop integrations are partially available'
            : 'Desktop integrations are available',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            degraded
                ? Icons.desktop_access_disabled_outlined
                : Icons.desktop_windows_outlined,
            color: degraded ? const Color(0xFFFFB86C) : null,
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatusIcon extends StatelessWidget {
  const _ConnectionStatusIcon({required this.phase});

  final GatewayConnectionPhase phase;

  @override
  Widget build(BuildContext context) {
    final connected = phase == GatewayConnectionPhase.connected;
    final tokens = context.visualTokens;
    return Tooltip(
      message: connected ? 'Connected' : 'Not connected',
      child: Icon(
        connected ? Icons.verified_user_outlined : Icons.link_off,
        color: connected ? tokens.signal : tokens.textMuted,
        semanticLabel: connected ? 'Connected' : 'Not connected',
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.phase});

  final GatewayConnectionPhase phase;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final label = switch (phase) {
      GatewayConnectionPhase.unpaired => 'Not paired',
      GatewayConnectionPhase.connecting => 'Connecting',
      GatewayConnectionPhase.connected => 'Connected',
      GatewayConnectionPhase.reconnecting => 'Reconnecting',
      GatewayConnectionPhase.offline => 'Offline',
      GatewayConnectionPhase.failed => 'Connection failed',
    };
    return Chip(
      avatar: Icon(
        phase == GatewayConnectionPhase.connected
            ? Icons.verified_user_outlined
            : Icons.link_off,
        size: 18,
        color: phase == GatewayConnectionPhase.connected
            ? tokens.signal
            : tokens.textMuted,
      ),
      label: Text(label),
    );
  }
}

class _NavigationPane extends StatelessWidget {
  const _NavigationPane({
    required this.workspace,
    required this.onSelect,
    required this.onCreate,
  });

  final GatewayWorkspaceState workspace;
  final Future<void> Function(String conversationId) onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AGENTS',
                  style: TextStyle(
                    color: context.visualTokens.signal,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                if (workspace.directory?.agents.isEmpty ?? true)
                  const Text('No Agent available')
                else
                  for (final agent in workspace.directory!.agents)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.smart_toy_outlined),
                      title: Text(agent.displayName),
                      subtitle: Text('${agent.adapter} · ${agent.version}'),
                    ),
                const SizedBox(height: 28),
                Text(
                  'CONVERSATIONS',
                  style: TextStyle(
                    color: context.visualTokens.signal,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                if (workspace.connectionPhase ==
                        GatewayConnectionPhase.connected &&
                    (workspace.directory?.agents.isNotEmpty ?? false))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add),
                      label: const Text('New conversation'),
                    ),
                  ),
                if (workspace.directory?.conversations.isEmpty ?? true)
                  const Text('No conversation selected')
                else
                  Expanded(
                    child: ListView(
                      children: [
                        for (final conversation
                            in workspace.directory!.conversations)
                          ListTile(
                            selected:
                                conversation.conversationId ==
                                workspace.selectedConversationId,
                            contentPadding: EdgeInsets.zero,
                            title: Text(conversation.title),
                            subtitle: Text(conversation.agentId),
                            onTap: () => onSelect(conversation.conversationId),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalOnlyBanner extends StatelessWidget {
  const _LocalOnlyBanner({
    required this.pairing,
    required this.workspace,
    required this.onOpenPairing,
    required this.onConnect,
    required this.onDisconnect,
  });

  final PairingState pairing;
  final GatewayWorkspaceState workspace;
  final VoidCallback onOpenPairing;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final paired = pairing.phase == PairingPhase.paired;
    return ColoredBox(
      color: Color.alphaBlend(
        tokens.attention.withValues(alpha: 0.08),
        tokens.panel,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final message = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  paired ? Icons.verified_user_outlined : Icons.lock_outline,
                  color: paired ? tokens.signal : tokens.attention,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    workspace.safeErrorMessage ??
                        (workspace.connectionPhase ==
                                GatewayConnectionPhase.connected
                            ? 'Authenticated Gateway stream is active. Only explicitly confirmed text can be sent.'
                            : paired
                            ? 'Device credential verified. Connect explicitly to load Agents and conversations.'
                            : 'Not paired. Draft text stays on this device and cannot be sent.'),
                    maxLines: MediaQuery.textScalerOf(context).scale(1) >= 1.5
                        ? 3
                        : null,
                    overflow: MediaQuery.textScalerOf(context).scale(1) >= 1.5
                        ? TextOverflow.ellipsis
                        : null,
                  ),
                ),
              ],
            );
            final pairButton = FilledButton(
              onPressed:
                  workspace.connectionPhase == GatewayConnectionPhase.connected
                  ? onDisconnect
                  : paired
                  ? onConnect
                  : onOpenPairing,
              child: Text(
                workspace.connectionPhase == GatewayConnectionPhase.connected
                    ? 'Disconnect'
                    : paired
                    ? 'Connect Gateway'
                    : 'Pair Gateway',
              ),
            );
            if (constraints.maxWidth < 480) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: message),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip:
                        workspace.connectionPhase ==
                            GatewayConnectionPhase.connected
                        ? 'Disconnect'
                        : paired
                        ? 'Connect Gateway'
                        : 'Pair Gateway',
                    onPressed:
                        workspace.connectionPhase ==
                            GatewayConnectionPhase.connected
                        ? onDisconnect
                        : paired
                        ? onConnect
                        : onOpenPairing,
                    icon: Icon(
                      workspace.connectionPhase ==
                              GatewayConnectionPhase.connected
                          ? Icons.link_off
                          : paired
                          ? Icons.link
                          : Icons.lock_open,
                    ),
                  ),
                ],
              );
            }
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  message,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: pairButton),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: message),
                const SizedBox(width: 16),
                pairButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConversationPicker extends StatelessWidget {
  const _ConversationPicker({
    required this.workspace,
    required this.onSelect,
    required this.onCreate,
  });

  final GatewayWorkspaceState workspace;
  final Future<void> Function(String conversationId) onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final conversations = workspace.directory?.conversations ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: workspace.selectedConversationId,
              decoration: const InputDecoration(labelText: 'Conversation'),
              items: [
                for (final conversation in conversations)
                  DropdownMenuItem(
                    value: conversation.conversationId,
                    child: Text(conversation.title),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onSelect(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'New conversation',
            onPressed: workspace.directory?.agents.isNotEmpty ?? false
                ? onCreate
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

Future<void> _showCreateConversationDialog(
  BuildContext context,
  GatewayWorkspaceState workspace,
  GatewayWorkspaceController controller,
) async {
  final agents = workspace.directory?.agents ?? const [];
  if (agents.isEmpty) return;
  final title = TextEditingController();
  var selected = agents.first;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('New conversation'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ClientAgentDirectoryEntry>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Agent'),
                items: [
                  for (final agent in agents)
                    DropdownMenuItem(
                      value: agent,
                      child: Text(agent.displayName),
                    ),
                ],
                onChanged: (agent) {
                  if (agent != null) setState(() => selected = agent);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                autofocus: true,
                maxLength: 128,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
  if (accepted == true && title.text.trim().isNotEmpty) {
    controller.createConversation(
      conversationId: _newOpaqueId('conversation'),
      title: title.text,
      agent: selected,
    );
  }
  title.dispose();
}

String _newOpaqueId(String purpose) {
  final random = math.Random.secure();
  final suffix = List<int>.generate(
    16,
    (_) => random.nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '$purpose-$suffix';
}

class _ConversationView extends StatelessWidget {
  const _ConversationView({
    required this.workspace,
    required this.signalCore,
    required this.ownsLease,
    required this.onAcquire,
    required this.onApproval,
    required this.onClarification,
    required this.onInterrupt,
  });

  final GatewayWorkspaceState workspace;
  final SignalCoreSnapshot signalCore;
  final bool ownsLease;
  final VoidCallback onAcquire;
  final Future<void> Function(ClientEventRecord, ClientApprovalDecision)
  onApproval;
  final void Function(ClientEventRecord, String) onClarification;
  final void Function(ClientEventRecord) onInterrupt;

  @override
  Widget build(BuildContext context) {
    final conversation = workspace.selectedConversation!;
    final activeRequest = workspace.events.reversed
        .where((event) => !_terminalKinds.contains(event.kind))
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;
        final coreDimension = desktop
            ? signalCore.isExpanded
                  ? 260.0
                  : constraints.maxWidth < 980
                  ? 144.0
                  : 188.0
            : signalCore.demandsInteraction
            ? 68.0
            : signalCore.isExpanded
            ? 180.0
            : 96.0;
        final header = _ConversationHeader(
          conversation: conversation,
          workspace: workspace,
          ownsLease: ownsLease,
          activeRequest: activeRequest,
          onAcquire: onAcquire,
          onInterrupt: onInterrupt,
        );
        final eventList = workspace.events.isEmpty
            ? const Center(child: Text('No durable events yet'))
            : ListView.builder(
                key: const ValueKey('conversation-events'),
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  desktop ? coreDimension + 40 : 16,
                  16,
                ),
                itemCount: workspace.events.length,
                itemBuilder: (context, index) => _EventCard(
                  event: workspace.events[index],
                  ownsLease: ownsLease,
                  onApproval: onApproval,
                  onClarification: onClarification,
                ),
              );
        if (desktop) {
          return Column(
            children: [
              header,
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: eventList),
                    Positioned(
                      right: 20,
                      top: 18,
                      child: SignalCoreView(
                        snapshot: signalCore,
                        dimension: coreDimension,
                        profile: SignalRenderProfile.highRefresh120,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return ListView(
          key: const ValueKey('mobile-conversation'),
          padding: EdgeInsets.zero,
          children: [
            header,
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              padding: const EdgeInsets.only(top: 10),
              child: SignalCoreView(
                snapshot: signalCore,
                dimension: coreDimension,
              ),
            ),
            if (workspace.events.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No durable events yet')),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final event in workspace.events)
                      _EventCard(
                        event: event,
                        ownsLease: ownsLease,
                        onApproval: onApproval,
                        onClarification: onClarification,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.conversation,
    required this.workspace,
    required this.ownsLease,
    required this.activeRequest,
    required this.onAcquire,
    required this.onInterrupt,
  });

  final ClientConversationDirectoryEntry conversation;
  final GatewayWorkspaceState workspace;
  final bool ownsLease;
  final ClientEventRecord? activeRequest;
  final VoidCallback onAcquire;
  final void Function(ClientEventRecord) onInterrupt;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    ownsLease
                        ? 'Control held by this device'
                        : workspace.selectedLease == null
                        ? 'Observe only · no control lease'
                        : 'Observe only · controlled by another device',
                    style: TextStyle(color: context.visualTokens.textMuted),
                  ),
                ],
              ),
            ),
            if (ownsLease && activeRequest != null)
              TextButton.icon(
                onPressed: () => onInterrupt(activeRequest!),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Interrupt'),
              )
            else if (!ownsLease)
              FilledButton.tonalIcon(
                onPressed: onAcquire,
                icon: const Icon(Icons.control_point_duplicate),
                label: Text(
                  workspace.selectedLease == null
                      ? 'Take control'
                      : 'Take over explicitly',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _terminalKinds = {
  ClientEventKind.requestCompleted,
  ClientEventKind.requestFailed,
  ClientEventKind.requestCancelled,
  ClientEventKind.requestInterrupted,
};

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.ownsLease,
    required this.onApproval,
    required this.onClarification,
  });

  final ClientEventRecord event;
  final bool ownsLease;
  final Future<void> Function(ClientEventRecord, ClientApprovalDecision)
  onApproval;
  final void Function(ClientEventRecord, String) onClarification;

  @override
  Widget build(BuildContext context) {
    final content = event.content;
    final pendingInteraction =
        event.kind == ClientEventKind.approvalRequired ||
        event.kind == ClientEventKind.clarificationRequired;
    final tokens = context.visualTokens;
    final title = event.kind.name;
    final text = switch (content) {
      MessageClientEventContent() => content.text,
      SafeMessageClientEventContent() => content.safeMessage,
      ToolClientEventContent() =>
        '${content.toolName} · ${content.stage}\n${content.safeSummary}',
      ApprovalClientEventContent() => content.safeSummary,
      ClarificationClientEventContent() => content.safePrompt,
      TerminalClientEventContent() =>
        content.failure?.safeMessage ?? 'Request finished.',
      UnsupportedClientEventContent() => content.safeMessage,
      EmptyClientEventContent() => '',
    };
    return Card(
      color: pendingInteraction
          ? Color.alphaBlend(
              tokens.attention.withValues(alpha: 0.12),
              tokens.panelRaised,
            )
          : null,
      shape: pendingInteraction
          ? RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              side: BorderSide(color: tokens.attention, width: 1.5),
            )
          : null,
      margin: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        container: true,
        liveRegion: pendingInteraction,
        label: pendingInteraction ? 'User action required' : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: pendingInteraction ? tokens.attention : null,
                  fontWeight: pendingInteraction ? FontWeight.w700 : null,
                ),
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 6),
                SelectableText(text),
              ],
              if (event.kind == ClientEventKind.approvalRequired &&
                  content is ApprovalClientEventContent) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: ownsLease
                          ? () => onApproval(
                              event,
                              ClientApprovalDecision.approve,
                            )
                          : null,
                      child: const Text('Approve'),
                    ),
                    OutlinedButton(
                      onPressed: ownsLease
                          ? () => onApproval(event, ClientApprovalDecision.deny)
                          : null,
                      child: const Text('Deny'),
                    ),
                  ],
                ),
              ],
              if (event.kind == ClientEventKind.clarificationRequired &&
                  content is ClarificationClientEventContent) ...[
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: ownsLease
                      ? () => _showClarificationDialog(context)
                      : null,
                  child: const Text('Answer explicitly'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showClarificationDialog(BuildContext context) async {
    final answer = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clarification response'),
        content: TextField(
          controller: answer,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Review this response before sending',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm and send'),
          ),
        ],
      ),
    );
    if (confirmed == true && answer.text.trim().isNotEmpty) {
      onClarification(event, answer.text);
    }
    answer.dispose();
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LOCAL RELAY  /  STANDBY',
              style: TextStyle(
                color: tokens.signal,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
              ),
            ),
            const SizedBox(height: 20),
            SignalCoreView(
              snapshot: resolveSignalCore(
                workspace: const GatewayWorkspaceState(),
                session: const ClientSessionState(),
                voice: const VoiceSessionState(),
                speech: const SpeechPlaybackState(),
              ),
              dimension: 124,
            ),
            const SizedBox(height: 24),
            const Text(
              'Pair a Gateway, then choose an Agent and conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Agent replies will remain complete text. Speech and visuals are optional views.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.textController,
    required this.session,
    required this.voice,
    required this.onChanged,
    required this.onConfirm,
    required this.onReopen,
    required this.onSend,
    required this.onNextDraft,
    required this.sendEnabled,
    required this.onStartVoice,
    required this.onStopVoice,
    required this.onCancelVoice,
    required this.onDiscardVoice,
  });

  final TextEditingController textController;
  final ClientSessionState session;
  final VoiceSessionState voice;
  final ValueChanged<String> onChanged;
  final VoidCallback onConfirm;
  final VoidCallback onReopen;
  final Future<void> Function() onSend;
  final VoidCallback onNextDraft;
  final bool sendEnabled;
  final Future<void> Function() onStartVoice;
  final Future<void> Function() onStopVoice;
  final Future<void> Function() onCancelVoice;
  final Future<void> Function() onDiscardVoice;

  @override
  Widget build(BuildContext context) {
    final confirmed = session.draftPhase == DraftPhase.confirmed;
    final accepted = session.draftPhase == DraftPhase.accepted;
    final uncertain = session.draftPhase == DraftPhase.uncertain;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.min(MediaQuery.sizeOf(context).height * 0.42, 340),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final editor = TextField(
                  controller: textController,
                  enabled: session.canEditDraft && !confirmed,
                  minLines: 1,
                  maxLines: 6,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    labelText: confirmed
                        ? 'Confirmed locally'
                        : 'Editable draft',
                    hintText: 'Type text to review before sending',
                  ),
                );
                final voiceAction = _VoiceAction(
                  voice: voice,
                  draftEditable: session.draftPhase == DraftPhase.editing,
                  onStart: onStartVoice,
                  onStop: onStopVoice,
                  onCancel: onCancelVoice,
                  onDiscard: onDiscardVoice,
                );
                final editorWithVoice = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    editor,
                    if (voice.phase != VoiceInputPhase.idle) ...[
                      const SizedBox(height: 6),
                      _VoiceStatus(voice: voice),
                    ],
                  ],
                );
                final primaryAction = accepted
                    ? OutlinedButton(
                        onPressed: onNextDraft,
                        child: const Text('New draft'),
                      )
                    : confirmed
                    ? OutlinedButton(
                        onPressed: onReopen,
                        child: const Text('Edit'),
                      )
                    : FilledButton(
                        onPressed: session.canConfirmDraft ? onConfirm : null,
                        child: const Text('Confirm'),
                      );
                final canSend = confirmed && session.canSubmit && sendEnabled;
                final sendAction = FilledButton.tonal(
                  onPressed: canSend ? onSend : null,
                  child: Text(
                    uncertain
                        ? 'Outcome uncertain'
                        : session.draftPhase == DraftPhase.submitting
                        ? 'Awaiting acceptance'
                        : canSend
                        ? 'Send confirmed text'
                        : 'Send unavailable',
                  ),
                );
                if (constraints.maxWidth < 640) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      editorWithVoice,
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [voiceAction, primaryAction, sendAction],
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: editorWithVoice),
                    const SizedBox(width: 12),
                    voiceAction,
                    const SizedBox(width: 8),
                    primaryAction,
                    const SizedBox(width: 8),
                    sendAction,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceAction extends StatelessWidget {
  const _VoiceAction({
    required this.voice,
    required this.draftEditable,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    required this.onDiscard,
  });

  final VoiceSessionState voice;
  final bool draftEditable;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;
  final Future<void> Function() onCancel;
  final Future<void> Function() onDiscard;

  @override
  Widget build(BuildContext context) {
    if (voice.phase == VoiceInputPhase.recording) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            onPressed: onStop,
            tooltip: 'Stop and transcribe',
            icon: const Icon(Icons.stop_rounded),
          ),
          IconButton(
            onPressed: onCancel,
            tooltip: 'Cancel recording',
            icon: const Icon(Icons.close),
          ),
        ],
      );
    }
    if (voice.canCancel) {
      return IconButton(
        onPressed: onCancel,
        tooltip: 'Cancel voice input',
        icon: const Icon(Icons.close),
      );
    }
    if (voice.phase == VoiceInputPhase.awaitingConfirmation) {
      return IconButton(
        onPressed: onDiscard,
        tooltip: 'Discard transcript',
        icon: const Icon(Icons.delete_outline),
      );
    }
    return IconButton.filledTonal(
      onPressed: draftEditable && voice.canStart ? onStart : null,
      tooltip: 'Record voice draft',
      icon: const Icon(Icons.mic_none),
    );
  }
}

class _VoiceStatus extends StatelessWidget {
  const _VoiceStatus({required this.voice});

  final VoiceSessionState voice;

  @override
  Widget build(BuildContext context) {
    final label = switch (voice.phase) {
      VoiceInputPhase.requestingPermission => 'Requesting microphone access',
      VoiceInputPhase.recording =>
        voice.provisionalTranscript.isEmpty
            ? 'Recording · speech remains editable before send'
            : 'Live transcript: ${voice.provisionalTranscript}',
      VoiceInputPhase.transcribing => 'Finalizing transcript',
      VoiceInputPhase.awaitingConfirmation =>
        'Transcript inserted · review and confirm before send',
      VoiceInputPhase.cancelled => 'Voice input cancelled',
      VoiceInputPhase.failed =>
        voice.failure?.safeMessage ?? 'Voice input failed',
      VoiceInputPhase.idle => '',
    };
    final progress = voice.phase == VoiceInputPhase.recording
        ? voice.audioLevel.clamp(0.02, 1.0)
        : null;
    return Semantics(
      liveRegion: true,
      label: label,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              semanticsLabel: 'Microphone level',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
