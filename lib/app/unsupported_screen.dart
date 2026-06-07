import 'package:flutter/material.dart';

import 'package:detoxo/core/widgets/common_widgets.dart';

/// Shown on platforms (iOS) where the core AccessibilityService-based blocker
/// cannot run. See docs/15-ios-cross-platform.md for the FamilyControls path.
class UnsupportedScreen extends StatelessWidget {
  const UnsupportedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyState(
        icon: Icons.phonelink_erase,
        title: 'Detoxo runs on Android',
        subtitle:
            'The reel/short blocker relies on Android’s Accessibility Service, '
            'which has no equivalent on this platform. An iOS Screen Time / '
            'Family Controls version is a separate effort.',
      ),
    );
  }
}
