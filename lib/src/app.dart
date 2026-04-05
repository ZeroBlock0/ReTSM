import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'features/home/home_screen.dart';

import '../../main.dart';

class ReTSMApp extends StatelessWidget {
  const ReTSMApp({super.key});

  @override
  Widget build(BuildContext context) {
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
          home: const HomeScreen(),
        );
      },
    );
  }
}
