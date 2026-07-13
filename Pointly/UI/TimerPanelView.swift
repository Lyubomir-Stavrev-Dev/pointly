import SwiftUI
import AppKit

// MARK: - Controller

final class CountdownTimerController: ObservableObject {
    @Published private(set) var remaining: TimeInterval = 5 * 60
    @Published private(set) var duration: TimeInterval = 5 * 60
    @Published private(set) var isRunning = false
    @Published private(set) var isFinished = false

    private var timer: Timer?

    var display: String {
        let total = max(0, Int(remaining.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    func set(minutes: Int) {
        pause()
        duration = TimeInterval(minutes * 60)
        remaining = duration
        isFinished = false
    }

    func addMinute(_ delta: Int) {
        let new = max(60, duration + TimeInterval(delta * 60))
        let wasRunning = isRunning
        pause()
        remaining = max(0, remaining + TimeInterval(delta * 60))
        duration = new
        isFinished = false
        if wasRunning && remaining > 0 { start() }
    }

    func start() {
        guard !isRunning, remaining > 0 else { return }
        isRunning = true
        isFinished = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            remaining -= 1
            if remaining <= 0 {
                remaining = 0
                finish()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func reset() {
        pause()
        remaining = duration
        isFinished = false
    }

    private func finish() {
        pause()
        isFinished = true
        NSSound(named: "Glass")?.play()
    }

    deinit { timer?.invalidate() }
}

// MARK: - Panel view

struct TimerPanelView: View {
    @ObservedObject var controller: CountdownTimerController
    var onClose: () -> Void

    private let brand = Color(red: 0.96, green: 0.39, blue: 0.30)
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("TIMER")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }

            Text(controller.display)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(controller.isFinished ? brand : .white)
                .opacity(controller.isFinished && pulse ? 0.25 : 1)
                .animation(controller.isFinished
                           ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                           : .default, value: pulse)
                .onChange(of: controller.isFinished) { _, finished in
                    pulse = finished
                }

            HStack(spacing: 6) {
                ForEach([5, 10, 15], id: \.self) { m in
                    presetButton("\(m)m") { controller.set(minutes: m) }
                }
                presetButton("−1") { controller.addMinute(-1) }
                presetButton("+1") { controller.addMinute(1) }
            }

            HStack(spacing: 8) {
                Button {
                    controller.isRunning ? controller.pause() : controller.start()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: controller.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(controller.isRunning ? "Pause" : "Start")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [brand, Color(red: 1, green: 0.55, blue: 0.26)],
                                                 startPoint: .leading, endPoint: .trailing))
                    )
                }
                .buttonStyle(.plain)

                Button {
                    controller.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 210)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.03, green: 0.03, blue: 0.07).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(brand.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: brand.opacity(0.25), radius: 12)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
        )
    }

    @ViewBuilder
    private func presetButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.09)))
        }
        .buttonStyle(.plain)
    }
}
