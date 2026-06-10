import 'package:cached_network_image/cached_network_image.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/blocklist/presentation/targets_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/block_target.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Lists every blockable surface and lets the user toggle each. Premium targets
/// are gated behind the premium upgrade — but use the same switch rhythm as
/// every other row (a disabled switch is replaced by a "Premium" pill).
class BlocklistTab extends StatefulWidget {
  const BlocklistTab({this.scrollController, super.key});

  final ScrollController? scrollController;

  @override
  State<BlocklistTab> createState() => _BlocklistTabState();
}

class _BlocklistTabState extends State<BlocklistTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TargetsCubit, TargetsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const LoadingState(message: 'Loading blocklist…');
        }
        if (state.error != null) {
          return EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load the blocklist',
            subtitle: state.error,
            action: SecondaryButton(
              label: 'Retry',
              onPressed: () => context.read<TargetsCubit>().load(),
            ),
          );
        }

        final settings = context.watch<SettingsCubit>().state;
        final isPremium = state.isPremium;
        final showSearch = state.targets.length > 8;

        final q = _query.trim().toLowerCase();
        final filtered = q.isEmpty
            ? state.targets
            : state.targets
                .where((t) =>
                    t.displayName.toLowerCase().contains(q) ||
                    t.appName.toLowerCase().contains(q))
                .toList();

        final apps = filtered.where((t) => !t.isBrowser).toList();
        final browsers = filtered.where((t) => t.isBrowser).toList();

        return ListView(
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.floatingNavClearance + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            Text(
              'What to block',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Toggle the feeds and surfaces Detoxo should block.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (showSearch) ...[
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search apps & feeds',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (apps.isNotEmpty) ...[
              const _GroupHeader('Apps'),
              for (final target in apps) _targetTile(context, target, settings, isPremium),
            ],
            if (browsers.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              const _GroupHeader('Browsers'),
              for (final target in browsers) _targetTile(context, target, settings, isPremium),
            ],
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl),
                child: EmptyState(icon: Icons.search_off, title: 'No matches'),
              ),
          ],
        );
      },
    );
  }

  Widget _targetTile(BuildContext context, BlockTarget target, AppSettings settings, bool isPremium) {
    final locked = target.premiumExclusive && !isPremium;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AdaptiveSwitchTile(
        leading: _TargetAvatar(target: target),
        title: target.displayName,
        subtitle: target.appName,
        value: settings.enabledPlatformIds.contains(target.platformId),
        enabled: !locked,
        locked: locked,
        onLockedTap: () => context.push(Routes.premium),
        onChanged: (v) =>
            context.read<SettingsCubit>().togglePlatform(target.platformId, enabled: v),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _TargetAvatar extends StatelessWidget {
  const _TargetAvatar({required this.target});
  final BlockTarget target;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: AppRadius.brMd,
      ),
      child: Text(
        target.displayName.isNotEmpty ? target.displayName.characters.first.toUpperCase() : '?',
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent),
      ),
    );
    if (target.iconUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: AppRadius.brMd,
      child: CachedNetworkImage(
        imageUrl: target.iconUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
