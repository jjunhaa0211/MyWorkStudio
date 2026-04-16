import SwiftUI
import DesignSystem

struct CatalogRootView: View {
    @State private var selectedSection: CatalogSection? = .colors
    @ObservedObject private var settings = AppSettings.shared

    enum CatalogSection: String, CaseIterable, Identifiable, Hashable {
        case colors = "Colors"
        case typography = "Typography"
        case spacing = "Spacing"
        case badges = "Badges"
        case buttons = "Buttons"
        case fields = "Fields"
        case modals = "Modals"
        case lists = "Lists"
        case cards = "Cards"
        case navigation = "Navigation"
        case indicators = "Indicators"
        case toasts = "Toasts"
        case callouts = "Callouts"
        case skeleton = "Skeleton"
        case accordion = "Accordion"
        case keyboard = "Keyboard"
        case avatar = "Avatar"
        case toggle = "Toggle"
        case tooltip = "Tooltip"
        case divider = "Divider"
        case badgeCount = "Badge Count"
        case segmented = "Segmented"
        case search = "Search"
        case codeBlock = "Code Block"
        case timeline = "Timeline"
        case colorPicker = "Color Picker"
        case ring = "Ring"
        case diff = "Diff"
        case splitPane = "Split Pane"
        case shortcutRecorder = "Shortcut Rec."
        case syntax = "Syntax"
        case chart = "Chart"
        case commandPalette = "Cmd Palette"
        case contextMenu = "Context Menu"
        case modifiers = "Modifiers"
        case extensions = "Extensions"
        case notifications = "Notifications"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .colors: return "paintpalette.fill"
            case .typography: return "textformat"
            case .spacing: return "ruler"
            case .badges: return "seal.fill"
            case .buttons: return "rectangle.fill"
            case .fields: return "character.cursor.ibeam"
            case .modals: return "rectangle.stack.fill"
            case .lists: return "list.bullet"
            case .cards: return "rectangle.on.rectangle"
            case .navigation: return "arrow.triangle.branch"
            case .indicators: return "circle.dotted"
            case .toasts: return "bell.badge.fill"
            case .callouts: return "exclamationmark.bubble.fill"
            case .skeleton: return "rectangle.dashed"
            case .accordion: return "rectangle.expand.vertical"
            case .keyboard: return "keyboard"
            case .avatar: return "person.crop.circle.fill"
            case .toggle: return "switch.2"
            case .tooltip: return "text.bubble"
            case .divider: return "minus"
            case .badgeCount: return "app.badge.fill"
            case .segmented: return "rectangle.split.3x1"
            case .search: return "magnifyingglass"
            case .codeBlock: return "chevron.left.forwardslash.chevron.right"
            case .timeline: return "clock.arrow.circlepath"
            case .colorPicker: return "eyedropper"
            case .ring: return "circle.circle"
            case .diff: return "plus.forwardslash.minus"
            case .splitPane: return "rectangle.split.2x1"
            case .shortcutRecorder: return "record.circle"
            case .syntax: return "paintbrush.pointed.fill"
            case .chart: return "chart.bar.fill"
            case .commandPalette: return "command"
            case .contextMenu: return "cursorarrow.and.square.on.square.dashed"
            case .modifiers: return "wand.and.stars"
            case .extensions: return "puzzlepiece.fill"
            case .notifications: return "bell.and.waves.left.and.right"
            }
        }

        var accent: Color {
            switch self {
            case .colors, .colorPicker: return Theme.cyan
            case .typography, .codeBlock, .syntax: return Theme.purple
            case .spacing, .splitPane, .divider: return Theme.orange
            case .badges, .indicators, .ring, .badgeCount: return Theme.green
            case .buttons, .commandPalette, .shortcutRecorder: return Theme.accent
            case .fields, .search, .contextMenu: return Theme.yellow
            case .cards, .lists, .timeline, .chart: return Theme.orange
            case .navigation, .segmented, .toggle: return Theme.cyan
            case .modals, .toasts, .callouts, .tooltip: return Theme.red
            case .accordion, .avatar, .keyboard, .diff, .skeleton: return Theme.green
            case .modifiers, .extensions, .notifications: return Theme.purple
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 18) {
                sidebarHeader

                List(CatalogSection.allCases, selection: $selectedSection) { section in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.bgSurface)
                                .frame(width: 28, height: 28)
                            Image(systemName: section.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }

                        Text(section.rawValue)
                            .font(Theme.mono(10.5, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(.vertical, 4)
                    .tag(section)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .padding(18)
            .frame(minWidth: 240)
            .background(Theme.bg)
            .toolbar {
                ToolbarItem {
                    themeToggleButton
                }
            }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    detailHero
                    detailContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(28)
            }
            .background(Theme.bg)
        }
        .background(Theme.bg)
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Doffice")
                .font(Theme.chrome(9, weight: .bold))
                .tracking(1.8)
                .foregroundColor(Theme.textDim)
            Text("Design System")
                .font(Theme.mono(20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text("\(CatalogSection.allCases.count) components")
                .font(Theme.mono(10))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerXL)
                .fill(Theme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerXL)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var detailHero: some View {
        let section = selectedSection ?? .colors
        return VStack(alignment: .leading, spacing: 10) {
            Text("COMPONENT")
                .font(Theme.chrome(8.5, weight: .bold))
                .tracking(1.8)
                .foregroundColor(Theme.textDim)
            Text(section.rawValue)
                .font(Theme.mono(24, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 10) {
                themeToggleButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerXL)
                .fill(Theme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerXL)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var themeToggleButton: some View {
        DSButton(
            settings.isDarkMode ? "Light" : "Dark",
            icon: settings.isDarkMode ? "sun.max.fill" : "moon.fill",
            tone: .neutral,
            prominent: false,
            compact: true
        ) {
            settings.isDarkMode.toggle()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .colors: ColorsCatalog()
        case .typography: TypographyCatalog()
        case .spacing: SpacingCatalog()
        case .badges: BadgesCatalog()
        case .buttons: ButtonsCatalog()
        case .fields: FieldsCatalog()
        case .modals: ModalsCatalog()
        case .lists: ListsCatalog()
        case .cards: CardsCatalog()
        case .navigation: NavigationCatalog()
        case .indicators: IndicatorsCatalog()
        case .toasts: ToastCatalog()
        case .callouts: CalloutCatalog()
        case .skeleton: SkeletonCatalog()
        case .accordion: AccordionCatalog()
        case .keyboard: KeyboardCatalog()
        case .avatar: AvatarCatalog()
        case .toggle: ToggleCatalog()
        case .tooltip: TooltipCatalog()
        case .divider: DividerCatalog()
        case .badgeCount: BadgeCountCatalog()
        case .segmented: SegmentedCatalog()
        case .search: SearchCatalog()
        case .codeBlock: CodeBlockCatalog()
        case .timeline: TimelineCatalog()
        case .colorPicker: ColorPickerCatalog()
        case .ring: RingCatalog()
        case .diff: DiffCatalog()
        case .splitPane: SplitPaneCatalog()
        case .shortcutRecorder: ShortcutRecorderCatalog()
        case .syntax: SyntaxCatalog()
        case .chart: ChartCatalog()
        case .commandPalette: CommandPaletteCatalog()
        case .contextMenu: ContextMenuCatalog()
        case .modifiers: ModifiersCatalog()
        case .extensions: ExtensionsCatalog()
        case .notifications: NotificationsCatalog()
        case .none:
            Text("Select a section")
                .font(Theme.mono(14))
                .foregroundColor(Theme.textDim)
        }
    }
}
