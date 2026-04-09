import Foundation

// MARK: - PluginHostProviding

/// PluginHost 런타임 확장 관리 인터페이스.
public protocol PluginHostProviding: AnyObject {
    var panels: [PluginHost.LoadedPanel] { get }
    var commands: [PluginHost.LoadedCommand] { get }
    var themes: [PluginHost.LoadedTheme] { get }
    var furniture: [PluginHost.LoadedFurniture] { get }
    var officePresets: [PluginHost.LoadedOfficePreset] { get }
    var effects: [PluginHost.LoadedEffect] { get }
    var lastPluginError: String? { get }

    func fireEvent(_ event: PluginEventType, context: [String: Any])
    func reload()
    func applyTheme(_ theme: PluginHost.LoadedTheme)
}

// MARK: - PluginManaging

/// PluginManager 플러그인 라이프사이클 관리 인터페이스.
public protocol PluginManaging: AnyObject {
    var plugins: [PluginEntry] { get }
    var activePluginPaths: [String] { get }
    var isInstalling: Bool { get }

    func install(source: String)
    func isExtensionEnabled(_ extensionId: String) -> Bool
    func toggleExtension(_ extensionId: String)
    func isPluginTrusted(_ pluginName: String) -> Bool
    func trustPlugin(_ pluginName: String)
}
