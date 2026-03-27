import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSCommandPalette (Cmd+K Style Search Palette)
// ═══════════════════════════════════════════════════════

public struct DSCommandItem: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let icon: String
    public var tint: Color
    public let action: () -> Void

    public init(id: String = UUID().uuidString, title: String, subtitle: String? = nil, icon: String, tint: Color = Theme.textSecondary, action: @escaping () -> Void) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.icon = icon; self.tint = tint; self.action = action
    }
}

public struct DSCommandPalette: View {
    @Binding public var isPresented: Bool
    public let items: [DSCommandItem]

    @State private var query = ""
    @State private var selectedIndex = 0

    public init(isPresented: Binding<Bool>, items: [DSCommandItem]) {
        self._isPresented = isPresented
        self.items = items
    }

    private var filtered: [DSCommandItem] {
        guard !query.isEmpty else { return items }
        let q = query.lowercased()
        return items.filter {
            $0.title.lowercased().contains(q) ||
            ($0.subtitle?.lowercased().contains(q) ?? false)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: Theme.sp2) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textDim)
                TextField("Type a command...", text: $query)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(13))
                    .foregroundColor(Theme.textPrimary)
                    .onSubmit { executeSelected() }
                    .accessibilityLabel("Command search")

                DSKeyboardShortcut("Esc", compact: true)
            }
            .padding(.horizontal, Theme.sp4)
            .padding(.vertical, Theme.sp3)

            Rectangle().fill(Theme.border).frame(height: 1)

            // Results
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            Button(action: { execute(item) }) {
                                HStack(spacing: Theme.sp3) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(item.tint)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.title)
                                            .font(Theme.mono(11, weight: .medium))
                                            .foregroundColor(Theme.textPrimary)
                                        if let subtitle = item.subtitle {
                                            Text(subtitle)
                                                .font(Theme.mono(9))
                                                .foregroundColor(Theme.textDim)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, Theme.sp4)
                                .padding(.vertical, Theme.sp2)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.cornerSmall)
                                        .fill(index == selectedIndex ? Theme.bgSelected : .clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                            .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, Theme.sp1)
                }
                .frame(maxHeight: 320)
                .onChange(of: selectedIndex) { _, idx in
                    if let item = filtered[safe: idx] {
                        proxy.scrollTo(item.id, anchor: .center)
                    }
                }
            }

            // Footer
            HStack(spacing: Theme.sp4) {
                HStack(spacing: 4) {
                    DSKeyboardShortcut("Up", compact: true)
                    DSKeyboardShortcut("Down", compact: true)
                    Text("navigate")
                        .font(Theme.code(8))
                        .foregroundColor(Theme.textMuted)
                }
                HStack(spacing: 4) {
                    DSKeyboardShortcut("Enter", compact: true)
                    Text("execute")
                        .font(Theme.code(8))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer()
                Text("\(filtered.count) results")
                    .font(Theme.code(8))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, Theme.sp4)
            .padding(.vertical, Theme.sp2)
            .background(Theme.bgSurface)
        }
        .background(RoundedRectangle(cornerRadius: Theme.cornerXL).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerXL).stroke(Theme.border, lineWidth: 1).allowsHitTesting(false))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .frame(width: 500)
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .onKeyPress(.upArrow) { selectedIndex = max(0, selectedIndex - 1); return .handled }
        .onKeyPress(.downArrow) { selectedIndex = min(filtered.count - 1, selectedIndex + 1); return .handled }
        .onKeyPress(.escape) { isPresented = false; return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Command palette")
    }

    private func executeSelected() {
        guard let item = filtered[safe: selectedIndex] else { return }
        execute(item)
    }

    private func execute(_ item: DSCommandItem) {
        isPresented = false
        item.action()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
