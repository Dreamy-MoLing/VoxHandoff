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
    this.sendLabel = 'Handoff to Hermes',
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
                    labelText: confirmed
                        ? 'Confirmed locally'
                        : 'Editable draft',
                    hintText:
                        'Type text to review before handing off to Hermes',
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
                        ? 'Outcome uncertain'
                        : session.draftPhase == DraftPhase.submitting
                        ? 'Awaiting acceptance'
                        : canSend
                        ? sendLabel
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
    if (voice.phase == VoiceInputPhase.awaitingCallConfirm) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            onPressed: onConfirmCallSend,
            tooltip: 'Send call preview',
            icon: const Icon(Icons.send_rounded),
          ),
          IconButton(
            onPressed: onDiscard,
            tooltip: 'Discard call preview',
            icon: const Icon(Icons.close),
          ),
        ],
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

class _VoiceStatus extends ConsumerWidget {
  const _VoiceStatus({required this.voice});

  final VoiceSessionState voice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = switch (voice.phase) {
      VoiceInputPhase.requestingPermission => 'Requesting microphone access',
      VoiceInputPhase.recording =>
        voice.interactionMode == InteractionMode.call
            ? voice.provisionalTranscript.isEmpty
                  ? 'Recording · release to send (Call mode)'
                  : 'Live transcript (Call): ${voice.provisionalTranscript}'
            : voice.provisionalTranscript.isEmpty
            ? 'Recording · speech remains editable before send'
            : 'Live transcript: ${voice.provisionalTranscript}',
      VoiceInputPhase.transcribing => 'Finalizing transcript',
      VoiceInputPhase.awaitingConfirmation =>
        'Transcript inserted · review and confirm before send',
      VoiceInputPhase.awaitingCallConfirm =>
        'Call preview · ${voice.finalTranscript ?? ''}',
      VoiceInputPhase.cancelled => 'Voice input cancelled',
      VoiceInputPhase.failed =>
        voice.failure?.safeMessage ?? 'Voice input failed',
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
