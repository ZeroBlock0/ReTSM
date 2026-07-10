import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_tsm/src/rust/api.dart' as rust_api;

import '../auth/connection_notifier.dart';

class UsersState {
  final List<rust_api.TsUser> users;
  final bool isLoading;
  final String? error;

  const UsersState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  UsersState copyWith({
    List<rust_api.TsUser>? users,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return UsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class UsersNotifier extends Notifier<UsersState> {
  Timer? _refreshTimer;
  bool _fetchInProgress = false;

  @override
  UsersState build() {
    final connection = ref.watch(connectionProvider);
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });
    ref.listen<ConnectionStatus>(connectionProvider, (previous, next) {
      _syncWithQueryConnection(next.queryState);
    });
    Future.microtask(() => _syncWithQueryConnection(connection.queryState));
    return const UsersState();
  }

  void _syncWithQueryConnection(AppConnectionState queryState) {
    if (queryState == AppConnectionState.connected) {
      _startAutoRefresh();
      return;
    }
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _fetchInProgress = false;
    if (state.isLoading || state.error != null) {
      state = state.copyWith(isLoading: false, clearError: true);
    }
  }

  void _startAutoRefresh() {
    if (_refreshTimer != null) return;
    _refreshTimer?.cancel();
    unawaited(_fetchUsers());
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_fetchUsers());
    });
  }

  Future<void> _fetchUsers() async {
    if (_fetchInProgress) return;
    _fetchInProgress = true;
    try {
      final usersList = await rust_api.queryGetUsers();
      state = state.copyWith(
        users: usersList,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(error: error.toString(), isLoading: false);
      unawaited(
        ref.read(connectionProvider.notifier).refreshQueryConnectionState(),
      );
    } finally {
      _fetchInProgress = false;
    }
  }

  Future<void> refresh() async {
    if (ref.read(connectionProvider).queryState !=
        AppConnectionState.connected) {
      state = state.copyWith(
        isLoading: false,
        error: 'Connect to ServerQuery before refreshing users.',
      );
      return;
    }
    state = state.copyWith(isLoading: true);
    await _fetchUsers();
  }
}

final usersProvider = NotifierProvider<UsersNotifier, UsersState>(
  UsersNotifier.new,
);
