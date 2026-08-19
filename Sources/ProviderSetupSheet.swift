import KeyboardShortcuts
import SwiftUI

/// Three-step readiness flow presented from the main settings workspace.
///
/// The shared controller instances are injected by `SettingsView`; keeping the
/// sheet stateless avoids a second API-key/model-loading lifecycle while it is
/// presented or dismissed.
struct ProviderSetupSheet: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: SettingsManager
    @ObservedObject var provider: ProviderSetupController

    let refreshAccessibilityOnAppear: Bool
    let onClose: () -> Void

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { provider.apiKey },
            set: { provider.updateAPIKey($0) }
        )
    }

    private var hasRunnableAction: Bool {
        ActionShortcutPolicy.hasRunnableAction(
            actions: settings.actions,
            shortcutFor: KeyboardShortcuts.getShortcut
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            setupHeader

            setupSection(
                number: "01",
                title: "Accessibility",
                isComplete: appState.accessibilityGranted
            ) {
                Text("Allows Fixer to copy selected text and send the result back to the app you’re using.")
                    .font(Fixer.sans(12))
                    .foregroundStyle(Fixer.textDim)
                    .fixedSize(horizontal: false, vertical: true)

                if !appState.accessibilityGranted {
                    Button("Open System Settings") {
                        PermissionsManager.promptForAccessibility()
                        PermissionsManager.openAccessibilitySettings()
                    }
                    .buttonStyle(FixerPrimaryButton())
                    .padding(.top, 9)
                }
            }

            sectionDivider

            setupSection(
                number: "02",
                title: "Gemini API key",
                isComplete: provider.hasStoredKey
            ) {
                providerSection
            }

            sectionDivider

            setupSection(
                number: "03",
                title: "Enabled action shortcut",
                isComplete: hasRunnableAction
            ) {
                Text("Close setup, enable an action, and record a unique global shortcut. Disabled actions and shortcut conflicts cannot run.")
                    .font(Fixer.sans(12))
                    .foregroundStyle(Fixer.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Done") { onClose() }
                    .buttonStyle(FixerPrimaryButton())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 22)
        }
        .padding(26)
        .frame(width: 520)
        .background(Fixer.base)
        .onAppear {
            if refreshAccessibilityOnAppear {
                appState.refreshAccessibility()
            }
        }
    }

    private var setupHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            RepairMark()
                .frame(width: 36, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("Finish setup")
                    .font(Fixer.display(28, .bold))
                    .foregroundStyle(Fixer.text)
                Text("Permission, provider and at least one shortcut make Fixer ready.")
                    .font(Fixer.sans(12))
                    .foregroundStyle(Fixer.muted)
            }
            Spacer()
        }
        .padding(.bottom, 20)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Fixer.line)
            .frame(height: 1)
            .padding(.vertical, 18)
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            FixerField(borderColor: provider.keyValidated ? Fixer.fixed : Fixer.line2) {
                HStack(spacing: 8) {
                    SecureField("Paste your key", text: apiKeyBinding)
                        .textFieldStyle(.plain)
                        .font(Fixer.mono(12))
                        .foregroundStyle(Fixer.text)

                    if provider.keyValidated {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Fixer.fixed)
                    }
                }
            }

            HStack(spacing: 10) {
                Button(provider.isLoadingModels ? "Checking…" : "Check key & load models") {
                    provider.fetchModels()
                }
                .buttonStyle(FixerPrimaryButton())
                .disabled(!provider.hasStoredKey || provider.isLoadingModels)

                Link("Get a key ↗", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                    .font(Fixer.sans(11.5, .medium))
                    .foregroundStyle(Fixer.textDim)
            }
            .padding(.top, 10)

            providerStatus

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .padding(.top, 2)
                Text("The API key stays in macOS Keychain. Selected text briefly passes through the system clipboard and is sent to Google Gemini.")
                    .font(Fixer.sans(10.5))
            }
            .foregroundStyle(Fixer.muted)
            .padding(.top, 10)

            if provider.canRemoveKey {
                Button("Remove key") {
                    provider.removeKey()
                }
                .buttonStyle(.plain)
                .font(Fixer.sans(11, .medium))
                .foregroundStyle(Fixer.safeText)
                .padding(.top, 9)
            }
        }
    }

    @ViewBuilder
    private var providerStatus: some View {
        if let modelError = provider.modelError {
            Text(modelError)
                .font(Fixer.sans(11))
                .foregroundStyle(Fixer.safeText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        } else if provider.keyValidated {
            Text("Key works · \(provider.availableModels.count) models loaded")
                .font(Fixer.sans(11, .medium))
                .foregroundStyle(Fixer.fixed)
                .padding(.top, 8)
        }
    }

    private func setupSection<Content: View>(
        number: String,
        title: String,
        isComplete: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(Fixer.mono(10, .semibold))
                .foregroundStyle(isComplete ? Fixer.fixed : Fixer.yellowDark)
                .frame(width: 25, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(Fixer.sans(14, .semibold))
                        .foregroundStyle(Fixer.text)
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Fixer.fixed)
                    }
                }
                content()
            }
        }
    }
}
