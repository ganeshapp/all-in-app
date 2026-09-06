# Port spec — Persistence, stats, settings, hand-history import/export, About

Subsystem id: `persistence-stats-settings`
Source app: All-In · Poker Dojo (React + TypeScript + Zustand), repo `/Users/gapp/Documents/Code/poker`, version **1.1.2** (git `1d16559`, 2026-08-02)
Target: Flutter/Dart mobile re-implementation. **This document is the only reference the porting engineer gets for this subsystem; nothing here requires opening the TypeScript.**

Source files covered (paths relative to the source repo):

| File | Lines | Role |
|---|---|---|
| `src/db/stats.ts` | 408 | Persistence layer: SQLite (Tauri SQL plugin) with localStorage fallback; schema v1→v4; stats, hands, guesses, decisions, imported hands, backup, reset |
| `src/lib/store.ts` | 65 | Minimal Zustand-style store factory (**unused** — nothing imports it; app uses the `zustand` package) |
| `src/store/statsStore.ts` | 79 | In-memory lifetime stats window + chart baseline; delegates writes to `db/stats` |
| `src/store/noteStore.ts` | 56 | Hand notes / bookmarks / tags (localStorage) |
| `src/store/reviewStore.ts` | 71 | Missed-drill review cards on an SRS schedule (localStorage) |
| `src/store/themeStore.ts` | 52 | Dark/light theme (localStorage) |
| `src/store/navStore.ts` | 20 | Tab navigation + one-shot lesson deep link (not persisted) |
| `src/store/goalStore.ts` | 75 | Daily activity counts, goal, streak (localStorage) — feeds the practice heatmap |
| `src/store/settingsStore.ts` | 62 | App settings + `coachThresholds` (localStorage) |
| `src/store/studyStore.ts` | 87 | Completed lessons + per-question quiz results (localStorage) |
| `src/lib/hhImport.ts` | 293 | PokerStars-dialect hand-history parser + imported-call analyzer |
| `src/lib/exportFile.ts` | 40 | Save-text-to-file (native → `~/Downloads`, web → blob download) and clipboard copy |
| `src/lib/openExternal.ts` | 15 | Open URL in system browser (native) or new tab (web) |
| `src/views/StatsView.tsx` | 582 | "Your progress" tab: KPIs, charts, coaching review, positional/style numbers, recent hands, import, heatmap, reset |
| `src/views/AboutView.tsx` | 251 | About tab: blurb, links, modes, methodology, roadmap, credits, update check |
| `src/views/SettingsView.tsx` | 182 | Settings tab |
| `src/components/stats/HandNoteEditor.tsx` | 117 | Note/tag editor modal for one hand |
| `src/components/stats/charts.tsx` | 72 | `LineChart` (cumulative winnings) and `MiniBars` (read accuracy) |
| `src/components/play/HandReplayModal.tsx` | 95 | Step-through replayer for a stored `HHHand` |
| `scripts/hhimport_test.ts` | 139 | 23 assertions — all pass |
| `src-tauri/src/lib.rs` | 93 | Tauri command layer (5 commands) + plugin registration |
| `src-tauri/tauri.conf.json` | 40 | Desktop app config (window, CSP, bundle) |

Also read (contracts this subsystem depends on, quoted where load-bearing): `src/game/handHistory.ts` (HHHand model, `formatHand`/`formatSession` export, `buildReplayFrames`), `src/lib/leaks.ts` (`DecisionRecord`, `leaksFromDecisions`), `src/lib/srs.ts`, `src/store/leakStore.ts`, `src/store/drillStore.ts` (persisted rating), `src/store/gameStore.ts` (where every stats record is *produced*; table options key), `src/components/ui/OnboardingModal.tsx` (onboarding flag), `src/components/play/SessionSummaryModal.tsx` (session export), `src/components/study/Quiz.tsx` (quiz key derivation), `src/lib/format.ts`, `src/engine/equity.ts` (`hashSeed`, `mulberry32`, `equityVsRandom` signature), `src/engine/notation.ts` (`cardsToLabel`), `src/engine/cards.ts` (`cardToInt`), `src/types/poker.ts`, `src/game/archetypes.ts` (names/colours), `src-tauri/capabilities/default.json`, `scripts/hh_test.ts` (41 assertions), `scripts/leaks_test.ts` (6), `scripts/srs_test.ts` (13), `TONE.md`, `README.md`.

Neighbouring subsystems that own things referenced here (they have their own port docs): the play loop / EV coach (`play-loop-and-coach.md` — produces `DecisionRecord`s, `HHHand`s, guess scores; owns `SessionSummaryModal` except its export bit), drills / SRS / leak queue (`drill-ux-srs-leaks.md` — owns `leakStore`, `reviewStore`'s consumer, `drillStore`), the math engine (`math-engine.md` — owns `equityVsRandom`, `hashSeed`, `mulberry32`, `evaluateCards`), study curriculum (`study-curriculum.md` — consumes `studyStore`). Where this subsystem *stores* their data, the exact byte-level shape is written out below so the port can share one storage layer.

There is **no Rust twin** for anything in this subsystem: `poker-core/` contains only hand evaluation and equity. The Tauri `lib.rs` merely forwards to it and adds one file-save command. Everything here is TypeScript-only and must be ported to Dart.

---

## 0. One-paragraph overview

All user data lives on-device. On desktop (Tauri) lifetime play statistics go into one SQLite file (`allin.db`, schema version 4, four tables); in a plain browser — or whenever any SQL call throws — the same data goes to two `localStorage` keys instead (`allin.stats.v1`, `allin.hands.v1`), silently and permanently for the rest of the session. Everything else (settings, theme, study progress, quiz results, daily activity, hand notes/tags, missed-drill review cards, coach-flagged leaks, drill rating, table options, onboarding flag) is *always* `localStorage`, one JSON value per key, all prefixed `allin.`. The Stats tab computes every number from an in-memory window of at most 800 hand records / 800 guesses / 800 decisions plus two lifetime counters (`hands_played`, `net_chips`), keeps the cumulative chart reconciled with the lifetime net via a `chartBase`, shows plain-language explanations for each stat, lists replayable recent hands (played and imported) with notes/tags, imports PokerStars-style `.txt` histories (parsed, stored as replayable hands that never touch stats, and scanned for clearly bad hero calls that become Review-queue leaks), offers a JSON backup, and a typed-confirmation reset. Sessions can be exported as PokerStars-style text. Settings hold five preferences and the coach strictness thresholds. About shows verbatim copy, a roadmap, credits and a passive GitHub release check.

---

## 1. Shared domain types (contracts consumed from other subsystems)

Cards are 2-character strings: rank in `2 3 4 5 6 7 8 9 T J Q K A`, suit in `c d h s` (e.g. `"Ah"`, `"Td"`, `"2c"`).

```ts
type Card = string;
type Position = "UTG" | "MP" | "CO" | "BTN" | "SB" | "BB";
type Street = "preflop" | "flop" | "turn" | "river" | "showdown";
type ActionType = "fold" | "check" | "call" | "bet" | "raise" | "post";
type Archetype = "TAG" | "LAG" | "Nit" | "Station";
type HandLabel = string;            // "AKs", "AKo", "TT"

interface PotResult { winners: number[]; amount: number; potLabel: string; }  // winners = seat ids

/* ---- Structured hand history (src/game/handHistory.ts) ---- */
interface HHAction {
  street: Street;
  seat: number;
  name: string;
  type: ActionType;
  amount: number;   // call: chips called; bet/raise: TOTAL committed on this street ("to")
  allIn: boolean;
}
interface HHSeat {
  seat: number;      // 0-based; 0 is hero in played hands
  name: string;
  stack: number;     // chips at the start of the hand
  isHero: boolean;
  position: Position;
}
interface HHHand {
  id: number;        // session-local hand number (restarts at 1 each session); imported: last 6 digits of the site id
  startedAt: number; // epoch ms — THE unique key for notes/tags and export ids
  button: number;    // seat index
  sb: number; bb: number;              // chips (imported: as written, may be fractional $)
  sbSeat: number; bbSeat: number;      // seat indices
  seats: HHSeat[];
  holes: Record<number, [Card, Card] | undefined>;   // seat -> hole cards (only known ones)
  actions: HHAction[];
  board: Card[];     // 0, 3, 4 or 5 cards
  potResults: PotResult[];
  heroNet: number;   // chips; imported hands: winnings only (approximate)
}

/* ---- Coach decision record (src/lib/leaks.ts) ---- */
interface DecisionRecord {
  verdict: "mistake" | "thin" | "ok" | "great" | "info";
  action: "fold" | "check" | "call" | "bet" | "raise" | "post";
  equity: number;      // 0..1
  potOdds: number;     // 0..1
  evBb: number;        // big blinds, signed
  street: string;      // Street value as string
  villainArchetype: string | null;
  position?: string | null;   // hero position (schema v2+)
  ts: number;          // epoch ms
}

/* ---- SRS state (src/lib/srs.ts) ---- */
interface SrsState { due: number; intervalDays: number; ease: number; reps: number; lapses: number; }

/* ---- Leak spot (src/engine/puzzles.ts) — produced by the coach AND by the HH import analyzer ---- */
interface DrillOption { action: "fold"|"check"|"call"|"bet"|"raise"; label: string; amount?: number; }
interface LeakSpot {
  id: string; street: Street; heroPos: Position; hole: [Card, Card]; board: Card[];
  pot: number; toCall: number; bb: number;      // coach leaks: chips + real bb; import leaks: already in bb with bb = 1
  oppActive: Position[]; options: DrillOption[]; best: DrillOption["action"];
  rationale: string; equity?: number; potOdds?: number; ts: number; srs?: SrsState;
}
```

`Puzzle` (stored inside review cards) is treated as an opaque JSON object by this subsystem; its identity fields used here are `kind`, `handLabel`, `board: Card[]`, `heroPos`.

Archetype display data used by the Stats tab (`src/game/archetypes.ts`):

| key | `name` | `color` |
|---|---|---|
| `TAG` | Tight-Aggressive | `#2f6fd0` |
| `LAG` | Loose-Aggressive | `#8a5cd1` |
| `Nit` | Nit | `#2faa66` |
| `Station` | Calling Station | `#d23b3b` |

---

## 2. Storage architecture (`src/db/stats.ts`)

### 2.1 Backend selection and fallback rules

```
type Backend = "sqlite" | "local";
module state: backend: Backend | null = null; lastError: string | null = null; db = null
```

`isNative()` (from `src/engine/engineClient.ts`) = `typeof window !== "undefined" && ("__TAURI_INTERNALS__" in window || "__TAURI__" in window)`, memoised. On mobile the equivalent is "always native" — the port should use SQLite unconditionally and keep the fallback only if it wants the same never-crash guarantee.

`ensureBackend()` (async, idempotent):
1. If `backend` already decided → return it.
2. If native: dynamically import the Tauri SQL plugin, `Database.load("sqlite:allin.db")` (file lives in the app's data dir, managed by the plugin), run the four `CREATE TABLE IF NOT EXISTS` statements + `INSERT OR IGNORE INTO user_stats (id) VALUES (1)` (see 2.2), then `migrate()`. On success `backend = "sqlite"`.
3. On any exception: `noteError("SQLite unavailable, using localStorage", e)` and fall through.
4. `backend = "local"`.

`noteError(context, e)` sets `lastError = "<context>: <String(e)>"` and `console.warn`s it. `backendInfo()` returns `{ backend, lastError }` (a diagnostics hook; no UI currently reads it).

**Fallback semantics (important invariant):** every write/read function first calls `ensureBackend()`; if it is `"sqlite"` it tries SQL inside try/catch; on *any* SQL error it notes the error, sets `backend = "local"` **for the rest of the process**, and then performs the localStorage version of the same operation. So a single failing statement permanently switches storage until restart; data written before the switch stays in SQLite and is invisible until the next successful SQLite start. The reads (`loadStats`) behave the same way.

### 2.2 SQLite schema

Database: `sqlite:allin.db` via `tauri-plugin-sql` v2 (feature `sqlite`). Capabilities granted to the main window (`src-tauri/capabilities/default.json`): `core:default`, `core:window:default`, `core:webview:default`, `opener:default`, `opener:allow-open-url`, `sql:default`, `sql:allow-load`, `sql:allow-execute`, `sql:allow-select`, `sql:allow-close`.

**Base DDL (schema v1, run on every start, all `IF NOT EXISTS`):**

```sql
CREATE TABLE IF NOT EXISTS user_stats (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  hands_played INTEGER NOT NULL DEFAULT 0,
  net_chips INTEGER NOT NULL DEFAULT 0,
  big_blind INTEGER NOT NULL DEFAULT 20
);
INSERT OR IGNORE INTO user_stats (id) VALUES (1);

CREATE TABLE IF NOT EXISTS hand_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  n INTEGER, net_bb REAL, pot_bb REAL,
  showdown INTEGER, won INTEGER, archetypes TEXT, ts INTEGER
);

CREATE TABLE IF NOT EXISTS range_guess (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  accuracy REAL, archetype TEXT, street TEXT, ts INTEGER
);

CREATE TABLE IF NOT EXISTS decisions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  verdict TEXT, action TEXT, equity REAL, pot_odds REAL,
  ev_bb REAL, street TEXT, archetype TEXT, ts INTEGER
);
```

**Migrations (`migrate()`), keyed on `PRAGMA user_version` (0 for a fresh file), `SCHEMA_VERSION = 4`:**

| from | statements (each `ALTER` wrapped in try/catch so a half-applied earlier run is harmless) | purpose |
|---|---|---|
| v < 2 | `ALTER TABLE hand_history ADD COLUMN position TEXT;` `ALTER TABLE hand_history ADD COLUMN hand_json TEXT;` `ALTER TABLE decisions ADD COLUMN position TEXT;` | hero position; full replayable hand payload |
| v < 3 | `ALTER TABLE hand_history ADD COLUMN saw_flop INTEGER;` | WTSD / W$SD denominators |
| v < 4 | `ALTER TABLE hand_history ADD COLUMN source TEXT;` | `'import'` for imported hands (never count toward stats); `NULL` for played |
| always | `PRAGMA user_version = 4;` | |

**Final column semantics**

`user_stats` (single row, id=1): `hands_played` lifetime count of played hands; `net_chips` lifetime hero net in **chips** (integer, `Math.round`ed per hand); `big_blind` — **never updated by any code path**; stays at the default 20. Every bb conversion of `net_chips` divides by this value.

`hand_history`: `n` session hand number; `net_bb` REAL hero net in bb; `pot_bb` REAL total pot in bb; `showdown` 0/1; `won` 0/1; `archetypes` JSON array text of `Archetype` strings (e.g. `["TAG","Nit"]`); `ts` epoch ms; `position` hero `Position` text or NULL; `hand_json` full `JSON.stringify(HHHand)` or NULL; `saw_flop` 0/1/NULL; `source` NULL (played) or `'import'`.

`range_guess`: `accuracy` REAL 0..1 (F1 of painted vs actual range), `archetype` text or NULL, `street` text, `ts`.

`decisions`: `verdict`, `action`, `equity` REAL, `pot_odds` REAL, `ev_bb` REAL, `street`, `archetype` (villain archetype or NULL), `position` (hero), `ts`.

No indexes beyond the primary keys. All reads order by `id DESC` with `LIMIT`.

### 2.3 localStorage fallback shapes

| key | value |
|---|---|
| `allin.stats.v1` | `StatsSnapshot` JSON: `{ handsPlayed: number, netChips: number, bigBlind: number, history: HandRecord[] (WITHOUT handJson), guesses: GuessRecord[], decisions: DecisionRecord[] }`. Arrays are chronological (oldest first) and each capped at 800 by dropping from the front. Default when missing/corrupt: `{ handsPlayed: 0, netChips: 0, bigBlind: 20, history: [], guesses: [], decisions: [] }`. |
| `allin.hands.v1` | `string[]` of `JSON.stringify(HHHand)` payloads, **most-recent-first**, capped at 100 (`LS_HANDS_CAP`); played and imported hands share this list. Default `[]`. |

Writes swallow quota errors silently (data is dropped).

### 2.4 Constants

| name | value | meaning |
|---|---|---|
| `LS_KEY` | `"allin.stats.v1"` | |
| `LS_HANDS_KEY` | `"allin.hands.v1"` | |
| `HISTORY_CAP` | `800` | rows loaded per table; in-memory window; local array cap |
| `LS_HANDS_CAP` | `100` | replayable hands kept in localStorage |
| `SCHEMA_VERSION` | `4` | |
| default `bigBlind` | `20` | chips |
| `loadRecentHands` default limit | `50` | StatsView passes `30` |
| backup hand limit | `100000` (sqlite) / `100` (local) | |

---

## 3. Persisted record types and exactly how the game loop fills them

```ts
interface HandRecord {
  n: number;            // table.handNumber
  netBb: number;        // heroNetChips / bigBlind
  potBb: number;        // sum(potResults.amount) / bigBlind
  showdown: boolean;    // summary.showdown.length > 0
  won: boolean;         // some potResult.winners includes 0 (hero seat)
  archetypes: Archetype[];  // every non-hero player with an archetype AND committedTotal > bigBlind
  position?: string | null; // hero's Position this hand
  sawFlop?: boolean;    // players[0].foldedStreet !== "preflop"  (true if hero never folded OR folded post-flop)
  handJson?: string;    // JSON.stringify(HHHand) — persisted, NOT loaded into the snapshot
  ts: number;           // Date.now() at hand end
}
interface GuessRecord { accuracy: number; archetype: Archetype | null; street: string; ts: number; }
interface StatsSnapshot {
  handsPlayed: number; netChips: number; bigBlind: number;
  history: HandRecord[]; guesses: GuessRecord[]; decisions: DecisionRecord[];
}
```

Producer (`gameStore.finalizeHand`, runs once per finished hand, in this order):
1. Close the in-progress `HHHand`: `board = table.board`, `potResults = summary.potResults`, `heroNet = summary.heroNetChips`, `holes[p.id] = p.hole` for **every** player (so the replayer can reveal all cards), append it to `session.history`, `handJson = JSON.stringify(hh)`.
2. `useGoals.record("hand")` (daily activity, §6.4).
3. If a summary exists: `useStats.recordHand(HandRecord, heroNetChips)` with the derivations in the type above. `archetypes` filter: `!p.isHero && p.archetype && p.committedTotal > bigBlind` — i.e. only opponents who put in more than one big blind (the BB post alone doesn't count; the SB post never does).

The `HHHand` itself is created at deal time with: `id = handNumber`, `startedAt = Date.now()`, `button`, `sb/bb` from the table, `sbSeat = seats===2 ? button : (button+1)%seats`, `bbSeat = seats===2 ? (button+1)%seats : (button+2)%seats`, `seats[] = players.map({seat: id, name, stack: stacksAtStart[id], isHero, position})`, `holes = {0: heroHole}`, empty `actions/board/potResults`, `heroNet 0`. Every applied action appends `{street, seat, name, type, amount, allIn}` where for a call `amount = callAmount`, `allIn = amount >= stack`; for bet/raise `amount = action.amount (total "to")`, `allIn = amount >= committed + stack`; fold/check `amount 0`.

`GuessRecord` producer (`gameStore.peek`): only when the user painted ≥ 1 hand label AND the bot has an archetype: `{ accuracy: F1 score (0..1), archetype: bot.archetype, street: guess.street, ts: Date.now() }`.

`DecisionRecord` producer (`gameStore.heroAction`, only when the coach is enabled and the review kind is `"decision"`): `{ verdict, action: a.type, equity: review.equity ?? 0, potOdds: review.potOdds ?? 0, evBb: (review.evChips ?? 0) / bigBlind, street: table.street, villainArchetype: review.villainArchetype ?? null, position: players[0].position, ts: Date.now() }`. When `verdict === "mistake"` a `LeakSpot` is also added to `leakStore` with `id = "<handNumber>-<street>-<Date.now()>"`, chips-denominated `pot/toCall` and `bb = bigBlind` (contrast with import leaks, §11.4).

---

## 4. Stats DB API (`src/db/stats.ts`) — function by function

All functions are `async`, never throw to callers (except `persistImportedHands`' local path which returns 0 on quota error).

### `loadStats(): Promise<StatsSnapshot>`
- local → `readLocal()` (parse `allin.stats.v1`, defaults on missing/corrupt).
- sqlite:
  1. `SELECT hands_played, net_chips, big_blind FROM user_stats WHERE id = 1;`
  2. `SELECT n, net_bb, pot_bb, showdown, won, archetypes, position, saw_flop, ts FROM hand_history WHERE source IS NULL ORDER BY id DESC LIMIT 800;` → reverse to chronological → map: `n:Number`, `netBb:Number`, `potBb:Number`, `showdown: !!`, `won: !!`, `archetypes: JSON.parse(text || "[]")`, `position: text || null` (empty string → null), `sawFlop: saw_flop == null ? undefined : !!saw_flop`, `ts:Number`. **`hand_json` is not loaded here.**
  3. `SELECT accuracy, archetype, street, ts FROM range_guess ORDER BY id DESC LIMIT 800;` → reverse → `{accuracy:Number, archetype: text || null, street:String, ts:Number}`.
  4. `SELECT verdict, action, equity, pot_odds, ev_bb, street, archetype, position, ts FROM decisions ORDER BY id DESC LIMIT 800;` → reverse → `{verdict: text || "ok", action: text || "call", equity, potOdds, evBb, street, villainArchetype: text || null, position: text || null, ts}`.
  5. Missing user_stats row → `handsPlayed 0, netChips 0, bigBlind 20`.
  6. Any error → `noteError("SQLite read failed, falling back")`, `backend = "local"`, return `readLocal()`.

### `persistHand(rec: HandRecord, netChipsDelta: number): Promise<void>`
- sqlite: `INSERT INTO hand_history (n, net_bb, pot_bb, showdown, won, archetypes, position, saw_flop, hand_json, ts) VALUES (?, …)` with `showdown/won` as 1/0, `archetypes` as `JSON.stringify`, `position ?? null`, `saw_flop` as `null | 1 | 0`, `hand_json ?? null`; then `UPDATE user_stats SET hands_played = hands_played + 1, net_chips = net_chips + ? WHERE id = 1;` with `Math.round(netChipsDelta)`. (Two statements, no transaction.) Return.
- on SQL error → note, switch to local, continue below.
- local: `s = readLocal(); s.handsPlayed += 1; s.netChips += Math.round(delta); push rec WITHOUT handJson; if length > 800 drop from front; writeLocal(s)`. Then if `handJson`: `hands = readLocalHands(); hands.unshift(handJson); save hands.slice(0, 100)` (quota errors ignored).

### `persistGuess(rec: GuessRecord)` / `persistDecision(rec: DecisionRecord)`
- sqlite: `INSERT INTO range_guess (accuracy, archetype, street, ts) VALUES (?,?,?,?)` / `INSERT INTO decisions (verdict, action, equity, pot_odds, ev_bb, street, archetype, position, ts) VALUES (?,…)` with `archetype = rec.villainArchetype`, `position = rec.position ?? null`.
- local: push onto the corresponding snapshot array, cap 800 from the front, write.

### `persistImportedHands(handJsons: string[]): Promise<number>`
- sqlite: for each payload, `INSERT INTO hand_history (n, net_bb, pot_bb, showdown, won, archetypes, position, saw_flop, hand_json, source, ts) VALUES (0, 0, 0, 0, 0, '[]', NULL, NULL, ?, 'import', ?)` with `[json, Date.now()]`. Return `handJsons.length`. On error → note `"SQLite import write failed"`, switch to local, continue.
- local: `hands = readLocalHands(); hands.unshift(...handJsons)` (the imported batch goes to the front, keeping its own order), save `slice(0, 100)`, return `handJsons.length`; on error return `0`.
- Imported rows never affect `user_stats` and are excluded from `loadStats` by `source IS NULL`.

### `loadRecentHands(limit = 50): Promise<string[]>`
- sqlite: `SELECT hand_json FROM hand_history WHERE hand_json IS NOT NULL ORDER BY id DESC LIMIT <limit>;` → array of JSON strings, most recent first. **Includes imported hands** (no `source` filter). On error → note `"SQLite hand read failed"` (does *not* switch backend) and fall through.
- local: `readLocalHands().slice(0, limit)`.

### `exportBackup(): Promise<string>`
`JSON.stringify({ exportedAt: Date.now(), backend: b, snapshot: await loadStats(), hands: await loadRecentHands(b === "sqlite" ? 100000 : 100) }, null, 0)` — compact JSON, no indentation. Note the snapshot is itself window-limited (800 per table) and `handsPlayed/netChips` are the lifetime totals. Nothing ever *imports* this file; it is a human-held safety copy.

### `resetStats(): Promise<void>`
- sqlite: `DELETE FROM hand_history;` (played **and** imported), `DELETE FROM range_guess;`, `DELETE FROM decisions;`, `UPDATE user_stats SET hands_played = 0, net_chips = 0 WHERE id = 1;` (big_blind untouched). Return. On error (silently) switch to local and continue.
- local: write the default empty snapshot to `allin.stats.v1`; `removeItem("allin.hands.v1")`.
- Does **not** touch notes, tags, leaks, review cards, goals, study progress, quiz results, settings, theme, drill rating, table options or the onboarding flag.

---

## 5. Stats store (`src/store/statsStore.ts`, `useStats`)

State: `handsPlayed 0, netChips 0, bigBlind 20, history [], guesses [], decisions [], chartBase 0, loaded false`.

- `init()`: if `loaded` return; `s = await loadStats()`; `historyBb = Σ history.netBb`; set `{...s, chartBase: s.netChips / s.bigBlind - historyBb, loaded: true}`. Called once from the Play tab's mount effect (`PlayView`), i.e. the app boots into Play so stats are loaded before the Stats tab is opened. (If the port opens Stats first, call `init()` there too — the guard makes it idempotent.)
- `recordHand(rec, delta)`: `next = [...history, rec]`; `dropped = next.length > 800 ? next.slice(0, next.length - 800) : []`; set `handsPlayed + 1`, `netChips + Math.round(delta)`, `history = next.slice(-800)`, `chartBase += Σ dropped.netBb`; then fire-and-forget `persistHand(rec, delta)`. The in-memory record keeps `handJson` (harmless).
- `recordGuess(rec)`: `guesses = [...guesses, rec].slice(-800)`; `persistGuess`.
- `recordDecision(rec)`: `decisions = [...decisions, rec].slice(-800)`; `persistDecision`.
- `clear()`: `await resetStats()`; set `handsPlayed 0, netChips 0, history [], guesses [], decisions [], chartBase 0` (`bigBlind` and `loaded` unchanged).

**Invariant:** `chartBase + Σ history.netBb == netChips / bigBlind` at all times (up to float error), so the cumulative chart's last point always equals the "Net" KPI regardless of how many old hands are outside the 800-row window.

---

## 6. Complete localStorage key catalogue and per-store specs

Every key, its owner, JSON shape, default, cap, and when it is written. All loaders wrap `JSON.parse` in try/catch and return the default on any failure; all savers swallow quota errors.

| key | owner | shape | default | cap / notes |
|---|---|---|---|---|
| `allin.stats.v1` | `db/stats.ts` (fallback only) | `StatsSnapshot` (§2.3) | empty snapshot | 800 per array |
| `allin.hands.v1` | `db/stats.ts` (fallback only) | `string[]` of HHHand JSON, newest first | `[]` | 100 |
| `allin.settings.v1` | `settingsStore` | `AppSettings` object (§6.1) | all defaults | merged over defaults on load |
| `allin.theme` | `themeStore` | raw string `"dark"` or `"light"` (not JSON) | `"dark"` | |
| `allin.goals.v1` | `goalStore` | `{ "<YYYY-MM-DD>": { drills: number, hands: number } }` | `{}` | unbounded |
| `allin.study.v1` | `studyStore` | `string[]` of completed lesson ids | `[]` | |
| `allin.quiz.v1` | `studyStore` | `{ "<qKey>": { correct, wrong, lastCorrect, ts } }` | `{}` | |
| `allin.handnotes.v1` | `noteStore` | `{ "<startedAt>": { note: string, tags: string[], ts: number } }` | `{}` | unbounded |
| `allin.review.v1` | `reviewStore` | `ReviewCard[]` = `{ id, puzzle: Puzzle, srs: SrsState }[]`, newest first | `[]` | 80 |
| `allin.leaks.v1` | `leakStore` | `LeakSpot[]`, newest first | `[]` | 60 |
| `allin.drills.v1` | `drillStore` | `{ rating, solved, correct, streak, best }` | `{1000,0,0,0,0}` | valid only if `rating` is a number |
| `allin.table.v1` | `gameStore` | `{ seats: 2\|6\|9, ante: 0\|5 }` | `{6, 0}` | sanitised on load |
| `allin.onboarded.v1` | `OnboardingModal` | raw string `"1"` | absent | presence == seen |

### 6.1 Settings (`src/store/settingsStore.ts`, `useSettings`)

```ts
type CoachStrictness = "relaxed" | "standard" | "strict";
type SimQuality = "standard" | "high";
interface AppSettings {
  fourColorDeck: boolean;     // ♠ black · ♥ red · ♦ blue · ♣ green
  reducedMotion: boolean;     // disable animations (also honours OS prefers-reduced-motion independently)
  coachStrictness: CoachStrictness;
  simQuality: SimQuality;     // Monte-Carlo effort for coach verdicts
  realisticReveal: boolean;   // hide folded players' cards at hand end
}
const DEFAULTS = { fourColorDeck: false, reducedMotion: false, coachStrictness: "standard", simQuality: "standard", realisticReveal: false };
```

- load: `{ ...DEFAULTS, ...JSON.parse(localStorage["allin.settings.v1"] || "{}") }` (unknown keys survive; missing keys default).
- `update(partial)`: merge into state, then write the whole settings object (minus the `update` function) back to the key.
- `coachThresholds(strictness)` → `{ mistakeBb, foldFlagBb }`:

| strictness | `mistakeBb` (a decision with EV below this is a blocking "mistake") | `foldFlagBb` (a fold that gives up more than this EV is flagged) |
|---|---|---|
| `relaxed` | −0.6 | 2.5 |
| `standard` | −0.3 | 1.5 |
| `strict` | −0.15 | 1.0 |

Consumers: `gameStore` reads `coachThresholds(coachStrictness)` and `baseIters = simQuality === "high" ? 4000 : 1600` per verdict; `App` adds CSS classes `four-color` (overrides `--suit-d: #2f7fd6; --suit-c: #2fa066`) and `reduce-motion` (`animation: none; transition: none` on everything); `Seat`/`ResultOverlay` read `realisticReveal`.

### 6.2 Theme (`src/store/themeStore.ts`, `useTheme`)

`type Theme = "dark" | "light"`. Load: value of `allin.theme` if exactly `"light"` or `"dark"`, else `"dark"`. Applied **at module import time** (before first paint) by toggling the `light` class on `<html>`. `toggle()` flips, applies, persists; `set(theme)` applies, persists, sets. Surfaces: sidebar button (`Dark mode`/`Light mode` + "switch"; icon `moon`/`sun`) and the Settings "Theme" segmented control (both just call `toggle`).

### 6.3 Navigation (`src/store/navStore.ts`, `useNav`) — not persisted

`type Tab = "play" | "drills" | "study" | "stats" | "settings" | "about"`; state `{ tab: "play", lessonId: null }`; `go(tab, lessonId?)` sets both (`lessonId ?? null`); `consumeLesson()` clears `lessonId` (StudyView consumes the one-shot deep link). Sidebar order and labels: Play, Drills, Study, Stats, Settings, About.

### 6.4 Daily goals / activity (`src/store/goalStore.ts`, `useGoals`)

Constants: `DAILY_DRILL_GOAL = 20`, `DAILY_HAND_GOAL = 30`, `day = 86_400_000` ms.

`dayKey(ts)` = local-time `YYYY-MM-DD` (`getFullYear`, `getMonth()+1`, `getDate()`, zero-padded to 2).

`metGoal(day?)` = `!!day && (day.drills >= 20 || day.hands >= 30)`.

- `record(kind: "drill" | "hand")`: increments today's `drills` or `hands` (creating `{drills:0, hands:0}` if absent), saves whole map.
- `today()` → today's entry or `{0,0}`.
- `streak()`: `t = now; if (!metGoal(a[dayKey(t)])) t -= day;` then `while (metGoal(a[dayKey(t)])) { n++; t -= day; }` → consecutive goal-met days ending today (if met) or yesterday. Subtracting 86 400 000 ms across a DST change can skip/repeat a calendar day — accepted quirk.

Producers: `gameStore.finalizeHand` → `record("hand")` once per finished hand (even if no summary); `drillStore.answer` → `record("drill")` per answered drill (all modes).

### 6.5 Study progress (`src/store/studyStore.ts`, `useStudy`)

- `completed: string[]` (lesson ids) from `allin.study.v1`. `complete(id)` appends if absent; `toggle(id)` adds/removes. Both save the array.
- `quizResults: Record<string, QuizStat>` from `allin.quiz.v1`, `QuizStat = { correct: number; wrong: number; lastCorrect: boolean; ts: number }`. `recordQuiz(qKey, correct)`: `prev = results[qKey] ?? {0,0,false,0}`; store `{ correct: prev.correct + (correct?1:0), wrong: prev.wrong + (correct?0:1), lastCorrect: correct, ts: Date.now() }`.
- `qKey` is derived by the Quiz component as `String(hashSeed(question.q))` — FNV-1a 32-bit of the question text (§11.4 gives the hash). Pinned: `hashSeed("Which beats which?") = 1415407767`, `hashSeed("") = 2166136261`, `hashSeed("a") = 3826002220`. Dart must reproduce this hash exactly (UTF-16 code units, `Math.imul` semantics) or migrate the key.

### 6.6 Hand notes, bookmarks, tags (`src/store/noteStore.ts`, `useNotes`, `HandNoteEditor`)

```ts
const PRESET_TAGS = ["review later", "bluff-catch", "thin value", "weird line", "big pot"];
interface HandNote { note: string; tags: string[]; ts: number; }
const handKey = (startedAt: number) => String(startedAt);   // notes keyed by HHHand.startedAt
```

- `set(key, note, tags)` → `notes[key] = { note, tags, ts: Date.now() }`, save. `remove(key)` deletes, save.
- A "bookmark" is simply the existence of a note entry (with text and/or tags). Notes work identically for played, imported, and session-summary hands; the key is the hand's `startedAt` (unique per hand; for imports it is the parsed timestamp, so two imported hands with identical timestamps share a note).

`HandNoteEditor` modal (opened from the Stats "Recent hands" list and the session summary):
- Title `Note on hand #<hand.id>`, description `new Date(hand.startedAt).toLocaleString()`.
- Textarea (4 rows) placeholder: `What happened, and what's the lesson? (e.g. 'called the river with a bluff-catcher vs a Nit — their range had no bluffs')`
- Section label `Tags`; chips for the 5 presets followed by any custom tags already on this note; tap toggles membership. Custom input placeholder `+ custom, Enter`; on Enter with non-blank text: `toggleTag(text.trim().toLowerCase())` and clear the input.
- Left: `Remove note` button (only when a note already exists) → `remove(key)` + close. Right: `Cancel`, `Save` (disabled when `!text.trim() && tags.length === 0`) → `set(key, text.trim(), tags)` + close.
- On open (key change) the editor loads the existing note text and tags.

### 6.7 Review cards — missed drills (`src/store/reviewStore.ts`, `useReview`) and SRS (`src/lib/srs.ts`)

`CAP = 80`. `ReviewCard = { id: string; puzzle: Puzzle; srs: SrsState }`.

- `addMiss(p)`: `key = `${p.kind}|${p.handLabel}|${p.board.join("")}|${p.heroPos}``; if a card with that id exists → no-op; else prepend `{ id: key, puzzle: p, srs: newSrs(Date.now()) }` and `slice(0, 80)`, save.
- `review(id, correct)`: map the card to `srs = reviewSrs(srs, correct, Date.now())`, then **remove** it if `correct && isGraduated(srs)`; save.
- `dueCards(now)` = cards with `isDue(srs, now)`.
- `clear()` → `[]`.

SRS (SM-2 family, tuned small), `RETIRE_REPS = 3`:
```
newSrs(now)              = { due: now, intervalDays: 0, ease: 2.3, reps: 0, lapses: 0 }
reviewSrs(s, false, now) = { due: now + 10*60_000, intervalDays: 0, ease: max(1.3, s.ease - 0.2), reps: 0, lapses: s.lapses + 1 }
reviewSrs(s, true, now)  : intervalDays = s.reps==0 ? 1 : s.reps==1 ? 3 : max(4, round(s.intervalDays * s.ease))
                           → { due: now + intervalDays*86_400_000, intervalDays, ease: min(3, s.ease + 0.05), reps: s.reps + 1, lapses: s.lapses }
isDue(s, now)            = !s || s.due <= now
isGraduated(s)           = s.reps >= 3
```
(Full drill-side behaviour is in `drill-ux-srs-leaks.md`; the shapes above are what this storage layer must persist byte-for-byte.)

### 6.8 Leaks (`src/store/leakStore.ts`, `useLeaks`) — storage contract only

`CAP = 60`. Load: parse array; any spot without `srs` gets `srs = newSrs(spot.ts ?? Date.now())` (pre-scheduling records become due immediately). `add(spot)`: prepend `{...spot, srs: spot.srs ?? newSrs(now)}`, `slice(0, 60)`, save — **no de-duplication by id**. `review(id, correct)` same retire rule as review cards. `dueSpots(now)`. `clear()`. Producers: the coach (§3) and the HH import analyzer (§11.4).

### 6.9 Drill rating (`allin.drills.v1`) — storage contract only

`{ rating: number; solved: number; correct: number; streak: number; best: number }`, default `{ rating: 1000, solved: 0, correct: 0, streak: 0, best: 0 }`; the stored object is accepted only if `typeof rating === "number"`. Written after every graded non-Review drill answer and by `seedRating(rating)` (placement test: score ≤ 2 → 900, ≤ 5 → 1050, else 1250; only `rating` changes). The Settings "Run again" button (§14) re-triggers the placement flow by deleting the onboarding flag, not this key.

### 6.10 Table options (`allin.table.v1`)

`interface TableOptions { seats: 2 | 6 | 9; ante: number }`. `loadTableOptions()`: `{ seats: v.seats === 2 || v.seats === 9 ? v.seats : 6, ante: v.ante === 5 ? 5 : 0 }` (anything else sanitised to 6-max / no ante). Saved on every `newSession(opts)` with the options actually used.

### 6.11 Onboarding flag (`allin.onboarded.v1`)

`hasOnboarded()` = `localStorage.getItem(key) === "1"`; **if localStorage throws, returns `true`** (never block the app). `markOnboarded()` sets `"1"` when the modal is closed/skipped/finished. `OnboardingModal` mounts in `App` and opens iff `!hasOnboarded()`.

### 6.12 `src/lib/store.ts`

A 65-line `createStore(initializer)` returning a hook with `getState/setState/subscribe` on `useSyncExternalStore`. **No file imports it**; the app uses `zustand`'s `create`. Nothing to port.

---

## 7. Stats tab (`src/views/StatsView.tsx`) — every number and every string

Data: `handsPlayed, netChips, bb (= bigBlind), history, guesses, decisions, chartBase` from `useStats`; `activity` from `useGoals`; `notes` from `useNotes`; `recent: HHHand[]` from `loadRecentHands(30)` (parsed, corrupt rows skipped; reloaded whenever `handsPlayed` changes or after an import).

Page header: h1 **`Your progress`**; subtitle **`Decisions, not results — but we track both.`**; ghost button `Reset` (icon `refresh`) opens the reset modal (§7.11) with the text field cleared.

### 7.1 Derived values

```
netBb      = netChips / bb
bb100      = handsPlayed > 0 ? (netBb / handsPlayed) * 100 : 0
cumulative = running sum: acc = chartBase; for h in history: acc += h.netBb; push acc     (length == history.length)
sd         = history.filter(showdown);  sdWin = sd.length ? count(sd.won) / sd.length : 0
avgAcc     = guesses.length ? mean(guesses.accuracy) : 0
archAgg    = for a in [TAG, LAG, Nit, Station]: hs = history where archetypes includes a;
             { a, hands: hs.length, net: Σ hs.netBb / max(1, h.archetypes.length) }     // multiway split → per-style nets sum to the true total
maxArchHands = max(1, ...archAgg.hands)
leak       = leaksFromDecisions(decisions)            (§8)
allLeaks   = leak.leaks + [ "Your range reads are often off — drill Guess & Peek and the Range-Building exercise." ] if guesses.length >= 5 && avgAcc < 0.5
recentMistakes = decisions.filter(verdict == "mistake").slice(-5).reverse()      // newest first, max 5
```

### 7.2 KPI row (5 tiles: label small-caps, value mono, optional sub)

| label | value | sub | tone |
|---|---|---|---|
| `Hands` | `String(handsPlayed)` | — | neutral |
| `Net` | `${fmtSigned(netBb)} bb` | — | good if `netBb >= 0` else bad |
| `Win rate` | `fmtSigned(bb100)` | `bb/100 (lifetime)` | good if `bb100 >= 0` |
| `Showdown` | `fmtPct(sdWin)` | `won` | neutral |
| `Read acc.` | `guesses.length ? fmtPct(avgAcc) : "—"` | `${guesses.length} reads` | neutral |

Tooltip on the Win-rate tile (title line `bb / 100`): **`Big blinds won per 100 hands — the standard, stake-independent win-rate. Roughly: +5 is a strong winner; expect wild swings under a few thousand hands.`**

### 7.3 Card `Cumulative winnings (bb)` (icon `stats`)

`LineChart(values = cumulative, color = netBb >= 0 ? good : bad, unit = "")`. Algorithm (`charts.tsx`):
- If `values.length < 2` → render centred text **`Play a few hands to see your trend.`** (170 px tall).
- Else: viewBox `640 × height(170)`, `pad = 28`; `min = Math.min(0, ...values)`, `max = Math.max(0, ...values)`, `span = max - min || 1`; `x(i) = pad + i/(n-1) * (W-2pad)`, `y(v) = H - pad - (v-min)/span * (H-2pad)`; polyline through all points (1-decimal coords), an area fill closed down to `y(min)` with a vertical gradient (colour at 28 % → 0 % opacity), a dashed zero line at `y(0)` (`rgba(255,255,255,0.18)`, dash `4 4`), a 4 px dot on the last point, and labels `max.toFixed(0)+unit` at top-left (y=16) and `min.toFixed(0)+unit` at bottom-left (y=H−6). Stroke width 2.5, round joins/caps. `preserveAspectRatio="none"`.

### 7.4 Card `Range-read accuracy` (icon `eye`)

`MiniBars(values = guesses.map(accuracy))`: if empty → **`No reads logged yet.`** (120 px). Else take the last 30, one bar each, height `max(3, v*100)%`, colour `--info` (unless overridden), opacity `0.55 + v*0.45`, hover title `${Math.round(v*100)}%`. Caption: **`Last ${Math.min(30, guesses.length)} Peek scores.`**

### 7.5 Card `Hands vs each style` (icon `target`)

One row per archetype in order TAG, LAG, Nit, Station: colour dot + `ARCHETYPES[a].name`; right: `${fmtSigned(x.net)} bb` (good/bad by sign); below: progress bar `value = x.hands`, `max = maxArchHands`, tinted with the archetype colour.

### 7.6 Card `Coaching review` (icon `coach`)

- If `leak.total === 0`: **`Play with the EV Coach on and your reviewed decisions, leaks and mistakes will appear here.`**
- Else: three verdict boxes (big mono number + small-caps label): `Mistakes` = `leak.mistakes` (bad colour), `Thin spots` = `leak.thin` (warn colour), `Great plays` = `leak.great` (good colour). Then each `allLeaks` string as a bullet with a `bolt` icon. Then, if `recentMistakes` non-empty, heading **`Recent −EV decisions`** (note the true minus sign U+2212) and one row per record: left (CSS-capitalised) `${d.street} ${d.action}` + (` vs ${d.villainArchetype}` if set); right mono bad-coloured `${Math.round(d.equity*100)}% eq · ${Math.round(d.potOdds*100)}% needed · ${fmtSigned(d.evBb)} bb`.

### 7.7 Card `Winnings by position` (icon `target`)

`POS = ["UTG","MP","CO","BTN","SB","BB"]`; per position: `hs = history.filter(position === pos)`, `net = Σ netBb`, `rate = hs.length ? net/hs.length*100 : 0` (bb/100), `hands = hs.length`. `tracked = Σ hands`.
- If `tracked === 0`: **`Position is tracked from every new hand you play.`**
- Else `maxAbs = max(1, ...|rate|)`; each row: bold position label (w 9), a centred diverging bar (track with a centre hairline at 50 %; filled segment of width `|rate|/maxAbs*50 %`, starting at 50 % for positive, at `50 − width` for negative; good/bad colour), right mono `hands ? `${fmtSigned(rate, 0)}/100` : "—"`, then faint `${hands}h`.
- Footnote: **`Everyone wins most from the button (acting last) and loses from the blinds (forced money, acting first). Worry only if your early-position numbers are deep red — that usually means playing too many weak hands up front.`**

### 7.8 Card `Style numbers` (icon `stats`)

```
flops   = history.filter(sawFlop === true)                     // records without the field (pre-v3) are excluded
wtsd    = flops.length ? count(history where showdown && sawFlop) / flops.length : null
sdHands = history.filter(showdown)
wsd     = sdHands.length ? count(sdHands.won) / sdHands.length : null
aggro   = count(decisions where action ∈ {bet, raise})
calls   = count(decisions where action == call)
af      = calls > 0 ? aggro / calls : null
```
Three rows, each a dotted-underlined label with a hover tooltip (title = label, body = blurb, footer `Healthy range: <band>`) and a mono value (`"—"` when null):

| label | value | band | blurb (verbatim) |
|---|---|---|---|
| `Went to showdown (WTSD)` | `fmtPct(wtsd)` | `24–32%` | `Of the hands where you saw a flop, how often you reached showdown. Too high = calling down too much; too low = giving up too easily.` |
| `Won at showdown (W$SD)` | `fmtPct(wsd)` | `49–56%` | `When you did reach showdown, how often you won. Very high can ironically mean you only call when it's obvious — you might be folding too many winners.` |
| `Aggression factor (AF)` | `af.toFixed(1)` | `2.0–4.0` | `Your bets + raises divided by your calls, over coached decisions. Below ~1.5 means you call far more than you pressure — the most common beginner leak.` |

Footnote: **`Small samples swing wildly — treat these as a mirror after a few hundred hands, not a verdict after ten.`**

### 7.9 Card `Recent hands` (icon `play`)

Header right: a file-picker button labelled **`Import hands (.txt)`** accepting `.txt,text/plain`; choosing a file runs the import flow (§11.5) and clears the input so the same file can be re-picked. Below the header an info banner shows `importMsg` when set.

Tag filter: `allTags = unique(flatMap(all notes → tags))` (across *all* notes, not just visible hands). If any exist, a chip row: `all` (selected when no filter) then one chip per tag; tapping a selected tag clears the filter. `rows = tagFilter ? recent.filter(h => notes[handKey(h.startedAt)]?.tags.includes(tagFilter)) : recent`.

Empty states: with a filter **`No hands carry that tag among the recent ones.`**; otherwise **`Finished hands appear here and stay replayable after a restart.`**

Row (scroll box max 280 px), most recent first: a button `Hand #${h.id} · ${new Date(h.startedAt).toLocaleString()}` (+ a small `imported` badge when `h.imported === true`) that opens the replayer (§10); mono `${fmtSigned(h.heroNet / h.bb)} bb` good/bad; a `book` icon button (gold when a note exists; title `Edit note` / `Add a note / tag`; aria-label `Edit note` / `Add note`) opening the note editor. If the note has text or tags, a second line shows each tag as a gold chip then the note text truncated to one line.

### 7.10 Card `Practice` (icon `bolt`) — the practice heatmap

```
weeks = 16; DAY = 86_400_000
today = local midnight of now (new Date(y, m, d).getTime())
for i from weeks*7-1 (=111) down to 0:
  t = today - i*DAY;  key = local YYYY-MM-DD of t;  day = activity[key]
  cells.push({ key, count: (day?.drills ?? 0) + (day?.hands ?? 0), met: metGoal(day) })
active = count(cells where count > 0)
```
Layout: CSS grid, **7 rows, column-major flow** (`grid-flow-col grid-rows-7`) → each column is one week, filling top-to-bottom, oldest column left, today is the last cell of the last column; 112 cells of 11 × 11 px, 3 px gap, 3 px radius. Cell colour: `met` → `--gold`; `count > 0` → `color-mix(in srgb, var(--gold) 35%, var(--ink-600))`; else `--ink-700`. Cell tooltip: `${key}: ${count} reps${met ? " · goal met" : ""}`.
Caption: if `active === 0` **`Each day you practice lights a square; hitting the daily goal (20 drills or 30 hands) makes it gold.`** else **`${active} active day${active === 1 ? "" : "s"} in the last 16 weeks. Gold = daily goal met. Consistency beats bingeing.`**

### 7.11 Reset modal (typed confirmation with a backup offer)

Title **`Reset all progress?`**; description **`This permanently deletes your lifetime stats, decisions, reads, and saved hands.`**
1. Secondary full-width button **`Download a backup first`** (icon `stats`) → `saveText(`allin-backup-${new Date().toISOString().slice(0, 10)}.json`, await exportBackup())`; the returned message (§13.1) is shown beneath in faint text.
2. Label **`Type RESET to confirm:`** (with `RESET` in bold mono) and a text input.
3. Buttons: ghost **`Cancel`**; danger **`Erase everything`**, enabled only when the input is exactly `RESET` (case-sensitive) → `await useStats.clear()` then close.

The modal opens with the input and backup message cleared. Reset does **not** clear notes/tags, leaks, review cards, goals, study, settings (§4 `resetStats`).

---

## 8. Leak detection rules (`src/lib/leaks.ts`, `leaksFromDecisions`)

```
dec = decisions.filter(verdict !== "info")          // n = dec.length
mistakes = dec where verdict == "mistake"; thin = count(verdict == "thin"); great = count(verdict == "great")
foldMistakes = count(mistakes where action == "fold"); callMistakes = count(mistakes where action == "call")
leaks = []
if n >= 8:
  if foldMistakes >= 3 && foldMistakes / n > 0.12 → "You fold too often when you're getting the right price — look for more +EV calls."
  if callMistakes >= 3 && callMistakes / n > 0.12 → "You call too wide for the pot odds — fold your weakest hands more."
  if mistakes.length == 0                          → "No clear −EV mistakes flagged — solid discipline. Keep refining the thin spots."
return { total: n, mistakes: mistakes.length, thin, great, foldMistakes, callMistakes, leaks }
```
(Order of the strings is as listed; the third uses U+2212 minus.) Tests in §17.3.
