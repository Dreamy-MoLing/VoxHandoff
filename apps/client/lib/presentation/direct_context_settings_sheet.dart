import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/direct_chat_controller.dart';
import '../domain/direct_context.dart';

Future<void> showDirectContextSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DirectContextSettingsSheet(),
    );

class _DirectContextSettingsSheet extends ConsumerStatefulWidget {
  const _DirectContextSettingsSheet();

  @override
  ConsumerState<_DirectContextSettingsSheet> createState() =>
      _DirectContextSettingsSheetState();
}

class _DirectContextSettingsSheetState
    extends ConsumerState<_DirectContextSettingsSheet> {
  late final TextEditingController _memory;
  String? _editingMemoryId;
  late Future<({List<FixedMemory> memories, RollingSummary? summary})>
  _contextFuture;

  @override
  void initState() {
    super.initState();
    _memory = TextEditingController();
    _reload();
  }

  @override
  void dispose() {
    _memory.dispose();
    super.dispose();
  }

  void _reload() {
    final controller = ref.read(directChatProvider.notifier);
    _contextFuture =
        Future.wait<Object?>([
          controller.listMemories(),
          controller.readSummary(),
        ]).then(
          (values) => (
            memories: values[0]! as List<FixedMemory>,
            summary: values[1] as RollingSummary?,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final configuration = ref.watch(directChatProvider).configuration;
    if (configuration == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Configure a Direct LLM before editing conversation context.',
          ),
        ),
      );
    }
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Conversation context',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Only this conversation\'s local memories, summary, and recent completed turns can enter the Direct request. Failed or partial replies are excluded.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _memory,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Add a fixed memory',
                  helperText: 'Saved locally for this conversation only.',
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(directChatProvider.notifier)
                        .saveMemory(_memory.text, memoryId: _editingMemoryId);
                    _memory.clear();
                    _editingMemoryId = null;
                    if (mounted) setState(_reload);
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    _editingMemoryId == null ? 'Save memory' : 'Update memory',
                  ),
                ),
              ),
              const Divider(height: 28),
              FutureBuilder<
                ({List<FixedMemory> memories, RollingSummary? summary})
              >(
                future: _contextFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Fixed memories',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (data.memories.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('No fixed memories saved.'),
                        )
                      else
                        for (final memory in data.memories)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(memory.text),
                            subtitle: Text(
                              '${memory.scope} · revision ${memory.revision}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Delete memory',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await ref
                                    .read(directChatProvider.notifier)
                                    .deleteMemory(memory.memoryId);
                                if (mounted) setState(_reload);
                              },
                            ),
                            onTap: () => setState(() {
                              _editingMemoryId = memory.memoryId;
                              _memory.text = memory.text;
                              _memory.selection = TextSelection.collapsed(
                                offset: _memory.text.length,
                              );
                            }),
                          ),
                      const Divider(height: 28),
                      const Text(
                        'Rolling summary',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (data.summary == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('No summary has been rebuilt.'),
                        )
                      else
                        SelectableText(data.summary!.text),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(directChatProvider.notifier)
                                  .rebuildSummary();
                              if (mounted) setState(_reload);
                            },
                            child: const Text('Rebuild locally'),
                          ),
                          if (data.summary != null)
                            TextButton(
                              onPressed: () async {
                                await ref
                                    .read(directChatProvider.notifier)
                                    .clearSummary();
                                if (mounted) setState(_reload);
                              },
                              child: const Text('Clear summary'),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
