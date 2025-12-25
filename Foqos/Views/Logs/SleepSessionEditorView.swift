import SwiftUI
import SwiftData

struct SleepSessionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // If nil, we are creating a new one
    var existingSession: BlockedProfileSession?
    var profile: BlockedProfiles

    @State private var sleepDate: Date
    @State private var wakeDate: Date

    // We maintain a "Base Date" for the session start day
    @State private var sessionDay: Date

    init(session: BlockedProfileSession?, profile: BlockedProfiles) {
        self.existingSession = session
        self.profile = profile

        if let session = session {
            _sleepDate = State(initialValue: session.startTime)
            _wakeDate = State(initialValue: session.endTime ?? Date())
            _sessionDay = State(initialValue: session.startTime)
        } else {
            // Default to optimal schedule relative to "last night"
            let now = Date()
            let calendar = Calendar.current

            // Reference day is usually "yesterday" for the start of sleep
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            let today = now

            // Fetch optimal settings
            let settings = SleepSettings.shared

            // Extract components from optimal settings (stored as dates on 2000-01-01 usually)
            // If they are nil, fallback to 22:00 / 07:00
            var startComponents = DateComponents(hour: 22, minute: 0)
            var endComponents = DateComponents(hour: 7, minute: 0)

            // Support both optional and non-optional properties without optional binding errors
            let optSleepDate: Date? = {
                // If these properties are optional, use them directly; if not, wrap into optional
                // We attempt to access and treat as optional via a closure to avoid compile-time errors
                return (SleepSettings.shared.optimalSleepTime as Date?)
            }()
            let optWakeDate: Date? = {
                return (SleepSettings.shared.optimalWakeTime as Date?)
            }()

            if let optSleep = optSleepDate {
                startComponents = calendar.dateComponents([.hour, .minute], from: optSleep)
            }
            if let optWake = optWakeDate {
                endComponents = calendar.dateComponents([.hour, .minute], from: optWake)
            }

            // Apply to yesterday/today
            // Start time is on "yesterday" date
            let start = calendar.date(bySettingHour: startComponents.hour!, minute: startComponents.minute!, second: 0, of: yesterday) ?? now

            // End time is on "today" date (usually)
            // But if end hour > start hour (nap?), it might be same day.
            // Standard sleep is overnight.
            let end = calendar.date(bySettingHour: endComponents.hour!, minute: endComponents.minute!, second: 0, of: today) ?? now

            _sleepDate = State(initialValue: start)
            _wakeDate = State(initialValue: end)
            _sessionDay = State(initialValue: start)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Date Picker (The "Day" of the sleep)
                    DatePicker("Date", selection: $sessionDay, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(15)
                        .padding(.horizontal)
                        .onChange(of: sessionDay) { _, newDay in
                           updateDatesRequestingNewDay(newDay)
                        }

                    // Circular Editor
                    VStack {
                        Text("Edit Schedule")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading)

                        // Pass bindings that update the internal dates
                        // We need to ensure that if the user drags "wake" past sleep, it might handle day change logic?
                        // For simplicity, CircularPicker just updates Time components.
                        // We handle "Next Day" logic by comparing angles or time.
                        CircularTimePickerBetter(
                            sleepTime: $sleepDate,
                            wakeTime: $wakeDate,
                            size: 260
                        )
                        .padding(.vertical, 20)
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(15)
                    .padding(.horizontal)

                    // Numeric Display (Detail)
                    HStack {
                        VStack {
                            Label("Bedtime", systemImage: "bed.double.fill")
                                .foregroundColor(.indigo)
                                .font(.caption)
                            Text(sleepDate, style: .time)
                                .font(.title3)
                                .bold()
                            Text(sleepDate, format: .dateTime.weekday().day().month())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        Divider()

                        VStack {
                            Label("Wake Up", systemImage: "alarm.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(wakeDate, style: .time)
                                .font(.title3)
                                .bold()
                            // If wake date is < sleep date, it means next day?
                            // Or rather, checking if it's different day
                            Text(wakeDate, format: .dateTime.weekday().day().month())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(existingSession == nil ? "Log Sleep" : "Edit Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                }
            }
        }
    }

    // Propagate day change to the Start/End times
    func updateDatesRequestingNewDay(_ newDay: Date) {
        let cal = Calendar.current

        // Extract time from current sleepDate
        let sleepComps = cal.dateComponents([.hour, .minute], from: sleepDate)
        // Combine newDay + sleepTime
        if let newSleep = cal.date(bySettingHour: sleepComps.hour!, minute: sleepComps.minute!, second: 0, of: newDay) {
            sleepDate = newSleep
        }

        // Handling Wake Date is tricky. Assuming wake is usually after sleep.
        // If current wake is next day, keep it next day relative to new day.
        let duration = wakeDate.timeIntervalSince(sleepDate)
        wakeDate = sleepDate.addingTimeInterval(duration)
    }

    func save() {
        // Ensure wake is after sleep logic?
        // With Circular picker 0-24h, we have explicit dates.
        // But what if user sets Sleep 23:00 and Wake 07:00?
        // The picker sets them on the *same day* usually or we need to detect crossover.

        // Let's refine the specific date logic.
        // If wake time (components) < sleep time (components), assume wake is next day.
        let cal = Calendar.current
        let sleepH = cal.component(.hour, from: sleepDate)
        let wakeH = cal.component(.hour, from: wakeDate)
        let wakeM = cal.component(.minute, from: wakeDate)
        let sleepM = cal.component(.minute, from: sleepDate)

        // Comparison by minute of day
        let sleepMins = sleepH * 60 + sleepM
        let wakeMins = wakeH * 60 + wakeM

        // If wake is "earlier" in the day than sleep, it must be the next day
        if wakeMins < sleepMins {
             // Wake date should be sleep date's day + 1 + wake time
            if let nextDay = cal.date(byAdding: .day, value: 1, to: sleepDate),
               let adjustedWake = cal.date(bySettingHour: wakeH, minute: wakeM, second: 0, of: nextDay) {
                wakeDate = adjustedWake
            }
        } else {
             // Same day
            if let sameDayWake = cal.date(bySettingHour: wakeH, minute: wakeM, second: 0, of: sleepDate) {
                wakeDate = sameDayWake
            }
        }

        if let session = existingSession {
            session.startTime = sleepDate
            session.endTime = wakeDate
            // Tag?
        } else {
            let session = BlockedProfileSession(
                tag: "Manual Log",
                blockedProfile: profile
            )
            session.startTime = sleepDate
            session.endTime = wakeDate
            modelContext.insert(session)
        }

        try? modelContext.save()
        dismiss()
    }
}
