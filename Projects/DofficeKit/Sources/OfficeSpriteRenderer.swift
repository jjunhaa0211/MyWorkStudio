import SwiftUI
import DesignSystem
import OrderedCollections

// ═══════════════════════════════════════════════════════
// MARK: - Office Sprite Renderer (Z-sorted Canvas)
// ═══════════════════════════════════════════════════════

public struct OfficeSpriteRenderer {
    public let map: OfficeMap
    public let characters: [String: OfficeCharacter]
    public let tabs: [TerminalTab]
    public let frame: Int
    public let dark: Bool
    public let theme: BackgroundTheme
    public let selectedTabId: String?
    public let selectedFurnitureId: String?
    public var chromeScreenshots: [String: CGImage] = [:]  // tabId → chrome screenshot
    public let officeCat: OfficeCat?
    /// Pre-built tab lookup table — avoids O(n) tabs.first(where:) per character
    internal let tabLookup: [String: TerminalTab]

    public init(map: OfficeMap, characters: [String: OfficeCharacter], tabs: [TerminalTab],
         frame: Int, dark: Bool, theme: BackgroundTheme,
         selectedTabId: String?, selectedFurnitureId: String?,
         officeCat: OfficeCat? = nil) {
        self.init(map: map, characters: characters, tabs: tabs,
                  frame: frame, dark: dark, theme: theme,
                  selectedTabId: selectedTabId, selectedFurnitureId: selectedFurnitureId,
                  officeCat: officeCat,
                  cachedPalette: OfficeScenePalette(theme: theme, dark: dark))
    }

    /// Init with a pre-built palette to avoid recomputing it every frame.
    public init(map: OfficeMap, characters: [String: OfficeCharacter], tabs: [TerminalTab],
         frame: Int, dark: Bool, theme: BackgroundTheme,
         selectedTabId: String?, selectedFurnitureId: String?,
         officeCat: OfficeCat? = nil,
         cachedPalette: OfficeScenePalette) {
        self.map = map
        self.characters = characters
        self.tabs = tabs
        self.frame = frame
        self.dark = dark
        self.theme = theme
        self.selectedTabId = selectedTabId
        self.selectedFurnitureId = selectedFurnitureId
        self.officeCat = officeCat
        self.palette = cachedPalette
        // Build O(1) tab lookup once instead of O(n) per character
        var lookup: [String: TerminalTab] = [:]
        lookup.reserveCapacity(tabs.count)
        for tab in tabs { lookup[tab.id] = tab }
        self.tabLookup = lookup
    }

    // Sprite cache: OrderedDictionary for LRU eviction (oldest = first entries)
    internal static var spriteCache: OrderedDictionary<String, CharacterSpriteSet> = [:]

    // Reusable Z-sort buffer — avoids per-frame heap allocation
    internal static var zBuffer: [ZDrawable] = []

    // Pre-allocated bubble text arrays to avoid per-frame allocation
    internal static let greetTexts0 = ["(ᵔᴥᵔ)", "ヾ(＾∇＾)", "(◕‿◕)", "\\(^o^)/"]
    internal static let greetTexts1 = ["(＾▽＾)", "(｡◕‿◕｡)", "٩(◕‿◕)۶", "(づ｡◕‿‿◕｡)づ"]
    internal static let chatTexts0 = ["(¬‿¬)", "ᕕ(ᐛ)ᕗ", "(•̀ᴗ•́)و", "( ˘▽˘)っ♨"]
    internal static let chatTexts1 = ["(≧◡≦)", "ʕ•ᴥ•ʔ", "(ノ◕ヮ◕)ノ*:・゚✧", "٩(♡ε♡)۶"]
    internal static let brainTexts0 = ["(°ロ°)☝", "φ(._.)メモメモ", "(⌐■_■)", "ᕦ(ò_óˇ)ᕤ"]
    internal static let brainTexts1 = ["(☞ﾟ∀ﾟ)☞", "( •_•)>⌐■-■", "ψ(._. )>", "(╯°□°)╯︵ ┻━┻"]
    internal static let coffeeTexts0 = ["☕(◕‿◕)", "(っ˘ω˘c)♨", "( ˘⌣˘)❤☕", "✧(˘⌣˘)☕"]
    internal static let coffeeTexts1 = ["(⊃˘▽˘)⊃☕", "☕(⌐■_■)", "(´∀`)♨", "☕✧(◕‿◕✿)"]
    internal static let highFiveTexts0 = ["(つ≧▽≦)つ", "ε=ε=(ノ≧∇≦)ノ", "(ﾉ◕ヮ◕)ﾉ*:・゚✧", "( •̀ω•́ )σ"]
    internal static let highFiveTexts1 = ["⊂(◉‿◉)つ", "(ノ´ヮ`)ノ*: ・゚✧", "\\(★ω★)/", "(*≧▽≦)ノシ"]
    internal static let arguingTexts0 = ["(ノಠ益ಠ)ノ", "(╬ Ò﹏Ó)", "ᕦ(ò_óˇ)ᕤ!", "( •̀ω•́ )☝"]
    internal static let arguingTexts1 = ["(¬_¬\")", "(ー_ー゛)", "ψ(｀∇´)ψ", "(눈_눈)"]
    internal static let nappingTexts0 = ["(-_-) zzZ", "(˘ω˘) zzz", "(-.-)Zzz..", "(¦3[▓▓]"]
    internal static let nappingTexts1 = ["(∪｡∪)｡｡｡", "(´-﹃-`)Zz", "₍ᐢ..ᐢ₎zzz", "(˘εз˘)"]
    internal static let dancingTexts0 = ["♪(┌・。・)┌", "♪ ₍₍(ง˘ω˘)ว⁾⁾♪", "┏(＾0＾)┛♪", "~(˘▽˘~)"]
    internal static let dancingTexts1 = ["(~˘▽˘)~♪", "♪♪♪(∇⌒ヽ)", "ᕕ(⌐■_■)ᕗ♪", "└(^o^ )Ｘ"]
    internal static let snackingTexts0 = ["🍩(◕ᴗ◕✿)", "🍪 ᵐᵐᵐ", "🍕(⌒▽⌒)", "( ˘ᴗ˘ )🧁"]
    internal static let snackingTexts1 = ["(ᵔᴥᵔ)🍫", "🥤(◕‿◕)", "🍿(≧◡≦)", "🍜(˘ω˘)"]
    internal static let photoTimeTexts0 = ["📸✧ᵕ̈", "🤳(◕‿◕✿)", "📸✌('ω'✌ )", "📷(⌐■_■)"]
    internal static let photoTimeTexts1 = ["✌(◕‿-)✌", "(＾▽＾)📸", "✨📸✨", "✌('ω')✌"]
    internal static let flirtingTexts0 = ["(⁄ ⁄•⁄ω⁄•⁄ ⁄)", "♡(◕‿◕✿)", "(˶ᵔ ᵕ ᵔ˶)♡", "(⸝⸝⸝´꒳`⸝⸝⸝)"]
    internal static let flirtingTexts1 = ["(◍•ᴗ•◍)❤", "♡(⁰▿⁰)♡", "(≧◡≦)♡", "(*˘︶˘*).。.:*♡"]
    internal static let pettingCatTexts0 = ["🐱♡", "(=^・ω・^=)", "ᓚᘏᗢ♡", "🐾(◕‿◕✿)"]
    internal static let pettingCatTexts1 = ["🐈✧", "(ΦωΦ)♡", "ᓚᘏᗢ~", "🐱(˘ω˘)"]
    // 고양이 전용 리액션
    internal static let catReactions = ["ᓚᘏᗢ", "=^.^=", "🐾", "(=^‥^=)"]
    internal static let catSleepReactions = ["ᓚᘏᗢzzz", "(=˘ω˘=)zzz", "₍˄·͈˶·͈˄₎zzz"]
    internal static let catPettedReactions = ["ᓚᘏᗢ♡", "ᵖᵘʳʳ~♡", "(=^-ω-^=)♡", "ᓚᘏᗢ~nyaa"]
    // 캐릭터가 고양이를 쓰다듬을 때 리액션
    internal static let pettingReactions = ["🐱♡ᵃʷ~", "(◕‿◕)🐾", "ᓚᘏᗢ so soft", "🐈✧ᶜᵘᵗᵉ"]

    // 가구 상호작용 전용 리액션
    internal static let coffeeInteractionReactions = ["☕ᵃʰʰ~", "☕(˘ω˘)", "☕✧", "( ˘⌣˘)☕♨"]
    internal static let waterInteractionReactions = ["💧ᵍˡᵘᵍ", "💦(◕‿◕)", "🥤ᵖᵘʰᵃ", "💧✧"]
    internal static let bookInteractionReactions = ["📖(ᵔᴥᵔ)", "📚hmm..", "📖ᶠˡⁱᵖ", "📕✧"]
    internal static let sofaInteractionReactions = ["(˘ω˘)~♡", "ᵃʰʰ~ ☁", "(-ω-)~♡", "✧ᶠˡᵘᶠᶠʸ"]
    internal static let printerInteractionReactions = ["🖨ᵇʳʳ", "🖨..⏳", "📄✓!", "🖨✧ᵈᵒⁿᵉ"]
    internal static let whiteboardInteractionReactions = ["📋hmm", "✏️(·_·)", "💡!", "📋✓"]
    internal static let trashInteractionReactions = ["🗑ᵖᵒⁱ", "🗑✓", "( ˘▽˘)🗑", "🗑✧"]
    internal static let plantInteractionReactions = ["🌿💧", "🌱✧", "🪴(◕‿◕)", "🌿ᵍʳᵒʷ"]
    // 축하 반응 전용 리액션
    internal static let celebrationReactReactions = ["👏✧", "🥳!", "\\(◕‿◕)/", "🎊✧"]

    // Pre-allocated activity reaction arrays to avoid per-frame allocation
    internal static let typingReactions = ["⌨️ ᵗᵃᵏ", "✎ ᵗᵃᵏ", "⌨ᵈᵃᵈᵃ", "⚡⌨⚡"]
    internal static let readingReactions = ["📖...", "🔍hmm", "👀...", "📄✓"]
    internal static let searchingReactions = ["🔎...", "🧐?", "🗂️...", "📂✓"]
    internal static let errorReactions = ["(╥_╥)", "╥﹏╥", "(ᗒᗣᗕ)՞", "( ꈨ◞ )"]
    internal static let thinkingReactions = ["(·_·)", "🤔...", "φ(._.)", "(ᵕ≀ᵕ)"]
    internal static let celebratingReactions = ["🎉✧", "\\(ᵔᵕᵔ)/", "٩(◕‿◕)۶", "★彡"]
    internal static let idleReactions = ["(¬_¬)", "(-_-) zzZ", "(˘ω˘)", "( ˙꒳˙ )"]
    internal static let windowColumns: Set<Int> = [3, 4, 5, 9, 10, 11, 15, 16, 17, 21, 22, 23, 31, 32, 33, 37, 38, 39]
    /// Computed once per renderer creation, not per property access
    public let palette: OfficeScenePalette

    // Static background cache: avoids redrawing ~8000 floor/wall draw calls every frame
    private static var cachedBackgroundImage: CGImage?
    private static var cachedBackgroundKey: String = ""
    private static let staticCachedTypes: Set<FurnitureType> = [.rug, .bookshelf, .whiteboard, .pictureFrame, .clock]
    public static func usesStaticBackgroundCache(for type: FurnitureType) -> Bool {
        staticCachedTypes.contains(type)
    }

    // MARK: - Main Render

    public func render(context: GraphicsContext, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        renderStaticBackground(context: context, scale: scale, offsetX: offsetX, offsetY: offsetY)
        renderDynamicLayers(context: context, scale: scale, offsetX: offsetX, offsetY: offsetY)
    }

    public func renderStaticBackground(context: GraphicsContext, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        let cacheKey = "\(theme.rawValue)-\(dark)-\(map.cols)-\(map.rows)"

        if cacheKey == Self.cachedBackgroundKey, let cached = Self.cachedBackgroundImage {
            var ctx = context
            ctx.translateBy(x: offsetX, y: offsetY)
            ctx.scaleBy(x: scale, y: scale)
            ctx.draw(
                Image(decorative: cached, scale: 1),
                in: CGRect(x: 0, y: 0,
                           width: CGFloat(map.cols) * 16,
                           height: CGFloat(map.rows) * 16)
            )
            return
        }

        // Cache miss — draw normally into the live context
        var ctx = context
        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: scale, y: scale)
        drawBackdrop(ctx)
        drawFloorTiles(ctx)
        drawWindowLight(ctx)
        drawWalls(ctx)
        drawCachedStaticFurniture(ctx)

        // Generate cached CGImage for subsequent frames
        Task { @MainActor in
            Self.generateBackgroundCache(map: map, dark: dark, theme: theme, cacheKey: cacheKey)
        }
    }

    /// Renders the static background into an offscreen CGImage via ImageRenderer.
    @MainActor private static func generateBackgroundCache(map: OfficeMap, dark: Bool, theme: BackgroundTheme, cacheKey: String) {
        let size = CGSize(
            width: CGFloat(map.cols) * 16,
            height: CGFloat(map.rows) * 16
        )
        let snapshotView = Canvas { context, _ in
            let renderer = OfficeSpriteRenderer(
                map: map,
                characters: [:],
                tabs: [],
                frame: 0,
                dark: dark,
                theme: theme,
                selectedTabId: nil,
                selectedFurnitureId: nil
            )
            renderer.drawBackdrop(context)
            renderer.drawFloorTiles(context)
            renderer.drawWindowLight(context)
            renderer.drawWalls(context)
            renderer.drawCachedStaticFurniture(context)
        }
        .frame(width: size.width, height: size.height)

        let imageRenderer = ImageRenderer(content: snapshotView)
        imageRenderer.scale = 1
        if let cgImage = imageRenderer.cgImage {
            cachedBackgroundImage = cgImage
            cachedBackgroundKey = cacheKey
        }
    }

    /// Invalidates the static background cache (call when theme or layout changes).
    public static func invalidateBackgroundCache() {
        cachedBackgroundImage = nil
        cachedBackgroundKey = ""
    }

    public func renderDynamicLayers(context: GraphicsContext, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        var ctx = context
        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: scale, y: scale)
        drawZSortedScene(ctx)
        drawOfficeCat(ctx)
        drawOverlays(ctx, viewScale: scale)
    }

    // MARK: - Pixel Art Cat Sprites
    // 색상 팔레트 (짧은 별명으로 스프라이트 가독성 확보)
    private static let F = "E8A060"  // fur 주황
    private static let L = "F0C890"  // light 밝은 배
    private static let D = "C07838"  // dark 줄무늬
    private static let N = "F08888"  // nose 코
    private static let E = "40B868"  // eye 녹색 눈
    private static let W = "F0F0E8"  // white 눈 흰자
    private static let I = "F0B0A0"  // inner ear 귀 안쪽
    private static let T = "D08848"  // tail 꼬리
    private static let P = "282828"  // pupil 동공
    private static let o = ""        // 투명

    // ── 앉아있기 (정면) 10w × 9h ──
    private static let catSitDown: SpriteData = [
        [o, o, F, o, o, o, o, F, o, o],  // 귀 꼭대기
        [o, F, I, F, F, F, F, I, F, o],  // 귀 + 머리
        [o, F, W, P, F, F, W, P, F, o],  // 눈
        [o, o, F, F, N, N, F, F, o, o],  // 코
        [o, o, F, L, L, L, L, F, o, o],  // 가슴
        [o, o, F, F, L, L, F, F, o, o],  // 몸통
        [o, o, F, F, F, F, F, F, o, o],  // 하체
        [o, o, F, o, o, o, o, F, o, o],  // 앞발
        [o, o, o, o, o, o, o, o, T, o],  // 꼬리
    ]

    // ── 걷기 (오른쪽 향) 4프레임  12w × 9h ──
    // 삼각형 귀, 둥근 머리, 아치형 등, 가는 다리, S자 꼬리
    private static let catWalkR: [SpriteData] = [
        // 프레임 0: 오른발 앞
        [
            [o, o, o, o, F, o, o, o, o, o, o, o],  // 귀 꼭대기
            [o, o, o, F, F, o, o, o, o, o, o, o],  // 귀 (삼각형)
            [o, o, F, F, F, F, o, o, o, o, o, o],  // 이마 (둥근 머리)
            [o, o, W, P, F, F, F, F, o, o, o, o],  // 눈 + 등 연결
            [o, o, F, N, F, F, L, F, F, o, o, o],  // 주둥이 + 몸통
            [o, o, o, F, F, F, F, F, F, T, o, o],  // 배 + 꼬리
            [o, o, o, F, o, o, o, F, o, o, T, o],  // 다리 벌림
            [o, o, o, o, o, o, o, o, o, o, o, o],
            [o, o, o, o, o, o, o, o, o, o, o, o],
        ],
        // 프레임 1: 다리 모음 (바운스)
        [
            [o, o, o, o, F, o, o, o, o, o, o, o],
            [o, o, o, F, F, o, o, o, o, o, o, o],
            [o, o, F, F, F, F, o, o, o, o, o, o],
            [o, o, W, P, F, F, F, F, o, o, o, o],
            [o, o, F, N, F, F, L, F, F, o, o, o],
            [o, o, o, F, F, F, F, F, F, T, o, o],
            [o, o, o, o, F, F, o, o, o, o, T, o],
            [o, o, o, o, o, o, o, o, o, o, o, o],
            [o, o, o, o, o, o, o, o, o, o, o, o],
        ],
        // 프레임 2: 왼발 앞
        [
            [o, o, o, o, F, o, o, o, o, o, o, o],
            [o, o, o, F, F, o, o, o, o, o, o, o],
            [o, o, F, F, F, F, o, o, o, o, o, o],
            [o, o, W, P, F, F, F, F, o, o, o, o],
            [o, o, F, N, F, F, L, F, F, o, o, o],
            [o, o, o, F, F, F, F, F, F, T, o, o],
            [o, o, F, o, o, o, F, o, o, o, T, o],
            [o, o, o, o, o, o, o, o, o, o, o, o],
            [o, o, o, o, o, o, o, o, o, o, o, o],
        ],
        // 프레임 3: 다리 모음 (바운스)
        [
            [o, o, o, o, F, o, o, o, o, o, o, o],
            [o, o, o, F, F, o, o, o, o, o, o, o],
            [o, o, F, F, F, F, o, o, o, o, o, o],
            [o, o, W, P, F, F, F, F, o, o, o, o],
            [o, o, F, N, F, F, L, F, F, o, o, o],
            [o, o, o, F, F, F, F, F, F, T, o, o],
            [o, o, o, F, F, o, o, o, o, o, T, o],
            [o, o, o, o, o, o, o, o, o, o, o, o],
            [o, o, o, o, o, o, o, o, o, o, o, o],
        ],
    ]

    // ── 걷기 (아래 향) 4프레임 10w × 9h ──
    private static let catWalkD: [SpriteData] = [
        [
            [o, o, F, o, o, o, o, F, o, o],
            [o, F, I, F, F, F, F, I, F, o],
            [o, F, W, P, F, F, W, P, F, o],
            [o, o, F, F, N, N, F, F, o, o],
            [o, o, F, L, L, L, L, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, o, F, o, o, o, o, F, o, o],
            [o, F, o, o, o, o, o, o, F, o],
            [o, o, o, o, o, o, o, o, o, o],
        ],
        [
            [o, o, F, o, o, o, o, F, o, o],
            [o, F, I, F, F, F, F, I, F, o],
            [o, F, W, P, F, F, W, P, F, o],
            [o, o, F, F, N, N, F, F, o, o],
            [o, o, F, L, L, L, L, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, o, o, F, o, o, F, o, o, o],
            [o, o, o, o, o, o, o, o, o, o],
            [o, o, o, o, o, o, o, o, o, o],
        ],
        [
            [o, o, F, o, o, o, o, F, o, o],
            [o, F, I, F, F, F, F, I, F, o],
            [o, F, W, P, F, F, W, P, F, o],
            [o, o, F, F, N, N, F, F, o, o],
            [o, o, F, L, L, L, L, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, F, o, o, o, o, o, F, o, o],
            [o, o, F, o, o, o, F, o, o, o],
            [o, o, o, o, o, o, o, o, o, o],
        ],
        [
            [o, o, F, o, o, o, o, F, o, o],
            [o, F, I, F, F, F, F, I, F, o],
            [o, F, W, P, F, F, W, P, F, o],
            [o, o, F, F, N, N, F, F, o, o],
            [o, o, F, L, L, L, L, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, o, F, o, o, o, F, o, o, o],
            [o, o, o, o, o, o, o, o, o, o],
            [o, o, o, o, o, o, o, o, o, o],
        ],
    ]

    // ── 걷기 (위 향) 4프레임 10w × 9h ──
    private static let catWalkU: [SpriteData] = [
        [
            [o, o, F, o, o, o, o, F, o, o],
            [o, F, D, F, F, F, F, D, F, o],
            [o, F, F, F, F, F, F, F, F, o],
            [o, o, F, F, D, D, F, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, o, F, o, o, o, o, F, o, o],
            [o, F, o, o, T, T, o, o, F, o],
            [o, o, o, o, o, T, o, o, o, o],
        ],
        [
            [o, o, F, o, o, o, o, F, o, o],
            [o, F, D, F, F, F, F, D, F, o],
            [o, F, F, F, F, F, F, F, F, o],
            [o, o, F, F, D, D, F, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, o, o, F, o, o, F, o, o, o],
            [o, o, o, o, T, T, o, o, o, o],
            [o, o, o, o, o, T, o, o, o, o],
        ],
        [
            [o, o, F, o, o, o, o, F, o, o],
            [o, F, D, F, F, F, F, D, F, o],
            [o, F, F, F, F, F, F, F, F, o],
            [o, o, F, F, D, D, F, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, F, o, o, o, o, o, F, o, o],
            [o, o, F, o, T, T, F, o, o, o],
            [o, o, o, o, o, T, o, o, o, o],
        ],
        [
            [o, o, F, o, o, o, o, F, o, o],
            [o, F, D, F, F, F, F, D, F, o],
            [o, F, F, F, F, F, F, F, F, o],
            [o, o, F, F, D, D, F, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, o, F, F, F, F, F, F, o, o],
            [o, o, F, o, o, o, F, o, o, o],
            [o, o, o, o, T, T, o, o, o, o],
            [o, o, o, o, o, T, o, o, o, o],
        ],
    ]

    // ── 잠자기 (동그랗게 웅크린 형태) 10w × 5h ──
    private static let catSleep: SpriteData = [
        [o, o, F, F, F, F, F, F, o, o],
        [o, F, D, F, F, F, D, F, F, o],
        [o, F, L, L, L, L, L, F, T, o],
        [o, o, F, F, F, F, F, T, T, o],
        [o, o, o, o, o, o, o, o, o, o],
    ]

    // ── 기지개 (앞다리 쭉, 엉덩이 올림) 12w × 8h ──
    private static let catStretch: SpriteData = [
        [o, o, o, o, o, o, o, o, o, F, o, o],  // 귀 꼭대기
        [o, o, o, o, o, o, o, o, F, F, o, o],  // 귀 삼각형
        [o, o, o, o, o, o, o, F, F, F, F, o],  // 머리
        [o, T, F, D, F, F, F, F, P, W, F, o],  // 꼬리+등+눈
        [o, o, T, F, F, L, L, F, F, N, o, o],  // 몸+가슴+코
        [o, o, o, F, F, F, F, F, o, o, o, o],  // 배
        [o, o, o, o, F, o, o, F, F, F, o, o],  // 뒷다리+앞다리쭉
        [o, o, o, o, o, o, o, o, o, o, o, o],
    ]

    // ── 쓰다듬받기 (행복, 눈 감음) 10w × 9h ──
    private static let catHappy: SpriteData = [
        [o, o, F, o, o, o, o, F, o, o],
        [o, F, I, F, F, F, F, I, F, o],
        [o, F, D, D, F, F, D, D, F, o],  // 눈 감음 (^ ^)
        [o, o, F, F, N, N, F, F, o, o],
        [o, o, F, L, L, L, L, F, o, o],
        [o, o, F, F, L, L, F, F, o, o],
        [o, o, F, F, F, F, F, F, o, o],
        [o, o, F, o, o, o, o, F, o, o],
        [o, o, o, o, o, o, o, o, T, o],
    ]

    // ── 장난 (엎드려 사냥 자세 - 머리 낮추고 엉덩이 올림) 12w × 8h ──
    private static let catPlay: [SpriteData] = [
        [
            [o, o, o, o, o, o, o, o, o, T, o, o],  // 꼬리 올라감
            [o, o, o, o, F, o, o, o, T, o, o, o],  // 귀+꼬리
            [o, o, o, F, F, o, F, F, F, o, o, o],  // 귀+엉덩이 올림
            [o, o, F, F, F, F, F, F, F, o, o, o],  // 머리+등
            [o, o, W, P, F, L, F, D, F, o, o, o],  // 눈+몸
            [o, o, F, N, F, F, F, F, o, o, o, o],  // 주둥이+배
            [o, o, F, F, o, o, o, F, o, o, o, o],  // 다리
            [o, o, o, o, o, o, o, o, o, o, o, o],
        ],
        [
            [o, o, o, o, o, o, o, o, o, o, T, o],  // 꼬리 흔들림
            [o, o, o, o, F, o, o, o, o, T, o, o],
            [o, o, o, F, F, o, F, F, F, o, o, o],
            [o, o, F, F, F, F, F, F, F, o, o, o],
            [o, o, P, W, F, L, F, D, F, o, o, o],  // 눈 반짝
            [o, o, F, N, F, F, F, F, o, o, o, o],
            [o, o, o, F, o, o, F, o, o, o, o, o],  // 다리 교차
            [o, o, o, o, o, o, o, o, o, o, o, o],
        ],
    ]

    /// 방향 & 상태에 따라 적절한 고양이 스프라이트 반환
    private func catSprite(for cat: OfficeCat) -> (sprite: SpriteData, mirrored: Bool) {
        switch cat.state {
        case .sleeping:
            return (Self.catSleep, false)
        case .stretching:
            return (Self.catStretch, cat.dir == .left)
        case .beingPetted:
            return (Self.catHappy, false)
        case .playing:
            let phase = (frame / 10) % Self.catPlay.count
            return (Self.catPlay[phase], cat.dir == .left)
        case .walking, .approaching:
            let walkFrame = cat.frame % 4
            switch cat.dir {
            case .right:
                return (Self.catWalkR[walkFrame], false)
            case .left:
                return (Self.catWalkR[walkFrame], true)  // 미러
            case .down:
                return (Self.catWalkD[walkFrame], false)
            case .up:
                return (Self.catWalkU[walkFrame], false)
            }
        case .idle:
            return (Self.catSitDown, false)
        }
    }

    private func drawOfficeCat(_ ctx: GraphicsContext) {
        guard let cat = officeCat else { return }

        let (sprite, mirrored) = catSprite(for: cat)
        let spriteH = CGFloat(sprite.count)
        let spriteW = CGFloat(sprite.first?.count ?? 10)

        // 걷기 바운스 (프레임 1,3에서 살짝 위로)
        let isWalking = cat.state == .walking || cat.state == .approaching
        let walkBob: CGFloat = isWalking ? ((cat.frame % 2 == 1) ? -0.5 : 0) : 0

        let drawX = cat.pixelX - spriteW / 2
        let drawY = cat.pixelY - spriteH + walkBob + 2

        // 그림자
        let shadowW: CGFloat = cat.state == .sleeping ? 10 : 8
        let shadowH: CGFloat = cat.state == .sleeping ? 2.5 : 3
        ctx.fill(
            Path(ellipseIn: CGRect(x: cat.pixelX - shadowW / 2, y: cat.pixelY + 0.5, width: shadowW, height: shadowH)),
            with: .color(Color.black.opacity(dark ? 0.16 : 0.09))
        )

        // 픽셀 렌더링 (캐릭터와 동일한 run-length 배치 + 1.15 스케일)
        for y in 0..<sprite.count {
            let row = sprite[y]
            let rowY = drawY + CGFloat(y)
            var runStart = -1
            var runHex = ""
            let cols = mirrored ? Array(row.reversed()) : row

            for x in 0..<cols.count {
                let hex = cols[x]
                if hex == runHex && !hex.isEmpty { continue }
                if !runHex.isEmpty && runStart >= 0 {
                    let runLen = CGFloat(x - runStart)
                    ctx.fill(Path(CGRect(
                        x: drawX + CGFloat(runStart), y: rowY,
                        width: runLen * 1.15, height: 1.15
                    )), with: .color(Color(hex: runHex)))
                }
                runStart = x
                runHex = hex
            }
            if !runHex.isEmpty && runStart >= 0 {
                let runLen = CGFloat(cols.count - runStart)
                ctx.fill(Path(CGRect(
                    x: drawX + CGFloat(runStart), y: rowY,
                    width: runLen * 1.15, height: 1.15
                )), with: .color(Color(hex: runHex)))
            }
        }

        // ── 상태별 이펙트 ──

        if cat.state == .sleeping {
            let zPhase = CGFloat((frame / 18) % 3)
            ctx.draw(
                Text("z").font(.system(size: 3.5 + zPhase * 0.8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "8090B0").opacity(0.7 - zPhase * 0.15)),
                at: CGPoint(x: cat.pixelX + 6 + zPhase * 2, y: drawY - 1 - zPhase * 3)
            )
        }

        if cat.state == .beingPetted {
            let heartPhase = (frame / 14) % 3
            let hx = cat.pixelX + 5
            let hy = drawY - 2 - CGFloat(heartPhase) * 2.5
            let ha = 0.9 - Double(heartPhase) * 0.2
            // 픽셀 하트 (3x3)
            for (dx, dy) in [(0,0), (2,0), (-1,1), (3,1), (0,2), (2,2), (1,3)] as [(CGFloat,CGFloat)] {
                ctx.fill(Path(CGRect(x: hx + dx, y: hy + dy, width: 1.15, height: 1.15)),
                         with: .color(Color(hex: "F08090").opacity(ha)))
            }
        }

        if cat.state == .stretching {
            let phase = (frame / 5) % 2
            let lx = cat.pixelX + (phase == 0 ? 7 : -5)
            for i in 0..<3 {
                ctx.fill(Path(CGRect(x: lx, y: drawY + 1 + CGFloat(i) * 2, width: 0.6, height: 1)),
                         with: .color(Color(hex: Self.F).opacity(0.35)))
            }
        }

        if cat.state == .playing {
            if (frame / 8) % 3 == 0 {
                ctx.fill(Path(CGRect(x: cat.pixelX - 4, y: drawY, width: 1, height: 1)),
                         with: .color(Color.white.opacity(0.75)))
            }
        }

        // 리액션 버블
        let cycle = frame % Int(OfficeConstants.fps * 8)
        if cycle < Int(OfficeConstants.fps * 1.5) && (cat.state == .idle || cat.state == .walking) {
            let reactions = Self.catReactions
            let text = reactions[frame / 24 % reactions.count]
            ctx.draw(
                Text(text).font(.system(size: 4, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "E8B870")),
                at: CGPoint(x: cat.pixelX, y: drawY - 5)
            )
        }
    }
}
