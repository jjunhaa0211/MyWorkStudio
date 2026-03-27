import SwiftUI
import DesignSystem

struct DiffCatalog: View {
    private let sampleDiff = DSDiffView.parse("""
    @@ -1,5 +1,7 @@
     import SwiftUI
    +import DesignSystem

     struct ContentView: View {
    -    let title = "Hello"
    +    let title = "Hello, 도피스!"
    +    @State private var count = 0
     }
    """)

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Diff Viewer")

            catalogSection("DSDiffView — Code Changes") {
                DSDiffView(sampleDiff, fileName: "ContentView.swift")
                    .frame(maxWidth: 600)
            }
        }
    }
}
