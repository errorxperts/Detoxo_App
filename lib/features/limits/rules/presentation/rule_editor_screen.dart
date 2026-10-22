import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/utils/clock_format.dart';
import 'package:detoxo/core/utils/duration_format.dart';
import 'package:detoxo/core/widgets/app_picker_sheet.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/catalog/catalog.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule_editor_args.dart';
import 'package:detoxo/features/limits/rules/domain/usecases/rule_summary.dart';
import 'package:detoxo/features/limits/rules/presentation/rules_cubit.dart';
import 'package:detoxo/features/limits/rules/presentation/widgets/override_tile.dart';
import 'package:detoxo/features/limits/rules/presentation/widgets/reel_feed_sheet.dart';
import 'package:detoxo/features/limits/rules/presentation/widgets/removable_chips.dart';
import 'package:detoxo/features/limits/rules/presentation/widgets/rule_kind_icon.dart';
import 'package:detoxo/features/limits/rules/presentation/widgets/website_sheet.dart';
import 'package:detoxo/features/protected_apps/protected_apps.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// Spoken weekday names for the day chips, whose visible labels are the
/// three-letter abbreviations `RuleSummary.dayLabel` renders.
const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The catalog's distracting categories — what the one-tap quick-pick toggles.
/// The catalog owns the set: `LockScope.distracting` widens to the same one.
final List<String> _distracting = Catalog.bundled.categoriesWithBehavior(
  AppBehavior.distracting,
);

/// Create / edit one rule. Draft state lives here until Save; the app-wide
/// [RulesCubit] persists and pushes.
class RuleEditorScreen extends StatefulWidget {
  const RuleEditorScreen({required this.args, super.key});

  final RuleEditorArgs args;

  /// One outline glyph per catalog category, so the rail can be scanned
  /// rather than read. Keyed by seed id; `test/rule_editor_test.dart` pins
  /// that every seed category has one, so a new category cannot ship bare.
  @visibleForTesting
  static const Map<String, IconData> categoryIcons = {
    'short_form_video': Icons.movie_filter_outlined,
    'social': Icons.people_outline,
    'video_streaming': Icons.live_tv_outlined,
    'games': Icons.sports_esports_outlined,
    'news': Icons.newspaper_outlined,
    'messaging': Icons.chat_bubble_outline,
    'browsers': Icons.language,
    'tools': Icons.handyman_outlined,
    'productivity': Icons.work_outline,
    'education': Icons.school_outlined,
  };

  /// The quick-pick's rule, pure so it can be pinned: when every id in [all]
  /// is already in [current], tapping clears them; otherwise it adds the
  /// missing ones and touches nothing else.
  @visibleForTesting
  static List<String> toggleAll(List<String> current, List<String> all) {
    if (all.every(current.contains)) {
      return [
        for (final id in current)
          if (!all.contains(id)) id,
      ];
    }
    return [
      ...current,
      for (final id in all)
        if (!current.contains(id)) id,
    ];
  }

  @override
  State<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<RuleEditorScreen> {
  late final TextEditingController _name;
  late final RuleKind _kind;
  late Set<int> _days;
  late int _startMin;
  late int _endMin;
  late int _minutes;
  late int _opens;
  late List<String> _apps;
  late List<String> _websites;
  late List<String> _platforms;
  late List<String> _categories;
  late bool _strict;

  /// M8. Set once, at creation — an existing locked rule can never be
  /// unlocked here, and `LockGuard` refuses it in the domain layer too.
  late bool _locked;
  late LockScope _lockScope;

  /// Labels for the selected apps' chips, from the process-wide installed-apps
  /// cache; a package the scan does not know falls back to its id.
  Map<String, String> _appLabels = const {};
  bool _saving = false;

  Rule? get _existing => widget.args.rule;

  /// "Edit" means the rule is STORED, not merely passed in: a preset stamp and
  /// the Activity row's "Limit this app" both arrive as a fresh, unsaved Rule
  /// and must read as new — "Save rule", "created", and no Delete button that
  /// would remove nothing and quietly discard the draft.
  late final bool _isEdit;

  @override
  void initState() {
    super.initState();
    final r = _existing;
    _isEdit =
        r != null &&
        context.read<RulesCubit>().state.rules.any((x) => x.id == r.id);
    _kind = r?.kind ?? widget.args.kind;
    _name = TextEditingController(text: r?.name ?? '');
    final s = r?.schedule;
    _days = {...(s?.days ?? RuleSchedule.weekdays)};
    _startMin = s?.startMin ?? 9 * 60;
    _endMin = s?.endMin ?? 17 * 60;
    _minutes = r == null || r.thresholdMs == 0 ? 30 : r.thresholdMs ~/ 60000;
    _opens = r == null || r.maxOpens == 0 ? 5 : r.maxOpens;
    _apps = [...(r?.selection.apps ?? const [])];
    _websites = [...(r?.selection.websites ?? const [])];
    _platforms = [...(r?.selection.platforms ?? const [])];
    _categories = [...(r?.selection.categories ?? const [])];
    _strict = r?.strict ?? false;
    _locked = r?.locked ?? false;
    _lockScope = r?.lockScope ?? LockScope.selection;
    sl<EngineRepository>().installedApps().then((apps) {
      if (!mounted || apps == null) return;
      setState(() {
        _appLabels = {for (final a in apps) a.packageName: a.appName};
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _defaultName => switch (_kind) {
    RuleKind.schedule => 'Schedule',
    RuleKind.timeLimit => 'Time limit',
    RuleKind.openLimit => 'Open limit',
  };

  @override
  Widget build(BuildContext context) {
    final ink2 = context.tokens.ink2;
    return GlassScaffold(
      appBar: GlassAppBar(
        title: Text(_isEdit ? 'Edit rule' : 'New ${_kind.label.toLowerCase()}'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.md,
          AppSpacing.gutter,
          AppSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          TextField(
            controller: _name,
            // Bounded like every other input here: the name is persisted and
            // rendered in a list row and in Today's Blocker rules row.
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: _defaultName,
              prefixIcon: Icon(ruleKindIcon(_kind)),
            ),
          ),
          ...switch (_kind) {
            RuleKind.schedule => _scheduleSection(),
            RuleKind.timeLimit => _budgetSection(
              headline: '${formatHm(Duration(minutes: _minutes))} a day',
              hint: 'Once the budget is spent, the apps block until midnight.',
              slider: Slider(
                value: _minutes.toDouble(),
                min: 5,
                max: 240,
                divisions: 47,
                semanticFormatterCallback: (v) => '${v.round()} minutes',
                onChanged: (v) => setState(() => _minutes = v.round()),
              ),
            ),
            RuleKind.openLimit => _budgetSection(
              headline: '${RuleSummary.count(_opens, 'open', 'opens')} a day',
              hint: 'After that many launches, the apps block until midnight.',
              slider: Slider(
                value: _opens.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                semanticFormatterCallback: (v) => '${v.round()} opens',
                onChanged: (v) => setState(() => _opens = v.round()),
              ),
            ),
          },
          // Concrete targets first (the apps, feeds and sites the user has in
          // mind), categories below them; Commitment comes after both, so the
          // rule says what it covers before it is asked how hard to hold.
          const SectionHeader('Block'),
          PanelGroup(
            children: [
              _target(
                GlassListTile(
                  leading: Icon(Icons.apps, color: ink2),
                  title: 'Apps',
                  subtitle: _apps.isEmpty
                      ? 'None selected'
                      : _count(_apps.length, 'app'),
                  trailing: Icon(Icons.add_circle_outline, color: ink2),
                  onTap: _pickApps,
                ),
                _apps.isEmpty
                    ? null
                    : RemovableChips(
                        items: _apps,
                        label: (pkg) => _appLabels[pkg] ?? pkg,
                        onRemove: (pkg) => setState(() => _apps.remove(pkg)),
                      ),
              ),
              if (_kind == RuleKind.schedule) ...[
                GlassListTile(
                  leading: Icon(Icons.play_circle_outline, color: ink2),
                  title: 'Reel feeds',
                  subtitle: _platforms.isEmpty
                      ? 'None selected'
                      : _count(_platforms.length, 'feed'),
                  trailing: Icon(Icons.add_circle_outline, color: ink2),
                  onTap: _pickPlatforms,
                ),
                _target(
                  GlassListTile(
                    leading: Icon(Icons.public, color: ink2),
                    title: 'Websites',
                    subtitle: _websites.isEmpty
                        ? 'None selected'
                        : _count(_websites.length, 'site'),
                    trailing: Icon(Icons.add_circle_outline, color: ink2),
                    onTap: _pickWebsites,
                  ),
                  _websites.isEmpty
                      ? null
                      : RemovableChips(
                          items: _websites,
                          onRemove: (h) => setState(() => _websites.remove(h)),
                        ),
                ),
              ],
            ],
          ),
          if (_kind != RuleKind.schedule)
            const InlineHint(
              icon: Icons.info_outline,
              text:
                  'Limits count app time from Android usage access, so they '
                  'apply to apps and categories.',
            ),
          const SectionHeader('Categories'),
          // Seed order is behaviour order (distracting first), so the top row
          // is the usual suspects and the quick-pick that opens it covers them.
          ChipRail(
            leading: AppChip(
              label: 'All distracting',
              // The lock section's "every distracting app" is a different set
              // (packages, re-resolved at push); name the noun this one toggles.
              semanticLabel: 'All distracting categories',
              icon: Icons.bolt_outlined,
              selected: _distracting.every(_categories.contains),
              onSelected: () => setState(
                () => _categories = RuleEditorScreen.toggleAll(
                  _categories,
                  _distracting,
                ),
              ),
            ),
            chips: [
              for (final c in AppCategorySeed.categories)
                AppChip(
                  label: c.displayName,
                  icon: RuleEditorScreen.categoryIcons[c.id],
                  selected: _categories.contains(c.id),
                  onSelected: () => setState(() {
                    _categories.contains(c.id)
                        ? _categories.remove(c.id)
                        : _categories.add(c.id);
                  }),
                ),
            ],
          ),
          const SectionHeader('Commitment'),
          ..._commitmentSection(context),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: _isEdit ? 'Save changes' : 'Save rule',
            expand: true,
            onPressed: _saving ? null : _save,
          ),
          // A locked rule shows NO delete button — absent, not greyed, the
          // same rule the list applies to its toggle. `LockGuard` refuses it in
          // the domain either way; this stops the user learning that the hard
          // way. Gated on the STORED lock, so ticking "Lock this rule" in the
          // draft does not make the button vanish before it is saved.
          if (_isEdit && !(_existing?.locked ?? false)) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Delete rule',
              destructive: true,
              onPressed: _delete,
            ),
          ],
        ],
      ),
    );
  }

  /// A target row with its picked chips under it, as one panel row.
  Widget _target(Widget row, Widget? chips) => chips == null
      ? row
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: chips,
            ),
          ],
        );

  List<Widget> _scheduleSection() {
    final overnight = _endMin < _startMin;
    final time = localTimeFormat(context);
    final ink2 = context.tokens.ink2;
    return [
      const SectionHeader('When'),
      PanelGroup(
        children: [
          Padding(
            // The rows' own insets, so the chips line up with their titles.
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (var d = 1; d <= 7; d++)
                  AppChip(
                    label: RuleSummary.dayLabel(d),
                    // Full weekday for screen readers: "Mon" is a glyph, not a
                    // word.
                    semanticLabel: _weekdayNames[d - 1],
                    selected: _days.contains(d),
                    onSelected: () => setState(() {
                      _days.contains(d) ? _days.remove(d) : _days.add(d);
                    }),
                  ),
              ],
            ),
          ),
          GlassListTile(
            leading: Icon(Icons.schedule, color: ink2),
            title: 'Starts',
            subtitle: time(_startMin),
            onTap: () => _pickTime(start: true),
          ),
          GlassListTile(
            leading: Icon(Icons.schedule, color: ink2),
            title: 'Ends',
            subtitle: time(_endMin),
            onTap: () => _pickTime(start: false),
          ),
        ],
      ),
      if (_startMin == _endMin)
        const InlineHint(
          icon: Icons.error_outline,
          text: 'Start and end cannot be the same time.',
        )
      else if (overnight)
        const InlineHint(
          icon: Icons.nightlight_round,
          text:
              'Ends the next morning — the whole night counts as the start day.',
        ),
    ];
  }

  List<Widget> _budgetSection({
    required String headline,
    required String hint,
    required Widget slider,
  }) => [
    const SectionHeader('Daily budget'),
    PanelGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: AppTypography.headline.copyWith(
                  color: context.tokens.ink,
                ),
              ),
              slider,
            ],
          ),
        ),
      ],
    ),
    InlineHint(icon: Icons.info_outline, text: hint),
  ];

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _startMin : _endMin;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: start ? 'Blocking starts' : 'Blocking ends',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (start) {
        _startMin = m;
      } else {
        _endMin = m;
      }
    });
  }

  Future<void> _pickApps() async {
    // Protected apps cannot be targeted (one role per app; protection wins
    // natively anyway) — the picker says so instead of failing silently.
    final protected = await sl<ProtectedAppsRepository>().load();
    if (!mounted) return;
    final picked = await showAppPickerSheet(
      context,
      title: 'Choose apps',
      confirmLabel: 'Add',
      loadApps: sl<EngineRepository>().installedApps,
      refreshApps: () => sl<EngineRepository>().installedApps(refresh: true),
      unavailable: {
        for (final p in _apps) p: 'Added',
        for (final a in ProtectedAppCatalog.apps)
          a.packageName: 'Auto-protected',
        for (final a in protected) a.packageName: 'Protected',
      },
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      for (final app in picked) {
        if (!_apps.contains(app.packageName)) _apps.add(app.packageName);
        _appLabels = {..._appLabels, app.packageName: app.appName};
      }
    });
  }

  Future<void> _pickPlatforms() async {
    final engine = sl<EngineRepository>();
    final targets = await sl<ConfigRepository>().loadBlockTargets(
      installedPackages: await engine.installedPackages(),
    );
    if (!mounted) return;
    final options = [
      for (final t in targets)
        if (!t.isBrowser &&
            (t.isInstalled || _platforms.contains(t.platformId)))
          (id: t.platformId, label: t.displayName),
    ];
    final picked = await ReelFeedSheet.show(
      context,
      title: 'Reel feeds',
      options: options,
      selected: _platforms.toSet(),
    );
    if (picked == null || !mounted) return;
    setState(
      () =>
          _platforms = options.map((o) => o.id).where(picked.contains).toList(),
    );
  }

  Future<void> _pickWebsites() async {
    final picked = await WebsiteSheet.show(context, initial: _websites);
    if (picked == null || !mounted) return;
    setState(() => _websites = picked);
  }

  /// Strict, then M8's "Lock this rule" — the strongest commitment the app
  /// offers, and the only one that cannot be undone from inside it — as one
  /// panel, with the hints under it.
  ///
  /// The lock has three states, deliberately different shapes:
  /// * **Not yet locked** — a toggle plus a blunt confirmation. Locking is a
  ///   one-way door, so it asks once, in plain words.
  /// * **Locked in the DRAFT but not saved** — the toggle stays, and stays
  ///   undoable. Nothing is committed until Save, and dropping the toggle here
  ///   made a mis-tap escapable only by leaving the editor and losing every
  ///   other pending edit — punishing the user for a decision the app had not
  ///   yet acted on.
  /// * **Already locked in the STORED rule** — no toggle at all (an off switch
  ///   that refuses is an invitation to keep tapping), a standing notice, and
  ///   the honest way out: spend one override.
  List<Widget> _commitmentSection(BuildContext context) {
    final committed = _existing?.locked ?? false;
    final ink2 = context.tokens.ink2;
    return [
      PanelGroup(
        children: [
          // A locked rule is committed: strict is implied and no longer the
          // user's to change, so the toggle goes away rather than sitting
          // there greyed out.
          if (!_locked)
            AppToggleTile(
              leading: Icon(Icons.lock_outline, color: ink2),
              title: 'Strict',
              subtitle: "A Pause won't lift this rule",
              value: _strict,
              onChanged: (v) => setState(() => _strict = v),
            ),
          if (!committed)
            AppToggleTile(
              leading: Icon(Icons.lock, color: ink2),
              title: 'Lock this rule',
              subtitle: _locked
                  ? 'Takes effect when you save.'
                  : 'No off switch. Lifting it costs an override.',
              value: _locked,
              onChanged: (v) async {
                if (!v) {
                  setState(() => _locked = false);
                  return;
                }
                final ok = await AppDialog.confirm(
                  context: context,
                  title: 'Lock this rule?',
                  message:
                      'A locked rule has no off switch and can’t be deleted. '
                      'An override lifts it for up to an hour, twice a week. '
                      'Reset app data is the only way to remove it.',
                  confirmLabel: 'Lock it',
                );
                if (ok && mounted) setState(() => _locked = true);
              },
            ),
          // Schedules only: `resolveSnapshot` never widens a limit (its budget
          // would widen with it), so offering the one-way toggle there
          // committed the user to a setting that did nothing.
          if (_locked && _kind == RuleKind.schedule)
            AppToggleTile(
              leading: Icon(Icons.auto_awesome_motion, color: ink2),
              title: 'Cover every distracting app',
              subtitle: 'Keeps holding as new ones are installed',
              value: _lockScope == LockScope.distracting,
              // Widening only: a lock that covers less than it did is a lock
              // being picked apart, and `LockGuard` refuses that anyway.
              onChanged: _lockScope == LockScope.distracting
                  ? null
                  : (v) => setState(
                      () => _lockScope = v ? LockScope.distracting : _lockScope,
                    ),
            ),
          // The STORED rule, not the draft: ticking "Lock this rule" and then
          // spending an override before saving would burn quota on a rule that
          // is not locked — and `resolveSnapshot` would have nothing to lift.
          if (committed) OverrideTile(rule: _existing!),
        ],
      ),
      if (_strict && !_locked)
        const InlineHint(
          icon: Icons.info_outline,
          text:
              'Strict rules keep blocking apps, reel feeds and websites even '
              'during a Pause.',
        ),
      if (_locked)
        InlineHint(
          icon: Icons.lock,
          text: committed
              ? 'Locked: no off switch, no delete, and a Pause doesn’t lift '
                    'it. Widen it any time; an override gets you through.'
              : 'Saving locks this rule. After that the only way in is an '
                    'override.',
        ),
    ];
  }

  Future<void> _save() async {
    final schedule = _kind == RuleKind.schedule
        ? RuleSchedule(days: _days, startMin: _startMin, endMin: _endMin)
        : null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rule = Rule(
      id: _existing?.id ?? const Uuid().v4(),
      name: _name.text.trim().isEmpty ? _defaultName : _name.text.trim(),
      kind: _kind,
      createdAtMs: _existing?.createdAtMs ?? now,
      enabled: _existing?.enabled ?? true,
      selection: RuleSelection(
        mode: _existing?.selection.mode ?? SelectionMode.block,
        apps: _apps,
        categories: _categories,
        websites: _kind == RuleKind.schedule ? _websites : const [],
        // Platforms survive a TIME limit now that `_limitEntry` meters reel
        // time for one: blanking them here re-saved onboarding's starter rule
        // as a rule with no targets at all, so renaming it quietly killed it.
        // An open limit still counts launches per package, which a feed has
        // none of, so it keeps dropping them.
        platforms: _kind == RuleKind.openLimit ? const [] : _platforms,
      ),
      schedule: schedule,
      thresholdMs: _kind == RuleKind.timeLimit ? _minutes * 60000 : 0,
      maxOpens: _kind == RuleKind.openLimit ? _opens : 0,
      strict: _strict,
      locked: _locked,
      lockScope: _lockScope,
    );
    // Same check the cubit re-runs before it persists — one helper, no copies.
    final error = rule.validate();
    if (error != null) {
      GlassToast.show(context, error, tone: AppTone.warning);
      return;
    }
    setState(() => _saving = true);
    final cubit = context.read<RulesCubit>();
    final ok = await cubit.save(rule);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      // Read, then clear: the list screen underneath leaves an error raised
      // from here alone, so it is this screen's to consume.
      final message = cubit.state.error ?? RulesCubit.saveFailed;
      cubit.clearError();
      GlassToast.show(context, message, tone: AppTone.warning);
      return;
    }
    GlassToast.show(
      context,
      _isEdit ? 'Rule saved.' : 'Rule created.',
      tone: AppTone.success,
    );
    context.pop();
  }

  Future<void> _delete() async {
    final rule = _existing!;
    final confirmed = await ConfirmSheet.show(
      context,
      icon: Icon3d(
        Assets.images.icons.iconBlockerRules,
        size: ConfirmSheet.iconSize,
      ),
      title: 'Delete ${rule.name}?',
      message: 'Its apps and sites unblock right away.',
      action: 'Slide to delete',
      cancel: 'Keep the rule',
      tone: ConfirmTone.critical,
    );
    if (!confirmed || !mounted) return;
    final cubit = context.read<RulesCubit>();
    final ok = await cubit.remove(rule.id);
    if (!mounted) return;
    if (ok) {
      GlassToast.show(context, '${rule.name} deleted');
      context.pop();
    } else {
      // Read the cubit's own message, like `_save` does: "this rule is locked"
      // and "your rules didn't load" are not the same problem, and neither is
      // "couldn't save — try again".
      final message = cubit.state.error ?? RulesCubit.saveFailed;
      cubit.clearError();
      GlassToast.show(context, message, tone: AppTone.warning);
    }
  }

  static String _count(int n, String noun) =>
      '${RuleSummary.count(n, noun, '${noun}s')} selected';
}
