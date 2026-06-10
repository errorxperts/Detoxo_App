import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Configure (or disable) the PIN lock and which sections it guards.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  PinType _type = PinType.custom;
  final _pinController = TextEditingController();
  final _emailController = TextEditingController();
  final Set<PinScope> _scopes = {PinScope.app, PinScope.settings};
  bool _biometric = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<PinCubit>().state;
    if (config.isConfigured) {
      _type = config.type;
      _scopes
        ..clear()
        ..addAll(config.scopes);
      _emailController.text = config.verifiedEmail;
      _biometric = config.biometricEnabled;
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final needsSecret = _type == PinType.custom;
    if (needsSecret && _pinController.text.trim().length < 4) {
      _toast('Enter a PIN of at least 4 digits.');
      return;
    }
    await context.read<PinCubit>().setup(
          type: _type,
          secret: _pinController.text.trim(),
          scopes: _scopes,
          verifiedEmail: _emailController.text.trim(),
          biometricEnabled: _biometric,
        );
    if (mounted) {
      _toast('PIN saved.');
      Navigator.of(context).pop();
    }
  }

  Future<void> _disable() async {
    await context.read<PinCubit>().disable();
    if (mounted) {
      _toast('PIN disabled.');
      Navigator.of(context).pop();
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final configured = context.watch<PinCubit>().state.isConfigured;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PIN lock'),
        actions: [
          if (configured)
            TextButton(onPressed: _disable, child: const Text('Disable')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'PIN type',
            child: Column(
              children: [
                for (final type in const [
                  PinType.custom,
                  PinType.date,
                  PinType.time,
                ])
                  RadioListTile<PinType>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_typeLabel(type)),
                    subtitle: Text(_typeHint(type)),
                    value: type,
                    // ignore: deprecated_member_use
                    groupValue: _type,
                    // ignore: deprecated_member_use
                    onChanged: (v) => setState(() => _type = v!),
                  ),
              ],
            ),
          ),
          if (_type == PinType.custom) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Your PIN',
              child: TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(hintText: 'Enter 4–10 digits'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SectionCard(
            title: 'Protect',
            child: Column(
              children: [
                _scopeTile(PinScope.app, 'Opening Detoxo'),
                _scopeTile(PinScope.settings, 'Changing settings'),
                _scopeTile(PinScope.planSwitch, 'Switching the plan'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Recovery email',
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'you@example.com (for PIN recovery)',
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow biometric unlock'),
              value: _biometric,
              onChanged: (v) => setState(() => _biometric = v),
            ),
          ),
          const SizedBox(height: 20),
          FullWidthButton(label: 'Save PIN', onPressed: _save),
        ],
      ),
    );
  }

  Widget _scopeTile(PinScope scope, String label) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: _scopes.contains(scope),
        onChanged: (v) => setState(() {
          if (v ?? false) {
            _scopes.add(scope);
          } else {
            _scopes.remove(scope);
          }
        }),
      );

  String _typeLabel(PinType t) => switch (t) {
        PinType.custom => 'Custom PIN',
        PinType.date => "Today's date",
        PinType.time => 'Current time',
        _ => t.name,
      };

  String _typeHint(PinType t) => switch (t) {
        PinType.custom => 'A PIN you choose',
        PinType.date => 'ddMMyyyy — changes daily',
        PinType.time => 'HHmm — changes each minute',
        _ => '',
      };
}
