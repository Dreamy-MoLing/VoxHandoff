import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/client_session_controller.dart';
import '../application/chat_source_controller.dart';
import '../application/desktop_integration_controller.dart';
import '../application/direct_chat_controller.dart';
import '../application/device_pairing_controller.dart';
import '../application/gateway_workspace_controller.dart';
import '../application/hermes_conversation_controller.dart';
import '../application/speech_playback_controller.dart';
import '../application/voice_session_controller.dart';
import '../application/voice_provider_settings_controller.dart';
import '../domain/client_session.dart';
import '../domain/confirmed_draft.dart';
import '../domain/direct_chat.dart';
import '../domain/desktop_capabilities.dart';
import '../domain/device_pairing.dart';
import '../domain/gateway_sync.dart';
import '../domain/gateway_workspace.dart';
import '../domain/signal_core.dart';
import '../domain/speech.dart';
import '../domain/voice.dart';
import 'conversation_view.dart';
import 'direct_chat_view.dart';
import 'direct_llm_settings_sheet.dart';
import 'design/agent_talk_theme.dart';
import 'hermes_conversation_settings_sheet.dart';
import 'hermes_conversation_view.dart';
import 'message_composer.dart';
import 'mobile_home_screen.dart';
import 'mobile_visual_preferences.dart';
import 'pairing_dialog.dart';
import 'voice_settings_sheet.dart';
import 'signal_core_view.dart';

part 'home_screen_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({this.visualPreferences, super.key});

  final MobileVisualPreferences? visualPreferences;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _composer;
  late final MobileVisualPreferences _ownedVisualPreferences;
  late final VoiceCallSendHandlers _voiceCallSendHandlers;
  var _mobilePreferencesRestoreStarted = false;

  MobileVisualPreferences get _visualPreferences =>
      widget.visualPreferences ?? _ownedVisualPreferences;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
    _ownedVisualPreferences = MobileVisualPreferences();
    _voiceCallSendHandlers = ref.read(voiceCallSendHandlerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _voiceCallSendHandlers.register(_sendConfirmedVoiceCall);
      ref.read(devicePairingProvider.notifier).restore();
      unawaited(
        ref
            .read(desktopIntegrationProvider.notifier)
            .initialize(
              onVoiceToggle: _toggleVoiceDraft,
              workspace: ref.read(gatewayWorkspaceProvider),
            ),
      );
      final assistant = ref.read(directChatProvider).assistantProfile;
      if (assistant != null) {
        unawaited(
          ref
              .read(voiceProviderSettingsProvider.notifier)
              .bindAssistant(
                assistant.assistantId,
                assistant.assistantRevision,
              ),
        );
      }
    });
  }

  @override
  void dispose() {
    _voiceCallSendHandlers.clear();
    _composer.dispose();
    if (widget.visualPreferences == null) _ownedVisualPreferences.dispose();
    super.dispose();
  }

  void _confirmDraft() {
    final session = ref.read(clientSessionProvider);
    final source = ref.read(chatSourceProvider);
    final direct = ref.read(directChatProvider);
    final workspace = ref.read(gatewayWorkspaceProvider);
    final hermesConversation = ref.read(hermesConversationProvider);
    if (source == ChatSource.hermes && workspace.selectedConversation == null) {
      // An unpaired shell may still keep a local confirmed draft for the
      // existing composer UX. It has no routable target and cannot be sent.
      ref.read(clientSessionProvider.notifier).confirmDraft();
      final confirmedText = ref.read(clientSessionProvider).draftText;
      _composer.value = TextEditingValue(
        text: confirmedText,
        selection: TextSelection.collapsed(offset: confirmedText.length),
      );
      return;
    }
    if (source == ChatSource.hermesConversation &&
        hermesConversation.configuration == null) {
      unawaited(showHermesConversationSettingsSheet(context));
      return;
    }
    final assistant =
        direct.assistantProfile ??
        const AssistantProfile(
          assistantId: 'default-assistant-uninitialized',
          assistantRevision: 1,
          systemPrompt: '',
        );
    final target = switch (source) {
      ChatSource.directLlm => _directTarget(direct),
      ChatSource.hermes => _hermesTarget(workspace),
      ChatSource.hermesConversation => _hermesConversationTarget(
        hermesConversation,
      ),
    };
    final contextParts = switch (source) {
      ChatSource.directLlm =>
        direct.messages
            .where((message) => message.contextEligible)
            .map(
              (message) => '${message.id}:${message.revision}:${message.text}',
            )
            .toList(growable: false),
      ChatSource.hermes =>
        workspace.events
            .map((event) => '${event.eventId}:${event.sequence}')
            .toList(growable: false),
      ChatSource.hermesConversation =>
        hermesConversation.messages
            .where((message) => message.contextEligible)
            .map(
              (message) => '${message.id}:${message.revision}:${message.text}',
            )
            .toList(growable: false),
    };
    final contextRevision = switch (source) {
      ChatSource.directLlm =>
        direct.configuration?.contextSnapshotRevision ?? 0,
      ChatSource.hermes =>
        workspace.selectedConversation?.revision.toInt() ?? 0,
      ChatSource.hermesConversation =>
        hermesConversation.configuration?.contextSnapshotRevision ?? 0,
    };
    final contextHash = switch (source) {
      ChatSource.directLlm =>
        direct.configuration?.contextSnapshotHash ??
            ConfirmedDraft.contextHash(contextParts),
      ChatSource.hermes => ConfirmedDraft.contextHash(contextParts),
      ChatSource.hermesConversation =>
        hermesConversation.configuration?.contextSnapshotHash ??
            ConfirmedDraft.contextHash(contextParts),
    };
    final draft = ConfirmedDraft(
      draftId: _opaqueId('draft'),
      draftRevision: session.draftRevision,
      confirmedText: session.draftText,
      assistantId: assistant.assistantId,
      assistantRevision: assistant.assistantRevision,
      contextSnapshotRevision: contextRevision,
      contextSnapshotHash: contextHash,
      target: target,
    );
    ref.read(clientSessionProvider.notifier).confirmDraft(draft);
    final confirmedText = ref.read(clientSessionProvider).draftText;
    _composer.value = TextEditingValue(
      text: confirmedText,
      selection: TextSelection.collapsed(offset: confirmedText.length),
    );
  }

  Future<void> _openPairing() => showDevicePairingDialog(context);

  Future<void> _send() async {
    final draft = ref.read(clientSessionProvider).confirmedDraft;
    if (draft == null) return;
    if (draft.chatSource == ChatSource.directLlm) {
      await ref.read(directChatProvider.notifier).sendConfirmedText(draft);
    } else if (draft.chatSource == ChatSource.hermesConversation) {
      await ref
          .read(hermesConversationProvider.notifier)
          .sendConfirmedText(draft);
    } else {
      await ref
          .read(gatewayWorkspaceProvider.notifier)
          .sendConfirmedText(draft);
    }
  }

  void _startNextDraft() {
    ref.read(clientSessionProvider.notifier).startNextDraft();
    _composer.clear();
  }

  Future<void> _startVoice() =>
      ref.read(voiceSessionProvider.notifier).startRecording();

  Future<void> _stopVoice() async {
    await ref.read(voiceSessionProvider.notifier).stopRecording();
    final draft = ref.read(clientSessionProvider).draftText;
    _composer.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  Future<void> _cancelVoice() =>
      ref.read(voiceSessionProvider.notifier).cancelRecording();

  Future<void> _discardVoice() async {
    await ref.read(voiceSessionProvider.notifier).discardTranscript();
    _composer.clear();
  }

  Future<void> _toggleVoiceDraft() async {
    final voice = ref.read(voiceSessionProvider);
    if (voice.canStop) {
      await _stopVoice();
    } else if (voice.canStart) {
      await _startVoice();
    }
  }

  /// Presentation-owned Call-mode send: binds a confirmation snapshot through
  /// the existing ChatSource abstraction and dispatches it. Hermes transport
  /// is M1's scope; failures surface to the voice controller, which keeps the
  /// editable transcript for a manual Command-mode confirm.
  Future<void> _sendConfirmedVoiceCall(String confirmedText) async {
    final session = ref.read(clientSessionProvider);
    if (session.canEditDraft && session.draftText.trim() != confirmedText) {
      ref.read(clientSessionProvider.notifier).editDraft(confirmedText);
    }
    _confirmDraft();
    await _send();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(clientSessionProvider);
    final controller = ref.read(clientSessionProvider.notifier);
    final pairing = ref.watch(devicePairingProvider);
    final source = ref.watch(chatSourceProvider);
    final directChat = ref.watch(directChatProvider);
    final workspace = ref.watch(gatewayWorkspaceProvider);
    final hermesConversation = ref.watch(hermesConversationProvider);
    final speechEnabled = ref.watch(speechEnabledProvider);
    ref.listen(directChatProvider, (_, next) {
      final assistant = next.assistantProfile;
      if (assistant != null) {
        unawaited(
          ref
              .read(voiceProviderSettingsProvider.notifier)
              .bindAssistant(
                assistant.assistantId,
                assistant.assistantRevision,
              ),
        );
      }
    });
    ref.listen(gatewayWorkspaceProvider, (_, next) {
      unawaited(
        ref.read(desktopIntegrationProvider.notifier).observeWorkspace(next),
      );
    });
    final workspaceController = ref.read(gatewayWorkspaceProvider.notifier);
    ref.watch(
      voiceSessionProvider.select(
        (voice) => (
          voice.phase,
          voice.sessionId,
          voice.provisionalTranscript,
          voice.finalTranscript,
          voice.failure,
        ),
      ),
    );
    final voice = ref.read(voiceSessionProvider);
    final desktop = ref.watch(desktopIntegrationProvider);
    final ownsLease = workspace.ownsSelectedLease(
      workspaceController.deviceId,
      DateTime.now(),
    );
    final compactAppBar = MediaQuery.sizeOf(context).width < 480;
    final isDirect = source == ChatSource.directLlm;
    final isHermesConversation = source == ChatSource.hermesConversation;
    final isMobilePlatform = Platform.isAndroid || Platform.isIOS;
    if (isMobilePlatform || MediaQuery.sizeOf(context).width < 600) {
      if (!_mobilePreferencesRestoreStarted) {
        _mobilePreferencesRestoreStarted = true;
        unawaited(_visualPreferences.restore());
      }
      return AnimatedBuilder(
        animation: _visualPreferences,
        builder: (context, _) {
          final theme = _visualPreferences.theme == MobileVisualTheme.light
              ? buildAgentTalkMobileLightTheme()
              : buildAgentTalkMobileDarkTheme();
          final systemScale = MediaQuery.textScalerOf(context).scale(1);
          final preferenceScale = _visualPreferences.fontSize / 21;
          return Theme(
            data: theme,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(systemScale * preferenceScale),
              ),
              child: MobileHomeScreen(
                preferences: _visualPreferences,
                composer: _composer,
                onOpenPairing: _openPairing,
                onConnect: workspaceController.connect,
                onDisconnect: workspaceController.disconnect,
                onConfirm: _confirmDraft,
                onReopen: controller.reopenDraft,
                onSend: _send,
                onNextDraft: _startNextDraft,
                onStartVoice: _startVoice,
                onStopVoice: _stopVoice,
                onCancelVoice: _cancelVoice,
                onDiscardVoice: _discardVoice,
                onOpenVoiceSettings: (sheetContext) =>
                    showVoiceSettingsSheet(sheetContext),
                onOpenHermesConversationSettings: (sheetContext) =>
                    showHermesConversationSettingsSheet(sheetContext),
                hermesConversation: hermesConversation,
              ),
            ),
          );
        },
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.space,
          control: true,
          shift: true,
        ): () =>
            unawaited(_toggleVoiceDraft()),
      },
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(
            header: true,
            label: 'VoxHandoff',
            child: const Text(
              'VOX / HANDOFF',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2.2),
            ),
          ),
          actions: [
            PopupMenuButton<ChatSource>(
              tooltip: 'Choose chat source',
              initialValue: source,
              onSelected: (value) => unawaited(
                ref.read(chatSourceProvider.notifier).select(value),
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ChatSource.hermesConversation,
                  child: Text('Hermes conversation'),
                ),
                PopupMenuItem(
                  value: ChatSource.hermes,
                  child: Text('Hermes via Gateway'),
                ),
                PopupMenuItem(
                  value: ChatSource.directLlm,
                  child: Text('Direct LLM API'),
                ),
              ],
              child: IconButton(
                onPressed: null,
                icon: Icon(
                  isDirect || isHermesConversation
                      ? Icons.forum_outlined
                      : Icons.hub_outlined,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Source settings',
              onPressed: () => showVoiceSettingsSheet(context),
              icon: const Icon(Icons.tune_outlined),
            ),
            if (desktop.isDesktop) _DesktopCapabilityIcon(snapshot: desktop),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: compactAppBar
                  ? _ConnectionStatusIcon(phase: session.connectionPhase)
                  : _ConnectionChip(phase: session.connectionPhase),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final showNavigation = constraints.maxWidth >= 900;
            final banner = isDirect
                ? _DirectLlmBanner(
                    state: directChat,
                    assistant: directChat.assistantProfile,
                    capabilities: AssistantCapabilityProjection.direct,
                    onConfigure: () => showDirectLlmSettingsSheet(context),
                  )
                : isHermesConversation
                ? HermesConversationBanner(
                    state: hermesConversation,
                    onConfigure: () =>
                        showHermesConversationSettingsSheet(context),
                  )
                : _LocalOnlyBanner(
                    pairing: pairing,
                    workspace: workspace,
                    onOpenPairing: _openPairing,
                    onConnect: workspaceController.connect,
                    onDisconnect: workspaceController.disconnect,
                  );
            final conversation = isDirect
                ? DirectChatView(
                    state: directChat,
                    onCancel: ref.read(directChatProvider.notifier).cancel,
                    onSpeak: ref.read(directChatProvider.notifier).speakMessage,
                    speechEnabled: speechEnabled,
                  )
                : isHermesConversation
                ? HermesConversationView(
                    state: hermesConversation,
                    onCancel: ref
                        .read(hermesConversationProvider.notifier)
                        .cancel,
                    onConfigure: () =>
                        showHermesConversationSettingsSheet(context),
                  )
                : workspace.selectedConversation == null
                ? const _EmptyConversation()
                : ConversationView(
                    workspace: workspace,
                    ownsLease: ownsLease,
                    onAcquire: () => workspaceController.acquireSelectedControl(
                      explicitTakeover: workspace.selectedLease != null,
                    ),
                    onApproval: workspaceController.resolveApproval,
                    onClarification: workspaceController.resolveClarification,
                    onInterrupt: workspaceController.interrupt,
                  );
            final composer = MessageComposer(
              textController: _composer,
              session: session,
              voice: voice,
              onChanged: controller.editDraft,
              onConfirm: _confirmDraft,
              onReopen: controller.reopenDraft,
              onSend: _send,
              onNextDraft: _startNextDraft,
              sendEnabled: isDirect
                  ? directChat.isConfigured &&
                        directChat.phase != DirectChatPhase.sending
                  : isHermesConversation
                  ? hermesConversation.isConfigured &&
                        hermesConversation.phase !=
                            HermesConversationPhase.sending
                  : ownsLease,
              requiresGatewayConnection: source == ChatSource.hermes,
              sendLabel: isDirect
                  ? 'Send to LLM'
                  : isHermesConversation
                  ? 'Send to Hermes'
                  : 'Handoff to Hermes',
              onStartVoice: _startVoice,
              onStopVoice: _stopVoice,
              onCancelVoice: _cancelVoice,
              onDiscardVoice: _discardVoice,
              onConfirmCallSend: () =>
                  ref.read(voiceSessionProvider.notifier).confirmCallSend(),
            );
            if (!showNavigation || isDirect || isHermesConversation) {
              return Column(
                children: [
                  Expanded(
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                        SliverToBoxAdapter(child: banner),
                        if (!isHermesConversation &&
                            workspace.directory != null)
                          SliverToBoxAdapter(
                            child: _ConversationPicker(
                              workspace: workspace,
                              onSelect: workspaceController.selectConversation,
                              onCreate: () => _showCreateConversationDialog(
                                context,
                                workspace,
                                workspaceController,
                              ),
                            ),
                          ),
                      ],
                      body: conversation,
                    ),
                  ),
                  composer,
                ],
              );
            }
            return Row(
              children: [
                _NavigationPane(
                  workspace: workspace,
                  onSelect: workspaceController.selectConversation,
                  onCreate: () => _showCreateConversationDialog(
                    context,
                    workspace,
                    workspaceController,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      banner,
                      Expanded(child: conversation),
                      composer,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  DirectTargetSnapshot _directTarget(DirectChatState state) {
    final configuration = state.configuration;
    if (configuration == null || configuration.conversationId.isEmpty) {
      throw StateError('Configure the Direct LLM target before confirming.');
    }
    return DirectTargetSnapshot(
      conversationId: configuration.conversationId,
      providerProfileId: configuration.profileId,
      credentialRevision: configuration.credentialRevision,
      configurationRevision: configuration.configurationRevision,
      normalizedOrigin: normalizedProviderOrigin(configuration.origin),
      model: configuration.model,
    );
  }

  HermesTargetSnapshot _hermesTarget(GatewayWorkspaceState workspace) {
    final conversation = workspace.selectedConversation;
    if (conversation == null) {
      throw StateError('Select a Hermes conversation before confirming.');
    }
    return HermesTargetSnapshot(
      conversationId: conversation.conversationId,
      nodeId: conversation.nodeId,
      agentId: conversation.agentId,
      capabilityRevision: conversation.capabilityRevision,
      sessionId: conversation.sessionId,
    );
  }

  HermesConversationTargetSnapshot _hermesConversationTarget(
    HermesConversationState state,
  ) {
    final configuration = state.configuration;
    if (configuration == null || !configuration.isSafe) {
      throw StateError('Configure the Hermes conversation before confirming.');
    }
    return HermesConversationTargetSnapshot(
      conversationId: configuration.conversationId,
      providerProfileId: configuration.providerProfileId,
      credentialRevision: configuration.credentialRevision,
      configurationRevision: configuration.configurationRevision,
      normalizedOrigin: configuration.normalizedOrigin,
      model: configuration.model,
      sessionId: configuration.sessionId,
      sessionKey: configuration.sessionKey,
    );
  }

  String _opaqueId(String prefix) {
    final random = math.Random.secure();
    return '$prefix-${List<int>.generate(16, (_) => random.nextInt(256)).map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
  }
}
