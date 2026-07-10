import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_tsm/core/config_service.dart';
import 'package:re_tsm/core/ui_utils.dart';
import 'package:re_tsm/src/features/auth/connection_notifier.dart';
import 'package:re_tsm/src/features/home/home_screen.dart';
import '../../common_widgets/auth_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _tsIpController = TextEditingController();
  final _tsPortController = TextEditingController();
  final _tsApiKeyController = TextEditingController();

  final _queryIpController = TextEditingController();
  final _queryPortController = TextEditingController();
  final _queryServerPortController = TextEditingController();
  final _queryUserController = TextEditingController();
  final _queryPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final config = ref.read(initialConfigProvider);
      _tsIpController.text = config['remote_ip']?.toString() ?? '127.0.0.1';
      _tsPortController.text = config['port']?.toString() ?? '5899';
      _tsApiKeyController.text = config['api_key']?.toString() ?? '';

      _queryIpController.text = config['query_ip']?.toString() ?? '127.0.0.1';
      _queryPortController.text = config['query_port']?.toString() ?? '10011';
      _queryServerPortController.text =
          config['query_server_port']?.toString() ?? '9987';
      _queryUserController.text = config['query_user']?.toString() ?? '';
      _queryPassController.text = config['query_pass']?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    _tsIpController.dispose();
    _tsPortController.dispose();
    _tsApiKeyController.dispose();
    _queryIpController.dispose();
    _queryPortController.dispose();
    _queryServerPortController.dispose();
    _queryUserController.dispose();
    _queryPassController.dispose();
    super.dispose();
  }

  Future<bool> _saveConfig() async {
    final remotePort = ConfigService.parsePort(_tsPortController.text);
    final queryPort = ConfigService.parsePort(_queryPortController.text);
    final queryServerPort =
        ConfigService.parsePort(_queryServerPortController.text);
    if (remotePort == null || queryPort == null || queryServerPort == null) {
      UIUtils.showGlobalSnackbar(
        'Ports must be whole numbers between 1 and 65535.',
        isError: true,
      );
      return false;
    }

    try {
      await ConfigService.updateConfig((conf) {
        conf['query_ip'] = _queryIpController.text.trim();
        conf['query_port'] = queryPort;
        conf['query_server_port'] = queryServerPort;
        conf['query_user'] = _queryUserController.text;
        conf['query_pass'] = _queryPassController.text;
        conf['remote_ip'] = _tsIpController.text.trim();
        conf['port'] = remotePort;
        conf['api_key'] = _tsApiKeyController.text;
      });
      return true;
    } catch (error) {
      UIUtils.showGlobalSnackbar(
        'Failed to save configuration: $error',
        isError: true,
      );
      return false;
    }
  }

  Future<void> _connectTs() async {
    if (!await _saveConfig()) return;
    final ip = _tsIpController.text;
    final port = ConfigService.parsePort(_tsPortController.text)!;
    final apiKey = _tsApiKeyController.text;
    ref.read(connectionProvider.notifier).connectTs(ip, port, apiKey);
  }

  Future<void> _connectQuery() async {
    if (!await _saveConfig()) return;
    final ip = _queryIpController.text;
    final port = ConfigService.parsePort(_queryPortController.text)!;
    final virtualServerPort =
        ConfigService.parsePort(_queryServerPortController.text)!;
    final user = _queryUserController.text;
    final pass = _queryPassController.text;
    ref
        .read(connectionProvider.notifier)
        .connectQuery(ip, port, virtualServerPort, user, pass);
  }

  Widget _buildFormCard({
    required ThemeData theme,
    required String title,
    required List<Widget> children,
  }) {
    return SizedBox(
      width: 350,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final theme = Theme.of(context);
    final language = ref.watch(languageProvider);
    final isZh = language == 'zh';

    return Scaffold(
      appBar: AppBar(
        title: Text(isZh ? 'ReTSM - 连接服务器' : 'ReTSM - Connect'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  // Remote Apps Form
                  _buildFormCard(
                    theme: theme,
                    title: 'Remote Apps (WebSocket)',
                    children: [
                      TextField(
                        controller: _tsIpController,
                        decoration: InputDecoration(
                            labelText: isZh ? 'IP 地址' : 'IP Address',
                            border: const OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _tsPortController,
                        decoration: InputDecoration(
                            labelText: isZh ? '端口' : 'Port',
                            border: const OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _tsApiKeyController,
                              decoration: InputDecoration(
                                  labelText: isZh ? 'API 密钥' : 'API Key',
                                  border: const OutlineInputBorder()),
                              obscureText: true,
                              onChanged: (v) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AuthButton(
                            apiKeyController: _tsApiKeyController,
                            ipController: _tsIpController,
                            portController: _tsPortController,
                            onAuthSuccess: () async {
                              await _saveConfig();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: connectionState.tsState ==
                                AppConnectionState.connecting
                            ? null
                            : connectionState.tsState ==
                                    AppConnectionState.connected
                                ? () => ref
                                    .read(connectionProvider.notifier)
                                    .disconnectTs()
                                : _connectTs,
                        child: connectionState.tsState ==
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
                            : Text(connectionState.tsState ==
                                    AppConnectionState.connected
                                ? (isZh ? '断开' : 'Disconnect')
                                : (isZh ? '连接' : 'Connect')),
                      ),
                      if (connectionState.tsError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          isZh
                              ? '连接失败: ${connectionState.tsError}'
                              : 'Connection failed: ${connectionState.tsError}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // ServerQuery Form
                  _buildFormCard(
                    theme: theme,
                    title: 'ServerQuery (TCP)',
                    children: [
                      TextField(
                        controller: _queryIpController,
                        decoration: InputDecoration(
                            labelText: isZh ? 'IP 地址' : 'IP Address',
                            border: const OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _queryPortController,
                        decoration: InputDecoration(
                            labelText: isZh ? '端口' : 'Port',
                            border: const OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _queryServerPortController,
                        decoration: InputDecoration(
                          labelText: isZh ? '虚拟服务器端口' : 'Virtual Server Port',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _queryUserController,
                        decoration: InputDecoration(
                            labelText: isZh ? '用户名' : 'Username',
                            border: const OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _queryPassController,
                        decoration: InputDecoration(
                            labelText: isZh ? '密码' : 'Password',
                            border: const OutlineInputBorder()),
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: connectionState.queryState ==
                                AppConnectionState.connecting
                            ? null
                            : connectionState.queryState ==
                                    AppConnectionState.connected
                                ? () => ref
                                    .read(connectionProvider.notifier)
                                    .disconnectQuery()
                                : _connectQuery,
                        child: connectionState.queryState ==
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
                            : Text(connectionState.queryState ==
                                    AppConnectionState.connected
                                ? (isZh ? '断开' : 'Disconnect')
                                : (isZh ? '连接' : 'Connect')),
                      ),
                      if (connectionState.queryError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          isZh
                              ? '连接失败: ${connectionState.queryError}'
                              : 'Connection failed: ${connectionState.queryError}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Continue button
              ElevatedButton.icon(
                onPressed: (connectionState.tsState ==
                            AppConnectionState.connected ||
                        connectionState.queryState ==
                            AppConnectionState.connected)
                    ? () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        );
                      }
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text(isZh ? '进入主界面' : 'Continue to Dashboard'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
