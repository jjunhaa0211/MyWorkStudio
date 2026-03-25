import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Prompt Favorites / Templates
// ═══════════════════════════════════════════════════════

class PromptFavorites: ObservableObject {
    static let shared = PromptFavorites()

    struct Favorite: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String        // e.g., "코드 리뷰"
        var prompt: String      // The actual prompt text
        var icon: String        // SF Symbol name
        var shortcut: String?   // e.g., "review"
        let createdAt: Date

        init(id: UUID = UUID(), name: String, prompt: String, icon: String, shortcut: String? = nil, createdAt: Date = Date()) {
            self.id = id; self.name = name; self.prompt = prompt; self.icon = icon; self.shortcut = shortcut; self.createdAt = createdAt
        }
    }

    @Published var favorites: [Favorite] = []

    private let storageKey = "promptFavorites_v1"

    private init() {
        load()
        if favorites.isEmpty { resetToDefaults() }
    }

    // MARK: - Default Templates

    static let defaultTemplates: [Favorite] = [
        Favorite(name: "코드 리뷰", prompt: "이 코드를 리뷰해주세요. 버그, 성능, 보안 문제를 찾아주세요.", icon: "magnifyingglass.circle.fill", shortcut: "review"),
        Favorite(name: "리팩토링", prompt: "이 코드를 깔끔하게 리팩토링해주세요.", icon: "arrow.triangle.2.circlepath.circle.fill", shortcut: "refactor"),
        Favorite(name: "테스트 작성", prompt: "이 코드에 대한 유닛 테스트를 작성해주세요.", icon: "checkmark.shield.fill", shortcut: "test"),
        Favorite(name: "버그 수정", prompt: "이 에러를 분석하고 수정해주세요:", icon: "ladybug.fill", shortcut: "fix"),
        Favorite(name: "설명", prompt: "이 코드가 무엇을 하는지 설명해주세요.", icon: "text.bubble.fill", shortcut: "explain"),
    ]

    func resetToDefaults() {
        favorites = Self.defaultTemplates
        save()
    }

    // MARK: - CRUD

    func add(_ favorite: Favorite) {
        favorites.append(favorite)
        save()
    }

    func add(name: String, prompt: String, icon: String = "star.fill", shortcut: String? = nil) {
        add(Favorite(name: name, prompt: prompt, icon: icon, shortcut: shortcut))
    }

    func update(_ favorite: Favorite) {
        guard let idx = favorites.firstIndex(where: { $0.id == favorite.id }) else { return }
        favorites[idx] = favorite
        save()
    }

    func delete(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func find(byName name: String) -> Favorite? {
        let q = name.lowercased()
        return favorites.first { $0.name.lowercased() == q || $0.shortcut?.lowercased() == q }
    }

    func find(byShortcut shortcut: String) -> Favorite? {
        let q = shortcut.lowercased()
        return favorites.first { $0.shortcut?.lowercased() == q }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Favorite].self, from: data) else { return }
        favorites = decoded
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Favorites Panel View
// ═══════════════════════════════════════════════════════

struct FavoritesPanelView: View {
    @ObservedObject private var store = PromptFavorites.shared
    let onSelect: (PromptFavorites.Favorite) -> Void
    let onDismiss: () -> Void

    @State private var editingFavorite: PromptFavorites.Favorite?
    @State private var showAddSheet = false

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Rectangle().fill(Theme.border).frame(height: 1)
            HStack(spacing: 6) {
                Image(systemName: "star.fill").font(.system(size: Theme.iconSize(9), weight: .bold)).foregroundColor(Theme.yellow)
                Text("프롬프트 즐겨찾기").font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
                Text("Cmd+P 토글").font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(Theme.accent)
                }.buttonStyle(.plain).help("새 즐겨찾기 추가")
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Theme.iconSize(10)))
                        .foregroundColor(Theme.textDim)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)

            // Grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.favorites) { fav in
                        favoriteCard(fav)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .frame(maxHeight: 80)

            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .background(Theme.bgSurface.opacity(0.95))
        .sheet(isPresented: $showAddSheet) {
            FavoriteEditSheet(favorite: nil) { newFav in
                store.add(newFav)
            }
        }
        .sheet(item: $editingFavorite) { fav in
            FavoriteEditSheet(favorite: fav) { updated in
                store.update(updated)
            }
        }
    }

    private func favoriteCard(_ fav: PromptFavorites.Favorite) -> some View {
        Button(action: { onSelect(fav) }) {
            VStack(spacing: 4) {
                Image(systemName: fav.icon)
                    .font(.system(size: Theme.iconSize(16), weight: .medium))
                    .foregroundColor(Theme.accent)
                Text(fav.name)
                    .font(Theme.chrome(9, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                if let shortcut = fav.shortcut {
                    Text("/fav \(shortcut)")
                        .font(Theme.chrome(7))
                        .foregroundColor(Theme.textDim)
                }
            }
            .frame(width: 100, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.bgCard)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: { editingFavorite = fav }) {
                Label("편집", systemImage: "pencil")
            }
            Button(role: .destructive, action: { store.delete(fav) }) {
                Label("삭제", systemImage: "trash")
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Favorite Edit Sheet
// ═══════════════════════════════════════════════════════

struct FavoriteEditSheet: View {
    let favorite: PromptFavorites.Favorite?
    let onSave: (PromptFavorites.Favorite) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var prompt: String = ""
    @State private var icon: String = "star.fill"
    @State private var shortcut: String = ""

    private let iconOptions = [
        "star.fill", "magnifyingglass.circle.fill", "arrow.triangle.2.circlepath.circle.fill",
        "checkmark.shield.fill", "ladybug.fill", "text.bubble.fill",
        "bolt.fill", "hammer.fill", "wrench.fill", "doc.text.fill",
        "cpu.fill", "terminal.fill", "chevron.left.forwardslash.chevron.right",
        "lightbulb.fill", "book.fill", "flag.fill",
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text(favorite == nil ? "새 즐겨찾기" : "즐겨찾기 편집")
                .font(Theme.chrome(13, weight: .bold)).foregroundColor(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("이름")
                TextField("예: 코드 리뷰", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.mono(11))

                fieldLabel("프롬프트")
                TextEditor(text: $prompt)
                    .font(Theme.mono(11))
                    .frame(minHeight: 60, maxHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))

                fieldLabel("단축어 (선택)")
                TextField("예: review", text: $shortcut)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.mono(11))

                fieldLabel("아이콘")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(iconOptions, id: \.self) { ic in
                            Button(action: { icon = ic }) {
                                Image(systemName: ic)
                                    .font(.system(size: Theme.iconSize(14)))
                                    .foregroundColor(icon == ic ? Theme.accent : Theme.textDim)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(icon == ic ? Theme.accent.opacity(0.15) : Theme.bgSurface)
                                    )
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("저장") {
                    let result = PromptFavorites.Favorite(
                        id: favorite?.id ?? UUID(),
                        name: name,
                        prompt: prompt,
                        icon: icon,
                        shortcut: shortcut.isEmpty ? nil : shortcut,
                        createdAt: favorite?.createdAt ?? Date()
                    )
                    onSave(result)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || prompt.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
        .background(Theme.bgCard)
        .onAppear {
            if let f = favorite {
                name = f.name; prompt = f.prompt; icon = f.icon; shortcut = f.shortcut ?? ""
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(Theme.chrome(9, weight: .semibold)).foregroundColor(Theme.textSecondary)
    }
}
