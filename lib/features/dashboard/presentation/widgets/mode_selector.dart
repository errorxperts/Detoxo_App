import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/reel_session_state.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// The five blocking modes. Order = the two sticky **base** modes and Pause
/// first (they're the feature-tour targets, kept as the leftmost pills), then
/// the count-based override modes.
enum DashboardMode { blockAll, conscious, pause, oneReel, unblock }

/// The blocking-mode picker: a horizontally-scrolling row of pill cells (a
/// glossy illustration "coin" over a label; the active cell fills with a
/// primary→secondary gradient pill). All five modes fit by scrolling sideways
/// within one glass strip.
class ModeSelector extends StatelessWidget {
  const ModeSelector({
    required this.selected,
    required this.reelSession,
    required this.onSelect,
    this.showcaseBuilder,
    this.enabled = true,
    super.key,
  });

  /// The active mode (drives the highlighted pill).
  final DashboardMode selected;

  /// Live One Reel / Unblock session, for the "N left" badge on the active pill.
  final ReelSessionState reelSession;

  /// Fired when a pill is tapped.
  final void Function(DashboardMode mode) onSelect;

  /// Optional per-mode decorator (feature-showcase target). Identity when null.
  final Widget Function(DashboardMode mode, Widget child)? showcaseBuilder;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.glass.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < _modeSpecs.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xxs),
                _decorate(
                  _modeSpecs[i].mode,
                  _ModeCell(
                    spec: _modeSpecs[i],
                    selected: selected == _modeSpecs[i].mode,
                    enabled: enabled,
                    badge: _badgeFor(_modeSpecs[i].mode),
                    onTap: () => onSelect(_modeSpecs[i].mode),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The live "N" remaining badge for the active One Reel / Unblock pill.
  int? _badgeFor(DashboardMode mode) {
    final isReel = mode == DashboardMode.oneReel || mode == DashboardMode.unblock;
    if (isReel && selected == mode && reelSession.active) {
      return reelSession.remaining;
    }
    return null;
  }

  Widget _decorate(DashboardMode mode, Widget cell) => showcaseBuilder?.call(mode, cell) ?? cell;
}

/// Static per-mode presentation (illustration asset, label).
class _ModeSpec {
  const _ModeSpec({required this.mode, required this.image, required this.label});

  final DashboardMode mode;

  /// Illustration asset path — the same artwork the feature tour shows.
  final String image;
  final String label;
}

final _modeSpecs = <_ModeSpec>[
  _ModeSpec(
    mode: DashboardMode.blockAll,
    image: Assets.images.illustration.block.path,
    label: 'Block All',
  ),
  _ModeSpec(
    mode: DashboardMode.conscious,
    image: Assets.images.illustration.conscious.path,
    label: 'Conscious',
  ),
  _ModeSpec(
    mode: DashboardMode.pause,
    image: Assets.images.illustration.countdown.path,
    label: 'Pause',
  ),
  _ModeSpec(
    mode: DashboardMode.oneReel,
    image: Assets.images.illustration.oneReel.path,
    label: 'One Reel',
  ),
  _ModeSpec(
    mode: DashboardMode.unblock,
    image: Assets.images.illustration.timer.path,
    label: 'Unblock',
  ),
];

class _ModeCell extends StatelessWidget {
  const _ModeCell({
    required this.spec,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.badge,
  });

  final _ModeSpec spec;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  /// Remaining-reels count for the active reel pill (null otherwise).
  final int? badge;

  /// Fixed pill width so cells read as pills and scroll sideways.
  static const double _width = 92;

  void _onTap() {
    AppHaptics.selection();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = selected
        ? scheme.onPrimary
        : scheme.onSurfaceVariant.withValues(alpha: enabled ? 0.7 : 0.35);

    return AppPressable(
      onTap: _onTap,
      enabled: enabled,
      selected: selected,
      haptic: false, // _onTap already fires a selection click
      child: SizedBox(
        width: _width,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs, horizontal: AppSpacing.xxs),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.secondary],
                  )
                : null,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.secondary.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeArt(
                image: spec.image,
                selected: selected,
                enabled: enabled,
                badge: badge,
              ),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(
                  color: fg,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pill's illustration "coin": the mode's artwork clipped to a ring-lit
/// circle (the source art is a glow on an opaque backdrop, so a circular clip
/// is what turns it into an icon), with an optional accent "N" badge.
///
/// The inactive state dims and shrinks the coin instead of tinting it — the
/// artwork is full-colour, so a colour filter is not available as the
/// selected/unselected signal.
class _ModeArt extends StatelessWidget {
  const _ModeArt({
    required this.image,
    required this.selected,
    required this.enabled,
    this.badge,
  });

  final String image;
  final bool selected;
  final bool enabled;
  final int? badge;

  static const double _size = 50;

  /// Decode cap for the 1024² source art — without it every pill would pin
  /// ~4 MB of bitmap for a 50dp icon.
  static const int _cacheWidth = 150;

  @override
  Widget build(BuildContext context) {
    final coin = AnimatedScale(
      scale: selected ? 1 : .8,
      duration: AppDurations.fast,
      curve: AppCurves.standard,
      child: Image.asset(
        image,
        height: _size,
        cacheWidth: _cacheWidth,
        opacity: AlwaysStoppedAnimation(enabled ? (selected ? 1.0 : 0.72) : 0.3),
      ),
    );

    if (badge == null) return coin;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        coin,
        Positioned(
          top: -4,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$badge',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.black,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
