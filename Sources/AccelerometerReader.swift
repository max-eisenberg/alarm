import Foundation
import IOKit
import IOKit.hid

enum SensorStartResult {
    case started
    case permissionRequired
    case unavailable
    case failed(String)
}

final class AccelerometerReader {
    typealias SampleHandler = (_ x: Double, _ y: Double, _ z: Double) -> Void

    var onSample: SampleHandler?

    private let reportCapacity = 4096
    private let reportBuffer: UnsafeMutablePointer<UInt8>
    private var device: IOHIDDevice?

    init() {
        reportBuffer = .allocate(capacity: reportCapacity)
        reportBuffer.initialize(repeating: 0, count: reportCapacity)
    }

    deinit {
        stop()
        reportBuffer.deinitialize(count: reportCapacity)
        reportBuffer.deallocate()
    }

    static func isSensorPresent() -> Bool {
        guard let matching = IOServiceMatching("AppleSPUHIDDevice") else { return false }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }
            if integerProperty(service, key: "PrimaryUsagePage") == 0xFF00,
               integerProperty(service, key: "PrimaryUsage") == 3 {
                return true
            }
        }
        return false
    }

    static func inputMonitoringStatus() -> IOHIDAccessType {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    }

    @discardableResult
    static func requestInputMonitoringAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    func requestInputMonitoring() -> Bool {
        Self.requestInputMonitoringAccess()
    }

    func start(requestPermissionIfNeeded: Bool = true) -> SensorStartResult {
        if device != nil { return .started }
        guard Self.isSensorPresent() else { return .unavailable }

        wakeSensorDrivers()

        guard let matching = IOServiceMatching("AppleSPUHIDDevice") else { return .unavailable }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return .failed("Could not enumerate motion hardware.")
        }
        defer { IOObjectRelease(iterator) }

        var accelerometerService: io_service_t = 0
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            if Self.integerProperty(service, key: "PrimaryUsagePage") == 0xFF00,
               Self.integerProperty(service, key: "PrimaryUsage") == 3 {
                accelerometerService = service
                break
            }
            IOObjectRelease(service)
        }

        guard accelerometerService != 0 else { return .unavailable }
        defer { IOObjectRelease(accelerometerService) }
        guard let hidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, accelerometerService) else {
            return .failed("The motion sensor could not be opened.")
        }

        let openResult = IOHIDDeviceOpen(hidDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            if openResult == kIOReturnNotPermitted {
                if requestPermissionIfNeeded {
                    _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
                }
                return .permissionRequired
            }
            return .failed("Motion sensor error: \(openResult)")
        }

        device = hidDevice
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            hidDevice,
            reportBuffer,
            reportCapacity,
            accelerometerReportCallback,
            context
        )
        IOHIDDeviceScheduleWithRunLoop(hidDevice, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        return .started
    }

    func stop() {
        guard let device else { return }
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        self.device = nil
    }

    fileprivate func consume(report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        // Apple has shipped more than one report size for this sensor. The
        // acceleration payload is stable at bytes 6...17, so accept reports
        // with trailing fields instead of silently discarding them.
        guard length >= 18 else { return }

        let x = Self.readInt32LE(report, offset: 6)
        let y = Self.readInt32LE(report, offset: 10)
        let z = Self.readInt32LE(report, offset: 14)
        let scale = 65_536.0
        onSample?(Double(x) / scale, Double(y) / scale, Double(z) / scale)
    }

    private func wakeSensorDrivers() {
        guard let matching = IOServiceMatching("AppleSPUHIDDriver") else { return }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            IORegistryEntrySetCFProperty(service, "SensorPropertyReportingState" as CFString, NSNumber(value: 1))
            IORegistryEntrySetCFProperty(service, "SensorPropertyPowerState" as CFString, NSNumber(value: 1))
            IORegistryEntrySetCFProperty(service, "ReportInterval" as CFString, NSNumber(value: 1_000))
            IOObjectRelease(service)
        }
    }

    private static func integerProperty(_ service: io_service_t, key: String) -> Int? {
        guard let unmanaged = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else { return nil }
        return (unmanaged.takeRetainedValue() as? NSNumber)?.intValue
    }

    private static func readInt32LE(_ bytes: UnsafeMutablePointer<UInt8>, offset: Int) -> Int32 {
        let value = UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
        return Int32(bitPattern: value)
    }
}

private let accelerometerReportCallback: IOHIDReportCallback = { context, result, _, _, _, report, length in
    guard result == kIOReturnSuccess, let context else { return }
    let reader = Unmanaged<AccelerometerReader>.fromOpaque(context).takeUnretainedValue()
    reader.consume(report: report, length: length)
}
