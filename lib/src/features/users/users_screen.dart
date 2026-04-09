import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_tsm/src/features/users/users_notifier.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usersProvider);
    final notifier = ref.read(usersProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Users',
            onPressed: state.isLoading ? null : () => notifier.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.red.shade100,
              width: double.infinity,
              child: Text(
                'Error: ${state.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (state.isLoading && state.users.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.users.isEmpty)
            const Expanded(child: Center(child: Text('No users online.')))
          else
            Expanded(
              child: SelectionArea(
                child: ListView.builder(
                  itemCount: state.users.length,
                  itemBuilder: (context, index) {
                    final user = state.users[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4.0),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user.clientNickname),
                        subtitle: Text(
                          'Client ID: ${user.clientId} | DB ID: ${user.clientDatabaseId} | Channel: ${user.cid}',
                        ),
                        trailing:
                            Text(user.clientType == 1 ? 'Query' : 'Voice'),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
