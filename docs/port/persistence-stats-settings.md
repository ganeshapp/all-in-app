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

---

## 9. Hand-history text export — the round-trip contract

Export lives in `src/game/handHistory.ts` (`formatHand`, `formatSession`, `exportHandId`). The **line-by-line emitter is pinned in `game-and-bots.md` §7.3** and must not be re-derived here; what this subsystem owns is (a) the two call sites, (b) the file/clipboard plumbing (§13), and (c) the hard requirement that the importer of §11 parses this exact output back (`scripts/hhimport_test.ts` asserts the round trip, §17.2).

```
exportHandId(h) = h.startedAt * 100 + (h.id % 100)      // globally unique; session ids restart at 1
formatSession(hands) = hands.map(formatHand).join("\n\n\n")
```

The `"\n\n\n"` join is load-bearing: §11.2 splits blocks on `\n{2,}` followed by `PokerStars `. A Dart port that joins with a single `\n` produces a file its own importer reads as one giant unparseable block.

Call sites (both in `SessionSummaryModal`, whose other behaviour belongs to `play-loop-and-coach.md`):

| button | action | message shown in the modal |
|---|---|---|
| `Copy` (ghost, disabled at 0 hands) | `copyText(formatSession(session.history))` (§13.2) | `Hand history copied to clipboard.` on true, `Copy failed.` on false |
| `Export hands (.txt)` (secondary, disabled at 0 hands) | `saveText(name, formatSession(session.history))` (§13.1); `name = "all-in-session-" + new Date(session.startedAt \|\| Date.now()).toISOString().slice(0, 19).replace(/[:T]/g, "-") + ".txt"` → e.g. `all-in-session-2026-09-06-19-20-31.txt` | the `message` field returned by `saveText` verbatim (§13.1) |

The Stats tab has **no** export button — only `Import hands (.txt)` (§11.5) and the JSON backup inside the reset modal (§7.11).

### 9.1 Canonical fixture (generated by running the real exporter)

This is the exact output of `formatHand` for the `scripts/hhimport_test.ts` hand (6-max, `startedAt = new Date(2026, 5, 19, 12, 0, 0)`, ids/stacks as in §17.2). Use it verbatim as the Dart exporter's golden file **and** as the importer's round-trip input.
Caveat: the fixture builds `startedAt` with the **local** `Date` constructor, so the printed wall-clock text is stable everywhere but the epoch value — and therefore the `#178183800000007` id — depends on the machine's time zone (this capture was produced at UTC+9). Pin the epoch your own test environment produces, or build the fixture from a literal epoch:

```
PokerStars Hand #178183800000007: Hold'em No Limit (10/20) - 2026/06/19 12:00:00 ET
Table 'All-In Dojo' 6-max Seat #1 is the button
Seat 1: You (2000 in chips)
Seat 2: Ivey (2000 in chips)
Seat 3: Polk (2000 in chips)
Seat 4: Dwan (2000 in chips)
Seat 5: Selbst (2000 in chips)
Seat 6: Galfond (2000 in chips)
Ivey: posts small blind 10
Polk: posts big blind 20
*** HOLE CARDS ***
Dealt to You [As Ks]
Selbst: folds
Galfond: folds
Dwan: raises 40 to 60
You: calls 60
Ivey: folds
Polk: folds
*** FLOP *** [Ah Kd 7c]
Dwan: bets 80
You: calls 80
*** TURN *** [Ah Kd 7c] [2s]
Dwan: checks
You: checks
*** RIVER *** [Ah Kd 7c 2s] [9h]
Dwan: checks
You: bets 120
Dwan: calls 120
*** SHOW DOWN ***
You: shows [As Ks] (two pair, Aces and Kings)
Dwan: shows [Qh Qd] (a pair of Queens)
You collected 520 from pot
*** SUMMARY ***
Total pot 520 | Rake 0
Board [Ah Kd 7c 2s 9h]
Seat 1: You (button) showed [As Ks] and won (520) with two pair, Aces and Kings
Seat 2: Ivey (small blind) folded before Flop
Seat 3: Polk (big blind) folded before Flop
Seat 4: Dwan showed [Qh Qd] and lost with a pair of Queens
Seat 5: Selbst folded before Flop
Seat 6: Galfond folded before Flop
```

(`178183800000007` = `1781838000000 * 100 + 7`; the importer turns it back into `id = 7` by taking the last 6 digits — §11.3 step 11.)

---

## 10. Hand replayer surface (`src/components/play/HandReplayModal.tsx`)

The frame model (`ReplayFrame`, `buildReplayFrames`) is pinned in `play-loop-and-coach.md` §21 — do not re-derive it. This section is only the modal that the Stats tab (§7.9) and the session summary open with `<HandReplayModal hand={replay} onClose={…} />`; `hand === null` renders nothing.

- `Modal maxWidth={760}`, title `` `Hand #${hand.id} replay` ``, description = the **current frame's `text`** (so the caption changes as you step).
- `frames = buildReplayFrames(hand)` memoised on `hand`; on every `hand` change `idx` is set to `frames.length - 1` — **the replayer opens on the last frame** (the winner line, `revealAll: true`), so the first thing the user sees is the finished hand, and stepping backwards is the normal interaction. `frame = frames[min(idx, last)] ?? frames[0]`.
- Seat order: `[hero, ...seats.filter(!isHero)]` — hero is always drawn first, i.e. at the bottom of the oval; `hero = seats.find(isHero) ?? seats[0]`.
- Seat placement on an oval, `n = ordered.length`, index `i`:
  `rad = π/2 − 2πi/n`; `left = (50 + 42·cos(rad))%`, `top = (46 + 41·sin(rad))%` (1 decimal). Table felt: an absolutely-positioned `80% × 90%` ellipse (`rounded-[46%/50%]`, 9 px border `#241509`).
- Pot + board are centred at `top: 40%`: `<Pot pot={frame.pot} bb={hand.bb} street={frame.street} />` above `<Board cards={frame.board} w={44} />`.
- Per seat: hole cards are shown iff `holes[seat]` exists **and** (`isHero` or `frame.revealAll`) — so villains' cards appear only on the final frame; hero cards are 34 px wide, villains' 24 px. A seat with no visible holes shows two face-down 24 px cards, unless it is in `frame.folded`, in which case it shows nothing and its whole block gets `opacity-25 grayscale` (name plate `opacity-50`).
- Name plate (88 px): `s.position` bold on top, `` `${fmtBb(s.stack, hand.bb)} bb` `` mono below (`fmtBb` = chips/bb rounded to 0.1, integers printed without a decimal). Hero's plate has a 2 px gold ring, others a 1 px `--line` ring.
- Transport row: `⏮` → `idx = 0`, `◀` → `max(0, idx-1)`, a `Slider` (`min 0`, `max last`, `step 1`, aria-label `Replay step`), `▶` → `min(last, idx+1)`, `⏭` → `idx = last`. First two disabled at `idx === 0`, last two at `idx >= last`. All four are 32 px squares using the `chevron-right` icon, the back pair rotated 180°.

---

## 11. PokerStars-dialect import (`src/lib/hhImport.ts`, 293 lines)

Two exported functions, no state, no I/O:

```ts
export interface ImportedHand extends HHHand { imported: true; heroName: string | null }
export function parsePokerStars(text: string): { hands: ImportedHand[]; skipped: number }
export function analyzeImported(hands: ImportedHand[]): { reviewed: number; leaks: LeakSpot[] }
```

`ImportedHand` is an `HHHand` (§1) plus exactly two fields: the literal `imported: true` flag (what the Stats row renders as the `imported` badge, §7.9) and `heroName` (the name found on the `Dealt to` line, or `null`). Both are stored inside the persisted `hand_json` blob and survive a restart — the badge is `h.imported === true` read straight off the parsed JSON, there is no separate `source` lookup in the UI.

**Never-throws contract:** `parsePokerStars` wraps every block in `try/catch`; a throw *or* a `null` from `parseOne` increments `skipped` and parsing continues. There is no error type, no partial-hand result, and no logging. A Dart port must keep this: the import button is a user-facing action on arbitrary third-party text.

### 11.1 Shared helpers

```
CARD_RE = /^[2-9TJQKA][cdhs]$/                       // exactly rank+suit, case-sensitive
parseCards(inside) = inside.trim().split(/\s+/).filter(c => CARD_RE.test(c))   // silently drops junk tokens
num(s)             = Number.parseFloat(s.replace(/[$,]/g, ""))                // "$1,250.50" -> 1250.5
```

`parseCards` never throws and can return 0..n cards; every caller checks the length it needs. `num` is the only numeric conversion in the file — it strips `$` and thousands separators anywhere in the token, so both play-chip (`60`) and real-money (`$0.05`) files parse, and the parsed values keep their original unit (§11.3 note 12).

Dart: `RegExp(r'^[2-9TJQKA][cdhs]$')`, `double.parse(s.replaceAll(RegExp(r'[$,]'), ''))`. Keep `num()` returning a double — imported blinds are frequently fractional (`0.05`), and `HHHand.sb/bb` are declared `number`.

### 11.2 `parsePokerStars(text)` — block splitting

```
blocks = text.replace(/\r/g, "")                     // CRLF files normalised, \n only
             .split(/\n{2,}(?=PokerStars )/)         // split on 2+ newlines FOLLOWED BY "PokerStars "
             .map(b => b.trim())
             .filter(b => b.startsWith("PokerStars "))
hands = []; skipped = 0
for block of blocks:
  try { h = parseOne(block); if (h) hands.push(h) else skipped++ }
  catch { skipped++ }
return { hands, skipped }
```

Consequences a Dart port must reproduce:

- The split is a **lookahead**, so the `PokerStars ` text stays at the head of the next block.
- A file whose hands are separated by a single newline is one block → 1 hand at best, the rest of the text ignored (it is all consumed as `lines` of the first hand and mostly matches nothing).
- Leading junk before the first `PokerStars ` line (site preambles, BOM-prefixed first lines) makes that block fail `startsWith` and it is dropped **without counting as skipped** — `skipped` only counts blocks that looked like hands and failed. A BOM (`﻿`) at the very start therefore silently loses the first hand.
- Hands separated by 3+ blank lines (our own `formatSession`, §9) split correctly.
- `\r` is removed globally *before* splitting; per-line `trim()` in `parseOne` then removes any remaining stray whitespace.

Dart note: `String.split(RegExp(...))` supports lookaheads in the same syntax, so `text.replaceAll('\r', '').split(RegExp(r'\n{2,}(?=PokerStars )'))` is a direct translation.

### 11.3 `parseOne(block): ImportedHand | null` — step by step

`lines = block.split("\n").map(l => l.trim())`. Every regex below is anchored at `^` against a **trimmed** line.

**1 · Header / blinds (fails → `null`, i.e. `skipped++`)**

```
hm = lines[0].match(/Hand #(\d+):.*\(\$?([\d.,]+)\/\$?([\d.,]+)(?:\s|\))/)
if (!hm) return null
sb = num(hm[2]); bb = num(hm[3])
```
Not anchored: any prefix is tolerated (`PokerStars Zoom Hand #…`, `Tournament #…, Hand #…`). The `(?:\s|\))` tail means `(10/20)` and `($0.05/$0.10 USD)` both match; `(10/20` with no terminator does not. `hm[1]` is the site hand id (digits only) and is reused in step 11.

**2 · Timestamp — LOCAL time, never UTC**

```
dm = lines[0].match(/- (\d{4})[/-](\d{2})[/-](\d{2})[ T](\d{2}):(\d{2}):(\d{2})/)
startedAt = dm ? new Date(+y, +m - 1, +d, +H, +M, +S).getTime() : Date.now()
```
`2024/03/07` and `2024-03-07` both match, as does a `T` separator. The `ET` suffix real PokerStars files carry is **ignored** — the wall-clock numbers are interpreted in the *device's* time zone. Dart: `DateTime(y, m, d, H, M, S).millisecondsSinceEpoch` (the local constructor, **not** `DateTime.utc`). Pinned: parsing `- 2024/03/07 21:14:11` on a device in Asia/Seoul yields `1709813651000`; the same file on a UTC device yields a different `startedAt`, and since `startedAt` is the note key (§6.6) and the leak id (§11.4), notes do not travel between time zones. This is the source behaviour; keep it unless you also migrate note keys.

Missing/instrumented dates fall back to `Date.now()`, so re-importing a dateless file creates a *new* hand each time.

**3 · Button**

```
tm = lines[1]?.match(/Seat #(\d+) is the button/)
buttonSeatNo = tm ? +tm[1] : 1                  // 1-based seat NUMBER, not an index
```
Only line 2 is examined. Any other layout silently means "seat #1 is the button".

**4 · Seats (fewer than 2 → `null`)**

```
for every line: m = /^Seat (\d+): (.+?) \(\$?([\d.,]+) in chips\)/
  seats.push({ seat: +m[1] - 1, name: m[2].trim(), stack: num(m[3]), isHero: false, position: "BTN" })
if (seats.length < 2) return null
byName = Map(name -> seat object)               // last duplicate name wins
```
`seat` is the printed seat number minus 1, so a table printed as `Seat 1 / Seat 3 / Seat 5` yields the sparse indices `0, 2, 4` while `seats.length` is 3 — see the position warning in step 10. Names keep their exact spelling (spaces, unicode); `byName` lookups everywhere else are exact string matches, which is why a player whose name contains `: ` or ` shows [` can confuse the action regexes (accepted risk in the source).

Note this loop scans **all** lines, including the `*** SUMMARY ***` block; summary lines read `Seat 4: Dwan showed …` and do not match `\(… in chips\)`, so they are ignored.

**5 · Blinds → seats (defaults when absent)**

```
sbSeat = seat of the FIRST-matched-then-overwritten /^(.+?): posts small blind/    (last match wins)
bbSeat = ditto for /^(.+?): posts big blind/
```
Both regexes are tested against every line in one pass and both assignments require `byName.has(name)`. `-1` means "never seen", and the returned hand substitutes:

```
sbSeat = sbSeat >= 0 ? sbSeat : (buttonSeatNo % n)
bbSeat = bbSeat >= 0 ? bbSeat : ((buttonSeatNo + 1) % n)      // n = seats.length
```
(Note the fallback mixes a 1-based seat number with a 0-based index modulo the seat count — it is a heuristic, not a correct rotation, and only fires on files with no blind lines. The combined `posts small & big blinds` line real PokerStars emits for a returning player matches **neither** regex.)

**6 · Hero (`Dealt to`)**

```
for every line: m = /^Dealt to (.+?) \[([^\]]+)\]/
  if (m && byName.has(m[1])) {
    cs = parseCards(m[2]); if (cs.length === 2) { heroName = m[1]; seat.isHero = true; holes[seat] = [cs[0], cs[1]] }
  }
```
Exactly 2 valid cards required (a 4-card Omaha `Dealt to` line is ignored, leaving the hand hero-less). The loop does not stop at the first hit and never clears a previous `isHero`, so a file containing several `Dealt to` lines (observed/multi-hero exports) ends up with **several seats flagged `isHero`**; `heroName` is the last one, while every later consumer uses `seats.find(s => s.isHero)`, i.e. the lowest seat index. A hand with no usable `Dealt to` line still parses (hero-less), is stored and replayable, but is skipped entirely by the analyzer (§11.4).

**7 · Streets and the board**

Processed in the same single pass, in this priority order, each with `continue`:

| line | effect |
|---|---|
| `/^\*\*\* FLOP \*\*\* \[([^\]]+)\]/` | `street = "flop"`, `board = parseCards(group)` (replaces) |
| `/^\*\*\* TURN \*\*\* \[[^\]]+\] \[([^\]]+)\]/` | `street = "turn"`, `board = [...board.slice(0,3), ...parseCards(group)]` |
| `/^\*\*\* RIVER \*\*\* \[[^\]]+\] \[([^\]]+)\]/` | `street = "river"`, `board = [...board.slice(0,4), ...parseCards(group)]` |
| starts with `*** SHOW DOWN` or `*** SUMMARY` | `street = "showdown"` |

`*** HOLE CARDS ***` is not a marker — preflop is simply the initial state. The turn/river rules rebuild the board from its own first 3/4 cards, so a `Board [..]` summary line cannot corrupt it and a missing FLOP header leaves the board short. `FIRST STREET`/`SECOND FLOP` (run-it-twice) markers are unknown and fall through to the action matchers, where they match nothing.

**8 · Showdown card harvest (only while `street === "showdown"`)**

```
sm = l.match(/^(?:Seat \d+: )?(.+?)[:]? (?:shows|showed) \[([^\]]+)\]/)
if (sm && byName.has(sm[1]) && parseCards(sm[2]).length === 2) holes[seat] = [c0, c1]
```
Then `continue` — **no action line is ever parsed after the first `*** SHOW DOWN ***` / `*** SUMMARY ***` marker.** The optional `Seat \d+: ` prefix lets summary lines contribute cards, but a summary line carrying a position tag (`Seat 1: villain_a (big blind) showed [Qd Th] …`) captures the name as `villain_a (big blind)`, which is not in `byName` and is dropped; those cards are recovered from the plain `villain_a: shows [Qd Th] (two pair…)` line in the `*** SHOW DOWN ***` section instead. `mucks hand` lines match nothing.

**9 · Action lines** (tried in this order, first match wins, all require `byName.has(name)`; each pushes `{street, seat, name, type, amount, allIn}`)

| regex | type | amount | allIn |
|---|---|---|---|
| `/^(.+?): folds/` | `fold` | 0 | false |
| `/^(.+?): checks/` | `check` | 0 | false |
| `/^(.+?): calls \$?([\d.,]+)( and is all-in)?/` | `call` | `num(g2)` — chips **added** this action | `!!g3` |
| `/^(.+?): bets \$?([\d.,]+)( and is all-in)?/` | `bet` | `num(g2)` — the bet size | `!!g3` |
| `/^(.+?): raises \$?[\d.,]+ to \$?([\d.,]+)( and is all-in)?/` | `raise` | `num(g2)` = the **total "to"**, the raise-by amount is discarded | `!!g3` |

There is no `post` action: the blind lines are consumed by step 5 and never become `HHAction`s (the analyzer seeds them into `committed` by hand, §11.4). `Uncalled bet (X) returned to Y` matches nothing and is ignored — which is why the imported `heroNet` (step 12) is winnings-only. `collected` lines are handled in step 10, not here.

**10 · Winners**

```
collected = Map<seat, number>()
for every line:
  m = l.match(/^(.+?) collected \$?([\d.,]+) from/)
   ?? l.match(/^Seat \d+: (.+?) (?:\([^)]+\) )?(?:collected \(\$?([\d.,]+)\)|showed \[[^\]]+\] and won \(\$?([\d.,]+)\))/)
  if (m) { name = m[1].trim(); amt = num(m[2] ?? m[3] ?? "0")
           if (byName.has(name) && amt > 0) collected.set(seat, Math.max(collected.get(seat) ?? 0, amt)) }
potResults = [...collected.entries()].map(([seat, amount]) => ({ winners: [seat], amount, potLabel: "Pot" }))
```
The second alternative tolerates the optional `(button)` / `(big blind)` tag between name and verb, and covers both summary spellings. `Math.max` (not `+=`) is what keeps the `X collected 520 from pot` line and the `Seat 1: X (button) … won (520)` line from double-counting the same pot; a genuine split main+side pot for one player is therefore also collapsed to the larger of the two. One `PotResult` per *collector* — `winners` always has exactly one seat, `potLabel` is always the literal `"Pot"`, and side-pot structure is lost. Dart: `m[2] ?? m[3]` must be null-aware on the *group*, not on the string (an unmatched alternative yields `null`, and `num(null)` would throw).

**11 · Positions (best-effort, relative to the button)**

```
n = seats.length
order = n === 2 ? ["BTN", "BB"] : ["BTN", "SB", "BB", "UTG", "MP", "CO", "MP", "MP", "CO"]
for s of seats: off = (s.seat - (buttonSeatNo - 1) + n) % n
                s.position = order[Math.min(off, order.length - 1)] ?? "MP"
```
Read literally: the table is indexed by **offset from the button in seat-index space**, clamped to the last entry (`CO`) for offsets ≥ 9, with `"MP"` as an unreachable final fallback. For a dense 6-max table `[BTN, SB, BB, UTG, MP, CO]` — correct. Two known wrong-but-shipped cases:

- **Sparse seat numbers.** The §17.2 real-site fixture prints `Seat 1 / Seat 3 / Seat 5` → indices `0, 2, 4`, `n = 3`, `buttonSeatNo = 3`: `villain_a` (index 0) gets offset 1 → `SB` although the file says he posted the big blind; `villain_b` (index 4) gets offset 2 → `BB` although he posted the small blind. Hero is `BTN`, correctly.
- **Heads-up.** `order = ["BTN", "BB"]` labels the non-button seat `BB` even when it posted the small blind.

Positions feed only `LeakSpot.heroPos` / `oppActive` (§11.4) and the replayer's name plates (§10) — nothing numeric — so the source accepts the error. A Dart port that "fixes" this changes the pinned leak fixtures in §17.2.

**12 · The returned object**

```
id       = Number(String(hm[1]).slice(-6))        // last 6 digits of the SITE hand id
startedAt, button = buttonSeatNo - 1, sb, bb, sbSeat, bbSeat (step 5 fallbacks applied)
seats, holes, actions, board, potResults
heroNet  = heroSeat != null ? (collected.get(heroSeat.seat) ?? 0) : 0
imported = true, heroName
```

- `id` collides freely (`#241537799999` → `799999`, our own `#178183800000007` → `7`); it is a display label only (`Hand #…` in the recent list), never a key. Notes and the leak id key on `startedAt`.
- `heroNet` is **winnings only** — nothing subtracts what the hero put in, so a losing imported hand shows `+0.0 bb` and a winning one shows the gross pot. §7.9 renders `fmtSigned(h.heroNet / h.bb)` for it, so an imported hand is never red. Imported hands never touch `user_stats` (§4 `persistImportedHands`), so this cannot corrupt the win-rate.
- Amounts stay in the file's own unit. A `$0.05/$0.10` hand keeps `bb = 0.1`, and everything downstream that divides by `bb` (recent-hands bb display, analyzer normalisation) therefore works for both chip and dollar files.

### 11.4 `analyzeImported(hands)` — the pot/committed state machine and its leaks

Purpose: find hero *calls* that were clearly unprofitable even against a random hand, and turn them into `LeakSpot`s for the Review queue (`leakStore`, §6.8). Villain ranges are unknown in an import, so the bar is deliberately high and one-sided — only calls are judged, never folds, bets or raises.

```
analyzeImported(hands) -> { reviewed: number, leaks: LeakSpot[] }

leaks = []; reviewed = 0
for h of hands:
  hero = h.seats.find(isHero); hole = hero ? h.holes[hero.seat] : undefined
  if (!hero || !hole) continue                       // whole hand skipped, nothing counted

  pot       = h.sb + h.bb                            // blinds only: antes/straddles are invisible
  committed = { [h.sbSeat]: h.sb, [h.bbSeat]: h.bb } // heads-up where sbSeat == bbSeat would keep one entry
  street    = "preflop"
  for a of h.actions:
    if (a.street !== street):                        // relies on actions being in street order
      street = a.street
      for k of Object.keys(committed): committed[+k] = 0     // EVERY tracked seat resets to 0
    prev = committed[a.seat] ?? 0
    if (a.type === "call"):
      if (a.seat === hero.seat && a.amount > 0): reviewed++ ; <equity test below>
      committed[a.seat] = prev + a.amount
      pot += a.amount
    else if (a.type === "bet" || a.type === "raise"):
      pot += a.amount - prev                         // "to" semantics: only the increment enters the pot
      committed[a.seat] = a.amount
    // fold and check change nothing
```

Details that matter for a faithful port:

- `pot` is measured **before** the hero's call is added (the call is added after the test), so `needed = a.amount / (pot + a.amount)` is the standard pot-odds fraction.
- The street reset iterates the *keys currently in* `committed` — seats that have not acted yet are simply absent and read as `prev = 0`. Blinds are seeded but never appear as `HHAction`s (§11.3 step 9).
- Uncalled bets returned to a player are not modelled, so `pot` runs high on hands that ended with a fold to a bet. Rake is ignored.
- `reviewed` counts **every** hero call with `amount > 0`, flagged or not; it is what the import message reports as "reviewed N of your calls". A hero call of 0 (rare `calls 0` lines) is not counted.

The test applied to each hero call:

```
boardNow = street == "preflop" ? []
         : street == "flop"    ? h.board.slice(0, 3)
         : street == "turn"    ? h.board.slice(0, 4)
         :                       h.board.slice(0, 5)
needed = a.amount / (pot + a.amount)
r      = equityVsRandom(comboToInts(hole), boardNow.map(cardToInt), 2500, hashSeed(`imp|${h.startedAt}|${street}|${a.amount}`))
flag if:  r.equity + 2 * r.se + 0.08 < needed
```

- `equityVsRandom(hero, board, iters = 2500, seed)` returns `{ equity, se, exact, … }` — heads-up vs one uniformly random hand, exact enumeration when the board is complete, Monte-Carlo otherwise (owned by `math-engine.md`). `comboToInts([c1, c2]) = [cardToInt(c1), cardToInt(c2)]`, `cardToInt(card) = RANKS.indexOf(card[0]) * 4 + SUITS.indexOf(card[1])` with `RANKS = "23456789TJQKA"`, `SUITS = "cdhs"`.
- `hashSeed(s)` is FNV-1a 32-bit over UTF-16 code units, returned unsigned:
  ```
  h = 0x811c9dc5; for each char: h ^= charCodeAt(i); h = Math.imul(h, 0x01000193); return h >>> 0
  ```
  Dart: keep the multiply in 32-bit (`(h * 0x01000193) & 0xFFFFFFFF`) — this is the same function §6.5 uses for quiz keys, so port it once.
- The `+ 2 × se + 0.08` margin is a *pessimistic* edge: even the optimistic end of the Monte-Carlo confidence interval, plus 8 equity points of slack, must still lose to the price. Roughly: only calls that were wrong by a mile survive. `analyzeImported` on the real-site fixture of §17.2 (a river call getting ~30 % odds with a set-less overpair) flags **nothing**.

The emitted `LeakSpot` (units: **already normalised to big blinds, with `bb: 1`** — the opposite convention to live-coach leaks, which are in chips with `bb = bigBlind`; §3 and `drill-ux-srs-leaks.md` §12):

```
id:        `imp-${h.startedAt}-${street}`
street, heroPos: hero.position, hole, board: boardNow
pot:       pot / h.bb                     toCall: a.amount / h.bb                bb: 1
oppActive: h.seats.filter(s => !s.isHero).map(s => s.position)      // everyone, folded or not
options:   [ { action: "fold", label: "Fold" },
             { action: "call", label: `Call ${(a.amount / h.bb).toFixed(1)} bb`, amount: a.amount / h.bb } ]
best:      "fold"
rationale: `Imported hand: you called ${(a.amount / h.bb).toFixed(1)} bb needing ${Math.round(needed * 100)}% but ${cardsToLabel(hole[0], hole[1])} wins only ~${Math.round(r.equity * 100)}% even against a random hand — real ranges make it worse.`
equity:    r.equity          potOdds: needed          ts: Date.now()
```

`cardsToLabel(a, b)` = the 2/3-char hand label: pair → `"QQ"`, else higher rank first + `s`/`o` (`cardsToLabel("Ah","Ks") = "AKo"`).

**The id is not unique.** `imp-${startedAt}-${street}` omits the amount and the action index, so two flagged hero calls on the same street of the same hand (call, then call again after a re-raise) produce two spots with the **same id**. `leakStore.add` does not de-duplicate (§6.8), so both are stored; `leakStore.review(id, correct)` then updates *both* and retires them together, and the Review queue shows the spot twice. Two different imported hands can also collide if their `startedAt` values are identical (same second, dateless files sharing a `Date.now()`). Reproduce as-is unless you are also changing the review UX — but a Dart port may safely append the action index if the accompanying drill doc is updated.

**Worked example** (the `scripts/hhimport_test.ts` "bad call" fixture, §17.2 — verified by running the real analyzer):

```
blinds 10/20, hero (Seat 1, index 0) posts the BIG blind, v1 (Seat 2, index 1) posts the small blind
pot = 30, committed = { 1: 10, 0: 20 }
v1 raises to 2000  ->  pot += 2000 - 10 = 1990  ->  pot = 2020, committed[1] = 2000
hero calls 1980    ->  reviewed = 1; needed = 1980 / (2020 + 1980) = 0.495
                       boardNow = [] (preflop); equity vs random for 7h2c ≈ 0.3466, se small
                       0.3466 + 2·se + 0.08 < 0.495  ->  FLAG
leak: { id: "imp-1781838000000-preflop", street: "preflop", heroPos: "BTN", hole: ["7h","2c"], board: [],
        pot: 101, toCall: 99, bb: 1, oppActive: ["BB"], best: "fold",
        options: [ {fold,"Fold"}, {call,"Call 99.0 bb",99} ],
        rationale: "Imported hand: you called 99.0 bb needing 50% but 72o wins only ~35% even against a random hand — real ranges make it worse.",
        equity: 0.3466, potOdds: 0.495 }
```
(`1781838000000` is `2026/06/19 12:00:00` read as **local** time at UTC+9 — §11.3 step 2; the leak id moves with the time zone. `equity ≈ 0.3466` is the 2 500-sample Monte-Carlo result for the seed `hashSeed("imp|1781838000000|preflop|1980")` and only reproduces exactly if the Dart RNG and sampling order match `math-engine.md`; the *flag/no-flag* outcome is robust either way.)

(Note the position labels: hero is tagged `BTN` and the small-blind poster `BB` — the step-11 heads-up quirk, faithfully reproduced.)

### 11.5 The Stats-tab import flow (`StatsView.onImportFile`, lines 41–56)

Trigger: the `Import hands (.txt)` label in the "Recent hands" card header (§7.9) wraps a hidden `<input type="file" accept=".txt,text/plain">`; `onChange` takes `files?.[0]`, calls `onImportFile(f)` and then sets `e.target.value = ""` **synchronously, without awaiting**, so the same file can be picked again immediately.

Exact order — the persist call happens **before** the analysis, and the reload is last:

```
1. text = await file.text()                                   // whole file into memory, UTF-8
2. { hands, skipped } = parsePokerStars(text)                  // §11.2
3. if (hands.length === 0):
     setImportMsg(`Couldn't find any PokerStars-style hands in that file${skipped ? ` (${skipped} blocks unparseable)` : ""}.`)
     return                                                    // nothing persisted, no reload
4. await persistImportedHands(hands.map(h => JSON.stringify(h)))   // §4 — source='import', never touches user_stats
5. { reviewed, leaks } = analyzeImported(hands)                // §11.4 — AFTER the write
6. const addLeak = useLeaks.getState().add; for (const l of leaks) addLeak(l)   // one store write per leak, cap 60, no de-dup
7. setImportMsg(<success template below>)
8. setReloadKey(k => k + 1)                                    // bumps the effect dependency
```

Step 8 re-runs the `useEffect([handsPlayed, reloadKey])` that calls `loadRecentHands(30)` (§4) and re-parses the rows into `recent`, so the imported hands appear in the list — including their `imported: true` badge — without a restart. The lifetime KPIs do not move, because nothing incremented `hands_played`/`net_chips`.

Verbatim messages (the only two; both render in the info banner above the list — `border-info/30 bg-info/10 text-info`, `0.76rem`, and stay until the next import):

```
Couldn't find any PokerStars-style hands in that file${skipped ? ` (${skipped} blocks unparseable)` : ""}.
```
```
Imported ${hands.length} hand${hands.length === 1 ? "" : "s"}${skipped ? ` (${skipped} skipped)` : ""} · reviewed ${reviewed} of your calls · ${leaks.length ? `${leaks.length} questionable one${leaks.length === 1 ? "" : "s"} added to the Review queue` : "no clear mistakes found"}. Imported hands never count toward your play stats.
```

Rendered examples: `Imported 12 hands (2 skipped) · reviewed 7 of your calls · 1 questionable one added to the Review queue. Imported hands never count toward your play stats.` — and with nothing flagged: `Imported 1 hand · reviewed 0 of your calls · no clear mistakes found. Imported hands never count toward your play stats.` The separator is a middle dot `·` (U+00B7); the apostrophe in `Couldn't` is a straight ASCII `'`.

Failure modes deliberately left unhandled: `file.text()` rejecting (unreadable file) escapes as an unhandled promise rejection — the button appears to do nothing; a huge file blocks the UI thread for the duration of the parse. A Dart port should keep the messages identical but is free to wrap step 1 in a try/catch and show the "Couldn't find any…" message on read failure.

---

## 12. Opening external URLs (`src/lib/openExternal.ts`, 15 lines)

```ts
export async function openExternal(url: string): Promise<void> {
  if (isNative()) {
    try { const { openUrl } = await import("@tauri-apps/plugin-opener"); await openUrl(url); return; }
    catch (e) { console.warn("opener plugin failed, falling back:", e); }
  }
  window.open(url, "_blank", "noopener,noreferrer");
}
```

Never throws, never returns a status. On native the dynamic import + `openUrl` is tried first (capability `opener:allow-open-url`, §2.2) and any failure logs `opener plugin failed, falling back:` and falls through to `window.open`. Callers are the About tab only (§15). Dart: `url_launcher` with `LaunchMode.externalApplication`, swallow errors.

---

## 13. Saving files and copying text (`src/lib/exportFile.ts`, 40 lines)

Two exported functions; both are total (never throw) and report success in their return value. Every caller shows the result directly to the user, so the strings below are user-facing copy.

### 13.1 `saveText(filename, contents): Promise<{ ok: boolean; message: string }>`

```ts
if (isNative()) {
  try {
    const { invoke } = await import("@tauri-apps/api/core");
    const path = await invoke<string>("save_text_file", { filename, contents });
    return { ok: true, message: `Saved to ${path}` };
  } catch (e) {
    return { ok: false, message: `Save failed: ${String(e)}` };
  }
}
try {
  const blob = new Blob([contents], { type: "text/plain" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
  return { ok: true, message: `Downloaded ${filename}` };
} catch (e) {
  return { ok: false, message: `Download failed: ${String(e)}` };
}
```

The four message templates, verbatim — these are the strings §7.11 shows under the backup button and §9 shows in the session summary:

| branch | `ok` | `message` |
|---|---|---|
| native success | `true` | `` `Saved to ${path}` `` — `path` is the absolute path returned by the Rust command (§16), e.g. `Saved to /Users/you/Downloads/allin-backup-2026-09-07.json` |
| native failure | `false` | `` `Save failed: ${String(e)}` `` |
| web success | `true` | `` `Downloaded ${filename}` `` |
| web failure | `false` | `` `Download failed: ${String(e)}` `` |

`String(e)` is JavaScript's error stringification (`Error: ENOENT …`, or a bare string when the Tauri command rejects with `Err(String)` — in that case the message is exactly the Rust `e.to_string()`). A Dart port should format the caught object the same way (`'$e'`) so the copy reads identically.

Note the web branch is fire-and-forget: `ok: true` only means the anchor click was dispatched, not that a file landed anywhere. Mobile Dart equivalent: write to the platform downloads/documents directory (or hand the bytes to a share sheet) and return `Saved to <displayed path>`; keep `Save failed: …` for the error case, and drop the `Downloaded …` variant only if there is no web build.

Callers: the Stats reset modal's backup button (§7.11, filename `` `allin-backup-${new Date().toISOString().slice(0, 10)}.json` `` → `allin-backup-2026-09-07.json`, contents `await exportBackup()`, §4) and the session summary's `Export hands (.txt)` (§9).

### 13.2 `copyText(text): Promise<boolean>`

```ts
export async function copyText(text: string): Promise<boolean> {
  try { await navigator.clipboard.writeText(text); return true; }
  catch { return false; }
}
```

No message, no fallback (`document.execCommand("copy")` is not attempted), silent on failure — the caller decides what to say. Its only caller is the session summary `Copy` button, which maps `true → "Hand history copied to clipboard."` and `false → "Copy failed."` (§9). Dart: `Clipboard.setData(ClipboardData(text: text))` inside a try/catch returning `true`/`false`.

---

## 14. Settings tab (`src/views/SettingsView.tsx`, 182 lines) — verbatim copy

Page: `h-full overflow-auto` → `mx-auto max-w-[720px] px-8 py-7`. Title **`Settings`** (display, 3xl, extrabold); subtitle **`Everything is saved on this device.`**

Three cards, each with a gold header (icon 15 px + label) and rows. A `Row` is `title` (0.875rem semibold) + `desc` (0.78rem muted, max-width 420 px) on the left and the control on the right, separated by a bottom border except on the last row. Controls: `Toggle` (`role="switch"`, `aria-checked`, `aria-label` = the row title, 44×24 px pill, gold when on, `bg-ink-600` when off, 20 px white knob) and `Segmented` (`bg-ink-700` strip, 0.74rem semibold options; selected = `bg-gold text-ink-900`).

**Card 1 — `Table & cards` (icon `eye`)**

| row title | description (verbatim) | control |
|---|---|---|
| `Four-color deck` | `♠ black · ♥ red · ♦ blue · ♣ green. Makes suits unmistakable at a glance — recommended, and essential if you have trouble telling red suits apart.` | a live preview of `As Ah Ad Ac` (26 px cards) + toggle → `update({ fourColorDeck })` |
| `Realistic reveals` | `By default the app shows everyone's cards when a hand ends — folded hands included — because seeing what people folded builds intuition. Turn this on to hide folded hands, like a real table.` | toggle → `update({ realisticReveal })` |
| `Theme` | `Light or dark — also switchable from the sidebar.` | segmented `Dark` / `Light`; **any** click calls `toggle()` (selecting the already-active option flips the theme) |
| `Reduce motion` | `Disables animations and transitions. Also honors your system's reduced-motion preference automatically.` | toggle → `update({ reducedMotion })` |

**Card 2 — `Coach` (icon `coach`)**

| row title | description (verbatim) | control |
|---|---|---|
| `Strictness` | `How eagerly the coach interrupts. Relaxed only flags clear blunders; strict calls out smaller EV losses too.` | segmented `Relaxed` / `Standard` / `Strict` → `update({ coachStrictness })` (thresholds in §6.1) |
| `Simulation quality` | `High runs 2.5× more Monte-Carlo trials per verdict — slightly slower, tighter error bars. Late streets are always computed exactly either way.` | segmented `Standard` / `High` → `update({ simQuality })` (1600 vs 4000 iters, §6.1) |

**Card 3 — `Keyboard` (icon `bolt`)** — despite the header, the first row is the onboarding reset

| row title | description (verbatim) | control |
|---|---|---|
| `Tour & placement` | `Re-run the first-launch tour and the placement quiz (recalibrates your drill rating).` | button **`Run again`** → `localStorage.removeItem("allin.onboarded.v1")` inside try/catch, then `window.location.reload()`. It does **not** touch `allin.drills.v1`: the rating changes only when the placement quiz finishes and calls `seedRating` (§6.9). |
| `Shortcuts` | `Play and drill without touching the mouse. F fold · C check/call · R raise · 1/2/3 drill answers · Enter next.` | button **`View all shortcuts`** → dispatches a synthetic `keydown` with `key: "?"` on `window` (bubbling), which the global shortcut-help listener picks up |

Both buttons are `rounded-lg border-[var(--line)] bg-ink-700 px-3 py-1.5 text-[0.78rem] font-semibold`.

Mobile port notes: "Run again" must clear the flag and re-enter the onboarding route rather than reloading the process; the `Shortcuts` row has no meaning on touch and can be dropped along with its card header rename.

---

## 15. About tab (`src/views/AboutView.tsx`, 251 lines) — verbatim copy

Page: `h-full overflow-auto` → `mx-auto max-w-[760px] px-8 py-8`. Constants: `SITE_URL = "https://gapp.in/poker"`, `RELEASES_URL = "https://github.com/ganeshapp/poker/releases/latest"`. `__APP_VERSION__` is injected at build time from `package.json` (currently `1.1.2`).

**Hero card** (centred, `rounded-2xl bg-ink-850 p-7`): 64 px `Logo`; h1 **`All-In · Poker Dojo`**; paragraph (max 520 px):

> `A clean, offline-first Texas Hold'em trainer that takes you from the rules to solid, EV-aware play — by actually doing the math with you, not just showing answers.`

then a pill **`Version {__APP_VERSION__}`** (0.66rem uppercase), then `<UpdateNotice />` (§15.1).

**Two link cards** (`sm:grid-cols-2`), both `openExternal` (§12):

| card | icon | title | subtitle | target |
|---|---|---|---|---|
| gold-tinted | `play` | `Play online` | `No install — runs in your browser at gapp.in/poker` | `SITE_URL` |
| neutral | `chip` | `Download desktop` | `Latest installer for macOS, Windows & Linux` (rendered from `&amp;`) | `RELEASES_URL` |

**`How to use it`** — four cards from the `MODES` array, in this order, each with a gold 28 px icon tile, a display-bold title and a 0.84rem muted body (all verbatim):

| icon | title | body |
|---|---|---|
| `play` | `Play` | `Start a session and play hand-after-hand against four bot archetypes. Step through the action manually or auto-play, click the eye on a player to guess/peek their range, and let the EV Coach grade your decisions with the math behind them.` |
| `target` | `Drills` | `Chess-puzzle-style practice. Replay a spot to the decision point, then choose fold/call/raise for instant feedback and a self-adjusting rating. Four modes: Mixed cash spots (pre-flop charts + post-flop pot-odds/equity), short-stack Push/Fold, Exploits vs known player types, and Review — your own coach-flagged mistakes, re-served until you fix them.` |
| `book` | `Study` | `A 5-level course from rules and position to hand-reading, bet-sizing, implied odds, SPR and multiway play — with interactive range, pot-odds, bluff and multiway-equity calculators, a quick-reference cheat sheet, and optional quizzes. Hover any dotted term for a definition.` |
| `stats` | `Stats` | `Track your win-rate (bb/100), range-read accuracy and results vs each archetype, see a coaching review of your leaks, replay any hand step-by-step from the session summary, and export a session's hands as a PokerStars-style history.` |

**`Good to know`** — one card, three bullets (icon + text):

1. (`check`, good) `Fully offline — your hands and progress stay on your machine (SQLite on desktop, browser storage on the web).`
2. (`info`) `Coaching and drills are graded by honest heuristics, not a solver — see "How the grading works" below for exactly what that means.`
3. (`info`) `It's a play-money trainer for learning. Variance is real: even good play swings, so judge yourself on decisions (the coach) more than short-term results.`

**`How the grading works`** — one card. Intro: `An honest summary of where the "right answers" come from, so you know how much to trust each verdict:` then three bullets whose lead phrase is bold:

1. (`info`) **`Pre-flop charts`** ` (drills and study diagrams) are self-authored consensus baselines for 100bb 6-max — solid standard play keyed by your position *and* the raiser's, with mixed frequencies where real strategies mix. They're not direct solver output; bot ranges still use a simplified model that's being upgraded next.` (the word `and` is italic)
2. (`info`) **`Post-flop coaching`** ` compares your pot odds with your hand's chance of winning, estimated by dealing thousands of random runouts against the opponent's likely hands (a Monte-Carlo simulation). That catches clear mistakes well, but it can't see everything a solver sees — treat close verdicts as guidance, not gospel.`
3. (`check`, good) **`Push/fold drills`** ` use Nash equilibrium tables we computed ourselves (chip-EV, no antes, one caller at a time) — mixed-frequency hands accept either answer, like the real equilibrium does. A third of push/fold reps are ICM bubble spots — solved the same way, but in tournament money instead of chips. Ante variants are still to come.`

**`On the roadmap`** — one card. Intro `Coming next (see the project README for the full, prioritised list):`; four `arrow-right` bullets, in order:

```
Configurable table — stack depths, 9-max, antes
Desktop auto-update — one-click new versions
Import your real online hand histories for coaching
Install as an app (PWA) on the web
```
Footer line: `It's evolving — feedback and ideas are welcome.` (0.74rem faint). *(Roadmap item 3 already ships as §11 — the list is stale in 1.1.2; keep or update it deliberately.)*

**`Built by`** — centred card: `Gapp` (2xl display, gold-light); a link **`www.gapp.in`** + `arrow-right` icon whose click handler `preventDefault()`s and calls `openExternal("https://www.gapp.in")`; then

> `Designed and built by Gapp. Made with Tauri + Rust and React + TypeScript. Thanks for playing — feedback is always welcome.`

Page footer: `All-In · Poker Dojo — © Gapp` (0.66rem faint, `py-8`). A Dart port must restate the "Made with…" sentence for Flutter.

### 15.1 `UpdateNotice` — the passive release check

```
on mount (once):  fetch("https://api.github.com/repos/ganeshapp/poker/releases/latest")
  -> r.ok ? r.json() : null
  -> if (!live || !j?.tag_name) return                     // `live` flag cleared by the cleanup function
     tag = j.tag_name.replace(/^v/, "")
     newer(a, b): compare a.split(".").map(Number) with b's, 3 components, missing -> 0; strictly greater wins
     if (newer(tag, __APP_VERSION__)) setLatest(tag)
  .catch(() => {})                                          // offline: say nothing
```

Renders nothing unless a newer tag exists; then a gold pill button: `arrow-right` icon + `` `Version ${latest} is out — download it here` `` → `openExternal(RELEASES_URL)`. No auto-update, no signature check, no retry, no caching (one request per mount of the About tab). The CSP in `tauri.conf.json` whitelists `https://api.github.com` in `connect-src` — without it the fetch fails and, per the design, nothing is shown.

---

## 16. Tauri host layer (`src-tauri/src/lib.rs` 93 lines, `tauri.conf.json` 40 lines)

Nothing here is business logic; it exists so the web app can reach Rust and the file system. A Flutter port replaces the whole layer, but the contracts matter because §13.1 and `math-engine.md` invoke them.

Registered plugins: `tauri_plugin_opener` (§12) and `tauri_plugin_sql` (§2.2). Five commands in `invoke_handler`:

| command | signature | forwards to |
|---|---|---|
| `evaluate_hand` | `(cards: Vec<String>) -> EvaluatedHand` | `poker_core::evaluate_named(cards_to_ints(&cards))` |
| `equity_vs_range` | `(hero, board, range: Vec<String>, iters: u32, seed: Option<u64>) -> EquityResult` | expands each label via `label_to_combos`, then `core::equity_vs_range(..., iters.max(1), seed)` |
| `equity_vs_random` | `(hero, board, iters, seed) -> EquityResult` | `core::equity_vs_random` |
| `equity_vs_field` | `(hero, board, opponents: u32, iters, seed) -> EquityResult` | `core::equity_vs_field` |
| `save_text_file` | `(filename: String, contents: String) -> Result<String, String>` | see below |

All three equity commands guard `cards_to_ints(&hero).len() < 2` and return the neutral `EquityResult { equity: 0.5, win: 0, tie: 0, lose: 0, samples: 0, se: 0.0, exact: false }` instead of erroring, and clamp `iters` with `.max(1)`.

`save_text_file` (the only file-system access in the app):

```rust
let home = env::var("HOME").or_else(|_| env::var("USERPROFILE"))?;   // Err -> Err(String)
let mut path = PathBuf::from(home);
path.push("Downloads");
let _ = fs::create_dir_all(&path);                                    // failure ignored
path.push(filename.replace('/', "_").replace('\\', "_"));             // flatten path separators
fs::write(&path, contents).map_err(|e| e.to_string())?;
Ok(path.to_string_lossy().to_string())                                // -> `Saved to ${path}` in §13.1
```

So: always `~/Downloads` (or `%USERPROFILE%\Downloads`), never a save dialog, silently overwrites an existing file, and the returned absolute path is what the user sees. Path separators in the requested filename are replaced with `_` — the only traversal guard.

`tauri.conf.json` essentials: `productName "All-In"`, `version "1.1.2"`, `identifier "com.allin.pokerdojo"` (the mobile port uses `com.gapp.allin`), frontend `../dist`, dev server `http://localhost:1420`; one window `main` titled `All-In · Poker Dojo`, 1280×840, min 1040×680, resizable, centred; bundle `targets: "all"` with the five icon sizes; CSP:

```
default-src 'self' ipc: http://ipc.localhost;
style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
font-src 'self' data: https://fonts.gstatic.com;
img-src 'self' data:;
connect-src 'self' ipc: http://ipc.localhost https://api.github.com
```

(the last entry is what allows §15.1's update check; Google Fonts is the only other remote origin).

---

## 17. Test suites to port

All four scripts run under `node --experimental-transform-types scripts/<name>.ts`, count `passed/failed` with a local `ok(cond, msg)` and `process.exit(failed === 0 ? 0 : 1)`. Port each as a Dart test file; the fixtures below are the pins.

### 17.1 `scripts/hh_test.ts` (41 assertions) — export + replay frames

Owned by `game-and-bots.md` §7 (exporter) and `play-loop-and-coach.md` §21 (frames); it pins substrings such as `Dwan: raises 40 to 60`, `Uncalled bet (40) returned to Dwan`, `Total pot 520`, and the absence of `Selbst: shows`. This subsystem only depends on it through §9's round-trip guarantee — if the exporter's spacing changes, §17.2 fails first.

### 17.2 `scripts/hhimport_test.ts` (139 lines, 23 assertions, all passing)

**Fixture A — round trip.** The `HHHand` of §9.1 (`id 7`, `startedAt = new Date(2026, 5, 19, 12, 0, 0)`, button seat 0, 10/20, sbSeat 1, bbSeat 2, six 2000-chip seats `You/Ivey/Polk/Dwan/Selbst/Galfond`, `holes {0: AsKs, 3: QhQd}`, the 13 actions listed in §9.1's output, board `Ah Kd 7c 2s 9h`, `potResults [{winners:[0], amount:520}]`, `heroNet 260`) is run through `formatHand` and back through `parsePokerStars`:

1. `hands.length === 1 && skipped === 0`
2. `h.sb === 10 && h.bb === 20`
3. `h.seats.length === 6`
4. `h.heroName === "You"` and `seats.find(isHero).name === "You"`
5. `h.holes[0].join("") === "AsKs"`
6. `h.holes[3].join("") === "QhQd"` (villain cards recovered from the `*** SHOW DOWN ***` line)
7. `h.board.join("") === "AhKd7c2s9h"` (built street by street)
8. `h.actions.filter(type === "fold").length === 4`
9. `h.actions.some(type === "raise" && amount === 60)` (the "to" amount, not the 40 raise-by)
10. `h.potResults.some(p => p.winners.includes(0) && p.amount > 0)`
11. `h.imported === true`

**Fixture B — genuine-PokerStars-style text** (`$` amounts, sparse seats, rake, mucks). Verbatim:

```
PokerStars Hand #241537799999: Hold'em No Limit ($0.05/$0.10 USD) - 2024/03/07 21:14:11 ET
Table 'Aludra III' 6-max Seat #3 is the button
Seat 1: villain_a ($10.00 in chips)
Seat 3: hero_name ($12.35 in chips)
Seat 5: villain_b ($9.40 in chips)
villain_b: posts small blind $0.05
villain_a: posts big blind $0.10
*** HOLE CARDS ***
Dealt to hero_name [Jh Jc]
hero_name: raises $0.20 to $0.30
villain_b: folds
villain_a: calls $0.20
*** FLOP *** [2d 7s Td]
villain_a: checks
hero_name: bets $0.45
villain_a: calls $0.45
*** TURN *** [2d 7s Td] [Qc]
villain_a: checks
hero_name: checks
*** RIVER *** [2d 7s Td Qc] [3h]
villain_a: bets $1.55
hero_name: calls $1.55
*** SHOW DOWN ***
villain_a: shows [Qd Th] (two pair, Queens and Tens)
hero_name: mucks hand
villain_a collected $4.53 from pot
*** SUMMARY ***
Total pot $4.75 | Rake $0.22
Board [2d 7s Td Qc 3h]
Seat 1: villain_a (big blind) showed [Qd Th] and won ($4.53) with two pair, Queens and Tens
Seat 3: hero_name (button) mucked
Seat 5: villain_b (small blind) folded before Flop
```

12. `hands.length === 1`
13. `sb === 0.05 && bb === 0.1`
14. `heroName === "hero_name"`
15. `holes[2].join("") === "JhJc"` (Seat 3 → index 2)
16. `holes[0].join("") === "QdTh"` (Seat 1 → index 0)
17. `board.length === 5`
18. `potResults.some(p => p.amount === 4.53)`

Additional values this fixture pins (verified by running the parser, useful as extra Dart assertions): `id === 799999`, `button === 2`, `sbSeat === 4`, `bbSeat === 0`, seat indices `[0, 2, 4]`, positions `villain_a → SB`, `hero_name → BTN`, `villain_b → BB` (the sparse-seat quirk of §11.3 step 11), `heroNet === 0` (hero collected nothing), `actions.length === 10`, `imported === true`.

**Fixture C — the hopeless call.** Verbatim:

```
PokerStars Hand #100000000001: Hold'em No Limit (10/20) - 2026/06/19 12:00:00 ET
Table 'T' 6-max Seat #1 is the button
Seat 1: hero (2000 in chips)
Seat 2: v1 (2000 in chips)
v1: posts small blind 10
hero: posts big blind 20
*** HOLE CARDS ***
Dealt to hero [7h 2c]
v1: raises 1980 to 2000
hero: calls 1980
*** SUMMARY ***
Total pot 4000 | Rake 0
```

19. `parsePokerStars(badCall).hands.length === 1`
20. `analyzeImported(...).reviewed >= 1`
21. `analysis.leaks.length === 1` (72o calling 99 bb for a 50 % price)
22. `analysis.leaks[0].best === "fold"`
23. `analyzeImported(fixtureB.hands).leaks.length === 0` — the conservative analyzer does **not** flag the reasonable calls in the real fixture

Assertion 23 is the important regression guard: a Dart port whose `equityVsRandom`, `hashSeed` or margin differ will most likely start flagging fixture B. The full expected leak object for fixture C is written out in §11.4.

### 17.3 `scripts/leaks_test.ts` (6 assertions) — `leaksFromDecisions` (§8)

Helper `d(verdict, action)` builds a `DecisionRecord` with `equity 0.3, potOdds 0.25, evBb -1, street "flop", villainArchetype "TAG", ts 0`.

1. `leaksFromDecisions([])` → `total === 0 && leaks.length === 0`
2. 4 × `("mistake","fold")` + 6 × `("ok","call")` → `total === 10 && foldMistakes === 4`
3. …and some leak string contains `fold too often` (case-insensitive)
4. 4 × `("mistake","call")` + 6 × `("ok","check")` → `callMistakes === 4` and a leak contains `call too wide`
5. 6 × `("ok","call")` + 4 × `("great","bet")` → `mistakes === 0 && great === 4` and a leak contains `No clear`
6. `[("info","check"), ("info","check"), ("ok","call")]` → `total === 1` (info verdicts excluded)

### 17.4 `scripts/srs_test.ts` (13 assertions) — the scheduler persisted by §6.7/§6.8

`DAY = 86_400_000`, `t0 = 1_750_000_000_000`.

1. `isDue(newSrs(t0), t0)`
2. `!isGraduated(newSrs(t0))`
3. first success → `intervalDays === 1 && due === t0 + DAY`
4. `!isDue(r1, t0 + DAY/2)`
5. second success → `intervalDays === 3`
6. third success (at `t0 + 4·DAY`) → `intervalDays >= 4`
7. …and `reps === RETIRE_REPS (3) && isGraduated`
8. a miss → `reps === 0 && lapses === 1`
9. …and `due - now <= 15 * 60_000` (the code uses exactly 10 minutes)
10. …and `ease` strictly below the previous ease
11. one correct answer after a miss → `intervalDays === 1 && !isGraduated` (a single success never retires a card)
12. 20 consecutive misses → `ease >= 1.3` (floor)
13. 20 consecutive successes with `reps` pinned to 1 → `ease <= 3` (ceiling)

---

## 18. Addenda: diagnostics text and render constants

These complete earlier sections with details that a pixel-faithful port needs; nothing here contradicts §4–§7.

### 18.1 The five `noteError` contexts (completes §4)

`lastError` is always `` `${context}: ${String(e)}` `` and is returned by `backendInfo()` alongside the live backend, so these strings are part of the diagnostics contract:

| context string | raised by | switches backend to `local`? |
|---|---|---|
| `SQLite unavailable, using localStorage` | `ensureBackend()` when the plugin import / `Database.load` / DDL / `migrate()` throws | yes (initial choice) |
| `SQLite read failed, falling back` | `loadStats()` | yes |
| `SQLite write failed, falling back` | **all three write paths** — `persistHand`, `persistGuess`, `persistDecision` (`stats.ts` lines 325, 359, 379) | yes |
| `SQLite import write failed` | `persistImportedHands()` | yes |
| `SQLite hand read failed` | `loadRecentHands()` | **no** — it falls through to the localStorage read for this call only and leaves `backend` as `"sqlite"` |

§4 listed four of the five; `SQLite write failed, falling back` is the one shared by the three record writers. Keep the wording if you surface `backendInfo()` in a debug screen.

### 18.2 Stats page container and tiles (completes §7)

- Page: `h-full overflow-auto` wrapper → `mx-auto max-w-[980px] px-8 py-7` (Settings is 720 px, About 760 px, Stats **980 px**).
- Header block: `mb-6 flex items-center justify-between`; h1 `font-display text-3xl font-extrabold`, subtitle `text-sm text-muted`, ghost `Reset` button with a 15 px `refresh` icon.
- KPI grid: `grid grid-cols-2 gap-3 sm:grid-cols-5` (2 columns on narrow screens, 5 from `sm`).
- `Kpi({ label, value, sub?, tone? })`: `rounded-2xl border border-[var(--line)] bg-ink-800/80 p-4`; label `text-[0.66rem] uppercase tracking-wide text-faint`; value `mono text-2xl font-extrabold` coloured `text-good` / `text-bad` by `tone`, else `var(--text)`; optional sub `text-[0.62rem] text-faint`.
- `VerdictBox({ label, value, color })` (§7.6): `rounded-xl border border-[var(--line)] bg-ink-850 px-2 py-3`; value `mono text-2xl font-extrabold` with an inline `color`; label `text-[0.62rem] uppercase tracking-wide text-faint`. The three boxes sit in `grid grid-cols-3 gap-3 text-center`.
- Every card below the KPI row is `<Card className="mt-4">`; the two side-by-side pairs are `mt-4 grid gap-4 lg:grid-cols-2`. Card headers are `mb-3 flex items-center gap-2 text-sm font-semibold` with a 16 px gold icon.
- The Win-rate KPI is wrapped in a `<Tooltip>` (via a plain `<div>` child) — the other four tiles have none.

### 18.3 Chart component signatures and render constants (completes §7.3 / §7.4)

```ts
function LineChart({ values, height = 170, color = "var(--gold)", unit = "" }: {
  values: number[]; height?: number; color?: string; unit?: string;
})
function MiniBars({ values, color = "var(--info)" }: { values: number[]; color?: string })
```

`StatsView` calls `LineChart(values = cumulative, color = netBb >= 0 ? "var(--good)" : "var(--bad)", unit = "")` — `height` is always the default 170 — and `MiniBars(values = guesses.map(g => g.accuracy))` with the default colour.

`LineChart` render details beyond §7.3's algorithm:

- Empty state (`values.length < 2`) is a `div`, not an SVG: `grid h-[170px] place-items-center text-sm text-faint` — a **hard-coded 170 px**, so passing a custom `height` does not resize the placeholder.
- The SVG is `viewBox="0 0 640 H"` with `className="w-full"`, `preserveAspectRatio="none"` **and** `style={{ height }}`: the 640-wide viewBox is stretched horizontally to the card width and squashed to exactly `height` pixels, so nothing is aspect-correct and stroke width is visually anisotropic. A Dart `CustomPainter` reproduces this by mapping x through `size.width / 640` and y through `size.height / H`.
- The area gradient is `<linearGradient id="areaFill" x1="0" y1="0" x2="0" y2="1">` with stops `color @ 0.28` → `color @ 0`. **The DOM id is a hard-coded constant**: two `LineChart`s on the same page would both reference `url(#areaFill)` and the second's gradient definition would lose to the first's. Only one is ever rendered today. In Dart use a local `Shader`, and note the fill is drawn *under* the stroke (`area` path first, then `line`).
- Zero line: `<line x1={pad} y1={zeroY} x2={W - pad} y2={zeroY} stroke="rgba(255,255,255,0.18)" strokeDasharray="4 4" />` — it spans only the padded plot area (28 → 612), **not** the full 640 width, and is drawn *before* the area so the fill covers it.
- Last-point marker: `<circle r={4} fill={color} />` at `(x(n-1), y(last))` — radius 4 in viewBox units, i.e. horizontally stretched like everything else.
- Labels: both at `x = pad` with `fill="var(--text-faint)" fontSize="11"` — `max.toFixed(0) + unit` at `y = 16`, `min.toFixed(0) + unit` at `y = H - 6`.
- Path data uses `toFixed(1)` coordinates; the area path is the line path plus `L x(n-1) y(min) L x(0) y(min) Z`; the line is `fill="none" stroke={color} strokeWidth={2.5} strokeLinejoin="round" strokeLinecap="round"`.

`MiniBars` render details:

- Empty state: `grid h-[120px] place-items-center text-sm text-faint` with `No reads logged yet.`
- Otherwise `recent = values.slice(-30)` in a `flex h-[120px] items-end gap-1` row; each bar is a `div` with `flex-1 rounded-t-sm` (equal widths, top corners rounded only), `height: ${Math.max(3, v * 100)}%`, `background: color`, `opacity: 0.55 + v * 0.45`, and `title={`${Math.round(v * 100)}%`}` (a hover tooltip — becomes a long-press tooltip or nothing on mobile).
- The React key is the array index, so bars animate/reuse by position, not identity.

### 18.4 Winnings-by-position bar geometry (completes §7.7)

Each row is `flex items-center gap-2 text-[0.76rem]` with four children:

1. `<span className="w-9 font-semibold text-[var(--text)]">` — the position label, fixed 36 px.
2. The track: `relative h-2.5 flex-1 overflow-hidden rounded-full bg-ink-600` (10 px tall). Inside it, first the fill `absolute top-0 h-full rounded-full` with `left = rate < 0 ? `${50 - (|rate|/maxAbs)*50}%` : "50%"`, `width = `${(|rate|/maxAbs)*50}%``, `background = rate >= 0 ? var(--good) : var(--bad)`; then the centre hairline `absolute left-1/2 top-0 h-full w-px bg-white/25` — 1 px wide, white at 25 % opacity, drawn **over** the fill.
3. `<span className={cx("mono w-20 text-right", rate >= 0 ? "text-good" : "text-bad")}>` — fixed 80 px, right-aligned, `${fmtSigned(rate, 0)}/100` or `—` when `hands === 0` (note the colour is chosen by `rate` even when the text is a dash: an untracked position renders a green `—`).
4. `<span className="w-10 text-right text-faint">` — fixed 40 px, `${hands}h`.

Rows sit in `space-y-2`; the footnote is `pt-1 text-[0.7rem] leading-relaxed text-faint`.

### 18.5 Modal widths (completes §6.6 and §7.11)

`Modal` takes an explicit `maxWidth` in px (the design doc's default is 560). Every dialog in this subsystem overrides it:

| dialog | `maxWidth` | source |
|---|---|---|
| Reset all progress? (§7.11) | **440** | `StatsView.tsx:506` |
| Note on hand #N (§6.6) | **440** | `HandNoteEditor.tsx:40` |
| Hand #N replay (§10) | **760** | `HandReplayModal.tsx:36` |

A port that inherits the 560 default renders both 440 dialogs too wide.

### 18.6 `HandNoteEditor` render details (completes §6.6)

- Body is `space-y-3`. Textarea: `rows={4}`, `w-full resize-none rounded-lg border border-[var(--line)] bg-ink-700 px-3 py-2 text-sm leading-relaxed`, placeholder text faint, focus ring `border-gold/60`.
- Tags section label: `mb-1.5 text-[0.68rem] font-semibold uppercase tracking-wide text-faint` reading `Tags`. Chip row is `flex flex-wrap gap-1.5`.
- Chips render `[...PRESET_TAGS, ...customTags]` where `customTags = tags.filter(t => !PRESET_TAGS.includes(t))` — the 5 presets always show, in their fixed order, followed by this note's custom tags. Chip style: `rounded-full px-2.5 py-1 text-[0.72rem] font-semibold transition`; selected `bg-gold text-ink-900`, unselected `bg-ink-700 text-muted` (hover → `--text`).
- The custom-tag input is visually distinct on purpose: `w-[110px] rounded-full border border-dashed border-[var(--line-strong)] bg-transparent px-2.5 py-1 text-[0.72rem]` — a **dashed** outline with no fill, sitting at the end of the same wrap row. `Enter` with non-blank text calls `toggleTag(value.trim().toLowerCase())` and clears it (`preventDefault` stops form submission); blur or any other key does nothing, so a typed-but-not-entered tag is silently discarded on save.
- Footer: `flex items-center justify-between`. Left slot is the `Remove note` ghost button (`size="sm"`, leading `x` icon at `size={14}`) **only when a note already exists**; otherwise an empty `<span />` occupies the slot so `Cancel`/`Save` stay right-aligned. Right slot is `flex gap-2`: ghost `Cancel`, then primary `Save` (`size="sm"`, leading `check` icon `size={14}`, `disabled={!text.trim() && tags.length === 0}`).
- State resets on `key` change (`useEffect([key])` → text, tags, custom input), i.e. every time a different hand is opened; the modal is kept mounted with `hand === null` rendering `null`.

### 18.7 The practice heatmap reads `activity` non-reactively (completes §7.10)

`StatsView` subscribes to `useStats` for its numbers, but the heatmap card calls `useGoals.getState().activity` **inside the render body** (`StatsView.tsx:456`) — a one-shot snapshot, not a subscription. Consequences in the source app:

- Recording a drill or a hand updates `goalStore`, but the Stats tab does **not** repaint on its own; the heatmap refreshes only when StatsView re-renders for another reason (a `handsPlayed` change, an import, opening a modal) or when the tab is re-mounted by navigating away and back.
- In practice the tab is usually entered *after* the practice, so the snapshot is fresh and the staleness is invisible.

This is unspecified behaviour, not a deliberate optimisation. **Recommendation for the Dart port: make it reactive** (`ref.watch` the goals provider) — the heatmap then updates live, which is a strict improvement and cannot break any pinned value. Record the deviation in the port notes so a later diff against the TypeScript does not look like a bug.

---

## 19. Port order and the traps that actually bite

1. **Storage first** (§2–§6). Get `StatsSnapshot`, the four tables, the 800/100 caps and the `chartBase` invariant right; everything else reads from them. Keep the localStorage key names and JSON shapes byte-identical if any migration from a web build is ever wanted.
2. **`hashSeed` once** (§11.4) — shared by quiz keys (§6.5) and import leak seeds; a wrong `Math.imul` port silently changes both.
3. **Local-time everywhere**: `dayKey` (§6.4), the heatmap's midnight (§7.10), the import timestamp (§11.3 step 2). No UTC anywhere.
4. **Units**: play stats in bb via `bigBlind = 20` that is never updated (§2.2); coach leaks in chips with `bb = bigBlind`; import leaks already normalised with `bb = 1` (§11.4). Mixing these produces plausible-looking nonsense.
5. **Imported hands are inert**: excluded from `loadStats` by `source IS NULL`, included in `loadRecentHands`, never touch `hands_played`/`net_chips`, and their `heroNet` is winnings-only (§11.3 step 12).
6. **Never throw on import** (§11.2) and never throw out of the DB layer (§4) — both are user-facing operations on data the app does not control.
7. **Verbatim strings**: every quoted string in §7, §11.5, §13.1, §14 and §15 is user-visible copy that TONE.md governs; translate nothing, and keep the typographic characters (`·` U+00B7, `−` U+2212 in `Recent −EV decisions`, `—` em dashes, curly-free ASCII apostrophes).
