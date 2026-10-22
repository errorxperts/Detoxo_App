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
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Set up protection')),
      body: BlocBuilder<PermissionsCubit, List<PermissionStatus>>(
        builder: (context, statuses) {
          final cubit = context.read<PermissionsCubit>();
          final allRequired = cubit.allRequiredGranted;
          final required = statuses.where((s) => s.kind.required).toList();
          final optional = statuses.where((s) => !s.kind.required).toList();
          // Same predicate as the gate — the "n of m on" note, the rows and
          // the Continue button must never contradict each other under a
          // flaky (unknown) read.
          final grantedReq = required.where(cubit.effectivelyGranted).length;

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
                    Text(
                      'Grant a few permissions so Detoxo can do its job.',
                      style: AppTypography.body.copyWith(
                        color: context.tokens.ink2,
                      ),
                    ),
                    // Each section says what it is, so no row needs a
                    // "Required" pill; the count is the section's note.
                    if (required.isNotEmpty) ...[
                      SectionHeader(
                        'Required to block',
                        note: '$grantedReq of ${required.length} on',
                      ),
                      PanelGroup(
                        children: [for (final s in required) PermissionRow(s)],
                      ),
                    ],
                    if (optional.isNotEmpty) ...[
                      const SectionHeader('Recommended'),
                      PanelGroup(
                        children: [for (final s in optional) PermissionRow(s)],
                      ),
                    ],
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
                    label: allRequired
                        ? 'Continue'
                        : 'Grant required permissions',
                    expand: true,
                    onPressed: allRequired
                        ? () => context.go(Routes.home)
                        : null,
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
