/// Formatting helpers — poker players think in big blinds.
///
/// Ported 1:1 from the desktop app's `src/lib/format.ts`. These strings appear
/// verbatim in coach copy, so every function reproduces the JavaScript output
/// exactly (including `Math.round` half-toward-+∞ rounding, `toFixed`
/// tie-breaking and `toLocaleString` thousands grouping).
library;

/// JavaScript `Math.round`: nearest integer, ties toward +∞ (so `-2.5 → -2`,
/// `-0.4 → -0`). Dart's `round()` rounds ties away from zero, which differs
/// for negative halves — use this helper wherever the TypeScript rounds.
///
/// Returns a double so that `-0.0`, `NaN` and infinities survive exactly as
/// in JS; call [jsIntString] to print it.
double jsRound(double x) {
  if (!x.isFinite) return x;
  final f = x.floorToDouble();
  final r = (x - f >= 0.5) ? f + 1 : f;
  // Math.round(-0.4) is -0: keep the sign when a negative input rounds to zero.
  return (r == 0 && x < 0) ? -0.0 : r;
}

/// JavaScript `Number.prototype.toFixed` — identical to Dart's
/// `toStringAsFixed` except that JS never prints a negative sign for `-0`.
String jsToFixed(double x, int digits) {
  if (x == 0) return 0.0.toStringAsFixed(digits);
  return x.toStringAsFixed(digits);
}

/// JSON value for a number, encoded the way `JSON.stringify` would: an
/// integral double becomes an int, so `3.0` is written as `3` and not `3.0`.
/// Every persisted engine value goes through this, because the desktop app
/// must be able to read a mobile backup byte-for-byte the same way.
Object jsonNum(num v) {
  final d = v.toDouble();
  return d.isFinite && d == d.truncateToDouble() && d.abs() < 1e15
      ? d.toInt()
      : v;
}

/// JavaScript `String(n)` for an integer-valued double (`-0 → "0"`).
String jsIntString(double v) {
  if (!v.isFinite || v.abs() >= 1e21) return v.toString();
  return v.toInt().toString();
}

/// Chips as big blinds: at most one decimal, dropped when whole
/// (`fmtBb(30, 20) == "1.5"`, `fmtBb(40, 20) == "2"`).
String fmtBb(num chips, num bb) {
  final v = chips / bb;
  final rounded = jsRound(v * 10) / 10;
  final isInteger = rounded.isFinite && rounded == rounded.truncateToDouble();
  return isInteger ? jsIntString(rounded) : jsToFixed(rounded, 1);
}

/// Chip count with thousands separators (`fmtChips(2000) == "2,000"`).
String fmtChips(num n) {
  final v = jsRound(n.toDouble());
  if (!v.isFinite) return v.toString();
  // `(-0).toLocaleString()` is "-0" in JS, so keep the sign of negative zero.
  final negative = v.isNegative;
  final digits = v.abs().toInt().toString();
  final buf = StringBuffer();
  if (negative) buf.write('-');
  final first = digits.length % 3;
  if (first > 0) buf.write(digits.substring(0, first));
  for (var i = first; i < digits.length; i += 3) {
    if (i > 0) buf.write(',');
    buf.write(digits.substring(i, i + 3));
  }
  return buf.toString();
}

/// Signed number with a fixed number of decimals (`fmtSigned(1.25) == "+1.3"`).
String fmtSigned(num n, [int digits = 1]) {
  final scale = _pow10(digits);
  final v = jsRound(n * scale) / scale;
  return (v >= 0 ? '+' : '') + jsToFixed(v, digits);
}

/// Fraction as a percentage (`fmtPct(0.334) == "33%"`, `fmtPct(0.334, 1) == "33.4%"`).
String fmtPct(num frac, [int digits = 0]) {
  return '${jsToFixed(frac * 100.0, digits)}%';
}

/// Beginner-first frequency phrasing (per TONE.md): probabilities as
/// counts — "about 1 time in 4", "about 7 times in 10".
String fmtTimes(num p) {
  if (p >= 0.93) return 'almost every time';
  if (p <= 0.04) return 'almost never';
  if (p >= 0.45) {
    final n = jsRound(p * 10.0);
    return 'about ${jsIntString(n)} times in 10';
  }
  final n = jsRound(1 / p);
  return n <= 10
      ? 'about 1 time in ${jsIntString(n)}'
      : 'about 1 time in ${jsIntString(n)}';
}

/// "you need to win about 1 time in N" for a break-even fraction.
String fmtNeed(num potOdds) {
  if (potOdds <= 0) return 'any win rate';
  final n = 1 / potOdds;
  final rounded = jsRound(n * 2) / 2;
  final isInteger = rounded.isFinite && rounded == rounded.truncateToDouble();
  return 'about 1 time in ${isInteger ? jsIntString(rounded) : jsToFixed(rounded, 1)}';
}

double _pow10(int digits) {
  var s = 1.0;
  for (var i = 0; i < digits; i++) {
    s *= 10;
  }
  return s;
}
