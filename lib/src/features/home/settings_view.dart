import 'package:flutter/material.dart';
import '../../../core/config_service.dart';
import '../../../core/ui_utils.dart';
import '../../common_widgets/auth_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_view.dart';
import 'server_admin_view.dart';

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
    _originalConf = Map<String, dynamic>.from(conf);
    setState(() {
      _remoteIpController.text = conf['remote_ip'] as String? ?? '127.0.0.1';
      _apiKeyController.text = conf['api_key'] as String? ?? '';
      _portController.text = (conf['port'] as int? ?? 5899).toString();
      _queryIpController.text = conf['query_ip'] as String? ?? '127.0.0.1';
      _queryPortController.text =
          (conf['query_port'] as int? ?? 10011).toString();
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
    if ((int.tryParse(_portController.text) ?? 5899) !=
        (_originalConf['port'] ?? 5899)) {
      return true;
    }
    if (_queryIpController.text != (_originalConf['query_ip'] ?? '127.0.0.1')) {
      return true;
    }
    if ((int.tryParse(_queryPortController.text) ?? 10011) !=
        (_originalConf['query_port'] ?? 10011)) {
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

  Future<void> saveConfig() async {
    await _save();
  }

  void revertConfig() {
    setState(() {
      _remoteIpController.text =
          _originalConf['remote_ip'] as String? ?? '127.0.0.1';
      _apiKeyController.text = _originalConf['api_key'] as String? ?? '';
      _portController.text = (_originalConf['port'] as int? ?? 5899).toString();
      _queryIpController.text =
          _originalConf['query_ip'] as String? ?? '127.0.0.1';
      _queryPortController.text =
          (_originalConf['query_port'] as int? ?? 10011).toString();
      _queryUserController.text = _originalConf['query_user'] as String? ?? '';
      _queryPassController.text = _originalConf['query_pass'] as String? ?? '';
      _language = _originalConf['language'] as String? ?? 'zh';
      _autoConnectRemote =
          _originalConf['auto_connect_remote'] as bool? ?? false;
      _autoConnectQuery = _originalConf['auto_connect_query'] as bool? ?? false;
    });
    ref.read(languageProvider.notifier).set(_language);
  }

  Future<void> _save() async {
    final newLang = _language;
    final conf = await ConfigService.loadConfig();

    conf['remote_ip'] = _remoteIpController.text;
    conf['api_key'] = _apiKeyController.text;
    conf['port'] = int.tryParse(_portController.text) ?? 5899;
    conf['query_ip'] = _queryIpController.text;
    conf['query_port'] = int.tryParse(_queryPortController.text) ?? 10011;
    conf['query_user'] = _queryUserController.text;
    conf['query_pass'] = _queryPassController.text;
    conf['language'] = newLang;
    conf['auto_connect_remote'] = _autoConnectRemote;
    conf['auto_connect_query'] = _autoConnectQuery;

    await ConfigService.saveConfig(conf);
    _originalConf = Map<String, dynamic>.from(conf);

    // Update global state
    ref.read(languageProvider.notifier).set(newLang);
    ref.read(autoConnectRemoteProvider.notifier).set(_autoConnectRemote);
    ref.read(autoConnectQueryProvider.notifier).set(_autoConnectQuery);

    if (!mounted) return;
    _showToast(newLang == 'zh' ? '配置已保存！' : 'Config saved successfully!');
  }

  @override
  Widget build(BuildContext context) {
    final isZh = _language == 'zh';
    final isRemoteConnected = ref.watch(remoteAppActualConnectionProvider);
    final isQueryConnected = ref.watch(serverAdminProvider).isConnected;

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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  isRemoteConnected
                                      ? (isZh ? '已连接' : 'Connected')
                                      : (isZh ? '已断开' : 'Disconnected'),
                                  style: TextStyle(
                                    color: isRemoteConnected
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: () {
                                    ref
                                        .read(remoteAppConnectionProvider
                                            .notifier)
                                        .set(!isRemoteConnected);
                                  },
                                  style: isRemoteConnected
                                      ? FilledButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .errorContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer,
                                        )
                                      : null,
                                  child: Text(isRemoteConnected
                                      ? (isZh ? '断开' : 'Disconnect')
                                      : (isZh ? '连接' : 'Connect')),
                                ),
                              ],
                            ),
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
                                  onAuthSuccess: _save,
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  isQueryConnected
                                      ? (isZh ? '已连接' : 'Connected')
                                      : (isZh ? '已断开' : 'Disconnected'),
                                  style: TextStyle(
                                    color: isQueryConnected
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: () {
                                    if (isQueryConnected) {
                                      ref
                                          .read(serverAdminProvider.notifier)
                                          .disconnect(
                                              isZh ? '已断开' : 'Disconnected');
                                    } else {
                                      ref
                                          .read(serverAdminProvider.notifier)
                                          .connect(isZh
                                              ? '连接中...'
                                              : 'Connecting...');
                                    }
                                  },
                                  style: isQueryConnected
                                      ? FilledButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .errorContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer,
                                        )
                                      : null,
                                  child: Text(isQueryConnected
                                      ? (isZh ? '断开' : 'Disconnect')
                                      : (isZh ? '连接' : 'Connect')),
                                ),
                              ],
                            ),
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
