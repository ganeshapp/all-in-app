/// Widget tests for the §10.1 foundations. Golden-free by design: they pump
/// every component in both themes at 360 / 390 / 430 pt and at 1.0× / 1.3×
/// text scale (§13), and assert the behaviours the spec is explicit about —
/// semantics labels, the 44 pt hit floor (§12), the disclosure row's inline
/// expand (§10.1) and the blocking sheet ignoring the scrim (§2.4).
library;

import 'package:allin/theme/app_theme.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _phone390 = Size(390, 844);

Future<void> pumpAllIn(
  WidgetTester tester,
  Widget child, {
  bool dark = true,
  double textScale = 1.0,
  Size size = _phone390,
}) async {
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
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(body: Center(child: child)),
            ),
      ),
    ),
  );
}

const Map<String, TermDefinition> _terms = {
  'BB': TermDefinition(
    id: 'BB',
    term: 'BB',
    definition:
        'Big Blind — posts the larger forced bet; last to act pre-flop. Also '
        'the unit we measure stacks and win-rate in.',
  ),
};

void main() {
  group('renders in both themes at every supported width and text scale', () {
    final sizes = <Size>[
      const Size(360, 780),
      const Size(390, 844),
      const Size(430, 932),
    ];

    Widget gallery() => SingleChildScrollView(
      child: Column(
        children: [
          const Eyebrow('next up'),
          const AllInButton.primary(label: 'Deal me in'),
          AllInButton.secondary(
            label: 'Resume',
            size: AllInButtonSize.sm,
            onPressed: () {},
          ),
          AllInButton.outline(
            label: 'Show me why',
            size: AllInButtonSize.lg,
            trailing: Icons.chevron_right,
            onPressed: () {},
          ),
          AllInButton.ghost(label: 'Skip', onPressed: () {}),
          AllInButton.danger(label: 'Erase everything', onPressed: () {}),
          AllInButton.primary(
            label: 'Calculating…',
            busy: true,
            onPressed: () {},
          ),
          AllInSegmented(
            labels: const ['Cash', 'Push/Fold', 'ICM', 'Exploits'],
            value: 1,
            onChanged: (_) {},
          ),
          AllInSwitch(value: true, onChanged: (_) {}),
          AllInSlider(value: 3, min: 0, max: 10, step: 0.5, onChanged: (_) {}),
          const AllInCard.plain(child: Text('Plain')),
          const AllInCard.glass(child: Text('Glass')),
          const AllInCard.gold(child: Text('Gold')),
          const AllInCard.info(child: Text('Info')),
          const StatTile(label: 'Net', value: '+4.5 bb', tone: StatTone.good),
          StatTile(
            label: 'bb / 100',
            value: '12.4',
            sub: 'over 412 hands',
            height: StatTile.heightLarge,
            onInfo: () {},
          ),
          const DisclosureRow(
            label: 'Show me the math',
            child: Text('You paid 8 bb to win 24 bb.'),
          ),
          const TermText('You are the {{BB}} this hand.', terms: _terms),
          const ProgressBarThin(value: 8, max: 20, height: 8),
          const AllInToast(text: 'Hand history copied'),
        ],
      ),
    );

    for (final size in sizes) {
      for (final dark in [true, false]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets(
            '${size.width.toInt()} · ${dark ? 'dark' : 'light'} · ${scale}x',
            (tester) async {
              await pumpAllIn(
                tester,
                gallery(),
                dark: dark,
                textScale: scale,
                size: size,
              );
              expect(tester.takeException(), isNull);
              expect(find.text('Deal me in'), findsOneWidget);
            },
          );
        }
      }
    }
  });

  group('semantics', () {
    testWidgets('controls expose labels and roles', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAllIn(
        tester,
        Column(
          children: [
            AllInButton.primary(label: 'Deal me in', onPressed: () {}),
            AllInSegmented(
              labels: const ['Cash', 'ICM'],
              value: 0,
              onChanged: (_) {},
            ),
            AllInSwitch(
              value: true,
              onChanged: (_) {},
              semanticLabel: 'Reduce motion',
            ),
            StatTile(label: 'Net', value: '+4.5 bb', onInfo: () {}),
            const DisclosureRow(label: 'Show me the math'),
            const ProgressBarThin(
              value: 8,
              max: 20,
              semanticLabel: 'Daily goal',
            ),
          ],
        ),
      );

      expect(find.bySemanticsLabel('Deal me in'), findsOneWidget);
      expect(find.bySemanticsLabel('Cash'), findsOneWidget);
      expect(find.bySemanticsLabel('Reduce motion'), findsOneWidget);
      expect(find.bySemanticsLabel('About Net'), findsOneWidget);
      expect(find.bySemanticsLabel('Net, +4.5 bb'), findsOneWidget);
      expect(find.bySemanticsLabel('Show me the math'), findsOneWidget);
      expect(find.bySemanticsLabel('Daily goal'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a disabled button reports enabled: false', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAllIn(
        tester,
        const AllInButton.primary(label: 'Erase everything'),
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel('Erase everything'),
      );
      expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
      handle.dispose();
    });
  });

  group('hit targets are at least 44 pt (§12)', () {
    testWidgets('every size of button', (tester) async {
      for (final size in AllInButtonSize.values) {
        await pumpAllIn(
          tester,
          AllInButton.primary(label: 'Go', size: size, onPressed: () {}),
        );
        final box = tester.getSize(find.byType(AllInButton));
        expect(box.height, greaterThanOrEqualTo(44));
        expect(box.width, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('segmented, switch and slider bands', (tester) async {
      await pumpAllIn(
        tester,
        Column(
          children: [
            AllInSegmented(
              labels: const ['A', 'B'],
              value: 0,
              onChanged: (_) {},
            ),
            AllInSwitch(value: false, onChanged: (_) {}),
            AllInSlider(value: 1, min: 0, max: 4, step: 1, onChanged: (_) {}),
          ],
        ),
      );
      expect(tester.getSize(find.byType(AllInSegmented)).height, 44);
      expect(tester.getSize(find.byType(AllInSwitch)).height, 44);
      expect(tester.getSize(find.byType(AllInSlider)).height, 44);
    });

    testWidgets('the disclosure row is 48 tall', (tester) async {
      await pumpAllIn(tester, const DisclosureRow(label: 'Expert detail'));
      expect(
        tester.getSize(find.text('Expert detail')).height,
        lessThan(DisclosureRow.rowHeight),
      );
      expect(
        tester.getSize(find.byType(DisclosureRow)).height,
        greaterThanOrEqualTo(DisclosureRow.rowHeight),
      );
    });

    testWidgets("StatTile's info control is a 44 pt square", (tester) async {
      await pumpAllIn(
        tester,
        SizedBox(
          width: 180,
          child: StatTile(label: 'Net', value: '+4.5 bb', onInfo: () {}),
        ),
      );
      final info = find.descendant(
        of: find.byType(StatTile),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 44 && w.height == 44,
        ),
      );
      expect(tester.getSize(info.first), const Size(44, 44));
    });
  });

  group('AllInButton', () {
    testWidgets('fires onPressed, and never while busy', (tester) async {
      var taps = 0;
      await pumpAllIn(
        tester,
        AllInButton.primary(label: 'Next hand', onPressed: () => taps++),
      );
      await tester.tap(find.byType(AllInButton));
      await tester.pump();
      expect(taps, 1);

      await pumpAllIn(
        tester,
        AllInButton.primary(
          label: 'Next hand',
          busy: true,
          onPressed: () => taps++,
        ),
      );
      await tester.tap(find.byType(AllInButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('busy shows a spinner, reduced motion shows none', (
      tester,
    ) async {
      await pumpAllIn(
        tester,
        AllInButton.primary(
          label: 'Calculating…',
          busy: true,
          onPressed: () {},
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pumpAllIn(
        tester,
        AllInButton.primary(
          label: 'Calculating…',
          busy: true,
          reducedMotion: true,
          onPressed: () {},
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Calculating…'), findsOneWidget);
    });
  });

  group('AllInSegmented', () {
    testWidgets('reports the tapped index once', (tester) async {
      final picked = <int>[];
      await pumpAllIn(
        tester,
        AllInSegmented(
          labels: const ['Cash', 'Push/Fold', 'ICM'],
          value: 0,
          onChanged: picked.add,
        ),
      );
      await tester.tap(find.text('ICM'));
      await tester.pump();
      await tester.tap(find.text('Cash'));
      await tester.pump();
      expect(picked, [2]); // tapping the active segment changes nothing
    });
  });

  group('AllInSlider', () {
    testWidgets('snaps to a detent', (tester) async {
      final values = <double>[];
      await pumpAllIn(
        tester,
        SizedBox(
          width: 300,
          child: AllInSlider(
            value: 0,
            min: 0,
            max: 10,
            step: 0.5,
            detents: const [2.5, 5, 7.5],
            onChanged: values.add,
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byType(AllInSlider)));
      await tester.pump();
      expect(values, isNotEmpty);
      expect(values.last % 0.5, 0);
    });
  });

  group('DisclosureRow', () {
    testWidgets('expands and collapses inline', (tester) async {
      final toggles = <bool>[];
      await pumpAllIn(
        tester,
        DisclosureRow(
          label: 'Show me the math',
          expandedLabel: 'Hide the math',
          onToggle: toggles.add,
          child: const Text('8 bb into 24 bb = 1 win in 4.'),
        ),
      );
      expect(find.text('8 bb into 24 bb = 1 win in 4.'), findsNothing);

      await tester.tap(find.text('Show me the math'));
      await tester.pumpAndSettle();
      expect(find.text('8 bb into 24 bb = 1 win in 4.'), findsOneWidget);
      expect(find.text('Hide the math'), findsOneWidget);

      await tester.tap(find.text('Hide the math'));
      await tester.pumpAndSettle();
      expect(find.text('8 bb into 24 bb = 1 win in 4.'), findsNothing);
      expect(toggles, [true, false]);
    });

    testWidgets('is always rendered, even with nothing behind it', (
      tester,
    ) async {
      await pumpAllIn(tester, const DisclosureRow(label: 'Expert detail'));
      expect(find.text('Expert detail'), findsOneWidget);

      await pumpAllIn(
        tester,
        const DisclosureRow(label: 'Expert detail', alwaysRendered: false),
      );
      expect(find.text('Expert detail'), findsNothing);
    });
  });

  group('TermText / TermPopover', () {
    testWidgets('a term opens an anchored definition and tap-outside closes', (
      tester,
    ) async {
      await pumpAllIn(
        tester,
        const SizedBox(
          width: 250,
          child: TermText(
            'You are the {{BB}} this hand, so you act last before the flop '
            'and first on every street after it.',
            terms: _terms,
          ),
        ),
      );
      expect(find.textContaining('Big Blind —'), findsNothing);

      await tester.tap(find.text('BB'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Big Blind —'), findsOneWidget);
      final card = tester.getSize(
        find
            .ancestor(
              of: find.textContaining('Big Blind —'),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(card.width, lessThanOrEqualTo(280));
      expect(card.height, lessThanOrEqualTo(180));

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.textContaining('Big Blind —'), findsNothing);
    });

    testWidgets('HitSlop lifts a small target to 44 pt', (tester) async {
      // Inline terms sit inside a paragraph, so their slop only reaches where
      // no glyph does (§6.3's "line-height slop"); the mechanism itself is
      // tested here, on the widget every small control can wrap itself in.
      var taps = 0;
      await pumpAllIn(
        tester,
        SizedBox(
          width: 200,
          height: 200,
          child: Center(
            child: HitSlop(
              minSize: const Size(44, 44),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox(width: 20, height: 18),
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(HitSlop));
      await tester.tapAt(center + const Offset(0, 14));
      await tester.pump();
      expect(taps, 1);

      await tester.tapAt(center + const Offset(0, 40));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('an unknown key renders as plain text', (tester) async {
      await pumpAllIn(
        tester,
        const SizedBox(
          width: 250,
          child: TermText('A {{nope|mystery}} term.', terms: _terms),
        ),
      );
      expect(find.text('mystery'), findsNothing);
      expect(find.textContaining('A mystery term.'), findsOneWidget);
    });
  });

  group('AllInSheet', () {
    Widget opener({
      required bool blocking,
      AllInSheetDetent detent = AllInSheetDetent.m,
      double maxHeightFraction = 1,
    }) => Builder(
      builder:
          (context) => AllInButton.primary(
            label: 'Open',
            onPressed:
                () => AllInSheet.show<void>(
                  context,
                  detent: detent,
                  blocking: blocking,
                  maxHeightFraction: maxHeightFraction,
                  child: const SizedBox(
                    height: 400,
                    child: Center(child: Text('Sheet body')),
                  ),
                ),
          ),
    );

    testWidgets('a normal sheet closes on a scrim tap', (tester) async {
      await pumpAllIn(tester, opener(blocking: false));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body'), findsOneWidget);

      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body'), findsNothing);
    });

    testWidgets('a blocking sheet ignores the scrim and has no grabber', (
      tester,
    ) async {
      await pumpAllIn(tester, opener(blocking: true));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body'), findsOneWidget);
      expect(find.bySemanticsLabel('Drag handle'), findsNothing);

      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body'), findsOneWidget);
    });

    testWidgets('reports onClose exactly once when it is dismissed', (
      tester,
    ) async {
      var closes = 0;
      await pumpAllIn(
        tester,
        Builder(
          builder:
              (context) => AllInButton.primary(
                label: 'Open',
                onPressed:
                    () => AllInSheet.show<void>(
                      context,
                      onClose: () => closes++,
                      child: const SizedBox(
                        height: 200,
                        child: Text('Sheet body'),
                      ),
                    ),
              ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(closes, 1);
    });

    testWidgets('opens instantly under reduced motion', (tester) async {
      await pumpAllIn(
        tester,
        Builder(
          builder:
              (context) => AllInButton.primary(
                label: 'Open',
                onPressed:
                    () => AllInSheet.show<void>(
                      context,
                      reducedMotion: true,
                      child: const SizedBox(
                        height: 200,
                        child: Text('Sheet body'),
                      ),
                    ),
              ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Sheet body'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('the table cap clamps every detent, L included', (
      tester,
    ) async {
      await pumpAllIn(
        tester,
        opener(
          blocking: false,
          detent: AllInSheetDetent.l,
          maxHeightFraction: 0.5,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final height = tester.getSize(find.byType(AllInSheet)).height;
      expect(height, lessThanOrEqualTo(844 * 0.5 + 1));
    });

    testWidgets('detent S hugs its content under the 40 % cap', (tester) async {
      await pumpAllIn(
        tester,
        Builder(
          builder:
              (context) => AllInButton.primary(
                label: 'Open',
                onPressed:
                    () => AllInSheet.show<void>(
                      context,
                      detent: AllInSheetDetent.s,
                      child: const SizedBox(height: 80, child: Text('Short')),
                    ),
              ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final height = tester.getSize(find.byType(AllInSheet)).height;
      expect(height, lessThan(844 * AllInSheet.sFraction));
    });
  });

  group('AllInDialog', () {
    testWidgets('typed confirmation stays disabled until the word matches', (
      tester,
    ) async {
      var erased = false;
      await pumpAllIn(
        tester,
        Builder(
          builder:
              (context) => AllInButton.danger(
                label: 'Reset all progress',
                onPressed:
                    () => AllInDialog.show<bool>(
                      context,
                      dialog: AllInDialog.typed(
                        title: 'Reset all progress?',
                        body:
                            'This permanently deletes your lifetime stats, '
                            'decisions, reads, and saved hands.',
                        confirmWord: 'RESET',
                        confirmLabel: 'Erase everything',
                        onConfirm: () => erased = true,
                      ),
                    ),
              ),
        ),
      );
      await tester.tap(find.text('Reset all progress'));
      await tester.pumpAndSettle();
      expect(find.text('Type RESET to confirm:'), findsOneWidget);

      await tester.tap(find.text('Erase everything'));
      await tester.pumpAndSettle();
      expect(erased, isFalse);
      expect(find.text('Erase everything'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'reset');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erase everything'));
      await tester.pumpAndSettle();
      expect(erased, isFalse);

      await tester.enterText(find.byType(EditableText), 'RESET');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erase everything'));
      await tester.pumpAndSettle();
      expect(erased, isTrue);
      expect(find.text('Erase everything'), findsNothing);
    });

    testWidgets('renders the Cupertino alert on iOS', (tester) async {
      tester.view.physicalSize = _phone390;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AllInAppTheme.dark().copyWith(platform: TargetPlatform.iOS),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: AllInButton.primary(
                      label: 'Reset',
                      onPressed:
                          () => AllInDialog.show<bool>(
                            context,
                            dialog: const AllInDialog.typed(
                              title: 'Reset all progress?',
                              confirmWord: 'RESET',
                              confirmLabel: 'Erase everything',
                            ),
                          ),
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('Type RESET to confirm:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('plain dialogs run their actions', (tester) async {
      var left = false;
      await pumpAllIn(
        tester,
        Builder(
          builder:
              (context) => AllInButton.primary(
                label: 'Leave',
                onPressed:
                    () => AllInDialog.show<void>(
                      context,
                      dialog: AllInDialog(
                        title: 'Start a new session?',
                        body: 'Your paused table will be replaced.',
                        actions: [
                          const AllInDialogAction(label: 'Cancel'),
                          AllInDialogAction(
                            label: 'Start new',
                            isDestructive: true,
                            onPressed: () => left = true,
                          ),
                        ],
                      ),
                    ),
              ),
        ),
      );
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Start a new session?'), findsOneWidget);
      await tester.tap(find.text('Start new'));
      await tester.pumpAndSettle();
      expect(left, isTrue);
    });
  });

  group('AllInToast', () {
    testWidgets('shows for 2.5 s then removes itself', (tester) async {
      await pumpAllIn(
        tester,
        Builder(
          builder:
              (context) => AllInButton.primary(
                label: 'Copy',
                onPressed:
                    () => AllInToast.show(context, 'Hand history copied'),
              ),
        ),
      );
      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Hand history copied'), findsOneWidget);

      await tester.pump(AllInToast.duration);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Hand history copied'), findsNothing);
    });
  });

  group('AllInScaffold', () {
    testWidgets('renders title, subtitle, actions and the pinned bottom slot', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = _phone390;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AllInAppTheme.dark(),
          home: AllInScaffold(
            title: 'Good evening',
            subtitle: 'Wednesday · 4 days in a row',
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
              ),
            ],
            bottom: AllInButton.primary(
              label: 'Deal me in',
              expand: true,
              onPressed: () {},
            ),
            body: const Center(child: Text('Body')),
          ),
        ),
      );
      expect(find.text('Good evening'), findsOneWidget);
      expect(find.text('Wednesday · 4 days in a row'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Deal me in'), findsOneWidget);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });
}
