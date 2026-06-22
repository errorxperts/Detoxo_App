import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/limits/app_blocker/domain/entities/app_block_entry.dart';
import 'package:detoxo/features/limits/app_blocker/domain/repositories/app_block_repository.dart';
import 'package:detoxo/features/limits/app_blocker/presentation/app_block_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppBlockScreen extends StatelessWidget {
  const AppBlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppBlockCubit(sl<AppBlockRepository>())..load(),
      child: const _AppBlockView(),
    );
  }
}

class _AppBlockView extends StatelessWidget {
  const _AppBlockView();

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('App blocker')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Add app'),
      ),
      body: SafeArea(
        child: BlocBuilder<AppBlockCubit, List<AppBlockEntry>>(
          builder: (context, entries) {
            if (entries.isEmpty) {
              return const EmptyState(
                icon: Icons.apps,
                title: 'No blocked apps yet',
                subtitle:
                    'Add an app package (e.g. com.instagram.android) to lock it.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final entry = entries[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    title: entry.appName,
                    subtitle: entry.packageName,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppToggle(
                          value: entry.enabled,
                          onChanged: (v) => context
                              .read<AppBlockCubit>()
                              .toggle(i, enabled: v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              context.read<AppBlockCubit>().removeAt(i),
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
    final cubit = context.read<AppBlockCubit>();
    final pkgController = TextEditingController();
    final nameController = TextEditingController();
    await AppDialog.show<void>(
      context: context,
      title: 'Block an app',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'App name'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: pkgController,
            decoration: const InputDecoration(
              labelText: 'Package (com.example.app)',
            ),
          ),
        ],
      ),
      actions: [
        GhostButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PrimaryButton(
          label: 'Add',
          onPressed: () {
            cubit.add(pkgController.text, nameController.text);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
