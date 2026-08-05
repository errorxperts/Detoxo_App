import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:detoxo/features/permissions/presentation/widgets/restricted_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The single entry point for granting a permission from anywhere in the app —
/// the funnel, the settings sheet and the dashboard card all route through here
/// so the disclosure and the recovery flow can't drift between them.
///
/// Order matters: if Android's restricted-settings gate is already swallowing
/// the grant, another trip to the system toggle just repeats the dead end, so
/// the walkthrough wins over a fresh request.
Future<void> requestPermission(BuildContext context, AppPermission kind) async {
  final cubit = context.read<PermissionsCubit>();
  final status = cubit.state.firstWhere(
    (s) => s.kind == kind,
    orElse: () => PermissionStatus(kind: kind),
  );

  if (status.blockedByRestrictedSettings) {
    return RestrictedSettingsSheet.show(context);
  }

  if (kind == AppPermission.accessibility) {
    final accepted = await _confirmAccessibilityDisclosure(context);
    if (!accepted) return;
  }

  await cubit.request(kind);
}

/// Google Play's Accessibility API policy requires a prominent, in-app
/// disclosure of what the service does and why, shown *before* the grant is
/// requested. The wording mirrors `accessibility_service_description` in
/// `android/app/src/main/res/values/strings.xml` so the in-app and OS-level
/// text agree — keep the two in sync.
Future<bool> _confirmAccessibilityDisclosure(BuildContext context) async {
  final accepted = await AppDialog.show<bool>(
    context: context,
    title: 'How Detoxo uses Accessibility',
    icon: Icons.accessibility_new,
    message:
        'Detoxo uses the Accessibility Service to detect short-form video '
        '(reels, shorts) in your apps and block it so you can stay focused.\n\n'
        'It reads on-screen content only to find and block distracting feeds. '
        'That check happens on your device, in the moment, and is thrown away '
        'immediately — Detoxo does not collect, store or transmit your screen '
        'content, messages or keystrokes.\n\n'
        'The next screen is Android’s own. Find Detoxo in the list and turn '
        'it on.',
    actions: [
      GhostButton(
        label: 'Not now',
        onPressed: () => Navigator.of(context).pop(false),
      ),
      PrimaryButton(
        label: 'Continue',
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );
  return accepted ?? false;
}
