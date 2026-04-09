import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_tsm/src/rust/api.dart' as rust_api;

import 'package:re_tsm/core/ui_utils.dart';

enum AppConnectionState { disconnected, connecting, connected, error, testing }

class ConnectionStatus {
  final AppConnectionState tsState;
  final AppConnectionState queryState;
  final String? tsError;
  final String? queryError;

  const ConnectionStatus({
    this.tsState = AppConnectionState.disconnected,
    this.queryState = AppConnectionState.disconnected,
    this.tsError,
    this.queryError,
  });

  ConnectionStatus copyWith({
    AppConnectionState? tsState,
    AppConnectionState? queryState,
    String? tsError,
    String? queryError,
  }) {
    return ConnectionStatus(
      tsState: tsState ?? this.tsState,
      queryState: queryState ?? this.queryState,
      tsError: tsError ?? this.tsError,
      queryError: queryError ?? this.queryError,
    );
  }
}

class ConnectionNotifier extends Notifier<ConnectionStatus> {
  StreamSubscription<String>? _tsSubscription;

  @override
  ConnectionStatus build() {
    return const ConnectionStatus();
  }

  Future<void> connectTs(String ip, int port, String apiKey) async {
    state =
        state.copyWith(tsState: AppConnectionState.connecting, tsError: null);
    try {
      _tsSubscription?.cancel();

      final stream =
          rust_api.startTsConnection(ip: ip, port: port, apiKey: apiKey);

      _tsSubscription = stream.listen((data) {
        if (state.tsState != AppConnectionState.connected) {
          state = state.copyWith(tsState: AppConnectionState.connected);
          UIUtils.showGlobalSnackbar(
              'Connected to TS Remote Apps successfully.');
        }
      }, onError: (e) {
        state = state.copyWith(
            tsState: AppConnectionState.error, tsError: e.toString());
        UIUtils.showGlobalSnackbar('TS Connection Error: $e');
      }, onDone: () {
        state = state.copyWith(tsState: AppConnectionState.disconnected);
        UIUtils.showGlobalSnackbar('TS Connection closed.');
      });
    } catch (e) {
      state = state.copyWith(
          tsState: AppConnectionState.error, tsError: e.toString());
      UIUtils.showGlobalSnackbar('TS Connection Failed: $e');
    }
  }

  Future<void> connectQuery(
      String ip, int port, String user, String pass) async {
    state = state.copyWith(
        queryState: AppConnectionState.connecting, queryError: null);
    try {
      await rust_api.connectQuery(ip: ip, port: port, user: user, pass: pass);
      state = state.copyWith(queryState: AppConnectionState.connected);
      UIUtils.showGlobalSnackbar('Connected to Query Server successfully.');
    } catch (e) {
      state = state.copyWith(
          queryState: AppConnectionState.error, queryError: e.toString());
      UIUtils.showGlobalSnackbar('Query Connection Failed: $e');
    }
  }

  Future<bool> testQueryConnection(
      String ip, int port, String user, String pass) async {
    final previousState = state.queryState;
    final previousError = state.queryError;

    state = state.copyWith(
        queryState: AppConnectionState.testing, queryError: null);

    try {
      await rust_api.connectQuery(ip: ip, port: port, user: user, pass: pass);

      state =
          state.copyWith(queryState: previousState, queryError: previousError);

      UIUtils.showGlobalSnackbar('Connection Test: Success (Connected to API)');
      return true;
    } catch (e) {
      state =
          state.copyWith(queryState: previousState, queryError: previousError);
      UIUtils.showGlobalSnackbar('Connection Test Exception: $e');
      return false;
    }
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, ConnectionStatus>(
        ConnectionNotifier.new);
