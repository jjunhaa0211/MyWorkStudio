import SwiftUI
import DesignSystem

struct TimelineCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Timeline")

            catalogSection("DSTimeline — Git History") {
                DSTimeline([
                    DSTimelineItem(title: "Merge PR #12", subtitle: "feat: add plugin marketplace", icon: "arrow.triangle.merge", tint: Theme.purple, timestamp: "2m ago"),
                    DSTimelineItem(title: "Push to main", subtitle: "3 commits pushed", icon: "arrow.up.circle.fill", tint: Theme.green, timestamp: "15m ago"),
                    DSTimelineItem(title: "Build failed", subtitle: "Test suite: 2 failures", icon: "xmark.circle.fill", tint: Theme.red, timestamp: "1h ago"),
                    DSTimelineItem(title: "Session started", subtitle: "claude-sonnet-4 • /project", icon: "play.circle.fill", tint: Theme.accent, timestamp: "2h ago"),
                    DSTimelineItem(title: "Version tagged", subtitle: "v0.0.27", icon: "tag.fill", tint: Theme.yellow, timestamp: "3h ago"),
                ])
                .frame(maxWidth: 450)
            }
        }
    }
}
