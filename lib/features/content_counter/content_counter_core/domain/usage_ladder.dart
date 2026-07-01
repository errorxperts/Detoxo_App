/// The single source of truth for the counter's usage-reactive visuals.
///
/// Both the color band (green→brown) and the emoji ladder step once per 50
/// reels and cap at [kUsageCap]. The native side keeps a byte-identical copy in
/// `android/.../engine/UsageLadder.kt`; the two MUST stay in sync (the bubble,
/// the home widget, and the in-app previews all render from this so they look
/// identical at the same count). `test/usage_ladder_test.dart` pins the stops.
library;

import 'package:flutter/painting.dart' show Color;

/// Highest count the ladders resolve; beyond this the darkest stop holds.
const int kUsageCap = 500;

/// 11 ARGB stops, one per 50 reels (0, 50, …, 500), success-green → darkest
/// brown-red. Kept in sync with `UsageLadder.BAND` on the native side.
const List<int> kBandStopsArgb = <int>[
  0xFF30A46C, // 0    success green
  0xFF56B450, // 50   light green
  0xFF8FC33A, // 100  yellow-green
  0xFFC7C21F, // 150  chartreuse
  0xFFF5A623, // 200  amber
  0xFFF07C1E, // 250  orange
  0xFFE5484D, // 300  red
  0xFFC63A3E, // 350  deep red
  0xFF9E2B2E, // 400  darker red
  0xFF742021, // 450  maroon
  0xFF4A1A14, // 500+ darkest brown
];

/// 11 emoji, one per 50 reels: content → distressed. Kept in sync with
/// `UsageLadder.EMOJI` on the native side.
const List<String> kEmojiLadder = <String>[
  '😄',
  '🙂',
  '😌',
  '😐',
  '😕',
  '😟',
  '😣',
  '😖',
  '😫',
  '😵',
  '💀',
];

/// Ladder index for [count] — `(count clamped to [0, kUsageCap]) ~/ 50`, giving
/// 0..10. Shared by both ladders and mirrored exactly on the native side.
int bandIndexFor(int count) => count.clamp(0, kUsageCap) ~/ 50;

/// The usage band color for [count].
Color bandColorFor(int count) => Color(kBandStopsArgb[bandIndexFor(count)]);

/// The usage mood emoji for [count].
String emojiFor(int count) => kEmojiLadder[bandIndexFor(count)];
