import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_entry.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_repository.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_block_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WebBlockScreen extends StatelessWidget {
  const WebBlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WebBlockCubit(sl<WebBlockRepository>())..load(),
      child: const _WebBlockView(),
    );
  }
}

class _WebBlockView extends StatelessWidget {
  const _WebBlockView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Website blocker')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Add site'),
      ),
      body: SafeArea(
        child: BlocBuilder<WebBlockCubit, List<WebBlockEntry>>(
        builder: (context, entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.public_off,
              title: 'No blocked sites yet',
              subtitle: 'Add domains like youtube.com to block them in browsers.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(entry.pattern),
                  subtitle: Text('${entry.matchType.name} · ${entry.blockMode.wire}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: entry.enabled,
                        onChanged: (v) =>
                            context.read<WebBlockCubit>().toggle(i, enabled: v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            context.read<WebBlockCubit>().removeAt(i),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        ),
      ),
    );
  }

  Future<void> _showAdd(BuildContext context) async {
    final cubit = context.read<WebBlockCubit>();
    final controller = TextEditingController();
    var type = WebMatchType.domain;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Block a website'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'e.g. youtube.com'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WebMatchType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Match'),
                items: WebMatchType.values
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setState(() => type = v ?? type),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                cubit.add(controller.text, type, BlockingMode.pressBack);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
