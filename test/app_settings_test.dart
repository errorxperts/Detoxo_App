import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings retired background keys', () {
    test('a stored blob with them loads, keeping every other field', () {
      final settings = AppSettings.fromJson(const {
        'themeMode': 'LIGHT',
        'onboarded': true,
        'reelAllowance': 3,
        'darkBackground': 'DARK3',
        'lightBackground': 'LIGHT2',
      });
      expect(settings.themeMode, AppThemeMode.light);
      expect(settings.onboarded, isTrue);
      expect(settings.reelAllowance, 3);
    });

    test('toJson writes neither key, and round-trips', () {
      const settings = AppSettings(themeMode: AppThemeMode.system);
      final json = settings.toJson();
      expect(json, isNot(contains('darkBackground')));
      expect(json, isNot(contains('lightBackground')));
      expect(AppSettings.fromJson(json), settings);
    });

    test('Dark stays the default theme', () {
      expect(const AppSettings().themeMode, AppThemeMode.dark);
      expect(AppSettings.fromJson(const {}).themeMode, AppThemeMode.dark);
    });
  });
}
