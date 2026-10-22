import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// One home for how Detoxo looks: the app theme (System / Light / Dark), then
/// the reel counter's two surfaces (the floating bubble and the home-screen
/// widget) and the block screen. Each section is an eyebrow over one panel;
/// each surface is a flat tile with a live preview you tap to customise and a
/// status word. The bubble and the block screen carry their own on/off; the
/// widget and the counter editors are gated by the counting master.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Appearance')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: const [
          SectionHeader('Theme'),
          _ThemeControl(),
          SectionHeader('Reel counter'),
          _CounterSection(),
          SectionHeader('Block screen'),
          _BlockScreenSection(),
        ],
      ),
    );
  }
}

// ── Block screen section ────────────────────────────────────────────────────────

/// The wall as one full-width tile: a live landscape preview you tap to edit,
/// its own on/off switch, and a truthful status (the same tri-state overlay
/// read the bubble uses: a wall can only appear with the grant). Switched off
/// it still opens the editor, which carries the same switch; the preview
/// itself shows "Off" and the status says what off means.
class _BlockScreenSection extends StatelessWidget {
  const _BlockScreenSection();

  @override
  Widget build(BuildContext context) {
    final style = context.watch<BlockScreenStyleCubit>().state;
    // Only the fields the tile reads — not every counter tick / settings commit.
    final (today, overlayGranted) = context
        .select<ContentCounterCubit, (int, bool?)>(
          (c) => (c.state.today, c.state.overlayGranted),
        );
    final (plan, allowance) = context
        .select<SettingsCubit, (BlockingPlan, int)>(
          (c) => (c.state.activePlan, c.state.reelAllowance),
        );
    final cubit = context.read<BlockScreenStyleCubit>();
    return PanelGroup(
      children: [
        _SurfaceTile(
          title: 'Block screen',
          previewHeight: 150,
          preview: BlockScreenPreview(
            style: style,
            payload: BlockScreenPayload.preview(
              plan: plan,
              allowance: allowance,
              todayCount: today,
            ),
            height: 150,
            compact: true,
          ),
          editable: true,
          onEdit: () => unawaited(context.push(Routes.blockScreenStyle)),
          trailing: AppToggle(
            value: style.enabled,
            semanticLabel: 'Block screen',
            onChanged: (on) => cubit.setEnabled(enabled: on),
          ),
          // Off, app and website blocks fall back to a short toast (reel
          // walls follow the block mode, not this switch).
          status: !style.enabled
              ? const _Status('Off · toast instead')
              : overlayGranted == false
              ? _Status.needsAccess(
                  () => unawaited(
                    context.read<ContentCounterCubit>().requestOverlay(),
                  ),
                )
              : const _Status.on(),
        ),
      ],
    );
  }
}

// ── Reel counter section ────────────────────────────────────────────────────────

/// Master switch + the two surfaces. Reads the app-wide cubits: the live count
/// (switch states, overlay grant, representative figures) and the appearance
/// (live styles — an edit made in either editor shows here on return without a
/// re-pull). No local mirrors of native state.
class _CounterSection extends StatelessWidget {
  const _CounterSection();

  @override
  Widget build(BuildContext context) {
    final count = context.watch<ContentCounterCubit>().state;
    final appearance = context.watch<CounterAppearanceCubit>().state;
    final cubit = context.read<ContentCounterCubit>();
    // A representative count so the bubble reads at a legible number even
    // before anything is counted today.
    final today = count.today > 0 ? count.today : 137;
    final counterOn = count.enabled;
    final bubbleOn = count.bubbleEnabled;

    return PanelGroup(
      children: [
        AppToggleTile(
          leading: Icon(Icons.movie_filter_rounded, color: context.tokens.ink2),
          title: 'Count short videos',
          value: counterOn,
          onChanged: (on) => unawaited(cubit.setEnabled(enabled: on)),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SurfaceTile(
                  title: 'Bubble',
                  preview: BubblePreview(
                    style: appearance.bubble,
                    count: today,
                    watch: count.timeToday,
                    area: 88,
                  ),
                  editable: counterOn && bubbleOn,
                  onEdit: () => unawaited(context.push(Routes.bubbleStyle)),
                  trailing: AppToggle(
                    value: bubbleOn,
                    enabled: counterOn,
                    semanticLabel: 'Bubble',
                    onChanged: (on) =>
                        unawaited(cubit.setBubbleEnabled(enabled: on)),
                  ),
                  // Truthful state: switched on but the overlay grant is
                  // missing, so no bubble can appear — say so, offer the fix.
                  status: count.bubbleBlocked
                      ? _Status.needsAccess(
                          () => unawaited(cubit.requestOverlay()),
                        )
                      : counterOn && bubbleOn
                      ? const _Status.on()
                      : const _Status.off(),
                ),
              ),
              const VerticalDivider(
                width: 1,
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
              ),
              Expanded(
                child: _SurfaceTile(
                  title: 'Widget',
                  // The demo, so the tile reads as a real widget rather
                  // than the grey empty tile. Its clock is floored to the
                  // minute so a rebuild hands the preview an equal payload;
                  // its numbers are made up, so a screen reader hears only
                  // the tile.
                  preview: WidgetPreview(
                    family: WidgetFamily.count,
                    size: WidgetSize.small,
                    payload: WidgetPayload.demo(
                      limitMinutes: 120,
                      theme: appearance.widget.theme.name,
                      reduceMotion: false,
                      nowMs:
                          DateTime.now().millisecondsSinceEpoch ~/
                          Duration.millisecondsPerMinute *
                          Duration.millisecondsPerMinute,
                    ),
                    width: 88,
                    animate: false,
                    excludeFromSemantics: true,
                  ),
                  editable: counterOn,
                  onEdit: () => unawaited(context.push(Routes.homeWidget)),
                  status: counterOn ? const _Status.on() : const _Status.off(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Theme control ──────────────────────────────────────────────────────────────

/// The app theme: one System / Light / Dark segmented control. System follows
/// the device; Dark is the default. The whole app re-themes instantly. The
/// same words-only 44 control as the home widget's Theme: on a 360 dp phone
/// a third of the taller track has no room for "System" (nor an icon).
class _ThemeControl extends StatelessWidget {
  const _ThemeControl();

  static const _modes = [
    AppThemeMode.system,
    AppThemeMode.light,
    AppThemeMode.dark,
  ];

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsCubit, AppSettings, AppThemeMode>(
      selector: (s) => s.themeMode,
      builder: (context, mode) => GlassSegmented(
        segments: const [
          (label: 'System', icon: null),
          (label: 'Light', icon: null),
          (label: 'Dark', icon: null),
        ],
        selectedIndex: _modes.indexOf(mode),
        onChanged: (i) =>
            unawaited(context.read<SettingsCubit>().setThemeMode(_modes[i])),
        height: AppSizes.controlHeight,
      ),
    );
  }
}

// ── Surface tile (bubble / home widget / block screen) ──────────────────────────

/// A flat tile (its section's panel is the surface) whose hero is a large
/// live preview of the surface's current style. Tapping the preview opens the
/// editor — but only when [editable]; otherwise the preview dims. [trailing]
/// holds the surface's own on/off switch (the bubble, the block screen) or is
/// null (the widget, gated by the counting master). [status] says whether the
/// surface shows, and fixes a missing grant in place.
class _SurfaceTile extends StatelessWidget {
  const _SurfaceTile({
    required this.title,
    required this.preview,
    required this.editable,
    required this.onEdit,
    required this.status,
    this.trailing,
    this.previewHeight = 96,
  });

  final String title;
  final Widget preview;
  final bool editable;
  final VoidCallback onEdit;
  final _Status status;
  final Widget? trailing;

  /// The preview slot's height — 96 fits the counter surfaces side by side;
  /// the full-width block-screen tile gets more room.
  final double previewHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // No bottom inset: the 48 dp status line is the tile's foot.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed-height header so the previews line up across the two tiles
          // even though only the bubble carries a switch.
          SizedBox(
            height: AppSizes.controlHeight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.label.copyWith(
                      color: context.tokens.ink,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // AppPressable, not a bare GestureDetector: the preview is the only
          // way into the editor, so it must announce as a (possibly disabled)
          // button to TalkBack / switch access.
          AppPressable(
            enabled: editable,
            onTap: onEdit,
            semanticLabel: 'Edit $title style',
            child: AnimatedOpacity(
              duration: context.motion(AppDurations.fast),
              opacity: editable ? 1 : 0.4,
              child: SizedBox(
                height: previewHeight,
                child: Center(child: preview),
              ),
            ),
          ),
          status,
        ],
      ),
    );
  }
}

/// A surface's status (spec `.dx-status`, a [Pill]): On, Off (or what off
/// means), or Needs access — a button that opens the "Display over other
/// apps" grant. Always one 48 dp line, so a change cross-fades the word in
/// place instead of moving the tile.
class _Status extends StatelessWidget {
  const _Status(this.label) : tone = AppTone.neutral, onFix = null;

  const _Status.on() : label = 'On', tone = AppTone.success, onFix = null;

  const _Status.off() : this('Off');

  const _Status.needsAccess(VoidCallback this.onFix)
    : label = 'Needs access',
      tone = AppTone.warning;

  final String label;
  final AppTone tone;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final pill = Center(
      child: Pill(label: label, tone: tone),
    );
    return SizedBox(
      height: AppSizes.minTapTarget,
      child: AnimatedSwitcher(
        duration: context.motion(AppDurations.fast),
        child: KeyedSubtree(
          key: ValueKey(label),
          child: onFix == null
              ? pill
              : AppPressable(
                  onTap: onFix!,
                  semanticLabel: 'Needs access. Allow display over other apps',
                  child: ExcludeSemantics(child: pill),
                ),
        ),
      ),
    );
  }
}
