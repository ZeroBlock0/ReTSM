import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_tsm/src/rust/api.dart' as rust_api;
import 'package:re_tsm/src/rust/models/chat.dart';

class ChatNotifier extends Notifier<List<ChatMessage>> {
  Timer? _refreshTimer;

  @override
  List<ChatMessage> build() {
    Future.microtask(() {
      _startAutoRefresh();
      _fetchMessages();
    });
    return [];
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    // Poll the rust backend for new messages every 1 second
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchMessages();
    });
  }

  Future<void> _fetchMessages() async {
    try {
      final msgs = await rust_api.getChatMessages();
      // Only update state if length changed to avoid unnecessary rebuilds
      if (msgs.length != state.length) {
        state = msgs;
      }
    } catch (e) {
      // Failed to fetch, ignore silently
    }
  }

  Future<void> sendMessage(String text) async {
    try {
      await rust_api.sendTsMessage(payload: text);
    } catch (e) {
      // Error handled by caller or silently
    }
  }

  void clear() {
    state = [];
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);
