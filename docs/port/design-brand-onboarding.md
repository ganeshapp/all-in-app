# All-In · Poker Dojo — Design, Brand, Shell & Onboarding (port spec)

Source app: `/Users/gapp/Documents/Code/poker` (React 18 + TypeScript + Zustand + Tailwind 3.4 + Radix UI, Tauri v2 desktop shell).
Target: Flutter/Dart mobile re-implementation. This document is the **only** reference the porting engineer has for this subsystem; it is written so the TypeScript never needs to be opened.

Files covered (paths relative to the source repo):

| File | What it owns |
|---|---|
| `src/styles/tokens.css` | Every colour, radius, shadow, font, easing, keyframe |
| `src/index.css` | Global base styles, backdrop/felt/glass surfaces, suit colour vars, four-colour deck, reduced-motion |
| `tailwind.config.js` | Tailwind aliases for the same tokens + extra shadows/animations |
| `src/components/Logo.tsx`, `public/favicon.svg` | The chip-mark logo and wordmark |
| `src/components/ui/Icon.tsx` | The 20-icon line-icon set (inline SVG paths) |
| `src/components/ui/controls.tsx` | `Button`, `Badge`, `ProgressBar`, `Card` |
| `src/components/ui/Dialog.tsx` | `Modal` |
| `src/components/ui/Tooltip.tsx`, `Slider.tsx` | Tooltip and slider primitives |
| `src/components/ui/ErrorBoundary.tsx` | Crash card |
| `src/components/ui/OnboardingModal.tsx` | First-run tour + placement quiz |
| `src/components/ui/ShortcutOverlay.tsx`, `src/lib/hotkeys.ts` | Keyboard shortcuts + overlay |
| `src/components/table/PlayingCard.tsx`, `Board.tsx`, `Pot.tsx`, `HUD.tsx`, `Seat.tsx`, `PokerTable.tsx` | Table rendering |
| `src/components/range/RangeMatrix.tsx` | 13×13 range grid + legend |
| `src/lib/cx.ts` | classNames helper (trivial) |
| `src/App.tsx`, `src/main.tsx`, `index.html` | App shell, sidebar nav, root mount, fonts |
| `src/views/SettingsView.tsx`, `src/views/AboutView.tsx` | Settings rows (accessibility) and About + update notice |
| `src/store/settingsStore.ts`, `themeStore.ts`, `navStore.ts` | Persisted prefs, theme, navigation |
| `README.md`, `.github/workflows/*.yml`, `src-tauri/tauri.conf.json` | CI / release / desktop packaging |

Conventions in this doc:
- Colours are given as the source `R G B` channel triplet **and** hex. Tailwind opacity modifiers such as `gold/15` mean "that colour at 15 % alpha".
- Tailwind sizing used in the source, for reference: `text-xs` 0.75rem/12px, `text-sm` 0.875rem/14px, `text-base` 1rem, `text-xl` 1.25rem, `text-2xl` 1.5rem, `text-3xl` 1.875rem; spacing unit `1` = 4px (`p-4` = 16px, `gap-2` = 8px, `px-3` = 12px, `py-2.5` = 10px, `h-10` = 40px, `w-11` = 44px, `h-1.5` = 6px, `w-5` = 20px, `h-2` = 8px, `h-3` = 12px, `h-7` = 28px, `h-9` = 36px); `rounded-lg` 8px, `rounded-xl` 12px, `rounded-2xl` 16px, `rounded-full` 9999px, `rounded-md` 6px, `rounded` 4px, `rounded-sm` 2px. Root font size is 16px, so e.g. `text-[0.72rem]` = 11.52px.
- All user-visible strings are quoted verbatim; they follow `TONE.md` (plain English first, "you" not "hero", no unexplained jargon) and must be reproduced exactly.

---

## 1. Design tokens

### 1.1 Colour channels — dark theme (default)

Defined on `:root` in `tokens.css` as `--c-<name>: R G B`. A full-colour alias `--<name>: rgb(var(--c-<name>))` exists for every one of them (so both "with alpha" and "solid" uses re-theme together).

| Token | R G B | Hex | Role |
|---|---|---|---|
| `ink-900` | 11 15 20 | `#0B0F14` | App background (`body`), deepest surface |
| `ink-850` | 14 19 26 | `#0E131A` | Slightly raised surface (About hero card, result overlay, error message box) |
| `ink-800` | 17 22 29 | `#11161D` | Panels, modal body, seat plate, cards (`bg-ink-800/80` for Card) |
| `ink-700` | 22 29 38 | `#161D26` | Tooltip body, kbd chips, segmented control track, range-matrix "off" cell, hover for secondary rows |
| `ink-600` | 31 40 51 | `#1F2833` | Secondary button, toggle-off track, progress-bar track, tour inactive dots |
| `ink-500` | 42 53 66 | `#2A3542` | Slider track, scrollbar thumb, secondary button hover |
| `ink-400` | 58 71 87 | `#3A4757` | Scrollbar thumb hover |
| `ink-300` | 85 101 122 | `#55657A` | (reserved, lightest ink) |
| `text` | 233 238 244 | `#E9EEF4` | Primary text |
| `text-muted` | 154 167 180 | `#9AA7B4` | Secondary text (`text-muted`) |
| `text-faint` | 107 120 136 | `#6B7888` | Tertiary text / labels (`text-faint`) |
| `gold` | 232 194 90 | `#E8C25A` | Brand accent, primary buttons, focus ring, active nav, turn ring |
| `gold-dark` | 199 154 54 | `#C79A36` | Logo gradient end |
| `gold-light` | 244 221 146 | `#F4DD92` | Primary-button hover, stack/pot numerals, logo gradient start |
| `felt` | 14 107 70 | `#0E6B46` | Table felt mid |
| `felt-dark` | 9 61 42 | `#093D2A` | Table felt edge |
| `felt-light` | 21 147 95 | `#15935F` | Table felt centre highlight, "success" button |
| `good` | 63 191 127 | `#3FBF7F` | Correct / winner / positive |
| `bad` | 236 90 90 | `#EC5A5A` | Wrong / mistake / error border |
| `warn` | 232 181 74 | `#E8B54A` | Thin spot / "missed" in range compare |
| `info` | 79 155 232 | `#4F9BE8` | Informational / "Call" action tone |
| `suit-red` | 216 58 58 | `#D83A3A` | ♥ and (2-colour deck) ♦ |
| `suit-black` | 27 34 48 | `#1B2230` | ♠ and (2-colour deck) ♣ |
| `combo-pair` | 184 68 47 | `#B8442F` | Range matrix: pair cells (diagonal) |
| `combo-suited` | 47 143 92 | `#2F8F5C` | Range matrix: suited cells (upper-right) |
| `combo-offsuit` | 44 58 74 | `#2C3A4A` | Range matrix: offsuit cells (lower-left) |
| `chip-red` | 210 59 59 | `#D23B3B` | Danger button, "All-In" action tone, "extra" range-compare cell |
| `chip-blue` | 47 111 208 | `#2F6FD0` | (Tailwind only) |
| `chip-green` | 47 170 102 | `#2FAA66` | (Tailwind only) |
| `chip-black` | 32 36 43 | `#20242B` | (Tailwind only) |
| `chip-purple` | 138 92 209 | `#8A5CD1` | (Tailwind only) |

Note: only `--chip-red` has a full-colour CSS alias; the other chip colours are exposed only as Tailwind classes (`bg-chip-blue` etc.). The bot archetype colours (section 6.4) happen to equal chip-blue / chip-purple / chip-green / chip-red.

### 1.2 Colour channels — light theme overrides

Applied when `<html>` has class `light` (`:root.light`). Only the listed channels change; everything not listed (felt, suits, combo-pair, combo-suited, chips, gold-* usage) keeps the dark value.

| Token | R G B | Hex |
|---|---|---|
| `ink-900` | 244 246 249 | `#F4F6F9` |
| `ink-850` | 238 241 245 | `#EEF1F5` |
| `ink-800` | 232 236 242 | `#E8ECF2` |
| `ink-700` | 223 229 237 | `#DFE5ED` |
| `ink-600` | 210 218 228 | `#D2DAE4` |
| `ink-500` | 186 196 209 | `#BAC4D1` |
| `ink-400` | 150 162 176 | `#96A2B0` |
| `ink-300` | 118 131 147 | `#768393` |
| `text` | 17 22 30 | `#11161E` |
| `text-muted` | 74 86 102 | `#4A5666` |
| `text-faint` | 110 123 139 | `#6E7B8B` |
| `gold` | 176 132 32 | `#B08420` |
| `gold-dark` | 140 104 24 | `#8C6818` |
| `gold-light` | 150 112 28 | `#96701C` |
| `good` | 30 150 90 | `#1E965A` |
| `bad` | 200 48 48 | `#C83030` |
| `warn` | 176 128 28 | `#B0801C` |
| `info` | 40 108 200 | `#286CC8` |
| `combo-offsuit` | 150 161 174 | `#96A1AE` |

Light theme also overrides:
- `--line: rgba(0,0,0,0.10)`; `--line-strong: rgba(0,0,0,0.18)` (dark: `rgba(255,255,255,0.08)` and `rgba(255,255,255,0.16)`).
- `--sh-card: 0 2px 6px rgba(15,23,35,0.12), 0 1px 2px rgba(15,23,35,0.08)`.
- `--sh-pop: 0 18px 50px -12px rgba(15,23,35,0.28), 0 4px 12px rgba(15,23,35,0.12)`.

Invariant: white-alpha utilities used inside the table (`bg-black/40`, `text-white/55`, `border-white/10`, …) are **not** themed — the felt is always dark, so those stay fixed in both themes.

### 1.3 Fixed (theme-independent) colours

| Name | Value | Use |
|---|---|---|
| `--rail` | `#2a1a10` | Table rail (also Tailwind `felt-rail`) |
| `--rail-light` | `#43291a` | Rail highlight (unused in components) |
| Table rim border | `#241509` | `PokerTable` felt border, 12px |
| Face-down card gradient | `#11805a` 0% → `#0a4f34` 55% → `#073a2a` 100%, 135° | `PlayingCard` back |
| Face-up card gradient | `#ffffff` 0% → `#eef2f6` 100%, 180° | `PlayingCard` face |
| Logo greens | `#15935f`, `#0e6b46`, `#093d2a`, `#0a4f34`, `#072a1d` | see section 2 |
| Logo golds | `#f4dd92`, `#c79a36` | see section 2 |
| Four-colour ♦ | `#2f7fd6` | `.four-color { --suit-d }` |
| Four-colour ♣ | `#2fa066` | `.four-color { --suit-c }` |
| Unknown-archetype seat colour | `#888` | `Seat` fallback |

### 1.4 Suit colours and the four-colour deck

`index.css`:

```css
:root {
  --suit-h: var(--suit-red);   /* ♥ #D83A3A */
  --suit-d: var(--suit-red);   /* ♦ #D83A3A (2-colour) */
  --suit-s: var(--suit-black); /* ♠ #1B2230 */
  --suit-c: var(--suit-black); /* ♣ #1B2230 (2-colour) */
}
.four-color {
  --suit-d: #2f7fd6;  /* ♦ blue */
  --suit-c: #2fa066;  /* ♣ green */
}
```

The `four-color` class is placed on the app root `<div>` when `settings.fourColorDeck` is true (section 10). `PlayingCard` reads `var(--suit-<s>)` where `s` ∈ `s|h|d|c`. Dart mapping:

```dart
Color suitColor(String suit, bool fourColor) {
  switch (suit) {
    case 'h': return const Color(0xFFD83A3A);
    case 'd': return fourColor ? const Color(0xFF2F7FD6) : const Color(0xFFD83A3A);
    case 's': return const Color(0xFF1B2230);
    case 'c': return fourColor ? const Color(0xFF2FA066) : const Color(0xFF1B2230);
  }
}
```

Suit glyphs (`SUIT_SYMBOL` in `src/engine/cards.ts`): `s → "♠"`, `h → "♥"`, `d → "♦"`, `c → "♣"`. Rank characters: `2 3 4 5 6 7 8 9 T J Q K A`; the card face prints `T` as `10`.

### 1.5 Lines, radii, shadows, fonts, easing

```
--line:        rgba(255,255,255,0.08)   (light: rgba(0,0,0,0.10))
--line-strong: rgba(255,255,255,0.16)   (light: rgba(0,0,0,0.18))

--r-sm: 6px   --r-md: 10px   --r-lg: 16px   --r-xl: 22px

--sh-card:  0 2px 6px rgba(0,0,0,0.35), 0 1px 2px rgba(0,0,0,0.25)
--sh-pop:   0 18px 50px -12px rgba(0,0,0,0.7), 0 4px 12px rgba(0,0,0,0.4)
--glow-gold: 0 0 0 1px rgba(232,194,90,0.45), 0 0 26px -4px rgba(232,194,90,0.5)
Tailwind-only shadows:
  shadow-chip:  0 3px 6px rgba(0,0,0,0.5)
  shadow-table: inset 0 0 120px rgba(0,0,0,0.55), 0 30px 70px -24px rgba(0,0,0,0.7)

--font-display: "Bricolage Grotesque", ui-sans-serif, system-ui, sans-serif
--font-sans:    "Inter", ui-sans-serif, system-ui, sans-serif
--font-mono:    "JetBrains Mono", ui-monospace, monospace

--ease: cubic-bezier(0.2, 0.8, 0.2, 1)
```

Fonts are loaded from Google Fonts in `index.html`:
`Bricolage+Grotesque:opsz,wght@12..96,400..800`, `Inter:wght@400;500;600;700`, `JetBrains+Mono:wght@400;500;700`. **Port note:** bundle these three families as assets (Bricolage Grotesque 400–800, Inter 400/500/600/700, JetBrains Mono 400/500/700); the app is offline-first and must not depend on the network for type.

Typography rules (`index.css @layer base`):
- `body`: background `ink-900`, colour `text`, family `font-sans`, antialiased, `overflow: hidden` (the app never scrolls at the window level; each view scrolls internally).
- `h1–h4`: family `font-display`, weight 700, `letter-spacing: -0.01em`, `line-height: 1.1`.
- `.mono`: `font-mono` + `font-variant-numeric: tabular-nums`. `.numeric`: tabular-nums only.
- `:focus-visible`: `outline: 2px solid var(--gold); outline-offset: 2px`.
- Scrollbars (WebKit): 10px wide, transparent track, thumb `ink-500` with `border-radius: 999px` and a 2px `ink-900` border; thumb hover `ink-400`.

### 1.6 Surfaces (`index.css @layer components`)

```css
.app-backdrop {  /* root of the whole app */
  background:
    radial-gradient(1200px 600px at 70% -10%, rgba(21,147,95,0.12), transparent 60%),
    radial-gradient(900px 500px at -10% 110%, rgba(232,194,90,0.06), transparent 55%),
    var(--ink-900);
}
.felt-surface {  /* the table */
  background: radial-gradient(120% 120% at 50% 35%,
    var(--felt-light) 0%, var(--felt) 38%, var(--felt-dark) 100%);
}
.glass {  /* frosted card, used by the "Ready to play?" overlay */
  background: linear-gradient(180deg, rgba(255,255,255,0.05), rgba(255,255,255,0.02));
  backdrop-filter: blur(8px);
  border: 1px solid var(--line);
}
```

### 1.7 Keyframes and named animations

Keyframes (both `tokens.css` and Tailwind define the same ones):

| Name | From | To | Notes |
|---|---|---|---|
| `dealIn` | `translateY(-34px) rotate(-6deg) scale(0.85)`, opacity 0 | identity, opacity 1 | Tailwind `animate-deal-in`: 0.34s `cubic-bezier(0.2,0.8,0.2,1)` both |
| `fadeUp` | `translateY(8px)`, opacity 0 | identity, opacity 1 | `animate-fade-up`: 0.3s ease-out both |
| `pop` | 0%: `scale(0.85)` opacity 0 · 60%: `scale(1.04)` · 100%: `scale(1)` opacity 1 | | `animate-pop`: 0.25s ease-out both. Modal uses `pop .22s var(--ease)`, Tooltip `pop .14s var(--ease)` |
| `overlayIn` | opacity 0 | opacity 1 | Modal overlay: `.18s ease` |
| `spin` | | `rotate(360deg)` | "dealing" spinner: `spin 0.9s linear infinite` |
| `slideInRight` (Tailwind only) | `translateX(110%)` opacity 0 | identity | `animate-slide-in-right`: 0.35s `cubic-bezier(0.2,0.8,0.2,1)` both (EV coach panel) |
| `pulseRing` (Tailwind only) | 0%: `box-shadow: 0 0 0 0 rgba(232,194,90,0.55)` · 70%: `0 0 0 13px rgba(232,194,90,0)` · 100%: `0 0 0 0 rgba(232,194,90,0)` | | `animate-pulse-ring`: 1.7s ease-out infinite (seat whose turn it is) |
| `shimmer` (Tailwind only) | | `translateX(100%)` | defined, unused |

Where used in this subsystem: `Board` (deal-in, staggered `i * 55ms`), `Seat` (pulse-ring on the acting seat; fade-up on the street-bet chip), `PokerTable` (spin), `Modal`/`Tooltip` (pop, overlayIn). Outside it: EV coach panel (slide-in-right), result overlay (pop), drill feedback and equity calculator (fade-up).

### 1.8 Reduced motion

Two independent mechanisms, both must be honoured:

1. User setting `settings.reducedMotion` → class `reduce-motion` on the app root:
   ```css
   .reduce-motion *, .reduce-motion *::before, .reduce-motion *::after {
     animation: none !important; transition: none !important;
   }
   ```
2. OS preference `@media (prefers-reduced-motion: reduce)` — `index.css` sets `animation: none; transition: none` and `tokens.css` sets `animation-duration: 0.01ms; animation-iteration-count: 1; transition-duration: 0.01ms` (both `!important`; net effect is "no motion").

Flutter: read `MediaQuery.disableAnimations` OR the stored setting; if either is true, use `Duration.zero` for every implicit/explicit animation in this subsystem (deal-in, fade-up, pop, pulse-ring, spin, slide-in, toggle knob, progress bar width transition).

---

## 2. Logo and favicon

`Logo({ size = 40, withWordmark = false })` renders a 64×64-viewBox SVG at `size × size` with `filter: drop-shadow(0 4px 10px rgba(0,0,0,0.45))`, `role="img"`, `aria-label="All-In logo"`. Gradient ids are made unique per instance in React; in Flutter just draw it. The favicon is the identical SVG. Verbatim:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <radialGradient id="body" cx="50%" cy="36%" r="72%">
      <stop offset="0%" stop-color="#15935f" />
      <stop offset="60%" stop-color="#0e6b46" />
      <stop offset="100%" stop-color="#093d2a" />
    </radialGradient>
    <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#f4dd92" />
      <stop offset="100%" stop-color="#c79a36" />
    </linearGradient>
  </defs>
  <circle cx="32" cy="32" r="30" fill="url(#body)" stroke="#072a1d" stroke-width="2" />
  <circle cx="32" cy="32" r="25.5" fill="none" stroke="#f4dd92" stroke-width="5"
          stroke-dasharray="6 7.34" />
  <circle cx="32" cy="32" r="19" fill="#0a4f34" stroke="#f4dd92" stroke-width="1.4" />
  <path d="M32 16 C 26 24, 16 30, 16 37 C 16 42, 20 45, 24.5 43.5 C 24 46, 22 48.5, 19.5 50 L 44.5 50 C 42 48.5, 40 46, 39.5 43.5 C 44 45, 48 42, 48 37 C 48 30, 38 24, 32 16 Z"
        fill="url(#gold)" />
</svg>
```

Reading of the mark: a green poker chip (radial green body, dark `#072a1d` 2px rim), a dashed gold ring at r=25.5 (stroke 5, dash `6 7.34` — with circumference 2π·25.5 ≈ 160.2 the pattern `13.34` repeats exactly 12 times, i.e. 12 chip "edge spots"), an inner dark-green disc r=19 with a thin gold rim, and a gold spade silhouette (the path) centred on the chip.

Wordmark (only when `withWordmark`), laid out to the right of the mark with a 12px gap (`gap-3`), `leading-none`:
- Line 1: `All-In` — display font, `1.4rem` (22.4px), weight 800, `tracking-tight` (−0.025em), colour `text`.
- Line 2 (margin-top 4px): `Poker Dojo` — `0.6rem` (9.6px), weight 600, uppercase, `letter-spacing: 0.34em`, colour `gold` at 80 % alpha.

Usage: sidebar (`size=40`, with wordmark), About hero (`size=64`, no wordmark). App icons for the desktop are PNG/ICNS/ICO renders of this SVG in `src-tauri/icons/` (32, 128, 128@2x, 512, Windows Square logos); regenerate the mobile launcher icons from the SVG above.

Window/app title everywhere: `All-In · Poker Dojo` (middle dot U+00B7 with spaces).

---

## 3. Iconography

`Icon({ name, size = 20, className, strokeWidth = 2 })` renders a 24×24-viewBox SVG at `size × size`, `fill="none"`, `stroke="currentColor"`, `stroke-width=2`, `stroke-linecap="round"`, `stroke-linejoin="round"`, `aria-hidden`. Some glyphs override to `fill="currentColor" stroke="none"` (marked below). Every icon, path verbatim:

| Name | SVG children (24×24) | Where used |
|---|---|---|
| `play` | `<polygon points="6 4 20 12 6 20 6 4" fill="currentColor" stroke="none"/>` | Nav "Play", tour step 1, onboarding "Start playing", About "Play online"/"Play" card |
| `book` | `<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>` | Nav "Study", tour step 3, "Take me there", About "Study", Study level 1 |
| `stats` | `<line x1="6" y1="20" x2="6" y2="14"/><line x1="12" y1="20" x2="12" y2="9"/><line x1="18" y1="20" x2="18" y2="4"/>` | Nav "Stats", About "Stats" |
| `eye` | `<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>` | Seat "guess range" button, Settings "Table & cards" header, coach "Read" verdict |
| `coach` | `<path d="M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9zM19 14l.9 2.1L22 17l-2.1.9L19 20l-.9-2.1L16 17l2.1-.9z" fill="currentColor" stroke="none"/>` (two four-point sparkles) | Tour step 4, Settings "Coach" header, "Explain last move" |
| `settings` | `<line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="1" y1="14" x2="7" y2="14"/><line x1="9" y1="8" x2="15" y2="8"/><line x1="17" y1="16" x2="23" y2="16"/>` (three sliders) | **Defined but unused** — the Settings nav item uses `target` (source quirk; a port may reasonably use `settings` here) |
| `chevron-right` | `<polyline points="9 18 15 12 9 6"/>` | List rows / disclosure (14 call sites outside this subsystem) |
| `check` | `<polyline points="20 6 9 17 4 12"/>` | About "Good to know" bullets (good colour), coach "Reasonable"/"Nice play" |
| `x` | `<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>` | Modal close (size 20), coach "Mistake" |
| `refresh` | `<polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>` | Redeal/retry buttons elsewhere |
| `arrow-right` | `<line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>` | Tour "Next"/"Continue" (size 14), update notice (12), About roadmap bullets (14), gapp.in link (14) |
| `trophy` | `<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M5 4H3v2a3 3 0 0 0 3 3M19 4h2v2a3 3 0 0 1-3 3"/>` | **Defined, unused** |
| `chip` | `<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3.4"/><line x1="12" y1="3" x2="12" y2="6"/><line x1="12" y1="18" x2="12" y2="21"/><line x1="3" y1="12" x2="6" y2="12"/><line x1="18" y1="12" x2="21" y2="12"/>` | Pot pill (16, gold), About "Download desktop" (18) |
| `lock` | `<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>` | **Defined, unused** |
| `target` | `<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.4" fill="currentColor" stroke="none"/>` | Nav "Drills" **and** nav "Settings", tour step 2, "Calibrate me", About "Drills", Study levels 3 & 5 |
| `bolt` | `<polygon points="13 2 4 14 12 14 11 22 20 10 12 10 13 2"/>` | Sidebar "Tip" card (13), Settings "Keyboard" header (15), Study level 4 |
| `info` | `<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="11"/><line x1="12" y1="8" x2="12.01" y2="8"/>` | Nav "About", About bullets (info colour), coach "Thin spot" |
| `cards` | `<rect x="3" y="7" width="12" height="15" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-2"/>` | Study level 2, session summary "Copy" |
| `sun` | `<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>` | Theme toggle when theme is light |
| `moon` | `<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>` | Theme toggle when theme is dark |

`IconName` union (exact): `play | book | stats | eye | coach | settings | chevron-right | check | x | refresh | arrow-right | trophy | chip | lock | target | bolt | info | cards | sun | moon`.

---

## 4. Shared UI primitives

### 4.1 `cx(...parts)` (`src/lib/cx.ts`)

Joins class names with single spaces. Accepts `string | number | null | undefined | false | Record<string, boolean|null|undefined>`; falsy parts are skipped; for a map, keys with truthy values are emitted in insertion order. Numbers are stringified. Pure utility — no Dart equivalent needed beyond a conditional style list.

### 4.2 `Button({ variant = "primary", size = "md" })`

Base: inline-flex, centred, `gap-2` (8px) between icon and label, `border-radius: 10px`, weight 600, `transition`, pressed state `scale(0.98)`, disabled: `opacity 0.45` and no pointer events.

| Variant | Style |
|---|---|
| `primary` | bg `gold`, text `ink-900`, hover bg `gold-light`, `shadow-card` |
| `secondary` | bg `ink-600`, text `text`, hover bg `ink-500`, 1px border `line` |
| `ghost` | transparent, text `muted`; hover text `text`, hover bg white/5 |
| `danger` | bg `chip-red`, text white, hover `brightness(1.1)` |
| `success` | bg `felt-light`, text white, hover `brightness(1.1)` |
| `outline` | 1px border `gold` @50 %, text `gold`, hover bg `gold` @10 % |

| Size | Height | Horizontal padding | Font |
|---|---|---|---|
| `sm` | 32px | 12px | 0.8rem (12.8px) |
| `md` | 40px | 16px | 0.875rem |
| `lg` | 48px | 20px | 0.95rem (15.2px) |

### 4.3 `Badge({ children, color? })`

Pill: inline-flex, `gap-1`, `rounded-full`, padding 8px × 2px, font 0.68rem (10.88px), weight 600, `line-height: 1`. When `color` (a hex string) is given: background = `color + "22"` (hex alpha 0x22 ≈ 13 %), text = `color`. No call sites in the current source, but exported.

### 4.4 `ProgressBar({ value, max = 100, tone = "var(--gold)" })`

Track: height 8px, `rounded-full`, bg `ink-600`, `overflow: hidden`, `role=progressbar`, `aria-valuenow=round(value)`, `aria-valuemax=max`. Fill: `width = clamp((value/max)*100, 0, 100)%`, bg `tone`, `rounded-full`, width transition 500ms.

### 4.5 `Card({ glass? })`

`border-radius: 16px`, 1px border `line`, padding 20px; background `ink-800` @80 % — or the `.glass` surface if `glass`.

### 4.6 `Modal({ open, onOpenChange, title, description?, maxWidth = 560, hideClose?, className? })` (Radix Dialog)

- Overlay: fixed full-screen, `z-50`, `bg-black/65`, `backdrop-blur(3px)`, animation `overlayIn .18s ease`. Clicking the overlay or pressing **Esc** calls `onOpenChange(false)`.
- Content: centred, `max-height 92vh`, `width 94vw`, `max-width = maxWidth`, `overflow: auto`, `border-radius 18px`, 1px border `line-strong`, bg `ink-800`, padding 24px, `shadow: var(--sh-pop)`, animation `pop .22s var(--ease)`.
- Header row (`margin-bottom 16px`, flex, `gap-4`, items-start, space-between): `Title` in display font `text-xl` bold colour `text`; optional `Description` below it (`margin-top 4px`, `text-sm`, muted). Unless `hideClose`, a close button on the right: `rounded-lg`, padding 6px, muted, hover bg white/5 + text `text`, `aria-label="Close"`, icon `x` size 20.
- Children rendered below.

### 4.7 `Tooltip({ content, side = "top" })` (Radix Tooltip)

Delay 250ms; `sideOffset` 6px; content: `z-60`, `max-width 260px`, `rounded-lg`, 1px border `line-strong`, bg `ink-700`, padding 12px × 8px, `text-xs`, colour `text`, `shadow: var(--sh-pop)`, animation `pop .14s var(--ease)`; arrow filled `ink-700`. On mobile, treat the trigger as tap-to-show (HUD uses it — section 6.4).

### 4.8 `Slider({ value, min, max, step = 1, onValueChange, ariaLabel = "Value" })` (Radix Slider)

`safeMax = max(min, max)`; displayed value clamped to `[min, safeMax]`. Root height 20px, `touch-none select-none`. Track 6px tall, `rounded-full`, bg `ink-500`; filled range bg `gold`. Thumb 16px circle, bg `gold`, 2px border `ink-900`, `shadow-card`; focused thumb gets `box-shadow: var(--glow-gold)`.

### 4.9 Settings-only controls (`SettingsView.tsx`)

- `Toggle`: `role=switch`, 44×24px pill, bg `gold` when on else `ink-600`; knob 20px white circle with shadow, `top: 2px`, `left: 22px` when on else `2px`, transition.
- `Segmented`: container `rounded-lg` bg `ink-700` padding 2px, flex; each option `rounded-md`, padding 10px × 4px, font 0.74rem weight 600; selected: bg `gold` text `ink-900`; others: muted, hover `text`.
- `Row({ title, desc })`: flex space-between, `gap-6`, `py-3`, bottom 1px border `line` except last; title `text-sm` weight 600 colour `text`; desc `margin-top 2px`, `max-width 420px`, 0.78rem, relaxed leading, muted; control on the right (`shrink-0`).

---

## 5. Playing card rendering (`PlayingCard`)

Signature: `PlayingCard({ card?: Card | null, faceDown?: boolean, w = 46, dim?: boolean, className?, style? })` where `Card` is a 2-char string like `"Ah"`, `"Td"` (rank char then suit char).

Geometry, all derived from width `w` (pixels):

```
h      = round(w * 1.4)                 // 46 → 64, 36 → 50, 56 → 78, 26 → 36
radius = max(4, round(w * 0.13))        // 46 → 6,  36 → 5,  56 → 7,  26 → 4
```

**Face-down / no card** (`faceDown || !card`):
- Box `w × h`, corner `radius`, `shadow-card`, 1px ring `rgba(0,0,0,0.40)`.
- Background: `linear-gradient(135deg, #11805a 0%, #0a4f34 55%, #073a2a 100%)`.
- Inner frame inset 3px on all sides, corner `radius − 2`, `border: 1px solid rgba(232,194,90,0.45)`, centred content.
- Centre ornament: circle of diameter `w * 0.34` (46 → 15.64), `border: 2px solid rgba(232,194,90,0.6)`, no fill.

**Face-up**:
- Box `w × h`, corner `radius`, `overflow: hidden`, `shadow-card`, 1px ring `rgba(0,0,0,0.15)`.
- Background: `linear-gradient(180deg, #ffffff 0%, #eef2f6 100%)`.
- `opacity = dim ? 0.55 : 1`.
- Ink colour `color = suitColor(suit)` (section 1.4) for all three glyphs.
- Rank glyph (top-left): text = rank, except `"T"` renders as `"10"`. Position `left = w*0.12`, `top = h*0.06`; `font-size = w*0.36`; display font, weight 800, `line-height: 1`.
- Small suit glyph under the rank: `left = w*0.13`, `top = h*0.34`; `font-size = w*0.26`; `line-height 1`.
- Large suit glyph bottom-right: `right = w*0.08`, `bottom = h*0.04`; `font-size = w*0.5`; opacity 0.92; `line-height 1`. (Clipped by `overflow: hidden` if it overflows.)

Worked example, `w = 46`: h 64, radius 6, rank at (5.52, 3.84) size 16.56, small suit at (5.98, 21.76) size 11.96, big suit 3.68 from right and 2.56 from bottom, size 23.

Card widths used: hero hole cards 46, bot hole cards 36, board 56, Settings four-colour preview 26 (cards `As Ah Ad Ac` in that order).

Dart sketch:

```dart
class PlayingCard extends StatelessWidget {
  final String? card; final bool faceDown; final double w; final bool dim;
  Widget build(ctx) {
    final h = (w * 1.4).roundToDouble();
    final radius = math.max(4, (w * 0.13).round()).toDouble();
    if (faceDown || card == null) return _back(w, h, radius);
    final rank = card![0] == 'T' ? '10' : card![0];
    final suit = card![1];
    final color = suitColor(suit, fourColor);
    return Container(width: w, height: h, clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(begin: top, end: bottom, colors: [0xFFFFFFFF, 0xFFEEF2F6]),
        boxShadow: shCard, border: Border.all(color: Color(0x26000000), width: 1)),
      child: Opacity(opacity: dim ? 0.55 : 1, child: Stack(children: [
        Positioned(left: w*0.12, top: h*0.06, child: Text(rank, style: display(w*0.36, w800, color))),
        Positioned(left: w*0.13, top: h*0.34, child: Text(suitGlyph(suit), style: sans(w*0.26, color))),
        Positioned(right: w*0.08, bottom: h*0.04, child: Opacity(opacity: .92,
          child: Text(suitGlyph(suit), style: sans(w*0.5, color)))),
      ])));
  }
}
```

---

## 6. Table components

### 6.1 `Board({ cards: Card[], w = 56 })`

Always renders **five slots** in a row, `gap-2` (8px), centred vertically.
- Slot `i` with a card: `PlayingCard(card, w)` with class `animate-deal-in` and `animation-delay = i * 55ms` (so the flop staggers 0/55/110ms, turn 165ms, river 220ms — note the delay is by slot index, so a freshly dealt river always waits 220ms).
- Empty slot: box `w × round(w*1.4)`, corner `max(4, round(w*0.13))`, `border: 1px dashed rgba(255,255,255,0.12)` (source class `border-white/12` — intent 12 %), background `rgba(0,0,0,0.10)`.

### 6.2 `Pot({ pot, bb, street })`

Column, centred, `gap-1`:
1. Street label: uppercase, 0.62rem, weight 600, `letter-spacing 0.3em`, colour white @55 %. Mapping (`STREET_LABEL`):
   `preflop → "Pre-flop"`, `flop → "Flop"`, `turn → "Turn"`, `river → "River"`, `showdown → "Showdown"`.
2. Pill: flex `gap-2`, `rounded-full`, 1px border `gold` @30 %, bg black @35 %, padding 16px × 6px, `shadow-card`, backdrop blur. Contents: `chip` icon size 16 in `gold`, then `"{fmtBb(pot, bb)} bb"` in mono, 0.95rem, bold, `gold-light`.

### 6.3 `fmtBb(chips, bb)` (`src/lib/format.ts`) — used by Pot and Seat

```
v = chips / bb
rounded = round(v * 10) / 10       // JS Math.round: half away from zero for positives
return isInteger(rounded) ? "${rounded}" : rounded.toFixed(1)
```
Examples to pin in tests: `fmtBb(200,100) → "2"`, `fmtBb(150,100) → "1.5"`, `fmtBb(1234,100) → "12.3"`, `fmtBb(105,100) → "1.1"` (10.5 rounds up), `fmtBb(0,100) → "0"`, `fmtBb(99,100) → "1"`, `fmtBb(2550,50) → "51"`.

Other helpers in the same file that the TONE rules reference (pin these too):
- `fmtChips(n)` → `round(n)` with locale thousands separators.
- `fmtSigned(n, digits=1)` → round to `digits`, prefix `"+"` when `>= 0`: `fmtSigned(1.25) → "+1.3"`, `fmtSigned(-0.04) → "-0.0"`, `fmtSigned(0) → "+0.0"`.
- `fmtPct(frac, digits=0)` → `"${(frac*100).toFixed(digits)}%"`: `fmtPct(0.318) → "32%"`.
- `fmtTimes(p)`: `p >= 0.93 → "almost every time"`; `p <= 0.04 → "almost never"`; `p >= 0.45 → "about N times in 10"` with `N = round(p*10)`; else `"about 1 time in N"` with `N = round(1/p)`. Examples: `0.31 → "about 1 time in 3"`, `0.25 → "about 1 time in 4"`, `0.7 → "about 7 times in 10"`, `0.5 → "about 5 times in 10"`, `0.95 → "almost every time"`, `0.02 → "almost never"`.
- `fmtNeed(potOdds)`: `<= 0 → "any win rate"`; else `n = 1/potOdds`, `rounded = round(n*2)/2`, `"about 1 time in " + (integer ? "N" : N.toFixed(1))`. Examples: `0.25 → "about 1 time in 4"`, `0.3 → "about 1 time in 3.5"` (3.33→3.5), `0.5 → "about 1 time in 2"`.

### 6.4 `HUD({ player })`

Constant `MIN_SAMPLE = 8` — "reads must be earned": numbers appear only after 8 observed hands.

```
n = player.handsSeen
enough = n >= 8
vpip = enough ? round(player.vpipCount / n * 100) : null
pfr  = enough ? round(player.pfrCount  / n * 100) : null
```
Returns nothing if `player.archetype` is unset (hero). Otherwise a pill wrapped in a `Tooltip(side: bottom)`:

Pill: flex `gap-1.5`, `rounded-md`, 1px border `line`, bg black @45 %, padding 6px × 2px, backdrop blur, `cursor: help`. Contents: an 8px dot filled with the archetype colour, then mono 0.62rem weight 600 white @85 %:
- if `enough`: `"{vpip}"` + `"/"` (white @40 %) + `"{pfr}"` + `" {n}h"` (margin-left 4px, white @35 %) — e.g. `24/18 12h`.
- else: `"–/– · {n}h"` (en dash U+2013, middle dot) in white @45 % — e.g. `–/– · 3h`.

Tooltip content (column, `space-y-1`):
1. `"{cfg.name} ({cfg.archetype})"` — weight 600, `gold-light`. e.g. `Tight-Aggressive (TAG)`.
2. `cfg.blurb` — muted.
3. Footnote (padding-top 4px, 0.7rem, faint), one of:
   - enough: `Observed over {n} hands this session — VPIP = how often they put money in pre-flop, PFR = how often they raise. Each player's exact numbers vary, so watch them settle.`
   - not enough: `Stats appear after 8 observed hands ({n} so far) — reads are earned, not given.`

Archetype table (`src/game/archetypes.ts`) — only the fields this subsystem displays:

| Key | `name` | `blurb` | `color` |
|---|---|---|---|
| `TAG` | Tight-Aggressive | Plays few hands but bets and raises them hard. The textbook winner. | `#2f6fd0` |
| `LAG` | Loose-Aggressive | Plays many hands with relentless pressure. Hard to put on a hand. | `#8a5cd1` |
| `Nit` | Nit | Extremely tight. If a Nit raises, believe them. | `#2faa66` |
| `Station` | Calling Station | Calls far too much, rarely raises. Value-bet relentlessly, never bluff. | `#d23b3b` |

(Their nominal VPIP/PFR are TAG 22/18, LAG 34/27, Nit 12/9, Station 46/7 — the HUD shows *observed* counts, not these.)

### 6.5 `Seat({ player, bb, isCurrent, isButton, isWinner, canGuess, onGuess })`

Inputs from `Player` (`src/types/poker.ts`): `id`, `name`, `isHero`, `archetype?`, `stack`, `hole: [Card,Card] | null`, `revealed`, `hasFolded`, `committed` (chips this street), `position` (`UTG|MP|CO|BTN|SB|BB`), `lastAction: { label, street } | null` (labels: `"Raise" "Bet" "Call" "Check" "Fold" "All-In" "SB" "BB"`), `handsSeen`, `vpipCount`, `pfrCount`.

Derived:
```
realistic = settings.realisticReveal
showHole  = player.isHero || (player.revealed && !(realistic && player.hasFolded))
color     = player.isHero ? gold : player.archetype ? ARCHETYPES[archetype].color : "#888"
holeW     = player.isHero ? 46 : 36
initial   = player.isHero ? "Y" : player.name[0]
```
`showHole` semantics: your own cards are always face-up; a bot's cards are face-up once `revealed` (showdown, or the end-of-hand learning reveal) — **unless** "Realistic reveals" is on and the bot folded, in which case they stay face-down.

Layout: column, centred, `gap-1.5` (6px):

1. **Hole cards row** — flex `gap-1` (4px); when `player.hasFolded`: `opacity 0.30` + `grayscale`. If `player.hole` is set: two `PlayingCard`s at `holeW`, each `card = showHole ? hole[i] : null`, `faceDown = !showHole`. If no hole (between hands): an empty spacer of height `round(holeW*1.4)` so the plate doesn't jump.

2. **Plate** — `width 128px`, `rounded-2xl` (16px), bg `ink-800` @90 %, padding 12px × 8px, backdrop blur, `transition`. Ring states (in precedence order as CSS classes combine):
   - `isCurrent` (this seat is to act): `ring-2` in `gold` **plus** `animate-pulse-ring` (the gold halo that expands to 13px and fades, every 1.7s).
   - otherwise: `ring-1` in `line`.
   - `isWinner` additionally: `ring-2` in `good` (overrides the ring colour).
   - `player.hasFolded`: whole plate `opacity 0.55`.

   Contents:
   - **Guess-range button** (only when `canGuess`): absolutely positioned at `top: -8px; right: -8px`, `z-10`, 28px circle, 1px border `gold` @50 %, bg `ink-700`, colour `gold`, `shadow-card`; hover → bg `gold`, text `ink-900`; tooltip/title `Guess {player.name}'s range`; `eye` icon 15. Tapping calls `onGuess(player.id)` (opens the Guess/Peek modal — another subsystem).
   - **Row 1** (flex, `gap-2`, centred):
     - Avatar: 36px circle, display font `text-sm` bold, background `color` @ hex-alpha `22` (~13 %), text `color`, `border: 1.5px solid color + "66"` (~40 %). Text = `initial`.
     - Name block (`flex-1 min-w-0`):
       - line: `player.name` (0.8rem, weight 600, colour `text`, truncated) + position badge (`rounded` 4px, bg white @8 % — source `bg-white/8`, which Tailwind's default scale doesn't generate, so it may render transparent on desktop; use 8 %), padding 4px × 0, 0.58rem, weight 600, uppercase, tracking-wide, muted: e.g. `BTN`.
       - line: stack in mono 0.72rem `gold-light` @90 %: `"{fmtBb(stack, bb)} "` + `bb` in faint.
     - **Dealer button** (only `isButton`): 20px white circle, text `D` 0.6rem weight 800 colour `ink-900`, small shadow.
   - **Row 2** (margin-top 6px, flex space-between, `gap-2`):
     - left: `HUD(player)` if `player.archetype` else the label `HERO` (0.62rem, weight 600, `gold` @70 %).
     - right (only if `player.lastAction`): `lastAction.label` in 0.66rem weight 600 with tone from `actionTone`:

       | label | class | colour |
       |---|---|---|
       | `Raise`, `Bet` | `text-gold` | gold |
       | `All-In` | `text-chip-red` | chip-red |
       | `Call` | `text-info` | info |
       | `Fold` | `text-faint` | faint |
       | anything else (`Check`, `SB`, `BB`, …) | `text-muted` | muted |

3. **Current-street bet** — a fixed 20px-tall row; when `player.committed > 0`: pill with `animate-fade-up`, `rounded-full`, 1px border `gold` @25 %, bg black @40 %, padding 8px × 2px, mono 0.66rem weight 600 `gold-light`, text `"{fmtBb(committed, bb)} bb"`.

### 6.6 `PokerTable()`

Reads the game store: `table` (players, phase, toAct, button, pot, bigBlind, street, board, summary), `thinking` (bool: bots are "dealing"/thinking), `openGuess(id)`.

Winners: when `table.phase === "hand-over"` and `table.summary` exists, `winners = ∪ potResults[*].winners` (player ids). Otherwise empty.

Container: `position: relative`, full height/width, `max-width 1000px`, centred.

- **Felt**: absolutely centred, `width 90%`, `height 80%` of the container, `border-radius: 46% / 50%` (elliptical), `border: 12px solid #241509`, `felt-surface` background, `shadow-table`.
- **Inner rail line**: centred, `84% × 72%`, same radius, `border: 1px solid rgba(255,255,255,0.10)`, pointer-events none.
- **Centre stack**: absolutely at `left 50%, top 39%` (translated −50 %/−50 %), column centred `gap-3` (12px): `Pot`, `Board`, then a 20px-tall row that shows, while `thinking`, a spinner + the word `dealing`: flex `gap-2`, 0.66rem, weight 500, uppercase, `letter-spacing 0.25em`, white @55 %; spinner = 14px circle, `border: 2px solid rgba(255,255,255,0.25)` with the top segment `gold`, `spin 0.9s linear infinite`.
- **Seats**: for each player `p`, an absolutely positioned wrapper (translated −50 %/−50 %) at `seatPos(players.length, p.id)` containing `Seat` with:
  ```
  canGuess  = phase === "betting" && !p.isHero && !p.hasFolded && p.hole != null
  isCurrent = phase === "betting" && table.toAct === p.id
  isButton  = table.button === p.id
  isWinner  = winners.contains(p.id)
  ```

**Seat placement algorithm** (`seatPos(n, i)`), hero (`id 0`) always bottom-centre, seats then proceed counter-clockwise on screen (bottom → right → top → left):

```
rad  = π/2 − (2π · i) / n
left = 50 + 42·cos(rad)   (% of container width,  1 decimal)
top  = 48 + 41·sin(rad)   (% of container height, 1 decimal; y grows downward)
```

Pinned outputs:

| n | i | left % | top % |
|---|---|---|---|
| 2 | 0 | 50.0 | 89.0 |
| 2 | 1 | 50.0 | 7.0 |
| 6 | 0 | 50.0 | 89.0 |
| 6 | 1 | 86.4 | 68.5 |
| 6 | 2 | 86.4 | 27.5 |
| 6 | 3 | 50.0 | 7.0 |
| 6 | 4 | 13.6 | 27.5 |
| 6 | 5 | 13.6 | 68.5 |
| 9 | 0 | 50.0 | 89.0 |
| 9 | 1 | 77.0 | 79.4 |
| 9 | 2 | 91.4 | 55.1 |
| 9 | 3 | 86.4 | 27.5 |
| 9 | 4 | 64.4 | 9.5 |
| 9 | 5 | 35.6 | 9.5 |
| 9 | 6 | 13.6 | 27.5 |
| 9 | 7 | 8.6 | 55.1 |
| 9 | 8 | 23.0 | 79.4 |

Port note: on a portrait phone the 90 %×80 % ellipse and 128px plates will not fit as-is; keep the *ordering* and the counter-clockwise ring, but expect to re-derive the radii (e.g. swap to a taller ellipse and scale plates). Preserve: hero bottom-centre, button at the seat, pot/board slightly above centre (39 %).

---

## 7. Range matrix (`RangeMatrix`, `RangeLegend`)

### 7.1 Grid definition (`src/engine/notation.ts`)

13×13, rows and columns indexed by `RANKS_DESC = [A,K,Q,J,T,9,8,7,6,5,4,3,2]` (A top-left).

```
labelAt(row, col):
  hi = RANKS_DESC[min(row,col)]; lo = RANKS_DESC[max(row,col)]
  row == col  → "${hi}${hi}"        (pair,    e.g. "AA")
  col >  row  → "${hi}${lo}s"       (suited,  upper-right triangle, e.g. "AKs")
  row >  col  → "${hi}${lo}o"       (offsuit, lower-left triangle,  e.g. "AKo")

kindOf(label):  length 2 → "pair"; endsWith "s" → "suited"; else "offsuit"
comboCount(label): pair 6 · suited 4 · offsuit 12
allLabels(): 169 labels row-major;  combosInSet(allLabels()) == 1326
cardsToLabel(a, b): higher rank first; same rank → pair; same suit char → "s" else "o"
```

Pinned by `scripts/engine_test.ts` (lines 89–95):
- `comboCount("AA") == 6`, `comboCount("AKs") == 4`, `comboCount("AKo") == 12`
- `allLabels().length == 169`
- `combosInSet(allLabels()) == 1326` (`TOTAL_COMBOS`)
- `labelToCombos("AKs").length == 4`
- `cardsToLabel("As","Kd") == "AKo"`, `cardsToLabel("As","Ks") == "AKs"`, `cardsToLabel("Ts","Td") == "TT"`

Additional values worth pinning for the grid itself: `labelAt(0,0)=="AA"`, `labelAt(0,1)=="AKs"`, `labelAt(1,0)=="AKo"`, `labelAt(12,12)=="22"`, `labelAt(0,12)=="A2s"`, `labelAt(12,0)=="A2o"`, `labelAt(4,5)=="T9s"`, `labelAt(5,4)=="T9o"`.

### 7.2 Component

`RangeMatrix({ value?: Set<label>, onChange?, readOnly?, highlight?: Set<label>, compare?: { painted: Set, actual: Set }, size = 520 })`

Layout: CSS grid `repeat(13, 1fr)`, `gap 2px`, total `width = size` (`max-width 100%`), `select-none touch-none`. Each cell: square (`aspect-ratio 1/1`), `border-radius 3px`, weight 600, `line-height 1`, centred label text, `font-size = max(8, (size/13) * 0.32)` (520 → 12.8px), `transition-colors`, `aria-pressed = value.has(label) || undefined`.

Mode selection: `interactive = !readOnly && !compare && onChange != null`.

Cell colour (`colorFor(label)`), evaluated in this order:

| Mode | Condition | Background | Text | `faint` |
|---|---|---|---|---|
| compare | in painted **and** in actual | `good` | `ink-900` | no |
| compare | in actual only | `warn` | `ink-900` | no |
| compare | in painted only | `chip-red` | white | no |
| compare | neither | `ink-700` | faint | yes |
| readOnly | `highlight` has label | kind colour† | white | no |
| readOnly | else | `ink-700` | faint | yes |
| interactive | `value` has label | kind colour† | white | no |
| interactive | else | `ink-700` @70 %, hover `ink-600` | faint | yes |

† kind colour = `combo-pair` for pairs, `combo-suited` for suited, `combo-offsuit` for offsuit.
`faint` cells get `opacity 0.92`. Interactive cells show `cursor: pointer`.

Painting (interactive only):
```
onPointerDown(label):  preventDefault; add = !value.has(label); addMode = add; painting = true; apply(label, add)
onPointerEnter(label): if painting → apply(label, addMode)
window pointerup:      painting = false
apply(label, add):     if value.has(label) == add → no-op; else copy set, add/remove, onChange(next)
```
I.e. the first cell touched decides whether the drag *adds* or *removes*; dragging across cells applies that same mode. In Flutter use a `Listener`/`GestureDetector` with hit-testing on move to get the cell under the finger.

### 7.3 `RangeLegend({ mode = "kind" })`

Row of swatches (12px squares, `rounded-sm`) + labels, 0.72rem muted, `gap-3`:
- `kind`: `combo-pair` "Pairs", `combo-suited` "Suited", `combo-offsuit` "Offsuit".
- `compare`: `good` "Correct", `warn` "Missed", `chip-red` "Extra".

---

## 8. Keyboard shortcuts

### 8.1 Guards (`src/lib/hotkeys.ts`)

```
isTypingTarget(e): target is contenteditable, or tag ∈ {INPUT, TEXTAREA, SELECT}  → global hotkeys ignore it
hasModifier(e):    e.metaKey || e.ctrlKey || e.altKey   (Shift is NOT a modifier here, so "?" = Shift+/ works)
```
Every global key listener below starts with `if (isTypingTarget(e) || hasModifier(e)) return;`. All handlers are `window` `keydown` listeners; on match they `preventDefault()`.

### 8.2 Bindings (exact behaviour)

**Play view (`PlayView`)** — key `Space` (`e.code === "Space"` or `e.key === " "`):
- no session active → `newSession()`
- session active and `table.phase === "hand-over"` → `deal()`
- otherwise ignored.

**Action bar (`ActionBar`)** — `k = e.key.toLowerCase()`:
1. `arrowright` and `settings.mode === "manual"` and a bot is to act and not paused → `stepBot()`; return.
2. `enter` and session active and `phase === "hand-over"` → `deal()`; return.
3. If it is not your turn → ignore everything else.
4. `f` → `heroAction({type:"fold"})`.
5. `c` → `heroAction(canCheck ? {type:"check"} : {type:"call"})`.
6. `r` **or** `enter`, when `canBet || canRaise` → `heroAction({ type: currentBet === 0 ? "bet" : "raise", amount: raiseTo })` where `raiseTo` is the size currently selected in the bar (default ≈ 66 % pot: `currentBet > 0 ? currentBet + round((pot + toCall)·0.66) : round(pot·0.66)`, clamped to `[minRaiseTo, maxRaiseTo]`).

**Drills (`DrillControls`)**:
- not yet answered: `1`/`2`/`3` → `answer(puzzle.options[idx].action)` if `idx < options.length`.
- answered: `Enter` → `next()`.

**Everywhere (`ShortcutOverlay`)**: `e.key === "?"` or (`e.code === "Slash"` and `shiftKey`) → toggle the overlay.
**Dialogs**: `Esc` closes any open `Modal` (Radix default).

The Settings row "View all shortcuts" opens the overlay by dispatching a synthetic `keydown` with `key: "?"` on `window`.

### 8.3 Shortcut overlay content (verbatim)

`Modal(maxWidth 420, title "Keyboard shortcuts", description "Play and drill without touching the mouse.")`. Body: sections separated by 16px; each section has a heading (0.66rem, weight 600, uppercase, tracking-wide, faint, margin-bottom 6px) and rows (flex space-between, `gap-4`, `text-sm`): description in muted on the left, key on the right as a `<kbd>`: `rounded-md`, 1px border `line-strong`, bg `ink-700`, padding 8px × 2px, mono 0.72rem weight 600 colour `text`.

```
Play
  F            Fold
  C            Check / call
  R            Bet / raise the selected size
  Enter        Confirm bet · next hand
  →            Next bot action (manual pace)
  Space        Start session · next hand
Drills
  1 / 2 / 3    Choose an answer
  Enter        Next puzzle
General
  ?            Show / hide this overlay
  Esc          Close dialogs
```

Port note: on mobile there is no physical keyboard; keep the bindings for hardware keyboards / tablets (Flutter `Shortcuts`/`Focus`), and re-label the Settings "Shortcuts" row accordingly or hide the overlay when no keyboard is attached. The Settings row text (section 9.3) mentions the keys explicitly, so decide deliberately.

---

## 9. Settings, theme and accessibility

### 9.1 `settingsStore` — persisted key `allin.settings.v1` (JSON)

```ts
interface AppSettings {
  fourColorDeck: boolean;      // default false. ♠ black · ♥ red · ♦ blue · ♣ green
  reducedMotion: boolean;      // default false. Also honours OS prefers-reduced-motion
  coachStrictness: "relaxed" | "standard" | "strict";  // default "standard"
  simQuality: "standard" | "high";                      // default "standard"
  realisticReveal: boolean;    // default false. true = hide folded players' cards at hand end
}
```
Load: `{...DEFAULTS, ...JSON.parse(storage[key] || "{}")}`, falling back to defaults on any error. `update(partial)` merges and re-saves the whole object (minus the function). `coachThresholds(strictness)` → `{ mistakeBb, foldFlagBb }`: relaxed `{-0.6, 2.5}`, standard `{-0.3, 1.5}`, strict `{-0.15, 1.0}` (consumed by the coach subsystem; listed here because it lives in this store).

How they are applied in this subsystem:
- `fourColorDeck` → class `four-color` on the app root (section 1.4).
- `reducedMotion` → class `reduce-motion` on the app root (section 1.8).
- `realisticReveal` → `Seat.showHole` (section 6.5).

### 9.2 `themeStore` — persisted key `allin.theme` (`"dark" | "light"`)

Default `"dark"`. On module load (before first paint) the stored theme is applied by toggling class `light` on `<html>`. `toggle()` flips and persists; `set(t)` sets and persists. `index.html` declares `<meta name="color-scheme" content="dark">`. The OS colour scheme is **not** consulted — theme is explicit and defaults to dark.

### 9.3 Settings view (verbatim copy)

Page: scrollable, `max-width 720px`, padding 32px × 28px. `h1` "Settings" (display, `text-3xl`, weight 800). Subtitle (`text-sm`, muted): `Everything is saved on this device.`

Card 1 header (`text-sm` weight 600 `gold`, `eye` icon 15): **Table & cards**

| Row title | Description | Control |
|---|---|---|
| Four-color deck | ♠ black · ♥ red · ♦ blue · ♣ green. Makes suits unmistakable at a glance — recommended, and essential if you have trouble telling red suits apart. | Preview of four `PlayingCard`s `As Ah Ad Ac` at `w=26` (`gap-1`), then a Toggle (aria-label "Four-color deck") |
| Realistic reveals | By default the app shows everyone's cards when a hand ends — folded hands included — because seeing what people folded builds intuition. Turn this on to hide folded hands, like a real table. | Toggle ("Realistic reveals") |
| Theme | Light or dark — also switchable from the sidebar. | Segmented `Dark` / `Light` (selecting either calls `toggle()` — a source quirk: tapping the already-selected option flips the theme anyway; a port should call `set(v)`) |
| Reduce motion | Disables animations and transitions. Also honors your system's reduced-motion preference automatically. | Toggle ("Reduce motion") |

Card 2 header (`coach` icon 15): **Coach**

| Row title | Description | Control |
|---|---|---|
| Strictness | How eagerly the coach interrupts. Relaxed only flags clear blunders; strict calls out smaller EV losses too. | Segmented `Relaxed` / `Standard` / `Strict` |
| Simulation quality | High runs 2.5× more Monte-Carlo trials per verdict — slightly slower, tighter error bars. Late streets are always computed exactly either way. | Segmented `Standard` / `High` |

Card 3 header (`bolt` icon 15): **Keyboard**

| Row title | Description | Control |
|---|---|---|
| Tour & placement | Re-run the first-launch tour and the placement quiz (recalibrates your drill rating). | Button `Run again` — removes storage key `allin.onboarded.v1` and reloads the app (so the onboarding modal mounts open) |
| Shortcuts | Play and drill without touching the mouse. F fold · C check/call · R raise · 1/2/3 drill answers · Enter next. | Button `View all shortcuts` — opens the shortcut overlay |

Both buttons: `rounded-lg`, 1px border `line`, bg `ink-700`, padding 12px × 6px, 0.78rem, weight 600, colour `text`, hover bg `ink-600`.

---

## 10. Error boundary (`ErrorBoundary`)

Wraps the whole app at the root (`main.tsx`: `<ErrorBoundary><App/></ErrorBoundary>`; React StrictMode is deliberately **not** used because the game loop is timer-driven and StrictMode's double-invocation would double-deal).

On a render crash it logs `Render crash caught by ErrorBoundary: <error>` and replaces the entire UI with:

- Full-screen `ink-900` background, padding 32px, content centred.
- Card `max-width 440px`, `rounded-2xl`, 1px border `bad` @40 %, bg `ink-800`, padding 24px, centred text:
  - Title (display, `text-xl`, bold): `Something broke`
  - Body (`text-sm`, relaxed, muted, margin-top 8px): `A part of the interface crashed. Your hands, stats, and progress are safe — reloading usually fixes it.`
  - Error text (margin-top 12px, mono, `max-height 96px` scrollable, `rounded-lg`, bg `ink-850`, padding 8px, left-aligned, 0.7rem, colour `bad`): `String(error.message ?? error)`.
  - Button (margin-top 16px, `rounded-xl`, bg `gold`, padding 20px × 8px, `text-sm`, bold, colour `ink-900`, hover brightness 1.1): `Reload the app` → full page reload.

Flutter: install `ErrorWidget.builder` / a top-level `runZonedGuarded` and show this same card; "Reload" should restart the root widget (e.g. `Phoenix.rebirth` or re-`runApp`).

---

## 11. App shell and navigation (`App.tsx`)

Root `<div>`: classes `app-backdrop flex h-screen w-screen overflow-hidden` + `four-color` when `settings.fourColorDeck` + `reduce-motion` when `settings.reducedMotion`. Two children: a fixed-width sidebar `<nav>` and a `<main>` that fills the rest (`min-w-0 flex-1 overflow-hidden`; each view scrolls itself).

### 11.1 `navStore` — in-memory only (not persisted)

```ts
type Tab = "play" | "drills" | "study" | "stats" | "settings" | "about";
state: { tab: Tab = "play"; lessonId: string | null = null }
go(tab, lessonId?)  → { tab, lessonId: lessonId ?? null }   // deep-link a Study lesson
consumeLesson()     → { lessonId: null }                     // StudyView calls after opening it
```
App always opens on **Play**.

### 11.2 Sidebar (`<nav>`)

`width 212px`, column, right 1px border `line`, bg `ink-900` @70 %, padding 16px.

1. Logo block: padding-x 4px, padding-bottom 24px, `Logo(size 40, withWordmark)`.
2. Nav list (`space-y-1`), one button per item, in this order:

   | id | label | icon |
   |---|---|---|
   | `play` | Play | `play` |
   | `drills` | Drills | `target` |
   | `study` | Study | `book` |
   | `stats` | Stats | `stats` |
   | `settings` | Settings | `target` (source reuses the Drills icon; the `settings` glyph exists and is unused) |
   | `about` | About | `info` |

   Button: full width, flex, `gap-3`, `rounded-xl`, padding 12px × 10px, `text-sm`, weight 600, `transition`; icon size 18. Active: bg `gold` @15 %, text `text`, icon `gold`. Inactive: text muted; hover bg white/5 + text `text`.
3. Bottom block (`mt-auto`, `space-y-3`):
   - **Theme toggle button**: full width, flex space-between, `rounded-xl`, 1px border `line`, bg `ink-800` @70 %, padding 12px × 8px, `text-sm`, weight 600, muted, hover text `text`. Left: icon (`moon` if dark, `sun` if light, size 16) + `Dark mode` / `Light mode`. Right: `switch` (0.66rem, faint). Tap → `toggleTheme()`.
   - **Tip card**: `rounded-xl`, 1px border `gold` @20 %, bg `gold` @6 %, padding 12px, 0.72rem, relaxed, muted. Header line (flex `gap-1.5`, weight 600, `gold-light`, margin-bottom 2px): `bolt` icon 13 + `Tip`. Body: `Use ` **`Guess Range`** (colour `text`) ` before you act, then let the EV Coach grade the decision.`
   - **Footer** (padding-x 4px, 0.62rem, faint): `All-In · offline poker dojo · press ` `?` (kbd, muted) ` for shortcuts`

### 11.3 Main area

Renders exactly one view by `tab`: `PlayView`, `DrillsView`, `StudyView`, `StatsView`, `SettingsView`, `AboutView`. Two always-mounted overlays follow: `ShortcutOverlay` and `OnboardingModal`.

Port note: a phone should map the six tabs to a bottom navigation bar (or a drawer) with the same order, labels and icons; keep the theme toggle and the tip inside Settings or a drawer.

### 11.4 Desktop window (`src-tauri/tauri.conf.json`)

`productName "All-In"`, `identifier "com.allin.pokerdojo"`, window label `main`, title `All-In · Poker Dojo`, 1280 × 840, min 1040 × 680, resizable, centred. CSP: `default-src 'self' ipc: http://ipc.localhost; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' data: https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self' ipc: http://ipc.localhost https://api.github.com` — i.e. the only network endpoints the app ever touches are Google Fonts and the GitHub Releases API (update notice).

---

## 12. First-run onboarding: tour + placement test (`OnboardingModal`)

### 12.1 Gate and persistence

- Storage key `SEEN_KEY = "allin.onboarded.v1"`; value `"1"` once seen.
- `hasOnboarded()` returns `storage[SEEN_KEY] === "1"`, and **`true` if storage throws** (no storage ⇒ never nag).
- The modal mounts with `open = !hasOnboarded()`. Any close path (`Skip`, the X, overlay tap, Esc, "Start playing", "Take me there") calls `markOnboarded()` then closes. Closing mid-quiz does **not** seed a rating.
- Settings → "Run again" deletes the key and reloads (section 9.3).

### 12.2 State machine

```
step: 0..3 = tour pages · 4 = placement intro · 5 = quiz · 6 = result
qi:    current question index 0..7
score: correct answers so far
picked: index (in the shuffled order) of the option just tapped, or null
perms:  per-question shuffled option order, fixed once at mount (Fisher–Yates, Math.random)
```

Modal: `maxWidth 470`, close button visible, title always **`Welcome to All-In`**, description by step:
- steps 0–3: `A 60-second tour · {step+1} of 4`
- steps 4–5: `Optional placement`
- step 6: `You're set`

### 12.3 Tour pages (steps 0–3), verbatim

Layout: row with a 40px `rounded-xl` icon tile (bg `gold` @15 %, icon `gold` size 19) and, to its right, the title (display, `text-base`, bold) over the body (margin-top 4px, 0.84rem, relaxed, muted). Below: a row with 4 progress pills on the left (each 20 × 6px, `rounded-full`; pill `i` is `gold` when `i <= step` else `ink-600`) and buttons on the right: `Skip` (ghost, sm) and `Next` (primary, sm, trailing `arrow-right` icon 14) — on the last page the primary reads `Continue`.

| step | icon | title | body |
|---|---|---|---|
| 0 | `play` | Play against real-ish opponents | Four bot styles with genuinely different tendencies. The EV Coach watches every decision and explains — in plain English first — whether it made money. At the end of each hand, everyone's cards are revealed, folds included: that's how you build intuition. |
| 1 | `target` | Drill like chess puzzles | Short spots with instant feedback: the answer, why, how much a mistake costs in big blinds, and the exact set of hands (the range) you were graded against. Anything you miss — and anything the coach flags in play — comes back on a spaced schedule until you've beaten it three times. |
| 2 | `book` | Study when you want the why | A 31-lesson course from the rules up to 3-bet pots and river play, with interactive calculators. Drill feedback links straight to the lesson that teaches each concept. |
| 3 | `coach` | Judge decisions, not results | Poker pays good decisions slowly and randomly. You'll lose hands you played perfectly and win hands you butchered. This app grades the decision — the only thing you control. That mindset is the whole game. |

### 12.4 Placement intro (step 4), verbatim

Paragraph (0.86rem, relaxed, muted):
`Eight quick questions calibrate the drills to your level — harder spots if you're experienced, clearer ones if you're new. No grade, no judgment, and you can skip it.`

Buttons (right-aligned): `Skip — start playing` (ghost, sm → close) · `Calibrate me` (primary, sm, trailing `target` icon 14 → step 5).

### 12.5 Quiz (step 5)

Header (0.72rem, weight 600, uppercase, tracking-wide, faint): `Question {qi+1} of 8`. Question (0.9rem, weight 500, colour `text`). Then the options as a vertical list (`gap-1.5`) in the shuffled order `perms[qi]`; each is a button: `rounded-lg`, 1px border, padding 12px × 8px, left-aligned, 0.84rem, `transition`.
- Idle: border `line`, bg `ink-800`, text muted, hover bg `ink-700`.
- Tapped and correct: border `good`, bg `good` @15 %, text `text`.
- Tapped and wrong: border `bad`, bg `bad` @15 %, text `text`.
- While `picked != null` every option is disabled.

On tap: `picked = oi`; if the option's original index equals `answer` then `score += 1`; after **350ms**: `picked = null`, then either `qi += 1` or, after the 8th question, `finishPlacement()`.

The eight questions. In the source the correct option is always index 0 (before shuffling); `answer` is that index.

| # | Question | Options (correct first) |
|---|---|---|
| 1 | Which beats which? | A flush beats a straight · A straight beats a flush · They tie |
| 2 | The best seat at the table is… | The button — you act last after the flop · Under the gun — you act first · The big blind — you've already paid |
| 3 | The pot is 10 bb and your opponent bets 5 bb. To call profitably you need to win about… | 1 time in 4 · 1 time in 2 · 2 times in 3 |
| 4 | A flush draw on the flop (9 outs, two cards to come) has roughly what chance of hitting? | About 36% · About 18% · About 9% |
| 5 | Why 3-bet (re-raise) before the flop? | Value with big hands, plus pressure with the right bluffs · Only ever with aces · To see a cheap flop |
| 6 | In a 3-bet pot with a low stack-to-pot ratio, top pair top kicker is usually… | A hand worth your whole stack · A fold to any bet · A hand to keep the pot tiny with |
| 7 | Against a player who never bluffs, their big river bet means you should… | Fold hands that only beat bluffs — even if folding is 'exploitable' · Call just often enough that bluffing can't profit · Always raise |
| 8 | With 10 big blinds in the small blind, folded to you, a solid strategy is… | Go all-in with over half your hands · Only go all-in with premium pairs · Just call the minimum and decide later |

Shuffle (per question, once at mount):
```
idx = [0,1,2]
for i from 2 down to 1: j = floor(random() * (i+1)); swap idx[i], idx[j]
```

### 12.6 Result (step 6) and how it seeds the drill rating

```
finishPlacement():
  rating = score <= 2 ? 900 : score <= 5 ? 1050 : 1250
  drills.seedRating(rating)     // writes {rating, solved, correct, streak, best} to "allin.drills.v1", keeping the other four fields
  step = 6
```
Context: the drill store's default rating is **1000**; the adaptive puzzle picker treats `< 1050` as "mostly easy (difficulty 1)", `< 1250` as "mostly medium", and `>= 1250` as "mostly hard". So 900 / 1050 / 1250 land in the beginner / intermediate / advanced bands.

Result card (`rounded-xl`, 1px border `gold` @25 %, bg `gold` @6 %, padding 12px): headline (display, `text-base`, bold) and body (0.84rem, muted, margin-top 4px) = `{score}/8 — drills are calibrated to match. {advice}`.

| score | headline | advice | lesson deep-link |
|---|---|---|---|
| 0–2 | Starting fresh — perfect. | Begin with Level 1: Hand Rankings. The course assumes nothing. | `hand-rankings` |
| 3–5 | You know the basics. | Start at Pot Odds & EV — the math that powers every decision here. | `pot-odds` |
| 6–8 | Solid foundations. | Jump into the advanced track — 3-bet pots and river play — and let the drills find your edges. | `threebet-pots` |

Buttons (right-aligned): `Take me there` (secondary, sm, leading `book` icon 14 → close, then `nav.go("study", lesson)`) · `Start playing` (primary, sm, leading `play` icon 14 → close).

Pinned expectations for Dart tests: score 0,1,2 → 900; 3,4,5 → 1050; 6,7,8 → 1250; the result-text bands follow the same cut-offs; `seedRating` must not reset `solved/correct/streak/best`.

---

## 13. About view and the update notice (`AboutView`)

Constants: `SITE_URL = "https://gapp.in/poker"`, `RELEASES_URL = "https://github.com/ganeshapp/poker/releases/latest"`, build version `__APP_VERSION__` injected from `package.json` (`1.1.2` at time of writing; `tauri.conf.json` and `src-tauri/Cargo.toml` carry the same number and must be bumped together).

`openExternal(url)`: on the desktop uses the Tauri opener plugin, falling back to `window.open(url, "_blank", "noopener,noreferrer")`; Flutter → `url_launcher` with external application mode.

### 13.1 Update notice (`UpdateNotice`)

Passive check, runs once on mount:
```
GET https://api.github.com/repos/ganeshapp/poker/releases/latest
if ok: tag = json.tag_name with a leading "v" stripped
newer(a, b): split both on ".", compare up to 3 numeric parts (missing → 0); true iff a > b
if newer(tag, APP_VERSION) → show the notice; else nothing
any error / offline → nothing (silently)
```
Notice = button (margin-top 4px, flex `gap-1.5`, `rounded-full`, 1px border `gold` @40 %, bg `gold` @10 %, padding 12px × 4px, 0.72rem, weight 600, `gold`, hover bg `gold` @20 %): `arrow-right` icon 12 + `Version {latest} is out — download it here` → opens `RELEASES_URL`. Pin: `newer("1.2.0","1.1.2") == true`, `newer("1.1.2","1.1.2") == false`, `newer("1.1","1.1.2") == false`, `newer("2","1.9.9") == true`. Port note: on mobile the release channel is the store; either drop this or point it at the store listing.

### 13.2 Page copy (verbatim)

Hero card (centred, `rounded-2xl`, border `line`, bg `ink-850`, padding 28px): `Logo(64)`; `h1` `All-In · Poker Dojo`; paragraph (`max-width 520px`, `text-sm`, muted): `A clean, offline-first Texas Hold'em trainer that takes you from the rules to solid, EV-aware play — by actually doing the math with you, not just showing answers.`; version pill (`rounded-full`, bg white/5, 0.66rem, weight 600, uppercase, faint): `Version {APP_VERSION}`; then `UpdateNotice`.

Two link tiles (grid, 2 columns on wide screens):
- `Play online` / `No install — runs in your browser at gapp.in/poker` (tile: border `gold` @30 %, bg `gold` @6 %, hover @12 %; icon tile `play` 18 in `gold` on `gold` @15 %) → `SITE_URL`.
- `Download desktop` / `Latest installer for macOS, Windows & Linux` (tile: border `line`, bg `ink-800` @70 %, hover `ink-700`; icon tile `chip` 18 on white/5) → `RELEASES_URL`.

`h2` **How to use it** — four `Card`s (grid, 2 columns), each with a 28px `rounded-lg` icon tile (`gold` @15 %, icon 15 `gold`) + title (display, `text-base`, bold) and body (0.84rem, muted):

| icon | title | body |
|---|---|---|
| `play` | Play | Start a session and play hand-after-hand against four bot archetypes. Step through the action manually or auto-play, click the eye on a player to guess/peek their range, and let the EV Coach grade your decisions with the math behind them. |
| `target` | Drills | Chess-puzzle-style practice. Replay a spot to the decision point, then choose fold/call/raise for instant feedback and a self-adjusting rating. Four modes: Mixed cash spots (pre-flop charts + post-flop pot-odds/equity), short-stack Push/Fold, Exploits vs known player types, and Review — your own coach-flagged mistakes, re-served until you fix them. |
| `book` | Study | A 5-level course from rules and position to hand-reading, bet-sizing, implied odds, SPR and multiway play — with interactive range, pot-odds, bluff and multiway-equity calculators, a quick-reference cheat sheet, and optional quizzes. Hover any dotted term for a definition. |
| `stats` | Stats | Track your win-rate (bb/100), range-read accuracy and results vs each archetype, see a coaching review of your leaks, replay any hand step-by-step from the session summary, and export a session's hands as a PokerStars-style history. |

`h2` **Good to know** — one `Card`, bullets (0.86rem, muted; leading icon 15 at `mt-0.5`):
- (`check`, good) `Fully offline — your hands and progress stay on your machine (SQLite on desktop, browser storage on the web).`
- (`info`, info) `Coaching and drills are graded by honest heuristics, not a solver — see "How the grading works" below for exactly what that means.`
- (`info`, info) `It's a play-money trainer for learning. Variance is real: even good play swings, so judge yourself on decisions (the coach) more than short-term results.`

`h2` **How the grading works** — one `Card`. Intro (0.84rem, muted): `An honest summary of where the "right answers" come from, so you know how much to trust each verdict:` then bullets (bold lead-in in colour `text`):
- (`info`) **Pre-flop charts** ` (drills and study diagrams) are self-authored consensus baselines for 100bb 6-max — solid standard play keyed by your position `*and*` the raiser's, with mixed frequencies where real strategies mix. They're not direct solver output; bot ranges still use a simplified model that's being upgraded next.`
- (`info`) **Post-flop coaching** ` compares your pot odds with your hand's chance of winning, estimated by dealing thousands of random runouts against the opponent's likely hands (a Monte-Carlo simulation). That catches clear mistakes well, but it can't see everything a solver sees — treat close verdicts as guidance, not gospel.`
- (`check`, good) **Push/fold drills** ` use Nash equilibrium tables we computed ourselves (chip-EV, no antes, one caller at a time) — mixed-frequency hands accept either answer, like the real equilibrium does. A third of push/fold reps are ICM bubble spots — solved the same way, but in tournament money instead of chips. Ante variants are still to come.`

`h2` **On the roadmap** — one `Card`. Intro: `Coming next (see the project README for the full, prioritised list):` then four rows with a `gold` `arrow-right` 14:
`Configurable table — stack depths, 9-max, antes` · `Desktop auto-update — one-click new versions` · `Import your real online hand histories for coaching` · `Install as an app (PWA) on the web`. Footnote (0.74rem, faint): `It's evolving — feedback and ideas are welcome.`

`h2` **Built by** — centred `Card`: `Gapp` (display, `text-2xl`, weight 800, `gold-light`); link `www.gapp.in` + `arrow-right` 14 (`text-sm`, weight 600, `gold`, hover `gold-light`) → `https://www.gapp.in`; paragraph (0.8rem, faint, `max-width 460px`): `Designed and built by Gapp. Made with Tauri + Rust and React + TypeScript. Thanks for playing — feedback is always welcome.`

Page footer (padding 32px, centred, 0.66rem, faint): `All-In · Poker Dojo — © Gapp`

Port note: rewrite the tech-stack sentence ("Made with Tauri + Rust…") and the "Download desktop"/"Play online" tiles for the mobile build, but keep every other line as-is — they encode the product's honesty commitments.

---

## 14. Local persistence keys used by this subsystem

| Key | Owner | Value |
|---|---|---|
| `allin.onboarded.v1` | OnboardingModal | `"1"` once the tour/placement has been shown |
| `allin.settings.v1` | settingsStore | JSON `AppSettings` (section 9.1) |
| `allin.theme` | themeStore | `"dark"` or `"light"` |
| `allin.drills.v1` | drillStore (written by `seedRating`) | JSON `{ rating, solved, correct, streak, best }`, default `{1000, 0, 0, 0, 0}` |

On the desktop these are `localStorage`; game/stat data lives in SQLite. For Flutter use `shared_preferences` with the same key names so a future import/export stays compatible.

---

## 15. CI, web deploy and desktop release (for context; mobile will replace this)

Version is single-sourced from `package.json` (`1.1.2`) via Vite `define: { __APP_VERSION__ }`; `tauri.conf.json` and `src-tauri/Cargo.toml` duplicate it and are bumped by hand.

**`ci.yml`** — on push to `main` and every PR, `ubuntu-latest`, Node 22, `npm ci`, then:
1. `npm run build` (= `tsc && vite build`; type-check + web bundle).
2. Node harnesses (`node --experimental-transform-types scripts/<x>.ts`): `engine_test`, `sim_test`, `multiway_test`, `hh_test`, `leaks_test`, `puzzles_test`, `pushfold_test`, `preflop_test`, `bot_test`, `srs_test`, `icm_test`, `hhimport_test`, `table_config_test`.
3. `golden_test.ts` (pinned evaluator scores + chart snapshots).
4. `cargo test --manifest-path poker-core/Cargo.toml`.
5. `parity_test.ts` (TS ↔ Rust identical scores and exact-equity counts).

**`pages.yml`** — on push to `main` (or manual): Node 20, `npm install`, `npm run build`, upload `dist`, deploy to GitHub Pages (`https://gapp.in/poker`). Vite `base: "./"` so the bundle works under any sub-path.

**`release.yml`** — on tag `v*` (or manual): matrix `macos-latest` (`--target universal-apple-darwin`, Rust targets `aarch64-apple-darwin,x86_64-apple-darwin`), `ubuntu-22.04` (installs `libwebkit2gtk-4.1-dev libgtk-3-dev libayatana-appindicator3-dev librsvg2-dev patchelf build-essential libxdo-dev libssl-dev file`), `windows-latest`; Node 20; `tauri-apps/tauri-action@v0` with `tagName = <tag>`, `releaseName = "All-In <tag>"`, `releaseBody = "Desktop installers for macOS, Windows and Linux. Download the right asset for your OS below. (macOS/Windows builds are unsigned — see the README for how to open them.)"`, not draft, not prerelease. Installers are **unsigned**. Bundle targets `all` (.dmg / .msi / .AppImage / .deb) with icons from `src-tauri/icons/`.

Tauri capabilities granted to the main window: `core:default`, `core:window:default`, `core:webview:default`, `opener:default`, `opener:allow-open-url`, `sql:default`, `sql:allow-load/execute/select/close`. Rust commands exposed: `evaluate_hand`, `equity_vs_range`, `equity_vs_random`, `equity_vs_field`, `save_text_file` (writes to `~/Downloads`).

Per the user's standing rules for Android releases (memory): the mobile port must ship per-ABI splits via a release script and be signed with a dedicated release keystore verified in CI — not a lone universal APK.

---

## 16. Existing tests that touch this subsystem

Only `scripts/engine_test.ts` pins values relevant here (notation, section 7.1). There are **no** tests for `cx`, `hotkeys`, `format.ts`, the seat geometry, the placement scoring or the semver comparison — the worked examples in sections 6.3, 6.6, 12.6 and 13.1 were computed from the source and should become Dart unit tests.

Suggested Dart test list:
- `labelAt`/`kindOf`/`comboCount`/`cardsToLabel` — the eight `engine_test` assertions + the extra grid corners in 7.1.
- `fmtBb`, `fmtSigned`, `fmtPct`, `fmtTimes`, `fmtNeed` — the examples in 6.3.
- `seatPos` — the 17 rows in 6.6 (1-decimal).
- Placement: score → rating and → result band; shuffle keeps exactly the three options; 350ms advance; closing before finish leaves rating untouched.
- `newer(a,b)` semver — the four cases in 13.1.
- `PlayingCard` geometry: `w=46 → h=64, r=6`; `w=36 → h=50, r=5`; `w=56 → h=78, r=7`; `w=26 → h=36, r=4`.
- `HUD`: `handsSeen 7 → "–/– · 7h"`, `handsSeen 8, vpip 2, pfr 1 → "25/13 8h"` (2/8=25, 1/8=12.5→13).
- Suit colour mapping in both deck modes; light/dark token tables (snapshot).

---

## 17. Port risks and open decisions

1. **Layout is desktop-only.** Sidebar 212px, table ellipse 90 %×80 %, 128px seat plates, 520px range matrix, min window 1040×680. Mobile needs a bottom nav, a re-derived seat ring (keep ordering/anchors from 6.6), a matrix sized to screen width (cell = width/13, font = max(8, cell·0.32)), and the shortcut overlay/tip copy revised for touch.
2. **Tailwind opacity quirks.** `bg-white/8` (Seat position badge) and `border-white/12` (empty board slot) are not in Tailwind's default opacity scale and may not have rendered on desktop; the *intent* (8 % / 12 % white) is what to port.
3. **Settings icon.** Nav "Settings" uses the `target` icon (same as Drills). Decide whether to keep the quirk or use the unused `settings` glyph.
4. **Theme segmented control** calls `toggle()` regardless of which option was tapped; port as `set(value)`.
5. **Fonts** are fetched from Google Fonts; bundle them. Bricolage Grotesque is a variable font (opsz 12–96, wght 400–800); Flutter needs static weight files or `FontVariation`.
6. **Update notice** targets GitHub Releases; on mobile route to the store or remove.
7. **Hover-only affordances** (HUD tooltip, seat guess-button hover, dotted glossary terms) need tap equivalents.
8. **`hasOnboarded()` returns true when storage is unavailable** — keep that fail-safe.
9. **Reduced motion** must merge the user toggle with `MediaQuery.disableAnimations`.
10. **No StrictMode / double-mount tolerance**: timers in the game loop assume single mount; keep onboarding/shortcut listeners idempotent.

---

## 18. Addenda — layout details omitted earlier

These sections **extend** §1.5 and §13.2; nothing above is superseded. Same conventions: spacing unit `1` = 4px, root font size 16px, so `text-[0.76rem]` = 12.16px.

### 18.1 About page container and scrolling (extends §13.2, source `src/views/AboutView.tsx`)

`AboutView` renders exactly two nested wrappers before any content:

```html
<div class="h-full overflow-auto">              <!-- the scroller -->
  <div class="mx-auto max-w-[760px] px-8 py-8"> <!-- the measure -->
```

- **Outer** — `height: 100%` of the `<main class="min-w-0 flex-1 overflow-hidden">` it sits in (§11.3), `overflow: auto`. This is the *only* scrolling element on the About page: the window itself never scrolls because `body { overflow: hidden }` (§1.5 / §18.5). The scrollbar is the app-wide WebKit one from `tokens.css` (10px, `ink-500` thumb).
- **Inner** — horizontally centred (`margin-left/right: auto`), **`max-width: 760px`**, `padding: 32px` on all four sides (`px-8` = 32px left/right, `py-8` = 32px top/bottom). Tailwind's preflight sets `box-sizing: border-box`, so the 760px cap **includes** the padding: the content column is at most **760 − 64 = 696px** wide. Below 760px of available width the card simply fills it, and the two `sm:grid-cols-2` grids collapse to one column below the Tailwind `sm` breakpoint (640px).

Flutter equivalent (note the `ConstrainedBox` wraps the `Padding`, not the reverse — that is what reproduces border-box):

```dart
SingleChildScrollView(                       // h-full overflow-auto
  child: Center(                             // mx-auto
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: const Padding(
        padding: EdgeInsets.all(32),         // px-8 py-8
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [/* … */]),
      ),
    ),
  ),
)
```

On a phone, 760px is wider than the viewport, so the constraint never binds — but keep the 32px page padding and keep the single internal scroller.

### 18.2 Section headings (`h2`) on the About page

All six headings — **How to use it**, **Good to know**, **How the grading works**, **On the roadmap**, **Built by** (and any added later) — carry the *identical* class list:

```html
<h2 class="mb-3 mt-8 font-display text-xl font-bold text-[var(--text)]">
```

| Property | Value |
|---|---|
| `margin-top` | **32px** (`mt-8`) |
| `margin-bottom` | **12px** (`mb-3`) |
| Font family | `--font-display` (Bricolage Grotesque) |
| Font size | `text-xl` = **1.25rem / 20px** |
| Weight | **700** (`font-bold`; the base layer already sets 700 for `h1–h4`) |
| Colour | `var(--text)` |
| Letter-spacing | **−0.01em** = −0.2px at 20px — inherited from the `h1–h4` base rule (§1.5) |
| Line-height | **1.1** = 22px — same base rule |

Margins do not collapse into anything here (the preceding sibling is always a `div`/`Card` with zero bottom margin), so the rendered rhythm is: 32px gap above every heading, 12px gap between the heading and the block under it.

```dart
Padding(
  padding: const EdgeInsets.only(top: 32, bottom: 12),
  child: Text(title, style: TextStyle(
    fontFamily: 'BricolageGrotesque', fontSize: 20, fontWeight: FontWeight.w700,
    letterSpacing: -0.2, height: 1.1, color: tokens.text)),
)
```

### 18.3 The two link tiles — exact geometry (extends §13.2)

Wrapper: `mt-4 grid gap-3 sm:grid-cols-2` → **16px** below the hero card, **12px** gap, one column under 640px and two at/above it.

Each tile is a `<button>`: `group flex items-center gap-3 rounded-2xl border p-4 text-left transition`.

| Part | Exact spec |
|---|---|
| Tile box | `border-radius: 16px`, 1px border, **padding 16px**, flex row, vertically centred, **12px** gap, text left-aligned |
| Icon tile | **40 × 40px** (`h-10 w-10`), `rounded-xl` = **12px** radius, `shrink-0`, contents centred (`grid place-items-center`), icon size **18** |
| Title | `block font-display text-sm font-bold text-[var(--text)]` → display font, **14px**, weight **700**, colour `--text` |
| Sub-label | `block text-[0.76rem] text-muted` → **0.76rem = 12.16px**, colour `--muted` |
| Transition | Tailwind `transition`: 150ms `cubic-bezier(0.4, 0, 0.2, 1)` on colour/background/border/opacity/shadow/transform |

Per-tile colours (as already listed in §13.2, repeated here so the tile spec is self-contained):

| Tile | Border | Background | Hover background | Icon tile | Icon |
|---|---|---|---|---|---|
| **Play online** | `gold` @30 % | `gold` @6 % | `gold` @12 % | `gold` @15 %, foreground `gold` | `play` 18 |
| **Download desktop** | `line` | `ink-800` @70 % | `ink-700` | white @5 %, foreground `--text` | `chip` 18 |

Notes an implementer will otherwise trip on:
- The title and sub-label are two `block` spans inside one wrapper `<span>`, i.e. a left-aligned two-line column beside the icon tile — in Flutter a `Column(crossAxisAlignment: .start)` with `mainAxisSize: .min`.
- Neither `text-sm` nor `text-[0.76rem]` is paired with a leading utility: the title gets Tailwind's `text-sm` pairing (**line-height 20px**), while the sub-label inherits the browser's `normal` line-height (no explicit value anywhere up the chain) — in Flutter leave `height: null` for the sub-label.
- The `group` class is present but **no `group-hover:` rule exists inside either tile** — it is a no-op; only the tile's own background changes on hover.
- Both tiles are buttons calling `openExternal(...)`, not anchors. The one real `<a>` on the page ("Built by" → `www.gapp.in`) also calls `preventDefault()` and routes through `openExternal`, so in Flutter every link on this page is just a tap handler on `url_launcher`.

### 18.4 About page vertical rhythm and remaining type metrics

Everything below is measured from the source and is additive to the verbatim copy in §13.2. Order is top to bottom.

| Block | Metrics not already in §13.2 |
|---|---|
| Hero card | `flex flex-col items-center`, **12px gap** between logo / h1 / paragraph / version pill / update notice |
| Hero `h1` | `font-display text-3xl font-extrabold` → **30px**, weight **800**, colour `--text` (plus base letter-spacing −0.01em, line-height 1.1) |
| Hero paragraph | `text-sm` 14px, **`leading-relaxed` = line-height 1.625**, `max-width 520px`, muted, centred |
| Version pill | padding **12px × 4px** (`px-3 py-1`), `tracking-wide` = **letter-spacing 0.025em**, 0.66rem (10.56px), weight 600, uppercase, bg white @5 %, `rounded-full`, colour `--faint` |
| Link tiles | 16px below hero; see §18.3 |
| Every `h2` | 32px above, 12px below; see §18.2 |
| "How to use it" grid | `grid gap-3 sm:grid-cols-2` → **12px** gap, 2 columns at ≥640px |
| Mode card header | `mb-1.5` = **6px** below the header row; header is flex, items centred, **8px** gap; icon tile **28 × 28px**, `rounded-lg` = 8px, icon size 15 |
| Mode card body | 0.84rem = **13.44px**, `leading-relaxed` (1.625), muted |
| "Good to know" list | `space-y-2` = **8px** between items; text 0.86rem = **13.76px**, `leading-relaxed`; each row is flex with **8px** gap; leading icon size **15**, `margin-top 2px` (`mt-0.5`), `shrink-0` |
| Grading card | intro paragraph `mb-2` = **8px**, 0.84rem `leading-relaxed`; list `space-y-2` (8px), rows flex `gap-2`, icon 15 at `mt-0.5`; bold lead-ins are weight **600** in colour `--text`; the word *and* in the first bullet is `<em>` (italic) |
| Roadmap card | intro `mb-2` (8px), 0.84rem, **no** relaxed leading; list `space-y-1.5` = **6px**; rows flex `gap-2`, `arrow-right` icon **14** at `mt-0.5`, colour `gold`; footnote `mt-2` = **8px**, 0.74rem = **11.84px**, faint |
| "Built by" card | `flex flex-col items-center text-center`, **8px** gap; name 24px (`text-2xl`) weight **800** colour `gold-light`; link row inline-flex **6px** gap, 14px, weight 600, `gold` → hover `gold-light`, trailing `arrow-right` **14**; closing paragraph `mt-1` = **4px**, 0.8rem = **12.8px**, `leading-relaxed`, faint, `max-width 460px` |
| Page footer | `py-8` = **32px** padding top *and* bottom (on top of the container's own 32px bottom padding → 64px of empty space below the last line), centred, 0.66rem = 10.56px, faint |

All cards on this page are the standard `Card` primitive (§4.5): 16px radius, 1px `line` border, **20px** padding, background `ink-800` @80 %.

### 18.5 `index.css @layer base` — the complete block (extends §1.5)

§1.5 lists the `body` rules and the `h1–h4` rule but omits `text-rendering` and the layout scaffold. The base layer of `src/index.css` is, in full and in source order:

```css
@layer base {
  html,
  body,
  #root {
    height: 100%;
  }

  body {
    background: var(--ink-900);
    color: var(--text);
    font-family: var(--font-sans);
    -webkit-font-smoothing: antialiased;
    text-rendering: optimizeLegibility;   /* omitted from §1.5 */
    overflow: hidden;
  }

  #root {                                  /* omitted from §1.5 */
    display: flex;
    flex-direction: column;
  }

  h1, h2, h3, h4 {
    font-family: var(--font-display);
    font-weight: 700;
    letter-spacing: -0.01em;
    line-height: 1.1;
  }
}
```

That is the whole `@layer base`. The `.mono` / `.numeric` classes, the `:focus-visible` outline and the WebKit scrollbar rules named in §1.5 live in `src/styles/tokens.css`, not here; `index.css` contributes nothing else at base level.

What the two omitted declarations mean for the port:

- **`text-rendering: optimizeLegibility`** asks the engine for kerning and standard ligatures. Flutter already applies kerning and `liga` by default, so this needs **no** code — do not disable them (i.e. do not pass `fontFeatures: [FontFeature.disable('liga')]` or `FontFeature.disable('kern')`). Tabular figures stay opt-in via the `.mono` / `.numeric` equivalents (§1.5) → `FontFeature.tabularFigures()`.
- **`html, body, #root { height: 100% }` + `#root { display: flex; flex-direction: column }`** is the layout scaffold: the React root fills the viewport exactly and lays its children out as a single vertical column that cannot grow past the screen. Together with `body { overflow: hidden }` this is what forces every view to scroll internally (§18.1) instead of the page scrolling. Flutter equivalent: a full-height root (`Scaffold` body sized by the viewport, no `SingleChildScrollView` at the top level) with a `Column`; scrolling belongs to each view, never to the shell. If any part of the shell is ever wrapped in a scroll view, the fixed sidebar/bottom-nav behaviour of §11 breaks.
