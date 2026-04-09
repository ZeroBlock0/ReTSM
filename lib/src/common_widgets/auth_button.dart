import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_tsm/core/ui_utils.dart';
import 'package:re_tsm/src/rust/api.dart';
import 'package:re_tsm/core/config_service.dart';

class AuthButton extends ConsumerStatefulWidget {
  final TextEditingController apiKeyController;
  final TextEditingController ipController;
  final TextEditingController portController;
  final VoidCallback? onAuthSuccess;

  const AuthButton({
    super.key,
    required this.apiKeyController,
    required this.ipController,
    required this.portController,
    this.onAuthSuccess,
  });

  @override
  ConsumerState<AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends ConsumerState<AuthButton> {
  bool _isRequestingAuth = false;

  void _showToast(String message, {bool isError = false}) {
    UIUtils.showGlobalSnackbar(message, isError: isError);
  }

  Future<void> _requestAuth() async {
    setState(() => _isRequestingAuth = true);
    final language = ref.read(languageProvider);
    final isZh = language == 'zh';

    try {
      final ip = widget.ipController.text.trim().isEmpty
          ? '127.0.0.1'
          : widget.ipController.text.trim();
      final port = int.tryParse(widget.portController.text) ?? 5899;

      _showToast(isZh
          ? '请在 TeamSpeak 客户端内点击“允许” (Allow)。'
          : 'Please click "Allow" inside the TeamSpeak client.');

      final key = await requestTsApiKey(ip: ip, port: port);
      widget.apiKeyController.text = key;

      if (widget.onAuthSuccess != null) {
        widget.onAuthSuccess!();
      }
    } catch (e) {
      if (!mounted) return;
      _showToast(isZh ? '授权失败: $e' : 'Auth failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isRequestingAuth = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final isZh = language == 'zh';
    final hasKey = widget.apiKeyController.text.trim().isNotEmpty;

    return FilledButton.icon(
      onPressed: (hasKey || _isRequestingAuth) ? null : _requestAuth,
      icon: _isRequestingAuth
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.vpn_key),
      label: Text(hasKey
          ? (isZh ? '已授权' : 'Authorized')
          : (isZh ? '申请 TS 授权' : 'Request TS Auth')),
    );
  }
}
