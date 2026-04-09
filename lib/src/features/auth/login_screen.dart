import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_tsm/core/config_service.dart';
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
    _queryUserController.dispose();
    _queryPassController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final conf = await ConfigService.loadConfig();
    conf['query_ip'] = _queryIpController.text;
    conf['query_port'] = int.tryParse(_queryPortController.text) ?? 10011;
    conf['query_user'] = _queryUserController.text;
    conf['query_pass'] = _queryPassController.text;

    conf['remote_ip'] = _tsIpController.text;
    conf['port'] = int.tryParse(_tsPortController.text) ?? 5899;
    conf['api_key'] = _tsApiKeyController.text;

    await ConfigService.saveConfig(conf);
  }

  Future<void> _connectTs() async {
    await _saveConfig();
    final ip = _tsIpController.text;
    final port = int.tryParse(_tsPortController.text) ?? 5899;
    final apiKey = _tsApiKeyController.text;
    ref.read(connectionProvider.notifier).connectTs(ip, port, apiKey);
  }

  Future<void> _connectQuery() async {
    await _saveConfig();
    final ip = _queryIpController.text;
    final port = int.tryParse(_queryPortController.text) ?? 10011;
    final user = _queryUserController.text;
    final pass = _queryPassController.text;
    ref.read(connectionProvider.notifier).connectQuery(ip, port, user, pass);
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
                    title: isZh
                        ? 'Remote Apps (本地/局域网)'
                        : 'Remote Apps (WebSocket)',
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
                            onAuthSuccess: _saveConfig,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: connectionState.tsState ==
                                AppConnectionState.connecting
                            ? null
                            : _connectTs,
                        child: connectionState.tsState ==
                                AppConnectionState.connecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(isZh ? '保存并测试' : 'Save & Test'),
                      ),
                    ],
                  ),
                  // ServerQuery Form
                  _buildFormCard(
                    theme: theme,
                    title: isZh ? 'ServerQuery (TCP 远程)' : 'ServerQuery (TCP)',
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
                        controller: _queryUserController,
                        decoration: InputDecoration(
                            labelText:
                                isZh ? '用户名 (默认 serveradmin)' : 'Username',
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
                            : _connectQuery,
                        child: connectionState.queryState ==
                                AppConnectionState.connecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(isZh ? '保存并测试' : 'Save & Test'),
                      ),
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
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
