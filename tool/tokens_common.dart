// Helpers shared by the token generators (tool/home_widget/gen_tokens.dart and
// tool/design/gen_design_tokens.dart): CSS colour parsing, name casing, Dart
// formatting and the write / `--check` loop. Keep them pure: both generators'
// outputs must stay byte-identical when this file changes.
import 'dart:io';

final _hex = RegExp(r'^#([0-9a-fA-F]{6})$');
final _rgba = RegExp(
  r'^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)$',
);

/// `#rrggbb` or `rgba(r,g,b,a)` as an ARGB int; alpha is `round(a * 255)`,
/// half up — CSS's rule.
int parseCssColour(String v, String name) {
  final hex = _hex.firstMatch(v);
  if (hex != null) return 0xFF000000 | int.parse(hex.group(1)!, radix: 16);
  final rgba = _rgba.firstMatch(v);
  if (rgba != null) {
    int ch(int i) => int.parse(rgba.group(i)!).clamp(0, 255);
    final a = (double.parse(rgba.group(4)!) * 255 + 0.5).floor().clamp(0, 255);
    return (a << 24) | (ch(1) << 16) | (ch(2) << 8) | ch(3);
  }
  throw FormatException('$name: unsupported colour "$v"');
}

String hex8(int argb) =>
    '0x${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';

String upperSnake(String kebab) => kebab.replaceAll('-', '_').toUpperCase();

String lowerCamel(String kebab) {
  final parts = kebab.split('-');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

String? readFile(String path) {
  final f = File(path);
  return f.existsSync() ? f.readAsStringSync() : null;
}

/// `dart format` the generated Dart so the precommit `fmt` step (which formats
/// all of lib/) never rewrites it — otherwise `--check` would see drift.
Future<String> formatDart(String source) async {
  final dir = Directory.systemTemp.createTempSync('tokens');
  try {
    final file = File('${dir.path}/generated.g.dart')
      ..writeAsStringSync(source);
    final result = await Process.run('dart', ['format', file.path]);
    if (result.exitCode != 0) {
      stderr.writeln(result.stderr);
      exit(result.exitCode);
    }
    return file.readAsStringSync();
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Writes every `(path, text)` output, or with [check] exits 1 when any file
/// on disk differs from what the generator would write (CI / precommit).
/// [source] names the token JSON in the drift message; [regen] is the command
/// that rewrites the outputs.
void syncOutputs(
  List<(String, String)> outputs, {
  required bool check,
  required String label,
  required String source,
  required String regen,
}) {
  if (check) {
    final drift = <String>[
      for (final (path, text) in outputs)
        if (readFile(path) != text) path,
    ];
    if (drift.isEmpty) {
      stdout.writeln('$label: up to date');
      return;
    }
    stderr.writeln(
      '$label drifted from $source:\n  ${drift.join('\n  ')}\n'
      'Run `$regen` and commit the result.',
    );
    exit(1);
  }
  for (final (path, text) in outputs) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
    stdout.writeln('wrote $path');
  }
}
