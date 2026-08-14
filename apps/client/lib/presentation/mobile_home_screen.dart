import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/chat_source_controller.dart';
import '../application/client_session_controller.dart';
import '../application/device_pairing_controller.dart';
import '../application/direct_chat_controller.dart';
import '../application/gateway_workspace_controller.dart';
import '../application/speech_playback_controller.dart';
import '../application/voice_session_controller.dart';
import '../domain/client_session.dart';
import '../domain/device_pairing.dart';
import '../domain/direct_chat.dart';
import '../domain/gateway_workspace.dart';
import '../domain/signal_core.dart';
import '../domain/voice.dart';
import 'conversation_view.dart';
import 'design/agent_talk_theme.dart';
import 'direct_chat_view.dart';
import 'message_composer.dart';
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(clientSessionProvider);
    final pairing = ref.watch(devicePairingProvider);
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
                  structureLine: context.visualTokens.structureLine,
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
                    phase: session.connectionPhase,
                    onSettings: () => showMobileVisualSettingsSheet(
                      context,
                      preferences: widget.preferences,
                      onOpenVoiceSettings: widget.onOpenVoiceSettings,
                    ),
                  ),
                  Expanded(
                    child: voiceFocused
                        ? _MobileVoiceStage(
                            snapshot: snapshot,
                            voice: voice,
                            onTap: _toggleTextMode,
                            onLongPressStart: _startVoice,
                            onLongPressEnd: _stopVoice,
                          )
                        : showText
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
                            onLongPressEnd: _stopVoice,
                            onConfirm: widget.onConfirm,
                            onReopen: widget.onReopen,
                            onSend: widget.onSend,
                            onNextDraft: widget.onNextDraft,
                            onStartVoice: _startVoice,
                            onStopVoice: _stopVoice,
                            onCancelVoice: widget.onCancelVoice,
                            onDiscardVoice: widget.onDiscardVoice,
                            onChanged: ref
                                .read(clientSessionProvider.notifier)
                                .editDraft,
                            onOpenPairing: widget.onOpenPairing,
                            onConnect: widget.onConnect,
                            onDisconnect: widget.onDisconnect,
                          )
                        : _MobileIdleStage(
                            snapshot: snapshot,
                            onTap: _toggleTextMode,
                            onLongPressStart: _startVoice,
                            onLongPressEnd: _stopVoice,
                            pairing: pairing,
                            onOpenPairing: widget.onOpenPairing,
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
  const _MobileTopBar({required this.phase, required this.onSettings});

  final GatewayConnectionPhase phase;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
    child: Row(
      children: [
        _MobileConnectionIndicator(phase: phase),
        const Spacer(),
        IconButton(
          tooltip: 'Open visual settings',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
  );
}

class _MobileConnectionIndicator extends StatelessWidget {
  const _MobileConnectionIndicator({required this.phase});

  final GatewayConnectionPhase phase;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final connected = phase == GatewayConnectionPhase.connected;
    final connecting =
        phase == GatewayConnectionPhase.connecting ||
        phase == GatewayConnectionPhase.reconnecting;
    final label = switch (phase) {
      GatewayConnectionPhase.unpaired => 'Unpaired',
      GatewayConnectionPhase.connecting => 'Connecting',
      GatewayConnectionPhase.connected => 'Connected',
      GatewayConnectionPhase.reconnecting => 'Reconnecting',
      GatewayConnectionPhase.offline => 'Offline',
      GatewayConnectionPhase.failed => 'Connection failed',
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
    return Semantics(
      label: 'Connection: $label',
      child: connected
          ? Padding(padding: const EdgeInsets.all(12), child: dot)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: tokens.panel,
                border: Border.all(color: tokens.structureLineStrong),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: tokens.shadow, blurRadius: 18)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [dot, const SizedBox(width: 8), Text(label)],
              ),
            ),
    );
  }
}

class _MobileIdleStage extends StatelessWidget {
  const _MobileIdleStage({
    required this.snapshot,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.pairing,
    required this.onOpenPairing,
  });

  final SignalCoreSnapshot snapshot;
  final VoidCallback onTap;
  final Future<void> Function() onLongPressStart;
  final Future<void> Function() onLongPressEnd;
  final PairingState pairing;
  final VoidCallback onOpenPairing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        const Spacer(),
        _MobileCoreGesture(
          snapshot: snapshot,
          dimension: math.min(constraints.maxWidth * 0.76, 292),
          onTap: onTap,
          onLongPressStart: onLongPressStart,
          onLongPressEnd: onLongPressEnd,
        ),
        const Spacer(),
        if (pairing.phase != PairingPhase.paired)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
            child: TextButton.icon(
              onPressed: onOpenPairing,
              icon: const Icon(Icons.link_outlined),
              label: const Text('Pair Gateway to start'),
            ),
          )
        else
          const SizedBox(height: 18),
      ],
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
      const Spacer(),
      _MobileCoreGesture(
        snapshot: snapshot,
        dimension: math.min(MediaQuery.sizeOf(context).width * 0.84, 330),
        onTap: onTap,
        onLongPressStart: onLongPressStart,
        onLongPressEnd: onLongPressEnd,
      ),
      const SizedBox(height: 20),
      Semantics(
        liveRegion: true,
        label: voice.provisionalTranscript.isEmpty
            ? 'Recording, input level ${voice.audioLevel.toStringAsFixed(2)}'
            : 'Live transcript: ${voice.provisionalTranscript}',
        child: Text(
          voice.provisionalTranscript.isEmpty
              ? 'Recording · release to stop'
              : voice.provisionalTranscript,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.visualTokens.textMuted),
        ),
      ),
      const Spacer(),
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
    required this.onStartVoice,
    required this.onStopVoice,
    required this.onCancelVoice,
    required this.onDiscardVoice,
    required this.onChanged,
    required this.onOpenPairing,
    required this.onConnect,
    required this.onDisconnect,
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
  final Future<void> Function() onStartVoice;
  final Future<void> Function() onStopVoice;
  final Future<void> Function() onCancelVoice;
  final Future<void> Function() onDiscardVoice;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenPairing;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;

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
          )
        : workspace.selectedConversation == null
        ? const _MobileEmptyText()
        : ConversationView(
            workspace: workspace,
            showSignalCore: false,
            ownsLease: ownsLease,
            onAcquire: () => workspaceController.acquireSelectedControl(
              explicitTakeover: workspace.selectedLease != null,
            ),
            onApproval: workspaceController.resolveApproval,
            onClarification: workspaceController.resolveClarification,
            onInterrupt: workspaceController.interrupt,
          );
    return Column(
      children: [
        _MobileTargetStrip(
          source: source,
          workspace: workspace,
          session: session,
          onOpenPairing: onOpenPairing,
          onConnect: onConnect,
          onDisconnect: onDisconnect,
        ),
        Expanded(child: content),
        SizedBox(
          height: 104,
          child: ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _MobileCoreGesture(
                snapshot: snapshot,
                dimension: math.min(
                  MediaQuery.sizeOf(context).width * 0.88,
                  360,
                ),
                onTap: onTapCore,
                onLongPressStart: onLongPressStart,
                onLongPressEnd: onLongPressEnd,
              ),
            ),
          ),
        ),
        MessageComposer(
          textController: composer,
          session: session,
          voice: voice,
          onChanged: onChanged,
          onConfirm: onConfirm,
          onReopen: onReopen,
          onSend: onSend,
          onNextDraft: onNextDraft,
          sendEnabled: source == ChatSource.directLlm
              ? direct.isConfigured && direct.phase != DirectChatPhase.sending
              : ownsLease,
          requiresGatewayConnection: source != ChatSource.directLlm,
          sendLabel: source == ChatSource.directLlm
              ? 'Send'
              : 'Handoff to Hermes',
          onStartVoice: onStartVoice,
          onStopVoice: onStopVoice,
          onCancelVoice: onCancelVoice,
          onDiscardVoice: onDiscardVoice,
        ),
      ],
    );
  }
}

class _MobileCoreGesture extends StatelessWidget {
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${snapshot.label}; tap for text, long-press for voice input',
    onTap: onTap,
    onLongPress: onLongPressStart,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: (_) => onLongPressStart(),
      onLongPressEnd: (_) => onLongPressEnd(),
      child: SignalCoreView(
        snapshot: snapshot,
        dimension: dimension,
        mobileVisual: true,
      ),
    ),
  );
}

class _MobileTargetStrip extends StatelessWidget {
  const _MobileTargetStrip({
    required this.source,
    required this.workspace,
    required this.session,
    required this.onOpenPairing,
    required this.onConnect,
    required this.onDisconnect,
  });

  final ChatSource source;
  final GatewayWorkspaceState workspace;
  final ClientSessionState session;
  final VoidCallback onOpenPairing;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final isConnected =
        session.connectionPhase == GatewayConnectionPhase.connected;
    final selected = workspace.selectedConversation;
    final title = source == ChatSource.directLlm
        ? 'Direct LLM'
        : selected?.title ?? 'Hermes workspace';
    final subtitle = source == ChatSource.directLlm
        ? 'Pure chat · history saved locally'
        : selected == null
        ? 'Choose a conversation to send'
        : selected.agentId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      child: Row(
        children: [
          Icon(
            source == ChatSource.directLlm
                ? Icons.forum_outlined
                : Icons.hub_outlined,
            color: tokens.signal,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (source == ChatSource.hermes)
            IconButton(
              tooltip: isConnected ? 'Disconnect Gateway' : 'Connect Gateway',
              onPressed:
                  workspace.connectionPhase == GatewayConnectionPhase.unpaired
                  ? onOpenPairing
                  : isConnected
                  ? onDisconnect
                  : onConnect,
              icon: Icon(isConnected ? Icons.link_off : Icons.link_outlined),
            ),
        ],
      ),
    );
  }
}

class _MobileEmptyText extends StatelessWidget {
  const _MobileEmptyText();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        'Choose a conversation, or edit text below.\nComplete replies remain available as text.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.visualTokens.textMuted),
      ),
    ),
  );
}

class _MobileStarfieldPainter extends CustomPainter {
  const _MobileStarfieldPainter({
    required this.signal,
    required this.signalStrong,
    required this.signalWarm,
    required this.structureLine,
    required this.customBackgroundPreview,
    required this.light,
  });

  final Color signal;
  final Color signalStrong;
  final Color signalWarm;
  final Color structureLine;
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
            : [const Color(0xFF050812), const Color(0xFF070A10)],
      );
    canvas.drawRect(rect, background);
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
    final axis = Paint()
      ..color = structureLine.withValues(alpha: light ? 0.45 : 0.6)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      axis,
    );
    final stars = <(double, double, double, Color)>[
      (0.12, 0.16, 1.0, Colors.white),
      (0.82, 0.11, 1.0, signal),
      (0.66, 0.27, 0.8, Colors.white),
      (0.24, 0.42, 1.0, signalWarm),
      (0.91, 0.52, 0.8, Colors.white),
      (0.42, 0.67, 0.8, signal),
      (0.09, 0.82, 0.8, Colors.white),
      (0.74, 0.88, 1.0, signalWarm),
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
      oldDelegate.structureLine != structureLine ||
      oldDelegate.customBackgroundPreview != customBackgroundPreview ||
      oldDelegate.light != light;
}
