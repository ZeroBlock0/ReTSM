import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_tsm/src/rust/api.dart' as rust_api;
import 'package:re_tsm/src/rust/models/user.dart';

class UsersState {
  final List<TsUser> users;
  final bool isLoading;
  final String? error;

  const UsersState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  UsersState copyWith({
    List<TsUser>? users,
    bool? isLoading,
    String? error,
  }) {
    return UsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class UsersNotifier extends Notifier<UsersState> {
  Timer? _refreshTimer;

  @override
  UsersState build() {
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });
    Future.microtask(_startAutoRefresh);
    return const UsersState(isLoading: true);
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _fetchUsers();
    // Refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchUsers();
    });
  }

  Future<void> _fetchUsers() async {
    try {
      final usersList = await rust_api.queryGetUsers();
      state = state.copyWith(users: usersList, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _fetchUsers();
  }
}

final usersProvider = NotifierProvider<UsersNotifier, UsersState>(
  UsersNotifier.new,
);
