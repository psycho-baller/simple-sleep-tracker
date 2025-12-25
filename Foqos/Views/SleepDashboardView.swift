import SwiftData
import SwiftUI

struct SleepDashboardView: View {
    @ObservedObject var sleepSettings = SleepSettings.shared
    @Environment(\.modelContext) private var context
    @EnvironmentObject var strategyManager: StrategyManager

    // Fetch generic sleep profile to display stats
    @Query private var profiles: [BlockedProfiles]
    @Query(sort: \BlockedProfileSession.startTime, order: .reverse) private
        var sessions: [BlockedProfileSession]

    @State private var viewMode: ViewMode = .week
    @State private var showingSettings = false
    @State private var showingLogs = false
    @State private var chartData: [DailySleepData] = []

    enum ViewMode: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"

        var id: String { self.rawValue }
    }

    var sleepProfile: BlockedProfiles? {
        if let id = sleepSettings.sleepProfileId {
            return profiles.first(where: { $0.id == id })
        }
        return nil
    }

    var lastSleepSession: BlockedProfileSession? {
        return sessions.first(where: {
            $0.blockedProfile.id == sleepSettings.sleepProfileId
                && $0.endTime != nil
        })
    }

    var isSleeping: Bool {
        guard let active = strategyManager.activeSession?.blockedProfile.id,
              let current = sleepProfile?.id else { return false }
        return active == current
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text(isSleeping ? "Good Night 🌙" : "Good Morning ☀️")
                                .font(.largeTitle)
                                .bold()
                            Text(Date(), style: .date)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()

                        Button(action: { showingLogs = true }) {
                                Image(systemName: "list.bullet.clipboard")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                        }
                        .padding(.trailing, 8)

                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)

                    // History Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("History")
                                .font(.title2)
                                .bold()
                            Spacer()
                            Picker("View Mode", selection: $viewMode) {
                                ForEach(ViewMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 150)
                        }
                        .padding(.horizontal)

                        // Statistics Section (Average, Sleep Cons., Wake Cons., Accuracy)
                        // Statistics Section (Average, Sleep Cons., Wake Cons., Accuracy)
                         HStack(spacing: 8) {
                                // 1. Average Sleep
                                let avgString = SleepDataUtils.formatAvgDuration(
                                    SleepDataUtils.calculateAverageDuration(for: chartData)
                                )
                                StatView(
                                    title: "AVG. SLEEP",
                                    value: "\(avgString.hours)h \(avgString.minutes)m")
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // 2. Sleep Consistency
                                let sleepCons = SleepDataUtils.calculateSleepConsistency(data: chartData)
                                StatView(title: "SLEEP CONS.", value: "\(sleepCons)%")
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // 3. Wake Consistency
                                let wakeCons = SleepDataUtils.calculateWakeConsistency(data: chartData)
                                StatView(title: "WAKE CONS.", value: "\(wakeCons)%")
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // 4. Accuracy
                                let accuracy = SleepDataUtils.calculateAccuracy(
                                    data: chartData,
                                    optimalSleepTime: sleepSettings.optimalSleepTime,
                                    optimalWakeTime: sleepSettings.optimalWakeTime
                                )
                                StatView(title: "ACCURACY", value: "\(accuracy)%")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal)

                        if viewMode == .week {
                            // Separated Chart Component
                            SleepChartView(
                                chartData: chartData,
                                optimalSleepTime: sleepSettings.optimalSleepTime,
                                optimalWakeTime: sleepSettings.optimalWakeTime
                            )
                            .onAppear {
                                #if DEBUG
                                if chartData.isEmpty {
                                    // chartData = SleepDataUtils.generateMockData()
                                }
                                #endif
                            }

                        } else {
                            // Month / Calendar View
                            // Reuse existing blocked sessions habit tracker
                            BlockedSessionsHabitTracker(
                                sessions: sessions.filter {
                                    // Filter only for sleep profile sessions if possible, or all sessions
                                    $0.blockedProfile.id
                                        == sleepSettings.sleepProfileId
                                }
                            )
                            .padding(.horizontal)
                        }
                    }

                    // Status Card (Sleep/Wake Actions)
                    VStack(spacing: 20) {
                        if isSleeping {
                            Text("You are currently sleeping")
                                .font(.headline)
                            Text("Enjoy your rest!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Button(action: {
                                // Stop Sleeping
                                if let profile = sleepProfile {
                                    strategyManager.toggleBlocking(
                                        context: context,
                                        activeProfile: profile
                                    )
                                }
                            }) {
                                Text("Wake Up")
                                    .font(.title3)
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(15)
                            }
                        } else {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Last Night's Sleep")
                                        .font(.headline)
                                    if let session = lastSleepSession {
                                        Text(
                                            "\(SleepDataUtils.formatDuration(session.duration))"
                                        )
                                        .font(.system(size: 34, weight: .bold))
                                    } else {
                                        Text("-- h -- m")
                                            .font(
                                                .system(size: 34, weight: .bold)
                                            )
                                    }
                                }
                                Spacer()
                            }

                            Button(action: {
                                // Start Sleeping
                                if let profile = sleepProfile {
                                    strategyManager.toggleBlocking(
                                        context: context,
                                        activeProfile: profile
                                    )
                                }
                            }) {
                                Text("Go to Sleep")
                                    .font(.title3)
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.indigo)
                                    .foregroundColor(.white)
                                    .cornerRadius(15)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .shadow(radius: 5)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(isPresented: $showingSettings) {
                if let profile = sleepProfile {
                    BlockedProfileView(profile: profile)
                } else {
                    Text("Error: No Sleep Profile Found")
                }
            }
            .sheet(isPresented: $showingLogs) {
                if let profile = sleepProfile {
                    SleepLogsView(profile: profile)
                }
            }
        }
    }
}



struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold)) // Smaller title
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 20, weight: .semibold)) // Slightly smaller value
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5) // Allow shrinking
        }
    }
}
