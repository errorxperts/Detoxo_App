import 'dart:async';
import 'dart:math' as math;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/utils/clock_format.dart';
import 'package:detoxo/core/utils/duration_format.dart';
import 'package:detoxo/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:detoxo/features/onboarding/domain/onboarding_script.dart';
import 'package:detoxo/features/onboarding/domain/starter_rule.dart';
import 'package:detoxo/features/onboarding/presentation/onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The survey as a focus carousel: one card in focus, the answered ones dimmed
/// above it (tap one to change it), the rest waiting below. Each answer is
/// written to the store the moment it is given, and a pick moves on by itself
/// after a beat.
///
/// The walker owns [page] — its Back and Continue step through the cards — so
/// this widget only asks to move ([onPage]).
class SurveyStep extends StatefulWidget {
  const SurveyStep({
    required this.progress,
    required this.page,
    required this.onPage,
    super.key,
  });

  final OnboardingProgress progress;

  /// The card in focus, [namePage] … [planPage].
  final int page;
  final ValueChanged<int> onPage;

  // The cards, top to bottom. Card 0 is the title, never in focus.
  static const int namePage = 1;
  static const int timePage = 2;
  static const int goalPage = 3;
  static const int planPage = 4;

  /// Whether Continue is live on [page]. The name is optional; the two picks
  /// gate, because the plan and the starter rule are built from them.
  static bool canContinue(OnboardingProgress p, int page) => switch (page) {
    timePage => p.band != null,
    goalPage => p.mattersMost != null,
    planPage => p.band != null && p.mattersMost != null,
    _ => true,
  };

  /// The first unanswered card after [from], else the plan.
  static int nextPage(OnboardingProgress p, int from) {
    if (from < timePage && p.band == null) return timePage;
    if (from < goalPage && p.mattersMost == null) return goalPage;
    return planPage;
  }

  @override
  State<SurveyStep> createState() => _SurveyStepState();
}

class _SurveyStepState extends State<SurveyStep>
    with SingleTickerProviderStateMixin {
  /// The cards' glide, the design's `cubic-bezier(.32, .72, 0, 1)`.
  static const Curve glide = Cubic(0.32, 0.72, 0, 1);
  static const Duration glideTime = AppDurations.slow;

  /// The beat between a pick and the next card.
  static const _beat = Duration(milliseconds: 480);

  late final _focus = AnimationController(
    vsync: this,
    lowerBound: SurveyStep.namePage.toDouble(),
    upperBound: SurveyStep.planPage.toDouble(),
    value: widget.page.toDouble(),
  );
  Timer? _advance;

  @override
  void didUpdateWidget(SurveyStep old) {
    super.didUpdateWidget(old);
    if (old.page == widget.page) return;
    _advance?.cancel();
    // Only the name card types: leaving it takes the keyboard down.
    FocusManager.instance.primaryFocus?.unfocus();
    final d = context.motion(glideTime);
    if (d == Duration.zero) {
      _focus.value = widget.page.toDouble();
    } else {
      _focus.animateTo(widget.page.toDouble(), duration: d, curve: glide);
    }
  }

  @override
  void dispose() {
    _advance?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _go(int page) {
    _advance?.cancel();
    widget.onPage(page);
  }

  /// After a pick, move on after a beat — unless the person went elsewhere
  /// first. Reads the progress at fire time, so the pick has landed.
  void _later(int from) {
    _advance?.cancel();
    _advance = Timer(_beat, () {
      if (mounted && widget.page == from) {
        widget.onPage(SurveyStep.nextPage(widget.progress, from));
      }
    });
  }

  /// A drag only updates; letting go ([settle]) moves on.
  void _pickBand(ScreenTimeBand band, {required bool settle}) {
    if (band != widget.progress.band) {
      context.read<OnboardingCubit>().answer(fieldBand, band.wire);
    }
    if (settle) {
      _later(SurveyStep.timePage);
    } else {
      _advance?.cancel();
    }
  }

  /// Re-picking the chosen goal still moves on: it is the "yes, that one".
  void _pickGoal(MattersMost m) {
    if (m != widget.progress.mattersMost) {
      context.read<OnboardingCubit>().answer(fieldMattersMost, m.wire);
    }
    _later(SurveyStep.goalPage);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final cubit = context.read<OnboardingCubit>();
    return _Carousel(
      focus: _focus,
      page: widget.page,
      onEdit: _go,
      cards: [
        (child: const _IntroCard(), edit: null),
        (
          child: _NameCard(
            name: p.name,
            onChanged: (v) => cubit.answer(fieldName, v),
            onDone: () => _go(SurveyStep.nextPage(p, SurveyStep.namePage)),
          ),
          edit: 'Change your name',
        ),
        (
          child: _TimeCard(
            band: p.band,
            days: p.daysPerYear,
            onPick: _pickBand,
          ),
          edit: 'Change your daily time',
        ),
        (
          child: _GoalCard(goal: p.mattersMost, onPick: _pickGoal),
          edit: 'Change what matters most',
        ),
        (child: _PlanCard(progress: p), edit: null),
      ],
    );
  }
}

/// Stacks the cards and glides the stack so the card in focus sits where the
/// first question does under the title. Answered cards stay above at a third
/// of their strength (tap one to go back to it); the rest wait, hidden, below.
/// The edges fade out under the header and over the CTA.
class _Carousel extends StatelessWidget {
  const _Carousel({
    required this.focus,
    required this.page,
    required this.onEdit,
    required this.cards,
  });

  final Animation<double> focus;
  final int page;
  final ValueChanged<int> onEdit;

  /// `edit` names the tap that brings a dimmed card back; null: not editable.
  final List<({Widget child, String? edit})> cards;

  static const double fadeTop = 56;
  static const double fadeBottom = 16;

  @override
  Widget build(BuildContext context) {
    final fade = context.motion(AppDurations.chip);
    final glide = context.motion(_SurveyStepState.glideTime);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) {
        final top = math.min(fadeTop / r.height, 0.5);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0, top, math.max(top, 1 - fadeBottom / r.height), 1],
        ).createShader(r);
      },
      child: ClipRect(
        child: CustomMultiChildLayout(
          delegate: _CarouselLayout(focus),
          children: [
            for (final (i, c) in cards.indexed)
              LayoutId(id: i, child: _card(i, c, fade, glide)),
          ],
        ),
      ),
    );
  }

  Widget _card(
    int i,
    ({Widget child, String? edit}) c,
    Duration fade,
    Duration glide,
  ) {
    final future = i > page;
    // The title stays lit while the first question is in focus: it heads it.
    final dim = i < page && !(i == 0 && page == SurveyStep.namePage);
    Widget card = IgnorePointer(
      ignoring: future || dim,
      child: ExcludeSemantics(excluding: future || dim, child: c.child),
    );
    card = AnimatedOpacity(
      opacity: future ? 0 : (dim ? 0.35 : 1),
      duration: fade,
      curve: Curves.ease,
      child: card,
    );
    card = AnimatedScale(
      scale: dim ? 0.97 : 1,
      alignment: Alignment.topCenter,
      duration: glide,
      curve: _SurveyStepState.glide,
      child: card,
    );
    card = TweenAnimationBuilder<double>(
      tween: Tween(end: future ? 28 : 0),
      duration: glide,
      curve: _SurveyStepState.glide,
      builder: (_, y, child) =>
          Transform.translate(offset: Offset(0, y), child: child),
      child: card,
    );
    // The card stays child 0 either way, so its state (the name field)
    // survives dimming.
    return Stack(
      children: [
        card,
        if (dim && c.edit != null)
          Positioned.fill(
            child: AppPressable(
              onTap: () => onEdit(i),
              semanticLabel: c.edit,
              radius: AppRadius.brLg,
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}

/// Measures each card (so large text and the keyboard just work) and places
/// the column for the fractional card in [focus].
class _CarouselLayout extends MultiChildLayoutDelegate {
  _CarouselLayout(this.focus) : super(relayout: focus);

  final Animation<double> focus;

  /// Where the title sits while the first question is in focus.
  static const double _introTop = 76;

  @override
  void performLayout(Size size) {
    final width = math.max(0.0, size.width - 2 * AppSpacing.gutter);
    final tops = <double>[];
    final heights = <double>[];
    var y = 0.0;
    for (var i = 0; hasChild(i); i++) {
      final h = layoutChild(i, BoxConstraints.tightFor(width: width)).height;
      tops.add(y);
      heights.add(h);
      y += h + AppSpacing.section;
    }
    // The card in focus sits where the first question does — lifted until it
    // clears the bottom fade, on a short screen or above the keyboard.
    final anchor = _introTop + tops[SurveyStep.namePage];
    double shift(int i) =>
        math.max(
          0.0,
          math.min(anchor, size.height - _Carousel.fadeBottom - heights[i]),
        ) -
        tops[i];
    final f = focus.value;
    final lo = f.floor();
    final hi = math.min(lo + 1, tops.length - 1);
    final dy = shift(lo) + (shift(hi) - shift(lo)) * (f - lo);
    for (var i = 0; i < tops.length; i++) {
      positionChild(i, Offset(AppSpacing.gutter, tops[i] + dy));
    }
  }

  @override
  bool shouldRelayout(_CarouselLayout old) => old.focus != focus;
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'A few quick things',
            style: AppTypography.titleXl.copyWith(color: t.ink),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: t.ink2),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Stays on this device. Shapes your setup.',
                style: AppTypography.body.copyWith(color: t.ink2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The name, optional. Writes on every edit so an abandoned run keeps
/// whatever was typed; the arrow (or the keyboard's Next) moves on.
class _NameCard extends StatefulWidget {
  const _NameCard({
    required this.name,
    required this.onChanged,
    required this.onDone,
  });

  final String? name;
  final ValueChanged<String?> onChanged;
  final VoidCallback onDone;

  @override
  State<_NameCard> createState() => _NameCardState();
}

class _NameCardState extends State<_NameCard> {
  late final _controller = TextEditingController(text: widget.name);
  final _node = FocusNode();

  @override
  void initState() {
    super.initState();
    _node.addListener(_refocus);
  }

  void _refocus() => setState(() {});

  @override
  void dispose() {
    _node.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = t.brightness == Brightness.dark;
    final focused = _node.hasFocus;
    final name = widget.name;
    final ms = context.motion(AppDurations.normal);
    final label = AppTypography.label.copyWith(
      fontWeight: FontWeight.w600,
      color: t.ink2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What should we call you?',
          style: AppTypography.title.copyWith(color: t.ink),
        ),
        const SizedBox(height: AppSpacing.gap),
        // A 1.5 px rim that lights up in the brand sweep while typing.
        AnimatedContainer(
          duration: ms,
          height: 64,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.row),
            color: focused ? null : t.ink.withValues(alpha: 0.1),
            gradient: focused
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.brand.light, t.brand.main, t.brand.deep],
                  )
                : null,
            boxShadow: [
              if (focused)
                BoxShadow(
                  color: t.brand.main.withValues(alpha: dark ? 0.55 : 0.45),
                  offset: const Offset(0, 12),
                  blurRadius: 25,
                  spreadRadius: -10,
                ),
            ],
          ),
          child: CustomPaint(
            painter: DxSurfacePainter(
              radius: BorderRadius.circular(AppRadius.row - 1.5),
              gradient: [t.buttonFrom, t.buttonTo],
              shadows: [
                DxShadow(
                  color: Colors.white.withValues(alpha: dark ? 0.06 : 1),
                  offset: const Offset(0, 1),
                  inset: true,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _node,
                      // A first name, rendered into two headlines ("You’re
                      // all set, …", "Here’s the deal, …").
                      maxLength: 20,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      autocorrect: false,
                      style: AppTypography.headline.copyWith(
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                      // The floating label names the field for TalkBack even
                      // once it holds text, which a hint would not.
                      decoration: InputDecoration(
                        labelText: 'Your first name',
                        labelStyle: label,
                        floatingLabelStyle: label.copyWith(
                          color: focused ? t.accentText(t.brand) : t.ink2,
                        ),
                        filled: false,
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.only(top: 4),
                      ),
                      onChanged: widget.onChanged,
                      onSubmitted: (_) => widget.onDone(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _GoButton(lit: name != null, onTap: widget.onDone),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          liveRegion: true,
          child: AnimatedDefaultTextStyle(
            duration: ms,
            style: AppTypography.subhead.copyWith(
              color: name == null ? t.ink2 : t.accentText(t.brand),
            ),
            child: Text(
              name == null
                  ? 'Optional. You can skip this.'
                  : 'Nice to meet you, $name',
            ),
          ),
        ),
      ],
    );
  }
}

/// The name field's arrow: the Start gradient once there is a name, a quiet
/// control while it is still a skip.
class _GoButton extends StatelessWidget {
  const _GoButton({required this.lit, required this.onTap});

  final bool lit;
  final VoidCallback onTap;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppPressable(
      onTap: onTap,
      semanticLabel: lit ? 'Continue' : 'Skip your name',
      pressedScale: 0.95,
      radius: BorderRadius.circular(_radius),
      child: AnimatedContainer(
        duration: context.motion(AppDurations.normal),
        width: AppSizes.controlHeight,
        height: AppSizes.controlHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          color: lit ? null : t.control,
          gradient: lit
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.startFrom, t.startTo],
                )
              : null,
          boxShadow: [
            if (lit)
              BoxShadow(
                color: t.brand.main.withValues(alpha: 0.35),
                offset: const Offset(0, 8),
                blurRadius: 15,
              ),
          ],
        ),
        child: Icon(
          Icons.arrow_forward_rounded,
          size: 18,
          color: lit ? t.startInk : t.ink2,
        ),
      ),
    );
  }
}

/// The meter's steps, lightest to heaviest: every band but "Not sure".
final List<ScreenTimeBand> _steps = [
  for (final b in ScreenTimeBand.values)
    if (b != ScreenTimeBand.dontKnow) b,
];

/// Usage warmth across the meter, as on the dashboard: brand → pause → over.
Color _warmth(AppTokens t, int step) {
  final x = step / (_steps.length - 1);
  return x <= 0.5
      ? Color.lerp(t.brand.main, t.pause.main, x / 0.5)!
      : Color.lerp(t.pause.main, t.over.main, (x - 0.5) / 0.5)!;
}

/// How long a day: a stepped bar meter to tap or drag, plus "Not sure".
class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.band,
    required this.days,
    required this.onPick,
  });

  final ScreenTimeBand? band;

  /// [OnboardingProgress.daysPerYear] for [band].
  final int? days;
  final void Function(ScreenTimeBand band, {required bool settle}) onPick;

  static const prompt = 'How long on reels a day?';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = t.brightness == Brightness.dark;
    final b = band;
    final unsure = b == ScreenTimeBand.dontKnow;
    final step = b == null || unsure ? -1 : _steps.indexOf(b);
    final ms = context.motion(AppDurations.normal);
    final insight = switch (b) {
      null => 'Tap or drag the bars',
      ScreenTimeBand.dontKnow => 'No problem. Detoxo will measure it for you.',
      // "7+" has no top: count its floor, not the 8 h the domain assumes.
      ScreenTimeBand.over7h =>
        '${(7 * 365 / 24).round()}+ days a year on short videos',
      _ => '≈ $days days a year on short videos',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: AppTypography.title.copyWith(color: t.ink)),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      _Pop(
                        key: ValueKey(b),
                        from: 0.92,
                        duration: const Duration(milliseconds: 380),
                        child: Text(
                          switch (b) {
                            null => '—',
                            ScreenTimeBand.dontKnow => b.label,
                            _ => '${b.label} h',
                          },
                          style: AppTypography.number.copyWith(
                            fontSize: 48,
                            color: b == null ? t.ink3 : t.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      AnimatedOpacity(
                        opacity: step >= 0 ? 1 : 0,
                        duration: ms,
                        child: Text(
                          'a day',
                          style: AppTypography.body.copyWith(color: t.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _UnsurePill(
                on: unsure,
                onTap: () => onPick(ScreenTimeBand.dontKnow, settle: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Semantics(
          liveRegion: true,
          child: AnimatedDefaultTextStyle(
            duration: context.motion(AppDurations.medium),
            // The warmth, pulled toward the ink so it reads as text.
            style: AppTypography.count.copyWith(
              color: step < 0
                  ? t.ink2
                  : Color.lerp(
                      _warmth(t, step),
                      dark ? Colors.white : AppTokens.accentTextInk,
                      dark ? 0.25 : 0.35,
                    ),
            ),
            child: Text(insight),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Meter(step: step, unsure: unsure, onPick: onPick),
      ],
    );
  }
}

class _UnsurePill extends StatelessWidget {
  const _UnsurePill({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Not a toggle off: un-picking would leave a required answer empty, so
    // the way out of "Not sure" is a bar.
    return AppPressable(
      onTap: onTap,
      selected: on,
      pressedScale: 0.95,
      radius: AppRadius.brPill,
      minTapTarget: AppSizes.minTapTargetSquare,
      child: AnimatedContainer(
        duration: context.motion(AppDurations.normal),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? t.controlOn : t.control,
          borderRadius: AppRadius.brPill,
        ),
        child: Text(
          ScreenTimeBand.dontKnow.label,
          style: AppTypography.count.copyWith(color: on ? t.ink : t.ink2),
        ),
      ),
    );
  }
}

/// Seven bars rising in height; those up to the pick fill with their own
/// warmth. One slider to TalkBack.
class _Meter extends StatefulWidget {
  const _Meter({
    required this.step,
    required this.unsure,
    required this.onPick,
  });

  /// The picked bar, or -1.
  final int step;
  final bool unsure;
  final void Function(ScreenTimeBand band, {required bool settle}) onPick;

  static const _heights = <double>[30, 40, 51, 62, 73, 84, 96];

  @override
  State<_Meter> createState() => _MeterState();
}

class _MeterState extends State<_Meter> {
  /// The bar under the finger mid-drag: the store's answer lags a frame.
  int? _drag;

  static String _spoken(ScreenTimeBand b) => switch (b) {
    ScreenTimeBand.lessThan1h => 'Under 1 hour a day',
    ScreenTimeBand.over7h => 'Over 7 hours a day',
    _ => '${b.label.replaceFirst('–', ' to ')} hours a day',
  };

  void _pick(int i, {required bool settle}) {
    if (i != (_drag ?? widget.step)) AppHaptics.selection();
    widget.onPick(_steps[i], settle: settle);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = t.brightness == Brightness.dark;
    final step = widget.step;
    return Semantics(
      slider: true,
      label: _TimeCard.prompt,
      value: step >= 0
          ? _spoken(_steps[step])
          : (widget.unsure ? 'Not sure' : 'Not set'),
      increasedValue: step < _steps.length - 1
          ? _spoken(_steps[step + 1])
          : null,
      decreasedValue: step > 0 ? _spoken(_steps[step - 1]) : null,
      onIncrease: step < _steps.length - 1
          ? () => _pick(step + 1, settle: false)
          : null,
      onDecrease: step > 0 ? () => _pick(step - 1, settle: false) : null,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, c) {
            int at(Offset o) => (o.dx / c.maxWidth * _steps.length)
                .floor()
                .clamp(0, _steps.length - 1);
            void drag(Offset o) {
              final i = at(o);
              _pick(i, settle: false);
              _drag = i;
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _pick(at(d.localPosition), settle: true),
              onHorizontalDragStart: (d) => drag(d.localPosition),
              onHorizontalDragUpdate: (d) => drag(d.localPosition),
              onHorizontalDragEnd: (_) {
                if (_drag case final i?) _pick(i, settle: true);
                _drag = null;
              },
              onHorizontalDragCancel: () => _drag = null,
              child: Column(
                children: [
                  SizedBox(
                    height: _Meter._heights.last,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < _steps.length; i++) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _bar(
                              t,
                              dark,
                              i,
                              on: i <= step,
                              now: i == step,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      for (var i = 0; i < _steps.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _steps[i].label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            style: AppTypography.caption.copyWith(
                              color: i == step ? t.ink : t.ink2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _bar(
    AppTokens t,
    bool dark,
    int i, {
    required bool on,
    required bool now,
  }) {
    final c = _warmth(t, i);
    final bar = SizedBox(
      height: _Meter._heights[i],
      width: double.infinity,
      child: CustomPaint(
        painter: DxSurfacePainter(
          radius: BorderRadius.circular(AppRadius.md),
          color: on ? null : t.control,
          gradient: on ? [Color.lerp(c, Colors.white, 0.3)!, c] : null,
          shadows: [
            DxShadow(
              color: Colors.white.withValues(
                alpha: now ? 0.45 : (dark ? 0.05 : 0.6),
              ),
              offset: const Offset(0, 1),
              inset: true,
            ),
            if (now)
              DxShadow(
                color: c.withValues(alpha: dark ? 0.45 : 0.35),
                offset: const Offset(0, 10),
                blur: 24,
              ),
          ],
        ),
      ),
    );
    return now ? _Pop(alignment: Alignment.bottomCenter, child: bar) : bar;
  }
}

/// What matters most: five round options and the line of what it sets up.
class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onPick});

  final MattersMost? goal;
  final ValueChanged<MattersMost> onPick;

  static const _icons = <MattersMost, IconData>{
    MattersMost.focus: Icons.center_focus_weak_rounded,
    MattersMost.sleep: Icons.bedtime_outlined,
    MattersMost.present: Icons.people_outline_rounded,
    MattersMost.mental: Icons.favorite_outline_rounded,
    MattersMost.other: Icons.more_horiz_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final g = goal;
    final ms = context.motion(AppDurations.normal);
    final tip = g == null ? t.ink2 : t.accentText(t.brand);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What matters most right now?',
          style: AppTypography.title.copyWith(color: t.ink),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, m) in MattersMost.values.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _GoalOption(
                  label: m.label,
                  icon: _icons[m] ?? Icons.circle_outlined,
                  on: m == g,
                  onTap: () => onPick(m),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.gap),
        Semantics(
          liveRegion: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedOpacity(
                opacity: g == null ? 0 : 1,
                duration: ms,
                child: Icon(Icons.auto_awesome_rounded, size: 14, color: tip),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: ms,
                  textAlign: TextAlign.center,
                  style: AppTypography.subhead.copyWith(color: tip),
                  child: Text(
                    g == null
                        ? 'Pick one. You can change it later.'
                        : _promise(context, g),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalOption extends StatelessWidget {
  const _GoalOption({
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final circle = AnimatedContainer(
      duration: context.motion(AppDurations.normal),
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? t.controlOn : t.control,
        boxShadow: [
          if (on) ...[
            BoxShadow(color: t.brand.main, spreadRadius: 2),
            BoxShadow(
              color: t.brand.main.withValues(alpha: 0.3),
              offset: const Offset(0, 10),
              blurRadius: 18,
            ),
          ],
        ],
      ),
      child: Icon(icon, size: 24, color: on ? t.accentText(t.brand) : t.ink2),
    );
    return AppPressable(
      onTap: onTap,
      selected: on,
      inMutuallyExclusiveGroup: true,
      pressedScale: 0.95,
      radius: AppRadius.brLg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (on) _Pop(child: circle) else circle,
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: AppTypography.caption.copyWith(color: on ? t.ink : t.ink2),
          ),
        ],
      ),
    );
  }
}

/// Where the answers land: the greeting, the rule and the daily time.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.progress});

  final OnboardingProgress progress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = progress.name;
    final band = progress.band;
    final step = band == null ? -1 : _steps.indexOf(band);
    return GlassContainer(
      borderRadius: AppRadius.card,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [t.startFrom, t.startTo],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: t.brand.main.withValues(alpha: 0.3),
                        offset: const Offset(0, 8),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: t.startInk,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name == null ? 'You’re all set' : 'You’re all set, $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline.copyWith(color: t.ink),
                    ),
                    Text(
                      'Here’s how Detoxo starts',
                      style: AppTypography.subhead.copyWith(color: t.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gap),
          _PlanLine(
            dot: t.brand.main,
            text: _promise(context, progress.mattersMost),
          ),
          const SizedBox(height: AppSpacing.xs),
          _PlanLine(
            dot: step >= 0 ? _warmth(t, step) : t.ink3,
            text: switch (band) {
              null => 'Add your daily time any time',
              ScreenTimeBand.dontKnow => 'Detoxo will measure your daily time',
              final ScreenTimeBand b => 'Starting point: ${b.label} h a day',
            },
          ),
        ],
      ),
    );
  }
}

class _PlanLine extends StatelessWidget {
  const _PlanLine({required this.dot, required this.text});

  final Color dot;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      StatusDot(color: dot),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: AppTypography.body.copyWith(color: context.tokens.ink),
        ),
      ),
    ],
  );
}

/// What the starter rule for [m] will do, read FROM the preset it stamps (as
/// the commitment step does), so no hour is restated here.
String _promise(BuildContext context, MattersMost? m) {
  final template = starterPreset(m).template;
  final s = template.schedule;
  if (s == null) {
    return 'Starts you on '
        '${formatHm(Duration(milliseconds: template.thresholdMs))} '
        'of reels a day';
  }
  final from = formatLocalTime(context, s.startMin);
  return s.days.length == 7
      ? 'Sets up a bedtime rule from $from'
      : 'Sets up focus hours, weekdays $from–'
            '${formatLocalTime(context, s.endMin)}';
}

/// A pick's pop: a dip and an overshoot back to size, replayed whenever the
/// widget is mounted (key it to replay on change). Still under Reduce Motion.
class _Pop extends StatelessWidget {
  const _Pop({
    required this.child,
    this.from = 0.9,
    this.duration = AppDurations.medium,
    this.alignment = Alignment.center,
    super.key,
  });

  final Widget child;
  final double from;
  final Duration duration;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return child.animate().scaleXY(
      begin: from,
      end: 1,
      duration: duration,
      curve: AppCurves.press,
      alignment: alignment,
    );
  }
}
