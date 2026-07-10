import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_tsm/core/config_service.dart';
import 'package:re_tsm/core/ui_utils.dart';
import 'package:re_tsm/src/rust/api.dart' as rust_api;

enum AppConnectionState { disconnected, connecting, connected, error }

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
    bool clearTsError = false,
    bool clearQueryError = false,
  }) {
    return ConnectionStatus(
      tsState: tsState ?? this.tsState,
      queryState: queryState ?? this.queryState,
      tsError: clearTsError ? null : tsError ?? this.tsError,
      queryError: clearQueryError ? null : queryError ?? this.queryError,
    );
  }
}

class ConnectionNotifier extends Notifier<ConnectionStatus> {
  StreamSubscription<String>? _tsSubscription;
  final StreamController<String> _tsEvents = StreamController.broadcast();
  Timer? _tsAuthorizationTimer;

  Stream<String> get tsEvents => _tsEvents.stream;

  @override
  ConnectionStatus build() {
    ref.onDispose(() {
      unawaited(_stopTsTransport());
      unawaited(_tsEvents.close());
    });
    Future.microtask(_connectAutomatically);
    return const ConnectionStatus();
  }

  Future<void> _connectAutomatically() async {
    final config = await ConfigService.loadConfig();
    if (config['auto_connect_remote'] == true) {
      await connectTsFromConfig();
    }
    if (config['auto_connect_query'] == true) {
      await connectQueryFromConfig();
    }
  }

  Future<void> connectTsFromConfig() async {
    final config = await ConfigService.loadConfig();
    await connectTs(
      config['remote_ip'] as String? ?? '127.0.0.1',
      ConfigService.portFromConfig(config['port'], 5899),
      config['api_key'] as String? ?? '',
    );
  }

  Future<void> connectQueryFromConfig() async {
    final config = await ConfigService.loadConfig();
    await connectQuery(
      config['query_ip'] as String? ?? '127.0.0.1',
      ConfigService.portFromConfig(config['query_port'], 10011),
      ConfigService.portFromConfig(config['query_server_port'], 9987),
      config['query_user'] as String? ?? '',
      config['query_pass'] as String? ?? '',
    );
  }

  Future<void> connectTs(String ip, int port, String apiKey) async {
    if (state.tsState == AppConnectionState.connecting) return;

    state = state.copyWith(
      tsState: AppConnectionState.connecting,
      clearTsError: true,
    );
    if (ip.trim().isEmpty || port < 1 || port > 65535) {
      _setTsError('A valid Remote Apps address and port are required.');
      return;
    }
    UIUtils.showGlobalSnackbar('Connecting to TS Remote Apps...');
    await _stopTsTransport();

    if (apiKey.isEmpty) {
      _setTsError('No API key configured.');
      return;
    }

    _tsSubscription = rust_api
        .startTsConnection(ip: ip, port: port, apiKey: apiKey)
        .listen(_handleTsEvent, onError: _setTsError, onDone: _handleTsDone);
    _tsAuthorizationTimer = Timer(const Duration(seconds: 15), () {
      if (state.tsState == AppConnectionState.connecting) {
        _setTsError('Timed out while waiting for Remote Apps authorization.');
        unawaited(_stopTsTransport());
      }
    });
  }

  void _handleTsEvent(String event) {
    if (!_tsEvents.isClosed) {
      _tsEvents.add(event);
    }
    try {
      final payload = jsonDecode(event) as Map<String, dynamic>;
      if (payload['type'] == 'error') {
        _setTsError(payload['message']?.toString() ?? 'Remote Apps error.');
      } else if (payload['type'] == 'connection' &&
          payload['status'] == 'authorized') {
        _tsAuthorizationTimer?.cancel();
        state = state.copyWith(
          tsState: AppConnectionState.connected,
          clearTsError: true,
        );
        UIUtils.showGlobalSnackbar('Connected to TS Remote Apps successfully.');
      }
    } catch (_) {
      // Keep non-JSON Remote Apps events visible in the dashboard.
    }
  }

  void _handleTsDone() {
    _tsAuthorizationTimer?.cancel();
    if (state.tsState == AppConnectionState.connecting) {
      _setTsError('Remote Apps connection closed before authorization.');
      return;
    }
    if (state.tsState == AppConnectionState.connected) {
      state = state.copyWith(tsState: AppConnectionState.disconnected);
      UIUtils.showGlobalSnackbar('TS Remote Apps connection closed.');
    }
  }

  void _setTsError(Object error) {
    _tsAuthorizationTimer?.cancel();
    final message = error.toString();
    state = state.copyWith(
      tsState: AppConnectionState.error,
      tsError: message,
    );
    UIUtils.showGlobalSnackbar('TS Connection Error: $message', isError: true);
  }

  Future<void> disconnectTs() async {
    await _stopTsTransport();
    state = state.copyWith(
      tsState: AppConnectionState.disconnected,
      clearTsError: true,
    );
    UIUtils.showGlobalSnackbar('TS Remote Apps disconnected.');
  }

  Future<void> _stopTsTransport() async {
    _tsAuthorizationTimer?.cancel();
    _tsAuthorizationTimer = null;
    await _tsSubscription?.cancel();
    _tsSubscription = null;
    try {
      await rust_api.disconnectTs();
    } catch (_) {
      // The transport may already be closed; the next connection starts cleanly.
    }
  }

  Future<void> connectQuery(
    String ip,
    int port,
    int virtualServerPort,
    String user,
    String pass,
  ) async {
    if (state.queryState == AppConnectionState.connecting) return;

    if (ip.trim().isEmpty ||
        port < 1 ||
        port > 65535 ||
        virtualServerPort < 1 ||
        virtualServerPort > 65535) {
      final message = 'A valid ServerQuery address and ports are required.';
      state = state.copyWith(
        queryState: AppConnectionState.error,
        queryError: message,
      );
      UIUtils.showGlobalSnackbar(message, isError: true);
      return;
    }

    state = state.copyWith(
      queryState: AppConnectionState.connecting,
      clearQueryError: true,
    );
    UIUtils.showGlobalSnackbar('Connecting to ServerQuery...');
    try {
      await rust_api.connectQuery(
        ip: ip,
        port: port,
        virtualServerPort: virtualServerPort,
        user: user,
        pass: pass,
      );
      state = state.copyWith(
        queryState: AppConnectionState.connected,
        clearQueryError: true,
      );
      UIUtils.showGlobalSnackbar('Connected to ServerQuery successfully.');
    } catch (error) {
      final message = error.toString();
      state = state.copyWith(
        queryState: AppConnectionState.error,
        queryError: message,
      );
      UIUtils.showGlobalSnackbar(
        'ServerQuery Connection Error: $message',
        isError: true,
      );
    }
  }

  Future<void> disconnectQuery() async {
    try {
      await rust_api.queryDisconnect();
      state = state.copyWith(
        queryState: AppConnectionState.disconnected,
        clearQueryError: true,
      );
      UIUtils.showGlobalSnackbar('ServerQuery disconnected.');
    } catch (error) {
      state = state.copyWith(
        queryState: AppConnectionState.error,
        queryError: error.toString(),
      );
    }
  }

  Future<void> refreshQueryConnectionState() async {
    if (state.queryState != AppConnectionState.connected) return;
    if (await rust_api.queryIsConnected()) return;

    const message = 'ServerQuery connection closed unexpectedly.';
    state = state.copyWith(
      queryState: AppConnectionState.disconnected,
      queryError: message,
    );
    UIUtils.showGlobalSnackbar(message, isError: true);
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, ConnectionStatus>(
  ConnectionNotifier.new,
);

final tsEventsProvider = StreamProvider<String>((ref) {
  return ref.read(connectionProvider.notifier).tsEvents;
});
