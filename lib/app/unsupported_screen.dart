import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Shown on platforms (iOS) where the core AccessibilityService-based blocker
/// cannot run. See docs/code_docs/15-ios-cross-platform.md for the
/// FamilyControls path.
class UnsupportedScreen extends StatelessWidget {
  const UnsupportedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // GlassScaffold, like every other screen: the router now actually routes
    // here (its route was registered in M6), so this is the ONLY screen an
    // unsupported-platform user ever sees — a bare Material surface would be
    // the one place the app drops its own aesthetic.
    return const GlassScaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.phonelink_erase,
          title: 'Detoxo works on Android only',
          subtitle: 'This version can’t run on this device.',
        ),
      ),
    );
  }
}
