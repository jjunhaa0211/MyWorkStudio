import SwiftUI
import DesignSystem

struct SyntaxCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Syntax Tokens")

            catalogSection("Code Colors") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    tokenSwatch("keyword", DSSyntax.keyword)
                    tokenSwatch("type", DSSyntax.type)
                    tokenSwatch("string", DSSyntax.string)
                    tokenSwatch("number", DSSyntax.number)
                    tokenSwatch("function", DSSyntax.function)
                    tokenSwatch("comment", DSSyntax.comment)
                    tokenSwatch("operator", DSSyntax.operator)
                    tokenSwatch("property", DSSyntax.property)
                    tokenSwatch("variable", DSSyntax.variable)
                    tokenSwatch("parameter", DSSyntax.parameter)
                    tokenSwatch("declaration", DSSyntax.declaration)
                    tokenSwatch("annotation", DSSyntax.annotation)
                }
                .frame(maxWidth: 500)
            }

            catalogSection("Terminal / ANSI") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    tokenSwatch("black", DSSyntax.termBlack)
                    tokenSwatch("red", DSSyntax.termRed)
                    tokenSwatch("green", DSSyntax.termGreen)
                    tokenSwatch("yellow", DSSyntax.termYellow)
                    tokenSwatch("blue", DSSyntax.termBlue)
                    tokenSwatch("magenta", DSSyntax.termMagenta)
                    tokenSwatch("cyan", DSSyntax.termCyan)
                    tokenSwatch("white", DSSyntax.termWhite)
                }
                .frame(maxWidth: 500)
            }

            catalogSection("Diff Colors") {
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(DSSyntax.diffAdded).frame(width: 32, height: 20)
                        Text("+ added").font(Theme.code(9, weight: .bold)).foregroundColor(DSSyntax.diffAddedText)
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(DSSyntax.diffRemoved).frame(width: 32, height: 20)
                        Text("- removed").font(Theme.code(9, weight: .bold)).foregroundColor(DSSyntax.diffRemovedText)
                    }
                }
            }
        }
    }

    private func tokenSwatch(_ name: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 16, height: 16)
            Text(name).font(Theme.code(9, weight: .medium)).foregroundColor(color)
            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgTertiary.opacity(0.5)))
    }
}
