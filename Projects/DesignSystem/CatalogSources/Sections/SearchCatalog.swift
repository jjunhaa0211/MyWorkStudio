import SwiftUI
import DesignSystem

struct SearchCatalog: View {
    @State private var query1 = ""
    @State private var query2 = "claude"

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Search Field")

            catalogSection("DSSearchField — Empty") {
                DSSearchField("Search sessions...", text: $query1)
                    .frame(maxWidth: 350)
            }

            catalogSection("DSSearchField — With Text") {
                DSSearchField("Filter...", text: $query2)
                    .frame(maxWidth: 350)
            }
        }
    }
}
