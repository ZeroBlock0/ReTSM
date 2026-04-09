import 'package:flutter_riverpod/flutter_riverpod.dart';

final initialConfigProvider = Provider<Map<String, dynamic>>((ref) {
  return {
    'serverIp': '127.0.0.1',
    'queryPort': 10011,
    'queryPassword': 'password',
  };
});
