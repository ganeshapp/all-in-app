/// A truncation sweep over every routed screen, at every size and text scale
/// DESIGN.md §4.2.3 / §13 support, in both themes.
///
/// §13's rule is that the layout adapts and the content does not shrink: a
/// label may wrap, a gloss may take a third line, a segmented row may fit its
/// type down to a floor — but nothing on screen ends in an ellipsis it was not
/// designed to end in. This test walks the app and fails on any `Text` whose
/// paragraph exceeded its `maxLines`, which is what an ellipsis *is*.
///
/// Everything it caught the first time it ran: "Heads-…" in the lobby's Table
/// row, "Range explo…" and "How often one hand beats anot…" in S0's tools
/// grid, "Quick reference & glo…", the lesson rows at 1.3×, "Std…" in the
/// coach's Strictness row, and "Equity c…" in S3's header.
///
/// Anything genuinely allowed to truncate belongs in [_allowed], with the
/// reason it is allowed.
library;

import 'package:allin/app/routes.dart';
import 'package:allin/engine/coach.dart';
import 'package:allin/engine/types.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/widgets/coach/coach_note_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/play/harness.dart';

/// §4.2.3's two columns, the widest phone, and the 1.3× cap of §13.
const Map<String, (Size, double)> _configs = <String, (Size, double)>{
  '360@1.0': (Size(360, 780), 1.0),
  '360@1.3': (Size(360, 780), 1.3),
  '411@1.3': (Size(411, 914), 1.3),
  '430@1.0': (Size(430, 932), 1.0),
};

/// Strings that are allowed to end in an ellipsis.
bool _allowed(String text) =>
// §5.1: D0's source pill is deliberately short-formed, and the full
// label plus its explainer are one tap away in the sheet.
const <String>{
  'Pre-flop chart · 100bb baseline',
  'Post-flop heuristic · fundamentals',
  'Push/Fold · computed Nash',
  'Push/Fold · ICM bubble',
  'Exploit · vs a known type',
  'Your flagged spot',
}.contains(text);

/// Every `Text` on screen that had to ellipsise, re-measured at the width its
/// paragraph actually got.
///
/// `RenderParagraph.didExceedMaxLines` alone is not enough: it reports the
/// last layout the paragraph was asked for, which for anything measured for
/// intrinsics is not the one that was painted.
List<String> truncatedText(WidgetTester tester) {
  final out = <String>{};

  bool clipped(RenderParagraph node) {
    var widgetSpan = false;
    node.text.visitChildren((span) {
      if (span is WidgetSpan) widgetSpan = true;
      return true;
    });
    // A `WidgetSpan` cannot be laid out outside its own render object.
    if (widgetSpan) return node.didExceedMaxLines;

    final painter = TextPainter(
      text: node.text,
      textDirection: node.textDirection,
      textAlign: node.textAlign,
      maxLines: node.maxLines,
      textScaler: node.textScaler,
      locale: node.locale,
      strutStyle: node.strutStyle,
      textWidthBasis: node.textWidthBasis,
    )..layout(maxWidth: node.size.width);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }

  void visit(RenderObject node) {
    if (node is RenderParagraph &&
        !node.debugNeedsLayout &&
        node.size.width > 0 &&
        clipped(node)) {
      final text = node.text.toPlainText();
      if (!_allowed(text)) {
        out.add(
          '"${text.length > 60 ? '${text.substring(0, 60)}…' : text}" '
          'in ${node.size.width.toStringAsFixed(1)} pt',
        );
      }
    }
    node.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return out.toList();
}

/// A blocking mistake with everything the note can show — the layer-2 steps,
/// the layer-3 bullets, an equity bar and the multiway callout.
CoachReview blockingReview() => const CoachReview(
  id: 1,
  kind: ReviewKind.decision,
  blocking: true,
  verdict: Verdict.mistake,
  title: 'Your call',
  villainName: 'Negreanu',
  villainArchetype: Archetype.station,
  villainRange: ['QQ', 'AKs', 'KTo'],
  board: ['Ks', '6h', 'Ts', '3h', '2c'],
  opponents: 2,
  multiway: true,
  equity: 0.17,
  potOdds: 0.34,
  evChips: -260,
  plain:
      'You paid 8.3 bb to win a pot of 24.1 bb — you need to win about 1 time '
      'in 3. Your hand wins about 1 time in 6 — not enough. Over time this '
      'call loses money; folding is better.',
  text:
      'Against a Calling Station your queen-jack offsuit has only 17% equity, '
      'but calling needs 34%. This call costs about -3.5 bb — folding is '
      'better.',
  steps: [
    'QJo vs the 2-player field on Ks 6h Ts 3h 2c → 17% equity.',
    'Pot 316 + your call 166 = 482; pot odds = 166/482 = 34%.',
    'EV(call) = 17% × 482 − 166 ≈ −84 chips (−4.2 bb). EV(fold) = 0.',
    'Because EV < 0, folding beats calling.',
  ],
  expert: [
    '17% equity vs the 2-player field, needing 34% — a clear fold.',
    'Equity is run against 2 opponents as random hands (1600-trial sim).',
    'Simulation precision: ±2.5% on the equity (1,600 trials).',
    "Baseline: verdicts grade vs THIS opponent's likely hands "
        '(exploitative).',
  ],
);

void main() {
  const routes = <String, String>{
    'Home': AllInRoutes.todayPath,
    'Play lobby': AllInRoutes.lobbyPath,
    'Drills': AllInRoutes.drillsPath,
    'Study': AllInRoutes.studyPath,
    'Stats': AllInRoutes.progressPath,
    'Settings': AllInRoutes.settingsPath,
    'About': AllInRoutes.aboutPath,
    'Quick reference': '/study/glossary',
    'All hands': '/stats/hands',
    'Table': AllInRoutes.tablePath,
    'Session summary': AllInRoutes.summaryTablePath,
    'Guess range': '/table/read/1',
    'Lesson with a matrix': '/study/lesson/opening-ranges',
    'Lesson with a calculator': '/study/lesson/pot-odds',
    'Tool screen': '/study/tools/equity',
  };

  for (final config in _configs.entries) {
    final size = config.value.$1;
    final scale = config.value.$2;

    for (final dark in const [true, false]) {
      final theme = dark ? 'dark' : 'light';

      for (final route in routes.entries) {
        testWidgets('${route.key} · ${config.key} · $theme', (tester) async {
          final container = makeContainer(coachEnabled: true);
          addTearDown(container.dispose);
          container
              .read(sessionProvider.notifier)
              .newSession(const TableOptions(seats: 6));
          await settleWidgets(tester);

          await pumpApp(
            tester,
            container: container,
            location: route.value,
            size: size,
            textScale: scale,
            dark: dark,
          );

          expect(tester.takeException(), isNull);
          expect(
            truncatedText(tester),
            isEmpty,
            reason: '${route.key} truncates at ${config.key} $theme',
          );
        });
      }

      testWidgets('Coach note, both rows open · ${config.key} · $theme', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AllInAppTheme.dark() : AllInAppTheme.light(),
            home: Builder(
              builder:
                  (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: CoachNoteView(review: blockingReview()),
                      ),
                    ),
                  ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(CoachCopy.showMath));
        await tester.pumpAndSettle();
        await tester.tap(find.text(CoachCopy.expertDetail));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          truncatedText(tester),
          isEmpty,
          reason: 'the coach note truncates at ${config.key} $theme',
        );
      });
    }
  }
}
