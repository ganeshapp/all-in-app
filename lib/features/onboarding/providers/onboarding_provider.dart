/// O0 / O1 state (DESIGN.md §8, §4.15).
///
/// Two independent things live here:
///
/// * the **tour gate** — `allin.onboarded.v1`, true once any close path has
///   run, and true as well when storage itself throws (a broken preferences
///   file must never trap a user in the tour);
/// * the **first-table coach marks** — three one-time captions over the first
///   three hands of the user's life, counted in `allin.hints.v1.firstHands`
///   so quitting between hands can neither repeat nor skip one.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/services/persistence/hints_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/* ----------------------------------------------------------------- the tour */

/// Whether the tour has been seen. `true` ⇒ O0 never mounts on launch (§8).
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(onboardingStoreProvider).hasOnboarded();

  /// Every close path of §8 — Skip, ✕, "Start playing", "Take me there",
  /// and the hand-off to the placement test.
  Future<void> markSeen() async {
    if (!state) state = true;
    await ref.read(onboardingStoreProvider).markOnboarded();
  }

  /// Settings → "Run again": clears the flag (and, via the caller, the coach
  /// marks) so the tour and the placement quiz run again. The drill rating is
  /// deliberately untouched — only finishing the quiz changes it.
  Future<void> runAgain() async {
    await ref.read(onboardingStoreProvider).reset();
    state = false;
    ref.invalidate(coachMarksProvider);
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

/* --------------------------------------------------------- O1 coach marks */

/// The three §4.15 captions, in the order they are owed.
enum CoachMark {
  /// Hand 1, under the action row in State C.
  step('Tap the table or Next action to step'),

  /// Hand 2, next to the first eye glyph that appears.
  eye('Tap the eye to read their range'),

  /// Hand 3, above the hero strip on the first hero turn.
  swipe('Swipe up here for the hand log and your session');

  const CoachMark(this.caption);

  /// The verbatim caption (§4.15).
  final String caption;
}

/// §4.15: heads-up adds this to the ticker for the first three HU hands. It is
/// a ticker line, not a caption, so the table renders it — the constant lives
/// here so both halves of O1 read from one place.
const String kHeadsUpFirstHandsTicker =
    "You're the button — you act first pre-flop, last after it";

@immutable
class CoachMarksState {
  const CoachMarksState({required this.handsSeen, this.visible});

  /// Hands the user has ever started (`allin.hints.v1.firstHands`).
  final int handsSeen;

  /// The caption on screen right now, or null.
  final CoachMark? visible;

  /// Still owed a caption (§4.15: the first three hands of a user's life).
  bool get armed => handsSeen >= 1 && handsSeen <= kFirstHandsHintLimit;

  /// The one caption this hand may show: hand 1 → step, 2 → eye, 3 → swipe.
  CoachMark? get markForThisHand =>
      handsSeen >= 1 && handsSeen <= CoachMark.values.length
          ? CoachMark.values[handsSeen - 1]
          : null;

  CoachMarksState copyWith({
    int? handsSeen,
    CoachMark? visible,
    bool clear = false,
  }) => CoachMarksState(
    handsSeen: handsSeen ?? this.handsSeen,
    visible: clear ? null : (visible ?? this.visible),
  );
}

/// Drives the O1 captions.
///
/// The play feature calls [handStarted] once per deal, [request] when the
/// surface a caption points at first exists, and [dismiss] on any tap.
class CoachMarksNotifier extends Notifier<CoachMarksState> {
  int? _lastHand;

  @override
  CoachMarksState build() => CoachMarksState(
    handsSeen: ref.read(hintsStoreProvider).load().firstHands,
  );

  /// A new hand was dealt. [handNumber] guards against a rebuild counting the
  /// same hand twice; pass the session's hand counter.
  Future<void> handStarted(int handNumber) async {
    if (_lastHand == handNumber) return;
    _lastHand = handNumber;
    // The counter runs one past the limit so that the fourth hand can turn
    // the marks off for good, on this run and every later one.
    if (state.handsSeen > kFirstHandsHintLimit) {
      state = state.copyWith(clear: true);
      return;
    }
    final counters = await ref
        .read(hintsStoreProvider)
        .increment(HintKind.firstHands);
    state = CoachMarksState(handsSeen: counters.firstHands);
  }

  /// Show [mark] if it is the one this hand owes and nothing else is up.
  void request(CoachMark mark) {
    if (!state.armed) return;
    if (state.visible != null) return;
    if (state.markForThisHand != mark) return;
    state = state.copyWith(visible: mark);
  }

  /// Any tap dismisses the visible caption; it is never shown again because
  /// the hand counter has already moved past it.
  void dismiss() {
    if (state.visible == null) return;
    state = state.copyWith(clear: true);
  }
}

final coachMarksProvider =
    NotifierProvider<CoachMarksNotifier, CoachMarksState>(
      CoachMarksNotifier.new,
    );

/// The caption on screen, for widgets that only care about that.
final visibleCoachMarkProvider = Provider<CoachMark?>(
  (ref) => ref.watch(coachMarksProvider.select((s) => s.visible)),
);
