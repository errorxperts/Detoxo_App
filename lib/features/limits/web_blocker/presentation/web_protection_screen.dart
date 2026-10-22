import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/limits/app_blocker/domain/repositories/app_block_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_stats_repository.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_block_cubit.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_block_state.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Web Blocker's batch protections, split out of the main screen:
/// each toggle blocks a whole category of sites at once. Reached from the
/// "Protection" row on the Web Blocker screen.
class WebProtectionScreen extends StatelessWidget {
  const WebProtectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Same cubit as the main screen: the toggles live in settings, and both
      // screens re-load on entry, so two instances never drift.
      create: (_) => WebBlockCubit(
        sl<WebBlockRepository>(),
        sl<SettingsRepository>(),
        sl<AppBlockRepository>(),
        sl<WebBlockStatsRepository>(),
        sl<EngineRepository>(),
      )..load(),
      child: const _WebProtectionView(),
    );
  }
}

class _WebProtectionView extends StatelessWidget {
  const _WebProtectionView();

  /// A protection's off branch: a critical [ConfirmSheet], then the commit,
  /// then the toast once the state shows it landed (a failed save reverts and
  /// toasts its own error). Turning one on stays direct. The switch is bound
  /// to the state, so a cancelled sheet snaps it back.
  static Future<void> _turnOff(
    BuildContext context, {
    required String title,
    required String message,
    required String cancel,
    required String toast,
    required Future<void> Function() commit,
    required bool Function() landed,
  }) async {
    final ok = await ConfirmSheet.show(
      context,
      icon: Icon3d(
        Assets.images.icons.iconWebBlocker,
        size: ConfirmSheet.iconSize,
      ),
      title: title,
      message: message,
      action: 'Slide to turn off',
      cancel: cancel,
      tone: ConfirmTone.critical,
    );
    if (!ok) return;
    await commit();
    if (context.mounted && landed()) GlassToast.show(context, toast);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(
        title: Text('Protection'),
        actions: [
          InfoButton(
            'Each switch blocks a whole category of sites in every supported '
            'browser, on top of your blocklist.',
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<WebBlockCubit, WebBlockState>(
          listenWhen: (p, c) => p.error != c.error && c.error != null,
          listener: (context, state) {
            GlassToast.show(context, state.error!, tone: AppTone.danger);
            context.read<WebBlockCubit>().clearError();
          },
          builder: (context, state) {
            if (state.isLoading) {
              return const LoadingState(message: 'Loading…');
            }
            final cubit = context.read<WebBlockCubit>();
            final ink2 = context.tokens.ink2;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  'One switch, a whole category of sites.',
                  style: AppTypography.subhead.copyWith(color: ink2),
                ),
                const SizedBox(height: AppSpacing.md),
                PanelGroup(
                  children: [
                    AppToggleTile(
                      title: 'Block websites of blocked apps',
                      subtitle: 'Apps you block stay blocked in the browser',
                      leading: Icon(Icons.apps_outlined, color: ink2),
                      value: state.blockForApps,
                      onChanged: (v) => v
                          ? cubit.setBlockForApps(value: true)
                          : _turnOff(
                              context,
                              title: 'Unblock sites of blocked apps?',
                              message:
                                  'Their websites open again in your browser.',
                              cancel: 'Keep them blocked',
                              toast: 'Sites of blocked apps unblocked',
                              commit: () => cubit.setBlockForApps(value: false),
                              landed: () => !cubit.state.blockForApps,
                            ),
                    ),
                    AppToggleTile(
                      title: 'Block adult content (18+)',
                      subtitle:
                          'Blocks 200+ known adult sites and every .xxx, '
                          '.porn, .sex or .adult address',
                      leading: Icon(Icons.shield_outlined, color: ink2),
                      value: state.blockAdult,
                      onChanged: (v) => v
                          ? cubit.setBlockAdult(value: true)
                          : _turnOff(
                              context,
                              title: 'Turn off the 18+ filter?',
                              message:
                                  'Adult sites open again in every browser.',
                              cancel: 'Keep it on',
                              toast: '18+ filter off',
                              commit: () => cubit.setBlockAdult(value: false),
                              landed: () => !cubit.state.blockAdult,
                            ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
