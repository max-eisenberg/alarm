import AppKit
import Darwin
import Foundation
import IOKit.hid

@main
struct AlarmCommand {
    private static var runLock: AlarmRunLock?

    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            runAlarm(arguments: [])
            return
        }

        switch command {
        case "--on", "on", "enable":
            runAlarm(arguments: Array(arguments.dropFirst()))
        case "--setup", "setup":
            printBanner()
            _ = preparePermissions(openSettingsWhenNeeded: true)
        case "--check", "check", "doctor":
            printBanner()
            printSystemCheck()
        case "--off", "off", "disable":
            print("\n  There is no unauthenticated --off switch.")
            print("  Use OWNER UNLOCK on the lock screen, then authenticate with macOS.\n")
        case "--version", "version":
            print("alarm 2.3.0")
        case "--help", "-h", "help":
            printHelp()
        default:
            runAlarm(arguments: arguments)
        }
    }

    @MainActor
    private static func runAlarm(arguments: [String]) {
        let configuration: (AlarmPersonality, AlarmSensitivity)
        do {
            configuration = try parseConfiguration(arguments)
        } catch {
            fputs("alarm: \(error.localizedDescription)\n", stderr)
            exit(EX_USAGE)
        }

        printBanner()
        guard let lock = AlarmRunLock.acquire() else {
            print("  Alarm is already on.\n")
            exit(EX_TEMPFAIL)
        }
        runLock = lock

        let sensorReady = preparePermissions(openSettingsWhenNeeded: true)
        if AccelerometerReader.isSensorPresent(), !sensorReady {
            printPermissionRestartFlow()
            exit(EX_NOPERM)
        }

        print("  ✓ \(configuration.0.name)")
        if configuration.1 != .balanced { print("  ✓ \(configuration.1.rawValue) sensitivity") }
        if !AccelerometerReader.isSensorPresent() {
            print("  ! Motion sensor     unavailable; touch guard only")
        }
        print("\n  Hands off. Arming in 3 seconds…")
        fflush(stdout)

        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        let state = AppState()
        state.selectedPersonality = configuration.0
        state.sensitivity = configuration.1
        state.onAlarmTriggered = { cause in
            print("\n  ⚠ ALARM — \(cause)")
            fflush(stdout)
        }
        state.onAlarmSettled = {
            print("  ✓ MacBook is still. Alarm quiet; lock remains armed.")
            fflush(stdout)
        }
        state.onDidDisarm = {
            print("\n  ✓ OWNER VERIFIED — alarm disarmed.\n")
            fflush(stdout)
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }

        let application = NSApplication.shared
        let delegate = AppDelegate(state: state, commandLineMode: true)
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.finishLaunching()
        state.arm()
        application.run()
        withExtendedLifetime(delegate) { }
    }

    private static func parseConfiguration(_ arguments: [String]) throws -> (AlarmPersonality, AlarmSensitivity) {
        var personality = AlarmPersonality.screamingMan
        var sensitivity = AlarmSensitivity.balanced
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            let value = argument.lowercased()
            switch argument {
            case "--personality", "-p":
                guard index + 1 < arguments.count,
                      let selected = personalityForName(arguments[index + 1].lowercased()) else {
                    throw CLIError("choose: scream, goose, car, villager, mother, or meep")
                }
                personality = selected
                index += 2
            case "--sensitivity", "-s":
                guard index + 1 < arguments.count,
                      let selected = sensitivityForName(arguments[index + 1]) else {
                    throw CLIError("sensitivity must be chill, balanced, or feral")
                }
                sensitivity = selected
                index += 2
            default:
                if let selected = personalityForName(value) {
                    personality = selected
                } else if let selected = sensitivityForName(value) {
                    sensitivity = selected
                } else {
                    throw CLIError("don't know '\(argument)'. Try: ./alarm help")
                }
                index += 1
            }
        }
        return (personality, sensitivity)
    }

    private static func sensitivityForName(_ value: String) -> AlarmSensitivity? {
        AlarmSensitivity.allCases.first { $0.rawValue.lowercased() == value.lowercased() }
    }

    private static func personalityForName(_ value: String) -> AlarmPersonality? {
        switch value.replacingOccurrences(of: "-", with: "") {
        case "scream", "screaming", "screamingman": .screamingMan
        case "goose", "angrygoose": .angryGoose
        case "car", "caralarm": .carAlarm
        case "villager", "medieval", "medievalvillager": .medievalVillager
        case "mother", "disappointedmother": .disappointedMother
        case "creature", "tinycreature", "meep": .tinyCreature
        default: nil
        }
    }

    @discardableResult
    private static func preparePermissions(openSettingsWhenNeeded: Bool) -> Bool {
        guard AccelerometerReader.isSensorPresent() else {
            print("  ! Internal IMU       not found")
            return true
        }

        let probe = AccelerometerReader()
        switch probe.start(requestPermissionIfNeeded: openSettingsWhenNeeded) {
        case .started:
            probe.stop()
            print("  ✓ Motion sensor ready")
            return true
        case .permissionRequired:
            print("  ! Motion permission needed")
            guard openSettingsWhenNeeded else { return false }
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(url)
            }
            return false
        case .unavailable:
            print("  ! Internal IMU       unavailable")
            return true
        case .failed(let message):
            print("  ! Sensor error       \(message)")
            return false
        }
    }

    private static func printPermissionRestartFlow() {
        let terminal = terminalDisplayName
        print("""

          ONE-TIME SETUP
          System Settings is open.

          1. Turn on \(terminal) under Input Monitoring.
          2. Quit and reopen \(terminal).
          3. Run ./alarm again.

        """)
    }

    private static var terminalDisplayName: String {
        switch ProcessInfo.processInfo.environment["TERM_PROGRAM"] {
        case "Apple_Terminal": "Terminal"
        case "iTerm.app": "iTerm"
        case let name?: name
        case nil: "your terminal"
        }
    }

    private static func printSystemCheck() {
        let architecture = ProcessInfo.processInfo.machineHardwareName
        print("  SYSTEM CHECK")
        print("  ─────────────────────────────────────────")
        print("  \(architecture == "arm64" ? "✓" : "!") Architecture       \(architecture)")
        print("  \(AccelerometerReader.isSensorPresent() ? "✓" : "!") Internal IMU       \(AccelerometerReader.isSensorPresent() ? "found" : "not found")")
        let probe = AccelerometerReader()
        let accessWorks: Bool
        if case .started = probe.start(requestPermissionIfNeeded: false) {
            accessWorks = true
            probe.stop()
        } else {
            accessWorks = false
        }
        print("  \(accessWorks ? "✓" : "!") Sensor access      \(accessWorks ? "working" : "restart terminal")")
        print("  ✓ Owner auth        managed by macOS\n")
    }

    private static func printBanner() {
        print("""

          DON'T TOUCH MY LAPTOP
          ─────────────────────

        """)
    }

    private static func printHelp() {
        print("""

        DON'T TOUCH MY LAPTOP

          ./alarm                 Arm it
          ./alarm goose           Arm it with an angry goose
          ./alarm goose feral     Goose + extra sensitive
          ./alarm check           Check that everything works
          ./alarm help            Show this

        SOUNDS
          scream  goose  car  villager  mother  meep

        SENSITIVITY
          chill  balanced  feral

        Press OWNER UNLOCK, then use Touch ID or your Mac password.

        """)
    }
}

private struct CLIError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

private extension ProcessInfo {
    var machineHardwareName: String {
        var system = utsname()
        uname(&system)
        return withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}
