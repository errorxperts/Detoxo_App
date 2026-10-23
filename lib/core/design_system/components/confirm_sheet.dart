import 'dart:async';
import 'dart:math' as math;

import 'package:detoxo/core/design_system/components/buttons.dart';
import 'package:detoxo/core/design_system/components/dx_icons.dart';
import 'package:detoxo/core/design_system/components/overlays.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The one confirm for every action that weakens protection (spec
/// ConfirmSheet): a [GlassBottomSheet] that waits `waitSeconds`, then asks
/// for a slide past 88 % of the track.
///
/// - **Wait** — the well's ring fills, the knob counts down, the track reads
///   "Take a breath…". It keeps its full length under Reduce Motion and when
///   the platform removes animations.
/// - **Ready** — the knob turns white with the tone's chevrons and nudges
///   once; the track shows `action`.
/// - **Slide** — at 88 % or more "Release to confirm"; an earlier release
///   springs back; a tap shows "Slide all the way →".
/// - **Confirmed** — a check and "Confirmed", then it closes with true after
///   1 s. TalkBack's double-tap and Enter / Space on the ready knob confirm
///   too.
///
/// `cancel`, the barrier, back and the grabber resolve false. It never
/// commits or toasts: the caller does both after a true, since its commit
/// can fail.
abstract final class ConfirmSheet {
  /// The size of the `icon` callers pass: an `Icon3d` or `DetoxoLogo` that
  /// fills the 88 well.
  static const double iconSize = 58;

  @visibleForTesting
  static const Key knobKey = ValueKey('ConfirmSheet.knob');

  @visibleForTesting
  static const Key trackKey = ValueKey('ConfirmSheet.track');

  static Future<bool> show(
    BuildContext context, {
    required Widget icon,
    required String title,
    required String action,
    required String cancel,
    required ConfirmTone tone,
    String? message,
    Widget? content,
    int waitSeconds = 5,
  }) {
    assert(
      waitSeconds >= 1 && waitSeconds <= 30,
      'waitSeconds must be 1..30, got $waitSeconds',
    );
    // Once the slide lands the answer is true, however the sheet closes.
    var confirmed = false;
    return GlassBottomSheet.show<bool>(
      context: context,
      child: _ConfirmBody(
        icon: icon,
        title: title,
        message: message,
        content: content,
        action: action,
        cancel: cancel,
        tone: tone,
        waitSeconds: waitSeconds.clamp(1, 30),
        onConfirmed: () => confirmed = true,
      ),
    ).then((result) => result ?? confirmed);
  }

  /// The waiting knob's fill. Light: [AppTokens.knob] at 55 % over the
  /// track. Dark: the track mixed 18 % toward the knob, because the knob at
  /// 55 % leaves the countdown at 2:1 there (this keeps ink-2 above 4.5:1).
  /// The native wall's slide mirrors this recipe when it is restyled.
  static Color waitKnob(AppTokens t) => t.brightness == Brightness.dark
      ? Color.lerp(t.trackTo, t.knob, 0.18)!
      : t.knob.withValues(alpha: 0.55);
}

class _ConfirmBody extends StatefulWidget {
  const _ConfirmBody({
    required this.icon,
    required this.title,
    required this.message,
    required this.content,
    required this.action,
    required this.cancel,
    required this.tone,
    required this.waitSeconds,
    required this.onConfirmed,
  });

  final Widget icon;
  final String title;
  final String? message;
  final Widget? content;
  final String action;
  final String cancel;
  final ConfirmTone tone;
  final int waitSeconds;
  final VoidCallback onConfirmed;

  @override
  State<_ConfirmBody> createState() => _ConfirmBodyState();
}

class _ConfirmBodyState extends State<_ConfirmBody>
    with TickerProviderStateMixin {
  static const double _track = 64;
  static const double _knob = 56;
  static const double _knobInset = (_track - _knob) / 2;

  /// The share of the travel a release must reach to confirm.
  static const double _threshold = 0.88;

  static const String _waitLabel = 'Take a breath…';
  static const String _releaseLabel = 'Release to confirm';
  static const String _hintLabel = 'Slide all the way →';
  static const String _confirmedLabel = 'Confirmed';

  /// The friction itself, so [AnimationBehavior.preserve]: a default
  /// controller runs at 5 % length when the platform removes animations,
  /// which would silently drop the wait.
  late final AnimationController _wait = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.waitSeconds),
    animationBehavior: AnimationBehavior.preserve,
  )..addListener(_tick);

  /// The knob's position, as a share of the travel.
  late final AnimationController _slide = AnimationController(vsync: this);

  /// The ready nudge: 0 → 10 → 0 px once.
  late final AnimationController _nudge = AnimationController(vsync: this);

  late int _left = widget.waitSeconds;
  double _travel = 0;
  bool _armed = false;
  bool _hint = false;
  bool _confirmed = false;
  bool _focused = false;
  Timer? _hintTimer;
  Timer? _closeTimer;

  bool get _ready => _left == 0;

  @override
  void initState() {
    super.initState();
    _wait.forward();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _closeTimer?.cancel();
    _wait.dispose();
    _slide.dispose();
    _nudge.dispose();
    super.dispose();
  }

  /// Rebuilds once per second of the wait, not per frame (the ring repaints
  /// on its own).
  void _tick() {
    final left = (widget.waitSeconds * (1 - _wait.value)).ceil();
    if (left == _left) return;
    setState(() => _left = left);
    if (!_ready) return;
    AppHaptics.light();
    _nudge.animateTo(
      1,
      duration: context.motion(const Duration(milliseconds: 600)),
    );
  }

  void _drag(DragUpdateDetails d) {
    if (_travel <= 0) return;
    // Setting the value also stops a spring back still running.
    _slide.value = _slide.value + d.delta.dx / _travel;
    final armed = _slide.value >= _threshold;
    if (armed == _armed && !_hint) return;
    _hintTimer?.cancel();
    setState(() {
      _armed = armed;
      _hint = false;
    });
    if (armed) AppHaptics.selection();
  }

  void _release([DragEndDetails? _]) {
    if (_confirmed) return;
    if (_slide.value >= _threshold) {
      _confirm();
      return;
    }
    setState(() => _armed = false);
    _slide.animateTo(
      0,
      duration: context.motion(AppDurations.press),
      curve: AppCurves.press,
    );
  }

  void _confirm() {
    if (_confirmed || !_ready) return;
    _hintTimer?.cancel();
    setState(() {
      _confirmed = true;
      _armed = false;
      _hint = false;
    });
    widget.onConfirmed();
    AppHaptics.success();
    _slide.animateTo(
      1,
      duration: context.motion(AppDurations.press),
      curve: AppCurves.press,
    );
    _closeTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  void _showHint() {
    _hintTimer?.cancel();
    setState(() => _hint = true);
    _hintTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _hint = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final message = widget.message;
    final content = widget.content;
    return PopScope(
      // The confirmed second: nothing but the close may pop it.
      canPop: !_confirmed,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: widget.title,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              Center(child: _well(t)),
              const SizedBox(height: AppSpacing.gap),
              Semantics(
                header: true,
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSheet.copyWith(color: t.ink),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.message.copyWith(color: t.ink2),
                  ),
                ),
              ],
              if (content != null) ...[
                const SizedBox(height: AppSpacing.md),
                content,
              ],
              const SizedBox(height: AppSpacing.xl),
              _slider(t),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: widget.cancel,
                expand: true,
                // maybePop, so the confirmed second's PopScope holds it.
                onPressed: () => Navigator.of(context).maybePop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The 88 icon well: a radial highlight up and left (CSS `circle at 35%
  /// 30%`, farthest corner = .955 of the side), a 6 px tone halo, and the
  /// wait ring.
  Widget _well(AppTokens t) => SizedBox.square(
    dimension: 88,
    child: CustomPaint(
      foregroundPainter: _WaitRingPainter(
        _wait,
        seconds: widget.waitSeconds,
        color: widget.tone.b,
        stepped: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            radius: 0.955,
            colors: [t.wellFrom, t.wellTo],
          ),
          boxShadow: [
            BoxShadow(
              color: widget.tone.b.withValues(alpha: 0.18),
              spreadRadius: 6,
            ),
          ],
        ),
        child: Center(child: widget.icon),
      ),
    ),
  );

  /// The recessed track, the tone fill, the label and the knob.
  Widget _slider(AppTokens t) {
    final tone = widget.tone;
    final label = _confirmed
        ? _confirmedLabel
        : !_ready
        ? _waitLabel
        : _armed
        ? _releaseLabel
        : _hint
        ? _hintLabel
        : widget.action;

    // The label is painted twice: ink-2 on the bare track, the tone ink on
    // the fill, each clipped to its side of the fill's edge.
    Widget copy(Color color, _Band band) => Positioned.fill(
      child: ClipRect(
        clipper: band,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(66, 0, 18, 0),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppTypography.button.copyWith(color: color),
              ),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      key: ConfirmSheet.trackKey,
      height: _track,
      child: CustomPaint(
        painter: DxSurfacePainter(
          radius: BorderRadius.circular(AppRadius.bar),
          gradient: [t.trackFrom, t.trackTo],
          shadows: t.trackShadow,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            _travel = box.maxWidth - _track;
            return AnimatedBuilder(
              animation: Listenable.merge([_slide, _nudge]),
              builder: (context, knob) {
                final dx = _slide.value * _travel;
                // The fill runs to the knob's far edge plus its 4 px gutter,
                // so a full slide fills the track.
                final fill = dx > 0 || _confirmed ? dx + _track : 0.0;
                return Stack(
                  children: [
                    if (fill > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: fill,
                        child: CustomPaint(
                          painter: DxSurfacePainter(
                            radius: AppRadius.brPill,
                            gradient: [tone.a, tone.b, tone.c],
                            stops: const [0, 0.55, 1],
                            angle: 90,
                          ),
                        ),
                      ),
                    ExcludeSemantics(
                      child: Stack(
                        children: [
                          copy(t.ink2, _Band(fill)),
                          if (fill > 0) copy(tone.ink, _Band(0, fill)),
                        ],
                      ),
                    ),
                    Positioned(
                      left: _knobInset + dx,
                      top: _knobInset,
                      child: Transform.translate(
                        offset: Offset(
                          math.sin(math.pi * _nudge.value) * 10,
                          0,
                        ),
                        child: knob,
                      ),
                    ),
                  ],
                );
              },
              child: _knobControl(t),
            );
          },
        ),
      ),
    );
  }

  Widget _knobControl(AppTokens t) {
    final tone = widget.tone;
    final live = _ready && !_confirmed;
    final seconds = _left == 1 ? 'second' : 'seconds';
    return Semantics(
      container: true,
      button: true,
      enabled: live,
      label: _ready
          ? widget.action
          : '${widget.action}, available in $_left $seconds',
      onTap: live ? _confirm : null,
      child: FocusableActionDetector(
        enabled: live,
        onShowFocusHighlight: (v) {
          if (mounted && v != _focused) setState(() => _focused = v);
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _confirm();
              return null;
            },
          ),
        },
        child: ExcludeSemantics(
          child: GestureDetector(
            key: ConfirmSheet.knobKey,
            dragStartBehavior: DragStartBehavior.down,
            // A finger tap only hints; the semantic tap above confirms.
            onTap: live ? _showHint : null,
            onHorizontalDragUpdate: live ? _drag : null,
            onHorizontalDragEnd: live ? _release : null,
            onHorizontalDragCancel: live ? _release : null,
            child: FocusRing(
              visible: _focused,
              radius: AppRadius.brPill,
              child: SizedBox.square(
                dimension: _knob,
                child: CustomPaint(
                  painter: _ready
                      ? DxSurfacePainter(
                          radius: AppRadius.brPill,
                          color: t.knob,
                          gradient: [
                            Colors.white.withValues(alpha: 0.5),
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.6],
                          shadows: [
                            DxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              offset: const Offset(0, -2),
                              inset: true,
                            ),
                            DxShadow(
                              color: tone.b.withValues(alpha: 0.35),
                              offset: const Offset(0, 8),
                              blur: 18,
                            ),
                          ],
                        )
                      : DxSurfacePainter(
                          radius: AppRadius.brPill,
                          color: ConfirmSheet.waitKnob(t),
                        ),
                  child: Center(
                    child: _ready
                        ? Glyph(
                            _confirmed
                                ? Assets.svg.check
                                : Assets.svg.chevronsRight,
                            color: tone.knob,
                          )
                        : Text(
                            '$_left',
                            style: AppTypography.button.copyWith(color: t.ink2),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 4 px tone ring (r 47) around the well, filling clockwise from 12
/// o'clock over the wait; [stepped] (Reduce Motion) moves it once a second.
/// Gone once the wait ends, leaving the halo.
class _WaitRingPainter extends CustomPainter {
  _WaitRingPainter(
    this.wait, {
    required this.seconds,
    required this.color,
    required this.stepped,
  }) : super(repaint: wait);

  final Animation<double> wait;
  final int seconds;
  final Color color;
  final bool stepped;

  @override
  void paint(Canvas canvas, Size size) {
    final v = wait.value;
    final p = stepped ? (v * seconds).floor() / seconds : v;
    if (p <= 0 || v >= 1) return;
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: 47),
      -math.pi / 2,
      2 * math.pi * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_WaitRingPainter old) =>
      old.wait != wait ||
      old.seconds != seconds ||
      old.color != color ||
      old.stepped != stepped;
}

/// Clips to the vertical band [from]..[to] of the box.
class _Band extends CustomClipper<Rect> {
  const _Band(this.from, [this.to = double.infinity]);

  final double from;
  final double to;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(from, 0, math.min(to, size.width), size.height);

  @override
  bool shouldReclip(_Band old) => old.from != from || old.to != to;
}
