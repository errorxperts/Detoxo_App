import 'package:detoxo/core/utils/result.dart';
import 'package:detoxo/features/access_protection/domain/entities/pin_config.dart';
import 'package:detoxo/features/access_protection/domain/repositories/pin_repository.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/access_protection/presentation/pin_gate.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory PIN repository for tests (no secure storage / network).
class _FakePinRepo implements PinRepository {
  PinConfig _stored = const PinConfig();

  @override
  Future<PinConfig> load() async => _stored;

  @override
  Future<void> save(PinConfig config) async => _stored = config;

  @override
  Future<Result<void>> sendRecoveryOtp(String email) async => const Ok(null);

  @override
  Future<Result<bool>> validateOtp(String email, String otp) async =>
      Ok(otp.trim() == '000000');
}

void main() {
  group('PinCubit.expectedLength', () {
    test('custom uses the stored secret length', () async {
      final cubit = PinCubit(_FakePinRepo());
      await cubit.setup(
        type: PinType.custom,
        secret: '123456',
        scopes: {PinScope.app},
      );
      expect(cubit.expectedLength, 6);
    });

    test('date is 8 (ddMMyyyy) and time is 4 (HHmm)', () async {
      final cubit = PinCubit(_FakePinRepo());
      await cubit.setup(type: PinType.date, secret: '', scopes: {PinScope.app});
      expect(cubit.expectedLength, 8);
      await cubit.setup(type: PinType.time, secret: '', scopes: {PinScope.app});
      expect(cubit.expectedLength, 4);
    });
  });

  group('PinCubit.resetSecretAfterRecovery', () {
    test(
      'sets a fresh custom PIN, clears lockout, preserves scopes/email/biometric',
      () async {
        final cubit = PinCubit(_FakePinRepo());
        await cubit.setup(
          type: PinType.date,
          secret: '',
          scopes: {PinScope.app, PinScope.settings},
          verifiedEmail: 'user@example.com',
          biometricEnabled: true,
        );

        await cubit.resetSecretAfterRecovery('4321');

        expect(cubit.state.type, PinType.custom);
        expect(cubit.state.secret, '4321');
        expect(cubit.state.retryCount, 0);
        expect(cubit.state.isLockedOut, isFalse);
        expect(cubit.state.scopes, {PinScope.app, PinScope.settings});
        expect(cubit.state.verifiedEmail, 'user@example.com');
        expect(cubit.state.biometricEnabled, isTrue);
      },
    );
  });

  group('requirePin short-circuit', () {
    testWidgets('returns true when no PIN is configured', (tester) async {
      final cubit = PinCubit(_FakePinRepo());
      late bool result;
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await requirePin(context, PinScope.settings),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(result, isTrue);
    });

    testWidgets('returns true when the scope is not guarded', (tester) async {
      final cubit = PinCubit(_FakePinRepo());
      await cubit.setup(
        type: PinType.custom,
        secret: '1234',
        scopes: {PinScope.app}, // guards launch only, not settings
      );
      late bool result;
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await requirePin(context, PinScope.settings),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(result, isTrue);
    });

    testWidgets('returns true when appLocker is configured but not guarded', (
      tester,
    ) async {
      final cubit = PinCubit(_FakePinRepo());
      await cubit.setup(
        type: PinType.custom,
        secret: '1234',
        scopes: {PinScope.app}, // does not guard the app locker
      );
      late bool result;
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await requirePin(context, PinScope.appLocker),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(result, isTrue);
    });
  });

  group('requirePin gating', () {
    testWidgets('shows the lock screen when appLocker is guarded', (
      tester,
    ) async {
      final cubit = PinCubit(_FakePinRepo());
      await cubit.setup(
        type: PinType.custom,
        secret: '1234',
        scopes: {PinScope.appLocker},
      );
      // The gate pushes onto the root navigator, so PinCubit must sit above
      // MaterialApp (as it does in main.dart) for the lock screen to find it.
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                // Fire-and-forget: the future resolves only once the user
                // unlocks/cancels, so we just assert the gate is shown.
                onPressed: () => requirePin(context, PinScope.appLocker),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump(); // begin pushing the lock-screen route
      // GlassScaffold runs an infinite ambient animation, so settle by a fixed
      // duration rather than pumpAndSettle (which would never converge).
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Confirm to manage locked apps'), findsOneWidget);
    });
  });

  group('PinCubit lockout ladder', () {
    test('locks out only after exceeding the 5 free attempts', () async {
      final cubit = PinCubit(_FakePinRepo());
      await cubit.setup(
        type: PinType.custom,
        secret: '1234',
        scopes: {PinScope.app},
      );

      for (var i = 0; i < 5; i++) {
        expect(await cubit.verify('0000'), isFalse);
      }
      expect(cubit.state.isLockedOut, isFalse); // 5 attempts: no lockout yet

      expect(await cubit.verify('0000'), isFalse); // 6th failure
      expect(cubit.state.isLockedOut, isTrue);
      expect(cubit.state.lockedUntil, isNotNull);

      // While locked out, even the correct PIN is refused.
      expect(await cubit.verify('1234'), isFalse);
    });
  });
}
