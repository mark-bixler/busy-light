import Foundation
import IOKit
import IOKit.hid

/// Talks to a Kuando Busylight Alpha over USB-HID.
///
/// Protocol (reverse-engineered from the device + the busylight-core reference
/// implementation): commands are a fixed 64-byte HID output report (report id 0)
/// made of seven 8-byte "steps" followed by an 8-byte footer.
///
/// We only ever use step 0:
///   - "jump" sets the color and loops (opcode 0x1)
///   - "keepalive" refreshes the device's alive timer (opcode 0x8)
///
/// The footer carries a 0xFFF pad and a 16-bit big-endian checksum = the sum of
/// every byte in the buffer except the two checksum bytes themselves.
///
/// The Alpha quiesces if it doesn't hear from us, so we resend a keepalive on a
/// timer. Color values are scaled from 0-255 down to the device's 0-100 range.
final class Busylight {

    // Plenom/Kuando vendor id, and the product ids that identify a Busylight Alpha.
    private static let vendorID = 0x27BB
    private static let alphaProductIDs: Set<Int> = [0x3BCA, 0x3BCB, 0x3BCE]
    // The Mic-chip variant of the Alpha uses a different VID/PID.
    private static let altVendorID = 0x04D8
    private static let altProductIDs: Set<Int> = [0xF848]

    private let manager: IOHIDManager
    private var device: IOHIDDevice?
    private var keepAliveTimer: Timer?
    private var currentColor: (r: Int, g: Int, b: Int) = (0, 0, 0)

    /// Called on the main thread whenever the connection state changes.
    var onConnectionChange: ((Bool) -> Void)?

    var isConnected: Bool { device != nil }

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, nil) // match everything; we filter below
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, dev in
            let me = Unmanaged<Busylight>.fromOpaque(ctx!).takeUnretainedValue()
            me.deviceAttached(dev)
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, dev in
            let me = Unmanaged<Busylight>.fromOpaque(ctx!).takeUnretainedValue()
            me.deviceRemoved(dev)
        }, ctx)

        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    // MARK: - Device matching

    private static func isBusylight(_ dev: IOHIDDevice) -> Bool {
        let vid = intProperty(dev, kIOHIDVendorIDKey)
        let pid = intProperty(dev, kIOHIDProductIDKey)
        if vid == vendorID && alphaProductIDs.contains(pid) { return true }
        if vid == altVendorID && altProductIDs.contains(pid) { return true }
        return false
    }

    private static func intProperty(_ dev: IOHIDDevice, _ key: String) -> Int {
        guard let ref = IOHIDDeviceGetProperty(dev, key as CFString) else { return -1 }
        return (ref as? Int) ?? -1
    }

    private func deviceAttached(_ dev: IOHIDDevice) {
        guard Busylight.isBusylight(dev), device == nil else { return }
        guard IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { return }
        device = dev
        // Re-apply whatever color we were showing, and start the keepalive.
        applyColor(currentColor)
        DispatchQueue.main.async { self.onConnectionChange?(true) }
    }

    private func deviceRemoved(_ dev: IOHIDDevice) {
        guard dev == device else { return }
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        device = nil
        DispatchQueue.main.async { self.onConnectionChange?(false) }
    }

    // MARK: - Public control

    /// Set the light to an sRGB color (each component 0-255).
    func setColor(r: Int, g: Int, b: Int) {
        currentColor = (r, g, b)
        applyColor(currentColor)
    }

    func off() {
        setColor(r: 0, g: 0, b: 0)
    }

    // MARK: - Command building & sending

    private func applyColor(_ c: (r: Int, g: Int, b: Int)) {
        send(Self.jumpBuffer(r: c.r, g: c.g, b: c.b))
        restartKeepAlive()
    }

    private func restartKeepAlive() {
        keepAliveTimer?.invalidate()
        // Reference uses a 10s refresh / 15s timeout. Resend a bit early at 8s.
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            self?.send(Self.keepAliveBuffer(timeout: 15))
        }
    }

    @discardableResult
    private func send(_ buffer: [UInt8]) -> Bool {
        guard let device else { return false }
        let result = buffer.withUnsafeBufferPointer { ptr in
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(0), ptr.baseAddress!, CFIndex(buffer.count))
        }
        return result == kIOReturnSuccess
    }

    /// Scale a 0-255 component into the device's 0-100 range.
    private static func scale(_ v: Int) -> UInt8 {
        let clamped = max(0, min(255, v))
        return UInt8(Int((Double(clamped) / 255.0) * 100.0))
    }

    /// Build a 64-byte buffer with step 0 set to the given command bytes.
    private static func buffer(step0: [UInt8]) -> [UInt8] {
        precondition(step0.count == 8)
        var buf = [UInt8](repeating: 0, count: 64)
        for i in 0..<8 { buf[i] = step0[i] }
        // Footer occupies bytes 56...63. Pad 0xFFF lives at bytes 60,61.
        buf[60] = 0x0F
        buf[61] = 0xFF
        // 16-bit big-endian checksum over every byte except the two checksum bytes.
        var sum = 0
        for i in 0..<62 { sum += Int(buf[i]) }
        buf[62] = UInt8((sum >> 8) & 0xFF)
        buf[63] = UInt8(sum & 0xFF)
        return buf
    }

    /// "Jump" step: show a steady color and loop on step 0.
    static func jumpBuffer(r: Int, g: Int, b: Int) -> [UInt8] {
        // byte0 = opcode(0x1)<<4 | operand(target step 0) = 0x10
        let step0: [UInt8] = [0x10, 0x00, scale(r), scale(g), scale(b), 0x00, 0x00, 0x00]
        return buffer(step0: step0)
    }

    /// "KeepAlive" step: refresh the device's alive timer (keeps current color).
    static func keepAliveBuffer(timeout: Int) -> [UInt8] {
        // byte0 = opcode(0x8)<<4 | operand(timeout seconds, low nibble)
        let byte0 = UInt8(0x80 | (timeout & 0x0F))
        let step0: [UInt8] = [byte0, 0, 0, 0, 0, 0, 0, 0]
        return buffer(step0: step0)
    }
}
