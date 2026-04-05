import 'package:flutter/material.dart';
import '../main.dart';
import 'dart:async';

class UIUtils {
  static OverlayEntry? _overlayEntry;
  static _ToastWidgetState? _currentToastState;

  static void showGlobalSnackbar(
    String message, {
    bool isError = false,
  }) {
    showGlobalActionSnackbar(message, isError: isError);
  }

  static void showGlobalActionSnackbar(
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    final overlay = globalNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    if (_overlayEntry != null) {
      _currentToastState?.dismiss();
      _overlayEntry = null;
      _currentToastState = null;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        isError: isError,
        action: action,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
          }
          if (_overlayEntry == entry) {
            _overlayEntry = null;
            _currentToastState = null;
          }
        },
        onStateCreated: (state) {
          if (_overlayEntry == entry) {
            _currentToastState = state;
          }
        },
      ),
    );

    _overlayEntry = entry;
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final SnackBarAction? action;
  final VoidCallback onDismiss;
  final void Function(_ToastWidgetState) onStateCreated;

  const _ToastWidget({
    Key? key,
    required this.message,
    required this.isError,
    this.action,
    required this.onDismiss,
    required this.onStateCreated,
  }) : super(key: key);

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _timer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    widget.onStateCreated(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    _timer = Timer(const Duration(seconds: 3), () {
      dismiss();
    });
  }

  void dismiss() {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _timer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = widget.isError
        ? Colors.red.shade600
        : (colorScheme.surfaceContainerHighest);
    final textColor =
        widget.isError ? Colors.white : (colorScheme.onSurfaceVariant);

    return Positioned(
      bottom: 40.0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25), // 0.1 opacity
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.isError) ...[
                            Icon(Icons.error, color: textColor),
                            const SizedBox(width: 8),
                          ] else ...[
                            Icon(Icons.info, color: textColor),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              widget.message,
                              textAlign: TextAlign.start,
                              style: TextStyle(color: textColor),
                            ),
                          ),
                          if (widget.action != null) ...[
                            const SizedBox(width: 16),
                            TextButton(
                              onPressed: () {
                                widget.action!.onPressed();
                                dismiss();
                              },
                              child: Text(
                                widget.action!.label,
                                style: TextStyle(
                                  color: widget.action!.textColor ??
                                      colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
