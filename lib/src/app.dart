import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import '../core/config_service.dart';

import '../../main.dart';

class ReTSMApp extends ConsumerWidget {
  const ReTSMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          // On Windows, Linux, macOS (if supported by the package), or Android 12+
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // Fallback if dynamic color isn't available
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            dynamicSchemeVariant: DynamicSchemeVariant.expressive,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
            dynamicSchemeVariant: DynamicSchemeVariant.expressive,
          );
        }

        final config = ref.read(initialConfigProvider);
        final hasConfig = (config['query_user']?.toString() ?? '').isNotEmpty ||
            (config['api_key']?.toString() ?? '').isNotEmpty;

        return MaterialApp(
          navigatorKey: globalNavigatorKey,
          title: 'ReTSM Dashboard',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            fontFamily: 'Google Sans Flex',
            fontFamilyFallback: const ['Noto Sans SC'],
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            fontFamily: 'Google Sans Flex',
            fontFamilyFallback: const ['Noto Sans SC'],
          ),
          themeMode: ThemeMode.system,
          home: hasConfig ? const HomeScreen() : const LoginScreen(),
        );
      },
    );
  }
}
