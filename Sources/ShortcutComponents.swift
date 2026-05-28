import SwiftUI
import AppKit

struct DictationShortcutEditor: View {
    @EnvironmentObject var appState: AppState

    let showsIntroText: Bool
    let onCaptureStateChange: ((Bool) -> Void)?

    @State private var activeCaptureRole: ShortcutRole?
    @State private var holdValidationMessage: String?
    @State private var toggleValidationMessage: String?
    @State private var copyAgainValidationMessage: String?

    init(showsIntroText: Bool = true, onCaptureStateChange: ((Bool) -> Void)? = nil) {
        self.showsIntroText = showsIntroText
        self.onCaptureStateChange = onCaptureStateChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsIntroText {
                Text("Hold to record, tap to start and stop, and press the toggle shortcut while holding to latch into tap mode. You can disable either workflow or turn both shortcuts off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appState.holdShortcut.isDisabled && appState.toggleShortcut.isDisabled {
                Label("Both dictation shortcuts are disabled.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ShortcutRoleSection(
                role: .hold,
                selection: appState.holdShortcut,
                validationMessage: holdValidationMessage,
                isCapturing: Binding(
                    get: { activeCaptureRole == .hold },
                    set: { activeCaptureRole = $0 ? .hold : nil }
                ),
                onSelect: { binding in
                    holdValidationMessage = appState.setShortcut(binding, for: .hold)
                }
            )

            ShortcutRoleSection(
                role: .toggle,
                selection: appState.toggleShortcut,
                validationMessage: toggleValidationMessage,
                isCapturing: Binding(
                    get: { activeCaptureRole == .toggle },
                    set: { activeCaptureRole = $0 ? .toggle : nil }
                ),
                onSelect: { binding in
                    toggleValidationMessage = appState.setShortcut(binding, for: .toggle)
                }
            )

            ShortcutRoleSection(
                role: .copyAgain,
                selection: appState.copyAgainShortcut,
                validationMessage: copyAgainValidationMessage,
                isCapturing: Binding(
                    get: { activeCaptureRole == .copyAgain },
                    set: { activeCaptureRole = $0 ? .copyAgain : nil }
                ),
                onSelect: { binding in
                    copyAgainValidationMessage = appState.setShortcut(binding, for: .copyAgain)
                }
            )

            Text("Custom shortcuts can use regular keys, modifier-only shortcuts, or modifier combinations.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if appState.usesFnShortcut {
                Text("Tip: If Fn opens the Emoji picker, go to System Settings > Keyboard and change \"Press fn key to\" to \"Do Nothing\".")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onChange(of: activeCaptureRole) { role in
            onCaptureStateChange?(role != nil)
        }
        .onDisappear {
            onCaptureStateChange?(false)
        }
    }
}

struct ShortcutRoleSection: View {
    @EnvironmentObject var appState: AppState
    let role: ShortcutRole
    let selection: ShortcutBinding
    let validationMessage: String?
    @Binding var isCapturing: Bool
    let onSelect: (ShortcutBinding) -> Void

    @State private var captureBackend: LocalShortcutCaptureBackend?
    @State private var captureInputState = ShortcutInputState()
    @State private var currentBinding: ShortcutBinding?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(role.title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if isCapturing {
                    Text(currentBinding?.displayName ?? "Press shortcut…")
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.blue)
                    Button("Done") { finishCapture() }
                        .buttonStyle(.bordered)
                    Button("Cancel") { cancelCapture() }
                        .buttonStyle(.plain)
                } else {
                    Menu {
                        Button("Disabled") { onSelect(.disabled) }
                        Divider()
                        ForEach(ShortcutPreset.allCases) { preset in
                            Button(preset.title) { onSelect(preset.binding) }
                        }
                        if let saved = appState.savedCustomShortcut(for: role) {
                            Divider()
                            Button(saved.displayName) { onSelect(saved) }
                        }
                        Divider()
                        Button("Record Custom…") { startCapture() }
                    } label: {
                        Text(selection.selectionTitle)
                            .font(selection.isCustom ? .system(.body, design: .monospaced) : .body)
                    }
                    .fixedSize()
                }
            }

            if isCapturing {
                Text(currentBinding == nil
                     ? "Press and hold the shortcut you want."
                     : "Press Esc or Enter to save.")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            if let validationMessage, !validationMessage.isEmpty {
                Label(validationMessage, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onDisappear { stopCapture(clearCaptureState: true) }
    }

    private func startCapture() {
        stopCapture(clearCaptureState: false)
        isCapturing = true
        captureInputState = ShortcutInputState()
        currentBinding = nil

        let backend = LocalShortcutCaptureBackend()
        backend.onInputEvent = { inputEvent in
            let result = ShortcutMatcher.reduce(
                state: captureInputState,
                event: inputEvent,
                configuration: .disabled
            )
            captureInputState = result.state

            guard case .modifierChanged(let keyCode, _) = inputEvent else { return }
            if let binding = ShortcutBinding.fromModifierKeyCode(
                keyCode,
                pressedModifierKeyCodes: captureInputState.pressedModifierKeyCodes,
                allowBareModifier: true
            ) {
                currentBinding = binding
            }
        }
        backend.onKeyDownEvent = { event in
            let isReturnKey = event.keyCode == 36 || event.keyCode == 76
            let hasPendingCapture = currentBinding != nil

            if isReturnKey && hasPendingCapture {
                finishCapture()
                return
            }
            if event.keyCode == 53 && hasPendingCapture {
                finishCapture()
                return
            }

            guard !ShortcutBinding.modifierKeyCodes.contains(event.keyCode) else {
                return
            }

            guard let binding = ShortcutBinding.from(
                event: event,
                pressedModifierKeyCodes: captureInputState.pressedModifierKeyCodes
            ) else {
                return
            }

            currentBinding = binding
        }
        backend.start()
        captureBackend = backend
    }

    private func finishCapture() {
        guard let currentBinding else {
            cancelCapture()
            return
        }
        onSelect(currentBinding)
        stopCapture(clearCaptureState: true)
    }

    private func cancelCapture() {
        stopCapture(clearCaptureState: true)
    }

    private func stopCapture(clearCaptureState: Bool) {
        captureBackend?.stop()
        captureBackend = nil
        captureInputState = ShortcutInputState()
        currentBinding = nil
        if clearCaptureState {
            isCapturing = false
        }
    }
}
