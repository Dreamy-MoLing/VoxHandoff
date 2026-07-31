import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ChatSource { hermes, directLlm }

final chatSourceProvider = NotifierProvider<ChatSourceController, ChatSource>(
  ChatSourceController.new,
);

class ChatSourceController extends Notifier<ChatSource> {
  @override
  ChatSource build() => ChatSource.hermes;
  void select(ChatSource source) => state = source;
}
