import 'package:flutter/material.dart';

import '../application/hermes_conversation_controller.dart';
import '../domain/direct_chat.dart';
import 'design/agent_talk_theme.dart';

class HermesConversationBanner extends StatelessWidget {
  const HermesConversationBanner({
    required this.state,
    required this.onConfigure,
    super.key,
  });

  final HermesConversationState state;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final configuration = state.configuration;
    final configured = state.isConfigured;
    final status =
        state.failure?.message ??
        (state.sessionBootstrapFallback
            ? '会话引导不可用，将使用稳定生成的 session ID。'
            : configured
            ? '已确认文本会发送到 Hermes Chat Completions。Agent 工作审批仍由 Hermes 负责。'
            : '请配置 HTTPS Hermes 地址，并将 API key 保存在操作系统安全存储中。');
    return Semantics(
      container: true,
      label: 'Hermes 对话；模型 ${configuration?.model ?? '未配置'}',
      child: ColoredBox(
        color: Color.alphaBlend(
          context.visualTokens.signal.withValues(alpha: 0.08),
          context.visualTokens.panel,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    configured
                        ? Icons.forum_outlined
                        : Icons.settings_ethernet_outlined,
                    color: configured
                        ? context.visualTokens.signal
                        : context.visualTokens.attention,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          configuration?.model ?? 'Hermes 对话',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(status),
                      ],
                    ),
                  ),
                ],
              );
              final button = OutlinedButton(
                onPressed: onConfigure,
                child: Text(configured ? '配置' : '配置 Hermes'),
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [content, const SizedBox(height: 8), button],
                );
              }
              return Row(
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 16),
                  button,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class HermesConversationView extends StatelessWidget {
  const HermesConversationView({
    required this.state,
    required this.onCancel,
    required this.onConfigure,
    this.mobileVisual = false,
    super.key,
  });

  final HermesConversationState state;
  final Future<void> Function() onCancel;
  final VoidCallback onConfigure;
  final bool mobileVisual;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _HermesConversationHeader(
        state: state,
        onCancel: onCancel,
        onConfigure: onConfigure,
        mobileVisual: mobileVisual,
      ),
      Expanded(
        child: state.messages.isEmpty
            ? Center(
                child: Text(
                  state.isConfigured
                      ? '确认文本，开始 Hermes 对话。'
                      : '发送已确认文本前，请先配置 Hermes 对话。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.visualTokens.textMuted),
                ),
              )
            : ListView.builder(
                padding: mobileVisual
                    ? const EdgeInsets.fromLTRB(20, 10, 20, 18)
                    : const EdgeInsets.all(16),
                itemCount: state.messages.length,
                itemBuilder: (context, index) => _HermesMessageBubble(
                  message: state.messages[index],
                  mobileVisual: mobileVisual,
                ),
              ),
      ),
    ],
  );
}

class _HermesConversationHeader extends StatelessWidget {
  const _HermesConversationHeader({
    required this.state,
    required this.onCancel,
    required this.onConfigure,
    required this.mobileVisual,
  });

  final HermesConversationState state;
  final Future<void> Function() onCancel;
  final VoidCallback onConfigure;
  final bool mobileVisual;

  @override
  Widget build(BuildContext context) {
    final configuration = state.configuration;
    final status = switch (state.phase) {
      HermesConversationPhase.unconfigured => '未配置',
      HermesConversationPhase.restoring => '正在恢复会话历史',
      HermesConversationPhase.bootstrapping => '正在创建 Hermes 会话',
      HermesConversationPhase.ready => '已就绪',
      HermesConversationPhase.testing => '正在测试地址',
      HermesConversationPhase.sending => '正在流式回复',
      HermesConversationPhase.cancelled => '上一条回复已取消',
      HermesConversationPhase.failed => '请求需要处理',
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobileVisual ? 20 : 16,
        mobileVisual ? 10 : 12,
        mobileVisual ? 20 : 16,
        6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  configuration?.model ?? 'Hermes 对话',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  state.toolProgress == null
                      ? 'Hermes Chat Completions · $status'
                      : '${state.toolProgress} · $status',
                  style: TextStyle(
                    color: state.failure == null
                        ? context.visualTokens.textMuted
                        : context.visualTokens.attention,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '配置 Hermes 对话',
            onPressed: onConfigure,
            icon: const Icon(Icons.tune_outlined),
          ),
          if (state.phase == HermesConversationPhase.sending)
            TextButton.icon(
              onPressed: () => onCancel(),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('停止'),
            ),
        ],
      ),
    );
  }
}

class _HermesMessageBubble extends StatelessWidget {
  const _HermesMessageBubble({
    required this.message,
    required this.mobileVisual,
  });

  final DirectChatMessage message;
  final bool mobileVisual;

  @override
  Widget build(BuildContext context) {
    final user = message.role == DirectChatRole.user;
    final streaming =
        message.terminal == DirectMessageTerminal.streaming && !user;
    final bubble = mobileVisual
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: user
                  ? context.visualTokens.signal.withValues(alpha: 0.12)
                  : context.visualTokens.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: user
                    ? context.visualTokens.signal.withValues(alpha: 0.24)
                    : context.visualTokens.textMuted.withValues(alpha: 0.12),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SelectableText(
                streaming && message.text.isEmpty ? '…' : message.text,
                style: const TextStyle(fontSize: 18, height: 1.45),
              ),
            ),
          )
        : Card(
            color: user
                ? context.visualTokens.signal.withValues(alpha: 0.12)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    streaming && message.text.isEmpty ? '…' : message.text,
                  ),
                  if (!user &&
                      message.terminal != DirectMessageTerminal.completed)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _directMessageTerminalLabel(message.terminal),
                        style: TextStyle(
                          color: context.visualTokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: mobileVisual
            ? const BoxConstraints(maxWidth: 360)
            : const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: mobileVisual ? 7 : 0),
          child: bubble,
        ),
      ),
    );
  }
}

String _directMessageTerminalLabel(DirectMessageTerminal terminal) =>
    switch (terminal) {
      DirectMessageTerminal.streaming => '流式回复中',
      DirectMessageTerminal.completed => '已完成',
      DirectMessageTerminal.cancelled => '已取消',
      DirectMessageTerminal.failed => '失败',
      DirectMessageTerminal.incomplete => '不完整',
      DirectMessageTerminal.truncated => '已截断',
    };
