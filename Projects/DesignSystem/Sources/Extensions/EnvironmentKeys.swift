import SwiftUI

// MARK: - Resize State Environment Key

private struct IsResizingKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Signals that a resize drag is in progress — heavy views should defer work.
    var isResizing: Bool {
        get { self[IsResizingKey.self] }
        set { self[IsResizingKey.self] = newValue }
    }
}
