import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/utils/duration_format.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/limits/app_blocker/domain/repositories/app_block_repository.dart';
import 'package:detoxo/features/limits/unblock/domain/entities/temporary_unblock.dart';
import 'package:detoxo/features/limits/unblock/presentation/unblock_cubit.dart';
import 'package:detoxo/features/limits/unblock/presentation/widgets/allowed_until.dart';
import 'package:detoxo/features/limits/unblock/presentation/widgets/unblock_duration_sheet.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/popular_site.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_entry.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_source.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_stats.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_stats_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/utils/domain_validator.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_block_cubit.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_block_state.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

/// Manage website blocking: one-tap popular-site chips, a Protection row that
/// opens the batch-protection screen, a searchable custom blocklist, and a
/// stats dashboard. Enforcement runs natively by reading the
/// browser address bar and pressing back on a blocked domain.
class WebBlockScreen extends StatelessWidget {
  const WebBlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WebBlockCubit(
        sl<WebBlockRepository>(),
        sl<SettingsRepository>(),
        sl<AppBlockRepository>(),
        sl<WebBlockStatsRepository>(),
        sl<EngineRepository>(),
      )..load(),
      child: const _WebBlockView(),
    );
  }
}

class _WebBlockView extends StatelessWidget {
  const _WebBlockView();

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(
        title: Text('Web Blocker'),
        actions: [
          InfoButton(
            'Detoxo reads the address bar and backs you out of blocked sites. '
            'Tap a popular site, add your own, or open Protection.',
          ),
        ],
      ),
      floatingActionButton: GlassFab(
        onPressed: () => _showSiteSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: 'Add website',
      ),
      body: SafeArea(
        child: BlocConsumer<WebBlockCubit, WebBlockState>(
          listenWhen: (p, c) => p.error != c.error && c.error != null,
          listener: (context, state) {
            GlassToast.show(context, state.error!, tone: AppTone.danger);
            context.read<WebBlockCubit>().clearError();
          },
          // No buildWhen: stats events are rare while this screen is visible
          // (blocks happen while the user is in the browser), so the full
          // rebuild is the cheap option over selector plumbing.
          builder: (context, state) {
            if (state.isLoading) {
              return const LoadingState(message: 'Loading…');
            }
            // The list has no right padding so the chip rows can scroll off the
            // screen edge; every other child adds it back.
            Widget inset(Widget child) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.gutter),
              child: child,
            );
            final count = state.entries.length;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                0,
                96 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                // The one entrance: the stats appear with the first block,
                // often while the screen is open. Nothing else replays on the
                // emits that follow.
                if (state.hasStats)
                  inset(_StatsSection(stats: state.stats)).entrance(),
                inset(const SectionHeader('Popular sites')),
                _PopularChips(state: state),
                const SizedBox(height: AppSpacing.md),
                inset(_ProtectionRow(activeCount: state.protectionCount)),
                inset(
                  SectionHeader(
                    'Your blocklist',
                    note: !state.hasEntries
                        ? null
                        : count == 1
                        ? '1 site'
                        : '$count sites',
                  ),
                ),
                inset(_Blocklist(state: state)),
                if (state.unsupportedBrowsers.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  inset(
                    _UnsupportedBrowsersNotice(
                      browsers: state.unsupportedBrowsers,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Add / edit sheet, shared by the FAB, the "Add website" chip and row edit.
Future<void> _showSiteSheet(
  BuildContext context, {
  WebBlockEntry? entry,
}) async {
  final cubit = context.read<WebBlockCubit>();
  final host = await GlassBottomSheet.show<String>(
    context: context,
    title: entry == null ? 'Block a website' : 'Edit website',
    child: _SiteSheet(cubit: cubit, entry: entry),
  );
  if (host != null && context.mounted) {
    GlassToast.show(
      context,
      entry == null ? 'Blocked $host' : 'Updated to $host',
      tone: AppTone.success,
    );
  }
}

// ── Stats dashboard ─────────────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});

  final WebBlockStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // No `crossAxisAlignment: stretch` here: this Row sits in a
          // ListView, so its height is unbounded — stretch hands the cards
          // an infinite height constraint and layout aborts the frame
          // (blank body, then per-frame `!semantics.parentDataDirty` spam).
          // The three cards are identical, so they match heights anyway.
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Blocked today',
                  value: stats.blockedToday,
                  icon: Icons.block,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  label: 'Total blocked',
                  value: stats.totalBlocked,
                  icon: Icons.public_off,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  label: 'Focus saved',
                  text: formatHm(Duration(minutes: stats.focusMinutesSaved)),
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),
          if (stats.mostBlockedHost != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.trending_up, size: 16, color: t.ink2),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Most blocked: ',
                  style: AppTypography.subhead.copyWith(color: t.ink2),
                ),
                Flexible(
                  child: Text(
                    stats.mostBlockedHost!,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subhead.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Unsupported browsers (EVO-047) ──────────────────────────────────────────
/// Names the installed browsers the engine cannot read, so the screen never
/// looks protective about a browser where nothing is enforced. Only rendered
/// when native actually answered and the list is non-empty — silence means
/// "all covered" or "couldn't ask", and inventing a warning for the second
/// would be its own kind of lie. The tap explains why.
class _UnsupportedBrowsersNotice extends StatelessWidget {
  const _UnsupportedBrowsersNotice({required this.browsers});

  final List<String> browsers;

  @override
  Widget build(BuildContext context) {
    final title = 'Not covered: ${browsers.join(', ')}';
    return NoticeLine(
      title,
      onTap: () => AppDialog.show<void>(
        context: context,
        title: title,
        message:
            'Detoxo can’t read the address bar in '
            '${browsers.length == 1 ? 'this browser' : 'these browsers'}, so '
            'your blocklist and the 18+ filter don’t apply there.',
      ),
    );
  }
}

// ── Protection row: batch protections live on their own screen ──────────────
/// One flat row under the popular sites: "Protection", how many batch
/// protections are on, and the chevron that says it opens a screen. One
/// button node, so TalkBack reads and activates it in one go.
class _ProtectionRow extends StatelessWidget {
  const _ProtectionRow({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return GlassListTile(
      leading: Icon(Icons.shield_outlined, color: context.tokens.ink2),
      title: 'Protection',
      subtitle: '$activeCount of ${WebBlockState.protectionTotal} on',
      onTap: () async {
        final cubit = context.read<WebBlockCubit>();
        await context.push<void>(Routes.webProtection);
        // The sub-screen edits the same persisted settings; re-load so this
        // row's count is fresh when the user comes back.
        await cubit.load();
      },
    );
  }
}

// ── Popular site chips ──────────────────────────────────────────────────────
class _PopularChips extends StatelessWidget {
  const _PopularChips({required this.state});

  final WebBlockState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WebBlockCubit>();
    final active = state.activePopularIds;
    // Two rows sharing one horizontal scroll; the "Add website" chip closes
    // the second.
    return ChipRail(
      // The list has no right padding so the rail can scroll off the screen
      // edge; only the far end of the scroll keeps a gutter.
      padding: const EdgeInsets.only(right: AppSpacing.gutter),
      trailing: AppChip(
        label: 'Add website',
        icon: Icons.add,
        selected: false,
        // A one-shot action, not a toggle: without this it announced as
        // "Add website, not selected".
        momentary: true,
        onSelected: () => _showSiteSheet(context),
      ),
      chips: [
        for (final site in state.popular)
          AppChip(
            label: site.name,
            icon: site.icon,
            selected: active.contains(site.id),
            onSelected: () {
              final listed = state.entries
                  .where((e) => e.pattern == site.primaryDomain)
                  .firstOrNull;
              // A chip lit by a custom entry upgrades it rather than
              // removing it, so only a removal that landed toasts.
              if (listed == null) {
                cubit.togglePopular(site);
              } else {
                _removeSite(
                  context,
                  listed,
                  '${site.name} unblocked',
                  commit: () => cubit.togglePopular(site),
                );
              }
            },
          ),
      ],
    );
  }
}

// ── Custom blocklist (search + rows) ────────────────────────────────────────
class _Blocklist extends StatelessWidget {
  const _Blocklist({required this.state});

  final WebBlockState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WebBlockCubit>();
    if (state.loadFailed) {
      // Unreadable, NOT empty: offering "add your own" here would invite the
      // user to type over a list that still exists and is still being
      // enforced natively. Retry, and say what actually happened.
      return EmptyState(
        icon: Icons.error_outline,
        title: "Couldn't open your blocklist",
        subtitle:
            'Your saved sites are still blocked. Try again, or reopen this '
            'screen.',
        action: PrimaryButton(
          label: 'Try again',
          flat: true,
          onPressed: cubit.load,
        ),
      );
    }
    if (!state.hasEntries) {
      // Same idiom as sibling screens: primary empty list = EmptyState + CTA.
      return EmptyState(
        icon: Icons.public_off,
        title: 'No sites blocked yet',
        subtitle: 'Tap a popular site above or add your own.',
        action: PrimaryButton(
          label: 'Add website',
          flat: true,
          onPressed: () => _showSiteSheet(context),
        ),
      );
    }
    final entries = state.visibleEntries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The query keeps the field visible even when deletions shrink the
        // list below the threshold — otherwise an active filter would have no
        // affordance to clear it. Threshold 8 matches the sibling screens.
        if (state.entries.length > 8 || state.query.isNotEmpty) ...[
          AppSearchField(
            hintText: 'Search blocked sites',
            onChanged: cubit.search,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: EmptyState(icon: Icons.search_off, title: 'No matches'),
          )
        else
          // Only one swipe pane open at a time across the list.
          SlidableAutoCloseBehavior(
            child: PanelGroup(
              children: [
                for (final entry in entries) _BlocklistRow(entry: entry),
              ],
            ),
          ),
      ],
    );
  }
}

class _BlocklistRow extends StatelessWidget {
  const _BlocklistRow({required this.entry});

  final WebBlockEntry entry;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WebBlockCubit>();
    final isCustom = entry.source == WebBlockSource.custom;
    final t = context.tokens;
    final color = entry.brandColor != null
        ? Color(entry.brandColor!)
        : t.tileWeb;
    // M8: the allow window is a grant now, so it comes from UnblockCubit's
    // DERIVED `active` list rather than from `DateTime.now()` at build time.
    // That matters: a cubit emit when the grant lapses actually rebuilds this
    // row, where a build-time clock read left a dead "Allowed until 14:05"
    // line on screen until something unrelated happened.
    final grant = context.select<UnblockCubit, TemporaryUnblock?>(
      (c) => c.state.activeFor(
        UnblockTargetType.website,
        entry.pattern,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
    final paused = grant != null;

    // How many actions the pane holds decides how far it opens.
    final actionCount = 1 + (entry.enabled ? 1 : 0) + (isCustom ? 1 : 0);
    // Disabled and paused rows read at a glance via a dimmed site letter.
    final dimmed = paused || !entry.enabled;
    // No outer clip: Slidable clips its own pane to the drag ratio, and each
    // action carries its own rounded surface.
    return Slidable(
      key: ValueKey(entry.pattern),
      groupTag: 'web-blocklist',
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        // Per-action gaps need a bit more room than the old edge-to-edge
        // pane; keeps every inner surface >= 48dp wide on a 360dp screen.
        extentRatio: const [0.30, 0.52, 0.70][actionCount - 1],
        children: [
          if (entry.enabled)
            RowAction(
              icon: paused ? Icons.play_arrow : Icons.timer_outlined,
              label: paused ? 'Resume' : 'Allow',
              tone: t.statusText(t.statusSetup),
              semanticLabel: paused
                  ? 'Resume blocking ${entry.label}'
                  : 'Allow ${entry.label} for a while',
              onPressed: (context) => paused
                  ? context.read<UnblockCubit>().endEarly(
                      UnblockTargetType.website,
                      entry.pattern,
                      // The same aliases the grant freed — see `_showAllowSheet`.
                      alsoEnd: entry.source == WebBlockSource.popular
                          ? PopularSites.aliasesFor(entry.pattern)
                          : const [],
                    )
                  : _showAllowSheet(context, entry),
            ),
          if (isCustom)
            RowAction(
              icon: Icons.edit_outlined,
              label: 'Edit',
              tone: t.brand.main,
              semanticLabel: 'Edit ${entry.label}',
              onPressed: (context) => _showSiteSheet(context, entry: entry),
            ),
          RowAction(
            icon: Icons.delete_outline,
            label: 'Delete',
            tone: t.over.main,
            semanticLabel: 'Remove ${entry.label}',
            onPressed: (_) => _removeSite(
              context,
              entry,
              '${entry.label} removed',
              commit: () => cubit.removeEntry(entry),
            ),
          ),
        ],
      ),
      child: Builder(
        // The swipe pane is the only route to Allow/Edit/Delete, and a screen
        // reader cannot swipe. Tap opens the same pane, so the tap target has
        // to SAY that — otherwise TalkBack announces a bare "example.com,
        // button" and those actions are unreachable.
        builder: (rowContext) => MergeSemantics(
          child: Semantics(
            hint: 'Opens allow, edit and delete actions',
            child: AppPressable(
              // Tap toggles the pane: swipe discoverability + a non-swipe path.
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
                    leading: AnimatedOpacity(
                      opacity: dimmed ? 0.45 : 1,
                      duration: context.motion(AppDurations.fast),
                      child: SiteLetter(entry.label, color: color, size: 34),
                    ),
                    title: entry.label,
                    // Popular rows show the domain under the brand name;
                    // custom rows' title already IS the domain.
                    subtitle: isCustom ? null : entry.pattern,
                    trailing: AppToggle(
                      value: entry.enabled,
                      semanticLabel: 'Block ${entry.label}',
                      onChanged: (v) => v
                          ? cubit.toggleEntry(entry, enabled: true)
                          : _siteOff(context, entry),
                    ),
                  ),
                  if (paused)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _textInset,
                        0,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: AllowedUntil(grant),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Where the row's title starts: the row inset, the 34 site letter and its
  /// gap. The allow line indents to it.
  static const double _textInset = AppSpacing.md + 34 + AppSpacing.sm;
}

// C10: switching one site off (or deleting it) stays one tap. The toast waits
// until the cubit's state shows the change landed (a failed save reverts and
// toasts its own error), speaks from the screen's Scaffold (a deleted row
// unmounts with its entry), and its Undo re-resolves the site by pattern at
// tap time: a site that is gone (or already back), or a screen that closed
// (the toast outlives the route), means do nothing.

Future<void> _siteOff(BuildContext context, WebBlockEntry entry) async {
  final cubit = context.read<WebBlockCubit>();
  final screen = Scaffold.of(context).context;
  WebBlockEntry? find() => cubit.isClosed
      ? null
      : cubit.state.entries
            .where((e) => e.pattern == entry.pattern)
            .firstOrNull;
  await cubit.toggleEntry(entry, enabled: false);
  if (!screen.mounted || find()?.enabled != false) return;
  GlassToast.show(
    screen,
    '${entry.label} unblocked',
    action: (
      label: 'Undo',
      onPressed: () {
        final now = find();
        if (now != null) cubit.toggleEntry(now, enabled: true);
      },
    ),
  );
}

/// A removal, by Delete or by deselecting a popular chip. Undo puts the entry
/// back where it was, fields intact.
Future<void> _removeSite(
  BuildContext context,
  WebBlockEntry entry,
  String message, {
  required Future<void> Function() commit,
}) async {
  final cubit = context.read<WebBlockCubit>();
  final screen = Scaffold.of(context).context;
  final index = cubit.state.entries.indexWhere(
    (e) => e.pattern == entry.pattern,
  );
  await commit();
  if (!screen.mounted ||
      cubit.state.entries.any((e) => e.pattern == entry.pattern)) {
    return;
  }
  GlassToast.show(
    screen,
    message,
    action: (
      label: 'Undo',
      onPressed: () {
        if (!cubit.isClosed) cubit.restoreEntry(entry, index);
      },
    ),
  );
}

/// EVO-012, generalised by M8: pick how long to allow the site. The chips are
/// now the shared `showUnblockDurationSheet` — the same sheet an app row and
/// the block screen use — and the window is a `WEBSITE` grant rather than a
/// per-entry field. Native still re-arms the block at expiry with Detoxo
/// closed; that is the property the whole mechanism exists for.
Future<void> _showAllowSheet(BuildContext context, WebBlockEntry entry) async {
  final unblock = context.read<UnblockCubit>();
  final window = await showUnblockDurationSheet(
    context,
    title: 'Unblock ${entry.label}?',
    icon: Assets.images.icons.iconWebBlocker,
    remaining: unblock.state.grantsLeft,
  );
  if (window == null) return;
  // A popular entry's cross-registrable aliases (youtu.be for youtube.com) ride
  // the wire as their own patterns, so they need their own grants — exactly
  // what `pausedUntil` did when it was duplicated onto them.
  final ok = await unblock.grant(
    UnblockTargetType.website,
    entry.pattern,
    window,
    source: UnblockSource.blocklistRow,
    alsoFree: entry.source == WebBlockSource.popular
        ? PopularSites.aliasesFor(entry.pattern)
        : const [],
  );
  // Only on success — a failure is toasted app-wide by the unblock listener.
  if (ok && context.mounted) {
    GlassToast.show(
      context,
      '${entry.label} unblocked for ${window.inMinutes} min',
      tone: AppTone.success,
    );
  }
}

/// Add / edit bottom-sheet body with inline domain validation.
class _SiteSheet extends StatefulWidget {
  const _SiteSheet({required this.cubit, this.entry});

  final WebBlockCubit cubit;
  final WebBlockEntry? entry;

  @override
  State<_SiteSheet> createState() => _SiteSheetState();
}

class _SiteSheetState extends State<_SiteSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.entry?.pattern ?? '',
  );
  String? _error;

  bool get _isEdit => widget.entry != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Same rule the cubit enforces — one shared helper, no drifting copies.
    final checked = DomainValidator.check(
      _controller.text,
      widget.cubit.state.entries.map((e) => e.pattern),
      ignoring: widget.entry?.pattern,
    );
    if (checked.host == null) {
      setState(() => _error = checked.error);
      return;
    }
    // Await the commit: success is only announced once persist + push ran.
    final ok = _isEdit
        ? await widget.cubit.editEntry(widget.entry!, _controller.text)
        : await widget.cubit.addCustom(_controller.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(checked.host);
    } else {
      // The cubit surfaced the reason via the screen's error toast.
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            hintText: 'e.g. youtube.com',
            errorText: _error,
            prefixIcon: const Icon(Icons.public),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: _isEdit ? 'Save' : 'Block website',
          onPressed: _submit,
          expand: true,
        ),
      ],
    );
  }
}
