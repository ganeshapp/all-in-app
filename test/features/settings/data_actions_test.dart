/// X0 → Data (DESIGN.md §7.9, §7.10) and X3's three refusals (§14).
///
/// The three actions are one injectable service, so the wording of every
/// success and every failure can be pinned without a share sheet or a file
/// picker; the widget half then only has to show what it is handed.
library;

import 'package:allin/app/providers/app_providers.dart';
import 'package:allin/features/settings/providers/settings_providers.dart';
import 'package:allin/features/settings/screens/settings_screen.dart';
import 'package:allin/features/settings/widgets/restore_dialog.dart';
import 'package:allin/services/file_service.dart';
import 'package:allin/services/persistence/backup_service.dart';
import 'package:allin/services/persistence/key_value_store.dart';
import 'package:allin/services/share_service.dart';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'settings_screen_test.dart' show kPhone, pumpSettings, reveal;

/// A share sheet that answers with whatever the test asks for.
class _FakeShareAdapter extends ShareAdapter {
  _FakeShareAdapter(this.outcome);

  final ShareOutcome outcome;
  int calls = 0;
  String? lastText;

  @override
  Future<ShareOutcome> shareText(String text, {String? subject}) async {
    calls++;
    lastText = text;
    return outcome;
  }

  @override
  Future<ShareOutcome> shareFile(
    String path, {
    String? text,
    String? subject,
    String? mimeType,
  }) async {
    calls++;
    return outcome;
  }
}

/// A `FileService` that stages into the system temp dir instead of asking
/// `path_provider` (which has no platform channel in a widget test).
FileService _stagingFiles() => FileService(
  temporaryDirectory: () async => Directory.systemTemp.createTemp('allin-test'),
);

/// A picker that cancels, or throws.
FileService _picker({Object? error}) => FileService(
  pickFiles: ({required allowedExtensions, dialogTitle}) async {
    if (error != null) throw error;
    return null;
  },
);

void main() {
  ProviderContainer containerWith(List<Override> overrides) {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(KeyValueStore.memory()),
        ...overrides,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('back up all data (§7.9)', () {
    test('a completed share reports "Backup ready to save"', () async {
      final adapter = _FakeShareAdapter(ShareOutcome.success);
      final container = containerWith([
        shareServiceProvider.overrideWith(
          (ref) => ShareService(adapter: adapter, files: _stagingFiles()),
        ),
      ]);

      final result =
          await container.read(settingsDataServiceProvider).shareBackup();

      expect(result.isOk, isTrue);
      expect(result.message, SettingsDataService.backupShared);
      expect(adapter.calls, 1);
    });

    test('a dismissed share says nothing at all', () async {
      final container = containerWith([
        shareServiceProvider.overrideWith(
          (ref) => ShareService(
            adapter: _FakeShareAdapter(ShareOutcome.dismissed),
            files: _stagingFiles(),
          ),
        ),
      ]);

      final result =
          await container.read(settingsDataServiceProvider).shareBackup();

      expect(result.status, DataActionStatus.cancelled);
      expect(result.message, isEmpty);
    });

    test('an unavailable share sheet uses the §14 wording', () async {
      final container = containerWith([
        shareServiceProvider.overrideWith(
          (ref) => ShareService(
            adapter: _FakeShareAdapter(ShareOutcome.unavailable),
            files: _stagingFiles(),
          ),
        ),
      ]);

      final result =
          await container.read(settingsDataServiceProvider).shareBackup();

      expect(result.status, DataActionStatus.failed);
      expect(result.message, SettingsDataService.backupFailed);
    });
  });

  group('restore from backup (§7.9, §14)', () {
    test('a cancelled picker is neither an error nor a restore', () async {
      final container = containerWith([
        fileServiceProvider.overrideWithValue(_picker()),
      ]);

      final picked =
          await container.read(settingsDataServiceProvider).pickBackup();

      expect(picked.json, isNull);
      expect(picked.error, isNull);
    });

    test('unreadable bytes get their own sentence', () async {
      final container = containerWith([
        fileServiceProvider.overrideWithValue(
          _picker(
            error: const FileServiceException(FileFailure.unreadable, 'boom'),
          ),
        ),
      ]);

      final picked =
          await container.read(settingsDataServiceProvider).pickBackup();

      expect(picked.json, isNull);
      expect(picked.error, SettingsDataService.unreadableFile);
      expect(
        picked.error,
        isNot(SettingsDataService.notABackup),
        reason: '§14 keeps the two refusals distinct',
      );
    });

    test(
      'a file that is not a backup is refused before anything is written',
      () {
        final container = containerWith([]);
        final data = container.read(settingsDataServiceProvider);

        final preview = data.inspect('{"hello":"world"}');
        expect(preview.isRestorable, isFalse);
        expect(preview.problem, BackupProblem.notABackup);
      },
    );

    test('a newer schema names both version numbers', () {
      const preview = BackupPreview(
        schemaVersion: 99,
        problem: BackupProblem.newerSchema,
      );
      final message = SettingsDataService.newerSchemaMessage(preview);

      expect(message, contains('backup v99'));
      expect(message, contains('v${BackupService.schemaVersion}'));
    });

    test('the X3 body names the date and the hand count', () {
      final at = DateTime(2026, 3, 12).millisecondsSinceEpoch;
      final body = SettingsDataService.restoreBody(
        BackupPreview(exportedAt: at, handCount: 1),
      );

      expect(body, contains('12 March 2026'));
      expect(body, contains('(1 hand)'), reason: 'singular, not "1 hands"');
      expect(
        SettingsDataService.restoreBody(
          BackupPreview(exportedAt: at, handCount: 4),
        ),
        contains('(4 hands)'),
      );
    });

    test('a stampless backup says so rather than inventing a date', () {
      expect(SettingsDataService.formatBackupDate(null), 'an unknown date');
      expect(SettingsDataService.formatBackupDate(0), 'an unknown date');
    });
  });

  testWidgets('a refused restore shows the §14 dialog and writes nothing', (
    tester,
  ) async {
    final store = KeyValueStore.memory();
    await pumpSettings(
      tester,
      store: store,
      size: kPhone,
      overrides: [
        fileServiceProvider.overrideWithValue(
          FileService(
            pickFiles: ({required allowedExtensions, dialogTitle}) async {
              throw const FileServiceException(FileFailure.unreadable, 'x');
            },
          ),
        ),
      ],
    );

    await reveal(tester, find.text(SettingsCopy.restore));
    await tester.tap(find.text(SettingsCopy.restore));
    await tester.pumpAndSettle();

    expect(find.text(RestoreCopy.refusedTitle), findsOneWidget);
    expect(find.text(SettingsDataService.unreadableFile), findsOneWidget);

    await tester.tap(find.text(RestoreCopy.ok));
    await tester.pumpAndSettle();
    expect(find.text(RestoreCopy.refusedTitle), findsNothing);
  });
}
