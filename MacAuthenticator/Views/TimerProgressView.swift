import SwiftUI

struct TimerProgressView: View {
    let remainingSeconds: Int
    let period: Int

    private var progress: Double {
        let safePeriod = max(period, 1)
        return Double(remainingSeconds) / Double(safePeriod)
    }

    private var ringColor: Color {
        remainingSeconds < 5 ? .orange : .accentColor
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: remainingSeconds)

            Text("\(remainingSeconds)")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(ringColor)
        }
        .frame(width: 28, height: 28)
        .accessibilityLabel("\(remainingSeconds) seconds remaining")
    }
}
