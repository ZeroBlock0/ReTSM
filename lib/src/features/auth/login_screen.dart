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

  bool _hasConfig = false;

  @override
  void initState() {
    super.initState();
    // Delay initialization until build to access provider
    Future.microtask(() {
      final config = ref.read(initialConfigProvider);
      _tsIpController.text = config['remote_ip']?.toString() ?? '127.0.0.1';
      _tsPortController.text = config['port']?.toString() ?? '5899';
      _tsApiKeyController.text = config['api_key']?.toString() ?? '';

      _queryIpController.text = config['query_ip']?.toString() ?? '127.0.0.1';
      _queryPortController.text = config['query_port']?.toString() ?? '10011';
      _queryUserController.text = config['query_user']?.toString() ?? '';
      _queryPassController.text = config['query_pass']?.toString() ?? '';

      setState(() {
        _hasConfig = (config['query_user']?.toString() ?? '').isNotEmpty;
      });
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

  void _connectTs() {
    final ip = _tsIpController.text;
    final port = int.tryParse(_tsPortController.text) ?? 5899;
    final apiKey = _tsApiKeyController.text;
    ref.read(connectionProvider.notifier).connectTs(ip, port, apiKey);
  }

  Future<void> _connectQuery() async {
    final ip = _queryIpController.text;
    final port = int.tryParse(_queryPortController.text) ?? 10011;
    final user = _queryUserController.text;
    final pass = _queryPassController.text;

    if (!_hasConfig) {
      // Save config if this is the first time setup
      final conf = await ConfigService.loadConfig();
      conf['query_ip'] = ip;
      conf['query_port'] = port;
      conf['query_user'] = user;
      conf['query_pass'] = pass;

      conf['remote_ip'] = _tsIpController.text;
      conf['port'] = int.tryParse(_tsPortController.text) ?? 5899;
      conf['api_key'] = _tsApiKeyController.text;

      await ConfigService.saveConfig(conf);
      setState(() => _hasConfig = true);
    }

    ref.read(connectionProvider.notifier).connectQuery(ip, port, user, pass);
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ReTSM - Connect')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Remote Apps Form
                  SizedBox(
                    width: 350,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Remote Apps (WebSocket)',
                                style: theme.textTheme.titleLarge),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _tsIpController,
                              decoration: const InputDecoration(
                                  labelText: 'IP Address',
                                  border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _tsPortController,
                              decoration: const InputDecoration(
                                  labelText: 'Port',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _tsApiKeyController,
                                    decoration: const InputDecoration(
                                        labelText: 'API Key',
                                        border: OutlineInputBorder()),
                                    obscureText: true,
                                    onChanged: (v) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AuthButton(
                                  apiKeyController: _tsApiKeyController,
                                  ipController: _tsIpController,
                                  portController: _tsPortController,
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
                                  ? const CircularProgressIndicator()
                                  : const Text('Connect TS'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // ServerQuery Form
                  SizedBox(
                    width: 350,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('ServerQuery (TCP)',
                                style: theme.textTheme.titleLarge),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _queryIpController,
                              decoration: const InputDecoration(
                                  labelText: 'IP Address',
                                  border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _queryPortController,
                              decoration: const InputDecoration(
                                  labelText: 'Port',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _queryUserController,
                              decoration: const InputDecoration(
                                  labelText: 'Username',
                                  border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _queryPassController,
                              decoration: const InputDecoration(
                                  labelText: 'Password',
                                  border: OutlineInputBorder()),
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
                                  ? const CircularProgressIndicator()
                                  : Text(_hasConfig
                                      ? 'Connection Test'
                                      : 'Save & Test'),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                label: const Text('Continue to Dashboard'),
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
