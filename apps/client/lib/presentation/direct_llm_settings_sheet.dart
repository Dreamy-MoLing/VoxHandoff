import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/direct_chat_controller.dart';
import '../domain/direct_chat.dart';
import 'direct_context_settings_sheet.dart';

Future<void> showDirectLlmSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DirectLlmSettingsSheet(),
    );

class _DirectLlmSettingsSheet extends ConsumerStatefulWidget {
  const _DirectLlmSettingsSheet();
  @override
  ConsumerState<_DirectLlmSettingsSheet> createState() =>
      _DirectLlmSettingsSheetState();
}

class _DirectLlmSettingsSheetState
    extends ConsumerState<_DirectLlmSettingsSheet> {
  late final TextEditingController _origin;
  late final TextEditingController _model;
  late final TextEditingController _key;
  late final TextEditingController _prompt;
  late final TextEditingController _assistantName;
  late final TextEditingController _assistantPersona;
  @override
  void initState() {
    super.initState();
    final current = ref.read(directChatProvider).configuration;
    _origin = TextEditingController(
      text: current?.origin.toString() ?? 'https://',
    );
    _model = TextEditingController(text: current?.model ?? '');
    _key = TextEditingController();
    _prompt = TextEditingController(text: current?.systemPrompt ?? '');
    final assistant = ref.read(directChatProvider).assistantProfile;
    _assistantName = TextEditingController(
      text: assistant?.displayName ?? 'VoxHandoff',
    );
    _assistantPersona = TextEditingController(text: assistant?.persona ?? '');
  }

  @override
  void dispose() {
    _origin.dispose();
    _model.dispose();
    _key.dispose();
    _prompt.dispose();
    _assistantName.dispose();
    _assistantPersona.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directChatProvider);
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
                'Direct LLM API',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Only confirmed text is sent directly to this HTTPS API base. The API key stays in OS secure storage.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _origin,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'HTTPS API base URL',
                  helperText: 'OpenRouter: https://openrouter.ai/api/v1',
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
              TextField(
                controller: _prompt,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Optional system prompt',
                ),
              ),
              TextField(
                controller: _assistantName,
                decoration: const InputDecoration(labelText: 'Assistant name'),
              ),
              TextField(
                controller: _assistantPersona,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Assistant persona (local display context)',
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
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    showDirectContextSettingsSheet(navigator.context);
                  },
                  icon: const Icon(Icons.memory_outlined),
                  label: const Text('Manage conversation memory and summary'),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed:
                        state.isConfigured &&
                            state.phase != DirectChatPhase.testing
                        ? () => ref
                              .read(directChatProvider.notifier)
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
    final uri = Uri.tryParse(_origin.text.trim());
    if (uri == null) return;
    final old = ref.read(directChatProvider).configuration;
    await ref
        .read(directChatProvider.notifier)
        .configure(
          DirectLlmConfiguration(
            id: old?.id ?? 'default-direct-llm',
            origin: uri,
            model: _model.text.trim(),
            systemPrompt: _prompt.text,
          ),
          _key.text,
        );
    final assistant = ref.read(directChatProvider).assistantProfile;
    if (assistant != null &&
        (assistant.displayName != _assistantName.text.trim() ||
            assistant.persona != _assistantPersona.text.trim())) {
      await ref
          .read(directChatProvider.notifier)
          .updateAssistantIdentity(
            displayName: _assistantName.text,
            persona: _assistantPersona.text,
          );
    }
  }
}
