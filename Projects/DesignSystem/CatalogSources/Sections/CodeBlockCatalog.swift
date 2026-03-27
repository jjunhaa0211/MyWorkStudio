import SwiftUI
import DesignSystem

struct CodeBlockCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Code Blocks")

            catalogSection("DSCodeBlock — Basic") {
                DSCodeBlock("let greeting = \"Hello, 도피스!\"\nprint(greeting)", language: "swift")
                    .frame(maxWidth: 500)
            }

            catalogSection("DSCodeBlock — With Line Numbers") {
                DSCodeBlock(
                    "import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        Text(\"Hello\")\n            .font(.title)\n    }\n}",
                    language: "swift",
                    showLineNumbers: true
                )
                .frame(maxWidth: 500)
            }

            catalogSection("DSCodeBlock — Shell") {
                DSCodeBlock("$ brew install mise\n$ mise install tuist@latest\n$ tuist generate", language: "shell")
                    .frame(maxWidth: 500)
            }
        }
    }
}
