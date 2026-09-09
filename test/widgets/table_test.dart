/// Widget tests for the §10.3 table components.
///
/// The felt tests pump a real six-max `TableState` at 360 / 390 / 430 and
/// assert the §4.2 invariants numerically: nothing overflows, plates never
/// overlap each other or the board, and the tucked hole cards clear the rail.
/// The rest pin the behaviours §4.5 is explicit about — the ActionRow's seven
/// states, the sizing rail's 0.5 bb quantisation and its detent magnets — plus
/// the seat plate's single-detector eye split (§4.3).
library;

import 'dart:io';
import 'dart:math';

import 'package:allin/engine/engine.dart';
import 'package:allin/theme/app_theme.dart';
import 'package:allin/theme/tokens.dart';
import 'package:allin/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bundled Inter, for the tests that measure a label's width.
Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final weight in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final file = File('assets/fonts/Inter-$weight.ttf');
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

const Size _phone390 = Size(390, 844);

Future<void> pumpTable(
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

/// A deterministic six-max hand: hero in the big blind facing a raise.
TableState sixMaxHand() {
  final rng = Random(7);
  final table = createTable(
    const GameConfig(
      seats: 6,
      startingStack: 2000,
      smallBlind: 10,
      bigBlind: 20,
    ),
    rng: rng,
  );
  return startHand(table, rng: rng);
}

/// §4.2.3's felt, plate, board and hole-card sizes per screen width.
class _FeltSpec {
  const _FeltSpec({
    required this.screen,
    required this.felt,
    required this.plate,
    required this.board,
    required this.holeCard,
  });

  final Size screen;
  final Size felt;
  final Size plate;
  final double board;
  final double holeCard;
}

const List<_FeltSpec> _specs = [
  _FeltSpec(
    screen: Size(360, 780),
    felt: Size(316, 466),
    plate: Size(96, 54),
    board: 40,
    holeCard: 28,
  ),
  _FeltSpec(
    screen: Size(390, 844),
    felt: Size(346, 479),
    plate: Size(104, 58),
    board: 44,
    holeCard: 30,
  ),
  _FeltSpec(
    screen: Size(430, 932),
    felt: Size(380, 548),
    plate: Size(112, 60),
    board: 50,
    holeCard: 34,
  ),
];

Widget _sixMaxFelt(TableState state, _FeltSpec spec) {
  return SizedBox(
    width: spec.felt.width,
    height: spec.felt.height,
    child: FeltCanvas(
      layout: FeltLayout.six,
      builder:
          (context, felt) => [
            for (final seat in felt.plateSeats)
              felt.place(
                felt.seatAnchor(seat),
                child: SeatPlate(
                  key: ValueKey('seat-$seat'),
                  player: state.players[seat],
                  plateSize: spec.plate,
                  holeCardWidth: spec.holeCard,
                  bigBlind: state.bigBlind,
                  mirrored: felt.seatAnchor(seat).dx < spec.felt.width / 2,
                  showEye: true,
                  onEye: () {},
                  onTap: () {},
                ),
              ),
            felt.place(
              felt.potAnchor,
              child: PotPill(
                key: const ValueKey('pot'),
                street: state.street,
                pot: state.pot,
                bigBlind: state.bigBlind,
              ),
            ),
            felt.place(
              felt.boardAnchor,
              child: BoardRow(
                key: const ValueKey('board'),
                cards: state.board,
                size: spec.board,
              ),
            ),
            for (final seat in felt.plateSeats)
              felt.place(
                felt.betAnchor(seat),
                child: BetPill(
                  key: ValueKey('bet-$seat'),
                  kind: BetPillKind.call,
                  amount: state.players[seat].committed,
                  bigBlind: state.bigBlind,
                ),
              ),
          ],
    ),
  );
}

void main() {
  // Several groups here assert what fits in a fixed width, and the action row
  // now *measures* its own labels to size its buttons (§4.5's exact commit is
  // never ellipsised). Those assertions only mean anything in the font the app
  // ships: the framework's 1-em-per-glyph fallback is ~15 % wider.
  setUpAll(_loadInter);

  group('the felt is a fixed dark material in both themes', () {
    // The felt is theme-invariant (`FeltCanvas` paints AllInColors.felt in
    // both themes), so everything that sits on it must read against dark
    // green. In Light, `context.colors` would flip seat plates to a near-white
    // box and every mono number on the felt to goldLight (#96701C — a dark
    // ochre on dark green). `FeltTheme` pins the dark palette for the whole
    // prop stack instead.
    testWidgets('felt props resolve AllInColors.dark under a light theme', (
      tester,
    ) async {
      AllInColors? inside;
      await pumpTable(
        tester,
        dark: false,
        SizedBox(
          width: 320,
          height: 220,
          child: FeltCanvas(
            builder:
                (context, felt) => [
                  felt.at(
                    0.5,
                    0.5,
                    child: Builder(
                      builder: (context) {
                        inside = context.colors;
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
          ),
        ),
      );
      expect(inside, isNotNull);
      expect(identical(inside, AllInColors.dark), isTrue);
      // Sanity: the page around the felt really is the light palette.
      expect(
        AllInAppTheme.light().extension<AllInTheme>()!.colors.ink800,
        AllInColors.light.ink800,
      );
    });

    testWidgets('the six-max plates and pills stay dark-palette in light', (
      tester,
    ) async {
      final state = sixMaxHand();
      await pumpTable(
        tester,
        dark: false,
        _sixMaxFelt(state, _specs.first),
        size: _specs.first.screen,
      );
      expect(tester.takeException(), isNull);

      // Every mono number painted on the felt uses the dark palette's
      // goldLight (#F4DD92), never the light theme's #96701C.
      final monos = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.style?.color == AllInColors.light.goldLight);
      expect(monos, isEmpty);

      // The plate background is the dark ink800, not the light near-white.
      final plateFills =
          tester
              .widgetList<Container>(
                find.descendant(
                  of: find.byKey(const ValueKey('seat-1')),
                  matching: find.byType(Container),
                ),
              )
              .map((c) => c.decoration)
              .whereType<BoxDecoration>()
              .map((d) => d.color)
              .toList();
      expect(
        plateFills,
        contains(AllInColors.dark.ink800.withValues(alpha: 0.92)),
      );
      expect(
        plateFills,
        isNot(contains(AllInColors.light.ink800.withValues(alpha: 0.92))),
      );
    });
  });

  group('FeltCanvas + SeatPlate + BoardRow geometry (§4.2)', () {
    for (final spec in _specs) {
      testWidgets('six-max felt lays out cleanly at ${spec.screen.width}', (
        tester,
      ) async {
        final state = sixMaxHand();
        await pumpTable(tester, _sixMaxFelt(state, spec), size: spec.screen);
        expect(tester.takeException(), isNull);

        final board = tester.getRect(find.byKey(const ValueKey('board')));
        final plates = <int, Rect>{
          for (final seat in [1, 2, 3, 4, 5])
            seat: tester.getRect(find.byKey(ValueKey('seat-$seat'))),
        };

        // No plate overlaps the board.
        for (final entry in plates.entries) {
          expect(
            entry.value.overlaps(board),
            isFalse,
            reason: 'seat ${entry.key} plate overlaps the board',
          );
        }
        // No plate overlaps another plate.
        for (final a in plates.entries) {
          for (final b in plates.entries) {
            if (a.key >= b.key) continue;
            expect(
              a.value.overlaps(b.value),
              isFalse,
              reason: 'seats ${a.key} and ${b.key} overlap',
            );
          }
        }
        // The pot pill clears the board too.
        final pot = tester.getRect(find.byKey(const ValueKey('pot')));
        expect(pot.overlaps(board), isFalse);
      });

      testWidgets('hole cards clear the rail at ${spec.screen.width}', (
        tester,
      ) async {
        final felt = FeltGeometry(
          size: spec.felt,
          layout: FeltLayout.six,
          railWidth: 10,
        );
        for (final seat in felt.plateSeats) {
          expect(
            felt.debugCardsClearRail(
              seat: seat,
              plateHeight: spec.plate.height,
              peek: SeatPlate.defaultPeek(SeatPlateVariant.standard),
            ),
            isTrue,
            reason: 'seat $seat peek reaches into the rail',
          );
        }
      });
    }

    // Regression: the felt is the table's one flexible band, and at 360 × 780
    // with the system insets and 1.3× text it came out 435.3 pt tall — 0.06 pt
    // short of what the top seat's anchor needs to keep its cards off the
    // rail. The raw assertion turned that into a red error box over the whole
    // table. The geometry now satisfies the invariant instead.
    test('a felt a hair too short nudges the seat instead of failing', () {
      const felt = FeltGeometry(
        // The exact size the device produced.
        size: Size(328, 435.26666666666665),
        layout: FeltLayout.six,
        railWidth: 10,
      );
      const plateHeight = 54.0;
      const peek = 24.0;

      // The raw anchor really is inside the rail…
      expect(
        felt.seatAnchor(3).dy - plateHeight / 2 - peek,
        lessThan(felt.railWidth),
      );
      // …the deficit is sub-point, so the check passes…
      final deficit = felt.railClearanceDeficit(
        seat: 3,
        plateHeight: plateHeight,
        peek: peek,
      );
      expect(deficit, greaterThan(0));
      expect(deficit, lessThan(1));
      expect(
        felt.debugCardsClearRail(seat: 3, plateHeight: plateHeight, peek: peek),
        isTrue,
      );
      // …and the anchor the felt actually places the seat at clears the rail.
      final cleared = felt.seatAnchorClearingRail(
        seat: 3,
        plateHeight: plateHeight,
        peek: peek,
      );
      expect(cleared.dx, felt.seatAnchor(3).dx);
      expect(
        cleared.dy - plateHeight / 2 - peek,
        greaterThanOrEqualTo(felt.railWidth),
      );

      // A felt short enough to move a seat past the tolerance is still a bug.
      const tiny = FeltGeometry(
        size: Size(328, 300),
        layout: FeltLayout.six,
        railWidth: 10,
      );
      expect(
        tiny.railClearanceDeficit(
          seat: 3,
          plateHeight: plateHeight,
          peek: peek,
        ),
        greaterThan(FeltGeometry.railClearanceTolerance),
      );
    });

    testWidgets('felt survives 1.15x text without overflowing', (tester) async {
      final state = sixMaxHand();
      await pumpTable(tester, _sixMaxFelt(state, _specs[1]), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('9-max anchors exist for all eight plates', (tester) async {
      const felt = FeltGeometry(
        size: Size(346, 479),
        layout: FeltLayout.nine,
        railWidth: 10,
      );
      expect(felt.plateSeats.length, 8);
      for (final seat in felt.plateSeats) {
        expect(
          felt.debugCardsClearRail(
            seat: seat,
            plateHeight:
                SeatPlate.defaultPlateSize(SeatPlateVariant.compact).height,
            peek: SeatPlate.defaultPeek(SeatPlateVariant.compact),
          ),
          isTrue,
        );
      }
    });
  });

  group('PlayingCardView (§10.3)', () {
    test('geometry is width-driven', () {
      expect(PlayingCardView.heightFor(22), 31);
      expect(PlayingCardView.heightFor(30), 42);
      expect(PlayingCardView.heightFor(44), 62);
      expect(PlayingCardView.heightFor(52), 73);
      expect(PlayingCardView.heightFor(72), 101);
      expect(PlayingCardView.heightFor(80), 112);
      expect(PlayingCardView.radiusFor(72), 9);
    });

    test('four-colour deck only moves diamonds and clubs', () {
      expect(PlayingCardView.suitColor('s'), PlayingCardView.suitColor('c'));
      expect(PlayingCardView.suitColor('h'), PlayingCardView.suitColor('d'));
      expect(
        PlayingCardView.suitColor('d', fourColorDeck: true),
        isNot(PlayingCardView.suitColor('h', fourColorDeck: true)),
      );
      expect(
        PlayingCardView.suitColor('c', fourColorDeck: true),
        isNot(PlayingCardView.suitColor('s', fourColorDeck: true)),
      );
    });

    testWidgets('renders 10 for a ten and hides the face when face-down', (
      tester,
    ) async {
      await pumpTable(
        tester,
        const PlayingCardView(card: 'Td', width: PlayingCardView.xl),
      );
      expect(find.text('10'), findsOneWidget);

      await pumpTable(
        tester,
        const PlayingCardView(
          card: 'Td',
          width: PlayingCardView.xl,
          faceDown: true,
        ),
      );
      expect(find.text('10'), findsNothing);
    });
  });

  group('SeatPlate (§4.3)', () {
    testWidgets('a folded plate dims its contents, not the plate', (
      tester,
    ) async {
      // Fading the whole widget took the plate's `ink800 @ 92 %` background to
      // ~51 % opaque, so the felt's radial highlight, inner hairline and seat
      // ring read straight through it — the plate stopped being an object.
      final state = sixMaxHand();
      final folded = Player(
        id: 1,
        name: state.players[1].name,
        isHero: false,
        stack: state.players[1].stack,
        archetype: state.players[1].archetype,
        hasFolded: true,
      );
      await pumpTable(
        tester,
        SeatPlate(
          key: const ValueKey('folded'),
          player: folded,
          plateSize: const Size(104, 58),
          holeCardWidth: 30,
          bigBlind: state.bigBlind,
          state: SeatPlateState.folded,
        ),
      );
      await tester.pumpAndSettle();

      final fills =
          tester
              .widgetList<Container>(
                find.descendant(
                  of: find.byKey(const ValueKey('folded')),
                  matching: find.byType(Container),
                ),
              )
              .map((w) => w.decoration)
              .whereType<BoxDecoration>()
              .map((d) => d.color)
              .toList();
      expect(fills, contains(AllInColors.dark.ink800.withValues(alpha: 0.92)));

      // The dimming `Opacity` is *inside* the plate's Container, never above
      // it, so the background keeps its own alpha.
      final opacityUnderPlate = find.descendant(
        of: find.descendant(
          of: find.byKey(const ValueKey('folded')),
          matching: find.byType(Container),
        ),
        matching: find.byType(AnimatedOpacity),
      );
      expect(opacityUnderPlate, findsWidgets);
    });

    testWidgets('the eye rect wins inside its quadrant, the plate elsewhere', (
      tester,
    ) async {
      final state = sixMaxHand();
      var eye = 0;
      var plate = 0;
      await pumpTable(
        tester,
        SeatPlate(
          player: state.players[1],
          bigBlind: state.bigBlind,
          showEye: true,
          onEye: () => eye++,
          onTap: () => plate++,
        ),
      );

      final rect = tester.getRect(find.byType(SeatPlate));
      // Outer (right) top corner → P7.
      await tester.tapAt(rect.topRight + const Offset(-8, 8));
      await tester.pump();
      expect(eye, 1);
      expect(plate, 0);

      // Bottom-left of the plate → P6.
      await tester.tapAt(rect.bottomLeft + const Offset(8, -8));
      await tester.pump();
      expect(eye, 1);
      expect(plate, 1);
    });

    test('HUD numbers are earned, not given', () {
      final player = Player(
        id: 1,
        name: 'Ivey',
        isHero: false,
        stack: 2000,
        handsSeen: 7,
        vpipCount: 2,
        pfrCount: 1,
      );
      expect(SeatPlate.hudNumbers(player), '–/–');
      player.handsSeen = 8;
      player.vpipCount = 2;
      player.pfrCount = 1;
      expect(SeatPlate.hudNumbers(player), '25/13');
    });

    test('heads-up shows BTN/SB but never stores it', () {
      expect(positionLabel(Position.btn, 2), 'BTN/SB');
      expect(positionLabel(Position.btn, 6), 'BTN');
      expect(positionLabel(Position.bb, 2), 'BB');
    });
  });

  group('SizingRail (§4.5)', () {
    const detents = [
      RailDetent(label: 'Min', value: 40),
      RailDetent(label: '⅓', value: 60, optionalLabel: true),
      RailDetent(label: '½', value: 80),
      RailDetent(label: '⅔', value: 100, optionalLabel: true),
      RailDetent(label: '¾', value: 120),
      RailDetent(label: 'Pot', value: 160),
      RailDetent(label: 'All-in', value: 2000),
    ];

    Future<List<int>> drive(
      WidgetTester tester,
      Future<void> Function(Rect rail) act, {
      double width = 358,
    }) async {
      final seen = <int>[];
      var value = 100;
      await pumpTable(
        tester,
        SizedBox(
          width: width,
          child: StatefulBuilder(
            builder:
                (context, setState) => SizingRail(
                  min: 40,
                  max: 2000,
                  detents: detents,
                  value: value,
                  bigBlind: 20,
                  onChanged: (v) {
                    seen.add(v);
                    setState(() => value = v);
                  },
                ),
          ),
        ),
      );
      await act(tester.getRect(find.byType(SizingRail)));
      await tester.pump();
      return seen;
    }

    testWidgets('tapping a slot jumps to that detent', (tester) async {
      // Slot i sits at inset 18 + i × (width − 36) / 6.
      const spacing = (358 - 36) / 6;
      final seen = await drive(tester, (rail) async {
        await tester.tapAt(
          Offset(rail.left + 18 + spacing * 5, rail.center.dy),
        );
      });
      expect(seen.last, 160);
    });

    testWidgets('a value between detents quantises to 0.5 bb', (tester) async {
      const spacing = (358 - 36) / 6;
      final seen = await drive(tester, (rail) async {
        final from = Offset(rail.left + 18 + spacing * 4, rail.center.dy);
        final to = Offset(rail.left + 270, rail.center.dy);
        final gesture = await tester.startGesture(from);
        await gesture.moveTo(to);
        await gesture.up();
      });
      expect(seen, isNotEmpty);
      for (final v in seen) {
        expect(v % 10, 0, reason: '$v is not a whole 0.5 bb');
        expect(v, inInclusiveRange(40, 2000));
      }
      expect(seen.last, 150);
    });

    testWidgets('the rail hides when the only raise is the shove', (
      tester,
    ) async {
      expect(SizingRail.isDegenerate(2000, 2000), isTrue);
      await pumpTable(
        tester,
        SizedBox(
          width: 358,
          child: SizingRail(
            min: 2000,
            max: 2000,
            detents: detents,
            value: 2000,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Only one raise size — all-in 100 bb'), findsOneWidget);
      expect(find.text('Min'), findsNothing);
      expect(tester.getSize(find.byType(SizingRail)).height, SizingRail.height);
    });

    testWidgets('collapsed detents keep their slot but lose their label', (
      tester,
    ) async {
      const short = [
        RailDetent(label: 'Min', value: 40),
        RailDetent(label: '⅓', value: 60),
        RailDetent(label: '½', value: 100),
        RailDetent(label: '⅔', value: 100),
        RailDetent(label: '¾', value: 100),
        RailDetent(label: 'Pot', value: 100),
        RailDetent(label: 'All-in', value: 100),
      ];
      await pumpTable(
        tester,
        SizedBox(
          width: 358,
          child: SizingRail(
            min: 40,
            max: 100,
            detents: short,
            value: 40,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Min'), findsOneWidget);
      expect(find.text('½'), findsOneWidget);
      expect(find.text('⅔'), findsNothing);
      expect(find.text('Pot'), findsNothing);
      expect(find.text('All-in'), findsNothing);
    });

    testWidgets('the thirds drop their labels when slots are tight', (
      tester,
    ) async {
      await pumpTable(
        tester,
        SizedBox(
          width: 270,
          child: SizingRail(
            min: 40,
            max: 2000,
            detents: detents,
            value: 100,
            onChanged: (_) {},
          ),
        ),
        size: const Size(360, 780),
      );
      expect(find.text('Min'), findsOneWidget);
      expect(find.text('½'), findsOneWidget);
      expect(find.text('⅓'), findsNothing);
      expect(find.text('⅔'), findsNothing);
    });
  });

  group('ActionRow (§4.5 states A–G)', () {
    const facingRaise = LegalActions(
      toCall: 40,
      canFold: true,
      canCheck: false,
      canCall: true,
      callAmount: 40,
      canBet: false,
      canRaise: true,
      minRaiseTo: 80,
      maxRaiseTo: 2000,
      potSize: 90,
      bigBlind: 20,
    );
    const nothingToCall = LegalActions(
      toCall: 0,
      canFold: true,
      canCheck: true,
      canCall: false,
      callAmount: 0,
      canBet: true,
      canRaise: false,
      minRaiseTo: 20,
      maxRaiseTo: 2000,
      potSize: 90,
      bigBlind: 20,
    );

    testWidgets('A — Fold · Call · Raise with exact-commit labels', (
      tester,
    ) async {
      await pumpTable(
        tester,
        const SizedBox(
          width: 358,
          child: ActionRow(
            state: ActionRowState.heroToAct,
            legal: facingRaise,
            raiseTo: 150,
            heroStack: 2000,
          ),
        ),
      );
      expect(find.text('Fold'), findsOneWidget);
      expect(find.text('Call 2 bb'), findsOneWidget);
      expect(find.text('Raise to 7.5 bb'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap at the button centre commits; the amount opens P13', (
      tester,
    ) async {
      // The keypad zone used to be the right 60 % of an opaque button whose
      // label is centred, so the visual centre of "Raise to 7.5 bb" — the
      // natural thumb target — opened a sheet instead of raising.
      var raises = 0;
      var amountTaps = 0;
      await pumpTable(
        tester,
        SizedBox(
          width: 358,
          child: ActionRow(
            state: ActionRowState.heroToAct,
            legal: facingRaise,
            raiseTo: 150,
            heroStack: 2000,
            enableHaptics: false,
            onBetRaise: () => raises++,
            onRaiseAmountTap: () => amountTaps++,
          ),
        ),
      );

      final label = find.text('Raise to 7.5 bb');
      await tester.tapAt(tester.getCenter(label));
      await tester.pump();
      expect(raises, 1, reason: 'the label centre must commit');
      expect(amountTaps, 0);

      // The right edge — the amount run — still opens the keypad.
      final button = tester.getRect(find.byType(AllInButton).last);
      await tester.tapAt(Offset(button.right - 8, button.center.dy));
      await tester.pump();
      expect(amountTaps, 1, reason: 'the amount still opens P13');
      expect(raises, 1);
    });

    test('the amount zone never swallows the button centre', () {
      // Measured from the right edge: the trailing gap plus the amount run,
      // clamped to 44 pt … 35 % of the button.
      for (final width in const [180.0, 203.0, 358.0]) {
        for (final label in const [
          'Raise to 7.5 bb',
          'Bet 4.5 bb',
          'All-in 100 bb',
          'Raise',
        ]) {
          final zone = ActionRow.amountZoneWidth(
            TextScaler.noScaling,
            label,
            width,
          );
          expect(zone, lessThanOrEqualTo(width * 0.5), reason: '$label@$width');
          expect(
            width - zone,
            greaterThan(width / 2),
            reason: 'the centre of $label at $width must commit',
          );
        }
      }
    });

    testWidgets('A — no bet to call is Check + Bet', (tester) async {
      await pumpTable(
        tester,
        const SizedBox(
          width: 358,
          child: ActionRow(
            state: ActionRowState.heroToAct,
            legal: nothingToCall,
            raiseTo: 90,
            heroStack: 2000,
          ),
        ),
      );
      expect(find.text('Fold'), findsNothing);
      expect(find.text('Check'), findsOneWidget);
      expect(find.text('Bet 4.5 bb'), findsOneWidget);
    });

    testWidgets('A — the maximum reads All-in', (tester) async {
      await pumpTable(
        tester,
        const SizedBox(
          width: 358,
          child: ActionRow(
            state: ActionRowState.heroToAct,
            legal: facingRaise,
            raiseTo: 2000,
            heroStack: 2000,
          ),
        ),
      );
      expect(find.text('All-in 100 bb'), findsOneWidget);
    });

    testWidgets('A — a call that commits the stack says so', (tester) async {
      await pumpTable(
        tester,
        const SizedBox(
          width: 358,
          child: ActionRow(
            state: ActionRowState.heroToAct,
            legal: facingRaise,
            raiseTo: 150,
            heroStack: 40,
          ),
        ),
      );
      expect(find.text('Call all-in 2 bb'), findsOneWidget);
    });

    testWidgets('B — no raise, Call fills the row', (tester) async {
      await pumpTable(
        tester,
        const SizedBox(
          width: 358,
          child: ActionRow(
            state: ActionRowState.heroToActNoRaise,
            legal: facingRaise,
            heroStack: 2000,
          ),
        ),
      );
      expect(find.text('Raise to 7.5 bb'), findsNothing);
      expect(find.text('Call 2 bb'), findsOneWidget);
    });

    testWidgets('C / D / E / G render their own single button', (tester) async {
      Future<void> pump(ActionRowState state, {bool autoPaused = false}) =>
          pumpTable(
            tester,
            SizedBox(
              width: 358,
              child: ActionRow(state: state, autoPaused: autoPaused),
            ),
          );

      await pump(ActionRowState.botManual);
      expect(find.text('Next action  ›'), findsOneWidget);

      await pump(ActionRowState.botAuto);
      expect(find.text('Pause · tap the table'), findsOneWidget);

      await pump(ActionRowState.botAuto, autoPaused: true);
      expect(find.text('Paused · tap to resume'), findsOneWidget);
      // Regression: the play glyph used to be a literal U+25B6 in the label,
      // which Android drew from NotoColorEmoji — a bright orange square in
      // the middle of the palette. It is an `Icon` now.
      expect(
        find.byIcon(Icons.play_arrow_rounded),
        findsOneWidget,
        reason: 'the resume affordance must be an icon, not an emoji glyph',
      );

      await pump(ActionRowState.handOver);
      expect(find.text('Next hand  ›'), findsOneWidget);

      await pump(ActionRowState.noSession);
      expect(find.text('Deal me in'), findsOneWidget);
    });

    testWidgets('F — paused dims and ignores taps', (tester) async {
      var taps = 0;
      await pumpTable(
        tester,
        SizedBox(
          width: 358,
          child: ActionRow(
            state: ActionRowState.paused,
            underlyingState: ActionRowState.botManual,
            onNextAction: () => taps++,
          ),
        ),
      );
      expect(find.text('Next action  ›'), findsOneWidget);
      await tester.tap(find.text('Next action  ›'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('Fold swallows a tap in its first 150 ms', (tester) async {
      var folds = 0;
      await pumpTable(
        tester,
        SizedBox(
          width: 358,
          child: ActionRow(
            state: ActionRowState.heroToAct,
            legal: facingRaise,
            raiseTo: 150,
            heroStack: 2000,
            onFold: () => folds++,
          ),
        ),
      );
      await tester.tap(find.text('Fold'));
      await tester.pump();
      expect(folds, 0);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Fold'));
      await tester.pump();
      expect(folds, 1);
    });

    // §4.2.4 words it as "above 1.3×", but at 1.3× the long labels already
    // overflow at every supported width (411 pt rendered "Call 1 …" /
    // "Raise t…"), and §4.5's exact commit is unconditional — so the step is
    // taken *at* 1.3×.
    test('at 1.3x and above the labels drop their amounts', () {
      expect(ActionRow.dropAmounts(const TextScaler.linear(1.15)), isFalse);
      expect(ActionRow.dropAmounts(const TextScaler.linear(1.3)), isTrue);
      expect(ActionRow.dropAmounts(const TextScaler.linear(1.5)), isTrue);
    });

    testWidgets('at 1.3x neither commit label is ellipsised', (tester) async {
      await pumpTable(
        tester,
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: SizedBox(
            width: 328, // 360 pt minus the §4.2.3 margins.
            child: ActionRow(
              state: ActionRowState.heroToAct,
              legal: facingRaise,
              raiseTo: 150,
              heroStack: 2000,
            ),
          ),
        ),
      );
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Raise'), findsOneWidget);
      expect(find.textContaining('…'), findsNothing);
    });
  });

  group('HeroStrip (§4.4)', () {
    test('the price line has exactly two forms', () {
      expect(
        HeroStrip.priceLineFor(
          toCall: 40,
          bigBlind: 20,
          potOdds: 0.25,
          short: false,
        ),
        'To call 2 bb · need to win 1 in 4',
      );
      expect(
        HeroStrip.priceLineFor(
          toCall: 40,
          bigBlind: 20,
          potOdds: 0.25,
          short: true,
        ),
        'To call 2 bb · need 1 in 4',
      );
    });

    test('heads-up, narrow screens and big text take the short form', () {
      expect(
        HeroStrip.useShortForm(
          width: 390,
          seats: 6,
          textScaler: TextScaler.noScaling,
        ),
        isFalse,
      );
      expect(
        HeroStrip.useShortForm(
          width: 360,
          seats: 6,
          textScaler: TextScaler.noScaling,
        ),
        isTrue,
      );
      expect(
        HeroStrip.useShortForm(
          width: 390,
          seats: 2,
          textScaler: TextScaler.noScaling,
        ),
        isTrue,
      );
      expect(
        HeroStrip.useShortForm(
          width: 430,
          seats: 6,
          textScaler: const TextScaler.linear(1.3),
        ),
        isTrue,
      );
    });

    testWidgets('the price line is never truncated — the left segment goes', (
      tester,
    ) async {
      await pumpTable(
        tester,
        const SizedBox(
          // Narrow enough that the stack cannot fit beside the price line in
          // the shipped font, wide enough that §4.4's "bare position pill"
          // fallback is still the answer.
          width: 240,
          child: HeroStrip(
            position: Position.bb,
            stack: 2000,
            priceLine: 'To call 37.5 bb · need 1 in 3',
          ),
        ),
      );
      expect(find.text('To call 37.5 bb · need 1 in 3'), findsOneWidget);
      expect(find.text('100 bb'), findsNothing);
      expect(find.text('BB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('all-in replaces the right side', (tester) async {
      await pumpTable(
        tester,
        const SizedBox(
          width: 358,
          child: HeroStrip(
            position: Position.bb,
            stack: 0,
            allIn: true,
            handLabel: 'QQ · pocket queens',
          ),
        ),
      );
      expect(find.text('ALL-IN'), findsOneWidget);
      expect(find.text('QQ · pocket queens'), findsNothing);
    });
  });

  group('Chip, badge, ticker, results (§4.8 / §4.2 / §4.12)', () {
    test('the chip shows a chip-length first clause of layer 1', () {
      // §10.3 models `title` and `clause` separately: the chip is ~250 pt and
      // spends ~80 on "Nice play · ", so a long first clause ellipsised at
      // exactly its payload ("You paid 1 bb to win a…"). The full sentence is
      // one tap away in P3.
      final long = CoachChip.firstClause(
        'You paid 8 bb to win a pot of 24 bb — you need to win 1 in 4.',
      );
      expect(long.length, lessThanOrEqualTo(CoachChip.maxClauseChars + 1));
      expect(long, endsWith('…'));
      expect(long, startsWith('You paid 8 bb to win'));

      // Clauses that already fit are left exactly as they are.
      expect(
        CoachChip.firstClause('Betting with the goods. Keep going.'),
        'Betting with the goods',
      );
      expect(CoachChip.firstClause('Nice fold; too expensive.'), 'Nice fold');
    });

    test('verdict labels are the desktop META strings', () {
      expect(CoachChip.verdictLabel(Verdict.mistake), 'Mistake');
      expect(CoachChip.verdictLabel(Verdict.thin), 'Thin spot');
      expect(CoachChip.verdictLabel(Verdict.ok), 'Reasonable');
      expect(CoachChip.verdictLabel(Verdict.great), 'Nice play');
      expect(CoachChip.verdictLabel(Verdict.info), 'Read');
    });

    testWidgets('the chip renders label + clause and taps through', (
      tester,
    ) async {
      var taps = 0;
      await pumpTable(
        tester,
        CoachChip(
          verdict: Verdict.great,
          title: 'Your bet · Flop',
          clause: 'Betting with the goods',
          enableHaptics: false,
          onTap: () => taps++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nice play · Betting with the goods'), findsOneWidget);
      expect(tester.getSize(find.byType(CoachChip)).height, CoachChip.height);
      await tester.tap(find.byType(CoachChip));
      expect(taps, 1);
    });

    testWidgets('the badge keeps a 44 pt target', (tester) async {
      await pumpTable(
        tester,
        const CoachBadge(count: 3, verdict: Verdict.mistake),
      );
      final size = tester.getSize(find.byType(CoachBadge));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('the ticker has the desktop empty line', (tester) async {
      await pumpTable(tester, const Ticker());
      expect(find.text('Actions will appear here.'), findsOneWidget);

      await pumpTable(
        tester,
        const Ticker(
          entry: LogEntry(
            id: 1,
            street: Street.preflop,
            text: 'Negreanu raises to 3 bb',
            kind: LogKind.action,
          ),
        ),
      );
      expect(find.text('Negreanu raises to 3 bb'), findsOneWidget);
    });

    testWidgets('the results card pins the coach row above the net line', (
      tester,
    ) async {
      var coachTaps = 0;
      await pumpTable(
        tester,
        SizedBox(
          width: 346,
          height: 188,
          child: ResultsCard(
            summary: const ResultsSummary(
              netBb: 12.5,
              caption: 'You won the pot',
              sentence: 'Ivey wins with two pair.',
            ),
            rows: const [
              RevealRow(
                playerId: 5,
                name: 'Polk',
                cards: ['Kd', '7c'],
                note: 'Folded on the flop.',
                folded: true,
              ),
              RevealRow(
                playerId: 4,
                name: 'Ivey',
                cards: ['9h', '9d'],
                note: 'Won with two pair.',
                readLabel: 'Your read 64 %',
              ),
            ],
            coach: const CoachChipContent(
              verdict: Verdict.mistake,
              title: 'Your call · River',
              clause: 'You paid 8 bb to win 24 bb',
            ),
            onCoachTap: () => coachTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mistake · You paid 8 bb to win 24 bb'), findsOneWidget);
      expect(find.text('+12.5 bb'), findsOneWidget);
      expect(find.text('YOU WON THE POT'), findsOneWidget);

      final coachRow = tester.getRect(
        find.text('Mistake · You paid 8 bb to win 24 bb'),
      );
      final net = tester.getRect(find.text('+12.5 bb'));
      expect(coachRow.top, lessThan(net.top));

      await tester.tap(find.text('Mistake · You paid 8 bb to win 24 bb'));
      expect(coachTaps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the collapsed card keeps the coach row', (tester) async {
      await pumpTable(
        tester,
        const SizedBox(
          width: 346,
          child: ResultsCard(
            summary: ResultsSummary(
              netBb: 12.5,
              caption: 'You won the pot',
              sentence: 'Ivey wins with two pair.',
            ),
            rows: [],
            collapsed: true,
            coach: CoachChipContent(
              verdict: Verdict.thin,
              clause: 'Thin value bet',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thin spot · Thin value bet'), findsOneWidget);
      expect(find.textContaining('See everyone’s cards'), findsOneWidget);
    });
  });

  group('BetPill / PotPill / BoardRow', () {
    testWidgets('the board always draws five slots', (tester) async {
      await pumpTable(
        tester,
        const BoardRow(cards: ['As', '7d', '2c'], size: 44),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlayingCardView), findsNWidgets(3));
      expect(
        tester.getSize(find.byType(BoardRow)).width,
        BoardRow.widthFor(44, 6),
      );
    });

    testWidgets('the pot pill carries the street and the amount', (
      tester,
    ) async {
      await pumpTable(
        tester,
        const PotPill(street: Street.preflop, pot: 90, bigBlind: 20),
      );
      expect(find.text('PRE-FLOP'), findsOneWidget);
      expect(find.text('Pot 4.5 bb'), findsOneWidget);
    });

    testWidgets('a tappable action pill gets a 44 pt band', (tester) async {
      await pumpTable(
        tester,
        BetPill(kind: BetPillKind.raise, amount: 60, onTap: () {}),
      );
      expect(tester.getSize(find.byType(BetPill)).height, 44);
    });

    testWidgets('the hero pill says "(you)" when it fits', (tester) async {
      await pumpTable(
        tester,
        const BetPill(
          kind: BetPillKind.blind,
          amount: 20,
          isHero: true,
          maxWidth: 400,
        ),
      );
      expect(find.text('1 bb (you)'), findsOneWidget);
    });

    testWidgets(
      // §4.2 gives the hero pill 36–44 pt and §4.2’s wireframe writes
      // "● 2 bb (you)" into it; the two cannot both hold, and §13’s 11 pt
      // legibility floor is the one that wins. `FittedBox` used to scale the
      // whole row down to ~5 pt instead — so the pill grows past its nominal
      // width rather than shrinking the hero's own number.
      'the hero pill grows past maxWidth rather than shrink below 11 pt',
      (tester) async {
        await pumpTable(
          tester,
          const BetPill(
            kind: BetPillKind.blind,
            amount: 20,
            isHero: true,
            maxWidth: 40,
          ),
        );
        expect(find.text('1 bb (you)'), findsOneWidget);
        final style = tester.widget<Text>(find.text('1 bb (you)')).style;
        expect(style?.fontSize, 11);

        // The text is laid out at its full 11 pt: the `FittedBox` never
        // scales it, because the pill widened to fit instead.
        final text = tester.renderObject<RenderBox>(find.text('1 bb (you)'));
        final fitted = tester.renderObject<RenderBox>(
          find.ancestor(
            of: find.text('1 bb (you)'),
            matching: find.byType(FittedBox),
          ),
        );
        expect(fitted.size.width, greaterThan(40));
        expect(fitted.size.width, greaterThanOrEqualTo(text.size.width));
      },
    );

    test('engine action labels map to pill kinds', () {
      expect(BetPill.kindFromActionLabel('Raise'), BetPillKind.raise);
      expect(BetPill.kindFromActionLabel('All-In'), BetPillKind.allIn);
      expect(BetPill.kindFromActionLabel('SB'), BetPillKind.blind);
    });
  });

  group('HeroHand + TurnRing', () {
    testWidgets('the hero hand lifts and glows on the turn', (tester) async {
      await pumpTable(
        tester,
        const HeroHand(cards: ['Qs', 'Qh'], size: 72, active: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlayingCardView), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion leaves a static ring', (tester) async {
      await pumpTable(
        tester,
        const TurnRing(
          mode: TurnRingMode.breathing,
          reducedMotion: true,
          child: SizedBox(width: 104, height: 58),
        ),
      );
      // No pending frames: nothing is animating.
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
