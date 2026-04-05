import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../rust/api.dart'; // FRB
import '../../../core/config_service.dart';
import '../../../core/ui_utils.dart';
import '../../widgets/expressive_empty_state.dart';

class RemoteAppConnectionNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(autoConnectRemoteProvider);
  }

  void set(bool val) => state = val;
}

final remoteAppConnectionProvider =
    NotifierProvider<RemoteAppConnectionNotifier, bool>(
        RemoteAppConnectionNotifier.new);

class RemoteAppActualConnectionNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void set(bool val) => state = val;
}

final remoteAppActualConnectionProvider =
    NotifierProvider<RemoteAppActualConnectionNotifier, bool>(
        RemoteAppActualConnectionNotifier.new);

final tsEventsProvider = StreamProvider<String>((ref) async* {
  final isConnected = ref.watch(remoteAppConnectionProvider);
  if (!isConnected) {
    yield '{"type": "info", "message": "Remote App Disconnected"}';
    return;
  }

  final conf = await ConfigService.loadConfig();
  final ip = conf['remote_ip'] as String? ?? '127.0.0.1';
  final port = conf['port'] as int? ?? 5899;
  final apiKey = conf['api_key'] as String? ?? '';

  if (apiKey.isEmpty) {
    yield '{"type": "error", "message": "No API Key configured."}';
    return;
  }

  yield '{"type": "info", "message": "Connecting to Remote Apps at ws://$ip:$port..."}';
  try {
    await for (final event
        in startTsConnection(ip: ip, port: port, apiKey: apiKey)) {
      yield event;
    }
    yield '{"type": "warning", "message": "Connection to Remote Apps lost."}';
  } catch (e) {
    yield '{"type": "error", "message": "Remote App Error: $e"}';
  }

  if (ref.read(remoteAppConnectionProvider)) {
    Future.microtask(
        () => ref.read(remoteAppConnectionProvider.notifier).set(false));
  }
});

class DashboardEvent {
  final String raw;
  final Map<String, dynamic>? parsed;
  final DateTime timestamp;

  DashboardEvent(this.raw)
      : parsed = _tryParse(raw),
        timestamp = DateTime.now();

  static Map<String, dynamic>? _tryParse(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return null;
    }
  }
}

class DashboardNotifier extends Notifier<List<DashboardEvent>> {
  Timer? _timer;

  @override
  List<DashboardEvent> build() {
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);

    ref.onDispose(() {
      _timer?.cancel();
    });

    ref.listen<AsyncValue<String>>(tsEventsProvider, (previous, next) {
      if (next is AsyncData && next.value != null) {
        final val = next.value!;
        addEvent(val);

        final notifier = ref.read(remoteAppActualConnectionProvider.notifier);

        final isZh = ref.read(languageProvider) == 'zh';
        if (val.contains('"message": "Connecting to Remote Apps')) {
          Future.microtask(() {
            notifier.set(false);
            UIUtils.showGlobalSnackbar(
                isZh ? '正在连接 Remote App...' : 'Connecting to Remote App...');
          });
        } else if (val
            .contains('"message": "Connection to Remote Apps lost"')) {
          Future.microtask(() {
            notifier.set(false);
            UIUtils.showGlobalSnackbar(
                isZh ? 'Remote App 连接已断开' : 'Remote App connection lost',
                isError: true);
          });
        } else if (val.contains('"message": "Remote App Disconnected"')) {
          Future.microtask(() {
            notifier.set(false);
            UIUtils.showGlobalSnackbar(
                isZh ? '已断开 Remote App' : 'Remote App Disconnected');
          });
        } else if (val.contains('"message": "Remote App Error')) {
          Future.microtask(() {
            notifier.set(false);
            UIUtils.showGlobalSnackbar(
                isZh ? 'Remote App 连接发生错误' : 'Remote App Error occurred',
                isError: true);
          });
        } else if (val.contains('"type":"auth"')) {
          Future.microtask(() => notifier.set(true));
        } else if (val.contains('"type": "auth"')) {
          Future.microtask(() => notifier.set(true));
        }
      }
    }, fireImmediately: true);

    return [];
  }

  void _onTick(Timer timer) {
    final clearSeconds = ref.read(eventAutoClearSecondsProvider);
    if (clearSeconds > 0 && state.isNotEmpty) {
      final now = DateTime.now();
      final limit = now.subtract(Duration(seconds: clearSeconds));
      final filtered = state.where((e) => e.timestamp.isAfter(limit)).toList();
      if (filtered.length != state.length) {
        state = filtered;
      }
    }
  }

  void addEvent(String rawEvent) {
    state = [...state, DashboardEvent(rawEvent)];
    if (state.length > 200) {
      state = state.sublist(state.length - 200); // keep last 200
    }
  }

  void clear() {
    state = [];
  }
}

final dashboardProvider =
    NotifierProvider<DashboardNotifier, List<DashboardEvent>>(
        DashboardNotifier.new);

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final _customJsonController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _clearController;

  @override
  void initState() {
    super.initState();
    _clearController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearController.text =
          ref.read(eventAutoClearSecondsProvider).toString();
    });
  }

  @override
  void dispose() {
    _customJsonController.dispose();
    _scrollController.dispose();
    _clearController.dispose();
    super.dispose();
  }

  void _sendCustomJson() async {
    final payload = _customJsonController.text.trim();
    if (payload.isEmpty) return;

    final isZh = ref.read(languageProvider) == 'zh';

    try {
      await sendTsMessage(payload: payload);
      if (!mounted) return;
      UIUtils.showGlobalSnackbar(
        isZh ? '已发送自定义 JSON 载荷。' : 'Sent custom JSON payload.',
      );
      _customJsonController.clear();
    } catch (e) {
      if (!mounted) return;
      UIUtils.showGlobalSnackbar(
        isZh ? '发送失败: $e' : 'Failed to send: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<DashboardEvent>>(dashboardProvider, (previous, next) {
      final autoScroll = ref.read(eventAutoScrollProvider);
      if (autoScroll && previous != null && next.length > previous.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    final events = ref.watch(dashboardProvider);
    final language = ref.watch(languageProvider);
    final isZh = language == 'zh';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isZh ? '日志' : 'Log',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Row(
                children: [
                  Tooltip(
                    message: isZh ? '自动滚动' : 'Auto Scroll',
                    child: Switch(
                      value: ref.watch(eventAutoScrollProvider),
                      onChanged: (val) {
                        ref.read(eventAutoScrollProvider.notifier).set(val);
                        // Save config in background
                        ConfigService.loadConfig().then((conf) {
                          conf['event_auto_scroll'] = val;
                          ConfigService.saveConfig(conf);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: Focus(
                      onFocusChange: (focused) {
                        if (!focused) {
                          final parsed =
                              int.tryParse(_clearController.text) ?? 0;
                          ref
                              .read(eventAutoClearSecondsProvider.notifier)
                              .set(parsed);
                          ConfigService.loadConfig().then((conf) {
                            conf['event_auto_clear_seconds'] = parsed;
                            ConfigService.saveConfig(conf);
                          });
                        }
                      },
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: isZh ? '清理(秒)' : 'Clear(s)',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        controller: _clearController,
                        onSubmitted: (val) {
                          final parsed = int.tryParse(val) ?? 0;
                          ref
                              .read(eventAutoClearSecondsProvider.notifier)
                              .set(parsed);
                          ConfigService.loadConfig().then((conf) {
                            conf['event_auto_clear_seconds'] = parsed;
                            ConfigService.saveConfig(conf);
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    tooltip: isZh ? '清空事件' : 'Clear Events',
                    onPressed: () {
                      ref.read(dashboardProvider.notifier).clear();
                    },
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: events.isEmpty
                  ? ExpressiveEmptyState(
                      message: isZh ? '等待事件中...' : 'Waiting for events...',
                      icon: Icons.hourglass_empty_rounded,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final ev = events[index];
                        final isError = ev.parsed?['type'] == 'error';
                        final isAuth = ev.parsed?['type'] == 'auth';

                        return ExpansionTile(
                          title: Text(ev.parsed?['type'] ??
                              (isZh ? '原始事件' : 'Raw Event')),
                          subtitle: Text(
                            ev.raw,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isError
                                  ? Colors.red
                                  : (isAuth ? Colors.green : null),
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SelectableText(
                                const JsonEncoder.withIndent('  ')
                                    .convert(ev.parsed ?? ev.raw),
                                style: const TextStyle(
                                    fontFamily: 'Google Sans Code'),
                              ),
                            )
                          ],
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(isZh ? '自定义 JSON 发送器' : 'Custom JSON Sender',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customJsonController,
                  decoration: InputDecoration(
                    hintText:
                        isZh ? '输入有效的 JSON 载荷' : 'Enter valid JSON payload',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                icon: const Icon(Icons.send),
                label: Text(isZh ? '发送' : 'Send'),
                onPressed: _sendCustomJson,
              )
            ],
          )
        ],
      ),
    );
  }
}
