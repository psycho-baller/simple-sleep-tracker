import SwiftUI

// MARK: - Improved Circular Time Picker
struct CircularTimePickerBetter: View {
    @Binding var sleepTime: Date
    @Binding var wakeTime: Date
    var size: CGFloat = 260

    // Internal state for angles (0-360) where 0 is 12 o'clock
    @State private var sleepAngle: Double = 0
    @State private var wakeAngle: Double = 0

    // Gesture State
    @State private var isDraggingSleep = false
    @State private var isDraggingWake = false

    // Haptics
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                // 1. Clock Face / Ticks
                ClockFace(size: size)

                // 2. Active Arc (The duration line)
                // We use trim. 0 is 3 o'clock in SwiftUI.
                // Our angles: 0 is 12 o'clock.
                // SwiftUI Circle starts at 3 o'clock (Right). Rotating -90 brings start to 12 o'clock.
                // Normalizing angles to 0-1 for trim.
                Group {
                    if endFraction > 1.0 {
                        // Crosses midnight: Draw two arcs
                        // Arc 1: Start to 1.0 (Midnight)
                        Circle()
                            .trim(from: sleepAngle / 360, to: 1.0)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [Color.indigo, Color.purple, Color.orange]),
                                    center: .center,
                                    startAngle: .degrees(sleepAngle - 90),
                                    endAngle: .degrees(wakeAngle - 90 + 360)
                                ),
                                style: StrokeStyle(lineWidth: 35, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        // Arc 2: 0.0 to End
                        Circle()
                            .trim(from: 0.0, to: endFraction - 1.0)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [Color.indigo, Color.purple, Color.orange]),
                                    center: .center,
                                    startAngle: .degrees(sleepAngle - 90),
                                    endAngle: .degrees(wakeAngle - 90 + 360)
                                ),
                                style: StrokeStyle(lineWidth: 35, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    } else {
                        // Normal case
                        Circle()
                            .trim(from: sleepAngle / 360, to: endFraction)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [Color.indigo, Color.purple, Color.orange]),
                                    center: .center,
                                    startAngle: .degrees(sleepAngle - 90),
                                    endAngle: .degrees(wakeAngle - 90)
                                ),
                                style: StrokeStyle(lineWidth: 35, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                }
                .frame(width: size, height: size)
                // Add a shadow to the arc for depth
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                // 3. Sleep Knob (Bed)
                KnobView(icon: "bed.double.fill", color: .indigo)
                    .position(
                        x: center.x + (size/2) * sin(CGFloat.pi * 2 * sleepAngle / 360),
                        y: center.y - (size/2) * cos(CGFloat.pi * 2 * sleepAngle / 360)
                    )
                    // Hit testing needs to be large enough
                    .scaleEffect(isDraggingSleep ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: isDraggingSleep)

                // 4. Wake Knob (Alarm)
                KnobView(icon: "alarm.fill", color: .orange)
                    .position(
                        x: center.x + (size/2) * sin(CGFloat.pi * 2 * wakeAngle / 360),
                        y: center.y - (size/2) * cos(CGFloat.pi * 2 * wakeAngle / 360)
                    )
                    .scaleEffect(isDraggingWake ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: isDraggingWake)

                // 5. Center Info
                VStack(spacing: 5) {
                    let diff = activeDuration
                    Text(formatDuration(diff))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)

                    Text("Time Asleep")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            // 6. Global Gesture Handler
            // We put a transparent layer on top to catch all touches
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(value: value, center: center)
                    }
                    .onEnded { _ in
                        isDraggingSleep = false
                        isDraggingWake = false
                        impactMedium.impactOccurred()
                    }
            )
            .onAppear {
                setAnglesFromDates()
            }
            .onChange(of: sleepTime) { _, _ in setAnglesFromDates() }
            .onChange(of: wakeTime) { _, _ in setAnglesFromDates() }
        }
        .frame(width: size + 60, height: size + 60) // Add padding for knobs
    }

    // MARK: - Helpers

    var endFraction: CGFloat {
        let start = sleepAngle / 360
        var end = wakeAngle / 360
        if end < start { end += 1.0 }
        return end
    }

    var activeDuration: TimeInterval {
        var diff = wakeAngle - sleepAngle
        if diff < 0 { diff += 360 }
        return (diff / 360) * 86400 // 24 hours in seconds
    }

    func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return "\(h)h \(m)m"
    }

    // MARK: - Subviews

    struct ClockFace: View {
        let size: CGFloat
        var body: some View {
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 35)
                    .frame(width: size, height: size)

                // Numbers
                ForEach(0..<4) { i in
                    VStack {
                        Text("\(i * 6 == 0 ? 24 : i * 6)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .offset(y: -(size/2 + 40))
                    .rotationEffect(.degrees(Double(i) * 90))
                }

                // Little ticks between numbers?
                ForEach(0..<24) { i in
                   Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 2, height: i % 6 == 0 ? 0 : 8) // Skip main numbers
                        .offset(y: -(size/2 + 25))
                        .rotationEffect(.degrees(Double(i) * 15))
                }
            }
        }
    }

    struct KnobView: View {
        let icon: String
        let color: Color

        var body: some View {
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemBackground))
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 20, weight: .bold))
            }
        }
    }

    // MARK: - Logic

    func dateToAngle(_ date: Date) -> Double {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let totalMins = Double(comps.hour ?? 0) * 60 + Double(comps.minute ?? 0)
        return (totalMins / (24 * 60)) * 360
    }

    func setAnglesFromDates() {
        // Prevent feedback loop during dragging
        if !isDraggingSleep { sleepAngle = dateToAngle(sleepTime) }
        if !isDraggingWake { wakeAngle = dateToAngle(wakeTime) }
    }

    func handleDrag(value: DragGesture.Value, center: CGPoint) {
        let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
        // atan2: Right=0, Down=90, Left=180, Top=-90.
        // We convert to degrees and adjust so Top=0 (12 o'clock).
        let angleRad = atan2(vector.dy, vector.dx)
        var angleDeg = angleRad * 180 / .pi + 90
        if angleDeg < 0 { angleDeg += 360 }

        // Detect which knob to move on start of drag
        // We use the startLocation to determine this only once per gesture ideally,
        // but onChanged comes repeatedly. We check state flags.
        if !isDraggingSleep && !isDraggingWake {
            // Determine distance to current knobs angles
            let sleepDist = abs(angleDifference(angle1: angleDeg, angle2: sleepAngle))
            let wakeDist = abs(angleDifference(angle1: angleDeg, angle2: wakeAngle))

            // Threshold for grabbing (e.g., 30 degrees arc)
            let threshold: Double = 30

            if sleepDist < threshold && sleepDist < wakeDist {
                isDraggingSleep = true
                impactLight.impactOccurred()
            } else if wakeDist < threshold {
                isDraggingWake = true
                impactLight.impactOccurred()
            } else {
                // Maybe dragging the arc itself? Complex implementation.
                // Let's stick to knobs for now for robustness.
                return
            }
        }

        // Apply update
        // Snap to 5 minutes (360 degrees / 24h / 12 = 30 degrees per hour / 12 = 2.5 degrees per 10 min?)
        // 24h = 1440m. 360 deg. 1m = 0.25 deg. 5m = 1.25 deg.
        // Let's snap to closest 1.25 degrees
        let snapInterval = 1.25 * 3 // 15 minutes snap for distinct feel? Or 5?
        // Let's go with 5 mins = 1.25 deg
        let snapDeg = 1.25

        let snappedAngle = round(angleDeg / snapDeg) * snapDeg

        if isDraggingSleep {
            if snappedAngle != sleepAngle {
                sleepAngle = snappedAngle
                updateTime(isSleep: true, angle: snappedAngle)
                // Haptic on change
                impactLight.impactOccurred()
            }
        } else if isDraggingWake {
            if snappedAngle != wakeAngle {
                wakeAngle = snappedAngle
                updateTime(isSleep: false, angle: snappedAngle)
                impactLight.impactOccurred()
            }
        }
    }

    func angleDifference(angle1: Double, angle2: Double) -> Double {
        var diff = angle1 - angle2
        if diff > 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        return diff
    }

    func updateTime(isSleep: Bool, angle: Double) {
        let totalMinutes = (angle / 360) * (24 * 60)
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60

        // Construct new date preserving day
        let cal = Calendar.current
        var comps = DateComponents()
        comps.hour = hours
        comps.minute = minutes

        // Base Date
        let baseDate = isSleep ? sleepTime : wakeTime
        let fullComps = cal.dateComponents([.year, .month, .day], from: baseDate)

        var newFullComps = fullComps
        newFullComps.hour = hours
        newFullComps.minute = minutes

        if let newDate = cal.date(from: newFullComps) {
            if isSleep {
                sleepTime = newDate
            } else {
                wakeTime = newDate
            }
        }
    }
}
