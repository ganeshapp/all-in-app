/// Hand notes, bookmarks and tags (docs/port/persistence-stats-settings.md
/// §6.6; DESIGN.md §7.6 note editor P12, §7.5 tag chips).
///
/// One key — `allin.handnotes.v1` — holding
/// `{ "<startedAt>": { note, tags, ts } }`. A "bookmark" is simply the
/// existence of an entry, which is why [HandNote.isEmpty] and the editor's
/// Save button share one rule: text and tags both blank means no note.
///
/// The key is the hand's `startedAt` (unique per hand; for imports it is the
/// parsed timestamp), so notes follow a hand through a restart and through
/// the replayer, the session summary and the All-hands list alike.
library;

import 'key_value_store.dart';

/// Storage key (desktop parity).
const String kHandNotesKey = 'allin.handnotes.v1';

/// The five preset tags the editor always offers, in this order.
const List<String> kPresetTags = [
  'review later',
  'bluff-catch',
  'thin value',
  'weird line',
  'big pot',
];

/// Notes are keyed by `String(startedAt)`.
String handNoteKey(int startedAt) => '$startedAt';

/// One note: free text, tags, and when it was last saved.
class HandNote {
  const HandNote({this.note = '', this.tags = const [], this.ts = 0});

  final String note;
  final List<String> tags;

  /// Epoch ms of the last save.
  final int ts;

  /// Nothing worth keeping — the editor disables Save in this state.
  bool get isEmpty => note.trim().isEmpty && tags.isEmpty;

  Map<String, Object?> toJson() => {'note': note, 'tags': tags, 'ts': ts};

  /// Tolerant decode: a malformed entry reads as an empty note.
  static HandNote fromJson(Object? json) {
    if (json is! Map) return const HandNote();
    return HandNote(
      note: json['note'] as String? ?? '',
      tags: [
        for (final t in (json['tags'] as List?) ?? const [])
          if (t is String) t,
      ],
      ts: (json['ts'] as num?)?.toInt() ?? 0,
    );
  }
}

class NotesRepository {
  NotesRepository(this._store);

  final KeyValueStore _store;

  /// Every note, keyed by [handNoteKey].
  Map<String, HandNote> loadAll() => {
    for (final e in _store.getJsonMap(kHandNotesKey).entries)
      e.key: HandNote.fromJson(e.value),
  };

  /// The note on one hand, or null.
  HandNote? noteFor(int startedAt) => loadAll()[handNoteKey(startedAt)];

  /// True when the hand carries a note or tags — the gold ✎ in the row.
  bool hasNote(int startedAt) => noteFor(startedAt) != null;

  /// Saves (or replaces) a note. [nowMs] defaults to the wall clock.
  Future<bool> setNote(
    int startedAt, {
    String note = '',
    List<String> tags = const [],
    int? nowMs,
  }) async {
    final all = loadAll();
    all[handNoteKey(startedAt)] = HandNote(
      note: note,
      tags: List.of(tags),
      ts: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    return _write(all);
  }

  /// "Remove note" in the editor.
  Future<bool> remove(int startedAt) async {
    final all = loadAll();
    all.remove(handNoteKey(startedAt));
    return _write(all);
  }

  /// Every tag in use, across all notes (the chip row of DESIGN §7.5),
  /// preset tags first in their fixed order, then custom ones alphabetically.
  List<String> allTags() {
    final used = <String>{for (final n in loadAll().values) ...n.tags};
    final presets = kPresetTags.where(used.contains).toList();
    final custom = used.where((t) => !kPresetTags.contains(t)).toList()..sort();
    return [...presets, ...custom];
  }

  /// Adds or removes [tag] on a note, lower-cased like the editor's custom
  /// field. Returns the resulting tag list.
  List<String> toggleTag(List<String> tags, String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isEmpty) return List.of(tags);
    return tags.contains(t) ? (List.of(tags)..remove(t)) : [...tags, t];
  }

  Future<bool> _write(Map<String, HandNote> all) => _store.setJson(
    kHandNotesKey,
    {for (final e in all.entries) e.key: e.value.toJson()},
  );
}
