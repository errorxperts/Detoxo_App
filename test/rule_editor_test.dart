import 'package:detoxo/features/catalog/catalog.dart';
import 'package:detoxo/features/limits/rules/presentation/rule_editor_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rule editor's pure parts: the category rail's icon map and the
/// "All distracting" quick-pick rule. The screen itself needs the app-wide
/// cubits and a device; these do not.
void main() {
  test('every seed category has an icon on the rail', () {
    // A category added to the seed without a glyph would render as the one
    // bare chip in the rail — the same drift guard the adult list has.
    for (final c in AppCategorySeed.categories) {
      expect(RuleEditorScreen.categoryIcons[c.id], isNotNull, reason: c.id);
    }
  });

  test('the catalog names the distracting categories in seed order', () {
    expect(Catalog.bundled.categoriesWithBehavior(AppBehavior.distracting), [
      'short_form_video',
      'social',
      'video_streaming',
      'games',
    ]);
  });

  test('toggleAll adds the missing ids, then clears exactly those', () {
    const all = ['a', 'b'];
    expect(RuleEditorScreen.toggleAll(const [], all), all);
    expect(RuleEditorScreen.toggleAll(const ['b', 'z'], all), ['b', 'z', 'a']);
    // Every id present → the tap clears them, and only them.
    expect(RuleEditorScreen.toggleAll(const ['a', 'z', 'b'], all), ['z']);
    expect(RuleEditorScreen.toggleAll(all, all), isEmpty);
  });
}
