import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/voice_session_controller.dart';
import '../domain/client_session.dart';
import '../domain/interaction_mode.dart';
import '../domain/voice.dart';

class MessageComposer extends StatelessWidget {
  const MessageComposer({
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
    required this.onConfirmCallSend,
    this.sendLabel = '交给 Hermes',
    this.requiresGatewayConnection = true,
    super.key,
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
  final Future<void> Function() onConfirmCallSend;
  final String sendLabel;
  final bool requiresGatewayConnection;

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
                    labelText: confirmed ? '已在本地确认' : '可编辑草稿',
                    hintText: '输入文字，检查后再交给 Hermes',
                  ),
                );
                final voiceAction = _VoiceAction(
                  voice: voice,
                  draftEditable: session.draftPhase == DraftPhase.editing,
                  onStart: onStartVoice,
                  onStop: onStopVoice,
                  onCancel: onCancelVoice,
                  onDiscard: onDiscardVoice,
                  onConfirmCallSend: onConfirmCallSend,
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
                        child: const Text('新建草稿'),
                      )
                    : confirmed
                    ? OutlinedButton(
                        onPressed: onReopen,
                        child: const Text('编辑'),
                      )
                    : FilledButton(
                        onPressed: session.canConfirmDraft ? onConfirm : null,
                        child: const Text('确认'),
                      );
                final canSend =
                    confirmed &&
                    (requiresGatewayConnection
                        ? session.canSubmit
                        : session.draftPhase == DraftPhase.confirmed) &&
                    sendEnabled;
                final sendAction = FilledButton.tonalIcon(
                  onPressed: canSend ? onSend : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  label: Text(
                    uncertain
                        ? '结果不确定'
                        : session.draftPhase == DraftPhase.submitting
                        ? '等待接受'
                        : canSend
                        ? sendLabel
                        : '暂不可发送',
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
    required this.onConfirmCallSend,
  });

  final VoiceSessionState voice;
  final bool draftEditable;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;
  final Future<void> Function() onCancel;
  final Future<void> Function() onDiscard;
  final Future<void> Function() onConfirmCallSend;

  @override
  Widget build(BuildContext context) {
    if (voice.phase == VoiceInputPhase.recording) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            onPressed: onStop,
            tooltip: '停止并转写',
            icon: const Icon(Icons.stop_rounded),
          ),
          IconButton(
            onPressed: onCancel,
            tooltip: '取消录音',
            icon: const Icon(Icons.close),
          ),
        ],
      );
    }
    if (voice.canCancel) {
      return IconButton(
        onPressed: onCancel,
        tooltip: '取消语音输入',
        icon: const Icon(Icons.close),
      );
    }
    if (voice.phase == VoiceInputPhase.awaitingCallConfirm) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            onPressed: onConfirmCallSend,
            tooltip: '发送通话预览',
            icon: const Icon(Icons.send_rounded),
          ),
          IconButton(
            onPressed: onDiscard,
            tooltip: '丢弃通话预览',
            icon: const Icon(Icons.close),
          ),
        ],
      );
    }
    if (voice.phase == VoiceInputPhase.awaitingConfirmation) {
      return IconButton(
        onPressed: onDiscard,
        tooltip: '丢弃转写',
        icon: const Icon(Icons.delete_outline),
      );
    }
    return IconButton.filledTonal(
      onPressed: draftEditable && voice.canStart ? onStart : null,
      tooltip: '录制语音草稿',
      icon: const Icon(Icons.mic_none),
    );
  }
}

class _VoiceStatus extends ConsumerWidget {
  const _VoiceStatus({required this.voice});

  final VoiceSessionState voice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = switch (voice.phase) {
      VoiceInputPhase.requestingPermission => '正在请求麦克风权限',
      VoiceInputPhase.recording =>
        voice.interactionMode == InteractionMode.call
            ? voice.provisionalTranscript.isEmpty
                  ? '正在录音 · 松开即发送（通话模式）'
                  : '实时转写（通话模式）：${voice.provisionalTranscript}'
            : voice.provisionalTranscript.isEmpty
            ? '正在录音 · 发送前仍可编辑语音内容'
            : '实时转写：${voice.provisionalTranscript}',
      VoiceInputPhase.transcribing => '正在完成转写',
      VoiceInputPhase.awaitingConfirmation => '转写已填入 · 请检查并确认后发送',
      VoiceInputPhase.awaitingCallConfirm =>
        '通话预览 · ${voice.finalTranscript ?? ''}',
      VoiceInputPhase.cancelled => '语音输入已取消',
      VoiceInputPhase.failed => voice.failure?.safeMessage ?? '语音输入失败',
      VoiceInputPhase.idle => '',
    };
    final audioLevel = ref.watch(
      voiceSessionProvider.select((state) => state.audioLevel),
    );
    final progress = voice.phase == VoiceInputPhase.recording
        ? audioLevel.clamp(0.02, 1.0)
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
              semanticsLabel: '麦克风音量',
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
