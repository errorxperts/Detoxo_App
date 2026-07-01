import 'dart:ui';

import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/design_system/tokens/app_blur.dart';
import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    this.endDrawer,
    this.scaffoldKey,
    this.drawerScrimColor,
    this.endDrawerEnableOpenDragGesture = true,
    this.extendBody = true,
    this.animatedBackground = true,
    this.safeArea = true,
    super.key,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  /// An optional right-side ([endDrawer]) panel. Pass [scaffoldKey] so callers
  /// can open it via `scaffoldKey.currentState?.openEndDrawer()`.
  final Widget? endDrawer;
  final Key? scaffoldKey;
  final Color? drawerScrimColor;
  final bool endDrawerEnableOpenDragGesture;

  final bool extendBody;
  final bool animatedBackground;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final hasAppBar = appBar != null;
    // The app bar already clears the status bar, so only inset the top when
    // there's no app bar; the bottom bar handles its own bottom inset.
    final content = safeArea
        ? SafeArea(top: !hasAppBar, bottom: bottomBar == null, child: body)
        : body;
    return AmbientBackground(
      animated: animatedBackground,
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.transparent,
        extendBody: extendBody,
        // extendBodyBehindAppBar stays at its default (false) so the body sits
        // below the frosted app bar instead of being hidden behind it.
        appBar: appBar,
        bottomNavigationBar: bottomBar,
        floatingActionButton: floatingActionButton,
        endDrawer: endDrawer,
        drawerScrimColor: drawerScrimColor,
        endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
        body: content,
      ),
    );
  }
}

/// A frosted top app bar that blurs the ambient gradient behind it.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({this.title, this.actions, this.leading, super.key});

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;

  /// App-wide trailing actions appended to *every* [GlassAppBar] after the
  /// screen's own [actions] (e.g. the global feedback button). Registered once
  /// at startup via a builder so the design system stays decoupled from feature
  /// code — the design system just invokes it; the feature decides what to show.
  static List<Widget> Function(BuildContext context)? globalActionsBuilder;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final globals = globalActionsBuilder?.call(context) ?? const <Widget>[];
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
            actions: [...?actions, ...globals],
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
