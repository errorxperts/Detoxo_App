import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/design_system/tokens/app_blur.dart';
import 'package:detoxo/core/design_system/tokens/app_colors.dart';

/// Full-screen ambient gradient + soft brand "mesh" blobs. ONE cheap paint
/// layer (no per-card blur) so glass surfaces above it have something real to
/// blur. Place a single instance behind each screen via [GlassScaffold].
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({required this.child, this.animated = true, super.key});

  final Widget child;

  /// Subtle drift on the blobs. Disabled automatically under reduced-motion.
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final drift = animated && !reduceMotion;

    Widget blob({required Alignment align, required Color color, required double size}) {
      Widget b = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
      if (drift) {
        b = b
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .move(
              begin: Offset.zero,
              end: const Offset(24, -28),
              duration: 6.seconds,
              curve: Curves.easeInOut,
            );
      }
      return Align(alignment: align, child: b);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surfaceDark),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                blob(
                  align: const Alignment(-0.9, -1.1),
                  color: AppColors.seed.withValues(alpha: 0.40),
                  size: 460,
                ),
                blob(
                  align: const Alignment(1.2, -0.2),
                  color: AppColors.accent.withValues(alpha: 0.32),
                  size: 380,
                ),
                blob(
                  align: const Alignment(-0.3, 1.3),
                  color: AppColors.seed.withValues(alpha: 0.30),
                  size: 420,
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Standard screen chrome: a transparent [Scaffold] layered over an
/// [AmbientBackground]. Flagship screens return this instead of a raw Scaffold.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    required this.body,
    this.appBar,
    this.bottomBar,
    this.floatingActionButton,
    this.extendBody = true,
    this.extendBehindAppBar = true,
    this.animatedBackground = true,
    this.safeArea = true,
    super.key,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final bool extendBody;
  final bool extendBehindAppBar;
  final bool animatedBackground;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final content = safeArea ? SafeArea(bottom: bottomBar == null, child: body) : body;
    return AmbientBackground(
      animated: animatedBackground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: extendBody,
        extendBodyBehindAppBar: extendBehindAppBar,
        appBar: appBar,
        bottomNavigationBar: bottomBar,
        floatingActionButton: floatingActionButton,
        body: content,
      ),
    );
  }
}

/// A frosted top app bar. Content scrolls under it because [GlassScaffold]
/// extends the body behind the app bar.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({this.title, this.actions, this.leading, super.key});

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppBlur.bar, sigmaY: AppBlur.bar),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.glass.border)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: title,
            actions: actions,
            leading: leading,
          ),
        ),
      ),
    );
  }
}

/// A frosted bottom bar wrapping its [child] (e.g. an adaptive tab bar). One
/// backdrop for the whole bar — never one per item. Pass `enableBlur: false`
/// when the child is itself a native blurred surface (iOS CNTabBar).
class GlassBottomBar extends StatelessWidget {
  const GlassBottomBar({required this.child, this.enableBlur = true, super.key});

  final Widget child;
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: enableBlur ? context.glass.fillTop : Colors.transparent,
        border: Border(top: BorderSide(color: context.glass.border)),
      ),
      child: SafeArea(top: false, child: child),
    );
    if (!enableBlur) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppBlur.bar, sigmaY: AppBlur.bar),
        child: bar,
      ),
    );
  }
}
