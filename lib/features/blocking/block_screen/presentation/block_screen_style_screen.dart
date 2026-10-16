import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/block_screen/domain/entities/block_screen_payload.dart';
import 'package:detoxo/features/blocking/block_screen/domain/entities/block_screen_style.dart';
import 'package:detoxo/features/blocking/block_screen/presentation/block_screen_style_cubit.dart';
import 'package:detoxo/features/blocking/block_screen/presentation/widgets/block_screen_preview.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The block screen's editor: one big live preview of the look the app theme
/// gives it (Face Down when light, Spotlight when dark), "Try it on your
/// phone", which raises the real wall over this screen, and one panel of
/// options. Reads the app-wide `BlockScreenStyleCubit` (shared with the
/// Appearance hub); the preview reflects the user's current plan.
class BlockScreenStyleScreen extends StatelessWidget {
  const BlockScreenStyleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassScaffold(
      appBar: GlassAppBar(
        title: Text('Block screen'),
        actions: [
          InfoButton(
            'Each block shows one of 100 built-in quotes, a new one every '
            'time. The look follows your app theme — Face Down when it’s '
            'light, Spotlight when it’s dark. Change the theme under '
            'Appearance.\n\nSwitched off, app and website blocks show a '
            'short toast instead. Daily limits, schedules, an empty '
            'Conscious bank and the Block screen mode for reels still '
            'show it.',
          ),
        ],
      ),
      body: SafeArea(child: _Body()),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    // Only the fields the preview reads: the editor must not rebuild on every
    // counter tick or unrelated settings commit.
    final (today, overlayGranted) = context
        .select<ContentCounterCubit, (int, bool?)>(
          (c) => (c.state.today, c.state.overlayGranted),
        );
    final (plan, allowance) = context
        .select<SettingsCubit, (BlockingPlan, int)>(
          (c) => (c.state.activePlan, c.state.reelAllowance),
        );
    final payload = BlockScreenPayload.preview(
      plan: plan,
      allowance: allowance,
      todayCount: today,
    );
    final cubit = context.read<BlockScreenStyleCubit>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).textTheme;

    final hairline = Divider(
      height: 1,
      thickness: 1,
      color: context.glass.border,
    );

    return BlocBuilder<BlockScreenStyleCubit, BlockScreenStyle>(
      builder: (context, style) {
        final on = style.enabled;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            // The same switch as the Appearance card's, so the screen that
            // shows the wall can also turn it off and on.
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _SwitchRow(
                icon: Icons.front_hand_rounded,
                title: 'Show block screen',
                caption: 'For app & website blocks',
                value: on,
                onChanged: (v) => cubit.setEnabled(enabled: v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PreviewStage(style: style, payload: payload),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${dark ? 'Spotlight' : 'Face Down'} · follows your app theme',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: context.glass.onGlassMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Waits for the switch, and for the overlay grant the line under
            // it asks for — a tap that can only fail is not offered.
            SecondaryButton(
              label: 'Try it on your phone',
              icon: Icons.fullscreen_rounded,
              expand: true,
              onPressed: on && overlayGranted != false
                  ? () => unawaited(_tryIt(context, payload))
                  : null,
            ),
            AppReveal(
              child: on && overlayGranted == false
                  ? NoticeLine(
                      'Needs “Display over other apps” — tap to allow',
                      onTap: () => unawaited(
                        context.read<ContentCounterCubit>().requestOverlay(),
                      ),
                    )
                  : null,
            ),
            const SectionHeader('Options'),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  _SwitchRow(
                    icon: Icons.movie_filter_rounded,
                    title: 'Reel count today',
                    value: style.showCount,
                    enabled: on,
                    onChanged: (v) => cubit.setShowCount(show: v),
                  ),
                  hairline,
                  _SwitchRow(
                    icon: Icons.repeat_rounded,
                    title: 'Times opened today',
                    caption: 'Needs Usage access',
                    value: style.showOpens,
                    enabled: on,
                    onChanged: (v) => cubit.setShowOpens(show: v),
                  ),
                  hairline,
                  _SwitchRow(
                    icon: Icons.hourglass_bottom_rounded,
                    title: 'Wait 5 seconds to go back',
                    value: style.backDelaySec > 0,
                    enabled: on,
                    onChanged: (v) => cubit.setBackDelay(on: v),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Raises the real wall. Only offered while switched on and not known to lack
/// the overlay grant (the tri-state `ContentCount.overlayGranted`), so a
/// `false` back means the grant was never read, or there is no native side.
Future<void> _tryIt(BuildContext context, BlockScreenPayload payload) async {
  final shown = await context.read<BlockScreenStyleCubit>().preview(payload);
  if (!context.mounted || shown) return;
  GlassToast.show(
    context,
    'Couldn’t show the preview — check “Display over other apps” under '
    'Appearance.',
  );
}

/// The glass stage under the big preview. Each look is pinned to the theme it
/// was drawn in, so when the app theme flips the old one cross-fades into the
/// new instead of snapping.
class _PreviewStage extends StatelessWidget {
  const _PreviewStage({required this.style, required this.payload});

  final BlockScreenStyle style;
  final BlockScreenPayload payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.glass.fillTop, context.glass.fillBottom],
        ),
        border: Border.all(color: context.glass.border),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppDurations.normal,
          child: Theme(
            key: ValueKey(theme.brightness),
            data: theme,
            child: BlockScreenPreview(
              style: style,
              payload: payload,
              height: 360,
            ),
          ),
        ),
      ),
    );
  }
}

/// One option in a panel: a flat row (the panel is the surface), not an
/// `AppToggleTile`, which brings its own glass. Not [enabled] (the block
/// screen switched off), it fades and its switch announces as disabled.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.caption,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? caption;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // One TalkBack node per row — title, caption and switch — so a caption is
    // read with its own switch, not lumped into the panel's text.
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: AnimatedOpacity(
                opacity: enabled ? 1 : 0.45,
                duration: AppDurations.fast,
                child: Row(
                  children: [
                    IconBadge(icon: icon),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (caption != null)
                            Text(
                              caption!,
                              style: text.bodySmall?.copyWith(
                                color: context.glass.onGlassMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppToggle(value: value, enabled: enabled, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
