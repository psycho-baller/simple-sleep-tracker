import SwiftUI

struct CircularTimePicker: View {
    // Dates for start (bedtime) and end (wake up)
    @Binding var sleepTime: Date
    @Binding var wakeTime: Date
    
    // Config
    var size: CGFloat = 250
    var strokeWidth: CGFloat = 40
    
    // Internal state for gesture handling
    @State private var sleepAngle: Double = 0.0
    @State private var wakeAngle: Double = 0.0
    
    var body: some View {
        ZStack {
            // 1. Background Circle (Track)
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: strokeWidth)
                .frame(width: size, height: size)
            
            // 2. Active Arc (Sleep Duration)
            // We use a custom shape or trim based on angles
            Circle()
                .trim(from: startFraction, to: endFraction)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.indigo, .purple, .orange]),
                        center: .center,
                        startAngle: .degrees(sleepAngle - 90),
                        endAngle: .degrees(wakeAngle - 90 + (wakeAngle < sleepAngle ? 360 : 0))
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
            
            // 3. Sleep Knob (Moon / Bed)
            Knob(icon: "moon.fill", color: .indigo)
                .offset(y: -size/2)
                .rotationEffect(.degrees(sleepAngle))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            change(location: value.location, isSleep: true)
                        }
                )
            
            // 4. Wake Knob (Sun / Alarm)
            Knob(icon: "sun.max.fill", color: .orange)
                .offset(y: -size/2)
                .rotationEffect(.degrees(wakeAngle))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            change(location: value.location, isSleep: false)
                        }
                )
            
            // 5. Center Info
            VStack {
                let duration = self.duration
                Text(formatDuration(duration))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Duration")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            updateAnglesFromDates()
        }
        .onChange(of: sleepTime) { _, _ in updateAnglesFromDates() }
        .onChange(of: wakeTime) { _, _ in updateAnglesFromDates() }
    }
    
    // MARK: - Subviews
    
    func Knob(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .shadow(radius: 4)
            
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
        }
    }
    
    // MARK: - Logic
    
    // Calculate fractions for the trim
    // Trim expects 0.0 to 1.0 where 0 is 3 o'clock (0 degrees).
    // Our angles: 0 is 12 o'clock.
    // Wait, SwiftUI Circle() starts at 3 o'clock (0 rads).
    // .rotationEffect(-90) makes 0 degrees at 12 o'clock.
    // So if sleepAngle is 0 (12 o'clock), trim should be 0.
    var startFraction: CGFloat {
        return sleepAngle / 360.0
    }
    
    var endFraction: CGFloat {
        var end = wakeAngle / 360.0
        if end < startFraction {
            end += 1.0 // Wrap around
        }
        return end
    }
    
    var duration: TimeInterval {
        var diff = wakeAngle - sleepAngle
        if diff < 0 { diff += 360 }
        // 360 degrees = 24 hours = 86400 seconds
        return (diff / 360.0) * 86400
    }
    
    func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    func updateAnglesFromDates() {
        sleepAngle = angle(for: sleepTime)
        wakeAngle = angle(for: wakeTime)
    }
    
    // Convert Date to Angle (0-360, 0 at 12:00 AM/PM)
    // Wait, let's use 24h cycle? 
    // Apple Health sleep editor usually uses 24h cycle.
    // 0 degrees = 00:00 (12 AM). 180 degrees = 12:00 (12 PM).
    func angle(for date: Date) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        
        let totalMinutes = hour * 60 + minute
        let totalMinutesInDay: Double = 24 * 60
        
        return (totalMinutes / totalMinutesInDay) * 360.0
    }
    
    func change(location: CGPoint, isSleep: Bool) {
        // Calculate vector from center
        // Center of the view is (size/2, size/2) if local coords, but drag location is in local coords
        // Actually drag gesture provides location relative to the view
        
        // This vector calculation is tricky in standard DragGesture inside ZStack elements
        // Let's use GeometryReader or assume center is frame center
        // It's easier if we interpret the angle from the center of the ZStack
        
        let vector = CGVector(dx: location.x, dy: location.y)
        // This location is relative to the knob's original position which is rotated... this is messy.
        // Better to use a DragGesture on blocking transparent view or calculate relative to center of circle
        
        // Let's simplify: Get angle from center of the circle to the touch point.
        // We need a GeometryReader to know the center?
        // Or assume center is 0,0 provided we translate coords.
        
        // Alternative: Use a transparent circle for gesture detection
    }
}

// Rewriting for proper gesture handling
struct CircularTimePickerBetter: View {
    @Binding var sleepTime: Date
    @Binding var wakeTime: Date
    var size: CGFloat = 280
    
    @State private var sleepAngle: Double = 0
    @State private var wakeAngle: Double = 0
    
    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            
            ZStack {
                 // Background
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 40)
                    .frame(width: size, height: size)
                
                 // Labels (12, 6, 18, 24)
                ForEach(0..<4) { i in
                    VStack {
                        Text("\(i * 6 == 0 ? 24 : i * 6)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                    }
                    .offset(y: -(size/2 + 35))
                    .rotationEffect(.degrees(Double(i) * 90))
                }
                
                // Active Arc
                Circle()
                    .trim(from: sleepAngle/360, to: (wakeAngle < sleepAngle ? wakeAngle + 360 : wakeAngle)/360)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.indigo, .purple, .orange]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 40, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)
                
                // Sleep Knob
                knob(icon: "bed.double.fill", color: .indigo, angle: sleepAngle)
                    .gesture(
                        DragGesture().onChanged { value in
                            onDrag(value: value, center: center, isSleep: true)
                        }
                    )
                
                // Wake Knob
                knob(icon: "alarm.fill", color: .orange, angle: wakeAngle)
                    .gesture(
                        DragGesture().onChanged { value in
                            onDrag(value: value, center: center, isSleep: false)
                        }
                    )
                
                VStack {
                    let diff = activeDuration
                    Text(formatDuration(diff))
                        .font(.largeTitle)
                        .bold()
                        .monospacedDigit()
                    Text("Time Asleep")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                setAnglesFromDates()
            }
        }
        .frame(height: size + 80)
    }
    
    func knob(icon: String, color: Color, angle: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 2)
                .frame(width: 48, height: 48)
            Image(systemName: icon)
                .foregroundColor(color)
        }
        .offset(y: -size/2)
        .rotationEffect(.degrees(angle))
    }
    
    func setAnglesFromDates() {
        sleepAngle = dateToAngle(sleepTime)
        wakeAngle = dateToAngle(wakeTime)
    }
    
    func dateToAngle(_ date: Date) -> Double {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let totalMins = Double(comps.hour ?? 0) * 60 + Double(comps.minute ?? 0)
        return (totalMins / (24 * 60)) * 360
    }
    
    func onDrag(value: DragGesture.Value, center: CGPoint, isSleep: Bool) {
        // Calculate angle from center to touch
        let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
        // atan2 returns angle in radians (-pi to pi). 0 is 3 o'clock (right).
        // -pi/2 is 12 o'clock (top).
        var angleRad = atan2(vector.dy, vector.dx)
        
        // Convert to degrees
        var angleDeg = angleRad * 180 / .pi
        
        // Adjust coordinate system:
        // atan2: Right=0, Down=90, Left=180, Top=-90
        // We want: Top=0, Right=90, Down=180, Left=270
        // Add 90 degrees?
        // If 0 (Right, 3pm) -> +90 -> 90. Correct.
        // If -90 (Top, 12am) -> +90 -> 0. Correct.
        angleDeg += 90
        
        if angleDeg < 0 { angleDeg += 360 }
        
        // Updates
        if isSleep {
            sleepAngle = angleDeg
            updateTime(isSleep: true, angle: angleDeg)
        } else {
            wakeAngle = angleDeg
            updateTime(isSleep: false, angle: angleDeg)
        }
    }
    
    func updateTime(isSleep: Bool, angle: Double) {
        // Convert angle (0-360) to time (0-24h)
        let totalMinutes = (angle / 360) * (24 * 60)
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60
        
        // Snap to 5 minutes?
        let snappedMinutes = (minutes / 5) * 5
        
        let cal = Calendar.current
        var components = DateComponents()
        components.hour = hours
        components.minute = snappedMinutes
        
        // We need to keep the same Day, just change time
        // Actually, for a single session we might need to handle day overflows?
        // Let's assume we are just picking a time on *some* arbitrary day for now, 
        // and the parent view handles date logic.
        
        if let newDate = cal.date(from: components) {
            // Merge time into original date
            let original = isSleep ? sleepTime : wakeTime
            
            // This is tricky. We need to preserve the Day of the original date, 
            // but set h/m from newDate.
            let fullComps = cal.dateComponents([.year, .month, .day], from: original)
            var newFullComps = fullComps
            newFullComps.hour = hours
            newFullComps.minute = snappedMinutes
            
            if let finalDate = cal.date(from: newFullComps) {
                if isSleep {
                    sleepTime = finalDate
                } else {
                    wakeTime = finalDate
                }
            }
        }
    }
    
    var activeDuration: TimeInterval {
        var diff = wakeAngle - sleepAngle
        if diff < 0 { diff += 360 }
        return (diff / 360) * 86400
    }
    
    func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return "\(h)hr \(m)min"
    }
}
