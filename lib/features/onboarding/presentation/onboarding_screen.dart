import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie_tgs/lottie.dart';

class _Page {
  const _Page({
    required this.accent,
    required this.title,
    required this.body,
    this.illustration,
    this.fallbackIcon,
    this.isWelcome = false,
  });

  final Color accent;
  final String title;
  final String body;
  final String? illustration;
  final IconData? fallbackIcon;
  final bool isWelcome;
}

/// A short value-prop intro funnel over the ambient gradient. Ends by marking
/// the user onboarded and moving on to the permission flow.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static final List<_Page> _pages = [
    const _Page(
      accent: AppColors.seed,
      title: 'Welcome to Detoxo',
      body:
          'Your calm companion for breaking free from short-form video and reclaiming your attention.',
      isWelcome: true,
    ),
    _Page(
      accent: AppColors.seed,
      title: 'Stop the doom-scroll',
      body:
          'Detoxo detects Reels, Shorts and infinite feeds the moment they appear and pulls you straight back out.',
      illustration: Assets.lottie.bow,
      fallbackIcon: Icons.motion_photos_off,
    ),
    _Page(
      accent: AppColors.onbTeal,
      title: 'You stay in control',
      body:
          'Choose exactly which apps and surfaces to block. Pause when you genuinely need to, with a mindful cooldown.',
      illustration: Assets.lottie.nightyNight,
      fallbackIcon: Icons.tune,
    ),
    _Page(
      accent: AppColors.onbViolet,
      title: 'Build the habit',
      body:
          'Daily limits, schedules and a PIN lock keep you honest long after the motivation fades.',
      illustration: Assets.lottie.glasses,
      fallbackIcon: Icons.lock_clock,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final settings = sl<SettingsRepository>();
    await settings.save((await settings.load()).copyWith(onboarded: true));
    if (mounted) context.go(Routes.permissions);
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: AppDurations.medium, curve: AppCurves.standard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return GlassScaffold(
      safeArea: false,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) =>
                _PageView(page: _pages[i], controller: _controller, index: i),
          ),
          // Skip — fades out on the last page.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                duration: AppDurations.fast,
                opacity: isLast ? 0 : 1,
                child: GhostButton(label: 'Skip', onPressed: isLast ? null : _finish),
              ),
            ),
          ),
          // Page indicator + primary CTA, overlaid at the bottom.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: AppDurations.fast,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index ? _pages[_index].accent : context.glass.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: isLast ? 'Get started' : 'Next',
                      tint: _pages[_index].accent,
                      expand: true,
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page, required this.controller, required this.index});

  final _Page page;
  final PageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 96, AppSpacing.xl, 160),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Parallax: the illustration drifts slower than the swipe.
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final page = controller.positions.isEmpty ? index.toDouble() : (controller.page ?? 0);
              final delta = (page - index) * 60;
              return Transform.translate(offset: Offset(delta, 0), child: child);
            },
            child: _Illustration(page: page),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ).animate(key: ValueKey('t$index')).fadeIn(delay: 80.ms).slideY(begin: 0.15, end: 0),
          const SizedBox(height: AppSpacing.md),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: context.glass.onGlassMuted),
          ).animate(key: ValueKey('b$index')).fadeIn(delay: 160.ms).slideY(begin: 0.15, end: 0),
        ],
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [page.accent.withValues(alpha: 0.35), page.accent.withValues(alpha: 0)],
        ),
      ),
      child: SizedBox(
        height: 150,
        child: page.isWelcome
            ? Image.asset('assets/images/detox_logo_no_bg.png', fit: BoxFit.contain)
            : Lottie.asset(
                page.illustration ?? '',
                errorBuilder: (context, error, stackTrace) => _fallback(page),
              ),
      ),
    );
  }

  Widget _fallback(_Page page) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(page.fallbackIcon, size: 64, color: Colors.white),
      ),
    );
  }
}
