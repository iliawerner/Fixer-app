import SwiftUI

struct HistoryPreferencesSection: View {
    @ObservedObject var preferences: HistoryPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History & clipboard")
                .font(.headline)
                .foregroundStyle(Fixer.text)
                .accessibilityAddTraits(.isHeader)
            Toggle("Copy result when the original target has changed", isOn: $preferences.copyResultWhenTargetChanges)
                .toggleStyle(.checkbox)
                .font(.callout)
            Text("If you switch fields or Fixer cannot verify the target, the result stays in History. With this option on, it also replaces your clipboard.")
                .font(.callout)
                .foregroundStyle(Fixer.textDim)
                .fixedSize(horizontal: false, vertical: true)
            Picker("Keep successful runs", selection: $preferences.retentionDays) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
                Text("Forever").tag(0)
            }
            .pickerStyle(.menu)
            Text("Text and audio are stored on this Mac. Failed and interrupted runs stay until you delete them. Successful and cancelled runs are cleaned up at launch.")
                .font(.caption)
                .foregroundStyle(Fixer.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
