import 'package:detoxo/core/design_system/tokens/app_motion.dart';
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
/// tappable surface (GlassCard, CTAs, tiles).
///
/// Exposes a proper `button` semantics node (role + [semanticLabel] + [enabled]
/// state) and is keyboard/switch-access activatable — so every custom tappable
/// routed through it announces correctly to TalkBack/VoiceOver, not just the
/// Material buttons. Set [minTapTarget] on small controls so the hit area meets
/// the 48dp minimum without changing the visual size.
class AppPressable extends StatefulWidget {
  const AppPressable({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
    this.haptic = true,
    this.enabled = true,
    this.semanticLabel,
    this.selected,
    this.minTapTarget,
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;
  final bool haptic;

  /// When false, the control is inert (no tap, no press animation) and is
  /// announced as a disabled button.
  final bool enabled;

  /// Accessibility label read by screen readers. Omit when the [child] already
  /// exposes descriptive text.
  final String? semanticLabel;

  /// Exposes a selected state to screen readers (for toggle-like chips/cells).
  final bool? selected;

  /// When set, expands the hit area to at least this size (the visual stays
  /// centered at its natural size) so small controls clear the 48dp floor.
  final Size? minTapTarget;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppDurations.instant,
  );

  // Keyboard / switch-access focus, painted as an accent ring (see build).
  bool _focused = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) => _c.forward();
  void _up([_]) => _c.reverse();

  void _handleTap() {
    if (!widget.enabled) return;
    if (widget.haptic) AppHaptics.light();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    Widget visual = AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.scale(
        scale: 1 - (_c.value * (1 - widget.pressedScale)),
        child: child,
      ),
      child: widget.child,
    );

    // Focus-visible ring for keyboard / switch access — an accent hairline drawn
    // as a foreground border (no layout shift; transparent until focused).
    visual = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? Theme.of(context).colorScheme.secondary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: visual,
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
      onTapDown: enabled ? _down : null,
      onTapUp: enabled ? _up : null,
      onTapCancel: enabled ? _up : null,
      onTap: enabled ? _handleTap : null,
      child: visual,
    );

    // Keyboard / switch-access focus + Enter/Space activation. Focus highlight
    // drives the accent ring painted above; TalkBack also reads the node.
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
      label: widget.semanticLabel,
      child: result,
    );
  }
}

/// Scale-on-press feedback driven by raw pointer events. Unlike [AppPressable]
/// this adds NO tap recognizer, so it can wrap a widget that owns its own tap
/// (Material buttons, `InkWell`) without fighting it in the gesture arena — the
/// child's `onPressed`/ripple still fires. Used to give every adaptive button a
/// subtle squish on Android.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, this.pressedScale = 0.97, super.key});

  final Widget child;
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppDurations.instant,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _c.forward(),
      onPointerUp: (_) => _c.reverse(),
      onPointerCancel: (_) => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(
          scale: 1 - (_c.value * (1 - widget.pressedScale)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
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

/// Pulsing / glowing status dot — "blocking active" on dashboard, "resumes in"
/// on pause. Colour encodes state (accent / danger / warning).
class StatusDot extends StatelessWidget {
  const StatusDot({
    required this.color,
    this.size = 12,
    this.pulsing = true,
    super.key,
  });

  final Color color;
  final double size;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
        ],
      ),
    );
    if (!pulsing || reduceMotion) return dot;
    return dot
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1,
          end: 1.25,
          duration: AppDurations.pulse,
          curve: AppCurves.gentle,
        );
  }
}
