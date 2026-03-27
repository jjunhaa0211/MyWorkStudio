import SwiftUI
import DesignSystem

struct AvatarCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Avatars")

            catalogSection("DSAvatar — Sizes") {
                HStack(spacing: 16) {
                    VStack(spacing: 4) { DSAvatar(name: "Kim", size: .xs, tint: Theme.accent); Text("xs").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                    VStack(spacing: 4) { DSAvatar(name: "Kim", size: .sm, tint: Theme.green); Text("sm").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                    VStack(spacing: 4) { DSAvatar(name: "Kim Jun", size: .md, tint: Theme.purple); Text("md").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                    VStack(spacing: 4) { DSAvatar(name: "Kim Jun", size: .lg, tint: Theme.orange); Text("lg").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                    VStack(spacing: 4) { DSAvatar(name: "Kim Jun", size: .xl, tint: Theme.cyan); Text("xl").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                }
            }

            catalogSection("DSAvatar — Content Types") {
                HStack(spacing: 16) {
                    VStack(spacing: 4) { DSAvatar(.initials("JK"), size: .lg, tint: Theme.accent); Text("Initials").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                    VStack(spacing: 4) { DSAvatar(.icon("person.fill"), size: .lg, tint: Theme.green); Text("Icon").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                    VStack(spacing: 4) { DSAvatar(.icon("star.fill"), size: .lg, tint: Theme.yellow); Text("Custom").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                }
            }

            catalogSection("DSAvatar — Status") {
                HStack(spacing: 16) {
                    DSAvatar(name: "Online", size: .lg, tint: Theme.accent, status: Theme.green)
                    DSAvatar(name: "Busy", size: .lg, tint: Theme.orange, status: Theme.red)
                    DSAvatar(name: "Away", size: .lg, tint: Theme.purple, status: Theme.yellow)
                    DSAvatar(name: "Off", size: .lg, tint: Theme.textDim, status: Theme.textMuted)
                }
            }

            catalogSection("DSAvatarStack") {
                DSAvatarStack([
                    ("Alice", Theme.accent), ("Bob", Theme.green), ("Charlie", Theme.purple),
                    ("Diana", Theme.orange), ("Eve", Theme.cyan), ("Frank", Theme.pink)
                ], size: .md, maxVisible: 4)
            }
        }
    }
}
