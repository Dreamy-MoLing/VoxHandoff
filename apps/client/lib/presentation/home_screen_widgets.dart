part of 'home_screen.dart';

String _capabilityLabel(AssistantCapability capability) => switch (capability) {
  AssistantCapability.chat => '聊天',
  AssistantCapability.agent => '助手工作',
  AssistantCapability.tools => '工具',
  AssistantCapability.approvals => '审批',
  AssistantCapability.leases => '控制租约',
  AssistantCapability.interrupt => '中断',
  AssistantCapability.clarifications => '澄清',
};

String _capabilitiesLabel(Set<AssistantCapability> capabilities) =>
    capabilities.map(_capabilityLabel).join('、');

class _DesktopCapabilityIcon extends StatelessWidget {
  const _DesktopCapabilityIcon({required this.snapshot});

  final DesktopCapabilitySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final degraded = snapshot.hasDegradedCapability;
    return Tooltip(
      message: snapshot.safeSummary,
      child: Semantics(
        label: degraded ? '桌面集成部分可用' : '桌面集成可用',
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
      message: connected ? '已连接' : '未连接',
      child: Icon(
        connected ? Icons.verified_user_outlined : Icons.link_off,
        color: connected ? tokens.signal : tokens.textMuted,
        semanticLabel: connected ? '已连接' : '未连接',
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
      GatewayConnectionPhase.unpaired => '未配对',
      GatewayConnectionPhase.connecting => '连接中',
      GatewayConnectionPhase.connected => '已连接',
      GatewayConnectionPhase.reconnecting => '重连中',
      GatewayConnectionPhase.offline => '离线',
      GatewayConnectionPhase.failed => '连接失败',
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
                  '助手',
                  style: TextStyle(
                    color: context.visualTokens.signal,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                if (workspace.directory?.agents.isEmpty ?? true)
                  const Text('暂无可用助手')
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
                  '会话',
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
                      label: const Text('新建会话'),
                    ),
                  ),
                if (workspace.directory?.conversations.isEmpty ?? true)
                  const Text('未选择会话')
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
                            ? '已建立认证 Gateway 流。只有明确确认的文本可以发送。'
                            : paired
                            ? '设备凭据已验证。请明确连接以加载助手和会话。'
                            : '尚未配对。草稿文本保留在此设备上，无法发送。'),
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
                  'Hermes 能力：${_capabilitiesLabel(capabilities.capabilities)}；助手状态只来自已认证的 Gateway',
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
                    ? '断开连接'
                    : paired
                    ? '连接 Gateway'
                    : '配对 Gateway',
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
                        ? '断开连接'
                        : paired
                        ? '连接 Gateway'
                        : '配对 Gateway',
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
        '${assistant?.displayName ?? 'VoxHandoff'}；能力：${_capabilitiesLabel(capabilities.capabilities)}；助手工具、审批、控制租约和远程执行不可用',
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
                        ? 'Direct LLM 对话仅在此设备上进行，不提供助手工具、审批或跨设备指令。'
                        : '请配置 HTTPS OpenAI 兼容的 LLM API。其 key 仅保存在操作系统安全存储中。'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onConfigure,
              child: Text(state.isConfigured ? '配置' : '配置 LLM'),
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
              decoration: const InputDecoration(labelText: '会话'),
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
            tooltip: '新建会话',
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
        title: const Text('新建会话'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ClientAgentDirectoryEntry>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: '助手'),
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
                decoration: const InputDecoration(labelText: '标题'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('创建'),
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
                    '本地中继  /  待命',
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
                    '请先配对 Gateway，再选择助手和会话。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '助手回复始终保留为完整文本；语音和视觉都是可选呈现。',
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
