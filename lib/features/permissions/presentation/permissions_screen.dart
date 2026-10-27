import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/presentation/permission_actions.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Guided permission funnel. Re-checks statuses whenever the app resumes (the
/// user typically grants from a system settings screen and returns).
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<PermissionsCubit>().refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<PermissionsCubit>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PermissionsCubit>();
    // Same predicate as the gate — the progress, the rows and the button must
    // never contradict each other under a flaky (unknown) read.
    int granted(List<PermissionStatus> s) =>
        s.where(cubit.effectivelyGranted).length;

    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Set up protection')),
      body: BlocConsumer<PermissionsCubit, List<PermissionStatus>>(
        // A grant lands while the user is away in system settings; a pulse on
        // the way back confirms it took. Not on the first load.
        listenWhen: (prev, next) =>
            prev.isNotEmpty && granted(next) > granted(prev),
        listener: (_, _) => AppHaptics.success(),
        builder: (context, statuses) {
          final required = statuses.where((s) => s.kind.required).toList();
          final optional = statuses.where((s) => !s.kind.required).toList();
          // The bottom button works through the required list in order, so
          // the whole funnel can be done from one place.
          final next = required
              .where((s) => !cubit.effectivelyGranted(s))
              .firstOrNull;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    AppSpacing.md,
                  ),
                  children: [
                    EntranceList(
                      children: [
                        if (required.isNotEmpty)
                          _Progress(
                            done: granted(required),
                            total: required.length,
                          ),
                        // Each section says what it is, so no row needs a
                        // "Required" pill.
                        if (required.isNotEmpty) ...[
                          const SectionHeader('Required'),
                          PanelGroup(
                            children: [
                              for (final s in required)
                                PermissionRow(s, key: ValueKey(s.kind)),
                            ],
                          ),
                        ],
                        if (optional.isNotEmpty) ...[
                          const SectionHeader('Recommended'),
                          PanelGroup(
                            children: [
                              for (final s in optional)
                                PermissionRow(s, key: ValueKey(s.kind)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                    vertical: AppSpacing.md,
                  ),
                  child: PrimaryButton(
                    label: next == null
                        ? 'Continue'
                        : 'Grant ${next.kind.label}',
                    expand: true,
                    // Statuses not read yet: an empty list passes the gate
                    // vacuously, so hold the button until they arrive.
                    onPressed: statuses.isEmpty
                        ? null
                        : next == null
                        ? () => context.go(Routes.home)
                        : () => requestPermission(context, next.kind),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// How far the required grants are, on the bare ground above the sections:
/// the count over a growing bar, then why the scariest grant is safe.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                done == total ? 'Ready to block' : 'Allow access to block',
                style: AppTypography.label.copyWith(color: t.ink),
              ),
            ),
            Text(
              '$done of $total on',
              style: AppTypography.subhead.copyWith(color: t.ink2),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ProgressBar(progress: done / total, height: 6, animate: true),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Screen content is checked on your phone and never stored or sent.',
          style: AppTypography.subhead.copyWith(color: t.ink2),
        ),
      ],
    );
  }
}
