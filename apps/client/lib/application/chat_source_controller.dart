import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../domain/confirmed_draft.dart' show ChatSource;

import '../domain/confirmed_draft.dart';
import 'client_session_controller.dart';
import 'direct_chat_controller.dart';

final chatSourceProvider = NotifierProvider<ChatSourceController, ChatSource>(
  ChatSourceController.new,
);

class ChatSourceController extends Notifier<ChatSource> {
  @override
  ChatSource build() => ChatSource.hermes;
  Future<void> select(ChatSource source) async {
    if (state != source) {
      ref.read(clientSessionProvider.notifier).invalidateConfirmation();
      await ref.read(directChatProvider.notifier).cancelForContextChange();
    }
    state = source;
  }
}
