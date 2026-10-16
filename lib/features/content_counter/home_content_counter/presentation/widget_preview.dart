import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/content_counter_core/presentation/counter_brand.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_payload.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/widget_model.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/faces/bento_face.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/faces/bonsai_face.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/faces/count_face.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/faces/next_colour_face.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/faces/plan_face.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/faces/rhythm_face.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/faces/time_limit_face.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_face_painter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_geometry.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The in-app home-widget preview: one [family] at one [size], drawn from the
/// same payload, model and tokens as the native widget (the board
/// `Library.dc.html`), [width] wide (default: the design width).
///
/// Motion (DS-07; the home screen itself just shows the new frame, IM-06):
/// - a tier or theme change cross-fades the colours over 700 ms;
/// - the ring, segments, bars and health bar ease to their new value over
///   800 ms, and the count and time roll there, but never up from zero or on
///   the first build;
/// - the bonsai sways, and drops a leaf from Thirsty to Withering.
///
/// It stays still, with no ticker, under the OS's "remove animations", the
/// payload's `reduceMotion`, or [animate] false (thumbnails). [TickerMode]
/// pauses it off screen.
///
/// A screen reader hears "family, size preview: what it shows" (say "Count,
/// Small preview: 152 reels today, …"), unless [excludeFromSemantics].
class WidgetPreview extends StatefulWidget {
  const WidgetPreview({
    required this.family,
    required this.size,
    required this.payload,
    this.width,
    this.animate = true,
    this.excludeFromSemantics = false,
    super.key,
  });

  final WidgetFamily family;
  final WidgetSize size;
  final WidgetPayload payload;

  /// The drawn width; the height follows the size's design box.
  final double? width;

  /// False draws only the settled frame and never starts a ticker.
  final bool animate;

  /// True for a preview inside a card that already names it (a rail
  /// thumbnail, the Appearance hub card), where its demo numbers would
  /// otherwise read as fact.
  final bool excludeFromSemantics;

  @override
  State<WidgetPreview> createState() => _WidgetPreviewState();
}

class _WidgetPreviewState extends State<WidgetPreview>
    with TickerProviderStateMixin {
  final _texts = FaceTextCache();
  final _clock = ValueNotifier(Duration.zero);

  /// Runs one change: values ease, numbers roll, colours cross-fade.
  AnimationController? _change;

  /// Drives the bonsai's sway and falling leaf through [_clock].
  Ticker? _loop;

  /// The latest payload as drawn; null until the first dependencies.
  _Target? _target;

  /// What showed when the target last changed; null when nothing eases.
  _Values? _from;

  var _platformDark = false;

  /// The app theme's primary in each brightness: the tile takes the one of
  /// the widget's own theme, as native does.
  var _brandLight = 0;
  var _brandDark = 0;
  var _use24h = false;
  var _reduceMotion = false;

  bool get _still =>
      !widget.animate || _reduceMotion || widget.payload.reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _platformDark =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    _use24h = MediaQuery.maybeAlwaysUse24HourFormatOf(context) ?? false;
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _brandLight = counterBrand(context, Brightness.light);
    _brandDark = counterBrand(context, Brightness.dark);
    _retarget();
  }

  @override
  void didUpdateWidget(WidgetPreview old) {
    super.didUpdateWidget(old);
    _retarget();
  }

  @override
  void dispose() {
    _change?.dispose();
    _loop?.dispose();
    _clock.dispose();
    _texts.clear();
    super.dispose();
  }

  /// Takes up the current payload and settings; on a visible change it
  /// starts easing from whatever shows right now.
  void _retarget() {
    final theme = widget.payload.theme;
    final dark = theme == 'dark' || (theme == 'system' && _platformDark);
    final brand = dark ? _brandDark : _brandLight;
    final old = _target;
    if (old == null ||
        old.payload != widget.payload ||
        old.dark != dark ||
        old.brand != brand ||
        old.use24h != _use24h) {
      final shown = old == null || _still ? null : _shown(old);
      _target = _Target(
        widget.payload,
        dark: dark,
        brand: brand,
        use24h: _use24h,
      );
      _from = shown;
      if (shown != null) {
        (_change ??= AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: WidgetTokens.motionEaseMs),
        )).forward(from: 0);
      }
    }
    if (_still) {
      _from = null;
      _change?.dispose();
      _change = null;
    }
    _syncLoop();
  }

  /// What the face shows right now: the target, or mid-change the eased
  /// values in whichever look dominates the cross-fade.
  _Values _shown(_Target target) {
    final from = _from;
    final t = _change?.value ?? 1;
    if (from == null || t >= 1) return target.values;
    final now = _Values.lerp(from, target.values, _ease.transform(t));
    return _fade.transform(t) < 0.5 ? now.inLookOf(from) : now;
  }

  /// The bonsai loop runs only while it has something to move.
  void _syncLoop() {
    final run =
        !_still &&
        widget.family == WidgetFamily.bonsai &&
        _target!.values.tier < 5;
    if (run == (_loop != null)) return;
    if (run) {
      _loop = createTicker((elapsed) => _clock.value = elapsed)..start();
    } else {
      _loop!.dispose();
      _loop = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _target!;
    final size = widget.size;
    final width = widget.width ?? size.box.width;
    // The painter adds no semantics of its own.
    final preview = RepaintBoundary(
      child: SizedBox(
        width: width,
        height: width * size.box.height / size.box.width,
        child: CustomPaint(
          painter: _PreviewPainter(
            face: widget.family.face,
            size: size,
            target: target,
            from: _from,
            change: _change,
            clock: _clock,
            moving: _loop != null,
            texts: _texts,
          ),
        ),
      ),
    );
    if (widget.excludeFromSemantics) return preview;
    return Semantics(
      label:
          '${widget.family.label}, ${size.label} preview: '
          '${target.model.describe(widget.family, size)}',
      excludeSemantics: true,
      child: preview,
    );
  }
}

/// The one family → face lookup (DS-10). Exhaustive: a new family does not
/// compile until it has a face.
extension on WidgetFamily {
  WidgetFace get face => switch (this) {
    WidgetFamily.count => const CountFace(),
    WidgetFamily.nextColour => const NextColourFace(),
    WidgetFamily.timeLimit => const TimeLimitFace(),
    WidgetFamily.rhythm => const RhythmFace(),
    WidgetFamily.bonsai => const BonsaiFace(),
    WidgetFamily.bento => const BentoFace(),
    WidgetFamily.plan => const PlanFace(),
  };
}

/// DS-07's easing for values and the roll; the colours cross-fade within
/// the first 700 of its 800 ms.
const _ease = Cubic(0.2, 0.8, 0.2, 1);
const _fade = Interval(
  0,
  WidgetTokens.motionCrossfadeMs / WidgetTokens.motionEaseMs,
  curve: _ease,
);

/// A settled target: one payload's model as of its arrival.
final class _Target {
  _Target(
    this.payload, {
    required this.dark,
    required this.brand,
    required this.use24h,
  }) : _now = DateTime.now();

  final WidgetPayload payload;
  final bool dark;
  final int brand;
  final bool use24h;
  final DateTime _now;

  late final WidgetModel model = _model(payload);
  late final values = _Values.of(model, dark: dark);

  /// The model with the count and time at a mid-roll [count] and [watch].
  WidgetModel rolled(int count, int watch) => _model(
    WidgetPayload(
      reelCount: count,
      watchSeconds: watch,
      reelTier: payload.reelTier,
      hourlySeconds: payload.hourlySeconds,
      limitMinutes: payload.limitMinutes,
      theme: payload.theme,
      reduceMotion: payload.reduceMotion,
      updatedAt: payload.updatedAt,
      trackingEnabled: payload.trackingEnabled,
    ),
  );

  WidgetModel _model(WidgetPayload p) => WidgetModel(
    p,
    nowMs: _now.millisecondsSinceEpoch,
    zoneOffsetMin: _now.timeZoneOffset.inMinutes,
    use24h: use24h,
    updatedZoneOffsetMin: DateTime.fromMillisecondsSinceEpoch(
      p.updatedAt,
    ).timeZoneOffset.inMinutes,
  );
}

/// The numbers a face eases between, and the look (tier, theme) they show in.
final class _Values {
  const _Values({
    required this.count,
    required this.watch,
    required this.ring,
    required this.segments,
    required this.health,
    required this.bars,
    required this.tier,
    required this.dark,
  });

  _Values.of(WidgetModel m, {required this.dark})
    : count = m.reelCount.toDouble(),
      watch = m.watchSeconds.toDouble(),
      ring = m.ringPct.toDouble(),
      segments = m.segmentsOn.toDouble(),
      health = m.bonsaiHealth.toDouble(),
      bars = m.bars,
      tier = m.tier;

  final double count;
  final double watch;
  final double ring;
  final double segments;
  final double health;
  final List<double> bars;
  final int tier;
  final bool dark;

  /// [a] eased toward [b] by [e], in [b]'s look. The count and time roll,
  /// except up from an empty start (DS-07): those jump.
  static _Values lerp(_Values a, _Values b, double e) {
    double mix(double x, double y) => x + (y - x) * e;
    final roll = a.count > 0;
    return _Values(
      count: roll ? mix(a.count, b.count) : b.count,
      watch: roll ? mix(a.watch, b.watch) : b.watch,
      ring: mix(a.ring, b.ring),
      segments: mix(a.segments, b.segments),
      health: mix(a.health, b.health),
      bars: [for (var i = 0; i < b.bars.length; i++) mix(a.bars[i], b.bars[i])],
      tier: b.tier,
      dark: b.dark,
    );
  }

  _Values inLookOf(_Values other) => _Values(
    count: count,
    watch: watch,
    ring: ring,
    segments: segments,
    health: health,
    bars: bars,
    tier: other.tier,
    dark: other.dark,
  );
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter({
    required this.face,
    required this.size,
    required this.target,
    required this.from,
    required this.change,
    required this.clock,
    required this.moving,
    required this.texts,
  }) : super(repaint: Listenable.merge([change, clock]));

  final WidgetFace face;
  final WidgetSize size;
  final _Target target;
  final _Values? from;
  final Animation<double>? change;
  final ValueListenable<Duration> clock;
  final bool moving;
  final FaceTextCache texts;

  @override
  void paint(Canvas canvas, Size box) {
    final design = size.box;
    canvas.scale(box.width / design.width);
    final c = FaceCanvas(canvas, design, texts);
    final to = target.values;
    final t = change?.value ?? 1;
    final from = t >= 1 ? null : this.from;
    final now = from == null ? to : _Values.lerp(from, to, _ease.transform(t));
    final model = now.count == to.count && now.watch == to.watch
        ? target.model
        : target.rolled(now.count.round(), now.watch.round());
    // The sway follows the target's stage, so both looks of a cross-fade
    // move together.
    final sway = moving ? _sway(clock.value, to.tier) : 0.0;
    final leaf = moving ? _leaf(clock.value, to.tier) : null;
    FaceFrame frame(_Values look) => FaceFrame(
      model: model,
      tier: look.tier,
      dark: look.dark,
      brand: target.brand,
      ring: now.ring,
      segments: now.segments,
      bars: now.bars,
      health: now.health,
      sway: sway,
      leaf: leaf,
    );

    final fade = from == null ? 1.0 : _fade.transform(t);
    if (from != null &&
        fade < 1 &&
        (from.tier != to.tier || from.dark != to.dark)) {
      face.paint(c, size, frame(from));
      // A layer's paint: only its alpha, the fade, is used.
      canvas.saveLayer(
        Offset.zero & design,
        Paint()..color = Color.fromRGBO(0, 0, 0, fade),
      );
      face.paint(c, size, frame(to));
      canvas.restore();
    } else {
      face.paint(c, size, frame(to));
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.face != face ||
      old.size != size ||
      old.target != target ||
      old.from != from ||
      old.change != change ||
      old.moving != moving;
}

/// bz-sway: -1.4° to 1.4° and back over the stage's period, each half eased
/// in and out; none once Leafless.
double _sway(Duration elapsed, int tier) {
  if (tier >= 5) return 0;
  final period = const [4000, 4000, 5000, 6000, 7000][tier];
  final u = elapsed.inMilliseconds % period / period;
  final s = Curves.easeInOut.transform(u < 0.5 ? u * 2 : u * 2 - 1);
  return u < 0.5 ? -1.4 + 2.8 * s : 1.4 - 2.8 * s;
}

/// bz-fall, every 3.6 s from Thirsty to Withering: the leaf eases in along
/// its path while it fades in by 12 % and out by the end.
({double travel, double opacity})? _leaf(Duration elapsed, int tier) {
  if (tier < 2 || tier > 4) return null;
  const period = 3600;
  final u = elapsed.inMilliseconds % period / period;
  return (
    travel: Curves.easeIn.transform(u),
    opacity: u < 0.12
        ? Curves.easeIn.transform(u / 0.12)
        : 1 - Curves.easeIn.transform((u - 0.12) / 0.88),
  );
}
