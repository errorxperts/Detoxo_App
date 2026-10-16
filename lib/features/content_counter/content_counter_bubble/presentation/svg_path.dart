import 'dart:ui';

final _tokenPattern = RegExp(r'[MmLlHhVvQqCcZz]|-?\d*\.?\d+');

/// Parses an SVG path [d] string into a [Path] in board units.
///
/// Supported grammar: commands `M m L l H h V v Q q C c Z z`; numbers are
/// separated by whitespace or commas, and a `-` glued to a previous number
/// starts a new one (`q0 8-8 8`). A command repeats while numbers remain, and
/// the implicit repeat after `M`/`m` is `L`/`l`. Relative commands are offset
/// from the current point, and `Z` closes the subpath and returns the current
/// point to its start. Any other letter throws a [FormatException]. The Kotlin
/// side (`overlay/bubble/SvgPath.kt`) implements the same grammar.
///
/// The caller translates and scales the result to the canvas.
Path parseSvgPath(String d) {
  final tokens = <Object>[];
  var pos = 0;
  for (final m in _tokenPattern.allMatches(d)) {
    _checkSeparators(d.substring(pos, m.start));
    pos = m.end;
    final t = m.group(0)!;
    tokens.add(RegExp('[A-Za-z]').hasMatch(t) ? t : double.parse(t));
  }
  _checkSeparators(d.substring(pos));

  final path = Path();
  var x = 0.0; // current point
  var y = 0.0;
  var startX = 0.0; // current subpath start
  var startY = 0.0;
  var i = 0;
  while (i < tokens.length) {
    final cmd = tokens[i];
    if (cmd is! String) {
      throw FormatException('SVG path must start with a command, got $cmd');
    }
    i++;
    final args = <double>[];
    while (i < tokens.length && tokens[i] is double) {
      args.add(tokens[i++] as double);
    }

    final rel = cmd == cmd.toLowerCase();
    final op = cmd.toUpperCase();
    if (op == 'Z') {
      if (args.isNotEmpty) {
        throw FormatException('SVG command "$cmd" takes no arguments');
      }
      path.close();
      x = startX;
      y = startY;
      continue;
    }
    final arity = switch (op) {
      'M' || 'L' => 2,
      'H' || 'V' => 1,
      'Q' => 4,
      'C' => 6,
      _ => throw FormatException('Unsupported SVG path command "$cmd"'),
    };
    if (args.isEmpty || args.length % arity != 0) {
      throw FormatException('Wrong number of arguments for SVG command "$cmd"');
    }

    var segOp = op;
    for (var k = 0; k < args.length; k += arity) {
      final ox = rel ? x : 0.0;
      final oy = rel ? y : 0.0;
      switch (segOp) {
        case 'M':
          x = args[k] + ox;
          y = args[k + 1] + oy;
          path.moveTo(x, y);
          startX = x;
          startY = y;
          segOp = 'L'; // implicit repeats after M are lineto
        case 'L':
          x = args[k] + ox;
          y = args[k + 1] + oy;
          path.lineTo(x, y);
        case 'H':
          x = args[k] + ox;
          path.lineTo(x, y);
        case 'V':
          y = args[k] + oy;
          path.lineTo(x, y);
        case 'Q':
          final cx = args[k] + ox;
          final cy = args[k + 1] + oy;
          x = args[k + 2] + ox;
          y = args[k + 3] + oy;
          path.quadraticBezierTo(cx, cy, x, y);
        case 'C':
          final c1x = args[k] + ox;
          final c1y = args[k + 1] + oy;
          final c2x = args[k + 2] + ox;
          final c2y = args[k + 3] + oy;
          x = args[k + 4] + ox;
          y = args[k + 5] + oy;
          path.cubicTo(c1x, c1y, c2x, c2y, x, y);
      }
    }
  }
  return path;
}

void _checkSeparators(String gap) {
  for (final ch in gap.split('')) {
    if (RegExp('[\\s,]').hasMatch(ch)) continue;
    if (RegExp('[A-Za-z]').hasMatch(ch)) {
      throw FormatException('Unsupported SVG path command "$ch"');
    }
    throw FormatException('Unexpected character "$ch" in SVG path');
  }
}
