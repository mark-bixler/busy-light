import SwiftUI
import AppKit

/// App state: owns the Busylight controller and tracks UI state.
@MainActor
final class LightModel: ObservableObject {
    @Published var connected = false
    @Published var activeLabel: String? = nil
    @Published var presets: [LightPreset] = Palette.load()

    private let light = Busylight()

    init() {
        light.onConnectionChange = { [weak self] connected in
            self?.connected = connected
        }
        connected = light.isConnected
        Palette.writeDefaultIfMissing()
    }

    func select(_ preset: LightPreset) {
        light.setColor(r: preset.r, g: preset.g, b: preset.b)
        activeLabel = preset.label
    }

    func turnOff() {
        light.off()
        activeLabel = nil
    }

    func reloadPalette() {
        presets = Palette.load()
    }

    /// The color currently shown on the light, if any (drives the menu-bar icon tint).
    var activeColor: Color? {
        presets.first { $0.label == activeLabel }?.color
    }
}

@main
struct BusylightMenuApp: App {
    @StateObject private var model = LightModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(model)
        } label: {
            // Beacon glyph that tints to the active status color (gray when off).
            Image(systemName: model.activeColor == nil ? "light.beacon.min" : "light.beacon.max.fill")
                .foregroundStyle(model.activeColor ?? Color.primary)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @EnvironmentObject var model: LightModel

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Busylight")
                    .font(.headline)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(model.connected ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(model.connected ? "Connected" : "Not found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(model.presets) { preset in
                    ColorButton(preset: preset, isActive: model.activeLabel == preset.label) {
                        model.select(preset)
                    }
                }
            }

            Divider()

            HStack {
                Button("Off") { model.turnOff() }
                Spacer()
                Button("Reload palette") { model.reloadPalette() }
                    .help("Re-read ~/.config/busylight/palette.json")
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .font(.callout)
        }
        .padding(14)
        .frame(width: 320)
    }
}

struct ColorButton: View {
    let preset: LightPreset
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(preset.color)
                    .frame(height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isActive ? Color.primary : Color.black.opacity(0.15),
                                          lineWidth: isActive ? 2.5 : 1)
                    )
                Text(preset.label)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }
}
