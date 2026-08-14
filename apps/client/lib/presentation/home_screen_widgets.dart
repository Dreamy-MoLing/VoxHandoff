part of 'home_screen.dart';

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
    ClientAgentDirectoryEntry? selectedAgent;
    final selectedAgentId = workspace.selectedConversation?.agentId;
    for (final agent in workspace.directory?.agents ?? const []) {
      if (agent.agentId == selectedAgentId) {
        selectedAgent = agent;
        break;
      }
    }
    final capabilities = selectedAgent == null
        ? const AssistantCapabilityProjection(
            source: ChatSource.hermes,
            capabilities: {AssistantCapability.chat, AssistantCapability.agent},
          )
        : AssistantCapabilityProjection.hermesFromNegotiation(
            supportsApprovals: selectedAgent.supportsApprovals,
            supportsInterrupt: selectedAgent.supportsInterrupt,
            supportsClarifications: selectedAgent.supportsClarifications,
          );
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
            final accessibleMessage = Semantics(
              container: true,
              label:
                  'Hermes capabilities: ${capabilities.capabilities.map((capability) => capability.name).join(', ')}; Agent state comes only from the authenticated Gateway',
              child: message,
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
                  Expanded(child: accessibleMessage),
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
                  accessibleMessage,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: pairButton),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: accessibleMessage),
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
  const _DirectLlmBanner({
    required this.state,
    required this.assistant,
    required this.capabilities,
    required this.onConfigure,
  });

  final DirectChatState state;
  final AssistantProfile? assistant;
  final AssistantCapabilityProjection capabilities;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        '${assistant?.displayName ?? 'VoxHandoff'}; capabilities: ${capabilities.capabilities.map((capability) => capability.name).join(', ')}; Agent tools, approvals, leases, and remote execution are unavailable',
    child: ColoredBox(
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
