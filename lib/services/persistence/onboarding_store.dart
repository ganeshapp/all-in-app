/// The onboarding flag (docs/port/persistence-stats-settings.md §6.11;
/// DESIGN.md §8 Onboarding, §9 "Tour & placement · Run again").
///
/// One key, `allin.onboarded.v1`, holding the raw string `"1"` — presence
/// means the tour has been seen. If storage itself is unreadable the answer is
/// **true**: a broken preferences file must never trap the user in the tour.
library;

import 'key_value_store.dart';

/// Storage key (desktop parity).
const String kOnboardedKey = 'allin.onboarded.v1';

class OnboardingStore {
  OnboardingStore(this._store);

  final KeyValueStore _store;

  /// True when the tour has been seen (or when storage cannot answer).
  bool hasOnboarded() {
    try {
      return _store.getString(kOnboardedKey) == '1';
    } catch (_) {
      return true;
    }
  }

  /// Set when the tour is finished, skipped or dismissed.
  Future<bool> markOnboarded() => _store.setString(kOnboardedKey, '1');

  /// Settings → "Run again": clears the flag so the tour and the placement
  /// quiz run again. Deliberately does **not** touch the drill rating — only
  /// finishing the placement quiz changes that (docs/port §6.9).
  Future<bool> reset() => _store.remove(kOnboardedKey);
}
