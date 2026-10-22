import 'package:detoxo/app/bootstrap.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// The brand moment shown while [runBootstrap] hydrates the app.
///
/// It no longer routes. Gating moved to the router's single `redirect` (see
/// `AppGate`), which the bootstrap opens by flipping `ready` — so this screen
/// is what the user looks at, and nothing more.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runBootstrap(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Everything rises in once; nothing loops. The spinner is the design
    // system's, held still under Reduce Motion.
    return GlassScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: DetoxoLogo(height: 120),
            ).entrance(),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Detoxo',
              style: AppTypography.titleXl.copyWith(color: t.ink),
            ).entrance(delay: AppDurations.stagger),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reclaim your attention',
              style: AppTypography.body.copyWith(color: t.ink2),
            ).entrance(delay: AppDurations.stagger * 2),
            const SizedBox(height: AppSpacing.xxl),
            const LoadingState().entrance(delay: AppDurations.stagger * 3),
          ],
        ),
      ),
    );
  }
}
