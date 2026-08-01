import 'package:detoxo/features/access_protection/domain/entities/pin_config.dart';
import 'package:detoxo/features/access_protection/domain/pin_hasher.dart';
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

  group('PinHasher', () {
    test('verifies the right secret and rejects the wrong one', () {
      final salt = PinHasher.newSalt();
      final hash = PinHasher.hash(salt, '1234');
      expect(PinHasher.verify(salt, hash, '1234'), isTrue);
      expect(PinHasher.verify(salt, hash, '0000'), isFalse);
    });

    test('different salts produce different hashes for the same secret', () {
      final a = PinHasher.newSalt();
      final b = PinHasher.newSalt();
      expect(a, isNot(b));
      expect(PinHasher.hash(a, '1234'), isNot(PinHasher.hash(b, '1234')));
    });

    test('verify is false when salt or hash is empty', () {
      expect(PinHasher.verify('', 'x', '1234'), isFalse);
      expect(PinHasher.verify('salt', '', '1234'), isFalse);
    });
  });

  group('PinCubit custom verify', () {
    test('accepts the configured PIN and rejects others (hashed)', () async {
      final cubit = PinCubit(_FakePinRepo());
      await cubit.setup(
        type: PinType.custom,
        secret: '1357',
        scopes: {PinScope.app},
      );
      // Stored hashed, not in plaintext.
      expect(cubit.state.secretHash, isNotEmpty);
      expect(cubit.state.salt, isNotEmpty);
      expect(await cubit.verify('1357'), isTrue);
      expect(await cubit.verify('0000'), isFalse);
    });

    test('disable() clears the configured lock', () async {
      final cubit = PinCubit(_FakePinRepo());
      await cubit.setup(
        type: PinType.custom,
        secret: '1357',
        scopes: {PinScope.app},
      );
      await cubit.disable();
      expect(cubit.state.isConfigured, isFalse);
      expect(cubit.state.type, PinType.none);
      expect(cubit.state.secretHash, isEmpty);
    });
  });

  group('no recovery backdoor', () {
    // A build once shipped a hardcoded '000000' recovery code that unlocked any
    // PIN. Nothing but the real PIN may ever verify.
    test('the retired dev recovery code does not unlock', () async {
      final cubit = PinCubit(_FakePinRepo());
      await cubit.setup(
        type: PinType.custom,
        secret: '1357',
        scopes: {PinScope.app},
      );
      expect(await cubit.verify('000000'), isFalse);
      expect(await cubit.verify('1357'), isTrue);
    });

    test('a stored config carries no email or other identifier', () async {
      final cubit = PinCubit(_FakePinRepo());
      await cubit.setup(
        type: PinType.custom,
        secret: '1357',
        scopes: {PinScope.app},
      );
      expect(cubit.state.toJson().keys, isNot(contains('verifiedEmail')));
    });

    test('a legacy config with verifiedEmail still loads', () {
      // Older installs persisted the key; fromJson must ignore it, not throw.
      final config = PinConfig.fromJson(const {
        'type': 'CUSTOM',
        'secretHash': 'abc',
        'salt': 'def',
        'secretLength': 4,
        'scopes': ['APP'],
        'verifiedEmail': 'legacy@example.com',
        'retryCount': 0,
        'biometricEnabled': false,
      });
      expect(config.type, PinType.custom);
      expect(config.scopes, const {PinScope.app});
    });
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
