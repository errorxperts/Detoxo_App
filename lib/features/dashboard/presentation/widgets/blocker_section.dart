import 'dart:typed_data';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/utils/app_logger.dart';
import 'package:detoxo/core/utils/clock_format.dart';
import 'package:detoxo/features/additional_feature/showcase_view/showcase_view.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/dashboard/presentation/today_copy.dart';
import 'package:detoxo/features/limits/limits.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Today's Blockers section: the "Blockers" header with "N of 2 on", the
/// active-unblocks card (only while something is allowed), the App Blocker
/// and Web Blocker tiles, and the Blocker rules row last.
///
/// Both blocker cubits are screen-scoped, so the section reads the
/// repositories through [sl] instead and re-reads them when the user pops back
/// from either screen. The master switch and the built-in feeds are live from
/// [SettingsCubit] / [TargetsCubit].
class BlockerSection extends StatefulWidget {
  const BlockerSection({super.key});

  @override
  State<BlockerSection> createState() => _BlockerSectionState();
}

class _BlockerSectionState extends State<BlockerSection> {
  List<AppBlockEntry> _locks = const [];
  List<WebBlockEntry> _sites = const [];

  /// How many of the two web protections (18+, sites of blocked apps) are on.
  int _protections = 0;

  /// Device icons of the custom locks, by package. Letter tiles until loaded.
  Map<String, Uint8List> _icons = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The protections come from the repository, not [SettingsCubit]: the Web
  /// Blocker writes them straight there, so the cubit can be stale. A failed
  /// read is logged and the last good lists stay.
  Future<void> _load() async {
    try {
      final (locks, sites, settings) = await (
        sl<AppBlockRepository>().load(),
        sl<WebBlockRepository>().load(),
        sl<SettingsRepository>().load(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _locks = locks;
        _sites = sites;
        _protections = [
          settings.blockAdultWebsites,
          settings.blockWebsitesForBlockedApps,
        ].where((on) => on).length;
      });
      // The icon scan is native and slow the first time; only locks need it.
      if (locks.isEmpty) return;
      final apps = await sl<EngineRepository>().installedApps();
      if (!mounted || apps == null) return;
      setState(() => _icons = {for (final a in apps) a.packageName: ?a.icon});
    } catch (e, s) {
      AppLogger.e('Blockers section: load failed', e, s);
    }
  }

  /// Opens a blocker screen and re-reads the lists once it pops.
  Future<void> _open(String route) async {
    await context.push(route);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final masterOn = context.select((SettingsCubit c) => c.state.masterEnabled);
    final feedIds = context.select(
      (SettingsCubit c) => c.state.enabledPlatformIds,
    );
    final targets = context.select((TargetsCubit c) => c.state.targets);

    // App Blocker: the custom locks, then the built-in feeds that are on.
    final feeds = [
      for (final f in targets)
        if (f.isInstalled && feedIds.contains(f.platformId)) f,
    ];
    final locksOn = _locks.where((e) => e.enabled).toList();
    final apps = _stack([
      for (final e in locksOn.isEmpty && feeds.isEmpty ? _locks : locksOn)
        (
          e.packageName,
          AppIconAvatar(
            iconUrl: '',
            iconBytes: _icons[e.packageName],
            appName: e.appName,
            size: 28,
            borderRadius: _iconRadius,
          ),
        ),
      for (final f in feeds)
        (
          f.packageName,
          AppIconAvatar(
            iconUrl: f.iconUrl,
            appName: f.appName,
            size: 28,
            borderRadius: _iconRadius,
          ),
        ),
    ]);
    final appStatus = blockerStatus(
      total: _locks.length + feeds.length,
      enabled: locksOn.length + feeds.length,
      masterOn: masterOn,
    );

    final sitesOn = _sites.where((e) => e.enabled).toList();
    final sites = _stack([
      for (final e in sitesOn.isEmpty ? _sites : sitesOn)
        (
          e.pattern,
          SiteLetter(
            e.label,
            color: e.brandColor == null ? t.tileWeb : Color(e.brandColor!),
          ),
        ),
    ]);
    final webStatus = blockerStatus(
      total: _sites.length + _protections,
      enabled: sitesOn.length + _protections,
      masterOn: masterOn,
    );
    final on = [appStatus, webStatus].where((s) => s == BlockerStatus.on);

    Widget tile(int step, Widget child) => Expanded(
      child: showcaseTarget(
        step: featureShowcaseSteps[step],
        index: step,
        radius: AppRadius.card,
        child: child,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Blockers',
                  style: AppTypography.title.copyWith(color: t.ink),
                ),
              ),
            ),
            Text(
              '${on.length} of 2 on',
              style: AppTypography.subhead.copyWith(color: t.ink2),
            ),
          ],
        ),
        // EVO-051: absent entirely when nothing is allowed — it exists to be
        // noticed exactly when something is. Brings its own top gap. Names
        // come from what this section already loaded; a host is its own name.
        ActiveUnblocksCard(
          nameOf: (g) =>
              switch (g.targetType) {
                UnblockTargetType.reel =>
                  targets
                      .where((f) => f.platformId == g.targetId)
                      .firstOrNull
                      ?.displayName,
                UnblockTargetType.app =>
                  _locks
                          .where((e) => e.packageName == g.targetId)
                          .firstOrNull
                          ?.appName ??
                      targets
                          .where((f) => f.packageName == g.targetId)
                          .firstOrNull
                          ?.appName,
                UnblockTargetType.website => null,
              } ??
              g.targetId,
        ),
        const SizedBox(height: AppSpacing.gap),
        // Equal heights when large text grows one tile past the 180 floor.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile(
                5,
                BlockerTile(
                  icon: Assets.images.icons.iconAppBlocker,
                  title: 'App Blocker',
                  status: appStatus,
                  glow: t.tileApp,
                  stack: apps.shown,
                  more: apps.more,
                  countLabel: RuleSummary.count(apps.total, 'app', 'apps'),
                  onTap: () => _open(Routes.appBlock),
                ),
              ),
              const SizedBox(width: AppSpacing.gap),
              tile(
                6,
                BlockerTile(
                  icon: Assets.images.icons.iconWebBlocker,
                  title: 'Web Blocker',
                  status: webStatus,
                  glow: t.tileWeb,
                  stack: sites.shown,
                  more: sites.more,
                  roundStack: true,
                  countLabel: sites.total == 0
                      ? null
                      : RuleSummary.count(sites.total, 'site', 'sites'),
                  note: _protections > 0 ? 'Protection on' : null,
                  onTap: () => _open(Routes.webBlock),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gap),
        BlocBuilder<RulesCubit, RulesState>(
          builder: (context, state) => BlockerRulesRow(
            summary: RuleSummary.nextEvent(
              state.rules,
              state.statuses,
              DateTime.now(),
              time: localTimeFormat(context),
            ),
            onCount: state.rules.isEmpty ? null : state.enabledCount,
            onTap: () => context.push(Routes.rules),
          ),
        ),
      ],
    );
  }

  static final _iconRadius = BorderRadius.circular(AppRadius.icon);

  /// One icon per distinct key (an app counts once however many of its feeds
  /// are on), split into the first three and the "+N" rest.
  static ({List<Widget> shown, int more, int total}) _stack(
    List<(String, Widget)> items,
  ) {
    final seen = <String>{};
    final unique = [
      for (final (key, icon) in items)
        if (seen.add(key)) icon,
    ];
    return (
      shown: unique.take(3).toList(),
      more: unique.length > 3 ? unique.length - 3 : 0,
      total: unique.length,
    );
  }
}
