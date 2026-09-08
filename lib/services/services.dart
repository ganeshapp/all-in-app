/// Barrel for the app's platform services (ARCHITECTURE.md "Layout",
/// DESIGN.md §16.3 `lib/services/`).
///
/// These are the only places the app talks to the outside world: isolates
/// (equity), the vibrator (haptics), the share sheet, the file system and the
/// clock. Persistence has its own barrel under `services/persistence/`.
library;

export 'clock.dart';
export 'equity_service.dart';
export 'file_service.dart';
export 'haptics.dart';
export 'share_service.dart';
