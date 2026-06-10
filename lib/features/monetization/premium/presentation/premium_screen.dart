import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/monetization/premium/domain/entities/premium_entitlement.dart';
import 'package:detoxo/features/monetization/premium/presentation/premium_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const _features = [
    'Block in-app & web short video',
    'Unlock every platform & block mode',
    'App blocker & website blocker',
    'Remove ads',
    'Priority support',
  ];

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Detoxo Premium')),
      body: BlocBuilder<PremiumCubit, PremiumEntitlement>(
        builder: (context, premium) {
          final text = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _Hero(isPremium: premium.isPremium),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                title: "What's included",
                child: Column(
                  children: [
                    for (final (i, feature) in _features.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Row(
                          children: [
                            AppAnimatedIcon(
                              icon: AppIcon.check,
                              color: AppColors.success,
                              size: 20,
                              interactive: true,
                              playOnAppear: true,
                              appearDelay: AppDurations.stagger * i,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text(feature)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!premium.isPremium)
                AnimatedIconButton(
                  label: 'Upgrade',
                  icon: AppIcon.premium,
                  tint: AppColors.accent,
                  expand: true,
                  onPressed: () => _upgrade(context),
                )
              else
                SecondaryButton(
                  label: 'Restore purchases',
                  expand: true,
                  onPressed: () => context.read<PremiumCubit>().restore(),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tip: enable “Premium dev-unlock” in Settings to try premium '
                'features without a store purchase in this build.',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _upgrade(BuildContext context) async {
    final error = await context.read<PremiumCubit>().purchase('premium_yearly');
    if (context.mounted && error != null) {
      GlassToast.show(context, error, tone: AppTone.danger);
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      accent: AppColors.accent,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brand,
              boxShadow: AppShadows.glowTeal,
            ),
            child: const AppAnimatedIcon(
              icon: AppIcon.premium,
              size: 40,
              color: Colors.white,
              interactive: true,
              playOnAppear: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isPremium ? 'You are Premium 🎉' : 'Go Premium',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isPremium
                ? 'Thanks for supporting Detoxo.'
                : 'Unlock every feature and reclaim your focus.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: context.glass.onGlassMuted),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppDurations.normal).slideY(begin: 0.08, end: 0);
  }
}
