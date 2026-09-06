/// 13×13 starting-hand grid utilities — ported from the desktop
/// `src/engine/notation.ts`.
///
/// Convention: rows/cols indexed by [kRanksDesc] (A=0 .. 2=12).
///   r == c           -> pair        ("AA")
///   c  > r (upper)   -> suited      ("AKs")
///   r  > c (lower)   -> offsuit     ("AKo")
library;

import 'types.dart';

enum ComboKind { pair, suited, offsuit }

/// A concrete two-card combo (desktop `[Card, Card]` tuple).
typedef Combo = (Card, Card);

HandLabel labelAt(int row, int col) {
  final hi = kRanksDesc[row < col ? row : col];
  final lo = kRanksDesc[row > col ? row : col];
  if (row == col) return '$hi$hi';
  if (col > row) return '$hi${lo}s';
  return '$hi${lo}o';
}

ComboKind kindOf(HandLabel label) {
  if (label.length == 2) return ComboKind.pair;
  return label.endsWith('s') ? ComboKind.suited : ComboKind.offsuit;
}

int comboCount(HandLabel label) {
  switch (kindOf(label)) {
    case ComboKind.pair:
      return 6;
    case ComboKind.suited:
      return 4;
    case ComboKind.offsuit:
      return 12;
  }
}

/// All 169 labels in grid order (row-major).
List<HandLabel> allLabels() {
  final out = <HandLabel>[];
  for (int r = 0; r < 13; r++) {
    for (int c = 0; c < 13; c++) {
      out.add(labelAt(r, c));
    }
  }
  return out;
}

/// Total number of two-card combos represented by a set of labels.
int combosInSet(Iterable<HandLabel> labels) {
  int n = 0;
  for (final l in labels) {
    n += comboCount(l);
  }
  return n;
}

/// C(52, 2).
const int kTotalCombos = 1326;

/// Expand a label into its concrete two-card combos, in the desktop order
/// (suits iterate c, d, h, s):
///   pair `XX`    -> [Xc,Xd],[Xc,Xh],[Xc,Xs],[Xd,Xh],[Xd,Xs],[Xh,Xs]
///   suited `XYs` -> [Xc,Yc],[Xd,Yd],[Xh,Yh],[Xs,Ys]
///   offsuit `XYo`-> for s1 in suits, for s2 in suits, s1 != s2 -> [Xs1, Ys2]
List<Combo> labelToCombos(HandLabel label) {
  final out = <Combo>[];
  final k = kindOf(label);
  final hi = label[0];
  if (k == ComboKind.pair) {
    for (int i = 0; i < kSuits.length; i++) {
      for (int j = i + 1; j < kSuits.length; j++) {
        out.add((hi + kSuits[i], hi + kSuits[j]));
      }
    }
    return out;
  }
  final lo = label[1];
  if (k == ComboKind.suited) {
    for (final s in kSuits) {
      out.add((hi + s, lo + s));
    }
  } else {
    for (final s1 in kSuits) {
      for (final s2 in kSuits) {
        if (s1 != s2) out.add((hi + s1, lo + s2));
      }
    }
  }
  return out;
}

/// Two concrete cards -> their grid label, e.g. ("As", "Kd") -> "AKo".
HandLabel cardsToLabel(Card a, Card b) {
  final ra = a[0];
  final rb = b[0];
  final ia = kRanksDesc.indexOf(ra);
  final ib = kRanksDesc.indexOf(rb);
  final hi = ia <= ib ? ra : rb;
  final lo = ia <= ib ? rb : ra;
  if (ra == rb) return '$hi$hi';
  final suited = a[1] == b[1];
  return '$hi$lo${suited ? 's' : 'o'}';
}

/// Human-friendly pretty label, e.g. "AKs" stays, "AA" stays.
String prettyLabel(HandLabel label) => label;
