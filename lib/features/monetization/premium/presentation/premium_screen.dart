import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:detoxo/features/monetization/premium/domain/entities/premium_entitlement.dart';
import 'package:detoxo/features/monetization/premium/presentation/premium_cubit.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const _features = [
    'Block in-app & web short video',
    'Unlock every platform & block mode',
    'App blocker & website blocker',
    'Remove ads',
    'Priority support',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detoxo Premium')),
      body: BlocBuilder<PremiumCubit, PremiumEntitlement>(
        builder: (context, premium) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Icon(
                Icons.workspace_premium,
                size: 64,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  premium.isPremium ? 'You are Premium 🎉' : 'Go Premium',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: "What's included",
                child: Column(
                  children: [
                    for (final feature in _features)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(feature),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!premium.isPremium)
                FullWidthButton(
                  label: 'Upgrade',
                  onPressed: () => _upgrade(context),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.read<PremiumCubit>().restore(),
                    child: const Text('Restore purchases'),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Tip: enable “Premium dev-unlock” in Settings to try premium '
                'features without a store purchase in this build.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _upgrade(BuildContext context) async {
    final error = await context.read<PremiumCubit>().purchase('premium_yearly');
    if (context.mounted && error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
