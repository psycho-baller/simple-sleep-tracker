import Foundation
import SwiftData

// MARK: - Data Models
struct DailySleepData: Identifiable {
    let id = UUID()
    let dayLabel: String
    let date: Date
    let startOffset: Double  // Hours from base time (e.g. 18:00)
    let endOffset: Double  // Hours from base time
    let duration: TimeInterval
}

// MARK: - Sleep Data Utilities
struct SleepDataUtils {
    static let baseHour = 18.0

    // MARK: - Data Generation
    static func generateMockData() -> [DailySleepData] {
        // Generate last 7 days including today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var data: [DailySleepData] = []

        // Populate with mockup data for visualization if no sessions
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -6 + i, to: today)!
            let weekday = calendar.component(.weekday, from: date)
            let dayLabel = calendar.shortWeekdaySymbols[weekday - 1]

            // Hacky mockup logic to demonstrate visualization:
            let sleepHour = Double.random(in: 22...25)  // 22(10pm) to 25(1am next day)
            let wakeHour = Double.random(in: 6...9)  // 6am to 9am

            // Convert chart hours relative to base 18:00
            let startOffset = sleepHour - baseHour
            let endOffset = (wakeHour + 24) - baseHour

            let duration = (endOffset - startOffset) * 3600

            data.append(
                DailySleepData(
                    dayLabel: dayLabel,
                    date: date,
                    startOffset: startOffset,
                    endOffset: endOffset,
                    duration: duration
                ))
        }

        return data
    }

    // MARK: - Calculations
    static func calculateYAxisDomain(data: [DailySleepData], optimalSleepTime: Date?, optimalWakeTime: Date?) -> (Double, Double) {
        let startOffsets = data.map { $0.startOffset }
        let endOffsets = data.map { $0.endOffset }

        // Also consider optimal times
        var allValues = startOffsets + endOffsets
        if let optimalSleep = calculateTimeOffset(for: optimalSleepTime) {
            allValues.append(optimalSleep)
        }
        if let optimalWake = calculateTimeOffset(for: optimalWakeTime) {
            allValues.append(optimalWake)
        }

        let minVal = allValues.min() ?? 0
        let maxVal = allValues.max() ?? 24

        // Tight padding (minVal, maxVal)
        return (minVal, maxVal)
    }

    static func calculateTimeOffset(for date: Date?) -> Double? {
        guard let date = date else { return nil }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        let doubleHour = Double(hour) + Double(minute) / 60.0

        var adjustedHour = doubleHour
        if adjustedHour < baseHour {
            adjustedHour += 24
        }

        return adjustedHour - baseHour
    }

    static func calculateAverageDuration(for data: [DailySleepData]) -> TimeInterval {
        // Use mock logic or real average
        // For now, returning fixed mock as per original code
        return 8 * 3600 + 15 * 60  // 8h 15m
    }

    // MARK: - Scoring Logic
    static func calculateConsistency(data: [DailySleepData]) -> Int {
        // Keep generic implementation for backward compatibility if needed,
        // or repurpose as average of the two?
        // Let's just return average of sleep and wake consistency
        let sleep = calculateSleepConsistency(data: data)
        let wake = calculateWakeConsistency(data: data)
        return (sleep + wake) / 2
    }

    static func calculateSleepConsistency(data: [DailySleepData]) -> Int {
        return calculateConsistencyFor(values: data.map { $0.startOffset })
    }

    static func calculateWakeConsistency(data: [DailySleepData]) -> Int {
        return calculateConsistencyFor(values: data.map { $0.endOffset })
    }

    private static func calculateConsistencyFor(values: [Double]) -> Int {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2.0) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance) // in hours directly

        // Let's say -20 points per hour of deviation?
        let deduction = Int(stdDev * 20)
        return max(0, 100 - deduction)
    }

    static func calculateAccuracy(data: [DailySleepData], optimalSleepTime: Date?, optimalWakeTime: Date?) -> Int {
        // Accuracy relative to sleepSettings.optimalSleepTime and optimalWakeTime
        guard !data.isEmpty,
              let targetSleep = calculateTimeOffset(for: optimalSleepTime),
              let targetWake = calculateTimeOffset(for: optimalWakeTime) else {
            return 0
        }

        var totalDeviation: Double = 0

        for day in data {
            let startDev = abs(day.startOffset - targetSleep)
            let endDev = abs(day.endOffset - targetWake)
            totalDeviation += (startDev + endDev)
        }

        let avgDeviation = totalDeviation / Double(data.count * 2) // Avg per event (sleep or wake)

        // Deduction: 1 hour off = 10 points?
        let deduction = Int(avgDeviation * 10)
        return max(0, 100 - deduction)
    }

    // MARK: - Formatters
    static func formatAvgDuration(_ duration: TimeInterval) -> (hours: String, minutes: String) {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return ("\(hours)", "\(minutes)")
    }

    static func formatTimeLabel(offset: Double) -> String {
        // offset 0 = 6 PM, 18 = 12 PM
        var hour = Int(baseHour + offset)
        if hour >= 24 { hour -= 24 }

        let ampm = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour) \(ampm)"
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }

    static func formatDurationShort(_ duration: TimeInterval) -> String {
        let hours = Double(duration) / 3600.0
        return String(format: "%.1f", hours)
    }
}
