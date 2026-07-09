import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/help/report_issue/report_issue.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Help & support hub — a single drawer entry point that groups the four
/// help actions: report an issue, browse FAQs, replay tutorials, and share an
/// idea. Report an issue opens a dialog; the others push their own screens.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Help & support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          const SectionHeader('Get help'),
          FeatureTile(
            icon: Icons.bug_report_outlined,
            title: 'Report an issue',
            subtitle: 'Tell us about a bug or problem',
            onTap: () => ReportIssueDialog.show(context),
          ),
          FeatureTile(
            icon: Icons.help_outline,
            animatedIcon: AppIcon.info,
            title: 'FAQ',
            subtitle: 'Answers to common questions',
            onTap: () => context.push(Routes.helpFaq),
          ),
          const SectionHeader('Learn & share'),
          FeatureTile(
            icon: Icons.tips_and_updates_outlined,
            title: 'Feature tutorials',
            subtitle: 'Replay the guided tours',
            onTap: () => context.push(Routes.featureTutorial),
          ),
          FeatureTile(
            icon: Icons.lightbulb_outline,
            title: 'Share an idea',
            subtitle: 'Suggest a feature or improvement',
            onTap: () => context.push(Routes.shareIdeas),
          ),
          const SectionHeader('Legal'),
          FeatureTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () => context.push(Routes.privacyPolicy),
          ),
          FeatureTile(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            subtitle: 'The terms for using Detoxo',
            onTap: () => context.push(Routes.termsConditions),
          ),
        ],
      ),
    );
  }
}
