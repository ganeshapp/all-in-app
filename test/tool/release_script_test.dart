/// Guards the release verification in `tool/release.sh` and
/// `.github/workflows/release.yml`.
///
/// Both scripts run under `set -o pipefail` (the GitHub Actions default `bash`
/// shell sets it too). Under pipefail, `unzip -l "$apk" | grep -q ...` fails
/// the *pipeline* with 141 even when the grep matched: `grep -q` exits on its
/// first match, `unzip` is killed by SIGPIPE mid-write, and pipefail reports
/// the producer's death as the pipeline's status. That is exactly what made a
/// correctly built, correctly signed arm64 APK get rejected with
/// "refusing: … lacks lib/arm64-v8a", blocking the release for a bug that was
/// never in the build. The same trap sits in `… | grep 'SHA-256 digest' |
/// head -1`.
///
/// The fix is to capture the producer's output into a variable and match it
/// with a here-string, so nothing is ever piped into an early-exiting reader.
/// These tests pin both halves of that: the scripts must not reintroduce the
/// piped form, and the idiom they use must actually succeed under pipefail.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `cmd | grep -q …` or `cmd | head …` — a pipe into a reader that exits as
/// soon as it has what it wants, which is fatal under `pipefail`.
final RegExp _pipeIntoEarlyExit = RegExp(r'\|\s*(grep\s+-[a-zA-Z]*q|head\b)');

/// Lines that are comments (leading `#`, allowing YAML indentation) are prose
/// about the trap, not shell that can trip over it.
bool _isComment(String line) => line.trimLeft().startsWith('#');

void main() {
  final repoRoot = Directory.current.path;

  group('release verification scripts', () {
    for (final path in const <String>[
      'tool/release.sh',
      '.github/workflows/release.yml',
    ]) {
      test('$path never pipes into an early-exiting reader', () {
        final file = File('$repoRoot/$path');
        expect(file.existsSync(), isTrue, reason: '$path is missing');

        final offenders = <String>[];
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isComment(line)) continue;
          if (_pipeIntoEarlyExit.hasMatch(line)) {
            offenders.add('  ${i + 1}: ${line.trim()}');
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'Under `set -o pipefail` these pipelines fail with SIGPIPE (141) '
              'even when the check passes, which rejects a good APK. Capture '
              'the output into a variable and match it with a here-string '
              'instead:\n${offenders.join('\n')}',
        );
      });
    }

    test('both scripts still verify the release certificate and the ABI', () {
      // The fix must not have quietly dropped a check.
      const sha256 =
          '1abea51cfb66ae07c02a71d7a3f0ce9cfaab92ad67241bbd9ec4f5a0731107eb';
      for (final path in const <String>[
        'tool/release.sh',
        '.github/workflows/release.yml',
      ]) {
        final text = File('$repoRoot/$path').readAsStringSync();
        expect(text, contains(sha256), reason: '$path lost the cert pin');
        expect(
          text,
          contains('Android Debug'),
          reason: '$path lost the debug-signature refusal',
        );
        expect(
          text,
          contains(r'lib/$abi/libflutter.so'),
          reason: '$path lost the per-ABI payload check',
        );
      }
    });
  });

  group(
    'the ABI check idiom under pipefail',
    () {
      late Directory tmp;
      late String zipPath;

      setUpAll(() {
        tmp = Directory.systemTemp.createTempSync('allin_release_check');
        // A stand-in for a split APK: a zip carrying one ABI's libflutter.so.
        final lib = Directory('${tmp.path}/lib/arm64-v8a')
          ..createSync(recursive: true);
        // Big enough that the producer is still writing when a `grep -q` would
        // exit — a few bytes can fit in the pipe buffer and hide the SIGPIPE.
        File('${lib.path}/libflutter.so').writeAsStringSync('x' * 200000);
        for (var i = 0; i < 400; i++) {
          File(
            '${tmp.path}/lib/arm64-v8a/filler_$i.txt',
          ).writeAsStringSync('$i');
        }
        zipPath = '${tmp.path}/app-arm64-v8a-release.apk';
        final zipped = Process.runSync('zip', <String>[
          '-q',
          '-r',
          zipPath,
          'lib',
        ], workingDirectory: tmp.path);
        expect(zipped.exitCode, 0, reason: 'could not build the fixture zip');
      });

      tearDownAll(() => tmp.deleteSync(recursive: true));

      /// Runs [body] the way the release scripts run: bash, with pipefail on.
      ProcessResult runUnderPipefail(String body) =>
          Process.runSync('bash', <String>['-c', 'set -euo pipefail\n$body']);

      test('accepts an archive that contains the ABI', () {
        final result = runUnderPipefail('''
        entries=\$(unzip -Z1 "$zipPath")
        grep -qxF "lib/arm64-v8a/libflutter.so" <<<"\$entries"
      ''');
        expect(
          result.exitCode,
          0,
          reason:
              'the check rejected an archive that does contain the ABI; '
              'stderr: ${result.stderr}',
        );
      });

      test('rejects an archive that lacks the ABI', () {
        final result = runUnderPipefail('''
        entries=\$(unzip -Z1 "$zipPath")
        grep -qxF "lib/x86_64/libflutter.so" <<<"\$entries"
      ''');
        expect(
          result.exitCode,
          isNot(0),
          reason: 'the check passed an archive missing the ABI it claims',
        );
      });

      test('does not match a different ABI by prefix', () {
        // `-x` (whole line) keeps "lib/arm64-v8a/libflutter.so.bak" or a longer
        // ABI name from satisfying the check for a shorter one.
        final result = runUnderPipefail('''
        entries=\$(unzip -Z1 "$zipPath")
        grep -qxF "lib/arm64" <<<"\$entries"
      ''');
        expect(result.exitCode, isNot(0));
      });
    },
    skip: Platform.isWindows ? 'needs bash, zip and unzip' : null,
  );
}
