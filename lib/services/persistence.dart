/// The persistence layer (DESIGN.md §16.3 `services/persistence/`, §16.4
/// "Persistence additions"; docs/port/persistence-stats-settings.md).
///
/// Everything on-device lives behind this barrel: the SQLite schema
/// ([AppDatabase]), the four repositories ([StatsRepository],
/// [SessionRepository], [HandsRepository], [NotesRepository]), the typed
/// key-value stores over [KeyValueStore], the [BackupService] and the JSON
/// codecs for the engine's state objects.
///
/// Plain Dart only — no Riverpod here. Notifiers wrap these; widgets never
/// touch sqflite or shared_preferences directly (ARCHITECTURE.md).
library;

export 'persistence/app_database.dart';
export 'persistence/backup_service.dart';
export 'persistence/drill_store.dart';
export 'persistence/goals_store.dart';
export 'persistence/hands_repository.dart';
export 'persistence/hints_store.dart';
export 'persistence/key_value_store.dart';
export 'persistence/leak_queue_store.dart';
export 'persistence/notes_repository.dart';
export 'persistence/onboarding_store.dart';
export 'persistence/records.dart';
export 'persistence/review_queue_store.dart';
export 'persistence/serialization.dart';
export 'persistence/session_repository.dart';
export 'persistence/settings_store.dart';
export 'persistence/stats_repository.dart';
export 'persistence/study_store.dart';
export 'persistence/table_options_store.dart';
