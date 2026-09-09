import SwiftUI

struct AppearancePreferencesSection: View {
    @ObservedObject var preferences: AppearancePreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
                .font(Fixer.sans(14, .semibold))
                .foregroundStyle(Fixer.text)
                .accessibilityAddTraits(.isHeader)

            Picker("Appearance", selection: $preferences.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("Follow System uses the appearance set in macOS.")
                .font(Fixer.sans(11))
                .foregroundStyle(Fixer.muted)
        }
    }
}
