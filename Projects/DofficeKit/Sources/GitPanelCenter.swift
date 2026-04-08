import SwiftUI
import DesignSystem

extension GitPanelView {
    // ═══════════════════════════════════════════════════════
    // MARK: - Center Panel (Graph + Commits)
    // ═══════════════════════════════════════════════════════

    var centerPanel: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textDim)
                TextField(NSLocalizedString("git.search.placeholder", comment: ""), text: $searchText)
                    .font(Theme.mono(9))
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.textPrimary)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textDim)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.bgSurface.opacity(0.5))
            Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 0.5)

            // Working directory bar
            if !git.workingDirStaged.isEmpty || !git.workingDirUnstaged.isEmpty {
                workingDirectoryBar
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            // Column headers
            HStack(spacing: 0) {
                Text(NSLocalizedString("git.graph", comment: "")).frame(width: CGFloat(max(git.maxLaneCount, 1)) * 20 + 12, alignment: .center)
                Text(NSLocalizedString("git.message", comment: "")).padding(.leading, 4)
                Spacer()
                Text(NSLocalizedString("git.author", comment: "")).frame(width: 90, alignment: .center)
                Text(NSLocalizedString("git.date", comment: "")).frame(width: 90, alignment: .trailing).padding(.trailing, 12)
            }
            .font(Theme.mono(7, weight: .bold))
            .foregroundColor(Theme.textDim.opacity(0.5))
            .padding(.vertical, 4)
            .background(Theme.bgSurface.opacity(0.3))

            Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 0.5)

            // Commit list
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(displayedCommits.enumerated()), id: \.element.id) { idx, commit in
                            commitRow(commit)
                                .id(commit.id)
                                .onTapGesture {
                                    selectCommit(commit)
                                    selectedKeyboardIndex = idx
                                }
                                .onHover { hovering in hoveredCommitId = hovering ? commit.id : nil }
                        }

                        // Load more / commit count
                        HStack(spacing: 8) {
                            Text(String(format: NSLocalizedString("git.commits.shown", comment: ""), displayedCommits.count))
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textDim)
                            if !searchText.isEmpty {
                                Text(String(format: NSLocalizedString("git.commits.total", comment: ""), git.commits.count))
                                    .font(Theme.mono(7))
                                    .foregroundColor(Theme.textDim.opacity(0.6))
                            }
                            Spacer()
                            Button(action: { git.loadMoreCommits() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 8))
                                    Text(NSLocalizedString("git.load.more", comment: ""))
                                        .font(Theme.mono(8, weight: .medium))
                                }
                                .foregroundStyle(Theme.accentBackground)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.accent.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }
                .onKeyPress(.upArrow) {
                    navigateCommit(direction: -1, scrollProxy: scrollProxy)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    navigateCommit(direction: 1, scrollProxy: scrollProxy)
                    return .handled
                }
            }
        }
    }

    func navigateCommit(direction: Int, scrollProxy: ScrollViewProxy) {
        let commits = displayedCommits
        guard !commits.isEmpty else { return }
        let newIndex = max(0, min(commits.count - 1, selectedKeyboardIndex + direction))
        selectedKeyboardIndex = newIndex
        let commit = commits[newIndex]
        selectCommit(commit)
        withAnimation(.easeInOut(duration: 0.1)) {
            scrollProxy.scrollTo(commit.id, anchor: .center)
        }
    }

    var workingDirectoryBar: some View {
        Button(action: {
            selectedCommitId = nil
            selectedFileForDiff = nil
            showDiffViewer = false
        }) {
            HStack(spacing: 0) {
                wipNode
                    .frame(width: CGFloat(max(git.maxLaneCount, 1)) * 20 + 12)

                HStack(spacing: 8) {
                    Text(NSLocalizedString("git.working.directory", comment: ""))
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.yellow)

                    if !git.workingDirStaged.isEmpty {
                        badge("\(git.workingDirStaged.count) staged", color: Theme.green)
                    }
                    badge(String(format: NSLocalizedString("git.changes.count", comment: ""), git.workingDirUnstaged.count), color: Theme.orange)

                    Spacer()

                    Text("\(git.workingDirStaged.count + git.workingDirUnstaged.count) files")
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                        .padding(.trailing, 12)
                }
            }
            .padding(.vertical, 8)
            .background(selectedCommitId == nil ? Theme.yellow.opacity(0.04) : .clear)
            .overlay(alignment: .leading) {
                if selectedCommitId == nil {
                    Rectangle().fill(Theme.yellow).frame(width: 3)
                }
            }
        }.buttonStyle(.plain)
    }

    var wipNode: some View {
        Canvas { ctx, size in
            let midX = size.width / 2
            let midY = size.height / 2
            let r: CGFloat = 5
            let rect = CGRect(x: midX - r, y: midY - r, width: r * 2, height: r * 2)
            ctx.stroke(Path(ellipseIn: rect), with: .color(Color.orange), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
        }
        .frame(width: 20, height: 20)
    }

    // MARK: - Commit Row

    func commitRow(_ commit: GitCommitNode) -> some View {
        let isSelected = selectedCommitId == commit.id
        let isHovered = hoveredCommitId == commit.id
        let graphW = CGFloat(max(git.maxLaneCount, 1)) * 20 + 12

        return HStack(alignment: .top, spacing: 0) {
            graphColumn(commit: commit).frame(width: graphW, height: Self.commitRowHeight)

            HStack(alignment: .top, spacing: 5) {
                ForEach(commit.refs, id: \.name) { ref in refBadge(ref) }
                Text(commit.message)
                    .font(Theme.mono(10, weight: isSelected ? .bold : .regular))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.leading, 4)

            Text(commit.author)
                .font(Theme.mono(8))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 90, alignment: .leading)

            Text(Self.relativeDate(commit.date))
                .font(Theme.mono(8))
                .foregroundColor(Theme.textDim)
                .frame(width: 90, alignment: .trailing)
                .padding(.trailing, 12)
        }
        .frame(minHeight: Self.commitRowHeight, alignment: .top)
        .background(
            isSelected ? Theme.accentBg(Theme.accent) :
            isHovered ? Theme.bgHover :
            .clear
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.borderSubtle).frame(height: 1)
        }
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle().fill(Theme.accentBackground).frame(width: 2)
            } else if commit.refs.contains(where: { $0.type == .head }) {
                Rectangle().fill(Theme.green).frame(width: 2)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                commitForAction = commit
                showCherryPickAlert = true
            }) {
                Label(NSLocalizedString("git.cherrypick", comment: ""), systemImage: "arrow.uturn.down.circle")
            }
            Button(action: {
                commitForAction = commit
                showRevertAlert = true
            }) {
                Label(NSLocalizedString("git.revert", comment: ""), systemImage: "arrow.uturn.backward.circle")
            }
            Divider()
            Button(action: {
                commitForAction = commit
                resetMode = "soft"
                showResetAlert = true
            }) {
                Label("Reset (soft)", systemImage: "arrow.counterclockwise")
            }
            Button(action: {
                commitForAction = commit
                resetMode = "mixed"
                showResetAlert = true
            }) {
                Label("Reset (mixed)", systemImage: "arrow.counterclockwise.circle")
            }
            Button(role: .destructive, action: {
                commitForAction = commit
                resetMode = "hard"
                showResetAlert = true
            }) {
                Label("Reset (hard)", systemImage: "arrow.counterclockwise.circle.fill")
            }
            Divider()
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.id, forType: .string)
                showInfoToast(NSLocalizedString("git.sha.copied", comment: ""))
            }) {
                Label(NSLocalizedString("git.sha.copy", comment: ""), systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Graph Drawing

    func graphColumn(commit: GitCommitNode) -> some View {
        let laneColors = GitDataProvider.laneColors
        let colW: CGFloat = 20
        let activeLanes = commit.activeLanes
        let commitLane = commit.lane
        let parentHashes = commit.parentHashes
        let laneMap = git.commitLaneMap
        let isMerge = parentHashes.count > 1
        let hasTag = commit.refs.contains { $0.type == .tag }
        let firstParentLane = commit.firstParentLane
        let childLanes = commit.childLanes

        return Canvas { ctx, size in
            let rowH = size.height
            let midY = rowH / 2

            func laneX(_ lane: Int) -> CGFloat { CGFloat(lane) * colW + 10 }

            func strokeLine(_ path: Path, color: Color) {
                ctx.stroke(path, with: .color(color.opacity(0.08)), lineWidth: 5)
                ctx.stroke(path, with: .color(color.opacity(0.45)), lineWidth: 2)
            }

            func strokeCurve(from: CGPoint, to: CGPoint, color: Color) {
                let mp = Path { p in
                    p.move(to: from)
                    p.addCurve(to: to,
                               control1: CGPoint(x: from.x, y: from.y + (to.y - from.y) * 0.5),
                               control2: CGPoint(x: to.x, y: to.y - (to.y - from.y) * 0.5))
                }
                ctx.stroke(mp, with: .color(color.opacity(0.08)), lineWidth: 5)
                ctx.stroke(mp, with: .color(color.opacity(0.45)), lineWidth: 2)
            }

            // ── 패스스루 레인 (이 커밋 레인 아닌 활성 레인) ──
            for laneIdx in activeLanes where laneIdx != commitLane {
                let x = laneX(laneIdx)
                let color = laneColors[laneIdx % laneColors.count]
                strokeLine(Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: rowH)) }, color: color)
            }

            let nodeX = laneX(commitLane)
            let nodeColor = laneColors[commitLane % laneColors.count]

            // ── 위쪽: 자식에서 이 커밋으로의 연결 ──
            // 자식이 같은 레인에 있으면 직선, 아니면 (자식 행이 그릴 것이므로) 그냥 직선
            let hasChildOnSameLane = childLanes.contains(commitLane) || childLanes.isEmpty
            if hasChildOnSameLane {
                strokeLine(Path { p in p.move(to: CGPoint(x: nodeX, y: 0)); p.addLine(to: CGPoint(x: nodeX, y: midY)) }, color: nodeColor)
            }
            // 다른 레인의 자식이 분기해 내려온 경우: 위에서 이 커밋으로 곡선
            for childLane in childLanes where childLane != commitLane {
                let childX = laneX(childLane)
                let childColor = laneColors[childLane % laneColors.count]
                strokeCurve(from: CGPoint(x: childX, y: 0), to: CGPoint(x: nodeX, y: midY), color: childColor)
            }

            // ── 아래쪽: 이 커밋에서 부모로의 연결 ──
            if !parentHashes.isEmpty {
                if firstParentLane >= 0 && firstParentLane == commitLane {
                    // 첫 번째 부모가 같은 레인 → 직선
                    strokeLine(Path { p in p.move(to: CGPoint(x: nodeX, y: midY)); p.addLine(to: CGPoint(x: nodeX, y: rowH)) }, color: nodeColor)
                } else if firstParentLane >= 0 {
                    // 첫 번째 부모가 다른 레인 → 곡선
                    let parentX = laneX(firstParentLane)
                    let parentColor = laneColors[firstParentLane % laneColors.count]
                    strokeCurve(from: CGPoint(x: nodeX, y: midY), to: CGPoint(x: parentX, y: rowH), color: parentColor)
                } else {
                    // 부모 레인 정보 없음 → 직선 fallback
                    strokeLine(Path { p in p.move(to: CGPoint(x: nodeX, y: midY)); p.addLine(to: CGPoint(x: nodeX, y: rowH)) }, color: nodeColor)
                }
            }

            // 머지 곡선 (2번째+ 부모)
            for pIdx in parentHashes.indices.dropFirst() {
                if let parentLane = laneMap[parentHashes[pIdx]] {
                    let parentX = laneX(parentLane)
                    let mergeColor = laneColors[parentLane % laneColors.count]
                    strokeCurve(from: CGPoint(x: nodeX, y: midY), to: CGPoint(x: parentX, y: rowH), color: mergeColor)
                }
            }

            // ── 노드 (커밋 점) ──
            let r: CGFloat = hasTag ? 5.5 : 4.5
            let nodeRect = CGRect(x: nodeX - r, y: midY - r, width: r * 2, height: r * 2)
            if hasTag {
                let diamond = Path { p in
                    p.move(to: CGPoint(x: nodeX, y: midY - r))
                    p.addLine(to: CGPoint(x: nodeX + r, y: midY))
                    p.addLine(to: CGPoint(x: nodeX, y: midY + r))
                    p.addLine(to: CGPoint(x: nodeX - r, y: midY))
                    p.closeSubpath()
                }
                ctx.fill(diamond, with: .color(Color.yellow))
                ctx.stroke(diamond, with: .color(Color.yellow.opacity(0.7)), lineWidth: 1.5)
            } else {
                let glowRect = CGRect(x: nodeX - r - 2, y: midY - r - 2, width: (r + 2) * 2, height: (r + 2) * 2)
                ctx.fill(Path(ellipseIn: glowRect), with: .color(nodeColor.opacity(0.15)))
                ctx.fill(Path(ellipseIn: nodeRect), with: .color(nodeColor))
                let hlRect = CGRect(x: nodeX - r * 0.4, y: midY - r * 0.4, width: r * 0.8, height: r * 0.8)
                ctx.fill(Path(ellipseIn: hlRect), with: .color(.white.opacity(0.3)))
                if isMerge {
                    let ring = CGRect(x: nodeX - r - 2.5, y: midY - r - 2.5, width: (r + 2.5) * 2, height: (r + 2.5) * 2)
                    ctx.stroke(Path(ellipseIn: ring), with: .color(nodeColor.opacity(0.7)), lineWidth: 1.5)
                }
            }
        }
    }

    // MARK: - Ref Badges

    func refBadge(_ ref: GitCommitNode.GitRef) -> some View {
        let (tint, icon): (Color, String) = {
            switch ref.type {
            case .head: return (Theme.green, "chevron.right")
            case .branch: return (Theme.accent, "arrow.triangle.branch")
            case .remoteBranch: return (Theme.purple, "cloud.fill")
            case .tag: return (Theme.yellow, "tag.fill")
            }
        }()

        return HStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 6, weight: .bold))
            Text(ref.name).font(Theme.code(7, weight: .bold)).lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, Theme.sp1 + 1).padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.accentBg(tint)))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.accentBorder(tint), lineWidth: 1))
    }

}
