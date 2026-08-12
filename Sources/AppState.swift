import AppKit
import Foundation
import LocalAuthentication

@MainActor
final class AppState: ObservableObject {
    enum Mode: Equatable {
        case idle
        case calibrating
        case armed
        case alarming
        case authenticating
    }

    enum SensorStatus: Equatable {
        case checking
        case ready
        case permissionRequired
        case unavailable
        case error(String)

        var title: String {
            switch self {
            case .checking: "CHECKING SENSOR"
            case .ready: "MOTION SENSOR READY"
            case .permissionRequired: "INPUT MONITORING NEEDED"
            case .unavailable: "NO SUPPORTED SENSOR"
            case .error: "SENSOR ERROR"
            }
        }
    }

    @Published var mode: Mode = .idle
    @Published var selectedPersonality: AlarmPersonality = .screamingMan
    @Published var sensitivity: AlarmSensitivity = .balanced
    @Published var sensorStatus: SensorStatus = .checking
    @Published var calibrationProgress = 0.0
    @Published var calibrationCountdown = 3
    @Published var motionLevel = 0.0
    @Published var triggerCause = "MOTION DETECTED"
    @Published var authenticationError: String?
    @Published private(set) var isAuthenticationPromptActive = false
    @Published private(set) var touchIDAvailable = false

    var onEngageKiosk: (() -> Void)?
    var onReleaseKiosk: (() -> Void)?
    var onAlarmTriggered: ((String) -> Void)?
    var onAlarmSettled: (() -> Void)?
    var onDidDisarm: (() -> Void)?

    private let sensor = AccelerometerReader()
    private let audio = AlarmAudio()
    private var samples: [(Double, Double, Double)] = []
    private var previousMotionSample: (Double, Double, Double)?
    private var calibratedNoiseFloor = 0.0005
    private var calibratedRestingPosition: (Double, Double, Double)?
    private var calibratedPositionNoise = 0.0005
    private var smoothedMotion = 0.0
    private var quietSince: Date?
    private var alarmObservedMotion = false
    private var calibrationTask: Task<Void, Never>?
    private var graceUntil = Date.distantPast
    private var authInProgress = false
    private var authenticationContext: LAContext?

    init() {
        sensor.onSample = { [weak self] x, y, z in
            Task { @MainActor in self?.consumeMotion(x: x, y: y, z: z) }
        }
        sensorStatus = AccelerometerReader.isSensorPresent() ? .ready : .unavailable

        let context = LAContext()
        var error: NSError?
        touchIDAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var isLocked: Bool {
        mode == .armed || mode == .alarming || mode == .authenticating
    }

    var canArm: Bool { mode == .idle }

    func arm() {
        guard mode == .idle else { return }
        authenticationError = nil

        switch sensor.start() {
        case .started:
            sensorStatus = .ready
        case .permissionRequired:
            sensorStatus = .permissionRequired
            openInputMonitoringSettings()
            return
        case .unavailable:
            sensorStatus = .unavailable
        case .failed(let message):
            sensorStatus = .error(message)
        }

        mode = .calibrating
        samples.removeAll(keepingCapacity: true)
        calibrationProgress = 0
        calibrationCountdown = 3
        let started = Date()

        calibrationTask?.cancel()
        calibrationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(started)
                self.calibrationProgress = min(elapsed / 3, 1)
                self.calibrationCountdown = max(1, Int(ceil(3 - elapsed)))
                if elapsed >= 3 {
                    self.finishCalibration()
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    func previewPersonality() {
        guard mode == .idle else { return }
        audio.preview(selectedPersonality)
    }

    func registerHumanInteraction() {
        guard mode == .armed, Date() >= graceUntil else { return }
        triggerAlarm(cause: "SOMEONE TOUCHED ME", canSettleAutomatically: false)
    }

    func triggerTestAlarm() {
        guard mode == .armed else { return }
        triggerAlarm(cause: "TEST MOVEMENT", canSettleAutomatically: true)
    }

    func requestOwnerUnlock() {
        guard isLocked, !authInProgress else { return }
        if mode == .armed { triggerAlarm(cause: "DISARM ATTEMPT", canSettleAutomatically: false) }
        beginAuthentication(policy: .deviceOwnerAuthentication, reportsErrors: true)
    }

    func openInputMonitoringSettings() {
        _ = sensor.requestInputMonitoring()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func finishCalibration() {
        if samples.count > 1 {
            let count = Double(samples.count)
            let restingPosition = samples.reduce((0.0, 0.0, 0.0)) { partial, sample in
                (partial.0 + sample.0, partial.1 + sample.1, partial.2 + sample.2)
            }
            calibratedRestingPosition = (
                restingPosition.0 / count,
                restingPosition.1 / count,
                restingPosition.2 / count
            )

            var restingDeltas: [Double] = []
            restingDeltas.reserveCapacity(samples.count - 1)
            for index in 1..<samples.count {
                restingDeltas.append(Self.distance(samples[index], samples[index - 1]))
            }
            restingDeltas.sort()
            let percentileIndex = min(Int(Double(restingDeltas.count - 1) * 0.9), restingDeltas.count - 1)
            calibratedNoiseFloor = max(restingDeltas[percentileIndex], 0.0005)

            if let calibratedRestingPosition {
                let restingOffsets = samples.map { Self.distance($0, calibratedRestingPosition) }.sorted()
                let offsetIndex = min(Int(Double(restingOffsets.count - 1) * 0.95), restingOffsets.count - 1)
                calibratedPositionNoise = max(restingOffsets[offsetIndex], 0.0005)
            }
        }
        previousMotionSample = samples.last
        smoothedMotion = 0
        quietSince = nil
        alarmObservedMotion = false

        mode = .armed
        graceUntil = Date().addingTimeInterval(0.65)
        onEngageKiosk?()
    }

    private func consumeMotion(x: Double, y: Double, z: Double) {
        let sample = (x, y, z)
        if mode == .calibrating {
            samples.append(sample)
            return
        }

        guard mode == .armed || mode == .alarming else {
            previousMotionSample = sample
            return
        }
        guard let previous = previousMotionSample else {
            previousMotionSample = sample
            return
        }
        previousMotionSample = sample

        let instantaneousMotion = Self.distance(sample, previous)
        smoothedMotion = (smoothedMotion * 0.58) + (instantaneousMotion * 0.42)
        let threshold = effectiveMotionThreshold
        let pickupMotion = calibratedRestingPosition.map { Self.distance(sample, $0) } ?? 0
        let pickupThreshold = effectivePickupThreshold
        motionLevel = min(max(
            max(smoothedMotion / threshold, instantaneousMotion / (threshold * 1.25)),
            pickupMotion / pickupThreshold
        ), 1)

        if mode == .armed {
            guard Date() >= graceUntil else { return }
            if pickupMotion >= pickupThreshold {
                triggerAlarm(cause: "PICKUP DETECTED", canSettleAutomatically: true)
            } else if smoothedMotion >= threshold || instantaneousMotion >= threshold * 1.25 {
                triggerAlarm(cause: "MOTION DETECTED", canSettleAutomatically: true)
            }
            return
        }

        if smoothedMotion >= threshold * 0.7 ||
            instantaneousMotion >= threshold ||
            pickupMotion >= pickupThreshold * 0.7 {
            alarmObservedMotion = true
            quietSince = nil
        } else if alarmObservedMotion, smoothedMotion <= threshold * 0.32 {
            if quietSince == nil { quietSince = Date() }
            if let quietSince, Date().timeIntervalSince(quietSince) >= 1.1 {
                settleAlarm()
            }
        } else {
            quietSince = nil
        }
    }

    private var effectiveMotionThreshold: Double {
        max(sensitivity.threshold, calibratedNoiseFloor * sensitivity.noiseMultiplier)
    }

    private var effectivePickupThreshold: Double {
        max(sensitivity.pickupThreshold, calibratedPositionNoise * sensitivity.noiseMultiplier)
    }

    private func beginAuthentication(policy: LAPolicy, reportsErrors: Bool) {
        guard isLocked, !authInProgress else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Keep Armed"
        context.localizedFallbackTitle = policy == .deviceOwnerAuthentication ? "Use Mac Password" : ""
        context.touchIDAuthenticationAllowableReuseDuration = 0
        var policyError: NSError?

        guard context.canEvaluatePolicy(policy, error: &policyError) else {
            if reportsErrors {
                authenticationError = policyError?.localizedDescription ?? "Owner authentication is unavailable."
            }
            return
        }

        authInProgress = true
        isAuthenticationPromptActive = true
        authenticationError = nil
        authenticationContext = context

        context.evaluatePolicy(policy, localizedReason: "Touch ID to disarm Don't Touch My Laptop") { [weak self, weak context] success, error in
            DispatchQueue.main.async {
                guard let self, let context, self.authenticationContext === context else { return }
                self.authInProgress = false
                self.isAuthenticationPromptActive = false
                self.authenticationContext = nil
                if success {
                    self.disarmAfterAuthentication()
                } else if reportsErrors,
                          (error as? LAError)?.code != .userCancel,
                          (error as? LAError)?.code != .appCancel,
                          (error as? LAError)?.code != .systemCancel {
                    self.authenticationError = error?.localizedDescription ?? "Authentication failed. Alarm remains armed."
                }
            }
        }
    }

    private func triggerAlarm(cause: String, canSettleAutomatically: Bool) {
        guard mode == .armed else { return }
        triggerCause = cause
        alarmObservedMotion = canSettleAutomatically
        quietSince = nil
        mode = .alarming
        audio.start(selectedPersonality)
        onAlarmTriggered?(cause)
    }

    private func settleAlarm() {
        guard mode == .alarming else { return }
        audio.stop()
        motionLevel = 0
        smoothedMotion = 0
        quietSince = nil
        alarmObservedMotion = false
        graceUntil = Date().addingTimeInterval(0.8)
        mode = .armed
        onAlarmSettled?()
    }

    private static func distance(
        _ lhs: (Double, Double, Double),
        _ rhs: (Double, Double, Double)
    ) -> Double {
        sqrt(pow(lhs.0 - rhs.0, 2) + pow(lhs.1 - rhs.1, 2) + pow(lhs.2 - rhs.2, 2))
    }

    private func disarmAfterAuthentication() {
        authenticationContext?.invalidate()
        authenticationContext = nil
        authInProgress = false
        isAuthenticationPromptActive = false
        audio.stop()
        sensor.stop()
        calibrationTask?.cancel()
        previousMotionSample = nil
        smoothedMotion = 0
        quietSince = nil
        alarmObservedMotion = false
        motionLevel = 0
        authenticationError = nil
        mode = .idle
        sensorStatus = AccelerometerReader.isSensorPresent() ? .ready : .unavailable
        onReleaseKiosk?()
        onDidDisarm?()
    }
}
