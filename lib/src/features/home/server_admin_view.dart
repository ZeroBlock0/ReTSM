import 'dart:convert';
import 'package:flutter/material.dart';
import '../../rust/api.dart';
import '../../../core/config_service.dart';
import '../../widgets/expressive_empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogEntry {
  final bool isCommand;
  final String text;
  final String? prettyText;
  LogEntry({required this.isCommand, required this.text, this.prettyText});
}

class ServerAdminState {
  final List<LogEntry> logs;
  final bool isConnected;
  final bool isVisualMode;
  final bool isPrettyPrint;
  final bool autoScroll;
  final bool autoClear;
  final List<Map<String, dynamic>> visualData;
  final List<Map<String, dynamic>> cachedClients;
  final String currentQueryType;

  ServerAdminState({
    required this.logs,
    required this.isConnected,
    required this.isVisualMode,
    required this.isPrettyPrint,
    required this.autoScroll,
    required this.autoClear,
    required this.visualData,
    required this.cachedClients,
    required this.currentQueryType,
  });

  ServerAdminState copyWith({
    List<LogEntry>? logs,
    bool? isConnected,
    bool? isVisualMode,
    bool? isPrettyPrint,
    bool? autoScroll,
    bool? autoClear,
    List<Map<String, dynamic>>? visualData,
    List<Map<String, dynamic>>? cachedClients,
    String? currentQueryType,
  }) {
    return ServerAdminState(
      logs: logs ?? this.logs,
      isConnected: isConnected ?? this.isConnected,
      isVisualMode: isVisualMode ?? this.isVisualMode,
      isPrettyPrint: isPrettyPrint ?? this.isPrettyPrint,
      autoScroll: autoScroll ?? this.autoScroll,
      autoClear: autoClear ?? this.autoClear,
      visualData: visualData ?? this.visualData,
      cachedClients: cachedClients ?? this.cachedClients,
      currentQueryType: currentQueryType ?? this.currentQueryType,
    );
  }
}

class ServerAdminNotifier extends Notifier<ServerAdminState> {
  @override
  ServerAdminState build() {
    Future.microtask(_initFromConfig);
    return ServerAdminState(
      logs: [LogEntry(isCommand: false, text: 'Not connected.')],
      isConnected: false,
      isVisualMode: true,
      isPrettyPrint: true,
      autoScroll: true,
      autoClear: false,
      visualData: [],
      cachedClients: [],
      currentQueryType: '',
    );
  }

  Future<void> _initFromConfig() async {
    final conf = await ConfigService.loadConfig();
    state = state.copyWith(
      autoScroll: conf['query_auto_scroll'] as bool? ?? true,
      autoClear: conf['query_auto_clear'] as bool? ?? false,
    );
    if (conf['auto_connect_query'] == true) {
      connect("Connecting ServerQuery...");
    }
  }

  Future<void> toggleAutoScroll(bool val) async {
    state = state.copyWith(autoScroll: val);
    final conf = await ConfigService.loadConfig();
    conf['query_auto_scroll'] = val;
    await ConfigService.saveConfig(conf);
  }

  Future<void> toggleAutoClear(bool val) async {
    state = state.copyWith(autoClear: val);
    final conf = await ConfigService.loadConfig();
    conf['query_auto_clear'] = val;
    await ConfigService.saveConfig(conf);
  }

  void setVisualMode(bool val) {
    state = state.copyWith(isVisualMode: val);
  }

  void setPrettyPrint(bool val) {
    state = state.copyWith(isPrettyPrint: val);
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  Future<void> connect(String connectingText) async {
    state = state.copyWith(
      logs: state.autoClear
          ? [LogEntry(isCommand: false, text: connectingText)]
          : [...state.logs, LogEntry(isCommand: false, text: connectingText)],
      visualData: [],
      currentQueryType: '',
    );
    final conf = await ConfigService.loadConfig();
    final ip = conf['query_ip'] as String? ?? '127.0.0.1';
    final port = conf['query_port'] as int? ?? 10011;
    final user = conf['query_user'] as String? ?? '';
    final pass = conf['query_pass'] as String? ?? '';

    try {
      final res =
          await connectQuery(ip: ip, port: port, user: user, pass: pass);
      state = state.copyWith(
        logs: [...state.logs, LogEntry(isCommand: false, text: res)],
        isConnected: true,
      );
    } catch (e) {
      state = state.copyWith(
        logs: [...state.logs, LogEntry(isCommand: false, text: 'Error: $e')],
      );
    }
  }

  Future<void> disconnect(String disconnectedText) async {
    await queryDisconnect();
    state = state.copyWith(
      isConnected: false,
      logs: [...state.logs, LogEntry(isCommand: false, text: disconnectedText)],
      visualData: [],
      currentQueryType: '',
    );
  }

  Future<void> sendCommand(String cmd,
      {bool isAction = false, String? refreshCmd}) async {
    if (!state.isConnected) return;

    var newLogs =
        state.autoClear ? <LogEntry>[] : List<LogEntry>.from(state.logs);
    newLogs.add(LogEntry(isCommand: true, text: cmd));
    state = state.copyWith(logs: newLogs);

    try {
      final res = await querySendCommand(command: cmd);
      String? prettyText;
      List<Map<String, dynamic>>? newVisualData;
      List<Map<String, dynamic>>? newCachedClients;
      String newCurrentQueryType = state.currentQueryType;

      try {
        final List<dynamic> parsed = jsonDecode(res);
        if (parsed.isNotEmpty) {
          final parsedList =
              parsed.map((e) => e as Map<String, dynamic>).toList();
          if (!isAction) {
            newVisualData = parsedList;
            newCurrentQueryType = cmd.split(' ').first;
          }
          if (cmd.startsWith('clientlist')) {
            newCachedClients = parsedList;
          }
        } else if (!isAction) {
          newVisualData = [];
          if (cmd.startsWith('clientlist')) {
            newCachedClients = [];
          }
        }
        prettyText = const JsonEncoder.withIndent('  ').convert(parsed);
      } catch (_) {
        if (!isAction) newVisualData = [];
      }

      state = state.copyWith(
        logs: [
          ...state.logs,
          LogEntry(isCommand: false, text: res, prettyText: prettyText)
        ],
        visualData: newVisualData ?? state.visualData,
        cachedClients: newCachedClients ?? state.cachedClients,
        currentQueryType: newCurrentQueryType,
      );

      if (refreshCmd != null) {
        await sendCommand(refreshCmd);
      }
    } catch (e) {
      state = state.copyWith(
        logs: [...state.logs, LogEntry(isCommand: false, text: 'Error: $e')],
        visualData: isAction ? state.visualData : [],
      );
    }
  }

  Future<void> fetchChannelsAndClients() async {
    // Invisibly fetch clientlist to update cache, then fetch channellist
    await sendCommand('clientlist -uid -country -ip -groups', isAction: true);
    await sendCommand('channellist');
  }

  Future<void> refreshCurrentView() async {
    if (state.currentQueryType == 'channellist') {
      await fetchChannelsAndClients();
    } else if (state.currentQueryType == 'clientlist') {
      await sendCommand('clientlist -uid -country -ip -groups');
    } else if (state.currentQueryType.isNotEmpty) {
      await sendCommand(state.currentQueryType);
    }
  }
}

final serverAdminProvider =
    NotifierProvider<ServerAdminNotifier, ServerAdminState>(() {
  return ServerAdminNotifier();
});

class ServerAdminView extends ConsumerStatefulWidget {
  const ServerAdminView({super.key});

  @override
  ConsumerState<ServerAdminView> createState() => _ServerAdminViewState();
}

class _ServerAdminViewState extends ConsumerState<ServerAdminView> {
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _escapeTs3(String str) {
    return str
        .replaceAll(r'\', r'\\')
        .replaceAll('/', r'\/')
        .replaceAll(' ', r'\s')
        .replaceAll('|', r'\p')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t')
        .replaceAll('\x0B', r'\v')
        .replaceAll('\x0C', r'\f');
  }

  Future<void> _pokeClient(String clid, bool isZh) async {
    final msg = await _promptInput(isZh ? '戳一下 (Poke)' : 'Poke Message',
        isZh ? '输入发送的消息:' : 'Enter message to send:');
    if (msg != null && msg.isNotEmpty) {
      await ref.read(serverAdminProvider.notifier).sendCommand(
          'clientpoke clid=$clid msg=${_escapeTs3(msg)}',
          isAction: true);
      await ref.read(serverAdminProvider.notifier).refreshCurrentView();
    }
  }

  Future<void> _kickClient(String clid, bool isZh) async {
    final msg = await _promptInput(isZh ? '踢出服务器' : 'Kick Reason',
        isZh ? '输入踢出原因 (可选):' : 'Enter kick reason (optional):');
    if (msg != null) {
      final reason = msg.isEmpty ? '' : ' reasonmsg=${_escapeTs3(msg)}';
      await ref.read(serverAdminProvider.notifier).sendCommand(
          'clientkick clid=$clid reasonid=5$reason',
          isAction: true);
      await ref.read(serverAdminProvider.notifier).refreshCurrentView();
    }
  }

  Future<void> _moveClient(String clid, bool isZh) async {
    final cid = await _promptInput(isZh ? '移动用户' : 'Move Client',
        isZh ? '输入目标频道 ID:' : 'Enter target Channel ID:');
    if (cid != null && cid.isNotEmpty) {
      await ref
          .read(serverAdminProvider.notifier)
          .sendCommand('clientmove clid=$clid cid=$cid', isAction: true);
      await ref.read(serverAdminProvider.notifier).refreshCurrentView();
    }
  }

  Future<void> _pmClient(String clid, bool isZh) async {
    final msg = await _promptInput(
        isZh ? '发送私信' : 'Private Message', isZh ? '输入消息内容:' : 'Enter message:');
    if (msg != null && msg.isNotEmpty) {
      await ref.read(serverAdminProvider.notifier).sendCommand(
          'sendtextmessage targetmode=1 target=$clid msg=${_escapeTs3(msg)}',
          isAction: true);
      await ref.read(serverAdminProvider.notifier).refreshCurrentView();
    }
  }

  Future<void> _serverChat(bool isZh) async {
    final msg = await _promptInput(isZh ? '全服广播' : 'Server Chat',
        isZh ? '输入要广播的消息:' : 'Enter message to all:');
    if (msg != null && msg.isNotEmpty) {
      await ref.read(serverAdminProvider.notifier).sendCommand(
          'sendtextmessage targetmode=3 msg=${_escapeTs3(msg)}',
          isAction: true);
      await ref.read(serverAdminProvider.notifier).refreshCurrentView();
    }
  }

  Future<String?> _promptInput(String title, String hint) {
    String val = '';
    final isZh = ref.read(languageProvider) == 'zh';
    return showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 300,
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(hintText: hint),
                  onChanged: (v) => val = v,
                  onSubmitted: (_) => Navigator.pop(ctx, val),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: Text(isZh ? '取消' : 'Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, val),
                    child: Text(isZh ? '确定' : 'OK')),
              ],
            ));
  }

  Future<void> _addClientServerGroup(String cldbid, bool isZh) async {
    if (cldbid.isEmpty) return;
    final sgid = await _promptInput(isZh ? '添加服务器组' : 'Add Server Group',
        isZh ? '输入服务器组 ID (SGID):' : 'Enter Server Group ID (SGID):');
    if (sgid != null && sgid.isNotEmpty) {
      await ref.read(serverAdminProvider.notifier).sendCommand(
          'servergroupaddclient sgid=$sgid cldbid=$cldbid',
          isAction: true);
      await ref.read(serverAdminProvider.notifier).refreshCurrentView();
    }
  }

  Future<void> _removeClientServerGroup(String cldbid, bool isZh) async {
    if (cldbid.isEmpty) return;
    final sgid = await _promptInput(isZh ? '移除服务器组' : 'Remove Server Group',
        isZh ? '输入服务器组 ID (SGID):' : 'Enter Server Group ID (SGID):');
    if (sgid != null && sgid.isNotEmpty) {
      await ref.read(serverAdminProvider.notifier).sendCommand(
          'servergroupdelclient sgid=$sgid cldbid=$cldbid',
          isAction: true);
      await ref.read(serverAdminProvider.notifier).refreshCurrentView();
    }
  }

  Widget _buildClientItem(Map<String, dynamic> client, bool isZh) {
    final clientName =
        client['client_nickname']?.toString() ?? 'Unknown Client';
    final clid = client['clid']?.toString() ?? '';
    final cldbid = client['client_database_id']?.toString() ?? '';
    final type = client['client_type'] == '1' ? 'Query' : 'Voice';
    final ip = client['connection_client_ip']?.toString() ?? '';
    final country = client['client_country']?.toString() ?? '';

    String subtitleStr = 'ID: $clid | Type: $type';
    if (ip.isNotEmpty) subtitleStr += ' | IP: $ip';
    if (country.isNotEmpty) subtitleStr += ' | Country: $country';

    final otherEntries = client.entries
        .where((e) =>
            e.key != 'status' &&
            e.key != 'client_nickname' &&
            e.key != 'client_type' &&
            e.key != 'clid' &&
            e.key != 'client_database_id' &&
            e.key != 'connection_client_ip' &&
            e.key != 'client_country')
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ExpansionTile(
      key: PageStorageKey('client_$clid'),
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title:
          Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitleStr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.security, color: Colors.green),
            tooltip: isZh ? '添加服务器组' : 'Add Server Group',
            onPressed: () => _addClientServerGroup(cldbid, isZh),
          ),
          IconButton(
            icon: const Icon(Icons.remove_moderator, color: Colors.orange),
            tooltip: isZh ? '移除服务器组' : 'Remove Server Group',
            onPressed: () => _removeClientServerGroup(cldbid, isZh),
          ),
          IconButton(
            icon: const Icon(Icons.touch_app),
            tooltip: isZh ? '戳一下' : 'Poke',
            onPressed: () => _pokeClient(clid, isZh),
          ),
          IconButton(
            icon: const Icon(Icons.block, color: Colors.red),
            tooltip: isZh ? '踢出服务器' : 'Kick from Server',
            onPressed: () => _kickClient(clid, isZh),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            tooltip: isZh ? '移动用户' : 'Move Client',
            onPressed: () => _moveClient(clid, isZh),
          ),
          IconButton(
            icon: const Icon(Icons.message),
            tooltip: isZh ? '私信' : 'Private Message',
            onPressed: () => _pmClient(clid, isZh),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: LayoutBuilder(builder: (context, constraints) {
              return Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: otherEntries.map((e) {
                  final rawStr = e.value?.toString() ?? '';
                  final valStr = rawStr.length > 500
                      ? '${rawStr.substring(0, 500)}...\n[Truncated, total ${rawStr.length} chars]'
                      : rawStr;
                  final isLongText = valStr.length > 35 || e.key.length > 25;
                  return SizedBox(
                    width: isLongText ? constraints.maxWidth : 200,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          valStr,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildVisualTable(ServerAdminState state, bool isZh) {
    if (state.visualData.isEmpty) {
      return ExpressiveEmptyState(
        message: isZh ? '没有数据或非可视化响应。' : 'No data or non-visual response.',
        icon: Icons.table_chart_rounded,
      );
    }

    // Filter out simple ok status responses
    final dataRows =
        state.visualData.where((r) => r['status'] != 'ok').toList();

    if (dataRows.isEmpty) {
      return ExpressiveEmptyState(
        message: state.visualData.any((r) => r['status'] == 'ok')
            ? (isZh ? '命令执行成功。' : 'Command executed successfully.')
            : (isZh ? '暂无数据。' : 'No data available.'),
        icon: state.visualData.any((r) => r['status'] == 'ok')
            ? Icons.check_circle_rounded
            : Icons.info_outline_rounded,
      );
    }

    if (state.currentQueryType == 'serverinfo') {
      final info = dataRows.first;
      // Extract and strictly sort the entries to prevent order changes
      final entries = info.entries.where((e) => e.key != 'status').toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      return SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: LayoutBuilder(builder: (context, constraints) {
                return Wrap(
                  spacing: 16.0,
                  runSpacing: 16.0,
                  children: entries.map((e) {
                    final rawStr = e.value?.toString() ?? '';
                    final valStr = rawStr.length > 500
                        ? '${rawStr.substring(0, 500)}...\n[Truncated, total ${rawStr.length} chars]'
                        : rawStr;
                    final isLongText = valStr.length > 35 || e.key.length > 25;
                    return SizedBox(
                      width: isLongText ? constraints.maxWidth : 200,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            valStr,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }),
            ),
          ),
        ),
      );
    }

    return SelectionArea(
        child: ListView.builder(
      itemCount: dataRows.length,
      itemBuilder: (ctx, idx) {
        final row = dataRows[idx];

        // Determine title and subtitle based on common keys
        String title = 'Item ${idx + 1}';
        String subtitle = '';
        Widget? leading;
        Widget? trailing;

        if (state.currentQueryType == 'channellist') {
          title = row['channel_name']?.toString() ?? 'Unknown Channel';
          subtitle = 'ID: ${row['cid'] ?? ''} | Parent: ${row['pid'] ?? '0'}';
          leading = const Icon(Icons.tag);

          // Instead of showing raw properties, we show clients in this channel
          final channelId = row['cid']?.toString();
          final clientsInChannel = state.cachedClients
              .where((c) => c['cid']?.toString() == channelId)
              .toList();

          final itemKey = '${state.currentQueryType}_${row['cid'] ?? idx}';

          return Card(
            key: ValueKey(itemKey),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ExpansionTile(
              key: PageStorageKey(itemKey),
              leading: leading,
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(subtitle),
              children: [
                if (clientsInChannel.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                        isZh
                            ? '该频道目前没有在线用户'
                            : 'No clients currently in this channel',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey)),
                  )
                else
                  ...clientsInChannel
                      .map((client) => _buildClientItem(client, isZh))
                      .toList(),
              ],
            ),
          );
        } else if (state.currentQueryType == 'clientlist') {
          return Card(
            key: ValueKey('${state.currentQueryType}_${row['clid'] ?? idx}'),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildClientItem(row, isZh),
          );
        } else if (state.currentQueryType == 'servergrouplist') {
          title = row['name']?.toString() ?? 'Unknown Server Group';
          final sgid = row['sgid'] ?? '';
          final type = row['type'] == '0'
              ? 'Template'
              : (row['type'] == '1' ? 'Regular' : 'Query');
          subtitle = 'SGID: $sgid | Type: $type';
          leading = const Icon(Icons.admin_panel_settings);
        } else if (state.currentQueryType == 'channelgrouplist') {
          title = row['name']?.toString() ?? 'Unknown Channel Group';
          final cgid = row['cgid'] ?? '';
          final type = row['type'] == '0'
              ? 'Template'
              : (row['type'] == '1' ? 'Regular' : 'Query');
          subtitle = 'CGID: $cgid | Type: $type';
          leading = const Icon(Icons.group_work);
        } else {
          // Fallback title for generic queries
          final titleKey = row.keys.firstWhere(
            (k) => k.contains('name') || k.contains('id'),
            orElse: () => row.keys.first,
          );
          title = row[titleKey]?.toString() ?? 'Item ${idx + 1}';
        }

        final otherEntries = row.entries
            .where((e) =>
                e.key != 'status' &&
                e.key != 'client_nickname' &&
                e.key != 'channel_name' &&
                e.key != 'name')
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        final itemKey =
            '${state.currentQueryType}_${row['cid'] ?? row['clid'] ?? row['sgid'] ?? row['cgid'] ?? idx}';

        return Card(
          key: ValueKey(itemKey),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            key: PageStorageKey(itemKey),
            leading: leading,
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
            trailing: trailing,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Wrap(
                      spacing: 16.0,
                      runSpacing: 16.0,
                      children: otherEntries.map((e) {
                        final rawStr = e.value?.toString() ?? '';
                        final valStr = rawStr.length > 500
                            ? '${rawStr.substring(0, 500)}...\n[Truncated, total ${rawStr.length} chars]'
                            : rawStr;
                        final isLongText =
                            valStr.length > 35 || e.key.length > 25;
                        return SizedBox(
                          width: isLongText ? constraints.maxWidth : 200,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.key,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                valStr,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final isZh = language == 'zh';
    final state = ref.watch(serverAdminProvider);
    final notifier = ref.read(serverAdminProvider.notifier);

    // Auto-scroll logic
    if (state.autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isZh ? '服务器管理' : 'Server Admin',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Row(
                children: [
                  if (!state.isVisualMode) ...[
                    FilterChip(
                      label: Text(isZh ? '自动滚动' : 'Auto Scroll'),
                      selected: state.autoScroll,
                      onSelected: (v) => notifier.toggleAutoScroll(v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(isZh ? '发送时清空' : 'Auto Clear'),
                      selected: state.autoClear,
                      onSelected: (v) => notifier.toggleAutoClear(v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(isZh ? '美观输出' : 'Pretty JSON'),
                      selected: state.isPrettyPrint,
                      onSelected: (v) => notifier.setPrettyPrint(v),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      tooltip: isZh ? '清空控制台' : 'Clear Console',
                      onPressed: () => notifier.clearLogs(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilterChip(
                    label: Text(isZh ? '可视化模式' : 'Visual Mode'),
                    selected: state.isVisualMode,
                    onSelected: (v) => notifier.setVisualMode(v),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              ActionChip(
                  label: Text(isZh ? '服务器信息' : 'Server Info'),
                  onPressed: () => notifier.sendCommand('serverinfo')),
              ActionChip(
                  label: Text(isZh ? '在线用户列表' : 'Client List'),
                  onPressed: () => notifier
                      .sendCommand('clientlist -uid -country -ip -groups')),
              ActionChip(
                  label: Text(isZh ? '频道列表' : 'Channel List'),
                  onPressed: () => notifier.fetchChannelsAndClients()),
              ActionChip(
                  label: Text(isZh ? '服务器组' : 'Server Groups'),
                  onPressed: () => notifier.sendCommand('servergrouplist')),
              ActionChip(
                  label: Text(isZh ? '频道组' : 'Channel Groups'),
                  onPressed: () => notifier.sendCommand('channelgrouplist')),
              ActionChip(
                  label: Text(isZh ? '全服广播' : 'Server Chat'),
                  onPressed: () => _serverChat(isZh)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cmdController,
                  decoration: InputDecoration(
                    labelText: isZh ? '原始查询命令' : 'Raw Query Command',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (val) {
                    notifier.sendCommand(val);
                    _cmdController.clear();
                  },
                ),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: () {
                  notifier.sendCommand(_cmdController.text);
                  _cmdController.clear();
                },
                child: Text(isZh ? '发送' : 'Send'),
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SelectionArea(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: double.infinity,
                  child: state.isVisualMode
                      ? _buildVisualTable(state, isZh)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16.0),
                          itemCount: state.logs.length,
                          itemBuilder: (context, index) {
                            final log = state.logs[index];
                            final color = log.isCommand
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).textTheme.bodyMedium?.color;
                            final prefix = log.isCommand ? '> ' : '';
                            final display = state.isPrettyPrint
                                ? (log.prettyText ?? log.text)
                                : log.text;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                '$prefix$display',
                                style: TextStyle(
                                  fontFamily: 'Google Sans Code',
                                  color: color,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
