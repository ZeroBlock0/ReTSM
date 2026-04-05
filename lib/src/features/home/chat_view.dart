import 'package:re_tsm/core/config_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/expressive_empty_state.dart';
import 'dashboard_view.dart';

class ChatMessage {
  final String sender;
  final String text;
  final DateTime time;

  ChatMessage({required this.sender, required this.text, required this.time});
}

class ChatNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() {
    ref.listen<AsyncValue<String>>(tsEventsProvider, (previous, next) {
      if (next is AsyncData && next.value != null) {
        processEvent(next.value!);
      }
    }, fireImmediately: true);
    return [];
  }

  void processEvent(String eventStr) {
    try {
      final json = jsonDecode(eventStr);
      if (json['type'] == 'textMessage') {
        final payload = json['payload'];
        final invoker = payload['invokerName'] ??
            payload['invoker']?['name'] ??
            payload['senderName'] ??
            payload['sender']?['name'] ??
            'Unknown';
        final text = payload['message'] ?? '';
        state = [
          ...state,
          ChatMessage(sender: invoker, text: text, time: DateTime.now())
        ];
      }
    } catch (_) {}
  }

  void clear() {
    state = [];
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, List<ChatMessage>>(ChatNotifier.new);

class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final language = ref.watch(languageProvider);
    final isZh = language == 'zh';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isZh ? '聊天' : 'Chat',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: isZh ? '清空聊天' : 'Clear Chat',
                onPressed: () {
                  ref.read(chatProvider.notifier).clear();
                },
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: messages.isEmpty
                  ? ExpressiveEmptyState(
                      message: isZh ? '暂无消息...' : 'No messages yet...',
                      icon: Icons.chat_bubble_outline_rounded,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final timeStr =
                            "${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}";
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        msg.sender,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeStr,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(msg.text),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
