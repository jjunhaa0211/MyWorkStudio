import SwiftUI
import WebKit
import Combine
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Browser Tab Model
// ═══════════════════════════════════════════════════════

public struct BrowserTab: Identifiable, Equatable {
    public let id: UUID
    public var url: URL?
    public var title: String
    public var isLoading: Bool
    public var canGoBack: Bool
    public var canGoForward: Bool
    public var estimatedProgress: Double

    public init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String = "New Tab",
        isLoading: Bool = false,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        estimatedProgress: Double = 0
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.isLoading = isLoading
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.estimatedProgress = estimatedProgress
    }

    public var displayTitle: String {
        if title.isEmpty || title == "about:blank" { return "New Tab" }
        return title
    }

    public var displayURL: String {
        url?.absoluteString ?? "about:blank"
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Bookmark Model
// ═══════════════════════════════════════════════════════

public struct BrowserBookmark: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var urlString: String

    public init(id: UUID = UUID(), title: String, urlString: String) {
        self.id = id
        self.title = title
        self.urlString = urlString
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Browser Manager
// ═══════════════════════════════════════════════════════

public class BrowserManager: ObservableObject {
    public static let shared = BrowserManager()

    @Published public var tabs: [BrowserTab] = []
    @Published public var activeTabId: UUID?
    @Published public var bookmarks: [BrowserBookmark] = []
    @Published public var showBookmarks: Bool = false

    // Navigation command — coordinator observes this
    public enum NavCommand: Equatable {
        case navigate(UUID, URL)
        case goBack(UUID)
        case goForward(UUID)
        case reload(UUID)
    }
    @Published public var pendingCommand: NavCommand?

    private let bookmarksKey = "browser_bookmarks"

    public init() {
        loadBookmarks()
        if tabs.isEmpty { createNewTab() }
    }

    public func navigate(tabId: UUID, to url: URL) {
        pendingCommand = .navigate(tabId, url)
    }
    public func goBack(tabId: UUID) { pendingCommand = .goBack(tabId) }
    public func goForward(tabId: UUID) { pendingCommand = .goForward(tabId) }
    public func reload(tabId: UUID) { pendingCommand = .reload(tabId) }

    public var activeTab: BrowserTab? {
        tabs.first(where: { $0.id == activeTabId })
    }

    public var activeTabIndex: Int? {
        tabs.firstIndex(where: { $0.id == activeTabId })
    }

    // ── Tab Management ──

    @discardableResult
    public func createNewTab(url: URL? = nil) -> UUID {
        let tab = BrowserTab(url: url)
        tabs.append(tab)
        activeTabId = tab.id
        return tab.id
    }

    public func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        if let idx = tabs.firstIndex(where: { $0.id == id }) {
            let wasActive = activeTabId == id
            tabs.remove(at: idx)
            if wasActive {
                let newIdx = min(idx, tabs.count - 1)
                activeTabId = tabs[newIdx].id
            }
        }
    }

    public func selectTab(_ id: UUID) {
        activeTabId = id
    }

    public func updateTab(id: UUID, title: String? = nil, url: URL? = nil,
                   isLoading: Bool? = nil, canGoBack: Bool? = nil,
                   canGoForward: Bool? = nil, estimatedProgress: Double? = nil) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        if let title = title { tabs[idx].title = title }
        if let url = url { tabs[idx].url = url }
        if let isLoading = isLoading { tabs[idx].isLoading = isLoading }
        if let canGoBack = canGoBack { tabs[idx].canGoBack = canGoBack }
        if let canGoForward = canGoForward { tabs[idx].canGoForward = canGoForward }
        if let estimatedProgress = estimatedProgress { tabs[idx].estimatedProgress = estimatedProgress }
    }

    // ── Bookmarks ──

    public func addBookmark(title: String, urlString: String) {
        let bookmark = BrowserBookmark(title: title, urlString: urlString)
        bookmarks.append(bookmark)
        saveBookmarks()
    }

    public func removeBookmark(_ id: UUID) {
        bookmarks.removeAll(where: { $0.id == id })
        saveBookmarks()
    }

    public func isBookmarked(url: String) -> Bool {
        bookmarks.contains(where: { $0.urlString == url })
    }

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
              let decoded = try? JSONDecoder().decode([BrowserBookmark].self, from: data) else { return }
        bookmarks = decoded
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - WKWebView Coordinator & NSViewRepresentable
// ═══════════════════════════════════════════════════════

public struct WebViewRepresentable: NSViewRepresentable {
    public let tabId: UUID
    public let url: URL?
    @ObservedObject var manager: BrowserManager

    public init(tabId: UUID, url: URL?, manager: BrowserManager) {
        self.tabId = tabId
        self.url = url
        self.manager = manager
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        public var parent: WebViewRepresentable
        public var cancellables = Set<AnyCancellable>()
        weak var webView: WKWebView?

        public init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        // ── Navigation Delegate ──

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.manager.updateTab(id: parent.tabId, isLoading: true)
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.manager.updateTab(
                id: parent.tabId,
                title: webView.title,
                url: webView.url,
                isLoading: false,
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward,
                estimatedProgress: 1.0
            )
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.manager.updateTab(id: parent.tabId, isLoading: false, estimatedProgress: 0)
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.manager.updateTab(id: parent.tabId, isLoading: false, estimatedProgress: 0)
        }

        public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            parent.manager.updateTab(
                id: parent.tabId,
                url: webView.url,
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward
            )
        }

        // ── UI Delegate: handle new window requests ──

        public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                parent.manager.createNewTab(url: url)
            }
            return nil
        }

        // ── Progress observation ──

        public func observeProgress(_ webView: WKWebView) {
            webView.publisher(for: \.estimatedProgress)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] progress in
                    guard let self = self else { return }
                    self.parent.manager.updateTab(id: self.parent.tabId, estimatedProgress: progress)
                }
                .store(in: &cancellables)

            webView.publisher(for: \.title)
                .receive(on: DispatchQueue.main)
                .compactMap { $0 }
                .sink { [weak self] title in
                    guard let self = self else { return }
                    self.parent.manager.updateTab(id: self.parent.tabId, title: title)
                }
                .store(in: &cancellables)

            webView.publisher(for: \.canGoBack)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] val in
                    self?.parent.manager.updateTab(id: self?.parent.tabId ?? UUID(), canGoBack: val)
                }
                .store(in: &cancellables)

            webView.publisher(for: \.canGoForward)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] val in
                    self?.parent.manager.updateTab(id: self?.parent.tabId ?? UUID(), canGoForward: val)
                }
                .store(in: &cancellables)
        }

        public func bindActions(_ webView: WKWebView) {
            self.webView = webView
        }

        /// Called from updateNSView — checks if there's a pending command for this tab.
        /// Consumes the command atomically before executing to prevent races
        /// when multiple coordinators process the same command.
        public func processCommand() {
            guard let webView = webView,
                  let cmd = parent.manager.pendingCommand else { return }
            let tabId = parent.tabId

            // Check if this command targets our tab
            let targetId: UUID
            switch cmd {
            case .navigate(let id, _): targetId = id
            case .goBack(let id): targetId = id
            case .goForward(let id): targetId = id
            case .reload(let id): targetId = id
            }
            guard targetId == tabId else { return }

            // Consume atomically before executing — prevents other coordinators
            // from picking up the same command in subsequent updateNSView calls
            parent.manager.pendingCommand = nil

            switch cmd {
            case .navigate(_, let url):
                webView.load(URLRequest(url: url))
            case .goBack:
                webView.goBack()
            case .goForward:
                webView.goForward()
            case .reload:
                webView.reload()
            }
        }
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")

        context.coordinator.observeProgress(webView)
        context.coordinator.bindActions(webView)

        if let url = url {
            webView.load(URLRequest(url: url))
        } else {
            webView.loadHTMLString(blankPageHTML, baseURL: nil)
        }

        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.processCommand()
    }

    private var blankPageHTML: String {
        """
        <html><head><style>
        body { background: #000; color: #707070; font-family: monospace;
               display: flex; align-items: center; justify-content: center;
               height: 100vh; margin: 0; }
        </style></head><body><p>about:blank</p></body></html>
        """
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Single Tab Content View
// ═══════════════════════════════════════════════════════

private struct BrowserTabContentView: View {
    public let tabId: UUID
    public let url: URL?
    @ObservedObject var manager: BrowserManager

    public var body: some View {
        WebViewRepresentable(tabId: tabId, url: url, manager: manager)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Browser Panel View
// ═══════════════════════════════════════════════════════

public struct BrowserPanelView: View {
    @ObservedObject private var manager = BrowserManager.shared
    @State private var urlBarText: String = ""
    @State private var isURLBarFocused: Bool = false
    @FocusState private var urlFieldFocused: Bool

    // (subjects removed — navigation via BrowserManager.pendingCommand)

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            tabBar
            urlBar
            progressBar
            ZStack {
                Theme.bg
                browserContent
            }
        }
        .background(Theme.bg)
        .onAppear {
            syncURLBar()
            // 브라우저 탭 진입 시 URL 바에 자동 포커스
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if urlBarText == "about:blank" || urlBarText.isEmpty { urlBarText = "" }
                urlFieldFocused = true
            }
        }
        .onChange(of: manager.activeTabId) { _, _ in syncURLBar() }
        .overlay(bookmarksSidebar, alignment: .leading)
        // Keyboard shortcuts
        .keyboardShortcut(for: .focusURLBar) { urlFieldFocused = true }
    }

    // ── Tab Bar ──

    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(manager.tabs) { tab in
                        tabButton(tab)
                    }
                }
                .padding(.horizontal, Theme.sp2)
            }
            Spacer(minLength: 0)

            HStack(spacing: 2) {
                // Bookmark toggle
                toolbarButton(icon: "book", active: manager.showBookmarks) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.showBookmarks.toggle()
                    }
                }

                // New tab button
                toolbarButton(icon: "plus") {
                    _ = manager.createNewTab()
                    urlFieldFocused = true
                }
            }
            .padding(.trailing, Theme.sp2)
        }
        .frame(height: 32)
        .background(Theme.bgCard)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func tabButton(_ tab: BrowserTab) -> some View {
        let isActive = manager.activeTabId == tab.id
        return Button(action: {
            manager.selectTab(tab.id)
        }) {
            HStack(spacing: 4) {
                if tab.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.6)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: Theme.iconSize(8)))
                        .foregroundColor(Theme.textDim)
                }

                Text(tab.displayTitle)
                    .font(Theme.chrome(9))
                    .foregroundColor(isActive ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .leading)

                if manager.tabs.count > 1 {
                    Button(action: {
                        closeTabAndCleanup(tab.id)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.sp2)
            .padding(.vertical, Theme.sp1)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .fill(isActive ? Theme.bgSelected : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // ── URL Bar ──

    private var urlBar: some View {
        HStack(spacing: 4) {
            // Navigation buttons
            navButton(icon: "chevron.left", enabled: manager.activeTab?.canGoBack ?? false) {
                if let id = manager.activeTabId { manager.goBack(tabId: id) }
            }
            navButton(icon: "chevron.right", enabled: manager.activeTab?.canGoForward ?? false) {
                if let id = manager.activeTabId { manager.goForward(tabId: id) }
            }
            navButton(icon: manager.activeTab?.isLoading == true ? "xmark" : "arrow.clockwise",
                      enabled: true) {
                if let id = manager.activeTabId { manager.reload(tabId: id) }
            }

            // URL text field
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: Theme.iconSize(8)))
                    .foregroundColor(
                        urlBarText.hasPrefix("https://") ? Theme.green : Theme.textDim
                    )

                TextField("URL or search", text: $urlBarText, onCommit: {
                    navigateToURL()
                })
                .focused($urlFieldFocused)
                .font(Theme.mono(10))
                .foregroundColor(Theme.textPrimary)
                .textFieldStyle(.plain)
                .onChange(of: urlFieldFocused) { _, focused in
                    if focused && (urlBarText == "about:blank" || urlBarText.isEmpty) {
                        urlBarText = ""
                    }
                }

                if !urlBarText.isEmpty {
                    Button(action: { urlBarText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: Theme.iconSize(9)))
                            .foregroundColor(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.sp2)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.bgSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerMedium)
                            .stroke(urlFieldFocused ? Theme.accent.opacity(0.5) : Theme.borderSubtle, lineWidth: 1)
                    )
            )

            // Bookmark current page
            navButton(
                icon: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark",
                enabled: manager.activeTab?.url != nil
            ) {
                toggleBookmarkForCurrentPage()
            }
        }
        .padding(.horizontal, Theme.sp2)
        .padding(.vertical, 4)
        .background(Theme.bgCard)
        .overlay(Rectangle().fill(Theme.borderSubtle).frame(height: 1), alignment: .bottom)
    }

    // ── Progress Bar ──

    private var progressBar: some View {
        GeometryReader { geo in
            let progress = manager.activeTab?.estimatedProgress ?? 0
            let isLoading = manager.activeTab?.isLoading ?? false
            if isLoading && progress < 1.0 {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: geo.size.width * CGFloat(progress), height: 2)
                    .animation(.linear(duration: 0.2), value: progress)
            }
        }
        .frame(height: 2)
    }

    // ── Browser Content (tab views) ──

    private var browserContent: some View {
        ZStack {
            ForEach(manager.tabs) { tab in
                WebViewRepresentable(tabId: tab.id, url: tab.url, manager: manager)
                    .opacity(manager.activeTabId == tab.id ? 1 : 0)
                    .allowsHitTesting(manager.activeTabId == tab.id)
            }
        }
    }

    // ── Bookmarks Sidebar ──

    private var bookmarksSidebar: some View {
        Group {
            if manager.showBookmarks {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Bookmarks")
                            .font(Theme.chrome(10, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Button(action: { manager.showBookmarks = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.textDim)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Theme.sp3)
                    .padding(.vertical, Theme.sp2)
                    .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)

                    if manager.bookmarks.isEmpty {
                        VStack(spacing: Theme.sp2) {
                            Image(systemName: "bookmark")
                                .font(.system(size: Theme.iconSize(20)))
                                .foregroundColor(Theme.textMuted)
                            Text("No bookmarks yet")
                                .font(Theme.chrome(9))
                                .foregroundColor(Theme.textDim)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 1) {
                                ForEach(manager.bookmarks) { bookmark in
                                    bookmarkRow(bookmark)
                                }
                            }
                            .padding(.vertical, Theme.sp1)
                        }
                    }

                    // Quick-access dev URLs
                    VStack(alignment: .leading, spacing: 2) {
                        Rectangle().fill(Theme.border).frame(height: 1)
                        Text("DEV")
                            .font(Theme.mono(8, weight: .bold))
                            .foregroundColor(Theme.textDim)
                            .padding(.horizontal, Theme.sp3)
                            .padding(.top, Theme.sp1)

                        devShortcutRow("localhost:3000", icon: "network", color: Theme.green)
                        devShortcutRow("localhost:5173", icon: "swift", color: Theme.orange)
                        devShortcutRow("localhost:8080", icon: "server.rack", color: Theme.cyan)
                        devShortcutRow("localhost:4000", icon: "leaf", color: Theme.purple)
                    }
                    .padding(.bottom, Theme.sp2)
                }
                .frame(width: 220)
                .background(Theme.bgCard)
                .overlay(Rectangle().fill(Theme.border).frame(width: 1), alignment: .trailing)
                .transition(.move(edge: .leading))
            }
        }
    }

    private func bookmarkRow(_ bookmark: BrowserBookmark) -> some View {
        Button(action: {
            if let url = URL(string: bookmark.urlString), let id = manager.activeTabId {
                manager.navigate(tabId: id, to: url)
                urlBarText = bookmark.urlString
            }
        }) {
            HStack(spacing: Theme.sp2) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: Theme.iconSize(8)))
                    .foregroundColor(Theme.accent)

                VStack(alignment: .leading, spacing: 1) {
                    Text(bookmark.title)
                        .font(Theme.chrome(9))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text(bookmark.urlString)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: { manager.removeBookmark(bookmark.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.sp3)
            .padding(.vertical, Theme.sp1 + 2)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func devShortcutRow(_ urlString: String, icon: String, color: Color) -> some View {
        Button(action: {
            let fullURL = "http://\(urlString)"
            if let url = URL(string: fullURL), let id = manager.activeTabId {
                manager.navigate(tabId: id, to: url)
                urlBarText = fullURL
            }
        }) {
            HStack(spacing: Theme.sp2) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(8)))
                    .foregroundColor(color)
                Text(urlString)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Theme.sp3)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    // ── Toolbar Buttons ──

    private func toolbarButton(icon: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(10), weight: .medium))
                .foregroundColor(active ? Theme.accent : Theme.textDim)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerSmall)
                        .fill(active ? Theme.accent.opacity(0.12) : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(9), weight: .medium))
                .foregroundColor(enabled ? Theme.textSecondary : Theme.textMuted)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // ── Navigation Logic ──

    private func navigateToURL() {
        guard let id = manager.activeTabId else { return }
        let input = urlBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        let url: URL?
        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            url = URL(string: input)
        } else if input.contains(".") && !input.contains(" ") {
            // Treat as a URL
            url = URL(string: "https://\(input)")
        } else {
            // Treat as a search query
            let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            url = URL(string: "https://www.google.com/search?q=\(encoded)")
        }

        if let url = url {
            manager.navigate(tabId: id, to: url)
            urlBarText = url.absoluteString
        }
    }

    private func syncURLBar() {
        urlBarText = manager.activeTab?.displayURL ?? ""
    }

    // ── Bookmark Helpers ──

    private var isCurrentPageBookmarked: Bool {
        guard let url = manager.activeTab?.url?.absoluteString else { return false }
        return manager.isBookmarked(url: url)
    }

    private func toggleBookmarkForCurrentPage() {
        guard let tab = manager.activeTab, let url = tab.url else { return }
        if manager.isBookmarked(url: url.absoluteString) {
            if let bm = manager.bookmarks.first(where: { $0.urlString == url.absoluteString }) {
                manager.removeBookmark(bm.id)
            }
        } else {
            manager.addBookmark(title: tab.displayTitle, urlString: url.absoluteString)
        }
    }

    // ── Tab Cleanup ──

    private func closeTabAndCleanup(_ id: UUID) {
        // No per-tab cleanup needed — navigation via BrowserManager.pendingCommand
        manager.closeTab(id)
    }

    // ── Subject Management ──

}

// ═══════════════════════════════════════════════════════
// MARK: - Keyboard Shortcut Helpers
// ═══════════════════════════════════════════════════════

private enum BrowserShortcut {
    case focusURLBar
    case newTab
    case closeTab
}

private extension View {
    @ViewBuilder
    func keyboardShortcut(for shortcut: BrowserShortcut, action: @escaping () -> Void) -> some View {
        self.background(
            Group {
                switch shortcut {
                case .focusURLBar:
                    Button("") { action() }
                        .keyboardShortcut("l", modifiers: .command)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                case .newTab:
                    Button("") { action() }
                        .keyboardShortcut("t", modifiers: .command)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                case .closeTab:
                    Button("") { action() }
                        .keyboardShortcut("w", modifiers: .command)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                }
            }
        )
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Split Browser View (Browser + Terminal)
// ═══════════════════════════════════════════════════════

public struct BrowserSplitView: View {
    @State private var splitRatio: CGFloat = 0.5

    public var terminalContent: AnyView
    public var browserContent: AnyView

    init<T: View, B: View>(terminal: T, browser: B) {
        self.terminalContent = AnyView(terminal)
        self.browserContent = AnyView(browser)
    }

    public init() {
        self.terminalContent = AnyView(
            Text("Terminal")
                .font(Theme.mono(12))
                .foregroundColor(Theme.textDim)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg)
        )
        self.browserContent = AnyView(BrowserPanelView())
    }

    public var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                terminalContent
                    .frame(width: geo.size.width * splitRatio)

                // Resize handle
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 3)
                    .contentShape(Rectangle().inset(by: -4))
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let newRatio = value.location.x / geo.size.width
                                splitRatio = min(max(newRatio, 0.15), 0.85)
                            }
                    )

                browserContent
                    .frame(width: geo.size.width * (1 - splitRatio) - 3)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Previews
// ═══════════════════════════════════════════════════════

#if DEBUG
public struct BrowserPanelView_Previews: PreviewProvider {
    public static var previews: some View {
        BrowserPanelView()
            .frame(width: 900, height: 600)
            .preferredColorScheme(.dark)
    }
}
#endif
