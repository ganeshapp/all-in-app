/// Semantic haptic events — DESIGN.md §11 (the Motion + haptics table) and
/// §4.8 (verdict haptics), gated by Settings → Haptics (§9, `allin.settings.v1`
/// key `haptics`).
///
/// Widgets never call `HapticFeedback` directly: they call the named event
/// that the §11 table lists for what just happened (`haptics.actionCommitted()`
/// when Fold/Call/Raise commits, `haptics.detentTick()` per sizing-rail
/// detent, …). That keeps the mapping in one place, keeps the single
/// [enabled] flag honest — when it is off *nothing* fires, including the
/// refusal haptic of §2.5 — and lets tests assert on patterns rather than on
/// platform channels.
///
/// iOS has notification haptics (success / warning / error) that Flutter does
/// not expose; §16.6 allows a thin platform adapter, so [PlatformHapticDriver]
/// approximates them with impact patterns. Swap the driver, not the call
/// sites, if that ever changes.
library;

import 'package:flutter/services.dart';

import '../engine/coach.dart' show Verdict;
import 'clock.dart';

/// The physical patterns the app can ask for.
enum HapticPattern {
  /// `HapticFeedback.lightImpact` — toggles, deals, hero's turn, goal met.
  light,

  /// `HapticFeedback.mediumImpact` — committing an action, thin verdicts.
  medium,

  /// `HapticFeedback.heavyImpact` — reserved for errors.
  heavy,

  /// `HapticFeedback.selectionClick` — detents, painted cells, frames, snaps.
  selection,

  /// Notification "success" (pot won, sharp read, correct drill).
  success,

  /// Notification "warning" (mistake verdict, blocking sheet, wrong drill).
  warning,

  /// Notification "error" — nothing in v1 uses it; kept for completeness.
  error,
}

/// What actually vibrates the phone. Injectable so tests need no channels.
abstract class HapticDriver {
  const HapticDriver();

  /// Fire [pattern]; must never throw (a missing vibrator is not an error).
  Future<void> play(HapticPattern pattern);
}

/// Maps [HapticPattern] onto `HapticFeedback` (§16.6 platform adapter).
class PlatformHapticDriver extends HapticDriver {
  const PlatformHapticDriver();

  @override
  Future<void> play(HapticPattern pattern) async {
    try {
      switch (pattern) {
        case HapticPattern.light:
          await HapticFeedback.lightImpact();
        case HapticPattern.medium:
          await HapticFeedback.mediumImpact();
        case HapticPattern.heavy:
          await HapticFeedback.heavyImpact();
        case HapticPattern.selection:
          await HapticFeedback.selectionClick();
        case HapticPattern.success:
          // No notification API in Flutter: a light tap reads as "done".
          await HapticFeedback.lightImpact();
        case HapticPattern.warning:
          // Two-beat warning: the closest impact pair to the platform pattern.
          await HapticFeedback.mediumImpact();
          await Future<void>.delayed(const Duration(milliseconds: 90));
          await HapticFeedback.lightImpact();
        case HapticPattern.error:
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 90));
          await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      // Platform channel unavailable (tests, desktop): silently ignore.
    }
  }
}

/// A driver that records instead of vibrating — for tests and previews.
class RecordingHapticDriver extends HapticDriver {
  RecordingHapticDriver();

  /// Every pattern played, oldest first.
  final List<HapticPattern> played = <HapticPattern>[];

  @override
  Future<void> play(HapticPattern pattern) async => played.add(pattern);

  void clear() => played.clear();
}

/// The app's haptics. One instance, held by the settings provider.
///
/// Every method is fire-and-forget: haptics are feedback, never something the
/// UI awaits. When [enabled] is false every call returns without touching the
/// platform — §2.5's "with Settings → Haptics also off, nothing happens".
class Haptics {
  Haptics({
    bool enabled = true,
    HapticDriver driver = const PlatformHapticDriver(),
    Clock clock = Clock.system,
  }) : _driver = driver,
       _clock = clock,
       _enabled = enabled;

  final HapticDriver _driver;
  final Clock _clock;
  final Map<String, int> _lastAt = <String, int>{};

  bool _enabled;

  /// Settings → Haptics. False short-circuits every event below.
  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    if (!value) _lastAt.clear();
  }

  /// §11: `selectionClick` streams are throttled to "≥ 30 ms apart".
  static const Duration minRepeatGap = Duration(milliseconds: 30);

  /* ------------------------------------------------------------ table (§4) */

  /// Fold / Call / Raise / Next / Got it committed (§11 "Button press").
  void actionCommitted() => _play(HapticPattern.medium);

  /// A toggle, chip or segmented control changed (§11 "Button press: light on
  /// toggles").
  void toggle() => _play(HapticPattern.light);

  /// The second hero card lands (§11 "Deal: hero cards").
  void dealCard() => _play(HapticPattern.light);

  /// It is the hero's turn — fires once per turn (§11 "Hero's turn").
  void heroTurn() => _play(HapticPattern.light);

  /// A bot's raise pill pops in on Auto pace (§11 "Action pill pop").
  void actionPill() => _play(HapticPattern.light);

  /// Sizing-rail detent (§11 "Sizing rail", §12) — throttled.
  void detentTick() => _throttled('detent', HapticPattern.selection);

  /// One range-matrix cell painted (§11 "Range paint") — throttled.
  void rangePaint() => _throttled('range', HapticPattern.selection);

  /// A sheet settled on an S/M/L snap point, or a drag crossed the §11
  /// hero-strip threshold.
  void sheetSnap() => _play(HapticPattern.selection);

  /// A blocked system back (§2.5): with reduced motion this *is* the whole
  /// response.
  void blockedBack() => _play(HapticPattern.selection);

  /// Chart / heatmap drag-to-inspect moved to a new cell (§7.3, §7.11) —
  /// throttled.
  void inspectCell() => _throttled('inspect', HapticPattern.selection);

  /// Frame scrubber moved one frame (§5.2, §7.7) — throttled.
  void frameScrub() => _throttled('frame', HapticPattern.selection);

  /* ---------------------------------------------------------- coach (§4.8) */

  /// "Nice play" / "Reasonable" (§4.8: light).
  void verdictGood() => _play(HapticPattern.light);

  /// "Thin spot" (§4.8: medium).
  void verdictThin() => _play(HapticPattern.medium);

  /// A mistake verdict (§4.8: `notification.warning`).
  void verdictMistake() => _play(HapticPattern.warning);

  /// A blocking note opened its sheet (§4.8: warning, once).
  void blockingSheet() => _play(HapticPattern.warning);

  /// Route a coach [verdict] to the right event (§4.8, §16.5 verdict colours
  /// use the same buckets).
  void verdict(Verdict verdict) {
    switch (verdict) {
      case Verdict.mistake:
        verdictMistake();
      case Verdict.thin:
        verdictThin();
      case Verdict.ok:
      case Verdict.great:
      case Verdict.info:
        verdictGood();
    }
  }

  /// Read-range Peek reveal (§4.9: medium).
  void peekReveal() => _play(HapticPattern.medium);

  /// Peek scored "Sharp read" (§4.9: success).
  void peekSharp() => _play(HapticPattern.success);

  /// The pot slides to the hero (§11 "Pot to winner": success on hero win).
  void potWon() => _play(HapticPattern.success);

  /* --------------------------------------------------------- drills (§5.3) */

  /// A drill option was chosen (§11 "Drill answer": medium).
  void drillAnswer() => _play(HapticPattern.medium);

  /// The feedback panel says correct (§11: success).
  void drillCorrect() => _play(HapticPattern.success);

  /// The feedback panel says wrong (§11: warning).
  void drillWrong() => _play(HapticPattern.warning);

  /// The daily goal bar completed (§11 "Goal met": light, no confetti).
  void goalMet() => _play(HapticPattern.light);

  /* -------------------------------------------------------------- plumbing */

  /// Escape hatch for a one-off event that is genuinely not in §11 yet.
  /// Prefer adding a named method above so the mapping stays reviewable.
  void pattern(HapticPattern pattern) => _play(pattern);

  void _play(HapticPattern pattern) {
    if (!_enabled) return;
    _driver.play(pattern);
  }

  void _throttled(String tag, HapticPattern pattern) {
    if (!_enabled) return;
    final now = _clock.nowMs;
    final last = _lastAt[tag];
    if (last != null && now - last < minRepeatGap.inMilliseconds) return;
    _lastAt[tag] = now;
    _driver.play(pattern);
  }
}
