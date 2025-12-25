import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var themeManager: ThemeManager
  @ObservedObject var sleepSettings = SleepSettings.shared

  func calculateDuration(start: Date, end: Date) -> String {
      let calendar = Calendar.current
      let startComponents = calendar.dateComponents([.hour, .minute], from: start)
      let endComponents = calendar.dateComponents([.hour, .minute], from: end)

      let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
      let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)

      var diffMinutes = endMinutes - startMinutes
      if diffMinutes < 0 {
          diffMinutes += 24 * 60
      }

      let hours = diffMinutes / 60
      let minutes = diffMinutes % 60

      if minutes == 0 {
          return "\(hours) hr"
      }
      return "\(hours) hr \(minutes) min"
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Sleep Schedule") {
             VStack(spacing: 20) {
                 HStack {
                     VStack(alignment: .leading) {
                         Label("Bedtime", systemImage: "moon.fill")
                             .foregroundColor(.indigo)
                             .font(.headline)
                         DatePicker("", selection: $sleepSettings.optimalSleepTime, displayedComponents: .hourAndMinute)
                             .labelsHidden()
                     }

                     Spacer()

                     VStack(alignment: .leading) {
                         Label("Wake Up", systemImage: "sun.max.fill")
                             .foregroundColor(.orange)
                             .font(.headline)
                         DatePicker("", selection: $sleepSettings.optimalWakeTime, displayedComponents: .hourAndMinute)
                             .labelsHidden()
                     }
                 }

                 // Duration Pill
                 let duration = calculateDuration(start: sleepSettings.optimalSleepTime, end: sleepSettings.optimalWakeTime)
                 HStack {
                     Image(systemName: "clock")
                     Text("Sleep Goal: \(duration)")
                 }
                 .font(.subheadline)
                 .fontWeight(.medium)
                 .foregroundColor(.white)
                 .padding(.vertical, 8)
                 .padding(.horizontal, 16)
                 .background(
                    Capsule()
                        .fill(Color(white: 0.15))
                 )
             }
             .padding(.vertical, 5)
        }

        Section("Theme") {
          HStack {
            Image(systemName: "paintpalette.fill")
              .foregroundStyle(themeManager.themeColor)
              .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
              Text("Appearance")
                .font(.headline)
              Text("Customize the look of your app")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .padding(.vertical, 8)

          Picker("Theme Color", selection: $themeManager.selectedColorName) {
            ForEach(ThemeManager.availableColors, id: \.name) { colorOption in
              HStack {
                Circle()
                  .fill(colorOption.color)
                  .frame(width: 20, height: 20)
                Text(colorOption.name)
              }
              .tag(colorOption.name)
            }
          }
          .onChange(of: themeManager.selectedColorName) { _, _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          }

          Divider()

          Picker("Display Mode", selection: $themeManager.themeMode) {
            ForEach(ThemeManager.ThemeMode.allCases) { mode in
              Text(mode.rawValue).tag(mode)
            }
          }
          .onChange(of: themeManager.themeMode) { _, _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          }
        }

        Section("Development") {
             Button("Restart Onboarding") {
                 SleepSettings.shared.isOnboarded = false
                 dismiss()
             }
             .foregroundColor(.red)
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: { dismiss() }) {
            Image(systemName: "xmark")
          }
          .accessibilityLabel("Close")
        }
      }
    }
  }
}

#Preview {
  SettingsView()
    .environmentObject(ThemeManager.shared)
}
