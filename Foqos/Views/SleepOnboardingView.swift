import FamilyControls
import SwiftData
import SwiftUI
import UserNotifications

struct SleepOnboardingView: View {
    @ObservedObject var sleepSettings = SleepSettings.shared
    @EnvironmentObject var requestAuthorizer: RequestAuthorizer
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) var dismiss

    @State private var step = 1
    @State private var selection = FamilyActivitySelection()
    @State private var scannedSleepTag: String? = nil
    @State private var scannedWakeTag: String? = nil

    // Notification Permission State
    @State private var notificationsAuthorized = false

    // For NFC scanning
    @StateObject private var nfcScanner = NFCScannerUtil()
    @State private var isScanningSleep = false
    @State private var isScanningWake = false

    var body: some View {
        VStack {
            if step == 1 {
                WelcomeStep(onNext: { withAnimation { step += 1 } })
            } else if step == 2 {
                SleepScheduleStep(
                    sleepTime: $sleepSettings.optimalSleepTime,
                    wakeTime: $sleepSettings.optimalWakeTime,
                    onNext: { withAnimation { step += 1 } }
                )
            } else if step == 3 {
                AppBlockingInfoStep(
                    selection: $selection,
                    isAuthorized: requestAuthorizer.isAuthorized,
                    onRequestAuthorization: { requestAuthorizer.requestAuthorization() },
                    onNext: { withAnimation { step += 1 } }
                )
            } else if step == 4 {
                NotificationPermissionStep(
                    isAuthorized: notificationsAuthorized,
                    onRequestPermission: requestNotificationPermission,
                    onNext: { withAnimation { step += 1 } }
                )
            } else if step == 5 {
                NFCSetupStep(
                    scannedSleepTag: scannedSleepTag,
                    scannedWakeTag: scannedWakeTag,
                    onScanSleep: {
                        isScanningSleep = true
                        nfcScanner.scan(profileName: "Sleep Tag")
                    },
                    onScanWake: {
                        isScanningWake = true
                        nfcScanner.scan(profileName: "Wake Tag")
                    },
                    onUseSameTag: {
                        scannedWakeTag = scannedSleepTag
                    },
                    onFinish: { finishOnboarding(useNFC: true) },
                    onSkip: { finishOnboarding(useNFC: false) }
                )
            }
        }
        .padding()
        .onAppear {
            setupNFC()
            checkNotificationStatus()
        }
    }

    func setupNFC() {
        nfcScanner.onTagScanned = { tag in
            let tagId = tag.url ?? tag.id
            if isScanningSleep {
                scannedSleepTag = tagId
                isScanningSleep = false
            } else if isScanningWake {
                scannedWakeTag = tagId
                isScanningWake = false
            }
        }
    }

    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                notificationsAuthorized = granted
                if granted {
                    // Automatically move to next step if granted? Or let user click Next.
                    // Let's just update state so UI reflects it.
                }
            }
        }
    }

    func finishOnboarding(useNFC: Bool) {
        // Create Profile
        do {
            let strategyId = useNFC ? NFCBlockingStrategy.id : ManualBlockingStrategy.id

            let profile = try BlockedProfiles.createProfile(
                in: context,
                name: "Sleep",
                selection: selection,
                blockingStrategyId: strategyId,
                physicalUnblockNFCTagId: useNFC ? scannedWakeTag : nil
            )

            // Save settings
            SleepSettings.shared.sleepProfileId = profile.id
            SleepSettings.shared.isOnboarded = true

        } catch {
            print("Error creating sleep profile: \(error)")
        }
    }
}

// MARK: - Step 1: Welcome
struct WelcomeStep: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 80))
                .foregroundColor(.indigo)

            Text("Welcome to Foqos Sleep")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)

            Text("Regain control of your rest. Foqos helps you disconnect from distractions and build healthy sleep habits.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()

            Button(action: onNext) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
        }
    }
}

// MARK: - Step 2: Sleep Schedule
struct SleepScheduleStep: View {
    @Binding var sleepTime: Date
    @Binding var wakeTime: Date
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("Your Sleep Schedule")
                .font(.title)
                .bold()

            Text("Set your ideal sleep and wake times. You can always change this later in settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Label("Bedtime", systemImage: "moon.fill")
                            .foregroundColor(.indigo)
                            .font(.headline)
                        DatePicker("Bedtime", selection: $sleepTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Label("Wake Up", systemImage: "sun.max.fill")
                            .foregroundColor(.orange)
                            .font(.headline)
                        DatePicker("Wake Up", selection: $wakeTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)

                let durationString = durationString(from: sleepTime, to: wakeTime)

                HStack {
                     Image(systemName: "clock")
                     Text("Sleep Goal: \(durationString)")
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
            .padding()

            Spacer()

            Button(action: onNext) {
                HStack {
                    Text("Set Schedule")
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(15)
            }
        }
    }

    private func durationString(from start: Date, to end: Date) -> String {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        var diffMinutes = endMinutes - startMinutes
        if diffMinutes < 0 { diffMinutes += 24 * 60 }
        let hours = diffMinutes / 60
        let minutes = diffMinutes % 60
        return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes) min"
    }
}

// MARK: - Step 3: App Blocking
struct AppBlockingInfoStep: View {
    @Binding var selection: FamilyActivitySelection
    var isAuthorized: Bool
    var onRequestAuthorization: () -> Void
    var onNext: () -> Void

    // Internal state to track if we should show the picker
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Block Distractions")
                .font(.title)
                .bold()

            Text("Select apps that keep you awake. We'll block them during your sleep schedule.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(spacing: 15) {
                if !isAuthorized {
                    Button(action: onRequestAuthorization) {
                        HStack {
                            Image(systemName: "lock.shield")
                            Text("Authorize Screen Time")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }

                Button(action: { showPicker = true }) {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                        Text("Select Apps to Block")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .familyActivityPicker(isPresented: $showPicker, selection: $selection)
            }

            Spacer()

            Button(action: onNext) {
                Text(selection.categoryTokens.isEmpty && selection.applicationTokens.isEmpty && selection.webDomainTokens.isEmpty ? "Skip" : "Next")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
        }
    }
}

// MARK: - Step 4: Notification Permission
struct NotificationPermissionStep: View {
    var isAuthorized: Bool
    var onRequestPermission: () -> Void
    var onNext: () -> Void

    // Dark theme colors
    private let bgGradient = LinearGradient(
        colors: [Color(red: 0.05, green: 0.07, blue: 0.15), Color(red: 0.1, green: 0.11, blue: 0.2)],
        startPoint: .top,
        endPoint: .bottom
    )
    private let cardBg = Color(red: 0.15, green: 0.16, blue: 0.24)
    private let buttonBlue = Color(red: 0.15, green: 0.35, blue: 0.95)

    var body: some View {
        ZStack {
            // Background
            bgGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                // Notification Preview Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text("SLEEP TRACKER")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)

                        Spacer()

                        Text("Now")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Text("Time to wind down 🌙")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Your 8-hour sleep goal is within reach. Start your routine now to wake up refreshed.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(cardBg.opacity(0.6))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal)

                VStack(spacing: 8) {
                    Text("Don't miss your sleep window")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Consistency is key to better rest. Enable notifications so we can gently remind you when it's time to rest.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 10)

                // Feature List
                VStack(spacing: 12) {
                    featureRow(icon: "bell.fill", color: .indigo, title: "Bedtime nudges", subtitle: "Gentle reminders to start your routine.")
                    featureRow(icon: "alarm.fill", color: .indigo, title: "Smart wake-up", subtitle: "Alarms that wake you at the lightest stage.")
                    featureRow(icon: "chart.bar.fill", color: .indigo, title: "Weekly insights", subtitle: "Summaries of your sleep debt and quality.")
                }
                .padding(.horizontal)

                Spacer()

                // Actions
                VStack(spacing: 16) {
                    Button(action: {
                        if isAuthorized {
                            onNext()
                        } else {
                            onRequestPermission()
                        }
                    }) {
                        HStack {
                            if isAuthorized {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Notifications Enabled")
                            } else {
                                Text("Turn on Notifications")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isAuthorized ? Color.green : buttonBlue)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                    }

                    if !isAuthorized {
                        Button("Maybe later") {
                            onNext()
                        }
                        .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        // Force dark mode for this view to ensure text contrast
        .preferredColorScheme(.dark)
        // Attempt to break out of parent padding if possible, though 'padding()' in parent is restrictive.
        // We add negative padding to compensate for the parent's default padding if we assume standard 16pt.
        .padding(-16)
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.35))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .foregroundColor(Color.blue.opacity(0.8))
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(cardBg.opacity(0.4))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Step 5: NFC Setup
struct NFCSetupStep: View {
    var scannedSleepTag: String?
    var scannedWakeTag: String?
    var onScanSleep: () -> Void
    var onScanWake: () -> Void
    var onUseSameTag: () -> Void
    var onFinish: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 25) {
            Text("Setup NFC Tags")
                .font(.title)
                .bold()

            Text("Control your sleep mode instantly with NFC tags. Scan one tag to sleep, and another to wake up. Or skip to use manual controls.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(spacing: 15) {
                // Sleep Tag Button
                Button(action: onScanSleep) {
                    HStack {
                        Image(systemName: "moon.fill")
                        Text(scannedSleepTag != nil ? "Sleep Tag Scanned!" : "Scan Sleep Tag")
                        if scannedSleepTag != nil {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(scannedSleepTag != nil ? Color.green : Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                if scannedSleepTag != nil {
                    // Wake Tag Button
                    Button(action: onScanWake) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                            Text(scannedWakeTag != nil ? "Wake Tag Scanned!" : "Scan Wake Tag")
                            if scannedWakeTag != nil {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(scannedWakeTag != nil ? Color.green : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    Button("Use Same Tag for Wake") {
                        onUseSameTag()
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .disabled(scannedWakeTag != nil)
                }
            }
            .padding(.horizontal)

            Spacer()

            if scannedSleepTag != nil && scannedWakeTag != nil {
                Button(action: onFinish) {
                    Text("Finish Setup")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
            } else {
                Button(action: onSkip) {
                    Text("Skip & Use Manual Controls")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }
        }
    }
}
