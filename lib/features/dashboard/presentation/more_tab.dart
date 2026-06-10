import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/monetization/premium/presentation/premium_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Entry points to the secondary features and settings.
class MoreTab extends StatelessWidget {
  const MoreTab({this.scrollController, super.key});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumCubit>().state.isPremium;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          'More',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        if (!isPremium)
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: ListTile(
              leading: const Icon(Icons.workspace_premium),
              title: const Text('Go Premium'),
              subtitle: const Text('Unlock every blocker and remove ads'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.premium),
            ),
          ),
        const SizedBox(height: 8),
        FeatureTile(
          icon: Icons.apps,
          title: 'App blocker',
          subtitle: 'PIN-lock whole apps',
          onTap: () => context.push(Routes.appBlock),
        ),
        FeatureTile(
          icon: Icons.public_off,
          title: 'Website blocker',
          subtitle: 'Block distracting sites in your browser',
          onTap: () => context.push(Routes.webBlock),
        ),
        FeatureTile(
          icon: Icons.hourglass_bottom,
          title: 'Daily limit',
          subtitle: 'Cap your short-video time per day',
          onTap: () => context.push(Routes.dailyLimit),
        ),
        FeatureTile(
          icon: Icons.bar_chart,
          title: 'Activity',
          subtitle: 'See what you blocked',
          onTap: () => context.push(Routes.analytics),
        ),
        FeatureTile(
          icon: Icons.lock,
          title: 'PIN lock',
          subtitle: 'Protect settings with a PIN',
          onTap: () => context.push(Routes.pinSetup),
        ),
        FeatureTile(
          icon: Icons.settings,
          title: 'Settings',
          subtitle: 'Block mode, haptics and more',
          onTap: () => context.push(Routes.settings),
        ),
      ],
    );
  }
}
