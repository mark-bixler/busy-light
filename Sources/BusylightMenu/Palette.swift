import Foundation
import SwiftUI

/// One labeled button in the grid: a meaning ("Busy") and the color it shows.
struct LightPreset: Identifiable, Codable {
    var id: String { label }
    var label: String        // what the color means, shown on the button
    var r: Int
    var g: Int
    var b: Int

    var color: Color { Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }
}

/// Loads the user's palette from ~/.config/busylight/palette.json if present,
/// otherwise falls back to a built-in starter palette. Edit the JSON and reopen
/// the menu to change colors/labels without rebuilding.
enum Palette {

    static var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/busylight/palette.json")
    }

    /// Starter palette. Replace these with your own colors + meanings (or edit the JSON file).
    static let builtIn: [LightPreset] = [
        LightPreset(label: "Available", r: 0,   g: 255, b: 0),
        LightPreset(label: "Busy",      r: 255, g: 0,   b: 0),
        LightPreset(label: "In a meeting", r: 255, g: 60, b: 0),
        LightPreset(label: "Away",      r: 255, g: 200, b: 0),
        LightPreset(label: "Focus / DND", r: 150, g: 0, b: 255),
        LightPreset(label: "Heads down", r: 0, g: 120, b: 255),
    ]

    static func load() -> [LightPreset] {
        guard let data = try? Data(contentsOf: configURL),
              let presets = try? JSONDecoder().decode([LightPreset].self, from: data),
              !presets.isEmpty
        else { return builtIn }
        return presets
    }

    /// Write the built-in palette to the config path so the user has a file to edit.
    @discardableResult
    static func writeDefaultIfMissing() -> Bool {
        let url = configURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return false }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(builtIn) else { return false }
        try? data.write(to: url)
        return true
    }
}
