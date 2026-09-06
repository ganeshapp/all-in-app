#!/usr/bin/env bash
# Build per-ABI release APKs, verify each is signed with the All-In release
# keystore and really contains its ABI, and name them allin-<version>-<abi>.apk
# under build/release/. Mirrors .github/workflows/release.yml.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f android/key.properties ] || { echo "android/key.properties missing — release builds must be signed with allin-release.jks" >&2; exit 1; }
EXPECTED_SHA256="1abea51cfb66ae07c02a71d7a3f0ce9cfaab92ad67241bbd9ec4f5a0731107eb"
VERSION=$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *([^+]+).*/\1/')
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
APKSIGNER=$(ls "$SDK"/build-tools/*/apksigner | sort -V | tail -1)

flutter build apk --split-per-abi --release
mkdir -p build/release
for abi in arm64-v8a armeabi-v7a x86_64; do
  src="build/app/outputs/flutter-apk/app-$abi-release.apk"
  cert=$("$APKSIGNER" verify --print-certs "$src" | grep 'SHA-256 digest' | head -1)
  case "$cert" in *"Android Debug"*) echo "refusing: $src is debug-signed" >&2; exit 1;; esac
  echo "$cert" | grep -q "$EXPECTED_SHA256" || { echo "refusing: $src is not signed with allin-release.jks" >&2; exit 1; }
  unzip -l "$src" | grep -q "lib/$abi/libflutter.so" || { echo "refusing: $src lacks lib/$abi" >&2; exit 1; }
  cp "$src" "build/release/allin-$VERSION-$abi.apk"
  echo "ok  build/release/allin-$VERSION-$abi.apk  ($(du -h "$src" | cut -f1))"
done
