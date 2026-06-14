import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/blocking/blocklist/presentation/targets_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/monetization/premium/presentation/premium_cubit.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Boots the app state, then routes to onboarding / PIN lock / permissions /
/// home depending on what the user has already set up.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final settings = context.read<SettingsCubit>();
    final targets = context.read<TargetsCubit>();
    final permissions = context.read<PermissionsCubit>();
    final pin = context.read<PinCubit>();
    final premium = context.read<PremiumCubit>();

    await Future.wait([
      settings.bootstrap(),
      targets.load(),
      permissions.refresh(),
      pin.load(),
      premium.load(),
    ]);

    // First run: seed the enabled set from each target's default status.
    if (settings.state.enabledPlatformIds.isEmpty) {
      final defaults = targets.state.targets
          .where((t) => t.defaultEnabled)
          .map((t) => t.platformId)
          .toSet();
      if (defaults.isNotEmpty) await settings.setEnabledPlatforms(defaults);
    }

    if (!mounted) return;

    if (!settings.state.onboarded) {
      context.go(Routes.onboarding);
      return;
    }
    if (pin.state.isConfigured && pin.state.guards(PinScope.app)) {
      context.go(Routes.pinLock);
      return;
    }
    if (!permissions.allRequiredGranted) {
      context.go(Routes.permissions);
      return;
    }
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.glowIndigo,
                  ),
                  child: Image.asset(
                    Assets.images.detoxLogoNoBg.path,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                )
                .animate()
                .fadeIn(duration: AppDurations.medium)
                .scaleXY(begin: 0.85, end: 1, curve: Curves.easeOutBack),
            const SizedBox(height: AppSpacing.xl),
            Text('Detoxo', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800))
                .animate()
                .fadeIn(delay: 200.ms, duration: AppDurations.normal)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reclaim your attention',
              style: text.bodyMedium,
            ).animate().fadeIn(delay: 350.ms, duration: AppDurations.normal),
            const SizedBox(height: AppSpacing.xxl),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}
