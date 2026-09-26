import 'package:detoxo/features/limits/rules/domain/entities/rule.dart';
import 'package:flutter/material.dart';

/// The glyph for a rule kind — shared by the list, the picker and the editor.
IconData ruleKindIcon(RuleKind k) => switch (k) {
  RuleKind.schedule => Icons.schedule,
  RuleKind.timeLimit => Icons.hourglass_bottom,
  RuleKind.openLimit => Icons.touch_app_outlined,
};
