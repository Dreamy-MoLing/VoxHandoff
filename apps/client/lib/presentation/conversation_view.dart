import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/client_session_controller.dart';
import '../application/speech_playback_controller.dart';
import '../application/voice_session_controller.dart';
import '../domain/client_event.dart';
import '../domain/conversation_timeline.dart';
import '../domain/gateway_sync.dart';
import '../domain/gateway_workspace.dart';
import '../domain/signal_core.dart';
import 'design/agent_talk_theme.dart';
import 'signal_core_view.dart';

class ConversationView extends StatelessWidget {
  const ConversationView({
    required this.workspace,
    required this.ownsLease,
    required this.onAcquire,
    required this.onApproval,
    required this.onClarification,
    required this.onInterrupt,
    super.key,
  });

  final GatewayWorkspaceState workspace;
  final bool ownsLease;
  final VoidCallback onAcquire;
  final Future<void> Function(ClientEventRecord, ClientApprovalDecision)
  onApproval;
  final void Function(ClientEventRecord, String) onClarification;
  final void Function(ClientEventRecord) onInterrupt;

  @override
  Widget build(BuildContext context) {
    final conversation = workspace.selectedConversation!;
    final activeRequest = workspace.activeTurn?.latestEvent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;
        final header = _ConversationHeader(
          conversationTitle: conversation.title,
          workspace: workspace,
          ownsLease: ownsLease,
          activeRequest: activeRequest,
          onAcquire: onAcquire,
          onInterrupt: onInterrupt,
        );
        if (desktop) {
          const coreDimension = 240.0;
          return Column(
            children: [
              header,
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _TurnList(
                        turns: workspace.timeline,
                        ownsLease: ownsLease,
                        trailingInset: coreDimension + 52,
                        onApproval: onApproval,
                        onClarification: onClarification,
                      ),
                    ),
                    Positioned(
                      right: 24,
                      top: 22,
                      child: _LiveSignalCore(
                        workspace: workspace,
                        dimension: coreDimension,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return CustomScrollView(
          key: const ValueKey('mobile-conversation'),
          slivers: [
            SliverToBoxAdapter(child: header),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: _LiveSignalCore(workspace: workspace, dimension: 172),
                ),
              ),
            ),
            if (workspace.timeline.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No durable turns yet')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                sliver: SliverList.builder(
                  itemCount: workspace.timeline.length,
                  itemBuilder: (context, index) => _TurnCard(
                    turn: workspace.timeline[index],
                    ownsLease: ownsLease,
                    onApproval: onApproval,
                    onClarification: onClarification,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TurnList extends StatelessWidget {
  const _TurnList({
    required this.turns,
    required this.ownsLease,
    required this.trailingInset,
    required this.onApproval,
    required this.onClarification,
  });

  final List<ConversationTurn> turns;
  final bool ownsLease;
  final double trailingInset;
  final Future<void> Function(ClientEventRecord, ClientApprovalDecision)
  onApproval;
  final void Function(ClientEventRecord, String) onClarification;

  @override
  Widget build(BuildContext context) {
    if (turns.isEmpty) {
      return const Center(child: Text('No durable turns yet'));
    }
    return ListView.builder(
      key: const ValueKey('conversation-turns'),
      padding: EdgeInsets.fromLTRB(20, 20, trailingInset, 24),
      itemCount: turns.length,
      itemBuilder: (context, index) => _TurnCard(
        turn: turns[index],
        ownsLease: ownsLease,
        onApproval: onApproval,
        onClarification: onClarification,
      ),
    );
  }
}

class _LiveSignalCore extends ConsumerWidget {
  const _LiveSignalCore({required this.workspace, required this.dimension});

  final GatewayWorkspaceState workspace;
  final double dimension;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(clientSessionProvider);
    final voice = ref.watch(voiceSessionProvider);
    final speech = ref.watch(speechPlaybackProvider);
    return RepaintBoundary(
      child: SignalCoreView(
        snapshot: resolveSignalCore(
          workspace: workspace,
          session: session,
          voice: voice,
          speech: speech,
        ),
        dimension: dimension,
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.conversationTitle,
    required this.workspace,
    required this.ownsLease,
    required this.activeRequest,
    required this.onAcquire,
    required this.onInterrupt,
  });

  final String conversationTitle;
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
                    conversationTitle,
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
                label: const Text('Stop Hermes'),
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

class _TurnCard extends StatelessWidget {
  const _TurnCard({
    required this.turn,
    required this.ownsLease,
    required this.onApproval,
    required this.onClarification,
  });

  final ConversationTurn turn;
  final bool ownsLease;
  final Future<void> Function(ClientEventRecord, ClientApprovalDecision)
  onApproval;
  final void Function(ClientEventRecord, String) onClarification;

  @override
  Widget build(BuildContext context) {
    final pending = turn.pendingInteraction;
    final tokens = context.visualTokens;
    return Semantics(
      container: true,
      label: 'Conversation turn',
      child: Card(
        key: ValueKey('turn-${turn.requestId}'),
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Color.alphaBlend(
                tokens.signal.withValues(alpha: 0.07),
                tokens.panelRaised,
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 18, color: tokens.signal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      turn.userText ?? 'Confirmed user turn',
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    _shortIdentity(turn.requestId),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: tokens.textMuted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 18,
                        color: tokens.signal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HERMES',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: tokens.signal,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const Spacer(),
                      _TurnStatus(turn: turn),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (turn.assistantText.isEmpty)
                    Text(
                      turn.isTerminal
                          ? 'No assistant text was returned.'
                          : 'Hermes is working…',
                      style: TextStyle(color: tokens.textMuted),
                    )
                  else
                    SelectableText(turn.assistantText),
                  if (turn.tools.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ToolTracePanel(tools: turn.tools),
                  ],
                  if (pending != null) ...[
                    const SizedBox(height: 14),
                    _InteractionPanel(
                      event: pending,
                      ownsLease: ownsLease,
                      onApproval: onApproval,
                      onClarification: onClarification,
                    ),
                  ],
                  if (_latestConnectionWarning(turn) case final warning?) ...[
                    const SizedBox(height: 12),
                    Text(warning, style: TextStyle(color: tokens.attention)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnStatus extends StatelessWidget {
  const _TurnStatus({required this.turn});

  final ConversationTurn turn;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (turn.terminalEvent?.kind) {
      ClientEventKind.requestCompleted => (
        'Completed',
        Icons.check_circle_outline,
      ),
      ClientEventKind.requestFailed => ('Failed', Icons.error_outline),
      ClientEventKind.requestCancelled => ('Cancelled', Icons.cancel_outlined),
      ClientEventKind.requestInterrupted => (
        'Stopped',
        Icons.stop_circle_outlined,
      ),
      _ => ('Live', Icons.graphic_eq),
    };
    return Semantics(
      label: 'Hermes turn status: $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ToolTracePanel extends StatelessWidget {
  const _ToolTracePanel({required this.tools});

  final List<ToolTrace> tools;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 6),
      leading: const Icon(Icons.account_tree_outlined),
      title: Text('Tool trace · ${tools.length}'),
      children: [
        for (final tool in tools)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 10),
            leading: Icon(switch (tool.state) {
              ToolTraceState.running => Icons.more_horiz,
              ToolTraceState.completed => Icons.check,
              ToolTraceState.failed => Icons.error_outline,
            }),
            title: Text(tool.toolName),
            subtitle: Text(tool.safeSummary),
          ),
      ],
    );
  }
}

class _InteractionPanel extends StatelessWidget {
  const _InteractionPanel({
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
    final tokens = context.visualTokens;
    final content = event.content;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'User action required',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.attention.withValues(alpha: 0.08),
          border: Border.all(color: tokens.attention, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.kind == ClientEventKind.approvalRequired
                    ? 'Explicit approval required'
                    : 'Hermes needs clarification',
                style: TextStyle(
                  color: tokens.attention,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(switch (content) {
                ApprovalClientEventContent() => content.safeSummary,
                ClarificationClientEventContent() => content.safePrompt,
                _ => 'Review the pending interaction.',
              }),
              const SizedBox(height: 12),
              if (content is ApprovalClientEventContent)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: ownsLease
                          ? () => onApproval(
                              event,
                              ClientApprovalDecision.approve,
                            )
                          : null,
                      child: const Text('Approve once'),
                    ),
                    OutlinedButton(
                      onPressed: ownsLease
                          ? () => onApproval(event, ClientApprovalDecision.deny)
                          : null,
                      child: const Text('Deny'),
                    ),
                  ],
                )
              else if (content is ClarificationClientEventContent)
                FilledButton.tonal(
                  onPressed: ownsLease
                      ? () => _showClarificationDialog(context)
                      : null,
                  child: const Text('Answer explicitly'),
                ),
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

String? _latestConnectionWarning(ConversationTurn turn) {
  for (final event in turn.events.reversed) {
    if (event.kind == ClientEventKind.connectionLost &&
        event.content is SafeMessageClientEventContent) {
      return (event.content as SafeMessageClientEventContent).safeMessage;
    }
    if (event.kind == ClientEventKind.connectionReady) return null;
  }
  return null;
}

String _shortIdentity(String value) =>
    value.length <= 12 ? value : '…${value.substring(value.length - 8)}';
