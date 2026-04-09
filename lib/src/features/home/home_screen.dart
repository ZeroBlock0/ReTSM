import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config_service.dart';

import 'dashboard_view.dart';
import 'chat_view.dart';
import 'server_admin_view.dart';
import 'settings_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final GlobalKey<SettingsViewState> _settingsKey =
      GlobalKey<SettingsViewState>();
  int _selectedIndex = 0;
  late final List<Widget> _views;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _views = [
      const DashboardView(),
      const ChatView(),
      const ServerAdminView(),
      SettingsView(key: _settingsKey),
    ];
    // Eagerly initialize providers so they start accumulating events in the background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider);
      ref.read(chatProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<bool?> _showUnsavedDialog() async {
    final isZh = ref.read(languageProvider) == 'zh';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isZh ? '未保存的更改' : 'Unsaved Changes'),
        content: Text(isZh
            ? '您有未保存的配置更改。要保存吗？'
            : 'You have unsaved configuration changes. Do you want to save?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(isZh ? '取消' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isZh ? '放弃' : 'Discard',
                style: const TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isZh ? '保存' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    final settingsState = _settingsKey.currentState;
    if (settingsState != null && settingsState.hasUnsavedChanges) {
      final result = await _showUnsavedDialog();
      if (result == null) return AppExitResponse.cancel;
      if (result == true) {
        await settingsState.saveConfig();
      }
    }
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final isZh = language == 'zh';

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) async {
              if (_selectedIndex == 3 && index != 3) {
                final settingsState = _settingsKey.currentState;
                if (settingsState != null && settingsState.hasUnsavedChanges) {
                  final result = await _showUnsavedDialog();
                  if (result == null) return;
                  if (result == true) {
                    await settingsState.saveConfig();
                  } else {
                    settingsState.revertConfig();
                  }
                }
              }
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.list_alt_outlined),
                selectedIcon: const Icon(Icons.list_alt),
                label: Text(isZh ? '日志' : 'Log'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.chat_bubble_outline),
                selectedIcon: const Icon(Icons.chat_bubble),
                label: Text(isZh ? '聊天' : 'Chat'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: const Icon(Icons.admin_panel_settings),
                label: Text(isZh ? '服务器管理' : 'Admin'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: Text(isZh ? '设置' : 'Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main content
          Expanded(
            child: _views[_selectedIndex],
          )
        ],
      ),
    );
  }
}
