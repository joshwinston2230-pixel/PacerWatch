import SwiftUI
import Combine
import WatchConnectivity

struct RaceSplit: Codable, Identifiable {
    var id: Int { km }
    let km: Int
    let pacePerKm: String
    let cumulativeTime: String
    let effortLabel: String
    let heartRateZone: Int
    let targetHR: Int?
}

struct FuelEvent: Codable, Identifiable {
    var id: Int { elapsedTimeMin }
    let elapsedTimeMin: Int
    let action: String
    let product: String
    let quantity: String
    let warning: String?
}

struct RacePlan: Codable {
    let splits: [RaceSplit]
    let fuelSchedule: [FuelEvent]
    let summary: PlanSummary
}

struct PlanSummary: Codable {
    let estimatedFinishTime: String
    let averagePace: String
    let recommendedStrategy: String?
}

class RaceViewModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var plan: RacePlan? = nil
    @Published var currentKm: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    
    private var timer: Timer?
    private var startTime: Date?
    private var pausedSeconds: Int = 0
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        #if targetEnvironment(simulator)
        loadTestPlan()
        #endif
    }
    
    func startRace() {
        startTime = Date()
        isRunning = true
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.elapsedSeconds = self.pausedSeconds + Int(Date().timeIntervalSince(self.startTime!))
        }
    }
    
    func pauseRace() {
        pausedSeconds = elapsedSeconds
        timer?.invalidate()
        isPaused = true
        isRunning = false
    }
    
    func resumeRace() {
        startTime = Date()
        isRunning = true
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.elapsedSeconds = self.pausedSeconds + Int(Date().timeIntervalSince(self.startTime!))
        }
    }
    
    func endRace() {
        timer?.invalidate()
        elapsedSeconds = 0
        pausedSeconds = 0
        currentKm = 0
        isRunning = false
        isPaused = false
        startTime = nil
    }
    
    func advanceKm() {
        if let plan = plan, currentKm < plan.splits.count - 1 {
            currentKm += 1
        }
    }
    
    func retreatKm() {
        if currentKm > 0 {
            currentKm -= 1
        }
    }
    
    var aheadBehindSeconds: Int {
        guard let plan = plan, currentKm < plan.splits.count else { return 0 }
        let targetSecs = timeStringToSeconds(plan.splits[currentKm].cumulativeTime)
        return targetSecs - elapsedSeconds
    }
    
    var nextFuelEvent: FuelEvent? {
        guard let plan = plan else { return nil }
        let elapsedMins = elapsedSeconds / 60
        return plan.fuelSchedule.first { $0.elapsedTimeMin > elapsedMins }
    }
    
    func timeStringToSeconds(_ time: String) -> Int {
        let parts = time.split(separator: ":").map { Int($0) ?? 0 }
        if parts.count == 3 { return parts[0]*3600 + parts[1]*60 + parts[2] }
        if parts.count == 2 { return parts[0]*60 + parts[1] }
        return 0
    }
    
    func formatElapsed(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
    
    // WCSession delegate
    func loadTestPlan() {
        let testJSON = """
        {"splits":[{"km":1,"pacePerKm":"5:30","cumulativeTime":"0:01:00","effortLabel":"Easy","heartRateZone":2,"targetHR":145},{"km":2,"pacePerKm":"5:00","cumulativeTime":"0:02:00","effortLabel":"Moderate","heartRateZone":3,"targetHR":158},{"km":3,"pacePerKm":"4:45","cumulativeTime":"0:03:00","effortLabel":"Hard","heartRateZone":4,"targetHR":168},{"km":4,"pacePerKm":"4:45","cumulativeTime":"0:04:00","effortLabel":"Hard","heartRateZone":4,"targetHR":170},{"km":5,"pacePerKm":"5:30","cumulativeTime":"0:05:00","effortLabel":"Easy","heartRateZone":2,"targetHR":145}],"fuelSchedule":[{"elapsedTimeMin":1,"action":"Take gel","product":"SiS Beta Fuel","quantity":"1 gel","warning":null},{"elapsedTimeMin":2,"action":"Drink water","product":"Aid station","quantity":"200ml","warning":null},{"elapsedTimeMin":3,"action":"Decision point","product":"How are you feeling?","quantity":"Push or hold pace","warning":"Halfway through — make a call"},{"elapsedTimeMin":4,"action":"Take caffeine gel","product":"GU Roctane Caffeine","quantity":"1 gel","warning":"Caffeine boost for final km"},{"elapsedTimeMin":5,"action":"Drink water","product":"Aid station","quantity":"200ml","warning":null}],"summary":{"estimatedFinishTime":"0:05:00","averagePace":"5:00","recommendedStrategy":"TEST PLAN"}}
        """
        if let data = testJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(RacePlan.self, from: data) {
            DispatchQueue.main.async {
                self.plan = decoded
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // iPhone sends plan as JSON string (more reliable across WC encoding paths than raw Data)
        if let planString = message["plan"] as? String,
           let planData = planString.data(using: .utf8) {
            DispatchQueue.main.async {
                do {
                    let decoded = try JSONDecoder().decode(RacePlan.self, from: planData)
                    self.plan = decoded
                    self.currentKm = 0
                    print("[Watch] Plan loaded: \(decoded.splits.count) splits")
                } catch {
                    print("[Watch] Failed to decode plan: \(error)")
                }
            }
        } else if let planData = message["plan"] as? Data {
            // Fallback for raw Data path
            DispatchQueue.main.async {
                if let decoded = try? JSONDecoder().decode(RacePlan.self, from: planData) {
                    self.plan = decoded
                    self.currentKm = 0
                }
            }
        } else {
            print("[Watch] Received message with no recognizable plan key")
        }
    }
}

struct ContentView: View {
    @StateObject var vm = RaceViewModel()
    
    var body: some View {
        if vm.plan == nil {
            NoPlanView()
                .environmentObject(vm)
        } else {
            RaceDayView()
                .environmentObject(vm)
        }
    }
}

struct NoPlanView: View {
    @EnvironmentObject var vm: RaceViewModel

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundColor(.green)
            Text("No Plan")
                .font(.headline)
                .foregroundColor(.white)
            Text("Load a plan from the Pacer app on your iPhone")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            // Dev-only test plan loader — set SHOW_DEV_TOOLS=false before App Store
            Button(action: { vm.loadTestPlan() }) {
                Text("🧪 Load Test Plan")
                    .font(.caption2)
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding()
    }
}

struct RaceDayView: View {
    @EnvironmentObject var vm: RaceViewModel
    @StateObject var fuelManager = FuelAlertManager()
    @State private var fuelItems: [FuelItem] = []

    var body: some View {
        ZStack {
        ScrollView {
            VStack(spacing: 8) {
                
                // Current km
                if let plan = vm.plan, vm.currentKm < plan.splits.count {
                    let split = plan.splits[vm.currentKm]
                    
                    // Pace display
                    VStack(spacing: 2) {
                        Text("KM \(vm.currentKm + 1)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(split.pacePerKm)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("TARGET PACE /KM")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // Elapsed vs target
                    HStack(spacing: 12) {
                        VStack(spacing: 2) {
                            Text(vm.formatElapsed(vm.elapsedSeconds))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                            Text("ELAPSED")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                        Divider()
                            .frame(height: 30)
                        VStack(spacing: 2) {
                            Text(split.cumulativeTime)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Text("TARGET")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Ahead/behind
                    if vm.isRunning || vm.isPaused {
                        let diff = vm.aheadBehindSeconds
                        HStack(spacing: 4) {
                            if abs(diff) <= 10 {
                                Text("On pace")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            } else if diff > 0 {
                                Text("▲ \(vm.formatElapsed(diff)) ahead")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(8)
                            } else {
                                Text("▼ \(vm.formatElapsed(-diff)) behind")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.yellow.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Effort badge
                    Text(split.effortLabel)
                        .font(.caption2)
                        .foregroundColor(effortColor(split.effortLabel))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(effortColor(split.effortLabel).opacity(0.2))
                        .cornerRadius(6)
                    
                    // Next fuel
                    if let fuel = vm.nextFuelEvent {
                        let minsAway = fuel.elapsedTimeMin - (vm.elapsedSeconds / 60)
                        VStack(spacing: 2) {
                            Text("NEXT FUEL \(minsAway)min")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(fuel.product)
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        .padding(6)
                        .background(Color.yellow.opacity(minsAway <= 5 ? 0.25 : 0.1))
                        .cornerRadius(8)
                    }
                    
                    // KM controls
                    HStack(spacing: 8) {
                        Button(action: vm.retreatKm) {
                            Text("← KM")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(vm.currentKm == 0)
                        
                        Button(action: vm.advanceKm) {
                            Text("KM →")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(vm.currentKm >= (vm.plan?.splits.count ?? 1) - 1)
                    }
                    
                    // Start/pause/end
                    if !vm.isRunning && !vm.isPaused {
                        Button(action: vm.startRace) {
                            Text("Start Race")
                                .font(.caption)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else if vm.isRunning {
                        Button(action: vm.pauseRace) {
                            Text("Pause")
                                .font(.caption)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.yellow)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 6) {
                            Button(action: vm.resumeRace) {
                                Text("Resume")
                                    .font(.caption2)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: vm.endRace) {
                                Text("End")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.4))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear { buildFuelItems() }
        .onChange(of: vm.plan?.splits.count) { _, _ in buildFuelItems() }
        .onChange(of: vm.elapsedSeconds) { _, elapsed in
            guard vm.isRunning, fuelManager.activeAlert == nil else { return }
            for item in fuelItems where !item.skipped && item.confirmedAt == nil {
                let secondsUntilFuel = (item.scheduledKm * 60) - elapsed
                if secondsUntilFuel == 15 {
                    fuelManager.triggerWarning(for: item)
                }
            }
        }

        if let alert = fuelManager.activeAlert {
            FuelAlertView(
                fuelItem: alert.item,
                alertState: alert.state,
                onDone: {
                    if let idx = fuelItems.firstIndex(where: { $0.id == alert.item.id }) {
                        fuelItems[idx].confirmedAt = Date()
                    }
                    fuelManager.confirmDone()
                },
                onSkip: {
                    if let idx = fuelItems.firstIndex(where: { $0.id == alert.item.id }) {
                        fuelItems[idx].skipped = true
                    }
                    fuelManager.confirmSkip()
                }
            )
            .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            .zIndex(100)
        }
        } // end ZStack
    }

    private func buildFuelItems() {
        guard let plan = vm.plan else { return }
        fuelItems = plan.fuelSchedule.map { event in
            FuelItem(
                id: UUID(),
                name: event.product,
                carbsGrams: 0,
                notes: event.quantity + (event.warning.map { " · \($0)" } ?? ""),
                scheduledKm: event.elapsedTimeMin
            )
        }
    }

    func effortColor(_ label: String) -> Color {
        switch label {
        case "Easy", "Moderate": return .gray
        case "Comfortably Hard": return .green
        case "Hard", "Max": return .yellow
        default: return .gray
        }
    }
}

#Preview {
    ContentView()
}
