import 'package:flutter_test/flutter_test.dart';
import 'package:re_tsm/core/config_service.dart';

void main() {
  group('ConfigService port handling', () {
    test('accepts valid TCP and UDP port boundaries', () {
      expect(ConfigService.parsePort('1'), 1);
      expect(ConfigService.parsePort('65535'), 65535);
    });

    test('rejects invalid port values', () {
      expect(ConfigService.parsePort('0'), isNull);
      expect(ConfigService.parsePort('65536'), isNull);
      expect(ConfigService.parsePort('not-a-port'), isNull);
    });

    test('falls back when persisted port values are invalid', () {
      expect(ConfigService.portFromConfig('5899', 1), 5899);
      expect(ConfigService.portFromConfig(0, 9987), 9987);
      expect(ConfigService.portFromConfig(null, 10011), 10011);
    });
  });

  test('defaults include the configurable virtual server port', () {
    expect(ConfigService.defaultConfig()['query_server_port'], 9987);
  });
}
