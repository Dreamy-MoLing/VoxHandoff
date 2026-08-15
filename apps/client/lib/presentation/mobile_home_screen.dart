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
import 'signal_core_view.dart';

class NativeMobileHomeScreen extends ConsumerStatefulWidget {
  const NativeMobileHomeScreen({
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
  ConsumerState<NativeMobileHomeScreen> createState() =>
      _NativeMobileHomeScreenState();
}

class _NativeMobileHomeScreenState
    extends ConsumerState<NativeMobileHomeScreen> {
  var _contentVisible = false;
  var _page = _MobilePage.home;

  void _toggleContent() {
    final voice = ref.read(voiceSessionProvider);
    if (voice.phase == VoiceInputPhase.recording ||
        voice.phase == VoiceInputPhase.transcribing) {
      return;
    }
    setState(() => _contentVisible = !_contentVisible);
  }

  Future<void> _startVoice() async {
    if (!ref.read(voiceSessionProvider).canStart) return;
    await widget.onStartVoice();
  }

  Future<void> _stopVoice() async {
    if (!ref.read(voiceSessionProvider).canStop) return;
    await widget.onStopVoice();
    if (mounted) setState(() => _contentVisible = true);
  }

  void _openPage(_MobilePage page) => setState(() => _page = page);

  void _returnHome() => setState(() => _page = _MobilePage.home);

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
        _contentVisible ||
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
              child: _MobileStarfield(
                signal: context.visualTokens.signal,
                signalStrong: context.visualTokens.signalStrong,
                signalWarm: context.visualTokens.signalWarm,
                structureLine: context.visualTokens.structureLine,
                customBackgroundPreview:
                    widget.preferences.customBackgroundPreview,
                light: Theme.of(context).brightness == Brightness.light,
              ),
            ),
            SafeArea(
              child: switch (_page) {
                _MobilePage.home => Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
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
                              onTapCore: _toggleContent,
                              onLongPressStart: _startVoice,
                              onLongPressEnd: _stopVoice,
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
                              onTap: _toggleContent,
                              onLongPressStart: _startVoice,
                              onLongPressEnd: _stopVoice,
                            )
                          : _MobileIdleStage(
                              snapshot: snapshot,
                              onTap: _toggleContent,
                              onLongPressStart: _startVoice,
                              onLongPressEnd: _stopVoice,
                            ),
                    ),
                    _MobileControlDeck(
                      visible: showText,
                      phase: session.connectionPhase,
                      message: workspace.safeErrorMessage,
                      onConnection: () => _openPage(_MobilePage.connection),
                      onSettings: () => _openPage(_MobilePage.settings),
                    ),
                  ],
                ),
                _MobilePage.settings => _MobileVisualSettingsPage(
                  preferences: widget.preferences,
                  onBack: _returnHome,
                  onOpenVoiceSettings: widget.onOpenVoiceSettings,
                ),
                _MobilePage.connection => _MobileConnectionPage(
                  phase: session.connectionPhase,
                  onBack: _returnHome,
                  onPair: () {
                    _returnHome();
                    widget.onOpenPairing();
                  },
                  onConnect: () {
                    _returnHome();
                    unawaited(widget.onConnect());
                  },
                  onDisconnect: () {
                    _returnHome();
                    unawaited(widget.onDisconnect());
                  },
                ),
              },
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

enum _MobilePage { home, settings, connection }

class _MobileControlDeck extends StatelessWidget {
  const _MobileControlDeck({
    required this.visible,
    required this.phase,
    required this.message,
    required this.onConnection,
    required this.onSettings,
  });

  final bool visible;
  final GatewayConnectionPhase phase;
  final String? message;
  final VoidCallback onConnection;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOut,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 18,
            left: 18,
            child: _MobileConnectionButton(
              phase: phase,
              message: message,
              onPressed: onConnection,
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: _MobileSettingsButton(onPressed: onSettings),
          ),
        ],
      ),
    ),
  );
}

class _MobileConnectionButton extends StatelessWidget {
  const _MobileConnectionButton({
    required this.phase,
    required this.message,
    required this.onPressed,
  });

  final GatewayConnectionPhase phase;
  final String? message;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final connected = phase == GatewayConnectionPhase.connected;
    final connecting =
        phase == GatewayConnectionPhase.connecting ||
        phase == GatewayConnectionPhase.reconnecting;
    final label = switch (phase) {
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
    final accessibleLabel = message?.trim().isNotEmpty == true
        ? '$label：${message!.trim()}'
        : label;
    return Semantics(
      button: true,
      label: '连接状态：$accessibleLabel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: BoxConstraints(minWidth: connected ? 38 : 94),
            height: 38,
            padding: EdgeInsets.symmetric(horizontal: connected ? 8 : 12),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                tokens.panel.withValues(alpha: 0.92),
                tokens.ink,
              ),
              border: Border.all(color: tokens.signal.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: tokens.shadow, blurRadius: 20),
                BoxShadow(
                  color: tokens.signal.withValues(alpha: 0.08),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PrototypeConnectionGlyph(color: color),
                if (!connected) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrototypeConnectionGlyph extends StatelessWidget {
  const _PrototypeConnectionGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 22,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12),
            ],
          ),
        ),
        Container(width: 18, height: 1, color: color.withValues(alpha: 0.7)),
        RotatedBox(
          quarterTurns: 1,
          child: Container(
            width: 18,
            height: 1,
            color: color.withValues(alpha: 0.7),
          ),
        ),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ],
    ),
  );
}

class _MobileSettingsButton extends StatelessWidget {
  const _MobileSettingsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '打开设置页面',
    child: IconButton(
      tooltip: '打开设置',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      style: IconButton.styleFrom(
        side: BorderSide(
          color: context.visualTokens.signal.withValues(alpha: 0.5),
        ),
        shape: const CircleBorder(),
        backgroundColor: Color.alphaBlend(
          context.visualTokens.panel.withValues(alpha: 0.92),
          context.visualTokens.ink,
        ),
        foregroundColor: context.visualTokens.signal,
      ),
      icon: const Icon(Icons.settings_outlined, size: 19),
    ),
  );
}

class _MobileVisualSettingsPage extends StatelessWidget {
  const _MobileVisualSettingsPage({
    required this.preferences,
    required this.onBack,
    required this.onOpenVoiceSettings,
  });

  final MobileVisualPreferences preferences;
  final VoidCallback onBack;
  final Future<void> Function(BuildContext) onOpenVoiceSettings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: preferences,
    builder: (context, _) {
      final tokens = context.visualTokens;
      final light = preferences.theme == MobileVisualTheme.light;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 34, 0, 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: _MobileBackButton(onPressed: onBack),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 54),
                child: Column(
                  children: [
                    const _MobilePageHeading(
                      kind: _MobilePageHeadingKind.settings,
                    ),
                    const SizedBox(height: 34),
                    _MobileSettingsItem(
                      icon: const _ThemeGlyph(),
                      title: '主题',
                      value: light ? '亮色' : '深色',
                      trailing: IconButton(
                        tooltip: light ? '切换暗色主题视觉样式' : '切换亮色主题视觉样式',
                        onPressed: () => unawaited(
                          preferences.setTheme(
                            light
                                ? MobileVisualTheme.dark
                                : MobileVisualTheme.light,
                          ),
                        ),
                        style: IconButton.styleFrom(
                          side: BorderSide(
                            color: tokens.signal.withValues(alpha: 0.52),
                          ),
                          shape: const CircleBorder(),
                          foregroundColor: tokens.signal,
                        ),
                        icon: Icon(
                          light
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MobileSettingsItem(
                      icon: const _BackgroundGlyph(),
                      title: '背景',
                      value: preferences.customBackgroundPreview ? '自定义' : '星空',
                      trailing: IconButton(
                        tooltip: '导入自定义背景',
                        onPressed: () => preferences.setCustomBackgroundPreview(
                          !preferences.customBackgroundPreview,
                        ),
                        style: IconButton.styleFrom(
                          side: BorderSide(
                            color: tokens.signal.withValues(alpha: 0.52),
                          ),
                          shape: const CircleBorder(),
                          foregroundColor: tokens.signal,
                        ),
                        icon: const Icon(Icons.file_upload_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MobileSettingsItem(
                      icon: const _FontGlyph(),
                      title: '文字大小',
                      value: preferences.fontSize <= 19
                          ? '小号'
                          : preferences.fontSize >= 25
                          ? '大号'
                          : '标准',
                      trailing: SizedBox(
                        width: 132,
                        child: Slider(
                          min: 18,
                          max: 28,
                          divisions: 10,
                          value: preferences.fontSize,
                          label: preferences.fontSize.round().toString(),
                          onChanged: (value) =>
                              unawaited(preferences.setFontSize(value)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextButton.icon(
                      onPressed: () => unawaited(onOpenVoiceSettings(context)),
                      icon: const Icon(Icons.graphic_eq_outlined),
                      label: const Text('语音与来源设置'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MobileSettingsItem extends StatelessWidget {
  const _MobileSettingsItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.trailing,
  });

  final Widget icon;
  final String title;
  final String value;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tokens.panel.withValues(alpha: 0.8),
          tokens.ink,
        ),
        border: Border.all(color: tokens.structureLine),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow.withValues(alpha: 0.6),
            blurRadius: 28,
          ),
        ],
      ),
      child: Row(
        children: [
          _MobileSettingsGlyphBox(child: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _MobileSettingsGlyphBox extends StatelessWidget {
  const _MobileSettingsGlyphBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(
        color: context.visualTokens.signal.withValues(alpha: 0.32),
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

class _ThemeGlyph extends StatelessWidget {
  const _ThemeGlyph();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Icon(Icons.circle_outlined, size: 17, color: context.visualTokens.signal),
      Container(
        width: 12,
        height: 14,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            context.visualTokens.panel.withValues(alpha: 0.8),
            context.visualTokens.ink,
          ),
          shape: BoxShape.circle,
        ),
      ),
    ],
  );
}

class _BackgroundGlyph extends StatelessWidget {
  const _BackgroundGlyph();

  @override
  Widget build(BuildContext context) => Icon(
    Icons.landscape_outlined,
    size: 20,
    color: context.visualTokens.signal,
  );
}

class _FontGlyph extends StatelessWidget {
  const _FontGlyph();

  @override
  Widget build(BuildContext context) => Text(
    'A',
    style: TextStyle(
      color: context.visualTokens.signal,
      fontFamily: 'Georgia',
      fontSize: 20,
      fontStyle: FontStyle.italic,
    ),
  );
}

enum _MobilePageHeadingKind { settings, connection }

class _MobilePageHeading extends StatelessWidget {
  const _MobilePageHeading({required this.kind});

  final _MobilePageHeadingKind kind;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return SizedBox.square(
      dimension: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tokens.signal.withValues(alpha: 0.36)),
              boxShadow: [
                BoxShadow(
                  color: tokens.signal.withValues(alpha: 0.1),
                  blurRadius: 44,
                ),
              ],
            ),
          ),
          if (kind == _MobilePageHeadingKind.settings)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.45, -0.55),
                  colors: [
                    tokens.textPrimary,
                    tokens.signal,
                    tokens.signalWarm,
                  ],
                  stops: const [0.07, 0.25, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: tokens.signal.withValues(alpha: 0.44),
                    blurRadius: 22,
                  ),
                ],
              ),
            )
          else ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tokens.signal),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF55E58C),
                boxShadow: [
                  BoxShadow(color: Color(0xCC55E58C), blurRadius: 18),
                ],
              ),
            ),
          ],
          Transform.rotate(
            angle: math.pi * 44 / 180,
            child: Container(
              width: 76,
              height: 1,
              color: tokens.signal.withValues(alpha: 0.34),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileBackButton extends StatelessWidget {
  const _MobileBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '返回主页面',
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    style: IconButton.styleFrom(
      side: BorderSide(color: context.visualTokens.structureLine),
      shape: const CircleBorder(),
      foregroundColor: context.visualTokens.textMuted,
    ),
    icon: const Icon(Icons.reply_outlined, size: 19),
  );
}

class _MobileConnectionPage extends StatelessWidget {
  const _MobileConnectionPage({
    required this.phase,
    required this.onBack,
    required this.onPair,
    required this.onConnect,
    required this.onDisconnect,
  });

  final GatewayConnectionPhase phase;
  final VoidCallback onBack;
  final VoidCallback onPair;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final connected = phase == GatewayConnectionPhase.connected;
    final paired = phase != GatewayConnectionPhase.unpaired;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 34, 0, 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: _MobileBackButton(onPressed: onBack),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 54),
              child: Column(
                children: [
                  const _MobilePageHeading(
                    kind: _MobilePageHeadingKind.connection,
                  ),
                  const SizedBox(height: 34),
                  _MobileConnectionOption(
                    label: '已连接',
                    color: const Color(0xFF55E58C),
                    selected: connected,
                    onPressed: connected ? onDisconnect : null,
                  ),
                  const SizedBox(height: 12),
                  _MobileConnectionOption(
                    label: '连接中',
                    color: const Color(0xFFF4C95D),
                    selected:
                        phase == GatewayConnectionPhase.connecting ||
                        phase == GatewayConnectionPhase.reconnecting,
                    onPressed: null,
                  ),
                  const SizedBox(height: 12),
                  _MobileConnectionOption(
                    label: paired ? '未连接' : '未配对',
                    color: context.visualTokens.danger,
                    selected:
                        !connected &&
                        phase != GatewayConnectionPhase.connecting &&
                        phase != GatewayConnectionPhase.reconnecting,
                    onPressed: paired ? onConnect : onPair,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileConnectionOption extends StatelessWidget {
  const _MobileConnectionOption({
    required this.label,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              (selected ? tokens.signal : tokens.panel).withValues(
                alpha: selected ? 0.08 : 0.8,
              ),
              tokens.ink,
            ),
            border: Border.all(
              color: selected
                  ? tokens.signal.withValues(alpha: 0.58)
                  : tokens.structureLine,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: tokens.signal.withValues(alpha: 0.08),
                      blurRadius: 22,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.75),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(color: tokens.textPrimary, letterSpacing: 1.1),
              ),
              const Spacer(),
              if (selected) Icon(Icons.check, size: 18, color: tokens.signal),
            ],
          ),
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
  });

  final SignalCoreSnapshot snapshot;
  final VoidCallback onTap;
  final Future<void> Function() onLongPressStart;
  final Future<void> Function() onLongPressEnd;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Center(
      child: _MobileCoreGesture(
        snapshot: snapshot,
        dimension: math.min(constraints.maxWidth * 0.92, 370),
        onTap: onTap,
        onLongPressStart: onLongPressStart,
        onLongPressEnd: onLongPressEnd,
      ),
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
          child: _MobileCoreGesture(
            snapshot: snapshot,
            dimension: math.min(MediaQuery.sizeOf(context).width * 0.92, 370),
            onTap: onTap,
            onLongPressStart: onLongPressStart,
            onLongPressEnd: onLongPressEnd,
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
    return Stack(
      fit: StackFit.expand,
      children: [
        if (snapshot.state != SignalCoreState.idle)
          Positioned(
            top: 0,
            left: 0,
            child: Semantics(
              container: true,
              liveRegion: true,
              label: snapshot.label,
              child: const SizedBox(width: 1, height: 1),
            ),
          ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 92, 0, 118),
            child: content,
          ),
        ),
        Positioned.fill(
          child: ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: const Offset(0, 246),
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
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _MobileDraftComposer(
            textController: composer,
            session: session,
            voice: voice,
            sendEnabled: source == ChatSource.directLlm
                ? direct.isConfigured && direct.phase != DirectChatPhase.sending
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.panel.withValues(alpha: 0.84),
            border: Border.all(color: tokens.structureLine),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: tokens.shadow, blurRadius: 24)],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  enabled: session.canEditDraft && !confirmed,
                  minLines: 1,
                  maxLines: 3,
                  onChanged: onChanged,
                  decoration: const InputDecoration(
                    hintText: '编辑要说的话',
                    border: InputBorder.none,
                    isDense: true,
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
      style: filled
          ? IconButton.styleFrom(
              backgroundColor: context.visualTokens.signal,
              foregroundColor: context.visualTokens.ink,
            )
          : null,
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
  static const _longPressDelay = Duration(milliseconds: 540);

  var _pressed = false;
  var _longPressTriggered = false;
  Timer? _pressTimer;

  void _setPressed(bool pressed) {
    if (_pressed == pressed || !mounted) return;
    setState(() => _pressed = pressed);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryButton) {
      return;
    }
    _pressTimer?.cancel();
    _longPressTriggered = false;
    _setPressed(true);
    _pressTimer = Timer(_longPressDelay, () {
      _longPressTriggered = true;
      unawaited(widget.onLongPressStart());
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _pressTimer?.cancel();
    _pressTimer = null;
    _setPressed(false);
    if (_longPressTriggered) {
      unawaited(widget.onLongPressEnd());
    } else {
      widget.onTap();
    }
    _longPressTriggered = false;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pressTimer?.cancel();
    _pressTimer = null;
    _setPressed(false);
    if (_longPressTriggered) {
      unawaited(widget.onLongPressEnd());
    }
    _longPressTriggered = false;
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${widget.snapshot.label}; tap for text, long-press for voice input',
    onTap: widget.onTap,
    onLongPress: widget.onLongPressStart,
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
      padding: const EdgeInsets.all(28),
      child: Text(
        '暂无对话。',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.visualTokens.textMuted),
      ),
    ),
  );
}

class _MobileStarfield extends StatefulWidget {
  const _MobileStarfield({
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
  State<_MobileStarfield> createState() => _MobileStarfieldState();
}

class _MobileStarfieldState extends State<_MobileStarfield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) == true) {
      _drift.stop();
      _drift.value = 0;
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _drift,
    builder: (context, _) => CustomPaint(
      painter: _MobileStarfieldPainter(
        signal: widget.signal,
        signalStrong: widget.signalStrong,
        signalWarm: widget.signalWarm,
        structureLine: widget.structureLine,
        customBackgroundPreview: widget.customBackgroundPreview,
        light: widget.light,
        phase: _drift.value,
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
    required this.phase,
  });

  final Color signal;
  final Color signalStrong;
  final Color signalWarm;
  final Color structureLine;
  final bool customBackgroundPreview;
  final bool light;
  final double phase;

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
    canvas.save();
    canvas.translate(-12 * phase, 10 * phase);
    for (final (x, y, radius, color) in stars) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * y),
        radius,
        Paint()..color = color.withValues(alpha: light ? 0.34 : 0.7),
      );
    }
    canvas.restore();
    canvas.save();
    canvas.translate(8 * phase, -7 * phase);
    for (final (x, y, radius, color) in [
      (0.18, 0.28, 0.7, Colors.white),
      (0.58, 0.13, 0.65, signal),
      (0.36, 0.76, 0.65, Colors.white),
      (0.88, 0.7, 0.7, signalWarm),
    ]) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * y),
        radius,
        Paint()..color = color.withValues(alpha: light ? 0.18 : 0.34),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MobileStarfieldPainter oldDelegate) =>
      oldDelegate.signal != signal ||
      oldDelegate.signalStrong != signalStrong ||
      oldDelegate.signalWarm != signalWarm ||
      oldDelegate.structureLine != structureLine ||
      oldDelegate.customBackgroundPreview != customBackgroundPreview ||
      oldDelegate.light != light ||
      oldDelegate.phase != phase;
}
