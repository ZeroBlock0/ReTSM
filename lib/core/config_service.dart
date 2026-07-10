import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final initialConfigProvider = Provider<Map<String, dynamic>>((ref) => {});

class LanguageNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.watch(initialConfigProvider)['language'] as String? ?? 'zh';
  void set(String val) => state = val;
}

final languageProvider =
    NotifierProvider<LanguageNotifier, String>(LanguageNotifier.new);

class EventAutoClearSecondsNotifier extends Notifier<int> {
  @override
  int build() =>
      ref.watch(initialConfigProvider)['event_auto_clear_seconds'] as int? ?? 0;
  void set(int val) => state = val;
}

final eventAutoClearSecondsProvider =
    NotifierProvider<EventAutoClearSecondsNotifier, int>(
        EventAutoClearSecondsNotifier.new);

class EventAutoScrollNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(initialConfigProvider)['event_auto_scroll'] as bool? ?? true;
  void set(bool val) => state = val;
}

final eventAutoScrollProvider = NotifierProvider<EventAutoScrollNotifier, bool>(
    EventAutoScrollNotifier.new);

class AutoConnectRemoteNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(initialConfigProvider)['auto_connect_remote'] as bool? ?? false;
  void set(bool val) => state = val;
}

final autoConnectRemoteProvider =
    NotifierProvider<AutoConnectRemoteNotifier, bool>(
        AutoConnectRemoteNotifier.new);

class AutoConnectQueryNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(initialConfigProvider)['auto_connect_query'] as bool? ?? false;
  void set(bool val) => state = val;
}

final autoConnectQueryProvider =
    NotifierProvider<AutoConnectQueryNotifier, bool>(
        AutoConnectQueryNotifier.new);

class ConfigService {
  static const String _fileName = 'config.json';
  static Future<void> _operationQueue = Future<void>.value();

  // Gets the portable path in the same directory as the executable
  static String get _configPath {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir${Platform.pathSeparator}$_fileName';
  }

  static Map<String, dynamic> defaultConfig() {
    return <String, dynamic>{
      'remote_ip': '127.0.0.1',
      'api_key': '',
      'port': 5899,
      'query_ip': '127.0.0.1',
      'query_port': 10011,
      'query_server_port': 9987,
      'query_user': '',
      'query_pass': '',
      'language': 'zh',
      'event_auto_clear_seconds': 0,
      'event_auto_scroll': true,
      'auto_connect_remote': false,
      'auto_connect_query': false,
      'query_auto_clear': false,
      'query_auto_scroll': true,
    };
  }

  static int? parsePort(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 1 || parsed > 65535) {
      return null;
    }
    return parsed;
  }

  static int portFromConfig(Object? value, int fallback) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed >= 1 && parsed <= 65535 ? parsed : fallback;
  }

  static Future<Map<String, dynamic>> loadConfig() async {
    return _serialize(_loadConfig);
  }

  static Future<void> saveConfig(Map<String, dynamic> config) {
    return _serialize(() => _saveConfig(config));
  }

  static Future<Map<String, dynamic>> updateConfig(
    void Function(Map<String, dynamic> config) update,
  ) {
    return _serialize(() async {
      final config = await _loadConfig();
      update(config);
      await _saveConfig(config);
      return config;
    });
  }

  static Future<T> _serialize<T>(Future<T> Function() operation) {
    final next = _operationQueue.then((_) => operation());
    _operationQueue = next.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return next;
  }

  static Future<Map<String, dynamic>> _loadConfig() async {
    final defaults = defaultConfig();
    try {
      final file = File(_configPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          return <String, dynamic>{
            ...defaults,
            ...Map<String, dynamic>.from(decoded),
          };
        }
      }
    } on FileSystemException catch (_) {
      return defaults;
    } on FormatException catch (_) {
      return defaults;
    }
    return defaults;
  }

  static Future<void> _saveConfig(Map<String, dynamic> config) async {
    final file = File(_configPath);
    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(jsonEncode(config), flush: true);
    try {
      await temporaryFile.rename(file.path);
    } on FileSystemException {
      if (await file.exists()) {
        await file.delete();
      }
      await temporaryFile.rename(file.path);
    }
  }
}
