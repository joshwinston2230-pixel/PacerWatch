import SwiftUI
import WatchKit
import Combine
import WatchConnectivity

enum FuelAlertState {
    case warning(secondsRemaining: Int)
    case fuelNow
    case overdue(minutesAgo: Int)
}

struct FuelItem: Identifiable {
    let id: UUID
    let name: String
    let carbsGrams: Int
    let notes: String
    let scheduledKm: Int
    var confirmedAt: Date? = nil
    var skipped: Bool = false
}

struct FuelAlertView: View {
    let fuelItem: FuelItem
    let alertState: FuelAlertState
    let onDone: () -> Void
    let onSkip: () -> Void

    var body: some View {
        switch alertState {
        case .warning(let secs):
            FuelWarningView(fuelItem: fuelItem, secondsRemaining: secs, onDone: onDone, onSkip: onSkip)
        case .fuelNow:
            FuelNowView(fuelItem: fuelItem, onDone: onDone, onSkip: onSkip)
        case .overdue(let mins):
            FuelOverdueView(fuelItem: fuelItem, minutesAgo: mins, onDone: onDone, onSkip: onSkip)
        }
    }
}

struct FuelWarningView: View {
    let fuelItem: FuelItem
    let secondsRemaining: Int
    let onDone: () -> Void
    let onSkip: () -> Void

    private let total: Double = 15
    private var progress: Double { Double(secondsRemaining) / total }

    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.84, blue: 0.04).ignoresSafeArea()
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.15), lineWidth: 5)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: secondsRemaining)
                    VStack(spacing: 0) {
                        Text("\(secondsRemaining)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        Text("secs")
                            .font(.system(size: 8))
                            .foregroundColor(Color(red: 0.23, green: 0.19, blue: 0))
                    }
                }
                Text("Fuel up soon")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                Text("KM \(fuelItem.scheduledKm) · Get ready")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.23, green: 0.19, blue: 0))
                VStack(spacing: 2) {
                    Text(fuelItem.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                    Text("\(fuelItem.carbsGrams)g carbs · \(fuelItem.notes)")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.23, green: 0.19, blue: 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.12))
                .cornerRadius(10)
                Button(action: onDone) {
                    Text("✓ Done early")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.04))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 12))
                        .foregroundColor(Color.black.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
    }
}

struct FuelNowView: View {
    let fuelItem: FuelItem
    let onDone: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.84, blue: 0.04).ignoresSafeArea()
            VStack(spacing: 6) {
                Text("⚡")
                    .font(.system(size: 32))
                Text("Fuel now")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                Text("KM \(fuelItem.scheduledKm) · Right on schedule")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.23, green: 0.19, blue: 0))
                    .multilineTextAlignment(.center)
                VStack(spacing: 2) {
                    Text(fuelItem.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                    Text("\(fuelItem.carbsGrams)g carbs · \(fuelItem.notes)")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.23, green: 0.19, blue: 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.12))
                .cornerRadius(10)
                Button(action: onDone) {
                    Text("✓ Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.04))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 12))
                        .foregroundColor(Color.black.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
    }
}

struct FuelOverdueView: View {
    let fuelItem: FuelItem
    let minutesAgo: Int
    let onDone: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.23, blue: 0.19).ignoresSafeArea()
            VStack(spacing: 6) {
                Text("!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                Text("Fuel overdue")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("KM \(fuelItem.scheduledKm) · \(minutesAgo) min ago")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                VStack(spacing: 2) {
                    Text(fuelItem.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(fuelItem.carbsGrams)g carbs · \(fuelItem.notes)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.15))
                .cornerRadius(10)
                Button(action: onDone) {
                    Text("✓ Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.23, blue: 0.19))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
    }
}

@MainActor
class FuelAlertManager: ObservableObject {
    @Published var activeAlert: (item: FuelItem, state: FuelAlertState)? = nil

    private var countdownTimer: Timer?
    private var overdueTimer: Timer?
    private var secondsRemaining: Int = 15

    func triggerWarning(for item: FuelItem) {
        secondsRemaining = 15
        activeAlert = (item, .warning(secondsRemaining: secondsRemaining))
        WKInterfaceDevice.current().play(.start)
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.secondsRemaining -= 1
                if self.secondsRemaining <= 0 {
                    self.countdownTimer?.invalidate()
                    self.triggerFuelNow(for: item)
                } else {
                    self.activeAlert = (item, .warning(secondsRemaining: self.secondsRemaining))
                }
            }
        }
    }

    private func triggerFuelNow(for item: FuelItem) {
        activeAlert = (item, .fuelNow)
        WKInterfaceDevice.current().play(.notification)
        overdueTimer?.invalidate()
        overdueTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.triggerOverdue(for: item, minutesAgo: 2)
            }
        }
    }

    private func triggerOverdue(for item: FuelItem, minutesAgo: Int) {
        activeAlert = (item, .overdue(minutesAgo: minutesAgo))
        WKInterfaceDevice.current().play(.failure)
    }

    func confirmDone() {
        countdownTimer?.invalidate()
        overdueTimer?.invalidate()
        WKInterfaceDevice.current().play(.success)
        if let alert = activeAlert {
            WCSession.default.sendMessage([
                "type": "fuelConfirmed",
                "fuelItemId": alert.item.id.uuidString,
                "status": "done",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ], replyHandler: nil, errorHandler: nil)
        }
        activeAlert = nil
    }

    func confirmSkip() {
        countdownTimer?.invalidate()
        overdueTimer?.invalidate()
        if let alert = activeAlert {
            WCSession.default.sendMessage([
                "type": "fuelConfirmed",
                "fuelItemId": alert.item.id.uuidString,
                "status": "skipped",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ], replyHandler: nil, errorHandler: nil)
        }
        activeAlert = nil
    }
}
