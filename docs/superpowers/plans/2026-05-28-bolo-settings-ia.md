# Bolo Settings IA Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure Bolo's Settings into a polished two-way IA — sidebar `About / —divider— / Setup / General / Dictation / Read Aloud / Run Log`, with tinted icon badges, a Setup status dashboard, a unified Run Log (dictation + read-aloud), an opt-in expressive-narration toggle, and shortcut collision warnings.

**Architecture:** SwiftUI settings live in `Sources/SettingsView.swift`; the sidebar is driven by the `SettingsTab` enum in `Sources/AppState.swift`; the content router is a `switch` in `SettingsView`. Today three "pages" (general/voice/dictation) share one `GeneralSettingsView` switching on a `CardGroup` enum; About/Setup become new standalone views, the config pages stay in `GeneralSettingsView` with an expanded page enum (least-churn). Run-log history is Core Data via `PipelineHistoryStore`; read-aloud events reuse the existing `intent` string field (no schema migration). Expressive narration rides the existing `normalizeForSpeech` LLM pass in `SpeechSynthesisService`.

**Tech Stack:** Swift / SwiftUI / AppKit, built with `make` (`swiftc`, no SwiftPM, no XCTest).

**No test harness:** This project has no unit tests. Each task's verification is: build, launch, and click through the affected UI. Build command (use everywhere a step says "build"):
```
make APP_NAME=Bolo BUNDLE_ID=com.virkhanna.bolo CODESIGN_IDENTITY="Bolo Dev"
```
Relaunch command:
```
pkill -x Bolo 2>/dev/null; sleep 1; open build/Bolo.app
```

---

## File structure

- `Sources/AppState.swift` — `SettingsTab` enum (cases/labels/icons/tint/divider), new `ttsExpressiveEnabled` published property + storage, `readSelectionAloud()` wiring for expressive + run-history, read-aloud history recorder, shortcut collision check in `setShortcut`, new `PipelineHistoryItemIntent.readAloud`.
- `Sources/PipelineHistoryItem.swift` — add `.readAloud` intent case.
- `Sources/SettingsView.swift` — `SidebarIconBadge` view, sidebar row + divider rendering, router switch, new `AboutSettingsView` + `SetupSettingsView`, `GeneralSettingsView` page-enum regroup (General/Dictation/Read Aloud), Read Aloud expressive toggle + inline key status, `RunLogView` segmented filter + read-aloud entry rendering.
- `Sources/ShortcutComponents.swift` — remove `.readSelection` row from `DictationShortcutEditor`; collision warning surfaced via existing `validationMessage`.
- `Sources/SpeechSynthesisService.swift` — expressive variant of the normalize prompt + `expressive` param on `normalizeForSpeech`.

---

## Phase 1 — Sidebar shell (enum, badges, divider, router)

### Task 1: Rework the `SettingsTab` enum

**Files:**
- Modify: `Sources/AppState.swift:23-63` (the `SettingsTab` enum)

- [ ] **Step 1: Replace the enum** with new cases, order, labels, icons, a `tint`, and a divider flag.

```swift
import SwiftUI   // ensure Color is available in this file (add if missing)

enum SettingsTab: String, CaseIterable, Identifiable {
    case about
    case setup
    case general
    case dictation
    case readAloud
    case runLog
    case debug

    var id: String { rawValue }

    static var visibleCases: [SettingsTab] {
        allCases.filter { tab in
            tab != .debug || AppBuild.isDevBundle
        }
    }

    var title: String {
        switch self {
        case .about: return "About Bolo"
        case .setup: return "Setup"
        case .general: return "General"
        case .dictation: return "Dictation"
        case .readAloud: return "Read Aloud"
        case .runLog: return "Run Log"
        case .debug: return "Debug"
        }
    }

    var icon: String {
        switch self {
        case .about: return "info.circle.fill"
        case .setup: return "checkmark.seal.fill"
        case .general: return "gearshape.fill"
        case .dictation: return "mic.fill"
        case .readAloud: return "speaker.wave.2.fill"
        case .runLog: return "clock.arrow.circlepath"
        case .debug: return "wrench.and.screwdriver.fill"
        }
    }

    var tint: Color {
        switch self {
        case .about: return .gray
        case .setup: return .orange
        case .general: return Color(nsColor: .darkGray)
        case .dictation: return .red
        case .readAloud: return .purple
        case .runLog: return .teal
        case .debug: return .brown
        }
    }

    /// A divider is drawn in the sidebar after this item.
    var showsDividerAfter: Bool { self == .about }
}
```

- [ ] **Step 2: Check `import SwiftUI` exists** at the top of `Sources/AppState.swift`. If only `Foundation`/`AppKit` are imported, add `import SwiftUI`. Run: `head -10 Sources/AppState.swift`.

- [ ] **Step 3: Build** (expect failures in `SettingsView.swift` router referencing removed `.voice` / `.macros` / `.prompts` — fixed in Task 2/3). Run the build command; note the errors are confined to `SettingsView.swift`.

(No commit yet — the app won't build until Task 2. Tasks 1–2 commit together.)

### Task 2: Sidebar badges, divider, and router

**Files:**
- Modify: `Sources/SettingsView.swift:400-445` (the `SettingsView` body: sidebar `ForEach` + router `switch`)
- Modify: `Sources/SettingsView.swift:452-472` (`SettingsSidebarRow`)
- Add: `SidebarIconBadge` view in `Sources/SettingsView.swift` (next to `SettingsSidebarRow`)

- [ ] **Step 1: Add the `SidebarIconBadge` view** (place directly above `private struct SettingsSidebarRow`):

```swift
private struct SidebarIconBadge: View {
    let systemName: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(tint)
            .frame(width: 20, height: 20)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}
```

- [ ] **Step 2: Rework `SettingsSidebarRow`** to take a tint and render the badge:

```swift
private struct SettingsSidebarRow: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            SidebarIconBadge(systemName: icon, tint: tint)
            Text(title)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }
}
```

- [ ] **Step 3: Update the sidebar `ForEach`** (lines ~406-419) to pass the tint and draw the divider after About:

```swift
ForEach(SettingsTab.visibleCases) { tab in
    Button {
        appState.selectedSettingsTab = tab
    } label: {
        SettingsSidebarRow(title: tab.title, icon: tab.icon, tint: tab.tint)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(appState.selectedSettingsTab == tab
                          ? Color.accentColor.opacity(0.15)
                          : Color.clear)
            )
    }
    .buttonStyle(.plain)

    if tab.showsDividerAfter {
        Divider().padding(.vertical, 4)
    }
}
```

- [ ] **Step 4: Update the router `switch`** (lines ~429-445) to the new cases. About/Setup point to new views (created in Phase 2/3 — add temporary stubs now so it builds):

```swift
switch appState.selectedSettingsTab {
case .about, .none:
    AboutSettingsView()
case .setup:
    SetupSettingsView()
case .general:
    GeneralSettingsView(page: .general)
case .dictation:
    GeneralSettingsView(page: .dictation)
case .readAloud:
    GeneralSettingsView(page: .readAloud)
case .runLog:
    RunLogView()
case .debug:
    DebugSettingsView()
}
```

- [ ] **Step 5: Add temporary stubs** at the bottom of `Sources/SettingsView.swift` so the project builds (replaced fully in Phase 2/3):

```swift
struct AboutSettingsView: View { var body: some View { Text("About — TODO") } }
struct SetupSettingsView: View { var body: some View { Text("Setup — TODO") } }
```

- [ ] **Step 6: Change `GeneralSettingsView`'s `CardGroup` to `Page`** with the new cases. At `Sources/SettingsView.swift:624` replace:
  `enum CardGroup { case general, voice, dictation }`
  with:
  `enum Page { case general, dictation, readAloud }`
  and rename the stored property: change `let group: CardGroup` (near the top of `GeneralSettingsView`) to `let page: Page`. Update the call sites `GeneralSettingsView(group:)` → `GeneralSettingsView(page:)` (already done in Step 4). Inside the body, the branding header currently shown for `group == .general` will be REMOVED in Phase 2 (it moves to About); for now change `if group == .general {` to `if false {` to disable it temporarily, and change the content `switch group {` to `switch page {` with cases `.general`, `.dictation`, and a new `.readAloud` that for now shows the existing voice cards. Concretely, in that switch use:
    - `case .general:` keep the existing General cards (App/Updates/Permissions/Build) — they get reorganized in Phase 4.
    - `case .dictation:` keep the existing Dictation cards.
    - `case .readAloud:` paste the three cards currently under the old `.voice` case (API Key, Read Aloud, Output Language) — reorganized in Phase 4/6.

- [ ] **Step 7: Build and launch.** Run build + relaunch commands. Expected: sidebar shows 6 rows (About, Setup, General, Dictation, Read Aloud, Run Log) with colored icon badges and a divider under About; About/Setup show TODO text; General/Dictation/Read Aloud show their cards.

- [ ] **Step 8: Commit.**
```bash
git add Sources/AppState.swift Sources/SettingsView.swift
git commit -m "Settings IA: new sidebar (tinted badges, divider, About/Setup/Read Aloud)"
```

---

## Phase 2 — About page

### Task 3: Build `AboutSettingsView`

**Files:**
- Modify: `Sources/SettingsView.swift` (replace the `AboutSettingsView` stub; remove the branding header + `aboutSection` + GitHub `@StateObject`s from `GeneralSettingsView`)

- [ ] **Step 1: Move the branding header + repo cards + about text into `AboutSettingsView`.** Replace the stub with a real view that owns the two GitHub caches and renders: app icon + name + version; `GitHubRepoCard` for `v-khanna/bolo`; the "Built on FreeFlow (MIT) — credit below" caption; `GitHubRepoCard` for `zachlatta/freeflow`; then the existing About Bolo text block. Use the exact contents currently in `GeneralSettingsView` (the branding `VStack` at ~lines 586-720 and `aboutSection` at ~lines 802-841). Concretely:

```swift
struct AboutSettingsView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var githubCache = GitHubMetadataCache.shared
    @StateObject private var boloGithubCache = GitHubMetadataCache.bolo
    private let freeflowRepoURL = URL(string: "https://github.com/zachlatta/freeflow")!
    private let boloRepoURL = URL(string: "https://github.com/v-khanna/bolo")!

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                    Text(AppName.displayName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("v\(appVersion)")
                        .font(.caption).foregroundStyle(.secondary)

                    GitHubRepoCard(cache: boloGithubCache, repoLabel: "v-khanna/bolo",
                                   repoURL: boloRepoURL,
                                   avatarURL: URL(string: "https://github.com/v-khanna.png"))
                        .padding(.top, 2)
                    Text("Built on FreeFlow (MIT) — credit below")
                        .font(.caption2).foregroundStyle(.tertiary).padding(.vertical, 2)
                    GitHubRepoCard(cache: githubCache, repoLabel: "zachlatta/freeflow",
                                   repoURL: freeflowRepoURL,
                                   avatarURL: URL(string: "https://avatars.githubusercontent.com/u/992248"))
                }
                .frame(maxWidth: .infinity).padding(.top, 4)

                SettingsCard("About Bolo", icon: "info.circle") {
                    aboutSection
                }
            }
            .padding(24)
        }
        .onAppear {
            Task { await githubCache.fetchIfNeeded() }
            Task { await boloGithubCache.fetchIfNeeded() }
        }
    }

    private var aboutSection: some View {
        // MOVE the body of GeneralSettingsView.aboutSection here verbatim
        // (the two descriptive Text blocks + Divider + "Built on FreeFlow"
        // block with the two GitHub link buttons). Uses boloRepoURL/freeflowRepoURL/openURL
        // which are now defined on this view.
        EmptyView()  // replace with the moved content
    }
}
```

- [ ] **Step 2: Delete the moved code from `GeneralSettingsView`:** remove the branding `VStack` (the `if false {...}` block from Phase 1), the `aboutSection` computed property, the "About Bolo" `SettingsCard` from the `.general` page, and the now-unused `githubCache`/`boloGithubCache` `@StateObject`s and `boloRepoURL`/`freeflowRepoURL` lets IF they are no longer referenced elsewhere in `GeneralSettingsView`. (Search the file; keep any still used.)

- [ ] **Step 3: Build and launch.** Expected: About tab shows icon, name, version, both repo cards, and the About Bolo text block; no duplicate About content under General.

- [ ] **Step 4: Commit.**
```bash
git add Sources/SettingsView.swift
git commit -m "Settings IA: dedicated About page"
```

---

## Phase 3 — Setup status dashboard

### Task 4: Build `SetupSettingsView`

**Files:**
- Modify: `Sources/SettingsView.swift` (replace the `SetupSettingsView` stub)

Read-only dashboard: each row shows a status badge and navigates (sets `appState.selectedSettingsTab`) to the owning page. It reads existing published state (`appState.apiKey`, `appState.hasScreenRecordingPermission`, mic/accessibility status, shortcut bindings) — it never mutates state.

- [ ] **Step 1: Confirm the permission/state accessors.** Run:
```bash
grep -n "accessibilityGranted\|micPermission\|func checkMicPermission\|AXIsProcessTrusted\|hasScreenRecordingPermission\|hasEnabledHoldShortcut\|hasEnabledToggleShortcut\|readSelectionShortcut" Sources/AppState.swift | head
```
Use whatever live accessors exist (e.g., `AXIsProcessTrusted()` for accessibility, `appState.hasScreenRecordingPermission`, `AVCaptureDevice.authorizationStatus(for: .audio)` for mic, `!appState.apiKey.isEmpty` for the key, `!appState.readSelectionShortcut.isDisabled` + `appState.hasEnabledHoldShortcut` for shortcuts).

- [ ] **Step 2: Implement the view:**

```swift
struct SetupSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

    private var apiKeySet: Bool {
        !appState.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var shortcutsConfigured: Bool {
        appState.hasEnabledHoldShortcut || appState.hasEnabledToggleShortcut || !appState.readSelectionShortcut.isDisabled
    }
    private var allGood: Bool {
        accessibilityGranted && micGranted && apiKeySet && shortcutsConfigured
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if allGood {
                    SetupBanner()
                }
                SettingsCard("Setup", icon: "checkmark.seal.fill") {
                    VStack(spacing: 0) {
                        SetupRow(title: "Accessibility", subtitle: "Required to read selected text & type.",
                                 ok: accessibilityGranted, okLabel: "Granted") { appState.selectedSettingsTab = .general }
                        Divider()
                        SetupRow(title: "Microphone", subtitle: "Required for dictation.",
                                 ok: micGranted, okLabel: "Granted") { appState.selectedSettingsTab = .general }
                        Divider()
                        SetupRow(title: "Groq API Key", subtitle: "Powers transcription and read-aloud.",
                                 ok: apiKeySet, okLabel: "Set") { appState.selectedSettingsTab = .general }
                        Divider()
                        SetupRow(title: "Shortcuts", subtitle: "Dictation and read-aloud hotkeys.",
                                 ok: shortcutsConfigured, okLabel: "Configured") { appState.selectedSettingsTab = .dictation }
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
            micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }
}

private struct SetupBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("All set!").font(.headline)
                Text("Bolo is ready. Talk to type, or select text and press your read shortcut.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.10)))
    }
}

private struct SetupRow: View {
    let title: String
    let subtitle: String
    let ok: Bool
    let okLabel: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(ok ? okLabel : "Needs action")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ok ? .green : .orange)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill((ok ? Color.green : Color.orange).opacity(0.14)))
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Ensure `import AVFoundation`** is present at the top of `Sources/SettingsView.swift` (for `AVCaptureDevice`). Add if missing.

- [ ] **Step 4: Build and launch.** Expected: Setup tab lists 4 rows with green/orange badges; tapping a row switches to General/Dictation; "All set!" banner appears only when everything is satisfied. Verify it does NOT expose toggles (read-only).

- [ ] **Step 5: Commit.**
```bash
git add Sources/SettingsView.swift
git commit -m "Settings IA: Setup status dashboard (read-only, deep-links)"
```

---

## Phase 4 — General page (API key in, voice cards out)

### Task 5: Reorganize the General page

**Files:**
- Modify: `Sources/SettingsView.swift` (the `.general` case of `GeneralSettingsView`'s page switch, ~lines 722-745)

- [ ] **Step 1: Set the `.general` page card list** to: App, API Key, Updates, Permissions, Sound Volume, Build. Move the `apiKeySection` card (currently under the old `.voice` case) into `.general`, and move the `soundVolumeSection` card (currently under `.dictation`) into `.general`. Resulting `.general` branch:

```swift
case .general:
    SettingsCard("App", icon: "power") { startupSection }
    SettingsCard("API Key", icon: "key.fill") { apiKeySection }
    SettingsCard("Updates", icon: "arrow.triangle.2.circlepath") { updatesSection }
    SettingsCard("Permissions", icon: "lock.shield.fill") { permissionsSection }
    SettingsCard("Sound Volume", icon: "speaker.wave.2.fill") { soundVolumeSection }
    SettingsCard("Build", icon: "info.circle.fill") { buildInfoSection }
```

- [ ] **Step 2: Build and launch.** Expected: General shows App / API Key / Updates / Permissions / Sound Volume / Build. API key field is present and editable here.

- [ ] **Step 3: Commit.**
```bash
git add Sources/SettingsView.swift
git commit -m "Settings IA: General owns API key + app/system cards"
```

---

## Phase 5 — Dictation page (regroup; fold Prompts + Voice Macros; drop read-selection from its shortcuts)

### Task 6: Compose the Dictation page

**Files:**
- Modify: `Sources/SettingsView.swift` (the `.dictation` case of the page switch)
- Modify: `Sources/ShortcutComponents.swift` (remove the `.readSelection` `ShortcutRoleSection` from `DictationShortcutEditor`, lines ~74-84)

- [ ] **Step 1: Remove the read-selection row from `DictationShortcutEditor`.** Delete the `ShortcutRoleSection(role: .readSelection, ...)` block (and its `@State private var readSelectionValidationMessage` if now unused) from `Sources/ShortcutComponents.swift`. Dictation shortcuts now = hold + toggle (+ copyAgain if present). The read-selection recorder moves to Read Aloud (Phase 6).

- [ ] **Step 2: Set the `.dictation` card list** (move `Prompts` + `Voice Macros` content in as cards; remove Sound Volume which moved to General in Phase 4):

```swift
case .dictation:
    SettingsCard("Dictation Shortcuts", icon: "keyboard.fill") { hotkeySection }
    SettingsCard("Microphone", icon: "mic.fill") { microphoneSection }
    SettingsCard("Audio During Dictation", icon: "speaker.slash.fill") { dictationAudioSection }
    SettingsCard("Recording Overlay", icon: "rectangle.dashed") { overlaySection }
    SettingsCard("Edit Mode", icon: "pencil") { commandModeSection }
    SettingsCard("Clipboard", icon: "doc.on.clipboard") { clipboardSection }
    SettingsCard("Output Language", icon: "globe") { outputLanguageSection }
    SettingsCard("Custom Vocabulary", icon: "text.book.closed.fill") { vocabularySection }
    SettingsCard("Cleanup Prompts", icon: "text.bubble.fill") { dictationPromptsSection }
    SettingsCard("Voice Macros", icon: "music.mic") { dictationMacrosSection }
```

- [ ] **Step 3: Bridge the Prompts + Voice Macros content into `GeneralSettingsView`.** The existing `PromptsSettingsView` and `VoiceMacrosSettingsView` are standalone views. Add two computed properties on `GeneralSettingsView` that embed them so they render as cards:

```swift
private var dictationPromptsSection: some View { PromptsSettingsView() }
private var dictationMacrosSection: some View { VoiceMacrosSettingsView() }
```
Note: `PromptsSettingsView`/`VoiceMacrosSettingsView` already wrap their content in `SettingsCard`s inside a `ScrollView`. To avoid a nested ScrollView + double card, refactor each to expose its inner section: add a `var content: some View` to each that returns the `VStack` of cards WITHOUT the outer `ScrollView`, and have the standalone `body` wrap `content` in the `ScrollView`. Then here use `PromptsSettingsView().content`. (If that refactor is too invasive, instead keep them as their own thin computed sections by copying their section `VStack`s.) Keep the outer Dictation `ScrollView` as the only scroller.

- [ ] **Step 4: Build and launch.** Expected: Dictation page lists all dictation cards including Cleanup Prompts and Voice Macros; the Dictation Shortcuts card no longer shows a "Read Selection Aloud" recorder. No nested-scroll jank.

- [ ] **Step 5: Commit.**
```bash
git add Sources/SettingsView.swift Sources/ShortcutComponents.swift
git commit -m "Settings IA: Dictation page (folds Prompts + Voice Macros; read shortcut moved out)"
```

---

## Phase 6 — Read Aloud page

### Task 7: Compose the Read Aloud page (recorder + voice + expressive + inline key)

**Files:**
- Modify: `Sources/SettingsView.swift` (the `.readAloud` case + the existing `readAloudSection`)

- [ ] **Step 1: Set the `.readAloud` card list:**

```swift
case .readAloud:
    SettingsCard("Read Selection Shortcut", icon: "command") { readShortcutSection }
    SettingsCard("Read Aloud", icon: "speaker.wave.2.fill") { readAloudSection }
```

- [ ] **Step 2: Add a `readShortcutSection`** that renders the read-selection recorder via the existing reusable `ShortcutRoleSection` (the same component used in `DictationShortcutEditor`). Add to `GeneralSettingsView`:

```swift
@State private var readSelectionValidationMessage: String?

private var readShortcutSection: some View {
    ShortcutRoleSection(
        role: .readSelection,
        selection: appState.readSelectionShortcut,
        validationMessage: readSelectionValidationMessage,
        isCapturing: Binding(
            get: { capturingReadShortcut },
            set: { capturingReadShortcut = $0 }
        ),
        onCapture: { binding in
            readSelectionValidationMessage = appState.setShortcut(binding, for: .readSelection)
        }
    )
}
```
Confirm `ShortcutRoleSection`'s exact init params against `Sources/ShortcutComponents.swift:106+` and match them (the example mirrors the copyAgain/readSelection usage previously in `DictationShortcutEditor`). Add the `@State private var capturingReadShortcut = false` and, while capturing, call `appState.suspendHotkeyMonitoringForShortcutCapture()` / `resumeHotkeyMonitoringAfterShortcutCapture()` (mirror `DictationShortcutEditor`).

- [ ] **Step 3: Add inline API-key status to `readAloudSection`.** At the top of the existing `readAloudSection` `VStack`, insert a warning shown only when the key is missing:

```swift
if appState.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
        Text("Add your Groq API key to use read-aloud.").font(.caption)
        Button("Configure") { appState.selectedSettingsTab = .general }
            .font(.caption)
    }
    .padding(.bottom, 4)
}
```

- [ ] **Step 4: Add the expressive-narration toggle** (after the "Clean up text before speaking" toggle in `readAloudSection`). The `ttsExpressiveEnabled` property is added in Phase 7 Task 8 — if implementing Read Aloud first, add the property now or do Task 8 before this step. Insert:

```swift
Toggle("Expressive narration", isOn: $appState.ttsExpressiveEnabled)
    .disabled(!appState.ttsCleanupEnabled)
Text("Lets the cleanup AI add occasional emotion (laughs, sighs) where the text calls for it. Requires “Clean up text before speaking.”")
    .font(.caption).foregroundStyle(.secondary)
```

- [ ] **Step 5: Build and launch.** Expected: Read Aloud page shows the ⌥⇧R recorder (editable), the voice/Test/speed/cleanup controls, an expressive toggle (disabled unless cleanup is on), and — only when no key — an inline "Configure" warning that jumps to General.

- [ ] **Step 6: Commit.**
```bash
git add Sources/SettingsView.swift
git commit -m "Settings IA: Read Aloud page (shortcut + expressive toggle + inline key status)"
```

---

## Phase 7 — Expressive narration engine

### Task 8: Add the `ttsExpressiveEnabled` setting

**Files:**
- Modify: `Sources/AppState.swift` (storage key ~line 221, published prop ~line 395, load ~line 667, init assignment ~line 765)

- [ ] **Step 1: Add the storage key** near `ttsCleanupStorageKey` (line ~221):
```swift
private let ttsExpressiveStorageKey = "tts_expressive"
```

- [ ] **Step 2: Add the published property** near `ttsCleanupEnabled` (line ~395):
```swift
@Published var ttsExpressiveEnabled: Bool {
    didSet { UserDefaults.standard.set(ttsExpressiveEnabled, forKey: ttsExpressiveStorageKey) }
}
```

- [ ] **Step 3: Load it** near line ~667:
```swift
let ttsExpressiveEnabled = UserDefaults.standard.bool(forKey: ttsExpressiveStorageKey)
```

- [ ] **Step 4: Assign in init** near line ~765:
```swift
self.ttsExpressiveEnabled = ttsExpressiveEnabled
```

- [ ] **Step 5: Build.** Expect success. (Toggle already added in Phase 6 Step 4.)

- [ ] **Step 6: Commit.**
```bash
git add Sources/AppState.swift
git commit -m "Read-aloud: add expressive narration setting"
```

### Task 9: Expressive variant of the cleanup prompt

**Files:**
- Modify: `Sources/SpeechSynthesisService.swift` (`normalizeSystemPrompt` ~line 103, `normalizeForSpeech` ~line 120)
- Modify: `Sources/AppState.swift` (`readSelectionAloud()` ~line 1745 cleanup branch)

- [ ] **Step 1: Add an expressive prompt + `expressive` param** to `normalizeForSpeech`. Add a second prompt constant and select it:

```swift
private static let expressiveSuffix = """

EXPRESSIVE MODE: You MAY insert these emotion tags, but only sparingly and only where the text genuinely calls for it: <laugh>, <sigh>, <gasp>, <groan>, <yawn>, <sniffle>, <cough>. Use at most a few in the whole passage. Never change wording; only add tags. If unsure, add nothing.
"""

func normalizeForSpeech(text: String, apiKey: String, expressive: Bool = false) async -> String {
    let system = expressive ? (Self.normalizeSystemPrompt + Self.expressiveSuffix) : Self.normalizeSystemPrompt
    // ...use `system` where `Self.normalizeSystemPrompt` was used in the messages array...
}
```
Update the `messages` system content to use the local `system` string.

- [ ] **Step 2: Pass the flag from `readSelectionAloud()`.** In `Sources/AppState.swift` where cleanup runs (~line 1750), thread expressive through:
```swift
let expressive = ttsExpressiveEnabled
// ...
let cleaned = await SpeechSynthesisService.shared.normalizeForSpeech(text: text, apiKey: key, expressive: expressive)
```
Also: if `ttsExpressiveEnabled` is true but `ttsCleanupEnabled` is false, still run the (expressive) normalize pass — change the branch condition from `if cleanup {` to `if cleanup || expressive {`.

- [ ] **Step 3: Build and launch.** Manual check: enable cleanup + expressive, select a line like `"That was hilarious, I can't believe it"`, press ⌥⇧R; the voice may add a `<laugh>`. Toggle expressive off → plain reading.

- [ ] **Step 4: Commit.**
```bash
git add Sources/SpeechSynthesisService.swift Sources/AppState.swift
git commit -m "Read-aloud: expressive narration (opt-in emotion tags via cleanup pass)"
```

---

## Phase 8 — Unified Run Log (read-aloud history + filter)

### Task 10: Add the `.readAloud` history intent

**Files:**
- Modify: `Sources/PipelineHistoryItem.swift:3-7`

- [ ] **Step 1: Add the case** to `PipelineHistoryItemIntent`:
```swift
enum PipelineHistoryItemIntent: String, Codable {
    case dictation
    case commandAutomatic = "command:automatic"
    case commandManual = "command:manual"
    case readAloud = "readAloud"
}
```
(No Core Data migration: `intent` is a string attribute; unknown values already map to `.dictation` via `makeHistoryItem`.)

- [ ] **Step 2: Build.** Expect success.

- [ ] **Step 3: Commit.**
```bash
git add Sources/PipelineHistoryItem.swift
git commit -m "Run log: add readAloud history intent"
```

### Task 11: Record read-aloud events

**Files:**
- Modify: `Sources/AppState.swift` (`readSelectionAloud()` ~line 1715; add a recorder helper near `recordPipelineHistoryEntry` ~line 2840)

- [ ] **Step 1: Add a read-aloud recorder** near `recordPipelineHistoryEntry`:
```swift
private func recordReadAloudHistory(text: String, snapshot: AppSelectionSnapshot, voice: String, speed: Double, cleanup: Bool, expressive: Bool) {
    let status = "voice=\(voice) speed=\(String(format: "%.1f", speed))× cleanup=\(cleanup ? "on" : "off") expressive=\(expressive ? "on" : "off") chars=\(text.count)"
    let entry = PipelineHistoryItem(
        intent: .readAloud,
        selectedText: String(text.prefix(4000)),
        capturedSelection: nil,
        timestamp: Date(),
        rawTranscript: String(text.prefix(4000)),
        postProcessedTranscript: "",
        postProcessingPrompt: nil,
        systemPrompt: nil,
        contextSummary: "",
        contextScreenshotDataURL: nil,
        contextScreenshotStatus: "n/a",
        postProcessingStatus: status,
        debugStatus: "",
        customVocabulary: "",
        contextAppName: snapshot.appName,
        contextBundleIdentifier: snapshot.bundleIdentifier,
        contextWindowTitle: snapshot.windowTitle
    )
    do {
        _ = try pipelineHistoryStore.append(entry, maxCount: maxPipelineHistoryCount)
        pipelineHistory = pipelineHistoryStore.loadAllHistory()
    } catch {
        os_log(.error, log: recordingLog, "Failed to record read-aloud history: %@", error.localizedDescription)
    }
}
```
Confirm `AppSelectionSnapshot`'s field names (`appName`/`bundleIdentifier`/`windowTitle`) via:
```bash
grep -n "struct AppSelectionSnapshot" -A 12 Sources/AppContextService.swift
```
and adjust to the real names.

- [ ] **Step 2: Call it from `readSelectionAloud()`** right after a successful selection+key guard (record the intent to read, before/at synth start). Use the already-fetched `snapshot`, `voice`, `speed`, `cleanup`, and `ttsExpressiveEnabled`.

- [ ] **Step 3: Build and launch.** Read a selection, then open Run Log — a read-aloud entry should appear.

- [ ] **Step 4: Commit.**
```bash
git add Sources/AppState.swift
git commit -m "Run log: record read-aloud events"
```

### Task 12: Run Log segmented filter + read-aloud entry rendering

**Files:**
- Modify: `Sources/SettingsView.swift` (`RunLogView` ~line 2103; `RunLogEntryView` ~line 2152)

- [ ] **Step 1: Add a filter enum + state** to `RunLogView`:
```swift
private enum RunLogFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case dictation = "Dictation"
    case readAloud = "Read Aloud"
    var id: String { rawValue }
}
@State private var filter: RunLogFilter = .all

private var filteredHistory: [PipelineHistoryItem] {
    switch filter {
    case .all: return appState.pipelineHistory
    case .readAloud: return appState.pipelineHistory.filter { $0.intent == .readAloud }
    case .dictation: return appState.pipelineHistory.filter { $0.intent != .readAloud }
    }
}
```

- [ ] **Step 2: Add a `Picker` (segmented)** under the header and drive the list off `filteredHistory`:
```swift
Picker("", selection: $filter) {
    ForEach(RunLogFilter.allCases) { Text($0.rawValue).tag($0) }
}
.pickerStyle(.segmented)
.labelsHidden()
.padding(.horizontal, 24)
.padding(.bottom, 8)
```
Replace `ForEach(appState.pipelineHistory)` with `ForEach(filteredHistory)`, and the empty-state text with one that respects the filter.

- [ ] **Step 3: Render read-aloud entries distinctly** in `RunLogEntryView`. Add a branch: when `item.intent == .readAloud`, show a speaker icon, the spoken text (`item.rawTranscript`), the source app (`item.contextAppName`), and the params line (`item.postProcessingStatus`) — instead of the dictation raw/clean transcript layout. Keep existing dictation rendering otherwise.

- [ ] **Step 4: Build and launch.** Expected: Run Log shows All/Dictation/Read Aloud segments; read-aloud runs appear with a speaker icon + params; dictation runs unchanged; switching filter works.

- [ ] **Step 5: Commit.**
```bash
git add Sources/SettingsView.swift
git commit -m "Run log: All/Dictation/Read Aloud filter + read-aloud entry rendering"
```

---

## Phase 9 — Shortcut collision detection

### Task 13: Warn on duplicate shortcut bindings

**Files:**
- Modify: `Sources/AppState.swift` (`setShortcut(_:for:)` ~line 1527)

- [ ] **Step 1: Read the current `setShortcut`** to see its existing validation return:
```bash
sed -n '1527,1600p' Sources/AppState.swift
```

- [ ] **Step 2: Add a collision check.** Before persisting, compare the new `binding` against the other roles' current bindings (hold, toggle, copyAgain, readSelection — whichever differ from `role`). If the new binding's `displayName` equals another enabled role's binding `displayName`, return a warning string naming the conflicting role (the function already returns `String?` used as the recorder's `validationMessage`). Example shape:
```swift
let others: [(ShortcutRole, ShortcutBinding)] = [
    (.hold, holdShortcut), (.toggle, toggleShortcut),
    (.copyAgain, copyAgainShortcut), (.readSelection, readSelectionShortcut)
].filter { $0.0 != role }
if !binding.isDisabled, let clash = others.first(where: { !$0.1.isDisabled && $0.1.displayName == binding.displayName }) {
    return "Already used by “\(clash.0.title)”. Pick a different combo."
}
```
Insert this near the top of `setShortcut`, after computing/validating `binding` but before saving. (If the function saves first, still set the binding but return the warning so the UI shows it — match the existing pattern.)

- [ ] **Step 3: Build and launch.** Set the read shortcut to the same combo as the dictation toggle → expect an inline warning under the recorder.

- [ ] **Step 4: Commit.**
```bash
git add Sources/AppState.swift
git commit -m "Shortcuts: warn on binding collisions across roles"
```

---

## Phase 10 — Final verification

### Task 14: End-to-end click-through

- [ ] **Step 1: Build + relaunch.**
- [ ] **Step 2: Verify the sidebar:** About (top) / divider / Setup / General / Dictation / Read Aloud / Run Log, each with its tinted badge.
- [ ] **Step 3: About** shows branding + both repo cards + About text.
- [ ] **Step 4: Setup** badges reflect reality; tapping rows navigates; "All set!" only when all green; no toggles.
- [ ] **Step 5: General** has App / API Key / Updates / Permissions / Sound Volume / Build; API key editable.
- [ ] **Step 6: Dictation** has all dictation cards incl. Cleanup Prompts + Voice Macros; no read-selection recorder in the Dictation Shortcuts card.
- [ ] **Step 7: Read Aloud** has the ⌥⇧R recorder, voice/Test/speed/cleanup, expressive toggle (disabled unless cleanup on), inline key warning only when key missing.
- [ ] **Step 8: Functional:** dictation still types; ⌥⇧R still reads selection; expressive adds emotion when on; collision warning fires.
- [ ] **Step 9: Run Log** filters across All/Dictation/Read Aloud; both event types render; a fresh read-aloud appears.
- [ ] **Step 10: Final commit** if any cleanup was needed; then push:
```bash
git push
```

---

## Self-review notes (coverage vs spec)

- Sidebar (About top + divider + Setup/General/Dictation/Read Aloud/Run Log), labels, tinted badges → Tasks 1–2. ✓
- About page → Task 3. ✓ · Setup dashboard (read-only, deep-links) → Task 4. ✓
- General owns API key + app/system; Read Aloud inline key status → Tasks 5, 7. ✓
- Dictation folds Prompts + Voice Macros; read-selection moved to Read Aloud → Task 6. ✓
- No standalone Shortcuts page; collision detection → Task 13. ✓
- Expressive narration (opt-in, rides cleanup) → Tasks 8–9. ✓
- Run Log unified with filter + read-aloud history (intent reuse, no migration) → Tasks 10–12. ✓
- Microphone placed on Dictation (user-confirmed) → Task 6. ✓

**Spec deviations (intentional, lower risk):** (1) read-aloud history reuses the `intent` string field instead of a new `kind` column — avoids Core Data migration (spec risk #4 eliminated). (2) Config pages stay in `GeneralSettingsView` with an expanded `Page` enum rather than fully separate view structs (About + Setup are separate); a deeper view split can be a later refactor.
