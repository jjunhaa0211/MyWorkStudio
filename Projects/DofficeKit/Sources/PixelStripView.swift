import SwiftUI
import DesignSystem

public struct PixelStripView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var frame: Int = 0
    @State private var dragPositions: [String: CGPoint] = [:]
    @State private var draggingId: String? = nil
    @State private var cachedGroups: [ProjectGroup] = []
    @State private var cachedTabSignature: String = ""

    let timer = Timer.publish(every: 1.0 / 8.0, on: .main, in: .common).autoconnect()

    // MARK: - Pre-allocated Colors (avoid per-frame Color(hex:) allocations)

    // Sunny / Clear Sky
    private static let sunYellow = Color(hex: "ffe840")
    private static let sunGlowLight = Color(hex: "fff8d0")
    private static let sunGlowMid = Color(hex: "ffee70")
    private static let cloudShadow = Color(hex: "4a90d9")
    private static let birdColor = Color(hex: "304060")

    // Sunset / Golden Hour
    private static let sunsetOrange = Color(hex: "ffa030")
    private static let sunsetRed = Color(hex: "ff5020")
    private static let goldenSun = Color(hex: "ffc040")
    private static let goldenSunBright = Color(hex: "ffe070")
    private static let sunsetSunBright = Color(hex: "ff6030")
    private static let goldenReflect = Color(hex: "ffc050")
    private static let sunsetReflect = Color(hex: "ff5030")
    private static let goldenCloudDark = Color(hex: "804020")
    private static let sunsetCloudDark = Color(hex: "601020")
    private static let goldenCloudBright = Color(hex: "ffc050")  // same as goldenReflect
    private static let sunsetCloudBright = Color(hex: "ff6040")
    private static let goldenHorizonA = Color(hex: "ff8030")
    private static let sunsetHorizonA = Color(hex: "ff3020")
    private static let goldenHorizonB = Color(hex: "ffa040")
    private static let sunsetHorizonB = Color(hex: "ff5030")  // same as sunsetReflect
    private static let goldenHorizonC = Color(hex: "ffc060")
    private static let sunsetHorizonC = Color(hex: "ff7040")
    private static let sunsetSunFaint = Color(hex: "ff4020")

    // Dusk
    private static let crescentMoon = Color(hex: "e8ecf8")
    private static let duskPurple = Color(hex: "6040a0")

    // Moonlit
    private static let moonHalo = Color(hex: "c8d8f8")
    private static let moonMid = Color(hex: "d0e0ff")
    private static let moonBright = Color(hex: "e8f0ff")
    private static let moonBeam = Color(hex: "c0d0ff")
    private static let fireflyGreen = Color(hex: "e0ff80")

    // Aurora
    private static let auroraColors: [Color] = [Color(hex: "30ff70"), Color(hex: "20e0a0"), Color(hex: "40a0ff"), Color(hex: "8060ff"), Color(hex: "c040ff")]

    // Milky Way
    private static let milkyBand = Color(hex: "b0c0ff")
    private static let milkyAccent = Color(hex: "d0a0ff")

    // Storm
    private static let stormCloud = Color(hex: "181e2a")
    private static let lightningFlash = Color(hex: "e8f0ff")

    // Rain
    private static let rainCloud = Color(hex: "384858")
    private static let raindrop = Color(hex: "80a8c8")
    private static let rainSplash = Color(hex: "a0c0d8")
    private static let puddleColor = Color(hex: "6090b0")

    // Cherry Blossom
    private static let softSunWarm = Color(hex: "fff8e8")
    private static let softSunGlow = Color(hex: "fff0d0")
    private static let branchBrown = Color(hex: "6a4030")
    private static let blossomPink = Color(hex: "ffa0b8")

    // Autumn
    private static let autumnSunA = Color(hex: "e08030")
    private static let autumnSunB = Color(hex: "e09040")
    private static let leafColors: [Color] = [Color(hex: "d04818"), Color(hex: "e08828"), Color(hex: "c8501c"), Color(hex: "b8901c")]

    // Forest
    private static let trunkGreen = Color(hex: "2a3020")
    private static let sunRayGreen = Color(hex: "80c060")

    // Neon City
    private static let neonBuildingDark = Color(hex: "080614")
    private static let neonPink = Color(hex: "ff40a0")
    private static let neonCyan = Color(hex: "40e0ff")
    private static let neonYellow = Color(hex: "f0e040")
    private static let neonGreen = Color(hex: "60ff80")
    private static let neonWindowColors: [Color] = [Color(hex: "ff40a0"), Color(hex: "40e0ff"), Color(hex: "f0e040"), Color(hex: "60ff80")]

    // Ocean
    private static let oceanSunLight = Color(hex: "fff8d0")
    private static let oceanSunBright = Color(hex: "fff8e0")
    private static let oceanWaveA = Color(hex: "60b0e8")
    private static let oceanWaveB = Color(hex: "3080c0")

    // Desert
    private static let desertSunMid = Color(hex: "ffe860")
    private static let desertSunBright = Color(hex: "fff0a0")
    private static let duneSand = Color(hex: "c09050")

    // Volcano
    private static let volcanoGlow = Color(hex: "ff2000")
    private static let lavaA = Color(hex: "ff3010")
    private static let lavaB = Color(hex: "ff6020")
    private static let emberColor = Color(hex: "ff6020")  // same as lavaB
    private static let ashColor = Color(hex: "804030")

    // backgroundTheme, isDarkMode를 읽어야 Canvas가 변경 시 다시 그려짐
    private var bgKey: String { "\(settings.backgroundTheme)_\(settings.isDarkMode)" }

    public init() {}

    public var body: some View {
        ZStack {
            Canvas { context, size in
                drawScene(context: context, size: size)
            }
            .drawingGroup()
            .id(bgKey)  // 배경 변경 시 Canvas 강제 재생성
            .background(canvasBgColor)

            if settings.isEditMode {
                editModeOverlay
            }
        }
        .onReceive(timer) { _ in
            frame += 1
            // Rebuild groups only when tab count or active tab changes
            let sig = "\(manager.userVisibleTabCount)|\(manager.activeTab?.id ?? "")"
            if sig != cachedTabSignature {
                cachedTabSignature = sig
                cachedGroups = buildGroups()
            }
        }
        .onAppear { cachedGroups = buildGroups() }
    }

    private var canvasBgColor: Color {
        let theme = BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
        if theme == .auto {
            return settings.isDarkMode ? Color(hex: "0a0d14") : Color(hex: "e8eaf0")
        }
        return Color(hex: theme.skyColors.top)
    }

    // MARK: - Project Group

    private struct ProjectGroup {
        let projectPath: String
        let projectName: String
        let tabs: [TerminalTab]
        var hasActiveTab: Bool
        var primaryActivity: ClaudeActivity {
            let priorities: [ClaudeActivity] = [.running, .writing, .searching, .reading, .thinking, .done, .error, .idle]
            for p in priorities {
                if tabs.contains(where: { $0.claudeActivity == p }) { return p }
            }
            return .idle
        }
        var isAnyRunning: Bool { tabs.contains(where: { $0.isRunning }) }
        var isAllCompleted: Bool { tabs.allSatisfy { $0.isCompleted } }
    }

    private func buildGroups() -> [ProjectGroup] {
        var dict: [String: [TerminalTab]] = [:]
        var order: [String] = []
        for tab in manager.userVisibleTabs {
            if dict[tab.projectPath] == nil { order.append(tab.projectPath) }
            dict[tab.projectPath, default: []].append(tab)
        }
        return order.compactMap { path in
            guard let tabs = dict[path], let first = tabs.first else { return nil }
            return ProjectGroup(
                projectPath: path,
                projectName: first.projectName,
                tabs: tabs,
                hasActiveTab: tabs.contains(where: { $0.id == manager.activeTabId })
            )
        }
    }

    // MARK: - Scene

    private func drawScene(context: GraphicsContext, size: CGSize) {
        let floorY = size.height * 0.62
        let dark = settings.isDarkMode

        drawBackground(context: context, size: size, floorY: floorY)

        // Floor — 타일 패턴
        let theme = BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
        let floorBase: Color
        let dotColor: Color
        if theme != .auto, !theme.floorColors.base.isEmpty {
            floorBase = Color(hex: theme.floorColors.base)
            dotColor = Color(hex: theme.floorColors.dot)
        } else {
            floorBase = dark ? Color(hex: "0e1220") : Color(hex: "d0d4dc")
            dotColor = dark ? Color(hex: "1a2030") : Color(hex: "b8bcc8")
        }
        context.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)),
                     with: .color(floorBase))
        // 바닥 경계선
        var floorLine = Path()
        floorLine.move(to: CGPoint(x: 0, y: floorY))
        floorLine.addLine(to: CGPoint(x: size.width, y: floorY))
        context.stroke(floorLine, with: .color(dotColor.opacity(0.5)), lineWidth: 1)
        // 타일 그리드
        let tileSize: CGFloat = 20
        let floorH = size.height - floorY
        for gx in stride(from: CGFloat(0), to: size.width, by: tileSize) {
            for gy in stride(from: floorY, to: size.height, by: tileSize) {
                let isAlt = (Int(gx / tileSize) + Int((gy - floorY) / tileSize)) % 2 == 0
                if isAlt {
                    context.fill(Path(CGRect(x: gx, y: gy, width: tileSize, height: tileSize)),
                                 with: .color(dotColor.opacity(0.08)))
                }
            }
        }
        // 타일 선
        for gx in stride(from: CGFloat(0), to: size.width, by: tileSize) {
            context.fill(Path(CGRect(x: gx, y: floorY, width: 0.5, height: floorH)),
                         with: .color(dotColor.opacity(0.12)))
        }
        for gy in stride(from: floorY, to: size.height, by: tileSize) {
            context.fill(Path(CGRect(x: 0, y: gy, width: size.width, height: 0.5)),
                         with: .color(dotColor.opacity(0.12)))
        }

        // Groups (중앙 정렬) - use cached groups to avoid rebuilding every frame
        let groups = cachedGroups
        guard !groups.isEmpty else { return }
        let spacing = min(CGFloat(200), (size.width - 40) / max(1, CGFloat(groups.count)))
        let totalW = spacing * CGFloat(groups.count)
        let startX = max(30, (size.width - totalW) / 2 + spacing / 2)
        for (gi, group) in groups.enumerated() {
            let cx = startX + CGFloat(gi) * spacing
            drawDesk(context: context, x: cx, floorY: floorY, group: group)
            let workerCount = group.tabs.count
            for (wi, tab) in group.tabs.enumerated() {
                let isActive = tab.id == manager.activeTabId
                let wx: CGFloat
                if workerCount == 1 {
                    wx = cx - 15
                } else {
                    let totalWidth = CGFloat(min(workerCount, 5)) * 32
                    let startX = cx + 33 - totalWidth / 2 - 15
                    wx = startX + CGFloat(wi % 5) * 32
                }
                drawWorker(context: context, x: wx, floorY: floorY, tab: tab, index: gi * 10 + wi, isActive: isActive)
            }
        }

    }

    // MARK: - Background Themes

    private func drawBackground(context: GraphicsContext, size: CGSize, floorY: CGFloat) {
        let theme = BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
        let w = size.width
        let h = floorY

        if theme == .auto {
            drawAutoBackground(context: context, size: size, floorY: floorY)
            return
        }

        // 3-layer sky gradient
        let top = Color(hex: theme.skyColors.top)
        let bot = Color(hex: theme.skyColors.bottom)
        context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(bot))
        context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.45)), with: .color(top.opacity(0.9)))
        context.fill(Path(CGRect(x: 0, y: h * 0.35, width: w, height: h * 0.25)), with: .color(top.opacity(0.15)))

        switch theme {
        // ── 맑은 낮 / 파란 하늘 ──
        case .sunny, .clearSky:
            let sunX = w * 0.78; let sunR: CGFloat = theme == .sunny ? 11 : 9
            // Sun rays
            for ray in 0..<8 {
                let angle = Double(ray) * .pi / 4.0 + Double(frame) * 0.002
                let rx = sunX + sunR + CGFloat(cos(angle)) * sunR * 5
                let ry = 4 + sunR + CGFloat(sin(angle)) * sunR * 5
                var rp = Path(); rp.move(to: CGPoint(x: sunX + sunR, y: 4 + sunR))
                rp.addLine(to: CGPoint(x: rx - 2, y: ry)); rp.addLine(to: CGPoint(x: rx + 2, y: ry)); rp.closeSubpath()
                context.fill(rp, with: .color(Self.sunYellow.opacity(0.025)))
            }
            // Sun glow
            context.fill(Path(ellipseIn: CGRect(x: sunX - sunR * 2.5, y: 4 - sunR * 1.5, width: sunR * 5, height: sunR * 5)),
                         with: .color(Self.sunGlowLight.opacity(0.08)))
            context.fill(Path(ellipseIn: CGRect(x: sunX - sunR * 1.2, y: 4 - sunR * 0.2, width: sunR * 2.4, height: sunR * 2.4)),
                         with: .color(Self.sunGlowMid.opacity(0.25)))
            context.fill(Path(ellipseIn: CGRect(x: sunX, y: 4 + sunR * 0.4, width: sunR * 2, height: sunR * 2)),
                         with: .color(Self.sunYellow.opacity(0.9)))
            // Layered clouds (with shadow)
            for i in 0..<7 {
                let fi = CGFloat(i)
                let cx = (fi * 140 + CGFloat(frame / 2) * (0.06 + fi * 0.015) + fi * 35).truncatingRemainder(dividingBy: w + 80) - 40
                let cy = 5 + fi * 7; let cw = 30 + fi * 5; let depth = 0.48 - fi * 0.035
                context.fill(Path(ellipseIn: CGRect(x: cx + 1, y: cy + 2, width: cw, height: 9)), with: .color(Self.cloudShadow.opacity(0.05)))
                context.fill(Path(ellipseIn: CGRect(x: cx, y: cy, width: cw, height: 9)), with: .color(.white.opacity(depth)))
                context.fill(Path(ellipseIn: CGRect(x: cx + cw * 0.2, y: cy - 4, width: cw * 0.65, height: 8)), with: .color(.white.opacity(depth * 0.8)))
                context.fill(Path(ellipseIn: CGRect(x: cx + cw * 0.45, y: cy - 2, width: cw * 0.4, height: 7)), with: .color(.white.opacity(depth * 0.6)))
            }
            // Birds
            for i in 0..<3 {
                let fi = CGFloat(i)
                let bx = (fi * 200 + CGFloat(frame) * 0.15 + 80).truncatingRemainder(dividingBy: w + 40) - 20
                let by = 12 + fi * 8
                var bird = Path(); bird.move(to: CGPoint(x: bx - 3, y: by + 1))
                bird.addLine(to: CGPoint(x: bx, y: by)); bird.addLine(to: CGPoint(x: bx + 3, y: by + 1))
                context.stroke(bird, with: .color(Self.birdColor.opacity(0.18)), lineWidth: 0.6)
            }

        // ── 노을 / 골든아워 ──
        case .sunset, .goldenHour:
            let isGolden = theme == .goldenHour
            let sunCX = w * (isGolden ? 0.45 : 0.38); let sunY = h - 6
            // Horizon warm glow
            context.fill(Path(ellipseIn: CGRect(x: sunCX - w * 0.35, y: sunY - h * 0.3, width: w * 0.7, height: h * 0.65)),
                         with: .color((isGolden ? Self.sunsetOrange : Self.sunsetRed).opacity(0.12)))
            // Sun
            context.fill(Path(ellipseIn: CGRect(x: sunCX - 20, y: sunY - 16, width: 40, height: 40)),
                         with: .color((isGolden ? Self.goldenSun : Self.sunsetSunFaint).opacity(0.15)))
            context.fill(Path(ellipseIn: CGRect(x: sunCX - 10, y: sunY - 6, width: 20, height: 20)),
                         with: .color((isGolden ? Self.goldenSunBright : Self.sunsetSunBright).opacity(0.8)))
            // Sun reflection pillar
            context.fill(Path(CGRect(x: sunCX - 3, y: sunY + 4, width: 6, height: h - sunY)),
                         with: .color((isGolden ? Self.goldenReflect : Self.sunsetReflect).opacity(0.08)))
            // Cloud silhouettes (dark bottom, bright edge)
            for i in 0..<7 {
                let fi = CGFloat(i)
                let cx = (fi * 120 + CGFloat(frame) * 0.05 + 25).truncatingRemainder(dividingBy: w + 70) - 35
                let cy = h * 0.2 + fi * 6; let cw = 35 + fi * 6
                // Dark base
                context.fill(Path(ellipseIn: CGRect(x: cx, y: cy + 1, width: cw, height: 7)),
                             with: .color((isGolden ? Self.goldenCloudDark : Self.sunsetCloudDark).opacity(0.12)))
                // Bright top edge
                context.fill(Path(ellipseIn: CGRect(x: cx + 2, y: cy - 1, width: cw - 4, height: 5)),
                             with: .color((isGolden ? Self.goldenCloudBright : Self.sunsetCloudBright).opacity(0.18)))
            }
            // Horizon glow (3 layers)
            context.fill(Path(CGRect(x: 0, y: h - 8, width: w, height: 8)),
                         with: .color((isGolden ? Self.goldenHorizonA : Self.sunsetHorizonA).opacity(0.1)))
            context.fill(Path(CGRect(x: 0, y: h - 4, width: w, height: 4)),
                         with: .color((isGolden ? Self.goldenHorizonB : Self.sunsetHorizonB).opacity(0.2)))
            context.fill(Path(CGRect(x: 0, y: h - 1, width: w, height: 1)),
                         with: .color((isGolden ? Self.goldenHorizonC : Self.sunsetHorizonC).opacity(0.35)))

        // ── 황혼 ──
        case .dusk:
            // Early stars
            for i in 0..<18 {
                let fi = CGFloat(i)
                let sx = (fi * 59 + 17).truncatingRemainder(dividingBy: w)
                let sy = (fi * 21 + 5).truncatingRemainder(dividingBy: max(1, h * 0.7))
                let a = 0.06 + sin(Double(frame / 2) * 0.04 + Double(i) * 1.3) * 0.08
                if a > 0.04 { context.fill(Path(CGRect(x: sx, y: sy, width: 1, height: 1)), with: .color(.white.opacity(a))) }
            }
            // Crescent moon
            context.fill(Path(ellipseIn: CGRect(x: w * 0.82, y: 6, width: 14, height: 14)),
                         with: .color(Self.crescentMoon.opacity(0.7)))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.82 + 3, y: 4, width: 14, height: 14)),
                         with: .color(Color(hex: theme.skyColors.top).opacity(0.95)))
            // Horizon purple glow
            context.fill(Path(CGRect(x: 0, y: h * 0.7, width: w, height: h * 0.3)),
                         with: .color(Self.duskPurple.opacity(0.08)))

        // ── 달빛 ──
        case .moonlit:
            // Moon + halo
            let mx = w * 0.72
            context.fill(Path(ellipseIn: CGRect(x: mx - 18, y: -2, width: 36, height: 36)),
                         with: .color(Self.moonHalo.opacity(0.05)))
            context.fill(Path(ellipseIn: CGRect(x: mx - 10, y: 2, width: 20, height: 20)),
                         with: .color(Self.moonMid.opacity(0.12)))
            context.fill(Path(ellipseIn: CGRect(x: mx - 7, y: 5, width: 14, height: 14)),
                         with: .color(Self.moonBright.opacity(0.85)))
            // Soft stars
            for i in 0..<25 {
                let fi = CGFloat(i); let sx = (fi * 43 + 11).truncatingRemainder(dividingBy: w)
                let sy = (fi * 19 + 3).truncatingRemainder(dividingBy: max(1, h - 5))
                let a = 0.08 + sin(Double(frame / 2) * 0.025 + Double(i) * 0.9) * 0.1
                if a > 0.05 { context.fill(Path(CGRect(x: sx, y: sy, width: 1, height: 1)), with: .color(.white.opacity(a))) }
            }
            // Moonlight beam cone
            var beam = Path()
            beam.move(to: CGPoint(x: mx, y: 12))
            beam.addLine(to: CGPoint(x: mx - w * 0.12, y: h))
            beam.addLine(to: CGPoint(x: mx + w * 0.12, y: h))
            beam.closeSubpath()
            context.fill(beam, with: .color(Self.moonBeam.opacity(0.02)))
            // Ground reflection
            context.fill(Path(ellipseIn: CGRect(x: mx - 20, y: h - 3, width: 40, height: 4)),
                         with: .color(Self.moonBeam.opacity(0.06)))
            // Fireflies
            for i in 0..<5 {
                let fi = CGFloat(i)
                let fx = (fi * 170 + sin(Double(frame) * 0.03 + Double(i) * 2) * 30).truncatingRemainder(dividingBy: w)
                let fy = h * 0.5 + CGFloat(sin(Double(frame) * 0.02 + Double(i) * 1.5)) * h * 0.15
                let a = 0.15 + sin(Double(frame) * 0.06 + Double(i) * 3) * 0.1
                context.fill(Path(ellipseIn: CGRect(x: CGFloat(fx), y: fy, width: 2, height: 2)), with: .color(Self.fireflyGreen.opacity(a)))
            }

        // ── 별밤 ──
        case .starryNight:
            // Dense stars (3 layers)
            for i in 0..<40 {
                let fi = CGFloat(i); let sx = (fi * 31 + 7).truncatingRemainder(dividingBy: w)
                let sy = (fi * 17 + 2).truncatingRemainder(dividingBy: max(1, h - 3))
                let a = 0.08 + sin(Double(frame / 2) * 0.04 + Double(i) * 0.6) * 0.14
                let sz: CGFloat = i % 7 == 0 ? 2 : 1
                if a > 0.04 {
                    context.fill(Path(CGRect(x: sx, y: sy, width: sz, height: sz)), with: .color(.white.opacity(a)))
                    if sz == 2 { // bright star cross
                        context.fill(Path(CGRect(x: sx - 1, y: sy + 0.5, width: 4, height: 0.5)), with: .color(.white.opacity(a * 0.3)))
                        context.fill(Path(CGRect(x: sx + 0.5, y: sy - 1, width: 0.5, height: 4)), with: .color(.white.opacity(a * 0.3)))
                    }
                }
            }
            // Shooting star (periodic)
            if frame % 180 < 12 {
                let p = CGFloat(frame % 180) / 12.0
                let sx = w * 0.85 - p * 80; let sy = 3 + p * 30
                for t in 0..<6 { // trail
                    let tt = CGFloat(t)
                    context.fill(Path(CGRect(x: sx + tt * 4, y: sy - tt * 1.5, width: 3 - tt * 0.4, height: 1)),
                                 with: .color(.white.opacity(max(0, 0.5 - Double(t) * 0.1) * Double(1 - p))))
                }
            }

        // ── 오로라 ──
        case .aurora:
            // Stars
            for i in 0..<30 {
                let fi = CGFloat(i); let sx = (fi * 37 + 9).truncatingRemainder(dividingBy: w)
                let sy = (fi * 15 + 4).truncatingRemainder(dividingBy: max(1, h - 5))
                let a = 0.06 + sin(Double(frame / 2) * 0.03 + Double(i)) * 0.08
                if a > 0.04 { context.fill(Path(CGRect(x: sx, y: sy, width: 1, height: 1)), with: .color(.white.opacity(a))) }
            }
            // Aurora curtains (5 layers, flowing)
            for (ci, ac) in Self.auroraColors.enumerated() {
                let cfi = CGFloat(ci)
                for x in stride(from: CGFloat(0), to: w, by: 5) {
                    let yBase = h * (0.12 + cfi * 0.08)
                    let wave1 = sin(Double(x) * 0.015 + Double(frame) * 0.025 + Double(ci) * 1.8) * Double(h) * 0.1
                    let wave2 = sin(Double(x) * 0.008 + Double(frame) * 0.015 + Double(ci) * 0.7) * Double(h) * 0.05
                    let yy = yBase + CGFloat(wave1 + wave2)
                    let a = 0.04 + sin(Double(frame) * 0.02 + Double(x) * 0.008 + Double(ci) * 1.2) * 0.03
                    let hh: CGFloat = 4 + CGFloat(sin(Double(x) * 0.02 + Double(ci))) * 2
                    context.fill(Path(CGRect(x: x, y: yy, width: 6, height: hh)), with: .color(ac.opacity(a)))
                }
            }

        // ── 은하수 ──
        case .milkyWay:
            for i in 0..<45 {
                let fi = CGFloat(i); let sx = (fi * 29 + 5).truncatingRemainder(dividingBy: w)
                let sy = (fi * 11 + 1).truncatingRemainder(dividingBy: max(1, h - 2))
                let a = 0.07 + sin(Double(frame / 2) * 0.035 + Double(i) * 0.5) * 0.1
                let sz: CGFloat = i % 8 == 0 ? 2 : 1
                if a > 0.03 { context.fill(Path(CGRect(x: sx, y: sy, width: sz, height: sz)), with: .color(.white.opacity(a))) }
            }
            // Milky way band (diagonal)
            for x in stride(from: CGFloat(0), to: w, by: 2) {
                let ratio = x / w
                let yCenter = h * (0.55 - ratio * 0.35) + sin(Double(x) * 0.008) * Double(h) * 0.04
                let bandW: CGFloat = 16 + sin(Double(x) * 0.01) * 4
                context.fill(Path(CGRect(x: x, y: CGFloat(yCenter) - bandW / 2, width: 3, height: bandW)),
                             with: .color(Self.milkyBand.opacity(0.035)))
                // Color variation in band
                if Int(x) % 8 == 0 {
                    context.fill(Path(CGRect(x: x, y: CGFloat(yCenter) - 2, width: 2, height: 4)),
                                 with: .color(Self.milkyAccent.opacity(0.025)))
                }
            }

        // ── 먹구름 ──
        case .storm:
            // Multi-layer storm clouds
            for layer in 0..<3 {
                let lfi = CGFloat(layer)
                for i in 0..<(6 + layer * 2) {
                    let fi = CGFloat(i)
                    let cx = (fi * (90 - lfi * 15) + CGFloat(frame) * (0.06 + lfi * 0.02) + lfi * 50).truncatingRemainder(dividingBy: w + 60) - 30
                    let cy = lfi * 12 + fi * 5 + 2
                    let cw = 30 + fi * 6 + lfi * 10
                    context.fill(Path(ellipseIn: CGRect(x: cx, y: cy, width: cw, height: 10 + lfi * 3)),
                                 with: .color(Self.stormCloud.opacity(0.35 + Double(layer) * 0.12)))
                }
            }
            // Lightning (more dramatic)
            if frame % 100 < 3 {
                let lx = w * 0.25 + CGFloat(frame % 7) * w * 0.08
                var bolt = Path(); bolt.move(to: CGPoint(x: lx, y: 0))
                bolt.addLine(to: CGPoint(x: lx + 4, y: h * 0.3))
                bolt.addLine(to: CGPoint(x: lx - 2, y: h * 0.3))
                bolt.addLine(to: CGPoint(x: lx + 3, y: h * 0.65))
                context.stroke(bolt, with: .color(Self.lightningFlash.opacity(0.6)), lineWidth: 1.5)
                // Flash
                context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(.white.opacity(0.04)))
            }

        // ── 비 ──
        case .rain:
            // Clouds
            for i in 0..<8 {
                let fi = CGFloat(i)
                let cx = (fi * 110 + CGFloat(frame) * 0.04 + 20).truncatingRemainder(dividingBy: w + 50) - 25
                context.fill(Path(ellipseIn: CGRect(x: cx, y: fi * 5, width: 45, height: 10)),
                             with: .color(Self.rainCloud.opacity(0.45)))
            }
            // Rain (angled, layered)
            for i in 0..<40 {
                let fi = CGFloat(i)
                let rx = (fi * 31 + 8 + CGFloat(frame) * 0.3).truncatingRemainder(dividingBy: w)
                let ry = (fi * 19 + CGFloat(frame) * 2.0).truncatingRemainder(dividingBy: max(1, h + 8))
                let len: CGFloat = i % 5 == 0 ? 6 : 4
                let a = i % 3 == 0 ? 0.35 : 0.2
                var drop = Path(); drop.move(to: CGPoint(x: rx, y: ry))
                drop.addLine(to: CGPoint(x: rx - 1.5, y: ry + len))
                context.stroke(drop, with: .color(Self.raindrop.opacity(a)), lineWidth: 0.8)
            }
            // Splash particles at ground
            for i in 0..<10 {
                let fi = CGFloat(i)
                let sx = (fi * 89 + CGFloat(frame) * 0.5).truncatingRemainder(dividingBy: w)
                if (frame + i * 7) % 20 < 4 {
                    context.fill(Path(ellipseIn: CGRect(x: sx - 1, y: h - 3, width: 3, height: 1.5)),
                                 with: .color(Self.rainSplash.opacity(0.2)))
                }
            }
            // Puddle reflections
            for i in 0..<4 {
                let fi = CGFloat(i)
                let px = fi * (w / 4) + 30
                let pw: CGFloat = 20 + fi * 8
                context.fill(Path(ellipseIn: CGRect(x: px, y: h - 2, width: pw, height: 3)),
                             with: .color(Self.puddleColor.opacity(0.08)))
            }

        // ── 눈 ──
        case .snow:
            for i in 0..<35 {
                let fi = CGFloat(i)
                let drift = sin(Double(frame) * 0.015 + Double(i) * 0.8) * 10
                let sx = (fi * 37 + 12 + CGFloat(drift)).truncatingRemainder(dividingBy: w)
                let sy = (fi * 15 + CGFloat(frame) * 0.4).truncatingRemainder(dividingBy: max(1, h + 12))
                let sz: CGFloat = i % 6 == 0 ? 3 : (i % 3 == 0 ? 2.5 : 1.5)
                let a: Double = i % 6 == 0 ? 0.7 : 0.45
                context.fill(Path(ellipseIn: CGRect(x: CGFloat(sx), y: sy, width: sz, height: sz)), with: .color(.white.opacity(a)))
            }
            // Snow accumulation hint
            context.fill(Path(CGRect(x: 0, y: h - 2, width: w, height: 2)), with: .color(.white.opacity(0.15)))

        // ── 안개 ──
        case .fog:
            for i in 0..<8 {
                let fi = CGFloat(i)
                let yy = h * (0.15 + fi * 0.1)
                let drift = sin(Double(frame) * 0.008 + Double(i) * 1.8) * 20
                let fogW = w * (1.2 + CGFloat(sin(Double(i) * 2)) * 0.3)
                context.fill(Path(ellipseIn: CGRect(x: CGFloat(drift) - fogW * 0.1, y: yy, width: fogW, height: 12 + fi * 2)),
                             with: .color(.white.opacity(0.06 + Double(i) * 0.008)))
            }

        // ── 벚꽃 ──
        case .cherryBlossom:
            // Soft sun
            context.fill(Path(ellipseIn: CGRect(x: w * 0.72 - 10, y: 2, width: 20, height: 20)),
                         with: .color(Self.softSunWarm.opacity(0.7)))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.72 - 18, y: -6, width: 36, height: 36)),
                         with: .color(Self.softSunGlow.opacity(0.12)))
            // Cherry tree branches (top corners)
            for side in 0..<2 {
                let baseX: CGFloat = side == 0 ? -5 : w - 25
                for b in 0..<4 {
                    let bf = CGFloat(b)
                    let bx = baseX + (side == 0 ? bf * 12 : -bf * 12)
                    let by = bf * 5
                    context.fill(Path(CGRect(x: bx, y: by, width: 18, height: 2)),
                                 with: .color(Self.branchBrown.opacity(0.2)))
                    // Blossom clusters on branches
                    for c in 0..<3 {
                        let cx = bx + CGFloat(c) * 6 + 2
                        context.fill(Path(ellipseIn: CGRect(x: cx, y: by - 2, width: 5, height: 4)),
                                     with: .color(Self.blossomPink.opacity(0.3)))
                    }
                }
            }
            // Petals (varied sizes, rotation feel)
            for i in 0..<25 {
                let fi = CGFloat(i)
                let drift = sin(Double(frame) * 0.02 + Double(i) * 1.5) * 15
                let px = (fi * 43 + 18 + CGFloat(drift)).truncatingRemainder(dividingBy: w)
                let py = (fi * 17 + CGFloat(frame) * 0.35).truncatingRemainder(dividingBy: max(1, h + 15))
                let sz = 2 + sin(Double(i) * 0.7) * 1
                let rot = sin(Double(frame) * 0.03 + Double(i) * 0.9)
                context.fill(Path(ellipseIn: CGRect(x: CGFloat(px), y: py, width: CGFloat(sz + rot), height: CGFloat(sz * 0.6))),
                             with: .color(Color(hex: i % 3 == 0 ? "ffb0c8" : (i % 3 == 1 ? "ffc0d0" : "ff90b0")).opacity(0.5)))
            }

        // ── 단풍 ──
        case .autumn:
            // Low warm sun
            let sunCX = w * 0.65
            context.fill(Path(ellipseIn: CGRect(x: sunCX - 14, y: h - 18, width: 28, height: 28)),
                         with: .color(Self.autumnSunA.opacity(0.5)))
            context.fill(Path(ellipseIn: CGRect(x: sunCX - 25, y: h - 30, width: 50, height: 50)),
                         with: .color(Self.autumnSunB.opacity(0.08)))
            // Leaves (3 colors, spin feel)
            let leafColors = Self.leafColors
            for i in 0..<18 {
                let fi = CGFloat(i)
                let drift = sin(Double(frame) * 0.02 + Double(i) * 2.3) * 12
                let lx = (fi * 51 + 10 + CGFloat(drift)).truncatingRemainder(dividingBy: w)
                let ly = (fi * 14 + CGFloat(frame) * 0.3).truncatingRemainder(dividingBy: max(1, h + 10))
                let lc = leafColors[i % leafColors.count]
                let sz = 2.0 + sin(Double(i) * 1.2) * 0.8
                context.fill(Path(ellipseIn: CGRect(x: CGFloat(lx), y: ly, width: CGFloat(sz), height: CGFloat(sz * 0.7))),
                             with: .color(lc.opacity(0.55)))
            }

        // ── 숲 ──
        case .forest:
            // Tree silhouettes (varied shapes)
            let treeCount = 14
            for i in 0..<treeCount {
                let fi = CGFloat(i)
                let tx = fi * (w / CGFloat(treeCount)) + 5
                let treeH = h * (0.25 + sin(Double(fi) * 1.3) * 0.12)
                let trunkW: CGFloat = 3 + fi.truncatingRemainder(dividingBy: 2) * 2
                // Trunk
                context.fill(Path(CGRect(x: tx + 4, y: h - treeH * 0.3, width: trunkW, height: treeH * 0.3)),
                             with: .color(Self.trunkGreen.opacity(0.3)))
                // Canopy (triangular)
                var tree = Path()
                tree.move(to: CGPoint(x: tx - 2, y: h - treeH * 0.25))
                tree.addLine(to: CGPoint(x: tx + trunkW / 2 + 2, y: h - treeH))
                tree.addLine(to: CGPoint(x: tx + trunkW + 6, y: h - treeH * 0.25))
                tree.closeSubpath()
                context.fill(tree, with: .color(Color(hex: i % 2 == 0 ? "1a3818" : "1e4020").opacity(0.35)))
            }
            // Sun rays through trees
            for i in 0..<4 {
                let rx = w * (0.2 + CGFloat(i) * 0.18)
                context.fill(Path(CGRect(x: rx, y: 0, width: 3, height: h)),
                             with: .color(Self.sunRayGreen.opacity(0.03)))
            }

        // ── 네온시티 ──
        case .neonCity:
            let bCount = 16
            for i in 0..<bCount {
                let fi = CGFloat(i)
                let bx = fi * (w / CGFloat(bCount))
                let bw = w / CGFloat(bCount) - 2
                let bh: CGFloat = 12 + fi.truncatingRemainder(dividingBy: 5) * 7 + (i % 3 == 0 ? 10 : 0)
                context.fill(Path(CGRect(x: bx, y: h - bh, width: bw, height: bh)),
                             with: .color(Self.neonBuildingDark.opacity(0.75)))
                // Windows (multi-color)
                let windowColors = Self.neonWindowColors
                for wy in stride(from: h - bh + 3, to: h - 2, by: 4) {
                    for wx in stride(from: bx + 2, to: bx + bw - 2, by: 4) {
                        let on = (Int(fi) + Int(wy) + Int(wx)) % 3 != 0
                        if on {
                            let wc = windowColors[(Int(fi) + Int(wy)) % windowColors.count]
                            context.fill(Path(CGRect(x: wx, y: wy, width: 2, height: 2)), with: .color(wc.opacity(0.35)))
                        }
                    }
                }
            }
            // Neon glow lines
            let nP = sin(Double(frame) * 0.05)
            context.fill(Path(CGRect(x: 0, y: h - 3, width: w, height: 3)),
                         with: .color(Self.neonPink.opacity(0.2 + nP * 0.06)))
            context.fill(Path(CGRect(x: 0, y: h - 1, width: w, height: 1)),
                         with: .color(Self.neonCyan.opacity(0.12 + nP * 0.04)))
            // Neon signs on buildings
            let signs = [(w * 0.15, Self.neonPink), (w * 0.45, Self.neonCyan), (w * 0.7, Self.neonYellow)]
            for (sx, sc) in signs {
                let sy = h - 20 - CGFloat(Int(sx) % 3) * 6
                let pulse = 0.3 + sin(Double(frame) * 0.08 + Double(sx) * 0.01) * 0.15
                context.fill(Path(CGRect(x: sx, y: sy, width: 12, height: 3)), with: .color(sc.opacity(pulse)))
                context.fill(Path(ellipseIn: CGRect(x: sx - 4, y: sy - 3, width: 20, height: 9)), with: .color(sc.opacity(pulse * 0.12)))
            }
            // Rain puddle reflections
            for i in 0..<6 {
                let fi = CGFloat(i)
                let px = fi * (w / 6) + 10
                let rc = i % 2 == 0 ? Self.neonPink : Self.neonCyan
                context.fill(Path(ellipseIn: CGRect(x: px, y: h - 1, width: 15, height: 2)), with: .color(rc.opacity(0.06)))
            }

        // ── 바다 ──
        case .ocean:
            // Sun
            context.fill(Path(ellipseIn: CGRect(x: w * 0.6 - 4, y: 4, width: 24, height: 24)),
                         with: .color(Self.oceanSunLight.opacity(0.1)))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.6, y: 6, width: 16, height: 16)),
                         with: .color(Self.oceanSunBright.opacity(0.7)))
            // Sun sparkle on water
            let sparkX = w * 0.6 + 8
            for i in 0..<8 {
                let fi = CGFloat(i)
                let sx = sparkX - 15 + fi * 4 + CGFloat(sin(Double(frame) * 0.05 + Double(i) * 1.5)) * 3
                let sy = h - 8 - fi * 1.5
                let a = 0.15 + sin(Double(frame) * 0.08 + Double(i) * 2) * 0.12
                context.fill(Path(CGRect(x: sx, y: sy, width: 2, height: 1)), with: .color(.white.opacity(a)))
            }
            // Seagulls
            for i in 0..<2 {
                let fi = CGFloat(i)
                let gx = (fi * 250 + CGFloat(frame) * 0.12 + 100).truncatingRemainder(dividingBy: w + 50) - 25
                let gy = 10 + fi * 6 + CGFloat(sin(Double(frame) * 0.04 + Double(i) * 3)) * 2
                var gull = Path(); gull.move(to: CGPoint(x: gx - 3, y: gy + 1))
                gull.addLine(to: CGPoint(x: gx, y: gy)); gull.addLine(to: CGPoint(x: gx + 3, y: gy + 1))
                context.stroke(gull, with: .color(.white.opacity(0.35)), lineWidth: 0.6)
            }
            // Layered waves
            for wave in 0..<6 {
                let wfi = CGFloat(wave)
                let waveY = h - wfi * 3 - 1
                let speed = 0.05 + Double(wave) * 0.008
                let amp = 1.5 + wfi * 0.3
                for x in stride(from: CGFloat(0), to: w, by: 4) {
                    let yOff = sin(Double(x) * 0.03 + Double(frame) * speed + Double(wave) * 1.2) * amp
                    let a = 0.08 - Double(wave) * 0.01
                    context.fill(Path(CGRect(x: x, y: waveY + CGFloat(yOff), width: 5, height: 2)),
                                 with: .color((wave < 3 ? Self.oceanWaveA : Self.oceanWaveB).opacity(a)))
                }
            }

        // ── 사막 ──
        case .desert:
            // Blazing sun
            let sunCX = w * 0.55
            context.fill(Path(ellipseIn: CGRect(x: sunCX - 25, y: -8, width: 50, height: 50)),
                         with: .color(Self.oceanSunLight.opacity(0.08)))
            context.fill(Path(ellipseIn: CGRect(x: sunCX - 12, y: 3, width: 24, height: 24)),
                         with: .color(Self.desertSunMid.opacity(0.2)))
            context.fill(Path(ellipseIn: CGRect(x: sunCX - 8, y: 7, width: 16, height: 16)),
                         with: .color(Self.desertSunBright.opacity(0.85)))
            // Heat shimmer (more visible)
            for x in stride(from: CGFloat(0), to: w, by: 5) {
                let yOff = sin(Double(x) * 0.04 + Double(frame) * 0.07) * 2
                context.fill(Path(CGRect(x: x, y: h - 4 + CGFloat(yOff), width: 4, height: 1.5)),
                             with: .color(.white.opacity(0.06)))
            }
            // Distant dunes silhouette
            for x in stride(from: CGFloat(0), to: w, by: 3) {
                let duneY = h - 3 - sin(Double(x) * 0.015) * 4
                context.fill(Path(CGRect(x: x, y: CGFloat(duneY), width: 4, height: CGFloat(h - duneY))),
                             with: .color(Self.duneSand.opacity(0.08)))
            }

        // ── 화산 ──
        case .volcano:
            // Red sky glow
            context.fill(Path(ellipseIn: CGRect(x: w * 0.25, y: h * 0.4, width: w * 0.5, height: h * 0.6)),
                         with: .color(Self.volcanoGlow.opacity(0.06)))
            // Lava glow (pulsing)
            let pulse = 0.12 + sin(Double(frame) * 0.04) * 0.06
            context.fill(Path(CGRect(x: 0, y: h - 6, width: w, height: 6)),
                         with: .color(Self.lavaA.opacity(pulse)))
            context.fill(Path(CGRect(x: 0, y: h - 3, width: w, height: 3)),
                         with: .color(Self.lavaB.opacity(pulse * 0.6)))
            // Ash & embers rising
            for i in 0..<18 {
                let fi = CGFloat(i)
                let ax = (fi * 47 + 8).truncatingRemainder(dividingBy: w)
                let ay = (CGFloat(frame) * (0.2 + Double(i % 3) * 0.1) + fi * 17).truncatingRemainder(dividingBy: max(1, h))
                let aY = h - ay
                let isEmber = i % 4 == 0
                let c = isEmber ? Self.emberColor : Self.ashColor
                let a = isEmber ? 0.45 : 0.2
                let sz: CGFloat = isEmber ? 2 : 1
                context.fill(Path(CGRect(x: ax, y: aY, width: sz, height: sz)), with: .color(c.opacity(a)))
            }

        case .auto:
            break
        }
    }

    private func drawAutoBackground(context: GraphicsContext, size: CGSize, floorY: CGFloat) {
        let dark = settings.isDarkMode
        context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: floorY)),
                     with: .color(dark ? Color(hex: "0a0d18") : Color(hex: "dce4f0")))
        if dark {
            for i in 0..<30 {
                let fi = CGFloat(i)
                let sx = (fi * 41 + 17).truncatingRemainder(dividingBy: size.width)
                let sy = (fi * 29 + 5).truncatingRemainder(dividingBy: max(1, floorY - 8))
                let alpha = 0.1 + sin(Double(frame / 2) * 0.03 + Double(i) * 0.9) * 0.15
                if alpha > 0.08 {
                    context.fill(Path(CGRect(x: sx, y: sy, width: 1, height: 1)),
                                 with: .color(.white.opacity(alpha)))
                }
            }
        } else {
            for i in 0..<6 {
                let fi = CGFloat(i)
                let cx = (fi * 137 + CGFloat(frame / 2) * 0.15 + 30).truncatingRemainder(dividingBy: size.width + 60) - 30
                let cy = (fi * 23 + 8).truncatingRemainder(dividingBy: max(1, floorY - 20))
                let w = 20 + fi * 5
                context.fill(Path(ellipseIn: CGRect(x: cx, y: cy, width: w, height: 8)),
                             with: .color(.white.opacity(0.5)))
                context.fill(Path(ellipseIn: CGRect(x: cx + 6, y: cy - 3, width: w * 0.7, height: 7)),
                             with: .color(.white.opacity(0.4)))
            }
        }
    }

    // MARK: - Desk (one per project group)

    private func drawDesk(context: GraphicsContext, x: CGFloat, floorY: CGFloat, group: ProjectGroup) {
        let dy = floorY - 8
        let dark = settings.isDarkMode
        let isActive = group.hasActiveTab

        let deskW: CGFloat = min(66 + CGFloat(max(0, group.tabs.count - 1)) * 20, 140)
        let deskX = x + 33 - deskW / 2

        let deskColor = dark
            ? (isActive ? Color(hex: "2a3040") : Color(hex: "1e2430"))
            : (isActive ? Color(hex: "a8b0c0") : Color(hex: "bcc4d0"))
        let legColor = dark ? Color(hex: "181c28") : Color(hex: "9aa0b0")

        // 의자 (책상 앞)
        let chairX = x + 33 - 8
        let chairY = floorY + 2
        let chairColor = dark ? Color(hex: "1a2030") : Color(hex: "a0a8b8")
        // 좌석
        context.fill(Path(CGRect(x: chairX, y: chairY, width: 16, height: 4)), with: .color(chairColor))
        // 등받이
        context.fill(Path(CGRect(x: chairX + 2, y: chairY + 4, width: 12, height: 10)), with: .color(chairColor.opacity(0.7)))
        // 다리
        context.fill(Path(CGRect(x: chairX + 3, y: chairY + 14, width: 2, height: 4)), with: .color(legColor))
        context.fill(Path(CGRect(x: chairX + 11, y: chairY + 14, width: 2, height: 4)), with: .color(legColor))

        // 책상 상판
        context.fill(Path(CGRect(x: deskX, y: dy, width: deskW, height: 5)), with: .color(deskColor))
        // 책상 다리
        context.fill(Path(CGRect(x: deskX + 4, y: dy + 5, width: 3, height: 10)), with: .color(legColor))
        context.fill(Path(CGRect(x: deskX + deskW - 7, y: dy + 5, width: 3, height: 10)), with: .color(legColor))
        // 책상 위 키보드
        let kbX = x + 33 - 10
        context.fill(Path(CGRect(x: kbX, y: dy - 2, width: 20, height: 3)), with: .color(dark ? Color(hex: "1a1e28") : Color(hex: "8890a0")))
        // 키보드 키 디테일
        for ki in 0..<4 {
            context.fill(Path(CGRect(x: kbX + 2 + CGFloat(ki) * 5, y: dy - 1, width: 3, height: 1)),
                         with: .color(dark ? Color(hex: "252a38") : Color(hex: "a0a8b8")))
        }

        // 모니터
        let monX = x + 33 - 21
        context.fill(Path(CGRect(x: monX, y: dy - 28, width: 42, height: 26)),
                     with: .color(dark ? Color(hex: "0a0d14") : Color(hex: "3a3e4a")))
        // 모니터 프레임 하이라이트 (상단)
        context.fill(Path(CGRect(x: monX, y: dy - 28, width: 42, height: 1)),
                     with: .color(dark ? Color(hex: "2a3040") : Color(hex: "5a6070")))
        // 모니터 스탠드
        context.fill(Path(CGRect(x: x + 29, y: dy - 2, width: 8, height: 2)),
                     with: .color(dark ? Color(hex: "161a24") : Color(hex: "5a5e6a")))

        // 화면 내용
        let screenColor: Color
        let act = group.primaryActivity
        switch act {
        case .thinking: screenColor = Theme.purple.opacity(0.5)
        case .writing: screenColor = Theme.green.opacity(0.4)
        case .reading: screenColor = Theme.accent.opacity(0.4)
        case .searching: screenColor = Theme.cyan.opacity(0.4)
        case .running: screenColor = Theme.yellow.opacity(0.4)
        case .error: screenColor = Theme.red.opacity(0.4)
        case .done: screenColor = Theme.green.opacity(0.5)
        default: screenColor = group.isAnyRunning ? Theme.accent.opacity(dark ? 0.12 : 0.25) : (dark ? Color(hex: "141820") : Color(hex: "4a5060"))
        }
        context.fill(Path(CGRect(x: monX + 2, y: dy - 26, width: 38, height: 22)), with: .color(screenColor))

        // 화면 코드 라인 애니메이션
        if group.isAnyRunning {
            let lc = dark ? screenColor.opacity(2) : Theme.overlayBg.opacity(0.4)
            for l in 0..<5 {
                let indent = CGFloat((l * 3 + frame / 6) % 4) * 3
                let w = CGFloat(5 + (frame / 4 + l * 7) % 22)
                context.fill(Path(CGRect(x: monX + 5 + indent, y: dy - 24 + CGFloat(l) * 4, width: w, height: 1.5)),
                             with: .color(lc))
            }
        }

        // 모니터 LED (전원 표시)
        let ledColor = group.isAnyRunning ? Theme.green.opacity(0.8) : (dark ? Color(hex: "333") : Color(hex: "888"))
        context.fill(Path(CGRect(x: monX + 19, y: dy - 3, width: 3, height: 1)), with: .color(ledColor))

        // 프로젝트 이름
        context.draw(
            Text(group.projectName)
                .font(Theme.mono(7, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? Theme.textPrimary : Theme.textSecondary),
            at: CGPoint(x: x + 33, y: floorY + 26)
        )

        if group.tabs.count > 1 {
            context.draw(
                Text("x\(group.tabs.count)")
                    .font(Theme.mono(6, weight: .bold))
                    .foregroundColor(Theme.cyan),
                at: CGPoint(x: x + 33, y: floorY + 36)
            )
        }

        if group.isAllCompleted {
            // 완료 배지
            let badgeY = dy - 34
            context.fill(Path(CGRect(x: x + 22, y: badgeY - 3, width: 24, height: 10)),
                         with: .color(Theme.green.opacity(0.15)))
            context.draw(
                Text("DONE")
                    .font(Theme.mono(7, weight: .bold))
                    .foregroundColor(Theme.green),
                at: CGPoint(x: x + 33, y: badgeY + 2)
            )
        }
    }

    // MARK: - Worker

    private func drawWorker(context: GraphicsContext, x: CGFloat, floorY: CGFloat, tab: TerminalTab, index: Int, isActive: Bool) {
        let s: CGFloat = 2.0
        let state = tab.workerState
        let baseY = floorY - 21 * s
        let dark = settings.isDarkMode

        // CharacterRegistry에서 종족 정보 가져오기
        let char = tab.characterId.flatMap { cid in CharacterRegistry.shared.allCharacters.first(where: { $0.id == cid }) }
        let species = char?.species ?? .human

        let bob: CGFloat
        switch state {
        case .thinking: bob = sin(Double(frame) * 0.12 + Double(index)) * 0.4
        case .writing, .coding: bob = sin(Double(frame) * 0.35 + Double(index)) * 1.0
        case .searching: bob = sin(Double(frame) * 0.5 + Double(index)) * 0.6
        case .running: bob = sin(Double(frame) * 0.45 + Double(index)) * 1.2
        default: bob = 0
        }
        let y = baseY + bob

        let fur = char.map { Color(hex: $0.skinTone) } ?? Color(hex: "ffd5b8")
        let hair = char.map { Color(hex: $0.hairColor) } ?? Color(hex: "4a3728")
        let shirt: Color
        switch state {
        case .success: shirt = Theme.green; case .error: shirt = Theme.red; case .thinking: shirt = Theme.purple
        default: shirt = tab.workerColor
        }
        let eye = Color(hex: "1a1a1a")

        func px(_ px: CGFloat, _ py: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
            context.fill(Path(CGRect(x: x + px * s, y: y + py * s, width: w * s, height: h * s)), with: .color(c))
        }

        context.fill(Path(ellipseIn: CGRect(x: x + 3 * s, y: floorY - 2, width: 10 * s, height: 3)),
                     with: .color(.black.opacity(dark ? 0.12 : 0.08)))

        switch species {
        case .cat:
            px(3, -1, 3, 3, fur); px(10, -1, 3, 3, fur)
            px(4, 1, 8, 6, fur)
            px(5, 3, 2, 2, Color(hex: "60c060")); px(6, 3, 1, 2, eye)
            px(9, 3, 2, 2, Color(hex: "60c060")); px(10, 3, 1, 2, eye)
            px(7, 5, 2, 1, Color(hex: "f08080"))
            px(4, 7, 8, 7, shirt)
            px(3, 12, 3, 2, fur); px(10, 12, 3, 2, fur)
            px(4, 14, 3, 3, fur); px(9, 14, 3, 3, fur)
            px(13, 10, 2, 2, fur); px(14, 8, 2, 3, fur)
        case .dog:
            px(2, 1, 3, 5, hair); px(11, 1, 3, 5, hair)
            px(4, 0, 8, 7, fur)
            px(5, 3, 2, 2, .white); px(6, 4, 1, 1, eye); px(9, 3, 2, 2, .white); px(10, 4, 1, 1, eye)
            px(7, 5, 2, 1, eye); px(7, 6, 2, 1, Color(hex: "f06060"))
            px(4, 7, 8, 7, shirt)
            px(4, 14, 3, 3, fur); px(9, 14, 3, 3, fur)
            px(13, 5, 2, 2, fur); px(14, 3, 2, 3, fur)
        case .rabbit:
            px(5, -4, 2, 5, fur); px(9, -4, 2, 5, fur)
            px(4, 1, 8, 6, fur)
            px(5, 3, 2, 2, Color(hex: "d04060")); px(6, 3, 1, 1, eye)
            px(9, 3, 2, 2, Color(hex: "d04060")); px(10, 3, 1, 1, eye)
            px(4, 7, 8, 7, shirt)
            px(5, 14, 3, 3, fur); px(8, 14, 3, 3, fur); px(13, 11, 3, 3, .white)
        case .bear:
            px(3, -1, 3, 3, fur); px(10, -1, 3, 3, fur)
            px(4, 1, 8, 7, fur); px(6, 5, 4, 3, Color(hex: "d0b090"))
            px(5, 3, 2, 2, eye); px(9, 3, 2, 2, eye); px(7, 5, 2, 1, Color(hex: "333"))
            px(3, 8, 10, 7, shirt)
            px(4, 15, 4, 3, fur); px(8, 15, 4, 3, fur)
        case .penguin:
            px(4, 0, 8, 5, Color(hex: "2a2a3a")); px(5, 2, 6, 4, .white)
            px(6, 3, 1, 1, eye); px(9, 3, 1, 1, eye); px(7, 5, 2, 1, Theme.yellow)
            px(3, 6, 10, 8, Color(hex: "2a2a3a")); px(5, 7, 6, 6, .white)
            px(5, 14, 3, 2, Theme.yellow); px(8, 14, 3, 2, Theme.yellow)
        case .fox:
            px(3, -1, 3, 4, Color(hex: "e07030")); px(10, -1, 3, 4, Color(hex: "e07030"))
            px(4, 1, 8, 6, fur); px(4, 4, 3, 3, .white); px(9, 4, 3, 3, .white)
            px(5, 3, 2, 1, Color(hex: "f0c020")); px(6, 3, 1, 1, eye)
            px(9, 3, 2, 1, Color(hex: "f0c020")); px(10, 3, 1, 1, eye)
            px(4, 7, 8, 7, shirt); px(4, 14, 3, 3, fur); px(9, 14, 3, 3, fur)
            px(12, 9, 3, 2, fur); px(13, 7, 3, 4, fur)
        case .robot:
            px(7, -3, 2, 3, Color(hex: "8090a0")); px(6, -4, 4, 1, Color(hex: "60f0a0"))
            px(3, 0, 10, 7, Color(hex: "a0b0c0")); px(4, 1, 8, 5, Color(hex: "8090a0"))
            px(5, 3, 2, 2, Color(hex: "60f0a0")); px(9, 3, 2, 2, Color(hex: "60f0a0"))
            px(3, 7, 10, 8, shirt)
            px(1, 9, 2, 5, Color(hex: "8090a0")); px(13, 9, 2, 5, Color(hex: "8090a0"))
            px(4, 15, 3, 3, Color(hex: "708090")); px(9, 15, 3, 3, Color(hex: "708090"))
        case .claude:
            let c = char.map { Color(hex: $0.shirtColor) } ?? tab.workerColor
            px(4, 1, 8, 1, c); px(3, 2, 10, 7, c)
            px(1, 3, 2, 2, c); px(0, 4, 1, 1, c); px(13, 3, 2, 2, c); px(15, 4, 1, 1, c)
            px(5, 4, 1, 2, Color(hex: "2a1810")); px(10, 4, 1, 2, Color(hex: "2a1810"))
            px(4, 9, 1, 3, c); px(6, 9, 1, 3, c); px(9, 9, 1, 3, c); px(11, 9, 1, 3, c)
        case .alien:
            // 큰 둥근 머리 + 거대한 아몬드 눈 + 안테나 + 가는 몸 + 글로우
            let glow = Color(hex: "40ff80")
            px(7, -4, 2, 1, glow); px(6, -3, 4, 1, glow.opacity(0.6)) // 안테나 + 빛
            px(3, -1, 10, 2, fur) // 넓은 이마
            px(2, 1, 12, 6, fur) // 큰 머리
            px(1, 2, 1, 3, fur) // 머리 옆 볼록
            px(14, 2, 1, 3, fur)
            // 큰 아몬드 눈 (검은 배경 + 녹색 동공 + 하이라이트)
            px(3, 2, 4, 4, Color(hex: "0a0a0a")); px(9, 2, 4, 4, Color(hex: "0a0a0a"))
            px(5, 3, 2, 2, glow); px(11, 3, 2, 2, glow)
            px(4, 3, 1, 1, glow.opacity(0.3)); px(10, 3, 1, 1, glow.opacity(0.3)) // 눈 반사
            // 가느다란 몸 + 옷
            px(5, 7, 6, 5, shirt)
            px(3, 8, 2, 3, shirt); px(11, 8, 2, 3, shirt) // 가는 팔
            px(2, 10, 2, 2, fur); px(12, 10, 2, 2, fur) // 긴 손가락
            px(5, 12, 2, 4, fur); px(9, 12, 2, 4, fur) // 가는 다리
            px(4, 15, 4, 1, fur); px(8, 15, 4, 1, fur) // 넓은 발

        case .ghost:
            // 반투명 느낌 + 물결 하단 + 큰 둥근 눈 + 볼터치
            let ghostBody = fur.opacity(0.85)
            px(5, -1, 6, 2, ghostBody) // 둥근 머리 상단
            px(3, 1, 10, 7, ghostBody) // 메인 몸
            px(2, 3, 1, 3, ghostBody); px(13, 3, 1, 3, ghostBody) // 옆면 볼록
            // 큰 둥근 눈 (검은 원 + 하이라이트)
            px(4, 3, 3, 3, Color(hex: "1a1a2a")); px(9, 3, 3, 3, Color(hex: "1a1a2a"))
            px(5, 3, 1, 1, .white.opacity(0.4)); px(10, 3, 1, 1, .white.opacity(0.4)) // 하이라이트
            // 볼터치
            px(3, 5, 2, 1, Color(hex: "f0a0b0").opacity(0.3)); px(11, 5, 2, 1, Color(hex: "f0a0b0").opacity(0.3))
            // 입 (작은 O)
            px(7, 6, 2, 1, Color(hex: "404060"))
            // 물결치는 하단 (3단 물결)
            px(2, 8, 3, 3, ghostBody); px(5, 9, 3, 2, ghostBody); px(8, 8, 3, 3, ghostBody); px(11, 9, 2, 2, ghostBody)
            px(3, 11, 2, 2, ghostBody); px(7, 11, 2, 1, ghostBody); px(10, 11, 2, 2, ghostBody)

        case .dragon:
            // 뿔 2개 + 비늘 무늬 + 날개 + 꼬리 + 불꽃 입김
            let horn = Color(hex: "f0c030")
            // 뿔 (지그재그)
            px(3, -3, 2, 1, horn); px(4, -2, 2, 2, horn)
            px(11, -3, 2, 1, horn); px(10, -2, 2, 2, horn)
            // 머리
            px(4, 0, 8, 6, fur)
            // 눈 (세로 슬릿 동공)
            px(5, 2, 2, 3, Color(hex: "ff4020")); px(6, 3, 1, 1, Color(hex: "ffff40"))
            px(9, 2, 2, 3, Color(hex: "ff4020")); px(10, 3, 1, 1, Color(hex: "ffff40"))
            // 콧구멍
            px(7, 4, 1, 1, Color(hex: "301010")); px(8, 4, 1, 1, Color(hex: "301010"))
            // 입에서 불꽃 (작은)
            if frame % 30 < 15 {
                px(12, 4, 2, 1, Color(hex: "ff6020").opacity(0.6)); px(14, 3, 1, 1, Color(hex: "ff4010").opacity(0.4))
            }
            // 몸 + 비늘 무늬
            px(3, 6, 10, 6, shirt)
            px(5, 7, 2, 1, shirt.opacity(0.6)); px(7, 8, 2, 1, shirt.opacity(0.6)); px(9, 9, 2, 1, shirt.opacity(0.6)) // 비늘
            // 날개 (삼각형)
            px(0, 4, 3, 2, shirt.opacity(0.5)); px(0, 6, 2, 2, shirt.opacity(0.4)); px(0, 3, 1, 1, shirt.opacity(0.3))
            px(13, 4, 3, 2, shirt.opacity(0.5)); px(14, 6, 2, 2, shirt.opacity(0.4)); px(15, 3, 1, 1, shirt.opacity(0.3))
            // 다리 (짧고 튼튼)
            px(4, 12, 3, 3, fur); px(9, 12, 3, 3, fur)
            // 꼬리 (오른쪽으로)
            px(13, 10, 2, 1, fur); px(14, 9, 2, 1, fur); px(15, 8, 1, 1, Color(hex: "ff6020"))

        case .chicken:
            // 빨간 볏 + 둥근 몸 + 주황 부리 + 턱수염 + 날개접힌 + 가는 다리
            px(6, -3, 4, 1, Color(hex: "e03020")) // 볏 꼭대기
            px(5, -2, 6, 2, Color(hex: "e03020")) // 볏 메인
            px(5, 0, 6, 5, fur) // 둥근 머리
            // 눈 (동그란 검은 눈)
            px(6, 2, 2, 2, Color(hex: "101010")); px(9, 2, 1, 1, Color(hex: "101010"))
            // 부리 (삼각형)
            px(11, 2, 2, 1, Color(hex: "f0a020")); px(12, 3, 1, 1, Color(hex: "f0a020"))
            // 턱수염
            px(6, 5, 2, 2, Color(hex: "f03020"))
            // 둥근 몸
            px(3, 5, 10, 7, shirt)
            // 접힌 날개 (작은 삼각)
            px(2, 6, 2, 3, shirt.opacity(0.7)); px(1, 7, 1, 2, shirt.opacity(0.5))
            px(12, 6, 2, 3, shirt.opacity(0.7)); px(14, 7, 1, 2, shirt.opacity(0.5))
            // 꼬리 깃털
            px(1, 5, 2, 1, shirt.opacity(0.6)); px(0, 4, 2, 1, shirt.opacity(0.4))
            // 가는 다리 + 발톱
            px(5, 12, 1, 4, Color(hex: "f0a020")); px(10, 12, 1, 4, Color(hex: "f0a020"))
            px(4, 15, 3, 1, Color(hex: "f0a020")); px(9, 15, 3, 1, Color(hex: "f0a020"))

        case .owl:
            // 귀깃 + 큰 원형 눈 + V자 부리 + 가슴무늬 + 접힌 날개
            // 귀깃 (삼각)
            px(3, -2, 2, 1, hair); px(2, -1, 3, 2, hair)
            px(11, -2, 2, 1, hair); px(11, -1, 3, 2, hair)
            px(4, 1, 8, 6, fur) // 둥근 머리
            // 안면 원형 디스크
            px(3, 2, 4, 4, Color(hex: "f0e8d0")); px(9, 2, 4, 4, Color(hex: "f0e8d0"))
            // 큰 원형 눈 (노란 홍채 + 검은 동공)
            px(4, 3, 2, 2, Color(hex: "f0c030")); px(10, 3, 2, 2, Color(hex: "f0c030"))
            px(5, 3, 1, 1, Color(hex: "101010")); px(11, 3, 1, 1, Color(hex: "101010"))
            // V자 부리
            px(7, 5, 1, 1, Color(hex: "c08020")); px(8, 5, 1, 1, Color(hex: "c08020"))
            px(7, 6, 2, 1, Color(hex: "a06818"))
            // 몸 + 가슴 V무늬
            px(3, 7, 10, 6, shirt)
            px(5, 8, 6, 1, Color(hex: "f0e8d0").opacity(0.4)) // 가슴 밝은 줄
            px(6, 9, 4, 1, Color(hex: "f0e8d0").opacity(0.3))
            // 접힌 날개
            px(1, 7, 2, 5, hair); px(0, 8, 1, 3, hair.opacity(0.6))
            px(13, 7, 2, 5, hair); px(15, 8, 1, 3, hair.opacity(0.6))
            // 발톱
            px(5, 13, 2, 2, Color(hex: "a08040")); px(9, 13, 2, 2, Color(hex: "a08040"))

        case .frog:
            // 튀어나온 큰 눈 + 넓적한 입 + 배 색 + 물갈퀴 발
            // 튀어나온 눈 (위로 솟은)
            px(3, -1, 4, 4, fur); px(9, -1, 4, 4, fur) // 눈 볼록
            px(4, 0, 2, 2, .white); px(10, 0, 2, 2, .white) // 흰자
            px(5, 0, 1, 2, Color(hex: "101010")); px(11, 0, 1, 2, Color(hex: "101010")) // 동공
            // 넓적한 머리
            px(3, 3, 10, 4, fur)
            // 넓은 입 (미소)
            px(4, 5, 8, 1, Color(hex: "306030")); px(5, 6, 6, 1, Color(hex: "f06060").opacity(0.5))
            // 몸 + 밝은 배
            px(3, 7, 10, 5, shirt)
            px(5, 8, 6, 3, Color(hex: "c0e0a0").opacity(0.3)) // 밝은 배
            // 팔 (살짝 벌린)
            px(1, 8, 2, 3, shirt); px(0, 10, 2, 2, fur) // 물갈퀴 손
            px(13, 8, 2, 3, shirt); px(14, 10, 2, 2, fur)
            // 다리 (쪼그린 자세 느낌)
            px(3, 12, 4, 2, fur); px(9, 12, 4, 2, fur)
            px(2, 13, 5, 1, fur); px(9, 13, 5, 1, fur) // 넓은 물갈퀴 발

        case .panda:
            // 둥근 귀 + 눈 패치 + 통통한 몸 + 대나무
            // 둥근 검은 귀
            px(2, -1, 3, 3, Color(hex: "1a1a1a")); px(11, -1, 3, 3, Color(hex: "1a1a1a"))
            // 흰 얼굴
            px(4, 1, 8, 6, fur)
            // 눈 패치 (검은 타원)
            px(4, 2, 3, 4, Color(hex: "1a1a1a")); px(9, 2, 3, 4, Color(hex: "1a1a1a"))
            // 눈 (흰 점)
            px(5, 3, 1, 2, .white); px(10, 3, 1, 2, .white)
            px(5, 4, 1, 1, Color(hex: "101010")); px(10, 4, 1, 1, Color(hex: "101010")) // 동공
            // 코
            px(7, 5, 2, 1, Color(hex: "1a1a1a"))
            // 통통한 몸
            px(2, 7, 12, 6, shirt)
            // 검은 팔
            px(0, 8, 2, 4, Color(hex: "1a1a1a")); px(14, 8, 2, 4, Color(hex: "1a1a1a"))
            // 검은 다리
            px(4, 13, 3, 3, Color(hex: "1a1a1a")); px(9, 13, 3, 3, Color(hex: "1a1a1a"))
            // 대나무 (들고 있음)
            px(15, 5, 1, 8, Color(hex: "40a040")); px(15, 4, 2, 1, Color(hex: "60c060"))

        case .unicorn:
            // 나선형 뿔 + 무지개 갈기 + 말 머리 + 꼬리
            // 나선형 뿔 (그라데이션)
            px(7, -5, 2, 1, Color(hex: "fff8d0")); px(7, -4, 2, 1, Color(hex: "f0d040"))
            px(7, -3, 2, 1, Color(hex: "e0b030")); px(7, -2, 2, 2, Color(hex: "d0a028"))
            // 머리
            px(4, 0, 8, 6, fur)
            // 무지개 갈기 (왼쪽으로 흘러내림)
            px(2, -1, 2, 2, Color(hex: "ff6080")); px(1, 1, 2, 2, Color(hex: "ff9040"))
            px(1, 3, 2, 2, Color(hex: "f0e040")); px(2, 5, 2, 2, Color(hex: "40c080"))
            // 눈 (큰 반짝이는 눈)
            px(5, 2, 2, 3, .white); px(6, 3, 1, 1, Color(hex: "c060c0")) // 보라 동공
            px(5, 2, 1, 1, Color(hex: "c060c0").opacity(0.3)) // 하이라이트
            px(9, 2, 2, 3, .white); px(10, 3, 1, 1, Color(hex: "c060c0"))
            px(9, 2, 1, 1, Color(hex: "c060c0").opacity(0.3))
            // 몸
            px(3, 6, 10, 7, shirt)
            px(1, 7, 2, 4, shirt); px(13, 7, 2, 4, shirt) // 다리
            px(4, 13, 3, 3, fur); px(9, 13, 3, 3, fur)
            // 무지개 꼬리
            px(14, 8, 2, 1, Color(hex: "ff6080")); px(15, 9, 1, 1, Color(hex: "f0e040")); px(14, 10, 2, 1, Color(hex: "40c080"))

        case .skeleton:
            // 두개골 + 이빨 + 갈비뼈 + 뼈 관절 + 맨 다리뼈
            let bone = Color(hex: "f0f0e0")
            let dark_bg = Color(hex: "1a1a1a")
            // 두개골
            px(4, 0, 8, 6, bone)
            px(3, 1, 1, 3, bone); px(12, 1, 1, 3, bone) // 광대뼈
            // 눈구멍 (검은 깊은 구멍)
            px(5, 1, 2, 3, dark_bg); px(9, 1, 2, 3, dark_bg)
            px(5, 2, 1, 1, Color(hex: "ff2020").opacity(0.3)); px(9, 2, 1, 1, Color(hex: "ff2020").opacity(0.3)) // 붉은 빛
            // 코구멍
            px(7, 4, 1, 1, dark_bg); px(8, 4, 1, 1, dark_bg)
            // 이빨 (지그재그)
            px(5, 5, 6, 1, dark_bg)
            px(5, 5, 1, 1, bone); px(7, 5, 1, 1, bone); px(9, 5, 1, 1, bone); px(11, 5, 1, 1, bone)
            // 목뼈
            px(6, 6, 4, 1, bone)
            // 갈비뼈 (교차)
            px(4, 7, 8, 6, Color(hex: "303030")) // 어두운 배경
            px(5, 7, 6, 1, bone); px(5, 9, 6, 1, bone); px(5, 11, 6, 1, bone) // 가로 갈비
            px(7, 7, 2, 5, bone.opacity(0.3)) // 척추
            // 팔뼈
            px(2, 7, 2, 1, bone); px(1, 8, 2, 1, bone); px(0, 9, 2, 1, bone) // 왼팔
            px(12, 7, 2, 1, bone); px(13, 8, 2, 1, bone); px(14, 9, 2, 1, bone) // 오른팔
            // 다리뼈
            px(5, 13, 2, 4, bone); px(9, 13, 2, 4, bone)
            px(4, 16, 4, 1, bone); px(8, 16, 4, 1, bone) // 발뼈
            px(5, 12, 2, 4, bone); px(9, 12, 2, 4, bone)
        case .human:
            px(4, 0, 8, 3, hair); px(3, 1, 1, 2, hair); px(12, 1, 1, 2, hair)
            px(4, 3, 8, 5, fur)
            let blink = frame % 60 == 0
            if blink { px(5, 5, 2, 1, eye); px(9, 5, 2, 1, eye) }
            else { px(5, 4, 2, 2, .white); px(6, 5, 1, 1, eye); px(9, 4, 2, 2, .white); px(10, 5, 1, 1, eye) }
            px(3, 8, 10, 6, shirt)
            if state == .writing || state == .coding || state == .pairing {
                let af = frame % 4
                px(1, 9, 2, 4, shirt); px(13, 9, 2, 4, shirt)
                px(0, CGFloat(12 + af % 2), 2, 2, fur); px(14, CGFloat(12 + (af+1) % 2), 2, 2, fur)
            } else {
                px(1, 9, 2, 5, shirt); px(13, 9, 2, 5, shirt); px(0, 13, 2, 2, fur); px(14, 13, 2, 2, fur)
            }
            let pc = dark ? Color(hex: "1e222e") : Color(hex: "3a4050")
            px(4, 14, 4, 4, pc); px(8, 14, 4, 4, pc)
            px(4, 18, 3, 2, pc); px(9, 18, 3, 2, pc)
            px(3, 19, 4, 2, dark ? Color(hex: "252a36") : Color(hex: "4a5060"))
            px(9, 19, 4, 2, dark ? Color(hex: "252a36") : Color(hex: "4a5060"))
        }

        // 이름
        context.draw(
            Text(tab.workerName).font(Theme.mono(7, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? tab.workerColor : Theme.textSecondary),
            at: CGPoint(x: x + 8 * s, y: y + 21 * s + 5))

        if isActive {
            context.fill(Path(CGRect(x: x + 5 * s, y: y - 5, width: 6 * s, height: 2)), with: .color(Theme.accent.opacity(0.6)))
        }

        // 상태 말풍선 (풍부한 버전)
        if tab.claudeActivity != .idle && tab.claudeActivity != .done || (tab.claudeActivity == .done && frame % 60 < 30) {
            let txt: String
            let bubbleColor: Color
            let textColor: Color
            switch tab.claudeActivity {
            case .thinking:
                let dots = String(repeating: ".", count: (frame / 8 % 3) + 1)
                txt = "💭\(dots)"
                bubbleColor = Theme.purple.opacity(0.15)
                textColor = Theme.purple
            case .reading:
                txt = "📖 " + NSLocalizedString("activity.reading", comment: "")
                bubbleColor = Theme.accent.opacity(0.12)
                textColor = Theme.accent
            case .writing:
                txt = "✏️ " + NSLocalizedString("activity.writing", comment: "")
                bubbleColor = Theme.green.opacity(0.12)
                textColor = Theme.green
            case .searching:
                txt = "🔍 " + NSLocalizedString("activity.searching", comment: "")
                bubbleColor = Theme.cyan.opacity(0.12)
                textColor = Theme.cyan
            case .running:
                let spinner = ["⠋","⠙","⠸","⠴","⠦","⠇"][frame / 3 % 6]
                txt = "\(spinner) " + NSLocalizedString("activity.running", comment: "")
                bubbleColor = Theme.yellow.opacity(0.12)
                textColor = Theme.yellow
            case .done:
                txt = "✅"
                bubbleColor = Theme.green.opacity(0.12)
                textColor = Theme.green
            case .error:
                txt = "⚠️ " + NSLocalizedString("activity.error", comment: "")
                bubbleColor = Theme.red.opacity(0.15)
                textColor = Theme.red
            default: txt = ""; bubbleColor = .clear; textColor = .clear
            }
            if !txt.isEmpty {
                let bw: CGFloat = CGFloat(txt.count) * 5.5 + 10
                let bx = x + 8 * s - bw / 2
                let by = y - 20
                // 말풍선 꼬리
                var tail = Path()
                tail.move(to: CGPoint(x: x + 8 * s - 3, y: by + 14))
                tail.addLine(to: CGPoint(x: x + 8 * s, y: by + 18))
                tail.addLine(to: CGPoint(x: x + 8 * s + 3, y: by + 14))
                context.fill(tail, with: .color(dark ? Color(hex: "1a2030") : .white))
                // 말풍선 본체
                context.fill(Path(roundedRect: CGRect(x: bx, y: by, width: bw, height: 14), cornerRadius: 4),
                             with: .color(dark ? Color(hex: "1a2030") : .white))
                context.fill(Path(roundedRect: CGRect(x: bx + 1, y: by + 1, width: bw - 2, height: 12), cornerRadius: 3),
                             with: .color(bubbleColor))
                context.stroke(Path(roundedRect: CGRect(x: bx, y: by, width: bw, height: 14), cornerRadius: 4),
                               with: .color(textColor.opacity(0.3)), lineWidth: 0.5)
                context.draw(Text(txt).font(Theme.mono(7, weight: .bold)).foregroundColor(textColor),
                    at: CGPoint(x: bx + bw / 2, y: by + 7))
            }
        }
    }

    // MARK: - 휴게실

    // Room bounds helper for edit mode
    private func roomBounds(size: CGSize) -> (rx: CGFloat, ry: CGFloat, roomW: CGFloat, roomH: CGFloat, floorY: CGFloat) {
        let floorY = size.height * 0.62
        let roomW: CGFloat = 125
        let rx = size.width - roomW + 15
        let ry = floorY * 0.15
        let roomH = floorY * 0.85 + (size.height - floorY)
        return (rx, ry, roomW, roomH, floorY)
    }

    private func furnitureAbsolutePos(_ item: FurnitureItem, size: CGSize) -> CGPoint {
        let b = roomBounds(size: size)
        // Check drag position first, then saved, then default
        if let dp = dragPositions[item.id] { return dp }
        if let saved = settings.furniturePosition(for: item.id) { return saved }
        return CGPoint(x: b.rx + item.defaultNormX * b.roomW, y: b.ry + item.defaultNormY * b.roomH)
    }

    private func drawBreakRoom(context: GraphicsContext, size: CGSize, floorY: CGFloat) {
        let dark = settings.isDarkMode
        let b = roomBounds(size: size)

        // ── Wall background ──
        let wallBase = dark ? Color(hex: "151a28") : Color(hex: "d8dce8")
        let wallTop = dark ? Color(hex: "101520") : Color(hex: "e0e4f0")
        context.fill(Path(CGRect(x: b.rx - 10, y: b.ry, width: b.roomW + 10, height: floorY - b.ry + 2)), with: .color(wallBase))
        context.fill(Path(CGRect(x: b.rx - 10, y: b.ry, width: b.roomW + 10, height: floorY * 0.3)), with: .color(wallTop.opacity(0.5)))

        // ── Warm glow ──
        let glowAlpha = 0.06 + sin(Double(frame) * 0.04) * 0.02
        context.fill(
            Path(ellipseIn: CGRect(x: b.rx - 5, y: floorY * 0.2, width: b.roomW * 0.88, height: floorY * 0.7)),
            with: .color(Theme.yellow.opacity(glowAlpha))
        )

        // ── Draw each furniture at its position ──
        for item in FurnitureItem.all {
            guard isFurnitureVisible(item.id) else { continue }
            let pos = furnitureAbsolutePos(item, size: size)
            drawFurnitureItem(context: context, item: item, at: pos, floorY: floorY)
        }

        // ── Outlet ──
        let outletColor = dark ? Color(hex: "1e2430") : Color(hex: "c8ccd4")
        context.fill(Path(roundedRect: CGRect(x: b.rx + b.roomW * 0.72, y: floorY - 20, width: 6, height: 8), cornerRadius: 1), with: .color(outletColor))
        context.fill(Path(CGRect(x: b.rx + b.roomW * 0.72 + 2, y: floorY - 18, width: 1, height: 2)), with: .color(dark ? Color(hex: "0a0d14") : Color(hex: "9a9ea8")))
        context.fill(Path(CGRect(x: b.rx + b.roomW * 0.72 + 4, y: floorY - 18, width: 1, height: 2)), with: .color(dark ? Color(hex: "0a0d14") : Color(hex: "9a9ea8")))

        // ── Resting characters on sofa ──
        let breakTabs = manager.userVisibleTabs.filter { $0.isOnBreak }
        if settings.breakRoomShowSofa {
            let sofaPos = furnitureAbsolutePos(FurnitureItem.all[0], size: size)
            for (i, tab) in breakTabs.prefix(3).enumerated() {
                let bx = sofaPos.x + 3 + CGFloat(i) * 16
                let by = sofaPos.y - 6
                let s: CGFloat = 1.5
                let skin = Color(hex: "ffd5b8")
                let hair = [Color(hex: "4a3728"), Color(hex: "8b4513"), Color(hex: "2c1810")][i % 3]
                func px(_ ppx: CGFloat, _ ppy: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
                    context.fill(Path(CGRect(x: bx + ppx * s, y: by + ppy * s, width: w * s, height: h * s)), with: .color(c))
                }
                px(2, -1, 6, 2, hair); px(1, 0, 1, 1, hair)
                px(2, 0, 6, 5, skin)
                px(2, 3, 2, 1, Color(hex: "ffb0a0").opacity(0.4))
                px(6, 3, 2, 1, Color(hex: "ffb0a0").opacity(0.4))
                px(3, 2, 2, 1, Color(hex: "555")); px(6, 2, 2, 1, Color(hex: "555"))
                px(4, 4, 2, 1, Color(hex: "c06060").opacity(0.5))
                px(1, 5, 8, 5, tab.workerColor)
                if i % 2 == 0 { px(9, 5, 2, 3, skin); px(9, 5, 3, 2, Color(hex: "e0d8d0")) }
                let zzPhase = Double(frame) * 0.08 + Double(i) * 2
                if frame % 40 < 28 {
                    context.draw(Text("z").font(Theme.scaled(5, weight: .bold)).foregroundColor(Theme.textDim.opacity(0.5)),
                        at: CGPoint(x: bx + 10 * s, y: by - 3 + sin(zzPhase) * 2))
                    context.draw(Text("z").font(Theme.scaled(4, weight: .bold)).foregroundColor(Theme.textDim.opacity(0.35)),
                        at: CGPoint(x: bx + 11 * s, y: by - 8 + sin(zzPhase + 0.5) * 1.5))
                    context.draw(Text("Z").font(Theme.scaled(4, weight: .bold)).foregroundColor(Theme.textDim.opacity(0.2)),
                        at: CGPoint(x: bx + 12 * s, y: by - 12 + sin(zzPhase + 1.0) * 1))
                }
            }
        }

        if !breakTabs.isEmpty {
            context.draw(
                Text(String(format: NSLocalizedString("pixel.break.resting.count", comment: ""), breakTabs.count))
                    .font(Theme.mono(6, weight: .medium))
                    .foregroundColor(Theme.textDim),
                at: CGPoint(x: b.rx + b.roomW * 0.4, y: floorY + 22)
            )
        }
    }

    private func isFurnitureVisible(_ id: String) -> Bool {
        switch id {
        case "sofa": return settings.breakRoomShowSofa
        case "coffeeMachine": return settings.breakRoomShowCoffeeMachine
        case "plant": return settings.breakRoomShowPlant
        case "sideTable": return settings.breakRoomShowSideTable
        case "picture": return settings.breakRoomShowPicture
        case "neonSign": return settings.breakRoomShowNeonSign
        case "rug": return settings.breakRoomShowRug
        case "bookshelf": return settings.breakRoomShowBookshelf
        case "aquarium": return settings.breakRoomShowAquarium
        case "arcade": return settings.breakRoomShowArcade
        case "whiteboard": return settings.breakRoomShowWhiteboard
        case "lamp": return settings.breakRoomShowLamp
        case "cat": return settings.breakRoomShowCat
        case "tv": return settings.breakRoomShowTV
        case "fan": return settings.breakRoomShowFan
        case "calendar": return settings.breakRoomShowCalendar
        case "poster": return settings.breakRoomShowPoster
        case "trashcan": return settings.breakRoomShowTrashcan
        case "cushion": return settings.breakRoomShowCushion
        default: return false
        }
    }

    private func drawFurnitureItem(context: GraphicsContext, item: FurnitureItem, at pos: CGPoint, floorY: CGFloat) {
        let dark = settings.isDarkMode
        _ = floorY
        drawAccessoryPixelFurniture(context: context, itemId: item.id, at: pos, dark: dark, frame: frame)
    }

    // MARK: - Edit Mode Overlay

    private var editModeOverlay: some View {
        GeometryReader { geo in
            let size = geo.size

            // Dim overlay
            Theme.overlay.opacity(0.15)
                .allowsHitTesting(false)

            // Draggable handles for each visible furniture
            ForEach(FurnitureItem.all) { item in
                if isFurnitureVisible(item.id) {
                    let pos = furnitureAbsolutePos(item, size: size)
                    furnitureDragHandle(item: item, pos: pos, size: size)
                }
            }

            // Top toolbar
            VStack {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.yellow)
                        Text(NSLocalizedString("pixel.furniture.edit.mode", comment: "")).font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.textOnAccent)
                    }
                    Text(NSLocalizedString("pixel.furniture.drag.hint", comment: "")).font(Theme.mono(9)).foregroundColor(Theme.textOnAccent.opacity(0.6))
                    Spacer()
                    Button(action: { settings.isEditMode = false }) {
                        Text(NSLocalizedString("pixel.furniture.done", comment: "")).font(Theme.mono(11, weight: .bold)).foregroundColor(Theme.yellow)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.yellow.opacity(0.2))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.yellow.opacity(0.5), lineWidth: 1)))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.overlay.opacity(0.6))

                Spacer()
            }
        }
    }

    private func furnitureDragHandle(item: FurnitureItem, pos: CGPoint, size: CGSize) -> some View {
        let w = item.width
        let h = item.height
        let isDragging = draggingId == item.id

        let strokeColor: Color = isDragging ? Theme.yellow : Theme.accent
        let fillColor: Color = isDragging ? Theme.yellow.opacity(0.1) : Theme.accent.opacity(0.05)

        return RoundedRectangle(cornerRadius: 3)
            .stroke(strokeColor, style: StrokeStyle(lineWidth: isDragging ? 2 : 1, dash: [3, 3]))
            .background(RoundedRectangle(cornerRadius: 3).fill(fillColor))
            .frame(width: w + 8, height: h + 8)
            .overlay(
                VStack(spacing: 1) {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: Theme.iconSize(7)))
                        .foregroundColor(strokeColor)
                    Text(item.name)
                        .font(Theme.mono(6, weight: .bold))
                        .foregroundColor(strokeColor)
                }
            )
            .position(x: pos.x + w / 2, y: pos.y + h / 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        draggingId = item.id
                        let b = roomBounds(size: size)
                        var newX = value.location.x - w / 2
                        var newY = value.location.y - h / 2
                        // Constrain within room bounds
                        newX = max(b.rx - 15, min(newX, b.rx + b.roomW - w))
                        if item.isWallItem {
                            newY = max(b.ry, min(newY, b.floorY - h))
                        } else {
                            newY = max(b.ry, min(newY, b.floorY + 20 - h))
                        }
                        // Snap to 4px grid
                        newX = round(newX / 4) * 4
                        newY = round(newY / 4) * 4
                        dragPositions[item.id] = CGPoint(x: newX, y: newY)
                    }
                    .onEnded { _ in
                        draggingId = nil
                        if let pos = dragPositions[item.id] {
                            settings.setFurniturePosition(pos, for: item.id)
                        }
                        dragPositions.removeValue(forKey: item.id)
                    }
            )
    }
}
