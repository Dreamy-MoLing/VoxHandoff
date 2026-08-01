import 'package:flutter/material.dart';

import '../application/direct_chat_controller.dart';
import '../domain/direct_chat.dart';
import 'design/agent_talk_theme.dart';

class DirectChatView extends StatelessWidget {
  const DirectChatView({
    required this.state,
    required this.onCancel,
    required this.onSpeak,
    required this.speechEnabled,
    super.key,
  });
  final DirectChatState state;
  final Future<void> Function() onCancel;
  final Future<void> Function(DirectChatMessage) onSpeak;
  final bool speechEnabled;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _DirectChatHeader(state: state, onCancel: onCancel),
      Expanded(
        child: state.messages.isEmpty
            ? const Center(
                child: Text(
                  'Configure your LLM API, then send confirmed text.\nThis source has no tools or approvals.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.messages.length,
                itemBuilder: (context, index) => _MessageBubble(
                  message: state.messages[index],
                  canSpeak:
                      speechEnabled &&
                      state.assistantProfile?.speechPolicy ==
                          AssistantSpeechPolicy.manual &&
                      state.messages[index].role == DirectChatRole.assistant &&
                      state.messages[index].terminal ==
                          DirectMessageTerminal.completed,
                  onSpeak: onSpeak,
                ),
              ),
      ),
    ],
  );
}

class _DirectChatHeader extends StatelessWidget {
  const _DirectChatHeader({required this.state, required this.onCancel});
  final DirectChatState state;
  final Future<void> Function() onCancel;
  @override
  Widget build(BuildContext context) {
    final configured = state.configuration;
    return ColoredBox(
      color: context.visualTokens.panel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.forum_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    configured == null ? 'Direct LLM chat' : configured.model,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    state.phase == DirectChatPhase.sending
                        ? 'Streaming reply locally'
                        : 'Direct HTTPS chat · no tools or approval',
                    style: TextStyle(color: context.visualTokens.textMuted),
                  ),
                ],
              ),
            ),
            if (state.phase == DirectChatPhase.sending)
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop'),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.canSpeak,
    required this.onSpeak,
  });
  final DirectChatMessage message;
  final bool canSpeak;
  final Future<void> Function(DirectChatMessage) onSpeak;
  @override
  Widget build(BuildContext context) {
    final user = message.role == DirectChatRole.user;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          color: user
              ? context.visualTokens.signal.withValues(alpha: 0.12)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  message.text.isEmpty &&
                          message.terminal == DirectMessageTerminal.streaming
                      ? '…'
                      : message.text,
                ),
                if (canSpeak)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Speak this completed reply',
                      onPressed: () => onSpeak(message),
                      icon: const Icon(Icons.volume_up_outlined),
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
