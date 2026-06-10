import 'package:detoxo/core/design_system/design_system.dart';
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
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        AppSpacing.floatingNavClearance + MediaQuery.viewPaddingOf(context).bottom,
      ),
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
              leading: const AppAnimatedIcon(
                icon: AppIcon.premium,
                size: 24,
                playOnAppear: true,
              ),
              title: const Text('Go Premium'),
              subtitle: const Text('Unlock every blocker and remove ads'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.premium),
            ),
          ),
        const SizedBox(height: 8),
        FeatureTile(
          icon: Icons.apps,
          animatedIcon: AppIcon.appBlocker,
          title: 'App blocker',
          subtitle: 'PIN-lock whole apps',
          onTap: () => context.push(Routes.appBlock),
        ),
        FeatureTile(
          icon: Icons.public_off,
          animatedIcon: AppIcon.websiteBlocker,
          title: 'Website blocker',
          subtitle: 'Block distracting sites in your browser',
          onTap: () => context.push(Routes.webBlock),
        ),
        FeatureTile(
          icon: Icons.hourglass_bottom,
          animatedIcon: AppIcon.dailyLimit,
          title: 'Daily limit',
          subtitle: 'Cap your short-video time per day',
          onTap: () => context.push(Routes.dailyLimit),
        ),
        FeatureTile(
          icon: Icons.bar_chart,
          animatedIcon: AppIcon.activity,
          title: 'Activity',
          subtitle: 'See what you blocked',
          onTap: () => context.push(Routes.analytics),
        ),
        FeatureTile(
          icon: Icons.lock,
          animatedIcon: AppIcon.pinLock,
          title: 'PIN lock',
          subtitle: 'Protect settings with a PIN',
          onTap: () => context.push(Routes.pinSetup),
        ),
        FeatureTile(
          icon: Icons.settings,
          animatedIcon: AppIcon.settings,
          title: 'Settings',
          subtitle: 'Block mode, haptics and more',
          onTap: () => context.push(Routes.settings),
        ),
      ],
    );
  }
}
