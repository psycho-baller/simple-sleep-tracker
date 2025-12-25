import SwiftData
import SwiftUI

struct SleepLogsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    // We filter by the active sleep profile
    var profile: BlockedProfiles
    
    // Sort by start time descending
    @Query(sort: \BlockedProfileSession.startTime, order: .reverse)
    private var allSessions: [BlockedProfileSession]
    
    // Filtered list
    var sessions: [BlockedProfileSession] {
        allSessions.filter { $0.blockedProfile.id == profile.id && $0.endTime != nil }
    }
    
    @State private var sessionToEdit: BlockedProfileSession?
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    Button(action: { sessionToEdit = session }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.startTime, format: .dateTime.weekday().day().month())
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 4) {
                                    Text(session.startTime, style: .time)
                                    Text("→")
                                    if let end = session.endTime {
                                        Text(end, style: .time)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if let end = session.endTime {
                                let duration = end.timeIntervalSince(session.startTime)
                                Text(formatDuration(duration))
                                    .font(.body)
                                    .monospacedDigit()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            delete(session)
                        }
                    }
                }
            }
            .navigationTitle("Sleep Logs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $sessionToEdit) { session in
                SleepSessionEditorView(session: session, profile: profile)
            }
            .sheet(isPresented: $showingAddSheet) {
                SleepSessionEditorView(session: nil, profile: profile)
            }
        }
        // Force the list background to be standard group
    }
    
    private func delete(_ session: BlockedProfileSession) {
        context.delete(session)
        try? context.save()
    }
    
    func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return "\(h)h \(m)m"
    }
}
