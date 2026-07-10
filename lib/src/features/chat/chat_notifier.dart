import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/connection_notifier.dart';

class ChatMessage {
  final String senderName;
  final String content;
  final int timestamp;

  const ChatMessage({
    required this.senderName,
    required this.content,
    required this.timestamp,
  });
}

class ChatNotifier extends Notifier<List<ChatMessage>> {
  static const int _maximumMessages = 500;

  @override
  List<ChatMessage> build() {
    ref.listen<AsyncValue<String>>(tsEventsProvider, (previous, next) {
      if (next case AsyncData<String>(:final value)) {
        _processEvent(value);
      }
    }, fireImmediately: true);
    return [];
  }

  void _processEvent(String event) {
    try {
      final json = jsonDecode(event) as Map<String, dynamic>;
      if (json['type'] != 'textMessage') return;

      final payload = json['payload'] as Map<String, dynamic>?;
      if (payload == null) return;

      final sender = payload['invokerName']?.toString() ??
          (payload['invoker'] as Map<String, dynamic>?)?['name']?.toString() ??
          payload['senderName']?.toString() ??
          (payload['sender'] as Map<String, dynamic>?)?['name']?.toString() ??
          'Unknown';
      final content = payload['message']?.toString() ?? '';
      final nextState = [
        ...state,
        ChatMessage(
          senderName: sender,
          content: content,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      ];
      state = nextState.length > _maximumMessages
          ? nextState.sublist(nextState.length - _maximumMessages)
          : nextState;
    } catch (_) {
      // Ignore malformed or non-chat Remote Apps events.
    }
  }

  void clear() => state = [];
}

final chatProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);
