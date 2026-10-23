import 'dart:typed_data';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/widgets/app_picker_sheet.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/limits/app_blocker/domain/app_block_sync.dart';
import 'package:detoxo/features/limits/app_blocker/domain/entities/app_block_entry.dart';
import 'package:detoxo/features/limits/app_blocker/domain/repositories/app_block_repository.dart';
import 'package:detoxo/features/limits/app_blocker/presentation/app_block_cubit.dart';
import 'package:detoxo/features/limits/unblock/domain/entities/temporary_unblock.dart';
import 'package:detoxo/features/limits/unblock/presentation/unblock_cubit.dart';
import 'package:detoxo/features/limits/unblock/presentation/widgets/allowed_until.dart';
import 'package:detoxo/features/limits/unblock/presentation/widgets/unblock_duration_sheet.dart';
import 'package:detoxo/features/limits/web_blocker/domain/web_block_sync.dart';
import 'package:detoxo/features/protected_apps/protected_apps.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

/// One place to manage blocking: the curated catalog of built-in feeds/surfaces
/// (install-aware, from [TargetsCubit]/[SettingsCubit]) and custom whole-app
/// locks the user adds ([AppBlockCubit]). The two systems enforce differently —
/// this screen just unifies their management.
class AppBlockScreen extends StatelessWidget {
  const AppBlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TargetsCubit + SettingsCubit are global (main.dart); only the custom-block
    // cubit is scoped to this route.
    return BlocProvider(
      create: (_) => AppBlockCubit(
        sl<AppBlockRepository>(),
        // Keep native in step with every mutation: the enforced whole-app
        // blocklist first, then the app-derived web rules.
        onChanged: () async {
          await syncAppBlocklist(sl(), sl());
          await syncWebBlocklist(sl(), sl(), sl(), sl());
        },
      )..load(),
      child: const _AppBlockView(),
    );
  }
}

class _AppBlockView extends StatefulWidget {
  const _AppBlockView();

  @override
  State<_AppBlockView> createState() => _AppBlockViewState();
}

class _AppBlockViewState extends State<_AppBlockView> {
  String _query = '';

  /// Device icons by package, from the engine's cached scan — also pre-warms
  /// the cache so the add-picker opens instantly. Null until loaded; rows fall
  /// back to letter tiles.
  Map<String, Uint8List>? _appIcons;

  @override
  void initState() {
    super.initState();
    sl<EngineRepository>().installedApps().then((apps) {
      if (!mounted || apps == null) return;
      setState(() {
        _appIcons = {for (final a in apps) a.packageName: ?a.icon};
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(
        title: Text('App Blocker'),
        actions: [
          InfoButton(
            'Switch off a feed like Reels or Shorts to keep the app but lose '
            'the feed, or add an app to lock all of it.',
          ),
        ],
      ),
      floatingActionButton: GlassFab(
        onPressed: () => _showAdd(context),
        icon: const Icon(Icons.add_rounded),
        label: 'Add app',
      ),
      body: SafeArea(
        child: BlocBuilder<TargetsCubit, TargetsState>(
          builder: (context, targets) {
            final settings = context.watch<SettingsCubit>().state;
            final custom = context.watch<AppBlockCubit>().state;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                // Clear the FAB.
                96 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                // No section at all until the first custom app: the FAB is the
                // entry point, and an empty hint would just push the catalog down.
                if (custom.isNotEmpty)
                  ..._customSection(
                    context,
                    custom,
                    // EVO-037 — Notification silence, offered where the intent
                    // forms. Locking an app stops the user walking into it; it
                    // does not stop the app calling them back out, and the only
                    // other switch is in Settings → Privacy. Shown once a lock
                    // is live and only while the feature is off, so it goes the
                    // moment it has done its job.
                    hint:
                        custom.any((e) => e.enabled) &&
                        !settings.suppressNotifications,
                  ),
                ..._curatedSection(
                  context,
                  targets,
                  settings.enabledPlatformIds,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Where a row's title starts: the row inset, the 34 avatar and its gap. A
  /// granted row's status line indents to it.
  static const double _textInset = AppSpacing.md + 34 + AppSpacing.sm;

  // ── Custom whole-app locks ────────────────────────────────────────────────
  List<Widget> _customSection(
    BuildContext context,
    List<AppBlockEntry> custom, {
    required bool hint,
  }) {
    return [
      const SectionHeader('Custom apps'),
      // Only one swipe pane open at a time across the list.
      SlidableAutoCloseBehavior(
        child: PanelGroup(
          children: [
            for (var i = 0; i < custom.length; i++) _customRow(i, custom[i]),
            if (hint)
              GlassListTile(
                leading: Icon(
                  Icons.notifications_off_outlined,
                  color: context.tokens.ink2,
                ),
                title: 'Locked apps can still notify you',
                subtitle: 'Turn on Notification silence in Settings → Privacy',
                onTap: () => context.push(Routes.settings),
              ),
          ],
        ),
      ),
    ];
  }

  /// A custom lock, the web row's shell: Unblock/Block and Remove sit in the
  /// swipe pane, which a tap also opens; only the timer stays on the row.
  Widget _customRow(int i, AppBlockEntry entry) {
    return Builder(
      builder: (context) {
        final t = context.tokens;
        // M8: a live grant on this package. Selected off the cubit's DERIVED
        // `active` list, so the row actually rebuilds when the grant lapses
        // instead of holding a dead countdown.
        //
        // The clock is read INSIDE the selector, not hoisted above the loop:
        // provider re-runs this closure on every cubit emit, and a captured
        // build-time `nowMs` sits before the `startMs` of any grant made
        // afterwards — so `isActiveAt` stayed false forever and the line never
        // appeared. The web-blocker row has the same shape.
        final grant = context.select<UnblockCubit, TemporaryUnblock?>(
          (c) => c.state.activeFor(
            UnblockTargetType.app,
            entry.packageName,
            DateTime.now().millisecondsSinceEpoch,
          ),
        );
        return Slidable(
          key: ValueKey(entry.packageName),
          groupTag: 'app-blocklist',
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            // Two actions, the web row's two-action ratio.
            extentRatio: 0.52,
            children: [
              if (entry.enabled)
                RowAction(
                  icon: Icons.lock_open,
                  label: 'Unblock',
                  tone: t.statusText(t.statusSetup),
                  semanticLabel: 'Unblock ${entry.appName}',
                  onPressed: (_) => _lockOff(i, entry),
                )
              else
                RowAction(
                  icon: Icons.lock_outline,
                  label: 'Block',
                  tone: t.brand.main,
                  semanticLabel: 'Block ${entry.appName}',
                  onPressed: (_) =>
                      context.read<AppBlockCubit>().toggle(i, enabled: true),
                ),
              RowAction(
                icon: Icons.delete_outline,
                label: 'Remove',
                tone: t.over.main,
                semanticLabel: 'Remove ${entry.appName}',
                onPressed: (_) => _remove(i, entry),
              ),
            ],
          ),
          child: Builder(
            // A screen reader cannot swipe: the tap opens the same pane, and
            // the hint says so. A container, not the web row's MergeSemantics:
            // merging would swallow the timer and "Block now" buttons.
            builder: (rowContext) => Semantics(
              container: true,
              hint: 'Opens block and remove actions',
              child: AppPressable(
                onTap: () {
                  final slidable = Slidable.of(rowContext);
                  if (slidable == null) return;
                  if (slidable.ratio == 0) {
                    slidable.openEndActionPane();
                  } else {
                    slidable.close();
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassListTile(
                      // With the switch gone, an off lock reads at a
                      // glance via a dimmed icon.
                      leading: AnimatedOpacity(
                        opacity: entry.enabled ? 1 : 0.45,
                        duration: context.motion(AppDurations.fast),
                        child: AppIconAvatar(
                          iconUrl: '',
                          iconBytes: _appIcons?[entry.packageName],
                          appName: entry.appName,
                        ),
                      ),
                      title: entry.appName,
                      subtitle: entry.enabled ? null : 'Not blocked',
                      // "Let me in for 15 minutes" — the headline of M8,
                      // and the reason a whole-app lock no longer has to be
                      // all or nothing. Only offered while the lock is
                      // actually on; a live grant offers "Block now".
                      trailing: entry.enabled && grant == null
                          ? IconButton(
                              icon: const Icon(Icons.timer_outlined),
                              // The same word the website rows use — one
                              // vocabulary for one mechanism.
                              tooltip: 'Allow ${entry.appName} for a while',
                              onPressed: () => _showAllowSheet(context, entry),
                            )
                          : null,
                    ),
                    if (grant != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: _textInset,
                          bottom: AppSpacing.xxs,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: AllowedUntil(grant)),
                            SecondaryButton(
                              label: 'Block now',
                              onPressed: () =>
                                  context.read<UnblockCubit>().endEarly(
                                    UnblockTargetType.app,
                                    entry.packageName,
                                  ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // C10: switching one thing off (or removing it) stays one tap. The toast
  // waits until the cubit's state shows the change landed (a failed save
  // reverts), speaks from this screen (a removed row unmounts with its entry),
  // and its Undo re-resolves the target at tap time: a target that is gone, or
  // a screen that closed (the toast outlives the route), means do nothing.

  Future<void> _lockOff(int i, AppBlockEntry entry) async {
    final cubit = context.read<AppBlockCubit>();
    int find() => cubit.isClosed
        ? -1
        : cubit.state.indexWhere((e) => e.packageName == entry.packageName);
    await cubit.toggle(i, enabled: false);
    final at = find();
    if (!mounted || at < 0 || cubit.state[at].enabled) return;
    GlassToast.show(
      context,
      '${entry.appName} unblocked',
      action: (
        label: 'Undo',
        onPressed: () {
          final at = find();
          if (at >= 0) cubit.toggle(at, enabled: true);
        },
      ),
    );
  }

  Future<void> _remove(int i, AppBlockEntry entry) async {
    final cubit = context.read<AppBlockCubit>();
    await cubit.removeAt(i);
    if (!mounted ||
        cubit.state.any((e) => e.packageName == entry.packageName)) {
      return;
    }
    GlassToast.show(
      context,
      '${entry.appName} removed',
      action: (
        label: 'Undo',
        onPressed: () {
          if (!cubit.isClosed) cubit.restore(entry, i);
        },
      ),
    );
  }

  Future<void> _feedOff(BlockTarget target) async {
    final settings = context.read<SettingsCubit>();
    final targets = context.read<TargetsCubit>();
    final id = target.platformId;
    // A failed save throws out of the commit, so no toast is reached.
    await settings.togglePlatform(id, enabled: false);
    if (!mounted || settings.state.enabledPlatformIds.contains(id)) return;
    GlassToast.show(
      context,
      '${target.displayName} unblocked',
      action: (
        label: 'Undo',
        onPressed: () {
          // An app uninstalled meanwhile has no feed left to block.
          final live = targets.state.targets.any(
            (t) => t.platformId == id && t.isInstalled,
          );
          if (live) settings.togglePlatform(id, enabled: true);
        },
      ),
    );
  }

  /// The same chips the website rows and the block screen use.
  Future<void> _showAllowSheet(
    BuildContext context,
    AppBlockEntry entry,
  ) async {
    final unblock = context.read<UnblockCubit>();
    final window = await showUnblockDurationSheet(
      context,
      title: 'Unblock ${entry.appName}?',
      icon: Assets.images.icons.iconAppBlocker,
      remaining: unblock.state.grantsLeft,
    );
    if (window == null) return;
    final ok = await unblock.grant(
      UnblockTargetType.app,
      entry.packageName,
      window,
      source: UnblockSource.blocklistRow,
    );
    // Only on success. A failed write reverts the grant and emits `error`,
    // which `PendingUnblockListener` toasts app-wide — announcing "unblocked
    // for 15 min" over an app that is still blocked is the one thing this must
    // not do.
    if (ok && context.mounted) {
      GlassToast.show(
        context,
        '${entry.appName} unblocked for ${window.inMinutes} min',
        tone: AppTone.success,
      );
    }
  }

  // ── Curated, install-aware feeds & surfaces ───────────────────────────────
  List<Widget> _curatedSection(
    BuildContext context,
    TargetsState state,
    Set<String> enabledIds,
  ) {
    if (state.isLoading) {
      return const [
        SectionHeader('Apps & feeds'),
        Padding(
          padding: EdgeInsets.only(top: AppSpacing.md),
          child: LoadingState(message: 'Loading apps…'),
        ),
      ];
    }
    if (state.error != null) {
      return [
        const SectionHeader('Apps & feeds'),
        EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load apps',
          subtitle: state.error,
          action: SecondaryButton(
            label: 'Retry',
            onPressed: () => context.read<TargetsCubit>().load(),
          ),
        ),
      ];
    }

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? state.targets
        : state.targets
              .where(
                (t) =>
                    t.displayName.toLowerCase().contains(q) ||
                    t.appName.toLowerCase().contains(q),
              )
              .toList();
    final apps = filtered.where((t) => !t.isBrowser).toList();
    final browsers = filtered.where((t) => t.isBrowser).toList();

    return [
      const SectionHeader('Apps & feeds'),
      if (state.targets.length > 8) ...[
        AppSearchField(
          hintText: 'Search apps & feeds',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (apps.isNotEmpty)
        PanelGroup(
          children: [
            for (final group in BlockAppGroup.from(apps))
              _appTile(context, group, enabledIds),
          ],
        ),
      if (browsers.isNotEmpty) ...[
        const SectionHeader('Browsers'),
        PanelGroup(
          children: [
            for (final group in BlockAppGroup.from(browsers))
              _appTile(context, group, enabledIds),
          ],
        ),
      ],
      if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.md),
          child: EmptyState(icon: Icons.search_off, title: 'No matches'),
        ),
    ];
  }

  Widget _appTile(
    BuildContext context,
    BlockAppGroup group,
    Set<String> enabledIds,
  ) {
    return BlockAppTile(
      group: group,
      enabledIds: enabledIds,
      onToggle: (id, {required enabled}) => enabled
          ? context.read<SettingsCubit>().togglePlatform(id, enabled: true)
          : _feedOff(group.surfaces.firstWhere((t) => t.platformId == id)),
    );
  }

  Future<void> _showAdd(BuildContext context) async {
    final cubit = context.read<AppBlockCubit>();
    // Protected apps can't be blocked (an app has one role; protection wins
    // natively anyway) — surface that in the picker instead of failing silently.
    final protected = await sl<ProtectedAppsRepository>().load();
    if (!context.mounted) return;
    final picked = await showAppPickerSheet(
      context,
      title: 'Block an app',
      confirmLabel: 'Block',
      loadApps: sl<EngineRepository>().installedApps,
      refreshApps: () => sl<EngineRepository>().installedApps(refresh: true),
      unavailable: {
        for (final e in cubit.state) e.packageName: 'Added',
        for (final a in ProtectedAppCatalog.apps)
          a.packageName: 'Auto-protected',
        for (final a in protected) a.packageName: 'Protected',
      },
    );
    if (picked == null || picked.isEmpty) return;
    final results = <AppBlockAddResult>[
      for (final app in picked) await cubit.add(app.packageName, app.appName),
    ];
    if (!context.mounted) return;
    _showAddOutcome(context, picked, results);
  }

  /// The toast tells the truth: "Added" only counts adds that landed, and a
  /// batch where nothing landed says why instead of celebrating a no-op.
  /// ("Added", not "Blocked": enforcement is native and real, but it engages
  /// on the entry's toggle/sync — this toast reports only the list mutation.)
  void _showAddOutcome(
    BuildContext context,
    List<InstalledApp> picked,
    List<AppBlockAddResult> results,
  ) {
    final added = results.where((r) => r == AppBlockAddResult.added).length;
    if (added > 0) {
      GlassToast.show(
        context,
        added == picked.length
            ? (added == 1
                  ? 'Added ${picked.first.appName}'
                  : 'Added $added apps')
            : 'Added $added of ${picked.length} apps',
        tone: AppTone.success,
      );
      return;
    }
    final message = switch (results.first) {
      AppBlockAddResult.sensitive => 'Sensitive app — Detoxo never blocks it.',
      AppBlockAddResult.duplicate => 'Already in your list.',
      AppBlockAddResult.failed => 'Couldn’t save — try again.',
      _ => 'That doesn’t look like a package id.',
    };
    GlassToast.show(context, message, tone: AppTone.warning);
  }
}
