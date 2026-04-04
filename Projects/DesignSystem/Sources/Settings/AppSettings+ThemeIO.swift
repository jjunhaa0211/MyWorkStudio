import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension AppSettings {
    public func saveCustomTheme(_ config: CustomThemeConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            if let json = String(data: data, encoding: .utf8) {
                customThemeJSON = json
            }
        } catch {
            print("[도피스] Theme save failed: \(error.localizedDescription)")
        }
    }

    public func exportThemeToFile() {
        let config = customTheme
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data: Data
        do {
            data = try encoder.encode(config)
        } catch {
            print("[도피스] Theme export encoding failed: \(error.localizedDescription)")
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "doffice_theme.json"
        panel.title = NSLocalizedString("settings.customtheme.export", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
            } catch {
                print("[도피스] Theme export write failed: \(error.localizedDescription)")
            }
        }
    }

    public func importThemeFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = NSLocalizedString("settings.customtheme.import", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let config = try JSONDecoder().decode(CustomThemeConfig.self, from: data)
                saveCustomTheme(config)
            } catch {
                print("[도피스] Theme import failed from \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
}
