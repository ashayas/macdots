import Foundation
import IOKit
import IOKit.hid

/// High-performance IOKit driver reading the internal MEMS IMU on Apple Silicon MacBooks (M1-M5)
/// Connects to AppleSPUHIDDevice (Bosch BMI286 or similar IMU) via unprivileged IOKit HID.
public final class AppleSiliconIMU: @unchecked Sendable, MotionSensorProtocol {
    public let sourceType: SensorSourceType = .hardwareIMU

    private let queue = DispatchQueue(label: "com.macdots.imu", qos: .userInteractive)
    private var handler: (@Sendable (MotionSample) -> Void)?

    private var workerThread: Thread?
    private var workerRunLoop: CFRunLoop?
    private var isStopping = false

    private var accelDevice: IOHIDDevice?
    private var gyroDevice: IOHIDDevice?
    private var accelBuffer: UnsafeMutablePointer<UInt8>?
    private var gyroBuffer: UnsafeMutablePointer<UInt8>?

    // Internal state cache for fusing accel + gyro
    private var latestAccel = Vector3(x: 0, y: 0, z: -1)
    private var latestGyro = Vector3.zero
    private var lock = os_unfair_lock()

    public init() {}

    public var isAvailable: Bool {
        checkHardwareAvailable()
    }

    public private(set) var isRunning: Bool = false

    private func checkHardwareAvailable() -> Bool {
        let matching = IOServiceMatching("AppleSPUHIDDevice")
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS, iterator != 0 else { return false }
        defer { IOObjectRelease(iterator) }

        var svc = IOIteratorNext(iterator)
        while svc != 0 {
            defer { IOObjectRelease(svc); svc = IOIteratorNext(iterator) }
            if let upRef = IORegistryEntryCreateCFProperty(svc, "PrimaryUsagePage" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber,
               let uRef = IORegistryEntryCreateCFProperty(svc, "PrimaryUsage" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
                if upRef.intValue == 0xFF00 && uRef.intValue == 3 {
                    return true
                }
            }
        }
        return false
    }

    public func start(handler: @escaping @Sendable (MotionSample) -> Void) {
        guard !isRunning else { return }
        self.handler = handler
        self.isStopping = false
        self.isRunning = true

        let thread = Thread { [weak self] in
            self?.runWorkerLoop()
        }
        thread.name = "com.macdots.imu.worker"
        thread.qualityOfService = .userInteractive
        self.workerThread = thread
        thread.start()
    }

    public func stop() {
        guard isRunning else { return }
        isStopping = true
        isRunning = false

        if let rl = workerRunLoop {
            CFRunLoopStop(rl)
        }
        workerThread = nil
        workerRunLoop = nil

        cleanupDevices()
    }

    private func wakeSPUDrivers() {
        let matching = IOServiceMatching("AppleSPUHIDDriver")
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS, iterator != 0 else { return }
        defer { IOObjectRelease(iterator) }

        var svc = IOIteratorNext(iterator)
        while svc != 0 {
            let repState = 1 as CFNumber
            let pwrState = 1 as CFNumber
            let interval = 10000 as CFNumber // 10ms (100 Hz report rate)

            IORegistryEntrySetCFProperty(svc, "SensorPropertyReportingState" as CFString, repState)
            IORegistryEntrySetCFProperty(svc, "SensorPropertyPowerState" as CFString, pwrState)
            IORegistryEntrySetCFProperty(svc, "ReportInterval" as CFString, interval)

            IOObjectRelease(svc)
            svc = IOIteratorNext(iterator)
        }
    }

    private func findSPUDevices() -> (accel: IOHIDDevice?, gyro: IOHIDDevice?) {
        let matching = IOServiceMatching("AppleSPUHIDDevice")
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS, iterator != 0 else { return (nil, nil) }
        defer { IOObjectRelease(iterator) }

        var foundAccel: IOHIDDevice?
        var foundGyro: IOHIDDevice?

        var svc = IOIteratorNext(iterator)
        while svc != 0 {
            if let upRef = IORegistryEntryCreateCFProperty(svc, "PrimaryUsagePage" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber,
               let uRef = IORegistryEntryCreateCFProperty(svc, "PrimaryUsage" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
                let up = upRef.intValue
                let u = uRef.intValue

                if up == 0xFF00 && u == 3 && foundAccel == nil {
                    foundAccel = IOHIDDeviceCreate(kCFAllocatorDefault, svc)
                } else if up == 0xFF00 && u == 9 && foundGyro == nil {
                    foundGyro = IOHIDDeviceCreate(kCFAllocatorDefault, svc)
                }
            }
            IOObjectRelease(svc)
            if foundAccel != nil && foundGyro != nil { break }
            svc = IOIteratorNext(iterator)
        }

        return (foundAccel, foundGyro)
    }

    private func runWorkerLoop() {
        workerRunLoop = CFRunLoopGetCurrent()

        // 1. Wake the SPU drivers
        wakeSPUDrivers()

        // 2. Discover devices
        let (accel, gyro) = findSPUDevices()
        self.accelDevice = accel
        self.gyroDevice = gyro

        let accelBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        let gyroBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        self.accelBuffer = accelBuf
        self.gyroBuffer = gyroBuf

        let unmanagedSelf = Unmanaged.passUnretained(self).toOpaque()

        // Accel callback
        if let dev = accelDevice {
            let kr = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
            if kr == KERN_SUCCESS {
                let accelCB: IOHIDReportCallback = { context, result, sender, type, reportID, report, reportLength in
                    guard let ctx = context, reportLength >= 18 else { return }
                    let me = Unmanaged<AppleSiliconIMU>.fromOpaque(ctx).takeUnretainedValue()
                    me.handleAccelReport(report: report, length: reportLength)
                }
                IOHIDDeviceRegisterInputReportCallback(dev, accelBuf, 64, accelCB, unmanagedSelf)
                IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            }
        }

        // Gyro callback
        if let dev = gyroDevice {
            let kr = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
            if kr == KERN_SUCCESS {
                let gyroCB: IOHIDReportCallback = { context, result, sender, type, reportID, report, reportLength in
                    guard let ctx = context, reportLength >= 18 else { return }
                    let me = Unmanaged<AppleSiliconIMU>.fromOpaque(ctx).takeUnretainedValue()
                    me.handleGyroReport(report: report, length: reportLength)
                }
                IOHIDDeviceRegisterInputReportCallback(dev, gyroBuf, 64, gyroCB, unmanagedSelf)
                IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            }
        }

        // Run until stopped
        while !isStopping {
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.25, false)
        }

        cleanupDevices()
    }

    private func handleAccelReport(report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        let x = report.advanced(by: 6).withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        let y = report.advanced(by: 10).withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        let z = report.advanced(by: 14).withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }

        // Scale Q16 to G
        let accel = Vector3(
            x: Double(x) / 65536.0,
            y: Double(y) / 65536.0,
            z: Double(z) / 65536.0
        )

        var gyroCopy: Vector3 = .zero
        os_unfair_lock_lock(&lock)
        latestAccel = accel
        gyroCopy = latestGyro
        os_unfair_lock_unlock(&lock)

        let sample = MotionSample(
            acceleration: accel,
            rotationRate: gyroCopy,
            sourceType: .hardwareIMU
        )
        handler?(sample)
    }

    private func handleGyroReport(report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        let gx = report.advanced(by: 6).withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        let gy = report.advanced(by: 10).withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        let gz = report.advanced(by: 14).withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }

        let gyro = Vector3(
            x: Double(gx) / 65536.0,
            y: Double(gy) / 65536.0,
            z: Double(gz) / 65536.0
        )

        os_unfair_lock_lock(&lock)
        latestGyro = gyro
        os_unfair_lock_unlock(&lock)
    }

    private func cleanupDevices() {
        if let dev = accelDevice {
            IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone))
            accelDevice = nil
        }
        if let dev = gyroDevice {
            IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone))
            gyroDevice = nil
        }
        if let b = accelBuffer {
            b.deallocate()
            accelBuffer = nil
        }
        if let b = gyroBuffer {
            b.deallocate()
            gyroBuffer = nil
        }
    }

    deinit {
        stop()
    }
}
