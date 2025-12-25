import Foundation
import SwiftData

final class SleepSettings: ObservableObject {
    static let shared = SleepSettings()

    private let kOptimalSleepTime = "optimalSleepTime"
    private let kOptimalWakeTime = "optimalWakeTime"
    private let kSleepProfileId = "sleepProfileId"
    private let kIsOnboarded = "isOnboarded"

    @Published var isOnboarded: Bool {
        didSet {
            UserDefaults.standard.set(isOnboarded, forKey: kIsOnboarded)
        }
    }

    var optimalSleepTime: Date {
        get {
            guard let data = UserDefaults.standard.object(forKey: kOptimalSleepTime) as? Date else {
                return Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
            }
            return data
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kOptimalSleepTime)
        }
    }

    var optimalWakeTime: Date {
        get {
            guard let data = UserDefaults.standard.object(forKey: kOptimalWakeTime) as? Date else {
                return Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
            }
            return data
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kOptimalWakeTime)
        }
    }

    var sleepProfileId: UUID? {
        get {
            guard let str = UserDefaults.standard.string(forKey: kSleepProfileId) else { return nil }
            return UUID(uuidString: str)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: kSleepProfileId)
        }
    }

    private init() {
        self.isOnboarded = UserDefaults.standard.bool(forKey: kIsOnboarded)
    }
}
