import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config_service.dart';
import '../../../core/ui_utils.dart';
import '../../common_widgets/auth_button.dart';
import '../auth/connection_notifier.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => SettingsViewState();
}

class SettingsViewState extends ConsumerState<SettingsView> {
  final _remoteIpController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _portController = TextEditingController();
  final _queryIpController = TextEditingController();
  final _queryPortController = TextEditingController();
  final _queryServerPortController = TextEditingController();
  final _queryUserController = TextEditingController();
  final _queryPassController = TextEditingController();

  Map<String, dynamic> _originalConf = {};
  String _language = 'zh';
  bool _autoConnectRemote = false;
  bool _autoConnectQuery = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _showToast(String message, {bool isError = false}) {
    UIUtils.showGlobalSnackbar(message, isError: isError);
  }

  Future<void> _load() async {
    final conf = await ConfigService.loadConfig();
    if (!mounted) return;
    _originalConf = Map<String, dynamic>.from(conf);
    setState(() {
      _remoteIpController.text = conf['remote_ip'] as String? ?? '127.0.0.1';
      _apiKeyController.text = conf['api_key'] as String? ?? '';
      _portController.text =
          ConfigService.portFromConfig(conf['port'], 5899).toString();
      _queryIpController.text = conf['query_ip'] as String? ?? '127.0.0.1';
      _queryPortController.text =
          ConfigService.portFromConfig(conf['query_port'], 10011).toString();
      _queryServerPortController.text =
          ConfigService.portFromConfig(conf['query_server_port'], 9987)
              .toString();
      _queryUserController.text = conf['query_user'] as String? ?? '';
      _queryPassController.text = conf['query_pass'] as String? ?? '';
      _language = conf['language'] as String? ?? 'zh';
      _autoConnectRemote = conf['auto_connect_remote'] as bool? ?? false;
      _autoConnectQuery = conf['auto_connect_query'] as bool? ?? false;
// _autoReconnect variables removed
    });
  }

  bool get hasUnsavedChanges {
    if (_originalConf.isEmpty) {
      return false;
    }
    if (_remoteIpController.text !=
        (_originalConf['remote_ip'] ?? '127.0.0.1')) {
      return true;
    }
    if (_apiKeyController.text != (_originalConf['api_key'] ?? '')) {
      return true;
    }
    if (ConfigService.parsePort(_portController.text) !=
        ConfigService.portFromConfig(_originalConf['port'], 5899)) {
      return true;
    }
    if (_queryIpController.text != (_originalConf['query_ip'] ?? '127.0.0.1')) {
      return true;
    }
    if (ConfigService.parsePort(_queryPortController.text) !=
        ConfigService.portFromConfig(_originalConf['query_port'], 10011)) {
      return true;
    }
    if (ConfigService.parsePort(_queryServerPortController.text) !=
        ConfigService.portFromConfig(
            _originalConf['query_server_port'], 9987)) {
      return true;
    }
    if (_queryUserController.text != (_originalConf['query_user'] ?? '')) {
      return true;
    }
    if (_queryPassController.text != (_originalConf['query_pass'] ?? '')) {
      return true;
    }
    if (_language != (_originalConf['language'] ?? 'zh')) {
      return true;
    }
    if (_autoConnectRemote != (_originalConf['auto_connect_remote'] ?? false)) {
      return true;
    }
    if (_autoConnectQuery != (_originalConf['auto_connect_query'] ?? false)) {
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _remoteIpController.dispose();
    _apiKeyController.dispose();
    _portController.dispose();
    _queryIpController.dispose();
    _queryPortController.dispose();
    _queryServerPortController.dispose();
    _queryUserController.dispose();
    _queryPassController.dispose();
    super.dispose();
  }

  Future<bool> saveConfig() {
    return _save();
  }

  void revertConfig() {
    setState(() {
      _remoteIpController.text =
          _originalConf['remote_ip'] as String? ?? '127.0.0.1';
      _apiKeyController.text = _originalConf['api_key'] as String? ?? '';
      _portController.text =
          ConfigService.portFromConfig(_originalConf['port'], 5899).toString();
      _queryIpController.text =
          _originalConf['query_ip'] as String? ?? '127.0.0.1';
      _queryPortController.text =
          ConfigService.portFromConfig(_originalConf['query_port'], 10011)
              .toString();
      _queryServerPortController.text =
          ConfigService.portFromConfig(_originalConf['query_server_port'], 9987)
              .toString();
      _queryUserController.text = _originalConf['query_user'] as String? ?? '';
      _queryPassController.text = _originalConf['query_pass'] as String? ?? '';
      _language = _originalConf['language'] as String? ?? 'zh';
      _autoConnectRemote =
          _originalConf['auto_connect_remote'] as bool? ?? false;
      _autoConnectQuery = _originalConf['auto_connect_query'] as bool? ?? false;
    });
    ref.read(languageProvider.notifier).set(_language);
  }

  Future<bool> _save() async {
    final newLang = _language;
    final remotePort = ConfigService.parsePort(_portController.text);
    final queryPort = ConfigService.parsePort(_queryPortController.text);
    final queryServerPort =
        ConfigService.parsePort(_queryServerPortController.text);
    if (remotePort == null || queryPort == null || queryServerPort == null) {
      _showToast(
        newLang == 'zh'
            ? '端口必须是 1 到 65535 之间的整数。'
            : 'Ports must be whole numbers between 1 and 65535.',
        isError: true,
      );
      return false;
    }

    try {
      final conf = await ConfigService.updateConfig((config) {
        config['remote_ip'] = _remoteIpController.text.trim();
        config['api_key'] = _apiKeyController.text;
        config['port'] = remotePort;
        config['query_ip'] = _queryIpController.text.trim();
        config['query_port'] = queryPort;
        config['query_server_port'] = queryServerPort;
        config['query_user'] = _queryUserController.text;
        config['query_pass'] = _queryPassController.text;
        config['language'] = newLang;
        config['auto_connect_remote'] = _autoConnectRemote;
        config['auto_connect_query'] = _autoConnectQuery;
      });
      _originalConf = Map<String, dynamic>.from(conf);
    } catch (error) {
      if (mounted) {
        _showToast(
          newLang == 'zh' ? '配置保存失败: $error' : 'Failed to save config: $error',
          isError: true,
        );
      }
      return false;
    }

    if (!mounted) return true;

    // Update global state
    ref.read(languageProvider.notifier).set(newLang);
    ref.read(autoConnectRemoteProvider.notifier).set(_autoConnectRemote);
    ref.read(autoConnectQueryProvider.notifier).set(_autoConnectQuery);

    _showToast(newLang == 'zh' ? '配置已保存！' : 'Config saved successfully!');
    return true;
  }

  Future<void> _connectTs() async {
    if (!await _save()) return;
    if (!mounted) return;
    await ref.read(connectionProvider.notifier).connectTs(
          _remoteIpController.text,
          ConfigService.parsePort(_portController.text)!,
          _apiKeyController.text,
        );
  }

  Future<void> _connectQuery() async {
    if (!await _save()) return;
    if (!mounted) return;
    await ref.read(connectionProvider.notifier).connectQuery(
          _queryIpController.text,
          ConfigService.parsePort(_queryPortController.text)!,
          ConfigService.parsePort(_queryServerPortController.text)!,
          _queryUserController.text,
          _queryPassController.text,
        );
  }

  Widget _connectionError(
    BuildContext context,
    String error,
    bool isZh,
  ) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        isZh ? '连接失败: $error' : 'Connection failed: $error',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isZh = _language == 'zh';
    final connection = ref.watch(connectionProvider);
    final remoteState = connection.tsState;
    final queryState = connection.queryState;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isZh ? '设置' : 'Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ListView(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(isZh ? '全局配置' : 'Global Configuration',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _language,
                              decoration: InputDecoration(
                                labelText: isZh ? '界面语言' : 'Language',
                                border: const OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'zh', child: Text('中文')),
                                DropdownMenuItem(
                                    value: 'en', child: Text('English')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _language = val);
                                  ref.read(languageProvider.notifier).set(val);
                                }
                              },
                            ),
                            const Divider(height: 32),
                            Text(
                                isZh
                                    ? 'Remote Apps 配置'
                                    : 'Remote Apps Configuration',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  isZh ? '状态: ' : 'Status: ',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  switch (remoteState) {
                                    AppConnectionState.connecting =>
                                      isZh ? '连接中' : 'Connecting',
                                    AppConnectionState.connected =>
                                      isZh ? '已连接' : 'Connected',
                                    AppConnectionState.error =>
                                      isZh ? '连接失败' : 'Connection failed',
                                    AppConnectionState.disconnected =>
                                      isZh ? '已断开' : 'Disconnected',
                                  },
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: remoteState ==
                                                AppConnectionState.connected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : remoteState ==
                                                    AppConnectionState
                                                        .connecting
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .secondary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                      ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: remoteState ==
                                          AppConnectionState.connecting
                                      ? null
                                      : remoteState ==
                                              AppConnectionState.connected
                                          ? () => ref
                                              .read(connectionProvider.notifier)
                                              .disconnectTs()
                                          : _connectTs,
                                  style: remoteState ==
                                          AppConnectionState.connected
                                      ? FilledButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .errorContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer,
                                        )
                                      : null,
                                  child: remoteState ==
                                          AppConnectionState.connecting
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(isZh ? '连接中' : 'Connecting'),
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(remoteState ==
                                              AppConnectionState.connected
                                          ? (isZh ? '断开' : 'Disconnect')
                                          : (isZh ? '连接' : 'Connect')),
                                ),
                              ],
                            ),
                            if (connection.tsError != null) ...[
                              const SizedBox(height: 8),
                              _connectionError(
                                context,
                                connection.tsError!,
                                isZh,
                              ),
                            ],
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: Text(isZh
                                  ? '启动时自动连接 Remote Apps'
                                  : 'Auto Connect Remote Apps on Startup'),
                              value: _autoConnectRemote,
                              onChanged: (val) {
                                setState(() => _autoConnectRemote = val);
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _remoteIpController,
                              decoration: InputDecoration(
                                labelText: isZh
                                    ? '远程 IP (默认: 127.0.0.1)'
                                    : 'Remote IP (Default: 127.0.0.1)',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _apiKeyController,
                                    decoration: InputDecoration(
                                      labelText: isZh ? 'API 密钥' : 'API Key',
                                      border: const OutlineInputBorder(),
                                    ),
                                    obscureText: true,
                                    onChanged: (v) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AuthButton(
                                  apiKeyController: _apiKeyController,
                                  ipController: _remoteIpController,
                                  portController: _portController,
                                  onAuthSuccess: () async {
                                    await _save();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _portController,
                              decoration: InputDecoration(
                                labelText: isZh
                                    ? 'Remote Apps 端口 (默认: 5899)'
                                    : 'Remote Apps Port (Default: 5899)',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const Divider(height: 32),
                            Text(
                                isZh
                                    ? 'ServerQuery 配置'
                                    : 'ServerQuery Configuration',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  isZh ? '状态: ' : 'Status: ',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  switch (queryState) {
                                    AppConnectionState.connecting =>
                                      isZh ? '连接中' : 'Connecting',
                                    AppConnectionState.connected =>
                                      isZh ? '已连接' : 'Connected',
                                    AppConnectionState.error =>
                                      isZh ? '连接失败' : 'Connection failed',
                                    AppConnectionState.disconnected =>
                                      isZh ? '已断开' : 'Disconnected',
                                  },
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: queryState ==
                                                AppConnectionState.connected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : queryState ==
                                                    AppConnectionState
                                                        .connecting
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .secondary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                      ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: queryState ==
                                          AppConnectionState.connecting
                                      ? null
                                      : queryState ==
                                              AppConnectionState.connected
                                          ? () => ref
                                              .read(connectionProvider.notifier)
                                              .disconnectQuery()
                                          : _connectQuery,
                                  style:
                                      queryState == AppConnectionState.connected
                                          ? FilledButton.styleFrom(
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .errorContainer,
                                              foregroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .onErrorContainer,
                                            )
                                          : null,
                                  child: queryState ==
                                          AppConnectionState.connecting
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(isZh ? '连接中' : 'Connecting'),
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(queryState ==
                                              AppConnectionState.connected
                                          ? (isZh ? '断开' : 'Disconnect')
                                          : (isZh ? '连接' : 'Connect')),
                                ),
                              ],
                            ),
                            if (connection.queryError != null) ...[
                              const SizedBox(height: 8),
                              _connectionError(
                                context,
                                connection.queryError!,
                                isZh,
                              ),
                            ],
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: Text(isZh
                                  ? '启动时自动连接 ServerQuery'
                                  : 'Auto Connect ServerQuery on Startup'),
                              value: _autoConnectQuery,
                              onChanged: (val) {
                                setState(() => _autoConnectQuery = val);
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _queryIpController,
                              decoration: InputDecoration(
                                labelText: isZh
                                    ? 'Query IP (默认: 127.0.0.1)'
                                    : 'Query IP (Default: 127.0.0.1)',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _queryPortController,
                              decoration: InputDecoration(
                                labelText: isZh
                                    ? 'Query 端口 (默认: 10011)'
                                    : 'Query Port (Default: 10011)',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _queryServerPortController,
                              decoration: InputDecoration(
                                labelText: isZh
                                    ? '虚拟服务器端口 (默认: 9987)'
                                    : 'Virtual Server Port (Default: 9987)',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _queryUserController,
                              decoration: InputDecoration(
                                labelText: isZh
                                    ? 'Query 用户名 (如: serveradmin)'
                                    : 'Query Username (e.g. serveradmin)',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _queryPassController,
                              decoration: InputDecoration(
                                labelText: isZh ? 'Query 密码' : 'Query Password',
                                border: const OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.save),
                                label:
                                    Text(isZh ? '保存配置' : 'Save Configuration'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 16),
                                ),
                                onPressed: _save,
                              ),
                            ),
                            const SizedBox(
                                height:
                                    32), // Add bottom padding to prevent cutoff
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
