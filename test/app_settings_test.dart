import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings.backgroundId', () {
    test('defaults to aurora', () {
      expect(const AppSettings().backgroundId, AppBackground.aurora);
    });

    test('copyWith + toJson serialize the wire token', () {
      final settings = const AppSettings().copyWith(backgroundId: AppBackground.bg1);
      expect(settings.backgroundId, AppBackground.bg1);
      expect(settings.toJson()['backgroundId'], 'BG1');
    });

    test('fromJson reads the wire token', () {
      final settings = AppSettings.fromJson(const {'backgroundId': 'BG3'});
      expect(settings.backgroundId, AppBackground.bg3);
    });

    test('fromJson defaults to aurora when the key is missing (back-compat)', () {
      final settings = AppSettings.fromJson(const <String, dynamic>{});
      expect(settings.backgroundId, AppBackground.aurora);
    });

    test('survives a full JSON round-trip', () {
      final original = const AppSettings().copyWith(backgroundId: AppBackground.bg3);
      final restored = AppSettings.fromJson(original.toJson());
      expect(restored.backgroundId, AppBackground.bg3);
      expect(restored, original);
    });
  });
}
