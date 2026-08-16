import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/hermes_conversation_controller.dart';
import '../domain/confirmed_draft.dart';
import '../domain/hermes_conversation.dart';

Future<void> showHermesConversationSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HermesConversationSettingsSheet(),
    );

class _HermesConversationSettingsSheet extends ConsumerStatefulWidget {
  const _HermesConversationSettingsSheet();

  @override
  ConsumerState<_HermesConversationSettingsSheet> createState() =>
      _HermesConversationSettingsSheetState();
}

class _HermesConversationSettingsSheetState
    extends ConsumerState<_HermesConversationSettingsSheet> {
  late final TextEditingController _origin;
  late final TextEditingController _model;
  late final TextEditingController _key;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    final current = ref.read(hermesConversationProvider).configuration;
    _origin = TextEditingController(
      text: current?.origin.toString() ?? 'https://127.0.0.1:8642',
    );
    _model = TextEditingController(text: current?.model ?? 'hermes');
    _key = TextEditingController();
  }

  @override
  void dispose() {
    _origin.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hermesConversationProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Hermes conversation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Confirmed text uses Hermes /v1/chat/completions. The API key stays in OS secure storage; session history is restored by the configured Hermes session ID.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _origin,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'HTTPS Hermes base URL',
                  helperText: 'Optional profile path: https://host/p/profile',
                ),
              ),
              TextField(
                controller: _model,
                decoration: const InputDecoration(labelText: 'Model'),
              ),
              TextField(
                controller: _key,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'API key (leave empty to keep saved key)',
                ),
              ),
              if (_inputError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _inputError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (state.failure != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.failure!.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed:
                        state.isConfigured &&
                            state.phase != HermesConversationPhase.testing &&
                            state.phase != HermesConversationPhase.sending
                        ? () => ref
                              .read(hermesConversationProvider.notifier)
                              .testConnection()
                        : null,
                    child: const Text('Test connection'),
                  ),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save securely'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final origin = Uri.tryParse(_origin.text.trim());
    final model = _model.text.trim();
    if (origin == null || model.isEmpty) {
      setState(() => _inputError = 'Enter an HTTPS origin and model.');
      return;
    }
    final current = ref.read(hermesConversationProvider).configuration;
    final configuration = HermesConversationConfiguration(
      providerProfileId: current?.providerProfileId ?? 'settings-profile',
      origin: origin,
      model: model,
      conversationId: current?.conversationId ?? 'settings-conversation',
      sessionId: current?.sessionId ?? 'settings-session',
      sessionKey: current?.sessionKey ?? 'settings-scope',
      credentialRevision: current?.credentialRevision ?? 1,
      configurationRevision: current?.configurationRevision ?? 1,
      contextSnapshotRevision: current?.contextSnapshotRevision ?? 0,
      contextSnapshotHash:
          current?.contextSnapshotHash ?? ConfirmedDraft.contextHash(const []),
      sessionIdPolicy:
          current?.sessionIdPolicy ?? HermesSessionIdPolicy.bootstrapPreferred,
    );
    if (!configuration.isSafe) {
      setState(
        () => _inputError = 'Use HTTPS with an optional /p/<profile> path.',
      );
      return;
    }
    setState(() => _inputError = null);
    await ref
        .read(hermesConversationProvider.notifier)
        .configure(configuration, _key.text);
    if (!mounted) return;
    if (ref.read(hermesConversationProvider).isConfigured) {
      Navigator.of(context).pop();
    }
  }
}
