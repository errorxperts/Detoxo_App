import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/blocklist/presentation/targets_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/block_target.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';

/// Lists every blockable surface and lets the user toggle each. Premium targets
/// are gated behind the premium upgrade.
class BlocklistTab extends StatelessWidget {
  const BlocklistTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TargetsCubit, TargetsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null) {
          return EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load the blocklist',
            subtitle: state.error,
            action: FilledButton(
              onPressed: () => context.read<TargetsCubit>().load(),
              child: const Text('Retry'),
            ),
          );
        }
        final settings = context.watch<SettingsCubit>().state;
        final isPremium = state.isPremium;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'What to block',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Toggle the feeds and surfaces Detoxo should block.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final target in state.targets)
              _TargetTile(
                target: target,
                enabled: settings.enabledPlatformIds.contains(target.platformId),
                locked: target.premiumExclusive && !isPremium,
              ),
          ],
        );
      },
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    required this.target,
    required this.enabled,
    required this.locked,
  });

  final BlockTarget target;
  final bool enabled;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          child: Text(
            target.displayName.isNotEmpty
                ? target.displayName.characters.first.toUpperCase()
                : '?',
          ),
        ),
        title: Text(target.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(target.appName),
        trailing: locked
            ? TextButton.icon(
                onPressed: () => context.push(Routes.premium),
                icon: const Icon(Icons.lock, size: 16),
                label: const Text('Premium'),
              )
            : Switch(
                value: enabled,
                onChanged: (v) => context
                    .read<SettingsCubit>()
                    .togglePlatform(target.platformId, v),
              ),
      ),
    );
  }
}
