import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Global haptics gate, mirrored from `AppSettings.vibrationEnabled`. Set once
/// from a high-level `BlocListener` so leaf widgets stay context-light.
abstract final class AppHaptics {
  static bool enabled = true;

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Confirming pulse — a completed, successful action (PIN / biometric unlock).
  static void success() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Firm rejection pulse — wrong PIN, failed/invalid action.
  static void error() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}

/// Scale-on-press micro-interaction with optional haptic feedback. Wrap any
/// custom tappable surface.
///
/// Press follows the spec's CSS transition: scale to [pressedScale] over
/// [AppDurations.press] with a short overshoot back ([AppCurves.press]), and no
/// scale at all under Reduce Motion. Keyboard / switch-access focus draws a
/// [FocusRing] that follows [radius].
///
/// Exposes a proper `button` semantics node (role + [semanticLabel] + [enabled]
/// state) and is keyboard/switch-access activatable, so every custom tappable
/// routed through it announces correctly to TalkBack. Set [minTapTarget] on
/// small controls so the hit area meets the 48dp minimum without changing the
/// visual size.
class AppPressable extends StatefulWidget {
  const AppPressable({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.975,
    this.radius = const BorderRadius.all(Radius.circular(AppRadius.row)),
    this.haptic = true,
    this.enabled = true,
    this.semanticLabel,
    this.selected,
    this.inMutuallyExclusiveGroup,
    this.minTapTarget,
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Cards .975 (the default), buttons .95; glass circles grow to 1.06.
  final double pressedScale;

  /// The shape the focus ring follows.
  final BorderRadius radius;
  final bool haptic;

  /// When false, the control is inert (no tap, no press animation) and is
  /// announced as a disabled button.
  final bool enabled;

  /// Accessibility label read by screen readers. Omit when the [child] already
  /// exposes descriptive text.
  final String? semanticLabel;

  /// Exposes a selected state to screen readers (for toggle-like chips/cells).
  final bool? selected;

  /// Marks one option of a single-choice group, so TalkBack reads it as a
  /// radio and each option stays one node.
  final bool? inMutuallyExclusiveGroup;

  /// When set, expands the hit area to at least this size (the visual stays
  /// centered at its natural size) so small controls clear the 48dp floor.
  final Size? minTapTarget;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;
  bool _focused = false;

  void _press(bool down) {
    if (mounted && _pressed != down) setState(() => _pressed = down);
  }

  @override
  void didUpdateWidget(AppPressable old) {
    super.didUpdateWidget(old);
    // Disabled mid-press, the tap recognizer goes away before the pointer
    // lifts: never stay pressed.
    if (!widget.enabled) _pressed = false;
  }

  void _handleTap() {
    if (!widget.enabled) return;
    if (widget.haptic) AppHaptics.light();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget visual = FocusRing(
      visible: _focused,
      radius: widget.radius,
      child: AnimatedScale(
        scale: _pressed && !still ? widget.pressedScale : 1,
        duration: AppDurations.press,
        curve: AppCurves.press,
        child: widget.child,
      ),
    );

    if (widget.minTapTarget != null) {
      visual = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minTapTarget!.width,
          minHeight: widget.minTapTarget!.height,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: visual),
      );
    }

    final enabled = widget.enabled;
    Widget result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _press(true) : null,
      onTapUp: enabled ? (_) => _press(false) : null,
      onTapCancel: enabled ? () => _press(false) : null,
      onTap: enabled ? _handleTap : null,
      child: visual,
    );

    // Keyboard / switch-access focus + Enter/Space activation.
    result = FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (v) {
        if (mounted && v != _focused) setState(() => _focused = v);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handleTap();
            return null;
          },
        ),
      },
      child: result,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      label: widget.semanticLabel,
      child: result,
    );
  }
}

/// The spec focus ring: a 2 px [AppTokens.focus] stroke 3 px outside the
/// control, following [radius]. Painted over the child, so it never shifts
/// layout.
class FocusRing extends StatelessWidget {
  const FocusRing({
    required this.visible,
    required this.radius,
    required this.child,
    super.key,
  });

  final bool visible;
  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: visible
        ? _FocusRingPainter(radius, context.tokens.focus)
        : null,
    child: child,
  );
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter(this.radius, this.color);

  final BorderRadius radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    // 3 px gap + half the 2 px stroke.
    radius.toRRect(Offset.zero & size).inflate(4),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color,
  );

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.radius != radius || old.color != color;
}

/// Scale-on-press feedback driven by raw pointer events. Unlike [AppPressable]
/// this adds NO tap recognizer, so it can wrap a widget that owns its own tap
/// (Material buttons, `InkWell`) without fighting it in the gesture arena.
/// Same press transition, and no scale under Reduce Motion.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, this.pressedScale = 0.95, super.key});

  final Widget child;
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _press(bool down) {
    if (mounted && _pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Listener(
      onPointerDown: (_) => _press(true),
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: AnimatedScale(
        scale: _pressed && !still ? widget.pressedScale : 1,
        duration: AppDurations.press,
        curve: AppCurves.press,
        child: widget.child,
      ),
    );
  }
}

/// The spec squish: when [trigger] changes, [child] stretches wide and short,
/// then tall, then settles (scale 1 → 1.08/.93 → .98/1.03 → 1 at 30/35/35 %,
/// each segment on [AppCurves.squish]). Used by the mode chip, the tab lens
/// (550 ms) and the quick-pick chip. Nothing under Reduce Motion.
class Squish extends StatefulWidget {
  const Squish({
    required this.trigger,
    required this.child,
    this.duration = AppDurations.chip,
    super.key,
  });

  final Object? trigger;
  final Widget child;
  final Duration duration;

  @override
  State<Squish> createState() => _SquishState();
}

class _SquishState extends State<Squish> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  static Animatable<double> _keys(double a, double b) => TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: a,
      ).chain(CurveTween(curve: AppCurves.squish)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: a, end: b).chain(CurveTween(curve: AppCurves.squish)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: b,
        end: 1.0,
      ).chain(CurveTween(curve: AppCurves.squish)),
      weight: 35,
    ),
  ]);

  static final _x = _keys(1.08, 0.98);
  static final _y = _keys(0.93, 1.03);

  @override
  void didUpdateWidget(Squish old) {
    super.didUpdateWidget(old);
    _c.duration = widget.duration;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (old.trigger != widget.trigger && !still) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(_x.evaluate(_c), _y.evaluate(_c), 1),
      child: child,
    ),
    child: widget.child,
  );
}

/// Entrance animation helpers (flutter_animate) for a consistent fade + slide-up.
extension EntranceX on Widget {
  /// Single-item entrance: fade + slide-up. Skips the motion when the user has
  /// "remove animations" enabled.
  Widget entrance({Duration delay = Duration.zero}) => Builder(
    builder: (context) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return this;
      return animate(delay: delay)
          .fadeIn(duration: AppDurations.normal, curve: AppCurves.decelerate)
          .slideY(
            begin: 0.12,
            end: 0,
            duration: AppDurations.normal,
            curve: AppCurves.standard,
          );
    },
  );
}

/// Staggered entrance for a list of children (stat tiles, permission cards, rows).
class EntranceList extends StatelessWidget {
  const EntranceList({
    required this.children,
    this.interval = AppDurations.stagger,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    super.key,
  });

  final List<Widget> children;
  final Duration interval;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return Column(crossAxisAlignment: crossAxisAlignment, children: children);
    }
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: children
          .animate(interval: interval)
          .fadeIn(duration: AppDurations.normal, curve: AppCurves.decelerate)
          .slideY(
            begin: 0.15,
            end: 0,
            duration: AppDurations.normal,
            curve: AppCurves.standard,
          ),
    );
  }
}

/// A status dot: a static circle of [color]. Status is never colour alone, so
/// the word beside it carries the meaning and the dot is hidden from screen
/// readers.
class StatusDot extends StatelessWidget {
  const StatusDot({required this.color, this.size = 8, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ),
  );
}
