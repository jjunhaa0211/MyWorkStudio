import SwiftUI
import DesignSystem

@main
struct DesignSystemCatalogApp: App {
    var body: some Scene {
        WindowGroup {
            CatalogRootView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)
    }
}
