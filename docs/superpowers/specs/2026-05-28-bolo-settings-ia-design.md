# Bolo Settings Information Architecture — Design

Date: 2026-05-28
Status: Approved design (pending spec review)

## Goal

Restructure Bolo's macOS Settings around its two-way identity — **Dictation**
(speech-to-text, inherited from FreeFlow) and **Read Aloud** (text-to-speech via
Groq) — so every control is findable in one guess, the shared Groq API key is
discoverable when setting up read-aloud, and a new Setup dashboard gives an
at-a-glance health check. Also: log read-aloud events in the Run Log, and add an
opt-in expressive-narration mode.

Decided via a 5-persona council + 2 debate rounds; user ratified the open
choices.

## Final sidebar

```
About
──────────────  (divider)
Setup
General
Dictation
Read Aloud
Run Log
Debug            (dev builds only — unchanged)
```

- **Labels:** plain-language ("Dictation", "Read Aloud") over "Speech to
  Text / Text to Speech" — clearer and avoids the near-anagram misclick.
- **No standalone "Shortcuts" page.** Each shortcut lives with the feature it
  triggers; collision detection (below) compensates for the lost unified view.
- **About sits at the top, above a divider** (user preference). Setup is the
  first *functional* item.

## Per-page contents

### About  (identity only)
- Branding header: app icon, "Bolo", version.
- `GitHubRepoCard` for `v-khanna/bolo`.
- "Built on FreeFlow (MIT) — credit below" caption.
- `GitHubRepoCard` for `zachlatta/freeflow`.
- "About Bolo" text block: what it is + Hindi origin ("bolo" = speak) + thanks
  to FreeFlow, with GitHub links.

(All of this already exists in `GeneralSettingsView`'s `.general` branding
header + the About card; it moves into a dedicated `AboutSettingsView`.)

### Setup  (status dashboard — read-and-route only)
A Cotypist-style checklist. **Shows derived status and navigates; never mutates
permission/key state inline** — this is the single source of truth for status,
so the General "Permissions" card and this page can't drift (Setup reads the
same live values; the actual grant buttons live in General).

- "All set!" success banner when everything is green.
- Rows, each with a status badge (Granted / Set / Needs action) and a chevron
  that switches `selectedSettingsTab` to the owning page:
  - Accessibility → General › Permissions
  - Microphone → General › Permissions
  - Screen Recording (optional, for dictation context) → General › Permissions
  - Groq API key (Set / Missing) → General › API Key
  - Shortcuts configured (dictation + read-aloud bound) → Dictation / Read Aloud
- No toggles, no text fields. Tapping a row is the only action.

### General  (app + provider + system)
- **App:** Launch at login, Show menu bar icon.
- **API Key:** Groq API key field + Save, with "Advanced Provider Settings"
  disclosure (base URL, custom transcription model). Shared by dictation and
  read-aloud.
- **Updates:** auto-check toggle + "Check for Updates Now" + last-checked.
- **Permissions:** the real grant buttons (Accessibility, Microphone, Screen
  Recording). This is where Setup's rows deep-link to.
- **Sound:** output feedback volume (start/stop sounds).
- **Build:** version/arch/macOS diagnostics + copy.

### Dictation  (speech-to-text)
- **Dictation Shortcuts:** hold + toggle recorders, shortcut start delay.
  (Read-selection shortcut is NOT here — it's on Read Aloud.)
- **Microphone:** input device selection.
- **Audio During Dictation:** mute-others behavior.
- **Recording Overlay:** overlay style (used by both recording and reading, but
  primarily a recording affordance).
- **Edit Mode.**
- **Clipboard.**
- **Output Language:** translate dictation output.
- **Custom Vocabulary.**
- **Prompts** (collapsible/advanced): system + context cleanup prompts.
- **Voice Macros** (collapsible/advanced): trigger phrase → paste predefined
  text, skipping cleanup.

### Read Aloud  (text-to-speech)
- **Read Selection Shortcut:** the ⌥⇧R recorder (co-located here).
- **Voice:** voice picker + Test Voice.
- **Speed.**
- **Clean up text before speaking** toggle.
- **Expressive narration** toggle (opt-in; see below). Visually subordinate to /
  dependent on the cleanup toggle since it rides the same LLM pass.
- **Inline API-key status:** when the Groq key is missing, show a small inline
  warning + "Configure" button that navigates to General › API Key. This is the
  fix for the #1 failure ("hit Test Voice, heard nothing").

### Run Log  (unified history)
- A segmented control at the top: **All / Dictation / Read Aloud**.
- One chronological list; each entry tagged by type with a distinct icon/color.
- Read-aloud events are now recorded (see "Read-aloud run history" below).

## Cross-cutting features

### Shortcut collision detection
Because there's no unified Shortcuts page, when a shortcut recorder binds a combo
already used by another role (hold / toggle / read-selection / copy-again), show
an inline warning on that recorder naming the conflicting role. Detection is a
pure comparison over the active `ShortcutConfiguration` bindings; no new storage.

### Read-aloud run history
Extend the existing run-log store (`PipelineHistoryStore` / `PipelineHistoryItem`,
Core Data) so read-aloud events are recorded alongside dictation runs:
- A `kind` discriminator (dictation vs readAloud) on history entries.
- Read-aloud entry fields: timestamp, source app/bundle id (from the selection
  snapshot), voice, speed, character count, whether cleanup/expressive ran,
  duration, success/cancelled/error.
- The Run Log filter keys off `kind`.

### Expressive narration (opt-in)
A toggle on Read Aloud. When ON (and cleanup is ON, since it rides the same
pass), the normalize-for-speech LLM step uses an augmented prompt that may
insert a small, fixed set of Groq Orpheus emotion tags (`<laugh>`, `<sigh>`,
`<gasp>`, `<groan>`, `<yawn>`, `<sniffle>`, `<cough>`) **sparingly** at natural
spots. Rules: never change wording; only add tags; use at most a few per
passage; only when clearly warranted by the text. Falls back to plain text on
any failure, exactly like the existing cleanup. When expressive is ON but
cleanup is OFF, enabling expressive implies running the (augmented) pass.

## Implementation mapping (for the plan)

- **`SettingsTab` enum** (`AppState.swift`) becomes the single source of truth
  for sidebar order + labels + icons. New cases: `.about`, `.setup`,
  `.readAloud`; rename `.dictation` stays, `.voice` is removed (its API-key card
  moves to General, its read-aloud cards move to Read Aloud). Divider rendered
  after `.about`.
- **Retire the `CardGroup` switch** in `GeneralSettingsView`. Split into focused
  views: `AboutSettingsView`, `SetupSettingsView`, `GeneralSettingsView`
  (slimmed), `DictationSettingsView`, `ReadAloudSettingsView`. The settings
  router (`SettingsView` switch) maps one enum case → one view. Goal: adding a
  page later = one enum case + one view, no second switch to edit.
- **Run Log:** `RunLogView` gains the segmented filter; `PipelineHistoryStore`
  gains the `kind` discriminator + read-aloud write path, called from
  `AppState.readSelectionAloud()` / `SpeechSynthesisService`.
- **Read Aloud inline key status + Setup rows** read existing published state on
  `AppState` (apiKey, permission flags, shortcut bindings); navigation sets
  `appState.selectedSettingsTab`.

## Out of scope (future)

- A dedicated multi-provider "Providers" page (revisit when the parked local
  Chatterbox engine or multiple TTS providers land).
- Per-app voice rules.
- Inline/point-of-use configuration (configuring in the overlay) — the devil's
  advocate's idea; interesting but a separate effort.

## Risks

1. **Dictation page overcrowding** (~10 cards). Mitigation: Prompts / Voice
   Macros / Custom Vocabulary as collapsible "advanced" sections.
2. **Setup ↔ General drift.** Mitigation: Setup never owns state — it reads the
   same `AppState` values General's Permissions card writes.
3. **Expressive narration hamminess.** Mitigation: restrained prompt, opt-in,
   small fixed tag set, easy off.
4. **Run-log schema migration** for the new `kind` field on existing Core Data
   store. Mitigation: default existing rows to `.dictation`.
5. **Large settings refactor regressing existing controls.** Mitigation: move
   cards verbatim where possible; build + click through every page.
