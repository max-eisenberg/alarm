import AppKit
import AudioToolbox
import CoreAudio
import Foundation

final class AlarmAudio {
    private var alarmSound: NSSound?
    private var originalOutputState: OutputState?

    func preview(_: AlarmPersonality) {
        stop()
        playAlarm(looping: false)
    }

    func start(_: AlarmPersonality) {
        stop()
        forceMaximumOutputVolume()
        playAlarm(looping: true)
    }

    func stop() {
        alarmSound?.stop()
        alarmSound = nil
        restoreOutputVolume()
    }

    private func playAlarm(looping: Bool) {
        guard let url = alarmFileURL(),
              let sound = NSSound(contentsOf: url, byReference: false) else {
            NSSound.beep()
            return
        }
        sound.loops = looping
        sound.volume = 1
        alarmSound = sound
        sound.play()
    }

    private func alarmFileURL() -> URL? {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let workingFolder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            executable.deletingLastPathComponent().appendingPathComponent("assets/audio/alarm.mp3"),
            workingFolder.appendingPathComponent("assets/audio/alarm.mp3")
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private struct OutputState {
        let device: AudioDeviceID
        let volumeSelector: AudioObjectPropertySelector?
        let volume: Float32?
        let mute: UInt32?
    }

    private func forceMaximumOutputVolume() {
        guard originalOutputState == nil, let device = defaultOutputDevice() else { return }

        let virtualVolume = kAudioHardwareServiceDeviceProperty_VirtualMainVolume
        let volumeSelector: AudioObjectPropertySelector? = propertyExists(
            device: device,
            selector: virtualVolume
        ) ? virtualVolume : (propertyExists(device: device, selector: kAudioDevicePropertyVolumeScalar)
            ? kAudioDevicePropertyVolumeScalar
            : nil)

        let oldVolume = volumeSelector.flatMap { readFloat(device: device, selector: $0) }
        let oldMute = readUInt32(device: device, selector: kAudioDevicePropertyMute)
        originalOutputState = OutputState(
            device: device,
            volumeSelector: volumeSelector,
            volume: oldVolume,
            mute: oldMute
        )

        if oldMute != nil {
            writeUInt32(0, device: device, selector: kAudioDevicePropertyMute)
        }
        if let volumeSelector {
            writeFloat(1, device: device, selector: volumeSelector)
        }
    }

    private func restoreOutputVolume() {
        guard let state = originalOutputState else { return }
        originalOutputState = nil
        if let volume = state.volume, let selector = state.volumeSelector {
            writeFloat(volume, device: state.device, selector: selector)
        }
        if let mute = state.mute {
            writeUInt32(mute, device: state.device, selector: kAudioDevicePropertyMute)
        }
    }

    private func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &device
        )
        return result == noErr && device != kAudioObjectUnknown ? device : nil
    }

    private func propertyAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func propertyExists(device: AudioDeviceID, selector: AudioObjectPropertySelector) -> Bool {
        var address = propertyAddress(selector)
        return AudioObjectHasProperty(device, &address)
    }

    private func readFloat(device: AudioDeviceID, selector: AudioObjectPropertySelector) -> Float32? {
        var address = propertyAddress(selector)
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private func writeFloat(_ value: Float32, device: AudioDeviceID, selector: AudioObjectPropertySelector) {
        var address = propertyAddress(selector)
        var mutableValue = value
        let size = UInt32(MemoryLayout<Float32>.size)
        _ = AudioObjectSetPropertyData(device, &address, 0, nil, size, &mutableValue)
    }

    private func readUInt32(device: AudioDeviceID, selector: AudioObjectPropertySelector) -> UInt32? {
        var address = propertyAddress(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private func writeUInt32(_ value: UInt32, device: AudioDeviceID, selector: AudioObjectPropertySelector) {
        var address = propertyAddress(selector)
        var mutableValue = value
        let size = UInt32(MemoryLayout<UInt32>.size)
        _ = AudioObjectSetPropertyData(device, &address, 0, nil, size, &mutableValue)
    }
}
