import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/client_session_controller.dart';
import '../application/chat_source_controller.dart';
import '../application/desktop_integration_controller.dart';
import '../application/direct_chat_controller.dart';
import '../application/device_pairing_controller.dart';
import '../application/gateway_workspace_controller.dart';
import '../application/voice_session_controller.dart';
import '../domain/client_session.dart';
import '../domain/confirmed_draft.dart';
import '../domain/direct_chat.dart';
import '../domain/desktop_capabilities.dart';
import '../domain/device_pairing.dart';
import '../domain/gateway_sync.dart';
import '../domain/gateway_workspace.dart';
import '../domain/signal_core.dart';
import '../domain/speech.dart';
import '../domain/voice.dart';
import 'conversation_view.dart';
import 'direct_chat_view.dart';
import 'direct_llm_settings_sheet.dart';
import 'design/agent_talk_theme.dart';
import 'message_composer.dart';
import 'pairing_dialog.dart';
import 'voice_settings_sheet.dart';
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
    final session = ref.read(clientSessionProvider);
    final source = ref.read(chatSourceProvider);
    final direct = ref.read(directChatProvider);
    final workspace = ref.read(gatewayWorkspaceProvider);
    if (source == ChatSource.hermes && workspace.selectedConversation == null) {
      // An unpaired shell may still keep a local confirmed draft for the
      // existing composer UX. It has no routable target and cannot be sent.
      ref.read(clientSessionProvider.notifier).confirmDraft();
      final confirmedText = ref.read(clientSessionProvider).draftText;
      _composer.value = TextEditingValue(
        text: confirmedText,
        selection: TextSelection.collapsed(offset: confirmedText.length),
      );
      return;
    }
    final assistant =
        direct.assistantProfile ??
        const AssistantProfile(
          assistantId: 'default-assistant-uninitialized',
          assistantRevision: 1,
          systemPrompt: '',
        );
    final target = switch (source) {
      ChatSource.directLlm => _directTarget(direct),
      ChatSource.hermes => _hermesTarget(workspace),
    };
    final contextParts = switch (source) {
      ChatSource.directLlm =>
        direct.messages
            .where((message) => message.contextEligible)
            .map(
              (message) => '${message.id}:${message.revision}:${message.text}',
            )
            .toList(growable: false),
      ChatSource.hermes =>
        workspace.events
            .map((event) => '${event.eventId}:${event.sequence}')
            .toList(growable: false),
    };
    final contextRevision = source == ChatSource.directLlm
        ? direct.configuration?.contextSnapshotRevision ?? 0
        : workspace.selectedConversation?.revision.toInt() ?? 0;
    final draft = ConfirmedDraft(
      draftId: _opaqueId('draft'),
      draftRevision: session.draftRevision,
      confirmedText: session.draftText,
      assistantId: assistant.assistantId,
      assistantRevision: assistant.assistantRevision,
      contextSnapshotRevision: contextRevision,
      contextSnapshotHash: ConfirmedDraft.contextHash(contextParts),
      target: target,
    );
    ref.read(clientSessionProvider.notifier).confirmDraft(draft);
    final confirmedText = ref.read(clientSessionProvider).draftText;
    _composer.value = TextEditingValue(
      text: confirmedText,
      selection: TextSelection.collapsed(offset: confirmedText.length),
    );
  }

  Future<void> _openPairing() => showDevicePairingDialog(context);

  Future<void> _send() async {
    final draft = ref.read(clientSessionProvider).confirmedDraft;
    if (draft == null) return;
    if (draft.chatSource == ChatSource.directLlm) {
      await ref.read(directChatProvider.notifier).sendConfirmedText(draft);
    } else {
      await ref
          .read(gatewayWorkspaceProvider.notifier)
          .sendConfirmedText(draft);
    }
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
    final source = ref.watch(chatSourceProvider);
    final directChat = ref.watch(directChatProvider);
    final workspace = ref.watch(gatewayWorkspaceProvider);
    ref.listen(gatewayWorkspaceProvider, (_, next) {
      unawaited(
        ref.read(desktopIntegrationProvider.notifier).observeWorkspace(next),
      );
    });
    final workspaceController = ref.read(gatewayWorkspaceProvider.notifier);
    ref.watch(
      voiceSessionProvider.select(
        (voice) => (
          voice.phase,
          voice.sessionId,
          voice.provisionalTranscript,
          voice.finalTranscript,
          voice.failure,
        ),
      ),
    );
    final voice = ref.read(voiceSessionProvider);
    final desktop = ref.watch(desktopIntegrationProvider);
    final ownsLease = workspace.ownsSelectedLease(
      workspaceController.deviceId,
      DateTime.now(),
    );
    final compactAppBar = MediaQuery.sizeOf(context).width < 480;
    final isDirect = source == ChatSource.directLlm;
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
            PopupMenuButton<ChatSource>(
              tooltip: 'Choose chat source',
              initialValue: source,
              onSelected: (value) => unawaited(
                ref.read(chatSourceProvider.notifier).select(value),
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ChatSource.hermes,
                  child: Text('Hermes via Gateway'),
                ),
                PopupMenuItem(
                  value: ChatSource.directLlm,
                  child: Text('Direct LLM API'),
                ),
              ],
              child: IconButton(
                onPressed: null,
                icon: Icon(
                  isDirect ? Icons.forum_outlined : Icons.hub_outlined,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Source settings',
              onPressed: () => showVoiceSettingsSheet(context),
              icon: const Icon(Icons.tune_outlined),
            ),
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
            final banner = isDirect
                ? _DirectLlmBanner(
                    state: directChat,
                    onConfigure: () => showDirectLlmSettingsSheet(context),
                  )
                : _LocalOnlyBanner(
                    pairing: pairing,
                    workspace: workspace,
                    onOpenPairing: _openPairing,
                    onConnect: workspaceController.connect,
                    onDisconnect: workspaceController.disconnect,
                  );
            final conversation = isDirect
                ? DirectChatView(
                    state: directChat,
                    onCancel: ref.read(directChatProvider.notifier).cancel,
                  )
                : workspace.selectedConversation == null
                ? const _EmptyConversation()
                : ConversationView(
                    workspace: workspace,
                    ownsLease: ownsLease,
                    onAcquire: () => workspaceController.acquireSelectedControl(
                      explicitTakeover: workspace.selectedLease != null,
                    ),
                    onApproval: workspaceController.resolveApproval,
                    onClarification: workspaceController.resolveClarification,
                    onInterrupt: workspaceController.interrupt,
                  );
            final composer = MessageComposer(
              textController: _composer,
              session: session,
              voice: voice,
              onChanged: controller.editDraft,
              onConfirm: _confirmDraft,
              onReopen: controller.reopenDraft,
              onSend: _send,
              onNextDraft: _startNextDraft,
              sendEnabled: isDirect
                  ? directChat.isConfigured &&
                        directChat.phase != DirectChatPhase.sending
                  : ownsLease,
              requiresGatewayConnection: !isDirect,
              sendLabel: isDirect ? 'Send to LLM' : 'Handoff to Hermes',
              onStartVoice: _startVoice,
              onStopVoice: _stopVoice,
              onCancelVoice: _cancelVoice,
              onDiscardVoice: _discardVoice,
            );
            if (!showNavigation || isDirect) {
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

  DirectTargetSnapshot _directTarget(DirectChatState state) {
    final configuration = state.configuration;
    if (configuration == null || configuration.conversationId.isEmpty) {
      throw StateError('Configure the Direct LLM target before confirming.');
    }
    return DirectTargetSnapshot(
      conversationId: configuration.conversationId,
      providerProfileId: configuration.profileId,
      credentialRevision: configuration.credentialRevision,
      configurationRevision: configuration.configurationRevision,
      normalizedOrigin: normalizedProviderOrigin(configuration.origin),
      model: configuration.model,
    );
  }

  HermesTargetSnapshot _hermesTarget(GatewayWorkspaceState workspace) {
    final conversation = workspace.selectedConversation;
    if (conversation == null) {
      throw StateError('Select a Hermes conversation before confirming.');
    }
    return HermesTargetSnapshot(
      conversationId: conversation.conversationId,
      nodeId: conversation.nodeId,
      agentId: conversation.agentId,
      capabilityRevision: conversation.capabilityRevision,
      sessionId: conversation.sessionId,
    );
  }

  String _opaqueId(String prefix) {
    final random = math.Random.secure();
    return '$prefix-${List<int>.generate(16, (_) => random.nextInt(256)).map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
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

class _DirectLlmBanner extends StatelessWidget {
  const _DirectLlmBanner({required this.state, required this.onConfigure});

  final DirectChatState state;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.visualTokens.panel,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.failure?.message ??
                  (state.isConfigured
                      ? 'Direct LLM chat is local to this device. It has no Agent tools, approvals, or cross-device commands.'
                      : 'Configure a HTTPS OpenAI-compatible LLM API. Its key is stored only in OS secure storage.'),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onConfigure,
            child: Text(state.isConfigured ? 'Configure' : 'Configure LLM'),
          ),
        ],
      ),
    ),
  );
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

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 24),
          ),
          child: Center(
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
                  const SizedBox(height: 16),
                  SignalCoreView(
                    snapshot: resolveSignalCore(
                      workspace: const GatewayWorkspaceState(),
                      session: const ClientSessionState(),
                      voice: const VoiceSessionState(),
                      speech: const SpeechPlaybackState(),
                    ),
                    dimension: 112,
                  ),
                  const SizedBox(height: 18),
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
          ),
        ),
      ),
    );
  }
}
