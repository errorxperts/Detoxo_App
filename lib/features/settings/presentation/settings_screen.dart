import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/monetization/premium/presentation/premium_cubit.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _modeLabels = {
    BlockingMode.pressBack: 'Press back (recommended)',
    BlockingMode.killApp: 'Close the app',
    BlockingMode.lockScreen: 'Lock the screen',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Protection',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Blocking enabled'),
                  subtitle: const Text('Master switch for all detection'),
                  value: settings.masterEnabled,
                  onChanged: (v) =>
                      context.read<SettingsCubit>().setMasterEnabled(enabled: v),
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'When a reel is detected',
                child: Column(
                  children: [
                    for (final entry in _modeLabels.entries)
                      RadioListTile<BlockingMode>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value),
                        value: entry.key,
                        // ignore: deprecated_member_use
                        groupValue: settings.defaultBlockMode,
                        // ignore: deprecated_member_use
                        onChanged: (mode) {
                          if (mode != null) {
                            context
                                .read<SettingsCubit>()
                                .setDefaultBlockMode(mode);
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Feedback',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vibrate on block'),
                  value: settings.vibrationEnabled,
                  onChanged: (v) =>
                      context.read<SettingsCubit>().setVibration(enabled: v),
                ),
              ),
              const SizedBox(height: 12),
              const _AdvancedSection(),
              const SizedBox(height: 12),
              const _DeveloperSection(),
            ],
          );
        },
      ),
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection();

  @override
  Widget build(BuildContext context) {
    final deviceAdmin = context.watch<PermissionsCubit>().state.firstWhere(
          (s) => s.kind == AppPermission.deviceAdmin,
          orElse: () => const PermissionStatus(kind: AppPermission.deviceAdmin),
        );
    return SectionCard(
      title: 'Advanced',
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Uninstall protection'),
        subtitle: const Text('Use device admin to resist removal'),
        value: deviceAdmin.granted,
        onChanged: (v) {
          if (v) {
            context.read<PermissionsCubit>().request(AppPermission.deviceAdmin);
          }
        },
      ),
    );
  }
}

class _DeveloperSection extends StatelessWidget {
  const _DeveloperSection();

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumCubit>().state.isPremium;
    return SectionCard(
      title: 'Developer',
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Premium dev-unlock'),
        subtitle: const Text('Unlock premium features locally for testing'),
        value: isPremium,
        onChanged: (v) => context.read<PremiumCubit>().toggleDevUnlock(unlocked: v),
      ),
    );
  }
}
