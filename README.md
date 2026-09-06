# All-In · Poker Dojo — mobile

The phone edition of [All-In](https://github.com/ganeshapp/poker), an offline-first, play-money
Texas Hold'em trainer: a sandbox table against readable bots, an inline EV coach that explains
every decision in plain English, chess-style drills graded by real charts and Nash tables, a 31-lesson
course, and honest stats — rebuilt in Flutter with a UX designed for one hand and a small screen.

Status: in development. See `docs/ARCHITECTURE.md`, `docs/DESIGN.md` and `docs/port/`.

## Development

```bash
flutter pub get
flutter run            # a connected phone or a booted emulator
flutter test
flutter analyze
```

Android release: `tool/release.sh` (needs `android/key.properties` pointing at the app's release
keystore). Tagging `vX.Y.Z` builds and publishes per-ABI APKs from CI.
