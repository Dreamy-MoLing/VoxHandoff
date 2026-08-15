import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../application/chat_source_controller.dart';
import '../application/client_session_controller.dart';
import '../application/direct_chat_controller.dart';
import '../application/gateway_workspace_controller.dart';
import '../application/speech_playback_controller.dart';
import '../application/voice_session_controller.dart';
import '../domain/client_event.dart';
import '../domain/client_session.dart';
import '../domain/direct_chat.dart';
import '../domain/gateway_workspace.dart';
import '../domain/gateway_sync.dart';
import '../domain/signal_core.dart';
import '../domain/voice.dart';
import 'message_composer.dart';
import 'mobile_home_screen.dart';
import 'mobile_visual_preferences.dart';

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
  WebViewController? _webViewController;
  var _webViewReady = false;
  var _contentVisible = false;
  String? _lastBridgeState;
  GatewayConnectionPhase? _lastConnectionPhase;

  bool get _usesWebView =>
      !kIsWeb &&
      WebViewPlatform.instance != null &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS => true,
        TargetPlatform.fuchsia ||
        TargetPlatform.linux ||
        TargetPlatform.windows => false,
      };

  @override
  void initState() {
    super.initState();
    if (_usesWebView) {
      _createWebViewController();
    }
  }

  void _createWebViewController() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _webViewReady = true;
            _lastBridgeState = null;
            _scheduleBridgeSync();
          },
        ),
      )
      ..addJavaScriptChannel(
        'AgentTalk',
        onMessageReceived: (message) => _handleBridgeMessage(message.message),
      );
    _webViewController = controller;
    unawaited(controller.loadFlutterAsset('assets/mobile_ui/index.html'));
  }

  Future<void> _startVoice() async {
    if (ref.read(voiceSessionProvider).canStart) {
      await widget.onStartVoice();
    }
  }

  Future<void> _stopVoice() async {
    if (ref.read(voiceSessionProvider).canStop) {
      await widget.onStopVoice();
    }
  }

  void _handleBridgeMessage(String rawMessage) {
    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) return;
      message = Map<String, dynamic>.from(decoded);
    } on FormatException {
      return;
    }

    final event = message['event'];
    if (event is! String) return;

    switch (event) {
      case 'viewChanged':
        final view = message['view'];
        if (view is String) {
          if (_contentVisible) setState(() => _contentVisible = false);
        }
      case 'toggleText':
        final visible = message['visible'];
        if (visible is bool) setState(() => _contentVisible = visible);
      case 'voiceStart':
        unawaited(_startVoice());
      case 'voiceStop':
        unawaited(_stopVoice());
      case 'voiceCancel':
        unawaited(widget.onCancelVoice());
      case 'connectionAction':
        _handleConnectionAction(message['status']);
      case 'themeChanged':
        _handleThemeChanged(message['theme']);
      case 'fontSizeChanged':
        _handleFontSizeChanged(message['value']);
      case 'backgroundChanged':
        if (message['custom'] == true) {
          widget.preferences.setCustomBackgroundPreview(true);
        }
      case 'conversationAction':
        _handleConversationAction(message['action'], message['eventId']);
    }
  }

  void _handleConnectionAction(Object? status) {
    if (status == 'connected') {
      unawaited(widget.onDisconnect());
      return;
    }
    if (status != 'disconnected') return;
    if (ref.read(clientSessionProvider).connectionPhase ==
        GatewayConnectionPhase.unpaired) {
      widget.onOpenPairing();
    } else {
      unawaited(widget.onConnect());
    }
  }

  void _handleThemeChanged(Object? value) {
    final theme = value == 'light'
        ? MobileVisualTheme.light
        : MobileVisualTheme.dark;
    unawaited(widget.preferences.setTheme(theme));
  }

  void _handleFontSizeChanged(Object? value) {
    final size = value is num ? value.toDouble() : null;
    if (size != null) unawaited(widget.preferences.setFontSize(size));
  }

  void _handleConversationAction(Object? action, Object? eventId) {
    if (action is! String || eventId is! String) return;
    if (action == 'speak') {
      final direct = ref.read(directChatProvider);
      for (final message in direct.messages) {
        if (message.id == eventId) {
          unawaited(
            ref.read(directChatProvider.notifier).speakMessage(message),
          );
          return;
        }
      }
      return;
    }

    final workspace = ref.read(gatewayWorkspaceProvider);
    ClientEventRecord? event;
    for (final candidate in workspace.events) {
      if (candidate.eventId == eventId) {
        event = candidate;
        break;
      }
    }
    if (event == null) return;
    final pendingEvent = event;

    final controller = ref.read(gatewayWorkspaceProvider.notifier);
    switch (action) {
      case 'approve':
        unawaited(
          controller.resolveApproval(
            pendingEvent,
            ClientApprovalDecision.approve,
          ),
        );
      case 'deny':
        unawaited(
          controller.resolveApproval(pendingEvent, ClientApprovalDecision.deny),
        );
      case 'clarify':
        unawaited(_showClarificationDialog(pendingEvent));
    }
  }

  Future<void> _showClarificationDialog(ClientEventRecord event) async {
    final answer = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clarification response'),
        content: TextField(
          controller: answer,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Explicit answer',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit answer'),
          ),
        ],
      ),
    );
    final text = answer.text.trim();
    answer.dispose();
    if (confirmed == true && text.isNotEmpty && mounted) {
      ref
          .read(gatewayWorkspaceProvider.notifier)
          .resolveClarification(event, text);
    }
  }

  void _scheduleBridgeSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncBridgeState();
    });
  }

  Future<void> _syncBridgeState() async {
    final controller = _webViewController;
    if (!_webViewReady || controller == null) return;

    final session = ref.read(clientSessionProvider);
    final source = ref.read(chatSourceProvider);
    final direct = ref.read(directChatProvider);
    final workspace = ref.read(gatewayWorkspaceProvider);
    final voice = ref.read(voiceSessionProvider);
    final speech = ref.read(speechPlaybackProvider);
    final workspaceController = ref.read(gatewayWorkspaceProvider.notifier);
    final snapshot = resolveSignalCore(
      workspace: workspace,
      session: session,
      voice: voice,
      speech: speech,
    );
    final showText =
        _contentVisible ||
        voice.phase == VoiceInputPhase.awaitingConfirmation ||
        session.draftPhase == DraftPhase.confirmed ||
        snapshot.state == SignalCoreState.approval ||
        snapshot.state == SignalCoreState.uncertain;
    final connection = _connectionPayload(session.connectionPhase);
    final connectionChanged = _lastConnectionPhase != session.connectionPhase;
    _lastConnectionPhase = session.connectionPhase;
    final state = <String, dynamic>{
      'theme': widget.preferences.theme == MobileVisualTheme.light
          ? 'light'
          : 'dark',
      'fontSize': widget.preferences.fontSize,
      'customBackground': widget.preferences.customBackgroundPreview,
      'ttsVisible': showText,
      'coreState': voice.phase == VoiceInputPhase.recording
          ? 'recording'
          : 'ready',
      'connection': connection.status,
      'connectionLabel': connection.label,
      'connectionMessage':
          connection.status != 'connected' ||
          (connectionChanged && connection.status == 'connected'),
    };
    final payload = <String, dynamic>{
      'state': state,
      'conversation': _conversationPayload(
        source: source,
        direct: direct,
        workspace: workspace,
        speechEnabled: ref.read(speechEnabledProvider),
        ownsLease: workspace.ownsSelectedLease(
          workspaceController.deviceId,
          DateTime.now(),
        ),
      ),
    };
    final encoded = jsonEncode(payload);
    if (encoded == _lastBridgeState) return;
    _lastBridgeState = encoded;
    try {
      await controller.runJavaScript(
        'window.AgentTalkHost?.applyState(${jsonEncode(state)});'
        'window.AgentTalkHost?.setConversation(${jsonEncode(payload['conversation'])});',
      );
    } catch (_) {
      // The page can be replaced while a platform WebView is loading.
      _lastBridgeState = null;
    }
  }

  ({String status, String label}) _connectionPayload(
    GatewayConnectionPhase phase,
  ) => switch (phase) {
    GatewayConnectionPhase.connected => (status: 'connected', label: '已连接'),
    GatewayConnectionPhase.connecting => (status: 'connecting', label: '连接中'),
    GatewayConnectionPhase.reconnecting => (status: 'connecting', label: '重连中'),
    GatewayConnectionPhase.unpaired => (status: 'disconnected', label: '未配对'),
    GatewayConnectionPhase.offline => (status: 'disconnected', label: '未连接'),
    GatewayConnectionPhase.failed => (status: 'disconnected', label: '连接失败'),
  };

  List<Map<String, dynamic>> _conversationPayload({
    required ChatSource source,
    required DirectChatState direct,
    required GatewayWorkspaceState workspace,
    required bool speechEnabled,
    required bool ownsLease,
  }) {
    if (source == ChatSource.directLlm) {
      return [
        for (final message in direct.messages)
          if (message.role != DirectChatRole.system)
            {
              'role': message.role == DirectChatRole.user
                  ? 'user'
                  : 'assistant',
              'text': message.text.isEmpty ? '…' : message.text,
              if (speechEnabled &&
                  message.role == DirectChatRole.assistant &&
                  message.terminal == DirectMessageTerminal.completed)
                'actions': [
                  {
                    'type': 'speak',
                    'eventId': message.id,
                    'label': '播放',
                    'enabled': true,
                  },
                ],
            },
      ];
    }

    final result = <Map<String, dynamic>>[];
    for (final turn in workspace.timeline) {
      if (turn.userText?.trim().isNotEmpty == true) {
        result.add({'role': 'user', 'text': turn.userText});
      }
      result.add({
        'role': 'assistant',
        'text': turn.assistantText.isEmpty
            ? (turn.isTerminal ? '未返回助手文本。' : 'Hermes 正在工作…')
            : turn.assistantText,
        'quiet': turn.assistantText.isEmpty,
      });
      final pending = turn.pendingInteraction;
      if (pending == null) continue;
      final content = pending.content;
      if (content is ApprovalClientEventContent) {
        result.add({
          'role': 'assistant',
          'text': content.safeSummary,
          'actions': [
            {
              'type': 'approve',
              'eventId': pending.eventId,
              'label': '批准一次',
              'enabled': ownsLease,
            },
            {
              'type': 'deny',
              'eventId': pending.eventId,
              'label': '拒绝',
              'enabled': ownsLease,
            },
          ],
        });
      } else if (content is ClarificationClientEventContent) {
        result.add({
          'role': 'assistant',
          'text': content.safePrompt,
          'actions': [
            {
              'type': 'clarify',
              'eventId': pending.eventId,
              'label': '明确回答',
              'enabled': ownsLease,
            },
          ],
        });
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (!_usesWebView) return _buildNativeFallback();

    final session = ref.watch(clientSessionProvider);
    final voice = ref.watch(voiceSessionProvider);
    final speech = ref.watch(speechPlaybackProvider);
    final workspace = ref.watch(gatewayWorkspaceProvider);
    final snapshot = resolveSignalCore(
      workspace: workspace,
      session: session,
      voice: voice,
      speech: speech,
    );
    final showText =
        _contentVisible ||
        voice.phase == VoiceInputPhase.awaitingConfirmation ||
        session.draftPhase == DraftPhase.confirmed ||
        snapshot.state == SignalCoreState.approval ||
        snapshot.state == SignalCoreState.uncertain;
    _scheduleBridgeSync();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_webViewController case final controller?)
            WebViewWidget(controller: controller),
          if (showText)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MessageComposer(
                textController: widget.composer,
                session: session,
                voice: voice,
                onChanged: ref.read(clientSessionProvider.notifier).editDraft,
                onConfirm: widget.onConfirm,
                onReopen: widget.onReopen,
                onSend: widget.onSend,
                onNextDraft: widget.onNextDraft,
                sendEnabled: _sendEnabled(
                  source: ref.watch(chatSourceProvider),
                  direct: ref.watch(directChatProvider),
                  workspace: workspace,
                ),
                onStartVoice: _startVoice,
                onStopVoice: _stopVoice,
                onCancelVoice: widget.onCancelVoice,
                onDiscardVoice: widget.onDiscardVoice,
                sendLabel: ref.watch(chatSourceProvider) == ChatSource.directLlm
                    ? '发送'
                    : '交给 Hermes',
                requiresGatewayConnection:
                    ref.watch(chatSourceProvider) != ChatSource.directLlm,
              ),
            ),
        ],
      ),
    );
  }

  bool _sendEnabled({
    required ChatSource source,
    required DirectChatState direct,
    required GatewayWorkspaceState workspace,
  }) {
    if (source == ChatSource.directLlm) {
      return direct.isConfigured && direct.phase != DirectChatPhase.sending;
    }
    final controller = ref.read(gatewayWorkspaceProvider.notifier);
    return workspace.ownsSelectedLease(controller.deviceId, DateTime.now());
  }

  Widget _buildNativeFallback() => NativeMobileHomeScreen(
    preferences: widget.preferences,
    composer: widget.composer,
    onOpenPairing: widget.onOpenPairing,
    onConnect: widget.onConnect,
    onDisconnect: widget.onDisconnect,
    onConfirm: widget.onConfirm,
    onReopen: widget.onReopen,
    onSend: widget.onSend,
    onNextDraft: widget.onNextDraft,
    onStartVoice: widget.onStartVoice,
    onStopVoice: widget.onStopVoice,
    onCancelVoice: widget.onCancelVoice,
    onDiscardVoice: widget.onDiscardVoice,
    onOpenVoiceSettings: widget.onOpenVoiceSettings,
  );
}
