import Foundation

// Quick end-to-end check of the native IOKit protocol against the real device.
let light = Busylight()
light.onConnectionChange = { c in print("connection:", c) }

func step(_ name: String, _ work: @escaping () -> Void, at: Double) {
    Timer.scheduledTimer(withTimeInterval: at, repeats: false) { _ in
        print("->", name); work()
    }
}

print("connected at start:", light.isConnected)
step("RED",   { light.setColor(r: 255, g: 0, b: 0) }, at: 0.5)
step("GREEN", { light.setColor(r: 0, g: 255, b: 0) }, at: 2.0)
step("BLUE",  { light.setColor(r: 0, g: 0, b: 255) }, at: 3.5)
step("WHITE", { light.setColor(r: 255, g: 255, b: 255) }, at: 5.0)
step("OFF",   { light.off() }, at: 6.5)
step("done",  { print("DONE"); exit(0) }, at: 7.2)

RunLoop.main.run()
