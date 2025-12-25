import SwiftUI
import Charts

struct SleepChartView: View {
    let chartData: [DailySleepData]
    let optimalSleepTime: Date?
    let optimalWakeTime: Date?

    var body: some View {
        let (minY, maxY) = SleepDataUtils.calculateYAxisDomain(
            data: chartData,
            optimalSleepTime: optimalSleepTime,
            optimalWakeTime: optimalWakeTime
        )

        Chart {
            // 1. Duration Line (Background)
            DurationChartContent(minY: minY, maxY: maxY)

            // 2. Sleep Bars & Optimal Lines (Foreground)
            SleepBarsContent(minY: minY, maxY: maxY)
        }
        // Invert Y-Axis so 18:00 is at Top
        // Domain: [-Max ... -Min] (Padded)
        .chartYScale(domain: -maxY...(-minY))
        .chartYAxis {
            // Right Axis: Time (Existing)
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                if let val = value.as(Double.self) {
                    let label = SleepDataUtils.formatTimeLabel(offset: -val)
                    AxisValueLabel(label)
                        .font(.system(size: 12))
                }
            }

            // Left Axis: Duration (0-12h)
            // We need to map 0, 4, 8, 12 hours to Chart Y values.
            // 0h -> -maxY (Bottom)
            // 12h -> -minY (Top)
            let top = -minY
            let bottom = -maxY
            let range = top - bottom
            let durationSteps = [0.0, 4.0, 8.0, 12.0]
            let mappedValues = durationSteps.map { bottom + ($0 / 12.0) * range }

            AxisMarks(position: .leading, values: mappedValues) { value in
                if let val = value.as(Double.self),
                   let index = mappedValues.firstIndex(of: val) {
                    let originalHour = durationSteps[index]
                    AxisValueLabel("\(Int(originalHour))h")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.gray)
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                if let day = value.as(String.self),
                   let data = chartData.first(where: { $0.dayLabel == day }) {
                    AxisValueLabel {
                        VStack(spacing: 2) {
                            Text(day)
                                .font(.system(size: 12, weight: .bold))
                            Text(SleepDataUtils.formatDurationShort(data.duration))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .frame(height: 300)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(radius: 5)
        .padding(.horizontal)
    }

    // MARK: - Sub-Components

    @ChartContentBuilder
    func DurationChartContent(minY: Double, maxY: Double) -> some ChartContent {
        // Optimal Duration Reference Line
        if let start = SleepDataUtils.calculateTimeOffset(for: optimalSleepTime),
           let end = SleepDataUtils.calculateTimeOffset(for: optimalWakeTime) {

            let calendar = Calendar.current
            let sDate = optimalSleepTime ?? Date()
            let wDate = optimalWakeTime ?? Date()
            let sHour = Double(calendar.component(.hour, from: sDate)) + Double(calendar.component(.minute, from: sDate))/60
            let wHour = Double(calendar.component(.hour, from: wDate)) + Double(calendar.component(.minute, from: wDate))/60

            let rawDiff = wHour - sHour
            let optimalDuration = rawDiff < 0 ? rawDiff + 24 : rawDiff

            let top = -minY
            let bottom = -maxY
            let range = top - bottom
            let normalizedY = bottom + (optimalDuration / 12.0) * range

            RuleMark(y: .value("Optimal Duration", normalizedY))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .foregroundStyle(.gray.opacity(0.5))
                .annotation(position: .leading) {
                    Text("\(String(format: "%.1f", optimalDuration))h")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
        }

        ForEach(chartData) { data in
            let durationHours = data.duration / 3600.0
            let top = -minY
            let bottom = -maxY
            let range = top - bottom
            let normalizedY = bottom + (durationHours / 12.0) * range

            LineMark(
                x: .value("Day", data.dayLabel),
                y: .value("Duration", normalizedY)
            )
            .foregroundStyle(.gray.opacity(0.3))
            .lineStyle(StrokeStyle(lineWidth: 3))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Day", data.dayLabel),
                y: .value("Duration", normalizedY)
            )
            .foregroundStyle(.gray)
            .symbolSize(30)
        }
    }

    @ChartContentBuilder
    func SleepBarsContent(minY: Double, maxY: Double) -> some ChartContent {
        // Optimal Sleep Time Line (Indigo)
        if let sleepOffset = SleepDataUtils.calculateTimeOffset(for: optimalSleepTime) {
            RuleMark(y: .value("Optimal Sleep", -sleepOffset))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundStyle(.indigo)
        }

        // Optimal Wake Time Line (Orange)
        if let wakeOffset = SleepDataUtils.calculateTimeOffset(for: optimalWakeTime) {
            RuleMark(y: .value("Optimal Wake", -wakeOffset))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundStyle(.orange)
        }

        ForEach(chartData) { data in
            BarMark(
                x: .value("Day", data.dayLabel),
                yStart: .value("Sleep Time", -data.startOffset),
                yEnd: .value("Wake Time", -data.endOffset),
                width: 25
            )
            .foregroundStyle(Color.cyan)
            .cornerRadius(4)
        }
    }
}
