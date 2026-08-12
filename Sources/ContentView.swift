import AppKit
import SwiftUI

private enum Theme {
    static let ink = Color(red: 0.055, green: 0.082, blue: 0.12)
    static let paper = Color(red: 0.95, green: 0.94, blue: 0.89)
    static let orange = Color(red: 1, green: 0.25, blue: 0.08)
    static let acid = Color(red: 0.83, green: 1, blue: 0.22)
    static let blue = Color(red: 0.08, green: 0.24, blue: 1)
}

struct ContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if state.mode == .idle {
                IdleView(state: state)
            } else if state.mode == .calibrating {
                CalibrationView(state: state)
            } else {
                LockedView(state: state)
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct IdleView: View {
    @ObservedObject var state: AppState

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    header
                    hero(compact: geometry.size.width < 980)
                    personalities
                    footer
                }
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 11) {
                Text("DT")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 39, height: 39)
                    .background(Theme.ink, in: Circle())
                Text("DON'T TOUCH\nMY LAPTOP")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .lineSpacing(-2)
            }
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(sensorColor).frame(width: 8, height: 8)
                Text(state.sensorStatus.title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
        }
        .padding(.horizontal, 32)
        .frame(height: 76)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink).frame(height: 2) }
    }

    @ViewBuilder
    private func hero(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            LabelLine(number: "01", text: "PERSONAL MACBOOK DEFENSE SYSTEM")
            Text("GO AHEAD.\nTOUCH IT.")
                .font(.system(size: compact ? 70 : 92, weight: .black, design: .rounded))
                .tracking(-6)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Theme.ink)
                .lineSpacing(-16)

            HStack(alignment: .center, spacing: 36) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("One big button. Zero chill. Your MacBook screams the second somebody gets handsy.")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                    sensorNotice
                    Picker("Sensitivity", selection: $state.sensitivity) {
                        ForEach(AlarmSensitivity.allCases) { level in Text(level.rawValue).tag(level) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(state.mode != .idle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: state.arm) {
                    ZStack {
                        Circle().fill(Theme.ink).offset(y: 12)
                        Circle().fill(Theme.orange)
                            .overlay(Circle().stroke(Theme.ink, lineWidth: 3))
                        Circle().stroke(.white.opacity(0.35), lineWidth: 2).padding(12)
                        VStack(spacing: 4) {
                            Text("PRESS TO")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(2)
                            Text("ARM\nMACBOOK")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .tracking(-2.5)
                                .lineSpacing(-7)
                        }
                        .foregroundStyle(Theme.ink)
                    }
                    .frame(width: compact ? 250 : 290, height: compact ? 250 : 290)
                }
                .buttonStyle(.plain)
                .shadow(color: .black.opacity(0.28), radius: 18, y: 15)
            }
        }
        .padding(34)
    }

    @ViewBuilder
    private var sensorNotice: some View {
        switch state.sensorStatus {
        case .permissionRequired:
            VStack(alignment: .leading, spacing: 8) {
                Text("Input Monitoring permission is required to read the internal motion sensor.")
                    .font(.system(size: 11, design: .monospaced))
                Button("OPEN PRIVACY SETTINGS", action: state.openInputMonitoringSettings)
                    .buttonStyle(UtilityButtonStyle(color: Theme.blue))
            }
        case .unavailable:
            Text("No compatible Apple Silicon motion sensor found. Touch/trackpad guard will still work while locked.")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        case .error(let message):
            Text(message).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.orange)
        default:
            HStack(spacing: 7) {
                Image(systemName: "waveform.path.ecg")
                Text("INTERNAL MOTION SENSOR + TOUCH GUARD")
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }

    private var personalities: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    LabelLine(number: "02", text: "CHOOSE YOUR FIGHTER", inverse: true)
                    Text("ALARM PERSONALITY")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .tracking(-2.5)
                }
                Spacer()
                Button("PREVIEW VOICE →", action: state.previewPersonality)
                    .buttonStyle(UtilityButtonStyle(color: Theme.acid))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 1)], spacing: 1) {
                ForEach(AlarmPersonality.allCases) { personality in
                    PersonalityCard(
                        personality: personality,
                        isSelected: state.selectedPersonality == personality
                    ) { state.selectedPersonality = personality }
                }
            }
        }
        .foregroundStyle(Theme.paper)
        .padding(34)
        .background(Theme.ink)
    }

    private var footer: some View {
        HStack {
            Text("NOT THE MACOS LOGIN SCREEN. STILL EXTREMELY ANNOYING TO A THIEF.")
            Spacer()
            Text("v1.0 • APPLE SILICON")
        }
        .font(.system(size: 8, weight: .bold, design: .monospaced))
        .padding(.horizontal, 34)
        .frame(height: 64)
    }

    private var sensorColor: Color {
        switch state.sensorStatus {
        case .ready: Color.green
        case .checking: Color.yellow
        default: Theme.orange
        }
    }
}

private struct PersonalityCard: View {
    let personality: AlarmPersonality
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text(String(format: "%02d", (AlarmPersonality.allCases.firstIndex(of: personality) ?? 0) + 1))
                    Spacer()
                    Image(systemName: personality.symbol).font(.system(size: 25, weight: .bold))
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                Spacer()
                Text(personality.name)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .tracking(-1)
                Text(personality.tagline)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .opacity(0.65)
            }
            .foregroundStyle(isSelected ? Theme.ink : Theme.paper)
            .padding(17)
            .frame(maxWidth: .infinity, minHeight: 165, alignment: .leading)
            .background(isSelected ? Theme.orange : Theme.ink)
            .overlay(Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct CalibrationView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 28) {
            Text("\(state.calibrationCountdown)")
                .font(.system(size: 54, weight: .black, design: .rounded))
                .frame(width: 100, height: 100)
                .overlay(Circle().stroke(Theme.paper, lineWidth: 3))
            Text("HANDS OFF.")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(4)
            Text("LEARNING THIS\nEXACT VIBE.")
                .font(.system(size: 76, weight: .black, design: .rounded))
                .tracking(-5)
                .multilineTextAlignment(.center)
                .lineSpacing(-12)
            ProgressView(value: state.calibrationProgress)
                .tint(Theme.acid)
                .frame(maxWidth: 600)
            Text("ESTABLISHING MOTION BASELINE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2)
        }
        .foregroundStyle(Theme.paper)
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.blue)
    }
}

struct LockedCompanionView: View {
    @ObservedObject var state: AppState

    var body: some View {
        LockedView(state: state)
    }
}

private struct LockedView: View {
    @ObservedObject var state: AppState

    var body: some View {
        GeometryReader { geometry in
            let unlockWidth = min(geometry.size.width * 0.44, 360)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 28)

                    StateArtwork(name: state.mode == .armed ? "locked" : "alarm")
                        .frame(
                            width: min(geometry.size.width * 0.58, 620),
                            height: min(geometry.size.height * 0.68, 620)
                        )

                    Spacer(minLength: 24)

                    Button(action: state.requestOwnerUnlock) {
                        UnlockArtwork()
                            .frame(width: unlockWidth, height: unlockWidth / 2)
                    }
                        .buttonStyle(UnlockImageButtonStyle())
                        .disabled(state.isAuthenticationPromptActive)

                    Text(unlockInstruction)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.white.opacity(0.75))
                        .padding(.top, 12)
                        .padding(.bottom, max(36, geometry.safeAreaInsets.bottom + 24))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var unlockInstruction: String {
        if state.isAuthenticationPromptActive { return "TOUCH ID — PLACE YOUR FINGER ON THE SENSOR" }
        if state.touchIDAvailable { return "OWNER UNLOCK — TOUCH ID OR PASSWORD" }
        return "OWNER UNLOCK"
    }
}

private struct StateArtwork: View {
    let name: String

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: name == "locked" ? "lock.fill" : "light.beacon.max.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(name == "locked" ? Color.white : Color.red)
                    .padding(100)
            }
        }
    }

    private func loadImage() -> NSImage? {
        loadImageAsset(named: name)
    }
}

private struct UnlockArtwork: View {
    var body: some View {
        Group {
            if let image = loadImageAsset(named: "unlock") {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Text("UNLOCK")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(Color.black)
                    .frame(width: 220, height: 56)
                    .background(Color.white, in: Capsule())
            }
        }
    }
}

private func loadImageAsset(named name: String) -> NSImage? {
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    let executableFolder = executable.deletingLastPathComponent()
    let workingFolder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let candidates = [
        executableFolder.appendingPathComponent("assets/images/\(name).png"),
        workingFolder.appendingPathComponent("assets/images/\(name).png")
    ]
    return candidates.lazy.compactMap { NSImage(contentsOf: $0) }.first
}

private struct LabelLine: View {
    let number: String
    let text: String
    var inverse = false

    var body: some View {
        HStack(spacing: 9) {
            Text(number)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(inverse ? Theme.ink : Theme.paper)
                .frame(width: 28, height: 19)
                .background(inverse ? Theme.acid : Theme.ink, in: Capsule())
            Text(text).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
        }
    }
}

private struct UtilityButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))
    }
}

private struct UnlockImageButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .contentShape(Rectangle())
    }
}
