import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:detoxo/core/design_system/components/badges.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The spec SHEET, for every bottom sheet and dialog: a [DxSurface.sheet]
/// inset 10 from the screen edges, a 40×5 grabber, an optional `titleSheet`
/// title, over a blurred radial scrim.
///
/// - The sheet slides in over [AppDurations.sheet] and the scrim fades over
///   [AppDurations.scrim]; neither moves under Reduce Motion.
/// - Dragging the grabber or title down past [dismissDrag] closes it; a
///   shorter drag springs back.
/// - `dismissible: false` locks it: no barrier tap, no drag, no back. The
///   caller must supply an action that pops it.
/// - `glow` paints the canvas's soft light behind the top edge (the Session
///   sheet passes its palette's main).
abstract final class GlassBottomSheet {
  /// How far a drag must pull the sheet down to close it.
  static const double dismissDrag = 110;

  @visibleForTesting
  static const Key grabberKey = ValueKey('GlassBottomSheet.grabber');

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isScrollControlled = true,
    bool dismissible = true,
    Color? glow,
  }) {
    final navigator = Navigator.of(context);
    final l10n = MaterialLocalizations.of(context);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return navigator.push(
      _SheetRoute<T>(
        builder: (_) => _Sheet(
          title: title,
          dismissible: dismissible,
          glow: glow,
          child: child,
        ),
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        isScrollControlled: isScrollControlled,
        barrierLabel: l10n.scrimLabel,
        barrierOnTapHint: l10n.scrimOnTapHint(l10n.bottomSheetLabel),
        backgroundColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: Colors.transparent,
        isDismissible: dismissible,
        enableDrag: false,
        useSafeArea: true,
        sheetAnimationStyle: still
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                duration: AppDurations.sheet,
                reverseDuration: AppDurations.sheet,
                curve: AppCurves.sheet,
                reverseCurve: FlippedCurve(AppCurves.sheet),
              ),
      ),
    );
  }
}

/// Material's modal sheet route with the spec scrim as its barrier.
class _SheetRoute<T> extends ModalBottomSheetRoute<T> {
  _SheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.modalBarrierColor,
    super.isDismissible,
    super.enableDrag,
    super.useSafeArea,
    super.sheetAnimationStyle,
  });

  // The scrim's 450 ms inside the sheet's 600 ms, on CSS `ease`: it leads
  // both ways, as the canvas's two transitions start together.
  static const double _lead = 450 / 600;

  late final CurvedAnimation _scrim = CurvedAnimation(
    parent: animation!,
    curve: const Interval(0, _lead, curve: AppCurves.glide),
    reverseCurve: const Interval(
      1 - _lead,
      1,
      curve: FlippedCurve(AppCurves.glide),
    ),
  );

  @override
  Widget buildModalBarrier() => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        child: FadeTransition(opacity: _scrim, child: const _Scrim()),
      ),
      // Transparent, so Material's plain barrier: taps, semantics, dismiss.
      super.buildModalBarrier(),
    ],
  );

  @override
  void dispose() {
    _scrim.dispose();
    super.dispose();
  }
}

/// The scrim: the backdrop blurred and lifted, under a radial dim that is
/// deepest at the bottom (`120% 70% at 50% 100%`, stops 0 / 60 / 100 %).
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return BackdropFilter(
      filter: ui.ImageFilter.compose(
        outer: ui.ColorFilter.matrix(cssSaturate(AppTokens.scrimSaturate)),
        inner: ui.ImageFilter.blur(
          sigmaX: AppTokens.scrimBlur,
          sigmaY: AppTokens.scrimBlur,
        ),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _EllipsePainter(
          centre: (size) => Offset(size.width / 2, size.height),
          radii: (size) => Size(size.width * 1.2, size.height * 0.7),
          colors: [
            t.scrim.withValues(alpha: t.kScrim0),
            t.scrim.withValues(alpha: t.kScrim60),
            t.scrim.withValues(alpha: t.kScrim100),
          ],
          stops: const [0, 0.6, 1],
        ),
      ),
    );
  }
}

/// A CSS elliptical `radial-gradient` filling the whole box: [colors] from
/// [centre] out to an ellipse of [radii], the last colour beyond it.
class _EllipsePainter extends CustomPainter {
  const _EllipsePainter({
    required this.centre,
    required this.radii,
    required this.colors,
    required this.stops,
  });

  final Offset Function(Size) centre;
  final Size Function(Size) radii;
  final List<Color> colors;
  final List<double> stops;

  @override
  void paint(Canvas canvas, Size size) {
    final c = centre(size);
    final r = radii(size);
    // In a frame scaled to the radii the ellipse is the unit circle.
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(r.width, r.height)
      ..drawRect(
        Rect.fromLTRB(
          -c.dx / r.width,
          -c.dy / r.height,
          (size.width - c.dx) / r.width,
          (size.height - c.dy) / r.height,
        ),
        Paint()..shader = ui.Gradient.radial(Offset.zero, 1, colors, stops),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_EllipsePainter old) =>
      !listEquals(old.colors, colors) || !listEquals(old.stops, stops);
}

class _Sheet extends StatefulWidget {
  const _Sheet({
    required this.title,
    required this.dismissible,
    required this.glow,
    required this.child,
  });

  final String? title;
  final bool dismissible;
  final Color? glow;
  final Widget child;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  /// The sheet's distance from rest while dragged down.
  double _dy = 0;
  bool _dragging = false;

  void _drag(DragUpdateDetails d) => setState(() {
    _dragging = true;
    _dy = math.max(0, _dy + d.delta.dy);
  });

  void _release([DragEndDetails? _]) {
    if (_dy > GlassBottomSheet.dismissDrag) {
      // The route slides it out from where the finger left it.
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _dragging = false;
      _dy = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mq = MediaQuery.of(context);
    final title = widget.title;

    Widget header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: GlassBottomSheet.grabberKey,
          height: 30,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: t.grabber,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        if (title != null) ...[
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleSheet.copyWith(color: t.ink),
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
        ],
      ],
    );
    if (widget.dismissible) {
      header = GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onVerticalDragUpdate: _drag,
        onVerticalDragEnd: _release,
        onVerticalDragCancel: _release,
        child: header,
      );
    }

    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Flexible(child: widget.child),
      ],
    );
    final glow = widget.glow;
    if (glow != null) {
      // A 340×260 light centred 10 px below the top edge, fading out to its
      // edges; the sheet's own clip trims it.
      body = CustomPaint(
        painter: _EllipsePainter(
          centre: (size) => Offset(size.width / 2, 10),
          radii: (_) => const Size(170, 130),
          colors: [
            glow.withValues(alpha: t.kSheetGlow),
            glow.withAlpha(0),
          ],
          stops: const [0, 1],
        ),
        child: body,
      );
    }

    return PopScope(
      canPop: widget.dismissible,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _inset,
          0,
          _inset,
          _inset + mq.padding.bottom + mq.viewInsets.bottom,
        ),
        child: AnimatedContainer(
          duration: _dragging
              ? Duration.zero
              : context.motion(AppDurations.press),
          curve: AppCurves.press,
          transform: Matrix4.translationValues(0, _dy, 0),
          // The sheet already clears the system bars; nested lists must not
          // pad for them again.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: GlassContainer(
              surface: DxSurface.sheet,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sheetSide,
                0,
                AppSpacing.sheetSide,
                AppSpacing.sheetSide,
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  /// The sheet's gap to the screen edges (`.dx-sheet` sits 10 px in).
  static const double _inset = 10;
}

/// A floating glass toast (replaces raw `ScaffoldMessenger` snackbars): the
/// tone's glyph and the message in ink, never a tone colour, with an optional
/// inline `action` such as Undo.
///
/// It stays 4 s, 6 s with an action, and 10 s while a screen reader or
/// switch access is navigating. Reduce Motion drops its slide.
abstract final class GlassToast {
  static void show(
    BuildContext context,
    String message, {
    AppTone tone = AppTone.neutral,
    ({String label, VoidCallback onPressed})? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final mq = MediaQuery.of(context);
    final glyph = switch (tone) {
      AppTone.success => Icons.check_circle_outline,
      AppTone.danger => Icons.error_outline,
      AppTone.warning => Icons.warning_amber_outlined,
      _ => Icons.info_outline,
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          clipBehavior: Clip.none,
          persist: false,
          duration: mq.accessibleNavigation
              ? const Duration(seconds: 10)
              : Duration(seconds: action == null ? 4 : 6),
          content: _Toast(
            glyph: glyph,
            message: message,
            action: action == null
                ? null
                : (
                    label: action.label,
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      action.onPressed();
                    },
                  ),
          ),
        ),
        snackBarAnimationStyle: mq.disableAnimations
            ? AnimationStyle.noAnimation
            : null,
      );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({
    required this.glyph,
    required this.message,
    required this.action,
  });

  final IconData glyph;
  final String message;
  final ({String label, VoidCallback onPressed})? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final action = this.action;
    return GlassContainer(
      surface: DxSurface.glass,
      // An action brings its own 48 dp target, so the pill trims around it.
      padding: action == null
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            )
          : const EdgeInsets.fromLTRB(AppSpacing.md, 4, 4, 4),
      child: Row(
        children: [
          Icon(glyph, size: 20, color: t.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.label.copyWith(color: t.ink),
            ),
          ),
          if (action != null)
            AppPressable(
              onTap: action.onPressed,
              radius: AppRadius.brPill,
              semanticLabel: action.label,
              minTapTarget: AppSizes.minTapTargetSquare,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: ExcludeSemantics(
                  child: Text(
                    action.label,
                    style: AppTypography.labelStrong.copyWith(color: t.ink),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
