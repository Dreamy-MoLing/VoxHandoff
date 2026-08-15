import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/chat_source_controller.dart';
import '../application/client_session_controller.dart';
import '../application/direct_chat_controller.dart';
import '../application/gateway_workspace_controller.dart';
import '../application/speech_playback_controller.dart';
import '../application/voice_session_controller.dart';
import '../domain/client_session.dart';
import '../domain/direct_chat.dart';
import '../domain/gateway_workspace.dart';
import '../domain/signal_core.dart';
import '../domain/voice.dart';
import 'conversation_view.dart';
import 'design/agent_talk_theme.dart';
import 'direct_chat_view.dart';
import 'mobile_visual_preferences.dart';
import 'mobile_visual_settings_sheet.dart';
import 'signal_core_view.dart';

class MobileHomeScreen extends ConsumerStatefulWidget {
  const MobileHomeScreen({
    required this.preferences,
    required this.composer,
    required this.onOpenPairing,
    required this.onConnect,
    required this.onDisconnect,
    required this.onConfirm,
    required this.onReopen,
    required this.onSend,
    required this.onNextDraft,
    required this.onStartVoice,
    required this.onStopVoice,
    required this.onCancelVoice,
    required this.onDiscardVoice,
    required this.onOpenVoiceSettings,
    super.key,
  });

  final MobileVisualPreferences preferences;
  final TextEditingController composer;
  final VoidCallback onOpenPairing;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final VoidCallback onConfirm;
  final VoidCallback onReopen;
  final Future<void> Function() onSend;
  final VoidCallback onNextDraft;
  final Future<void> Function() onStartVoice;
  final Future<void> Function() onStopVoice;
  final Future<void> Function() onCancelVoice;
  final Future<void> Function() onDiscardVoice;
  final Future<void> Function(BuildContext) onOpenVoiceSettings;

  @override
  ConsumerState<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends ConsumerState<MobileHomeScreen> {
  var _textMode = false;

  void _toggleTextMode() {
    final voice = ref.read(voiceSessionProvider);
    if (voice.phase == VoiceInputPhase.recording ||
        voice.phase == VoiceInputPhase.transcribing) {
      return;
    }
    setState(() => _textMode = !_textMode);
  }

  Future<void> _startVoice() async {
    if (!ref.read(voiceSessionProvider).canStart) return;
    await widget.onStartVoice();
  }

  Future<void> _stopVoice() async {
    if (!ref.read(voiceSessionProvider).canStop) return;
    await widget.onStopVoice();
    if (mounted) setState(() => _textMode = true);
  }

  Future<void> _finishVoicePress() async {
    final voice = ref.read(voiceSessionProvider);
    if (voice.canStop) {
      await _stopVoice();
    } else if (voice.canCancel) {
      await widget.onCancelVoice();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(clientSessionProvider);
    final source = ref.watch(chatSourceProvider);
    final direct = ref.watch(directChatProvider);
    final workspace = ref.watch(gatewayWorkspaceProvider);
    final voice = ref.watch(voiceSessionProvider);
    final speech = ref.watch(speechPlaybackProvider);
    final speechEnabled = ref.watch(speechEnabledProvider);
    final workspaceController = ref.read(gatewayWorkspaceProvider.notifier);
    final ownsLease = workspace.ownsSelectedLease(
      workspaceController.deviceId,
      DateTime.now(),
    );
    final snapshot = resolveSignalCore(
      workspace: workspace,
      session: session,
      voice: voice,
      speech: speech,
    );
    final voiceFocused =
        voice.phase == VoiceInputPhase.requestingPermission ||
        voice.phase == VoiceInputPhase.recording ||
        voice.phase == VoiceInputPhase.transcribing;
    final showText =
        _textMode ||
        voice.phase == VoiceInputPhase.awaitingConfirmation ||
        session.draftPhase == DraftPhase.confirmed ||
        snapshot.state == SignalCoreState.approval ||
        snapshot.state == SignalCoreState.uncertain;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.space,
          control: true,
          shift: true,
        ): () =>
            _toggleVoice(),
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MobileStarfieldPainter(
                  signal: context.visualTokens.signal,
                  signalStrong: context.visualTokens.signalStrong,
                  signalWarm: context.visualTokens.signalWarm,
                  customBackgroundPreview:
                      widget.preferences.customBackgroundPreview,
                  light: Theme.of(context).brightness == Brightness.light,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _MobileTopBar(
                    visible: showText,
                    phase: session.connectionPhase,
                    message: workspace.safeErrorMessage,
                    onConnection: switch (session.connectionPhase) {
                      GatewayConnectionPhase.unpaired => widget.onOpenPairing,
                      GatewayConnectionPhase.connected => () => unawaited(
                        widget.onDisconnect(),
                      ),
                      GatewayConnectionPhase.connecting ||
                      GatewayConnectionPhase.reconnecting => null,
                      GatewayConnectionPhase.offline ||
                      GatewayConnectionPhase.failed => () => unawaited(
                        widget.onConnect(),
                      ),
                    },
                    onSettings: () => showMobileVisualSettingsSheet(
                      context,
                      preferences: widget.preferences,
                      onOpenVoiceSettings: widget.onOpenVoiceSettings,
                    ),
                  ),
                  Expanded(
                    child: showText
                        ? _MobileTextMode(
                            source: source,
                            direct: direct,
                            workspace: workspace,
                            session: session,
                            voice: voice,
                            snapshot: snapshot,
                            speechEnabled: speechEnabled,
                            ownsLease: ownsLease,
                            composer: widget.composer,
                            onTapCore: _toggleTextMode,
                            onLongPressStart: _startVoice,
                            onLongPressEnd: _finishVoicePress,
                            onConfirm: widget.onConfirm,
                            onReopen: widget.onReopen,
                            onSend: widget.onSend,
                            onNextDraft: widget.onNextDraft,
                            onStopVoice: _stopVoice,
                            onCancelVoice: widget.onCancelVoice,
                            onDiscardVoice: widget.onDiscardVoice,
                            onChanged: ref
                                .read(clientSessionProvider.notifier)
                                .editDraft,
                          )
                        : voiceFocused
                        ? _MobileVoiceStage(
                            snapshot: snapshot,
                            voice: voice,
                            onTap: _toggleTextMode,
                            onLongPressStart: _startVoice,
                            onLongPressEnd: _finishVoicePress,
                          )
                        : _MobileIdleStage(
                            snapshot: snapshot,
                            onTap: _toggleTextMode,
                            onLongPressStart: _startVoice,
                            onLongPressEnd: _finishVoicePress,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVoice() async {
    final voice = ref.read(voiceSessionProvider);
    if (voice.canStop) {
      await _stopVoice();
    } else if (voice.canStart) {
      await _startVoice();
    }
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    required this.visible,
    required this.phase,
    required this.message,
    required this.onConnection,
    required this.onSettings,
  });

  final bool visible;
  final GatewayConnectionPhase phase;
  final String? message;
  final VoidCallback? onConnection;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      maintainState: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 12, 36, 4),
        child: Row(
          children: [
            _MobileConnectionIndicator(
              phase: phase,
              message: message,
              onPressed: onConnection,
            ),
            const Spacer(),
            IconButton(
              tooltip: '打开设置',
              onPressed: onSettings,
              style: IconButton.styleFrom(
                minimumSize: const Size(28, 28),
                maximumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              iconSize: 18,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileConnectionIndicator extends StatefulWidget {
  const _MobileConnectionIndicator({
    required this.phase,
    required this.message,
    required this.onPressed,
  });

  final GatewayConnectionPhase phase;
  final String? message;
  final VoidCallback? onPressed;

  @override
  State<_MobileConnectionIndicator> createState() =>
      _MobileConnectionIndicatorState();
}

class _MobileConnectionIndicatorState
    extends State<_MobileConnectionIndicator> {
  Timer? _connectedMessageTimer;
  var _showConnectedMessage = false;

  @override
  void didUpdateWidget(covariant _MobileConnectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _connectedMessageTimer?.cancel();
      _connectedMessageTimer = null;
      if (widget.phase == GatewayConnectionPhase.connected &&
          oldWidget.phase != GatewayConnectionPhase.connected) {
        _showConnectedMessage = true;
        _connectedMessageTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() => _showConnectedMessage = false);
          _connectedMessageTimer = null;
        });
      } else {
        _showConnectedMessage = false;
      }
    }
  }

  @override
  void dispose() {
    _connectedMessageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final connected = widget.phase == GatewayConnectionPhase.connected;
    final connecting =
        widget.phase == GatewayConnectionPhase.connecting ||
        widget.phase == GatewayConnectionPhase.reconnecting;
    final label = switch (widget.phase) {
      GatewayConnectionPhase.unpaired => '未配对',
      GatewayConnectionPhase.connecting => '连接中',
      GatewayConnectionPhase.connected => '已连接',
      GatewayConnectionPhase.reconnecting => '重连中',
      GatewayConnectionPhase.offline => '未连接',
      GatewayConnectionPhase.failed => '连接失败',
    };
    final color = connected
        ? const Color(0xFF55E58C)
        : connecting
        ? const Color(0xFFF4C95D)
        : tokens.danger;
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 10),
        ],
      ),
    );
    final shownMessage = widget.message?.trim().isNotEmpty == true
        ? widget.message!.trim()
        : label;
    final showMessage = !connected || _showConnectedMessage;
    return Semantics(
      button: widget.onPressed != null,
      label: '连接状态：$label',
      child: showMessage
          ? Container(
              constraints: const BoxConstraints(maxWidth: 230, minHeight: 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: tokens.panel.withValues(alpha: 0.82),
                border: Border.all(
                  color: tokens.signal.withValues(alpha: 0.42),
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: tokens.shadow,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: tokens.signal.withValues(alpha: 0.12),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(999),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    dot,
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        shownMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : connected
          ? IconButton(
              tooltip: '连接状态：$label',
              onPressed: widget.onPressed,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              icon: dot,
            )
          : const SizedBox.shrink(),
    );
  }
}

class _MobileIdleStage extends StatelessWidget {
  const _MobileIdleStage({
    required this.snapshot,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final SignalCoreSnapshot snapshot;
  final VoidCallback onTap;
  final Future<void> Function() onLongPressStart;
  final Future<void> Function() onLongPressEnd;

  @override
  Widget build(BuildContext context) => Center(
    child: _MobileCoreGesture(
      snapshot: snapshot,
      dimension: math.min(MediaQuery.sizeOf(context).width * 0.92, 370),
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
    ),
  );
}

class _MobileVoiceStage extends StatelessWidget {
  const _MobileVoiceStage({
    required this.snapshot,
    required this.voice,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final SignalCoreSnapshot snapshot;
  final VoiceSessionState voice;
  final VoidCallback onTap;
  final Future<void> Function() onLongPressStart;
  final Future<void> Function() onLongPressEnd;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Center(
          child: OverflowBox(
            alignment: Alignment.center,
            maxWidth: math.min(MediaQuery.sizeOf(context).width * 1.12, 460),
            maxHeight: math.min(MediaQuery.sizeOf(context).width * 1.12, 460),
            child: _MobileCoreGesture(
              snapshot: snapshot,
              dimension: math.min(MediaQuery.sizeOf(context).width * 1.12, 460),
              onTap: onTap,
              onLongPressStart: onLongPressStart,
              onLongPressEnd: onLongPressEnd,
            ),
          ),
        ),
      ),
      if (voice.phase != VoiceInputPhase.recording)
        Semantics(
          liveRegion: true,
          label: voice.provisionalTranscript.isEmpty
              ? snapshot.label
              : '实时转写：${voice.provisionalTranscript}',
          child: const SizedBox(height: 1),
        ),
    ],
  );
}

class _MobileTextMode extends StatelessWidget {
  const _MobileTextMode({
    required this.source,
    required this.direct,
    required this.workspace,
    required this.session,
    required this.voice,
    required this.snapshot,
    required this.speechEnabled,
    required this.ownsLease,
    required this.composer,
    required this.onTapCore,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onConfirm,
    required this.onReopen,
    required this.onSend,
    required this.onNextDraft,
    required this.onStopVoice,
    required this.onCancelVoice,
    required this.onDiscardVoice,
    required this.onChanged,
  });

  final ChatSource source;
  final DirectChatState direct;
  final GatewayWorkspaceState workspace;
  final ClientSessionState session;
  final VoiceSessionState voice;
  final SignalCoreSnapshot snapshot;
  final bool speechEnabled;
  final bool ownsLease;
  final TextEditingController composer;
  final VoidCallback onTapCore;
  final Future<void> Function() onLongPressStart;
  final Future<void> Function() onLongPressEnd;
  final VoidCallback onConfirm;
  final VoidCallback onReopen;
  final Future<void> Function() onSend;
  final VoidCallback onNextDraft;
  final Future<void> Function() onStopVoice;
  final Future<void> Function() onCancelVoice;
  final Future<void> Function() onDiscardVoice;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final workspaceController = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(gatewayWorkspaceProvider.notifier);
    final content = source == ChatSource.directLlm
        ? DirectChatView(
            state: direct,
            onCancel: ProviderScope.containerOf(
              context,
              listen: false,
            ).read(directChatProvider.notifier).cancel,
            onSpeak: ProviderScope.containerOf(
              context,
              listen: false,
            ).read(directChatProvider.notifier).speakMessage,
            speechEnabled: speechEnabled,
            mobileVisual: true,
          )
        : workspace.selectedConversation == null
        ? const _MobileEmptyText()
        : ConversationView(
            workspace: workspace,
            mobileVisual: true,
            showSignalCore: false,
            ownsLease: ownsLease,
            onAcquire: () => workspaceController.acquireSelectedControl(
              explicitTakeover: workspace.selectedLease != null,
            ),
            onApproval: workspaceController.resolveApproval,
            onClarification: workspaceController.resolveClarification,
            onInterrupt: workspaceController.interrupt,
          );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: snapshot.state != SignalCoreState.idle,
      label: snapshot.label,
      value: snapshot.state.name,
      onTap: onTapCore,
      onLongPress: () => unawaited(onLongPressStart()),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: content),
          Positioned(
            left: 0,
            right: 0,
            bottom: -250,
            height: math.min(MediaQuery.sizeOf(context).width * 1.12, 460),
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxWidth: math.min(MediaQuery.sizeOf(context).width * 1.12, 460),
              maxHeight: math.min(MediaQuery.sizeOf(context).width * 1.12, 460),
              child: ExcludeSemantics(
                child: _MobileCoreGesture(
                  snapshot: snapshot,
                  dimension: math.min(
                    MediaQuery.sizeOf(context).width * 1.12,
                    460,
                  ),
                  onTap: onTapCore,
                  onLongPressStart: onLongPressStart,
                  onLongPressEnd: onLongPressEnd,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _MobileDraftComposer(
              textController: composer,
              session: session,
              voice: voice,
              sendEnabled: source == ChatSource.directLlm
                  ? direct.isConfigured &&
                        direct.phase != DirectChatPhase.sending
                  : ownsLease,
              requiresGatewayConnection: source != ChatSource.directLlm,
              sendLabel: source == ChatSource.directLlm ? '发送' : '交给 Hermes',
              onChanged: onChanged,
              onConfirm: onConfirm,
              onReopen: onReopen,
              onSend: onSend,
              onNextDraft: onNextDraft,
              onStopVoice: onStopVoice,
              onCancelVoice: onCancelVoice,
              onDiscardVoice: onDiscardVoice,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDraftComposer extends StatelessWidget {
  const _MobileDraftComposer({
    required this.textController,
    required this.session,
    required this.voice,
    required this.sendEnabled,
    required this.requiresGatewayConnection,
    required this.sendLabel,
    required this.onChanged,
    required this.onConfirm,
    required this.onReopen,
    required this.onSend,
    required this.onNextDraft,
    required this.onStopVoice,
    required this.onCancelVoice,
    required this.onDiscardVoice,
  });

  final TextEditingController textController;
  final ClientSessionState session;
  final VoiceSessionState voice;
  final bool sendEnabled;
  final bool requiresGatewayConnection;
  final String sendLabel;
  final ValueChanged<String> onChanged;
  final VoidCallback onConfirm;
  final VoidCallback onReopen;
  final Future<void> Function() onSend;
  final VoidCallback onNextDraft;
  final Future<void> Function() onStopVoice;
  final Future<void> Function() onCancelVoice;
  final Future<void> Function() onDiscardVoice;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final confirmed = session.draftPhase == DraftPhase.confirmed;
    final accepted = session.draftPhase == DraftPhase.accepted;
    final uncertain = session.draftPhase == DraftPhase.uncertain;
    final canSend =
        confirmed &&
        (requiresGatewayConnection ? session.canSubmit : true) &&
        sendEnabled;
    final actions = <Widget>[];
    if (voice.phase == VoiceInputPhase.recording) {
      actions.add(
        _MobileActionButton(
          label: '停止录音并转写',
          icon: Icons.stop_rounded,
          onPressed: () => unawaited(onStopVoice()),
          filled: true,
        ),
      );
      actions.add(
        _MobileActionButton(
          label: '取消录音',
          icon: Icons.close,
          onPressed: () => unawaited(onCancelVoice()),
        ),
      );
    } else if (voice.canCancel) {
      actions.add(
        _MobileActionButton(
          label: '取消语音输入',
          icon: Icons.close,
          onPressed: () => unawaited(onCancelVoice()),
        ),
      );
    } else if (voice.phase == VoiceInputPhase.awaitingConfirmation) {
      actions.add(
        _MobileActionButton(
          label: '丢弃语音草稿',
          icon: Icons.delete_outline,
          onPressed: () => unawaited(onDiscardVoice()),
        ),
      );
    }
    if (accepted) {
      actions.add(
        _MobileActionButton(
          label: '开始新草稿',
          icon: Icons.add,
          onPressed: onNextDraft,
          filled: true,
        ),
      );
    } else if (confirmed) {
      actions.add(
        _MobileActionButton(
          label: '重新编辑草稿',
          icon: Icons.edit_outlined,
          onPressed: onReopen,
        ),
      );
    } else if (session.canConfirmDraft) {
      actions.add(
        _MobileActionButton(
          label: '确认草稿',
          icon: Icons.check,
          onPressed: onConfirm,
          filled: true,
        ),
      );
    }
    if (confirmed || uncertain) {
      actions.add(
        _MobileActionButton(
          label: uncertain ? '结果不确定，未重复发送' : sendLabel,
          icon: uncertain ? Icons.warning_amber_rounded : Icons.arrow_upward,
          onPressed: canSend ? () => unawaited(onSend()) : null,
          filled: canSend,
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: 0.86,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.panel.withValues(alpha: 0.42),
                border: Border.all(
                  color: tokens.structureLine.withValues(alpha: 0.52),
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: tokens.shadow.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: textController,
                      enabled: session.canEditDraft && !confirmed,
                      minLines: 1,
                      maxLines: 2,
                      onChanged: onChanged,
                      style: TextStyle(
                        color: tokens.textPrimary.withValues(alpha: 0.82),
                        fontSize: 16,
                        height: 1.3,
                      ),
                      decoration: InputDecoration(
                        hintText: '编辑要说的话',
                        hintStyle: TextStyle(
                          color: tokens.textMuted.withValues(alpha: 0.78),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                    if (actions.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(spacing: 2, children: actions),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileActionButton extends StatelessWidget {
  const _MobileActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: IconButton(
      tooltip: label,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: filled
            ? context.visualTokens.signal.withValues(alpha: 0.72)
            : Colors.transparent,
        foregroundColor: filled
            ? context.visualTokens.ink
            : context.visualTokens.textMuted,
        disabledForegroundColor: context.visualTokens.textMuted.withValues(
          alpha: 0.55,
        ),
        minimumSize: const Size(30, 30),
        maximumSize: const Size(30, 30),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      iconSize: 18,
      icon: Icon(icon),
    ),
  );
}

class _MobileCoreGesture extends StatefulWidget {
  const _MobileCoreGesture({
    required this.snapshot,
    required this.dimension,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final SignalCoreSnapshot snapshot;
  final double dimension;
  final VoidCallback onTap;
  final Future<void> Function() onLongPressStart;
  final Future<void> Function() onLongPressEnd;

  @override
  State<_MobileCoreGesture> createState() => _MobileCoreGestureState();
}

class _MobileCoreGestureState extends State<_MobileCoreGesture> {
  static const _longPressDuration = Duration(milliseconds: 540);

  Timer? _pressTimer;
  int? _pointer;
  var _longPressTriggered = false;
  var _ignoreNextTap = false;
  var _pressed = false;

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed || !mounted) return;
    setState(() => _pressed = pressed);
  }

  void _clearPressTimer() {
    _pressTimer?.cancel();
    _pressTimer = null;
  }

  bool _acceptsPointer(PointerDownEvent event) =>
      event.kind != PointerDeviceKind.mouse || event.buttons == kPrimaryButton;

  void _onPointerDown(PointerDownEvent event) {
    if (!_acceptsPointer(event) || _pointer != null) return;
    _clearPressTimer();
    _pointer = event.pointer;
    _longPressTriggered = false;
    _ignoreNextTap = false;
    _setPressed(true);
    _pressTimer = Timer(_longPressDuration, () {
      if (!mounted || _pointer != event.pointer || _longPressTriggered) return;
      _pressTimer = null;
      _longPressTriggered = true;
      _ignoreNextTap = true;
      unawaited(widget.onLongPressStart());
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _clearPressTimer();
    final longPress = _longPressTriggered;
    final suppressTap = _ignoreNextTap;
    _pointer = null;
    _longPressTriggered = false;
    _ignoreNextTap = false;
    _setPressed(false);
    if (longPress) {
      unawaited(widget.onLongPressEnd());
    } else if (!suppressTap) {
      widget.onTap();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _clearPressTimer();
    final longPress = _longPressTriggered;
    _pointer = null;
    _longPressTriggered = false;
    _ignoreNextTap = false;
    _setPressed(false);
    if (longPress) unawaited(widget.onLongPressEnd());
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${widget.snapshot.label}; tap for text, long-press for voice input',
    onTap: widget.onTap,
    onLongPress: () => unawaited(widget.onLongPressStart()),
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        child: SignalCoreView(
          snapshot: widget.snapshot,
          dimension: widget.dimension,
          mobileVisual: true,
        ),
      ),
    ),
  );
}

class _MobileEmptyText extends StatelessWidget {
  const _MobileEmptyText();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      child: const MobileConversationBubble(
        text: '我已准备好，随时可以开始。',
        quiet: true,
        centered: true,
      ),
    ),
  );
}

class _MobileStarfieldPainter extends CustomPainter {
  const _MobileStarfieldPainter({
    required this.signal,
    required this.signalStrong,
    required this.signalWarm,
    required this.customBackgroundPreview,
    required this.light,
  });

  final Color signal;
  final Color signalStrong;
  final Color signalWarm;
  final bool customBackgroundPreview;
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        light
            ? [const Color(0xFFF7FBFF), const Color(0xFFEDF4FA)]
            : const [Color(0xFF050812), Color(0xFF070A10), Color(0xFF03050A)],
        light ? null : const [0, 0.56, 1],
      );
    canvas.drawRect(rect, background);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.74),
          size.width * 0.38,
          [
            signalStrong.withValues(alpha: light ? 0.08 : 0.15),
            signalStrong.withValues(alpha: 0),
          ],
        ),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.12, size.height * 0.16),
          size.width * 0.28,
          [
            signalWarm.withValues(alpha: light ? 0.06 : 0.08),
            signalWarm.withValues(alpha: 0),
          ],
        ),
    );
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height * 0.52),
        size.width * 0.7,
        [
          signalStrong.withValues(alpha: light ? 0.08 : 0.14),
          signal.withValues(alpha: 0),
        ],
      );
    canvas.drawRect(rect, glow);
    if (customBackgroundPreview) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width * 0.78, size.height * 0.18),
            size.width * 0.78,
            [
              signalWarm.withValues(alpha: light ? 0.12 : 0.1),
              signalWarm.withValues(alpha: 0),
            ],
          ),
      );
    }
    final stars = <(double, double, double, Color)>[
      (0.12, 0.16, 1.0, Colors.white),
      (0.82, 0.11, 1.0, signal),
      (0.66, 0.27, 0.8, Colors.white),
      (0.24, 0.42, 1.0, signalWarm),
      (0.91, 0.52, 0.8, Colors.white),
      (0.42, 0.67, 0.8, signal),
      (0.09, 0.82, 0.8, Colors.white),
      (0.74, 0.88, 1.0, signalWarm),
      (0.31, 0.08, 0.55, Colors.white),
      (0.54, 0.15, 0.45, signal),
      (0.96, 0.23, 0.5, Colors.white),
      (0.16, 0.31, 0.46, signalWarm),
      (0.77, 0.36, 0.5, Colors.white),
      (0.35, 0.52, 0.42, signal),
      (0.58, 0.61, 0.48, Colors.white),
      (0.88, 0.72, 0.42, signalWarm),
      (0.27, 0.76, 0.44, Colors.white),
      (0.52, 0.93, 0.48, signal),
    ];
    for (final (x, y, radius, color) in stars) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * y),
        radius,
        Paint()..color = color.withValues(alpha: light ? 0.34 : 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MobileStarfieldPainter oldDelegate) =>
      oldDelegate.signal != signal ||
      oldDelegate.signalStrong != signalStrong ||
      oldDelegate.signalWarm != signalWarm ||
      oldDelegate.customBackgroundPreview != customBackgroundPreview ||
      oldDelegate.light != light;
}
