import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Spacing, Sizing & Corner System
// ═══════════════════════════════════════════════════════
//
// 4px base grid. All spacing in multiples of 4.

public enum DSSpacing {
    // ── Grid Units ──
    public static let sp1: CGFloat = 4
    public static let sp2: CGFloat = 8
    public static let sp3: CGFloat = 12
    public static let sp4: CGFloat = 16
    public static let sp5: CGFloat = 20
    public static let sp6: CGFloat = 24
    public static let sp8: CGFloat = 32

    // ── Row Heights ──
    public static let rowCompact: CGFloat = 28
    public static let rowDefault: CGFloat = 36
    public static let rowComfortable: CGFloat = 44

    // ── Panel & Toolbar ──
    public static let panelPadding: CGFloat = 16
    public static let cardPadding: CGFloat = 12
    public static let toolbarHeight: CGFloat = 36
    public static let sidebarItemHeight: CGFloat = 30
}

public enum DSCorners {
    /// Badges, tags, small chips
    public static let small: CGFloat = 5
    /// Buttons, inputs, select
    public static let medium: CGFloat = 6
    /// Cards, panels, dialogs
    public static let large: CGFloat = 8
    /// Modals, sheets, large containers
    public static let xl: CGFloat = 12
}

public enum DSBorder {
    public static let width: CGFloat = 1.0
    public static let activeOpacity: CGFloat = 1.0
    public static let lightOpacity: CGFloat = 0.6

    // ── Interaction state opacities ──
    public static let hoverOpacity: CGFloat = 0.08
    public static let pressedOpacity: CGFloat = 0.12
    public static let strokeActiveOpacity: CGFloat = 0.25
    public static let strokeInactiveOpacity: CGFloat = 0.15
}

// ═══════════════════════════════════════════════════════
// MARK: - Animation Tokens
// ═══════════════════════════════════════════════════════

public enum DSAnimation {
    /// Micro interactions (button press, toggle)
    public static let fast: Double = 0.12
    /// Standard transitions (panel open, tab switch)
    public static let normal: Double = 0.2
    /// Deliberate transitions (modal appear, page change)
    public static let slow: Double = 0.35

    /// Spring presets
    public static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    public static let springGentle = Animation.spring(response: 0.45, dampingFraction: 0.8)
    public static let springBouncy = Animation.spring(response: 0.35, dampingFraction: 0.5)

    /// Easing presets
    public static let easeOut = Animation.easeOut(duration: normal)
    public static let easeInOut = Animation.easeInOut(duration: normal)
}

// ═══════════════════════════════════════════════════════
// MARK: - Opacity Tokens
// ═══════════════════════════════════════════════════════

public enum DSOpacity {
    public static let disabled: Double = 0.4
    public static let dimmed: Double = 0.6
    public static let subtle: Double = 0.08
    public static let medium: Double = 0.15
    public static let prominent: Double = 0.25
    public static let overlay: Double = 0.7
}
