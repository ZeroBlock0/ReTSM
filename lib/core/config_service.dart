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
  static final String _fileName = 'config.json';

  // Gets the portable path in the same directory as the executable
  static String get _configPath {
    final exeDir = Directory.current.path;
    return '$exeDir${Platform.pathSeparator}$_fileName';
  }

  static Future<Map<String, dynamic>> loadConfig() async {
    try {
      final file = File(_configPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content);
      }
    } catch (e) {
      // Failed to load config
    }
    // Return default config
    return {
      'remote_ip': '127.0.0.1',
      'api_key': '',
      'port': 5899,
      'query_ip': '127.0.0.1',
      'query_port': 10011,
      'query_user': '',
      'query_pass': '',
      'language': 'zh',
      'event_auto_clear_seconds': 0,
      'event_auto_scroll': true,
      'auto_connect_remote': false,
      'auto_connect_query': false,
    };
  }

  static Future<void> saveConfig(Map<String, dynamic> config) async {
    try {
      final file = File(_configPath);
      await file.writeAsString(jsonEncode(config));
    } catch (e) {
      // Failed to save config
    }
  }
}
