import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension AppSettings {
    public func saveCustomTheme(_ config: CustomThemeConfig) {
        if let data = try? JSONEncoder().encode(config),
           let json = String(data: data, encoding: .utf8) {
            customThemeJSON = json
        }
    }

    public func exportThemeToFile() {
        let config = customTheme
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(config) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "doffice_theme.json"
        panel.title = NSLocalizedString("settings.customtheme.export", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    public func importThemeFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = NSLocalizedString("settings.customtheme.import", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            guard let data = try? Data(contentsOf: url),
                  let config = try? JSONDecoder().decode(CustomThemeConfig.self, from: data) else { return }
            saveCustomTheme(config)
        }
    }
}
