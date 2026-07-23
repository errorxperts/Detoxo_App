import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings background', () {
    test('defaults: dark1 for dark, aurora for light', () {
      expect(const AppSettings().darkBackground, AppBackground.dark1);
      expect(const AppSettings().lightBackground, AppBackground.aurora);
    });

    test('copyWith + toJson serialize both wire tokens', () {
      final settings = const AppSettings().copyWith(
        darkBackground: AppBackground.dark3,
        lightBackground: AppBackground.light2,
      );
      expect(settings.darkBackground, AppBackground.dark3);
      expect(settings.lightBackground, AppBackground.light2);
      expect(settings.toJson()['darkBackground'], 'DARK3');
      expect(settings.toJson()['lightBackground'], 'LIGHT2');
    });

    test('fromJson reads the wire tokens', () {
      final settings = AppSettings.fromJson(
        const {'darkBackground': 'DARK5', 'lightBackground': 'LIGHT4'},
      );
      expect(settings.darkBackground, AppBackground.dark5);
      expect(settings.lightBackground, AppBackground.light4);
    });

    test('fromJson defaults when keys are missing (back-compat)', () {
      final settings = AppSettings.fromJson(const <String, dynamic>{});
      expect(settings.darkBackground, AppBackground.dark1);
      expect(settings.lightBackground, AppBackground.aurora);
    });

    test('survives a full JSON round-trip', () {
      final original = const AppSettings().copyWith(
        darkBackground: AppBackground.dark6,
        lightBackground: AppBackground.light5,
      );
      final restored = AppSettings.fromJson(original.toJson());
      expect(restored.darkBackground, AppBackground.dark6);
      expect(restored.lightBackground, AppBackground.light5);
      expect(restored, original);
    });
  });
}
