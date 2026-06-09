import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/theme/app_colors.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:ms_undraw/ms_undraw.dart';

/// One onboarding slide. [illustration] is null for the branded welcome page,
/// which shows the app logo instead. [fallbackIcon] doubles as the loading
/// placeholder and the offline/error widget for the undraw illustration (which
/// is fetched from the network on first display and then disk-cached).
class _Page {
  const _Page({
    required this.bg,
    required this.title,
    required this.body,
    this.illustration,
    this.fallbackIcon,
    this.isWelcome = false,
  });

  final Color bg;
  final String title;
  final String body;
  final UnDrawIllustration? illustration;
  final IconData? fallbackIcon;
  final bool isWelcome;
}

/// A short value-prop intro funnel. Ends by marking the user onboarded and
/// moving on to the permission flow. Uses liquid_swipe for the page
/// transitions and ms_undraw line-art for the illustrations.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = LiquidController();
  int _index = 0;

  // Deepened brand tones so white text/illustrations stay legible on every page.
  static const _teal = Color(0xFF0F8B7E);
  static const _violet = Color(0xFF5B3FB8);

  static const _pages = [
    _Page(
      bg: AppColors.surfaceDark,
      title: 'Welcome to Detoxo',
      body:
          'Your calm companion for breaking free from short-form video and reclaiming your attention.',
      isWelcome: true,
    ),
    _Page(
      bg: AppColors.seed,
      title: 'Stop the doom-scroll',
      body:
          'Detoxo detects Reels, Shorts and infinite feeds the moment they appear and pulls you straight back out.',
      illustration: UnDrawIllustration.screen_time,
      fallbackIcon: Icons.motion_photos_off,
    ),
    _Page(
      bg: _teal,
      title: 'You stay in control',
      body:
          'Choose exactly which apps and surfaces to block. Pause when you genuinely need to, with a mindful cooldown.',
      illustration: UnDrawIllustration.control_panel,
      fallbackIcon: Icons.tune,
    ),
    _Page(
      bg: _violet,
      title: 'Build the habit',
      body:
          'Daily limits, schedules and a PIN lock keep you honest long after the motivation fades.',
      illustration: UnDrawIllustration.healthy_habit,
      fallbackIcon: Icons.lock_clock,
    ),
  ];

  Future<void> _finish() async {
    final settings = sl<SettingsRepository>();
    await settings.save((await settings.load()).copyWith(onboarded: true));
    if (mounted) context.go(Routes.permissions);
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _controller.animateToPage(page: _index + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    final current = _pages[_index];
    return Scaffold(
      body: Stack(
        children: [
          LiquidSwipe(
            liquidController: _controller,
            enableLoop: false,
            ignoreUserGestureWhileAnimating: true,
            positionSlideIcon: 0.5,
            slideIconWidget: const Icon(Icons.arrow_back_ios, color: Colors.white70),
            onPageChangeCallback: (i) => setState(() => _index = i),
            pages: [for (final page in _pages) _buildPage(context, page)],
          ),
          // Skip — fades out on the last page.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isLast ? 0 : 1,
                child: TextButton(
                  onPressed: isLast ? null : _finish,
                  child: const Text('Skip', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
          // Page indicator + primary CTA, overlaid at the bottom.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index ? Colors.white : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: Colors.white,
                          foregroundColor: current.bg,
                        ),
                        onPressed: _next,
                        child: Text(isLast ? 'Get started' : 'Next'),
                      ),
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

  Widget _buildPage(BuildContext context, _Page page) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      color: page.bg,
      padding: const EdgeInsets.fromLTRB(32, 88, 32, 170),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 220,
            child: page.isWelcome
                ? Image.asset('assets/images/detox_logo_no_bg.png', fit: BoxFit.contain)
                : UnDraw(
                    illustration: page.illustration!,
                    color: Colors.white,
                    placeholder: _fallback(page),
                    errorWidget: _fallback(page),
                  ),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  /// Circular icon shown while the undraw SVG loads and if it fails to load
  /// (e.g. a cold/offline first launch), so the slide still looks intentional.
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
