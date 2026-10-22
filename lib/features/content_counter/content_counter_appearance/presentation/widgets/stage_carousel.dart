import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// The stage-and-rail pieces the appearance pickers share (Home widget,
/// Bubble style): a pager whose off-centre pages shrink and dim, the glass
/// surface each page sits on, and a rail of thumbnails that stagger in and
/// keep the selected one in view.

/// A stage page's surface: the design system's panel,
/// inset [AppSpacing.xxs] each side so
/// neighbouring pages keep a gap. [child] sits inside [padding], clipped to
/// the glass.
class StageSurface extends StatelessWidget {
  const StageSurface({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
    child: GlassContainer(padding: padding, child: child),
  );
}

/// One stage page, shrinking, dimming and pulled [peek] toward the centre as
/// it slides off it, and hidden from screen readers unless centred (the pager
/// carries the swipe). Driven by the controller itself, never by a per-frame
/// `setState`.
class StagePage extends StatelessWidget {
  const StagePage({
    required this.controller,
    required this.index,
    required this.child,
    this.peek = 0,
    super.key,
  });

  final PageController controller;
  final int index;
  final double peek;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // One attached pager only: a "remove animations" toggle re-inflates
        // the stage, and for a frame two of them share this controller.
        final page = controller.positions.length == 1 ? controller.page : null;
        final at = page ?? controller.initialPage.toDouble();
        // < 0 for a page right of centre, > 0 left of it.
        final d = (at - index).clamp(-1.0, 1.0);
        final off = d.abs();
        return ExcludeSemantics(
          excluding: at.round() != index,
          child: Opacity(
            opacity: 1 - 0.45 * off,
            child: Transform.translate(
              offset: Offset(d * peek, 0),
              child: Transform.scale(scale: 1 - 0.10 * off, child: child),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// A rail thumbnail: staggers in on the first build, and once selected
/// scrolls the rail to keep itself in view (a swipe can select one off
/// screen).
class RailThumb extends StatefulWidget {
  const RailThumb({
    required this.index,
    required this.selected,
    required this.child,
    super.key,
  });

  final int index;
  final bool selected;
  final Widget child;

  @override
  State<RailThumb> createState() => _RailThumbState();
}

class _RailThumbState extends State<RailThumb> {
  @override
  void didUpdateWidget(RailThumb old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _reveal() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box == null) return;
    // The rail's own position only: `Scrollable.ensureVisible` would also
    // scroll the page to centre the rail.
    unawaited(
      Scrollable.maybeOf(context)?.position.ensureVisible(
        box,
        alignment: 0.5,
        duration: context.motion(AppDurations.normal),
        curve: AppCurves.standard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = context.motion(const Duration(milliseconds: 200));
    if (duration == Duration.zero) return widget.child;
    // 40 ms apart: the last of seven lands at 440 ms.
    return widget.child
        .animate(delay: Duration(milliseconds: 40 * widget.index))
        .fadeIn(duration: duration, curve: AppCurves.decelerate)
        .slideX(
          begin: 0.3,
          end: 0,
          duration: duration,
          curve: AppCurves.standard,
        );
  }
}
