/// The P0 lobby's own state (DESIGN.md §4.1): the live table-setup draft that
/// re-seats the felt preview as the user changes it, the last ten ended
/// sessions, the one-shot hint counters and the "ring the Resume card" signal
/// §2.1 owes the height-gated Play-tab item.
///
/// Nothing here touches the engine — `SessionNotifier` owns the table.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/features/play/providers/play_providers.dart';
import 'package:allin/features/play/providers/session_provider.dart';
import 'package:allin/services/persistence/hints_store.dart';
import 'package:allin/services/persistence/session_repository.dart';
import 'package:allin/services/persistence/table_options_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// §4.1 "Recent sessions: last 10 ended sessions". Empty (and the section
/// hidden) until the first session ends.
final recentSessionsProvider = FutureProvider<List<SessionRecord>>((ref) {
  ref.watch(sessionsRevisionProvider);
  return ref.watch(sessionRepositoryProvider).recentSessions();
});

/// The seats / ante the setup card is currently showing. Seeded from
/// `allin.table.v1` and only written back when "Deal me in" is pressed, so
/// browsing the segmented controls never changes what a Resume would use.
class LobbyDraftNotifier extends Notifier<TableOptions> {
  @override
  TableOptions build() => ref.read(tableOptionsStoreProvider).load();

  void setSeats(int seats) =>
      state = TableOptions(seats: seats, ante: state.ante);

  void setAnte(int ante) =>
      state = TableOptions(seats: state.seats, ante: ante);
}

final lobbyDraftProvider = NotifierProvider<LobbyDraftNotifier, TableOptions>(
  LobbyDraftNotifier.new,
);

/// §2.1: when the pill is height-gated out, tapping the Play tab "opens the
/// lobby with the Resume card focused and ringed gold for 2 s".
class ResumeFocusNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state = state + 1;
}

final resumeFocusProvider = NotifierProvider<ResumeFocusNotifier, int>(
  ResumeFocusNotifier.new,
);

/// The one-shot hint counters (§4.15). Read synchronously; the table bumps
/// them through [HintsStore] and invalidates this provider.
final hintCountersProvider = Provider<HintCounters>(
  (ref) => ref.watch(hintsStoreProvider).load(),
);

/// §4.1's empty state: no live session, no ended session and no hand ever
/// dealt — the preview shows dashed slots and the "Your first table" caption.
final neverPlayedProvider = Provider<bool>((ref) {
  final active = ref.watch(sessionProvider.select((s) => s.active));
  if (active) return false;
  if (ref.watch(hintCountersProvider).firstHands > 0) return false;
  final recent = ref.watch(recentSessionsProvider);
  return recent.maybeWhen(data: (rows) => rows.isEmpty, orElse: () => true);
});
