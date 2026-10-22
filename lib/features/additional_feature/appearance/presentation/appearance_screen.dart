import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// One home for how Detoxo *looks*: the app theme (System / Light / Dark), the reel
/// counter's two surfaces — the floating bubble and the home-screen widget —
/// and the block screen, each shown as a large live preview you tap to
/// customise. The bubble and the block screen carry their own on/off; the
/// widget and the counter editors are gated by the counting master.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Appearance')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xxl + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: const [
          // ── App theme ───────────────────────────────────────────────────
          SectionHeader('Theme'),
          _ThemeControl(),

          // ── Reel counter: master switch + the two surfaces as cards ─────
          SectionHeader('Reel counter'),
          _CounterSection(),

          // ── Block screen: the wall raised at the moment of a block ──────
          SizedBox(height: AppSpacing.md),
          SectionHeader('Block screen'),
          _BlockScreenSection(),
        ],
      ),
    );
  }
}

// ── Block screen section ────────────────────────────────────────────────────────

/// The wall as one full-width card: a live landscape preview you tap to edit,
/// its own on/off switch, and the truthful overlay-permission notice (the same
/// tri-state read the bubble card uses — a wall can only appear with the grant).
/// Switched off it still opens the editor, which carries the same switch; the
/// preview itself shows "Off" and a line says what off means.
class _BlockScreenSection extends StatelessWidget {
  const _BlockScreenSection();

  @override
  Widget build(BuildContext context) {
    final style = context.watch<BlockScreenStyleCubit>().state;
    // Only the fields the card reads — not every counter tick / settings commit.
    final (today, overlayGranted) = context
        .select<ContentCounterCubit, (int, bool?)>(
          (c) => (c.state.today, c.state.overlayGranted),
        );
    final (plan, allowance) = context
        .select<SettingsCubit, (BlockingPlan, int)>(
          (c) => (c.state.activePlan, c.state.reelAllowance),
        );
    final cubit = context.read<BlockScreenStyleCubit>();
    return _SurfaceCard(
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
      hint: style.enabled
          ? null
          : 'Off — app & website blocks fall back to a short toast',
      notice: style.enabled && overlayGranted == false
          ? 'Needs “Display over other apps” — tap to allow'
          : null,
      onNotice: () =>
          unawaited(context.read<ContentCounterCubit>().requestOverlay()),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FlatToggleRow(
          icon: Icons.movie_filter_rounded,
          label: 'Count short videos',
          value: counterOn,
          onChanged: (on) => unawaited(cubit.setEnabled(enabled: on)),
        ),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SurfaceCard(
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
                    onChanged: (on) =>
                        unawaited(cubit.setBubbleEnabled(enabled: on)),
                  ),
                  hint: counterOn && bubbleOn
                      ? null
                      : (counterOn ? 'Bubble off' : 'Counting off'),
                  // Truthful state: the switch is on but the overlay grant is
                  // missing, so no bubble can appear — say so, offer the fix.
                  notice: count.bubbleBlocked
                      ? 'Needs “Display over other apps” — tap to allow'
                      : null,
                  onNotice: () => unawaited(cubit.requestOverlay()),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SurfaceCard(
                  title: 'Widget',
                  // The demo, so the card reads as a real widget rather
                  // than the grey empty tile. Its clock is floored to the
                  // minute so a rebuild hands the preview an equal payload;
                  // its numbers are made up, so a screen reader hears only
                  // the card.
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
                  hint: counterOn ? null : 'Counting off',
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
/// the device; Dark is the default. The whole app re-themes instantly.
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
          (label: 'System', icon: Icons.brightness_auto_rounded),
          (label: 'Light', icon: Icons.light_mode_rounded),
          (label: 'Dark', icon: Icons.dark_mode_rounded),
        ],
        selectedIndex: _modes.indexOf(mode),
        onChanged: (i) =>
            unawaited(context.read<SettingsCubit>().setThemeMode(_modes[i])),
      ),
    );
  }
}

/// A flat (no card) toggle row: muted icon, semibold label, switch (the reel
/// counter master).
class _FlatToggleRow extends StatelessWidget {
  const _FlatToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.tokens.ink2),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        AppToggle(value: value, semanticLabel: label, onChanged: onChanged),
      ],
    );
  }
}

// ── Surface card (bubble / home widget) ─────────────────────────────────────────

/// A card whose hero is a large live preview of the surface's current style.
/// Tapping the preview opens the editor — but only when [editable]; otherwise the
/// preview dims. [hint] is a muted line under it (what is off, what to switch
/// on). [trailing] holds the surface's own on/off switch (the bubble, the block
/// screen) or is null (the widget, gated by the counting master). [notice] is a
/// warning line (with a tap action) for a surface that is switched on but cannot
/// actually appear. Both lines slide in and out rather than pop the card.
class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.title,
    required this.preview,
    required this.editable,
    required this.onEdit,
    this.trailing,
    this.hint,
    this.notice,
    this.onNotice,
    this.previewHeight = 96,
  });

  final String title;
  final Widget preview;
  final bool editable;
  final VoidCallback onEdit;
  final Widget? trailing;
  final String? hint;
  final String? notice;
  final VoidCallback? onNotice;

  /// The preview slot's height — 96 fits the counter surfaces side by side;
  /// the full-width block-screen card gets more room.
  final double previewHeight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed-height header so the previews line up across the two cards
          // even though only the bubble carries a switch.
          SizedBox(
            height: AppSizes.controlHeight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
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
              duration: AppDurations.fast,
              opacity: editable ? 1 : 0.4,
              child: SizedBox(
                height: previewHeight,
                child: Center(child: preview),
              ),
            ),
          ),
          AppReveal(
            child: hint == null
                ? null
                : Padding(
                    // Keyed, so "Counting off" ↔ "Bubble off" cross-fades.
                    key: ValueKey(hint),
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Center(
                      child: Text(
                        hint!,
                        style: text.bodySmall?.copyWith(
                          color: context.tokens.ink2,
                        ),
                      ),
                    ),
                  ),
          ),
          AppReveal(
            child: notice == null
                ? null
                : NoticeLine(notice!, onTap: onNotice ?? () {}),
          ),
        ],
      ),
    );
  }
}
