import FamilyControls
import SwiftData
import SwiftUI

struct HomeView: View {
  @Environment(\.modelContext) private var context
  @EnvironmentObject var requestAuthorizer: RequestAuthorizer
  @EnvironmentObject var strategyManager: StrategyManager

  @ObservedObject var sleepSettings = SleepSettings.shared

  var body: some View {
      Group {
          if !sleepSettings.isOnboarded {
              SleepOnboardingView()
          } else {
              SleepDashboardView()
          }
      }
      .onAppear {
          // Ensure strategy manager is loaded
          strategyManager.loadActiveSession(context: context)
      }
      // Keep required environment injections and overlay logic from original HomeView if any needed
      // but for "Simple Sleep Tracker" we simplify drastically.
      // We do need to handle the StrategyManager error alerts though.
      .onReceive(strategyManager.$errorMessage) { errorMessage in
        // In a real app we'd show alert here
          print("Error: \(errorMessage ?? "")")
      }
  }
}

#Preview {
  HomeView()
    .environmentObject(RequestAuthorizer())
    .environmentObject(StrategyManager())
}
