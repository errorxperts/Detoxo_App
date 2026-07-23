import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/reel_session_state.dart';
import 'package:flutter/material.dart';

/// The five blocking modes. Order = the two sticky **base** modes and Pause
/// first (they're the feature-tour targets, kept as the leftmost pills), then
/// the count-based override modes.
enum DashboardMode { blockAll, conscious, pause, oneReel, unblock }

/// The blocking-mode picker: a horizontally-scrolling row of pill cells (an icon
/// over a label; the active cell fills with a primary→secondary gradient pill).
/// All five modes fit by scrolling sideways within one glass strip.
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
    final isReel =
        mode == DashboardMode.oneReel || mode == DashboardMode.unblock;
    if (isReel && selected == mode && reelSession.active) {
      return reelSession.remaining;
    }
    return null;
  }

  Widget _decorate(DashboardMode mode, Widget cell) =>
      showcaseBuilder?.call(mode, cell) ?? cell;
}

/// Static per-mode presentation (icon, label).
class _ModeSpec {
  const _ModeSpec({
    required this.mode,
    required this.icon,
    required this.label,
  });

  final DashboardMode mode;
  final AppIcon icon;
  final String label;
}

const _modeSpecs = <_ModeSpec>[
  _ModeSpec(
    mode: DashboardMode.blockAll,
    icon: AppIcon.ban,
    label: 'Block All',
  ),
  _ModeSpec(
    mode: DashboardMode.conscious,
    icon: AppIcon.shieldCheck,
    label: 'Conscious',
  ),
  _ModeSpec(mode: DashboardMode.pause, icon: AppIcon.pause, label: 'Pause'),
  _ModeSpec(
    mode: DashboardMode.oneReel,
    icon: AppIcon.oneReel,
    label: 'One Reel',
  ),
  _ModeSpec(
    mode: DashboardMode.unblock,
    icon: AppIcon.unblock,
    label: 'Unblock',
  ),
];

class _ModeCell extends StatefulWidget {
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

  @override
  State<_ModeCell> createState() => _ModeCellState();
}

class _ModeCellState extends State<_ModeCell> {
  final AnimatedIconController _controller = AnimatedIconController();

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didUpdateWidget(_ModeCell old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected && !_reduceMotion) {
      _controller.animate();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    AppHaptics.selection();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = widget.selected;
    final fg = selected
        ? scheme.onPrimary
        : scheme.onSurfaceVariant.withValues(
            alpha: widget.enabled ? 0.7 : 0.35,
          );

    return AppPressable(
      onTap: _onTap,
      enabled: widget.enabled,
      selected: selected,
      haptic: false, // _onTap already fires a selection click
      child: SizedBox(
        width: _ModeCell._width,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
              _IconWithBadge(
                icon: widget.spec.icon,
                color: fg,
                controller: _controller,
                badge: widget.badge,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                widget.spec.label,
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

/// The pill's animated glyph with an optional accent "N" badge (remaining reels).
class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({
    required this.icon,
    required this.color,
    required this.controller,
    this.badge,
  });

  final AppIcon icon;
  final Color color;
  final AnimatedIconController controller;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final glyph = AppAnimatedIcon(
      icon: icon,
      size: 20,
      color: color,
      controller: controller,
    );
    if (badge == null) return glyph;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        glyph,
        Positioned(
          top: -6,
          right: -10,
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
