import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_tsm/src/rust/frb_generated.dart';
import 'src/app.dart';
import 'core/config_service.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  // Wait for Flutter initialization
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the rust-dart bridge
  await RustLib.init();

  // Load initial config
  final config = await ConfigService.loadConfig();

  runApp(
    ProviderScope(
      overrides: [
        initialConfigProvider.overrideWithValue(config),
      ],
      child: const ReTSMApp(),
    ),
  );
}
