import SwiftUI
import DesignSystem

struct CatalogRootView: View {
    @State private var selectedSection: CatalogSection? = .colors
    @StateObject private var settings = AppSettings.shared

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
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(CatalogSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            .toolbar {
                ToolbarItem {
                    Button(action: { settings.isDarkMode.toggle() }) {
                        Image(systemName: settings.isDarkMode ? "sun.max.fill" : "moon.fill")
                    }
                }
            }
        } detail: {
            ScrollView {
                detailContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
            }
            .background(Theme.bg)
        }
        .background(Theme.bg)
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
        case .none:
            Text("Select a section")
                .font(Theme.mono(14))
                .foregroundColor(Theme.textDim)
        }
    }
}
