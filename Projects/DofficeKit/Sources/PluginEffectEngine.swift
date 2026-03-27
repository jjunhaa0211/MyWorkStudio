import SwiftUI
import Combine
#if os(macOS)
import AppKit
import DesignSystem
#endif

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Effect Engine (이펙트 런타임)
// ═══════════════════════════════════════════════════════

public class PluginEffectEngine: ObservableObject {
    public static let shared = PluginEffectEngine()

    // ── 시각 상태 ──
    @Published public var comboCount: Int = 0
    @Published public var comboMultiplier: Int = 1
    @Published public var activeParticles: [ParticleBurst] = []
    @Published public var shakeOffset: CGSize = .zero
    @Published public var flashColor: Color?
    @Published public var activeToasts: [EffectToast] = []
    @Published public var confettiPieces: [ConfettiPiece] = []

    // v2 이펙트 상태
    @Published public var typewriterText: TypewriterState?
    @Published public var progressBarState: ProgressBarState?
    @Published public var glowState: GlowState?

    private var comboDecayTimer: Timer?
    private var typewriterTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    public struct ParticleBurst: Identifiable {
        public let id = UUID()
        public let emojis: [String]
        public let positions: [(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat)]
        public let createdAt: Date
        public let duration: Double

        public init(emojis: [String], positions: [(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat)], createdAt: Date, duration: Double) {
            self.emojis = emojis
            self.positions = positions
            self.createdAt = createdAt
            self.duration = duration
        }
    }

    public struct EffectToast: Identifiable {
        public let id = UUID()
        public let text: String
        public let icon: String
        public let tintHex: String

        public init(text: String, icon: String, tintHex: String) {
            self.text = text
            self.icon = icon
            self.tintHex = tintHex
        }
    }

    public struct ConfettiPiece: Identifiable {
        public let id = UUID()
        public let colorHex: String
        public let x: CGFloat
        public let delay: Double

        public init(colorHex: String, x: CGFloat, delay: Double) {
            self.colorHex = colorHex
            self.x = x
            self.delay = delay
        }
    }

    // v2 이펙트 모델

    public struct TypewriterState: Identifiable {
        public let id: UUID
        public let fullText: String
        public var displayedCount: Int
        public let colorHex: String
        public let fontSize: CGFloat
        public let position: String        // "top" | "center" | "bottom"

        public var displayedText: String {
            String(fullText.prefix(displayedCount))
        }

        public init(id: UUID = UUID(), fullText: String, displayedCount: Int = 0, colorHex: String, fontSize: CGFloat, position: String) {
            self.id = id
            self.fullText = fullText
            self.displayedCount = displayedCount
            self.colorHex = colorHex
            self.fontSize = fontSize
            self.position = position
        }
    }

    public struct ProgressBarState: Identifiable {
        public let id: UUID
        public let progress: Double        // 0.0 ~ 1.0
        public let label: String
        public let barColorHex: String
        public let trackColorHex: String
        public let duration: Double        // 자동 진행 시간

        public init(id: UUID = UUID(), progress: Double, label: String, barColorHex: String, trackColorHex: String, duration: Double) {
            self.id = id
            self.progress = progress
            self.label = label
            self.barColorHex = barColorHex
            self.trackColorHex = trackColorHex
            self.duration = duration
        }
    }

    public struct GlowState: Identifiable {
        public let id = UUID()
        public let colorHex: String
        public let intensity: Double       // 글로우 강도 (0.0 ~ 1.0)
        public let pulseSpeed: Double      // 펄스 주기 (초)
        public let duration: Double

        public init(colorHex: String, intensity: Double, pulseSpeed: Double, duration: Double) {
            self.colorHex = colorHex
            self.intensity = intensity
            self.pulseSpeed = pulseSpeed
            self.duration = duration
        }
    }

    private init() {
        NotificationCenter.default.publisher(for: .pluginEffectEvent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let event = notif.userInfo?["event"] as? PluginEventType else { return }
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ event: PluginEventType) {
        let matching = PluginHost.shared.effects.filter { $0.trigger == event && $0.enabled }
        for effect in matching {
            executeEffect(effect)
        }
    }

    private func executeEffect(_ effect: PluginHost.LoadedEffect) {
        switch effect.effectType {
        case .comboCounter: executeCombo(effect.config)
        case .particleBurst: executeParticleBurst(effect.config)
        case .screenShake: executeScreenShake(effect.config)
        case .flash: executeFlash(effect.config)
        case .sound: executeSound(effect.config)
        case .toast: executeToast(effect.config)
        case .confetti: executeConfetti(effect.config)
        case .typewriter: executeTypewriter(effect.config)
        case .progressBar: executeProgressBar(effect.config)
        case .glow: executeGlow(effect.config)
        }
    }

    // MARK: - Combo Counter

    private func executeCombo(_ config: [String: EffectValue]) {
        comboCount += 1
        let decay = config["decaySeconds"]?.doubleValue ?? 2.0

        // 멀티플라이어 계산
        if comboCount >= 100 { comboMultiplier = 10 }
        else if comboCount >= 50 { comboMultiplier = 5 }
        else if comboCount >= 25 { comboMultiplier = 3 }
        else if comboCount >= 10 { comboMultiplier = 2 }
        else { comboMultiplier = 1 }

        // 마일스톤 시 흔들림
        let shakeOnMilestone = config["shakeOnMilestone"]?.boolValue ?? true
        if shakeOnMilestone && [10, 25, 50, 100].contains(comboCount) {
            executeScreenShake(["intensity": .double(3), "duration": .double(0.2)])
        }

        // 디케이 타이머 리셋
        comboDecayTimer?.invalidate()
        comboDecayTimer = Timer.scheduledTimer(withTimeInterval: decay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.comboCount = 0
                    self?.comboMultiplier = 1
                }
            }
        }
    }

    // MARK: - Particle Burst

    private func executeParticleBurst(_ config: [String: EffectValue]) {
        let emojis = config["emojis"]?.stringArrayValue ?? ["✨", "🔥", "⚡"]
        let count = config["count"]?.intValue ?? 15
        let duration = config["duration"]?.doubleValue ?? 1.5

        var positions: [(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat)] = []
        for _ in 0..<count {
            positions.append((
                x: CGFloat.random(in: 0.2...0.8),
                y: CGFloat.random(in: 0.3...0.7),
                vx: CGFloat.random(in: -60...60),
                vy: CGFloat.random(in: -120 ... -40)
            ))
        }

        let burst = ParticleBurst(emojis: emojis, positions: positions, createdAt: Date(), duration: duration)
        activeParticles.append(burst)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) { [weak self] in
            self?.activeParticles.removeAll { $0.id == burst.id }
        }
    }

    // MARK: - Screen Shake

    private func executeScreenShake(_ config: [String: EffectValue]) {
        let intensity = config["intensity"]?.doubleValue ?? 4.0
        let duration = config["duration"]?.doubleValue ?? 0.3
        let steps = Int(duration / 0.03)

        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.03) { [weak self] in
                let damping = 1.0 - (Double(i) / Double(steps))
                self?.shakeOffset = CGSize(
                    width: CGFloat.random(in: -intensity...intensity) * damping,
                    height: CGFloat.random(in: -intensity...intensity) * damping
                )
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.shakeOffset = .zero
        }
    }

    // MARK: - Flash

    private func executeFlash(_ config: [String: EffectValue]) {
        let hex = config["colorHex"]?.stringValue ?? "ffffff"
        let duration = config["duration"]?.doubleValue ?? 0.3

        withAnimation(.easeIn(duration: 0.05)) {
            flashColor = Color(hex: hex)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) {
                self?.flashColor = nil
            }
        }
    }

    // MARK: - Sound

    private func executeSound(_ config: [String: EffectValue]) {
        #if os(macOS)
        let name = config["name"]?.stringValue ?? "Pop"
        NSSound(named: NSSound.Name(name))?.play()
        #endif
    }

    // MARK: - Toast

    private func executeToast(_ config: [String: EffectValue]) {
        let text = config["text"]?.stringValue ?? ""
        let icon = config["icon"]?.stringValue ?? "bell.fill"
        let tint = config["tint"]?.stringValue ?? "accent"
        let duration = config["duration"]?.doubleValue ?? 3.0

        let toast = EffectToast(text: text, icon: icon, tintHex: tint)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activeToasts.append(toast)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) {
                self?.activeToasts.removeAll { $0.id == toast.id }
            }
        }
    }

    // MARK: - Confetti

    private func executeConfetti(_ config: [String: EffectValue]) {
        let colors = config["colors"]?.stringArrayValue ?? ["f14c4c", "3ecf8e", "3291ff", "f5a623", "8e4ec6"]
        let count = config["count"]?.intValue ?? 40
        let duration = config["duration"]?.doubleValue ?? 3.0

        var pieces: [ConfettiPiece] = []
        for _ in 0..<count {
            pieces.append(ConfettiPiece(
                colorHex: colors.randomElement() ?? "3291ff",
                x: CGFloat.random(in: 0...1),
                delay: Double.random(in: 0...0.5)
            ))
        }
        confettiPieces = pieces

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            withAnimation { self?.confettiPieces.removeAll() }
        }
    }

    // MARK: - Typewriter (타자기 텍스트 애니메이션)

    private func executeTypewriter(_ config: [String: EffectValue]) {
        let text = config["text"]?.stringValue ?? "Hello, World!"
        let speed = config["speed"]?.doubleValue ?? 0.05
        let colorHex = config["colorHex"]?.stringValue ?? "3291ff"
        let fontSize = CGFloat(config["fontSize"]?.doubleValue ?? 16.0)
        let position = config["position"]?.stringValue ?? "center"
        let holdDuration = config["holdDuration"]?.doubleValue ?? 2.0

        let stateId = UUID()
        typewriterText = TypewriterState(id: stateId, fullText: text, colorHex: colorHex, fontSize: fontSize, position: position)

        typewriterTimer?.invalidate()
        var charIndex = 0
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            charIndex += 1
            DispatchQueue.main.async {
                guard self.typewriterText?.id == stateId else { timer.invalidate(); return }
                self.typewriterText = TypewriterState(
                    id: stateId, fullText: text, displayedCount: charIndex,
                    colorHex: colorHex, fontSize: fontSize, position: position
                )
            }
            if charIndex >= text.count {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) { [weak self] in
                    withAnimation(.easeOut(duration: 0.5)) {
                        if self?.typewriterText?.id == stateId {
                            self?.typewriterText = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Progress Bar (프로그레스 바)

    private func executeProgressBar(_ config: [String: EffectValue]) {
        let label = config["label"]?.stringValue ?? ""
        let barColor = config["barColorHex"]?.stringValue ?? "3ecf8e"
        let trackColor = config["trackColorHex"]?.stringValue ?? "2a2d35"
        let duration = config["duration"]?.doubleValue ?? 3.0

        let stateId = UUID()
        progressBarState = ProgressBarState(
            id: stateId, progress: 0,
            label: label, barColorHex: barColor, trackColorHex: trackColor, duration: duration
        )

        // 0 → 1 애니메이션 (0.05초 간격)
        let steps = max(Int(duration / 0.05), 1)
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) { [weak self] in
                guard let self = self, self.progressBarState?.id == stateId else { return }
                self.progressBarState = ProgressBarState(
                    id: stateId, progress: min(Double(i) / Double(steps), 1.0),
                    label: label, barColorHex: barColor, trackColorHex: trackColor, duration: duration
                )
            }
        }

        // 완료 후 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 1.0) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                if self?.progressBarState?.id == stateId {
                    self?.progressBarState = nil
                }
            }
        }
    }

    // MARK: - Glow (테두리 글로우)

    private func executeGlow(_ config: [String: EffectValue]) {
        let colorHex = config["colorHex"]?.stringValue ?? "5b9cf6"
        let intensity = config["intensity"]?.doubleValue ?? 0.6
        let pulseSpeed = config["pulseSpeed"]?.doubleValue ?? 1.0
        let duration = config["duration"]?.doubleValue ?? 3.0

        let state = GlowState(
            colorHex: colorHex,
            intensity: intensity,
            pulseSpeed: pulseSpeed,
            duration: duration
        )
        withAnimation(.easeIn(duration: 0.2)) {
            glowState = state
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            withAnimation(.easeOut(duration: 0.5)) {
                if self?.glowState?.id == state.id {
                    self?.glowState = nil
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Effect Overlay (SwiftUI 오버레이)
// ═══════════════════════════════════════════════════════

public struct PluginEffectOverlay: View {
    @ObservedObject var engine = PluginEffectEngine.shared
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public init() {}

    public var body: some View {
        ZStack {
            // 플래시
            if let color = engine.flashColor {
                color.opacity(0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // 콤보 카운터 (우상단)
            if engine.comboCount > 0 {
                comboView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(20)
            }

            // 파티클
            ForEach(engine.activeParticles) { burst in
                particleBurstView(burst)
            }

            // 컨페티
            if !engine.confettiPieces.isEmpty {
                confettiView
            }

            // 토스트 (좌하단)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(engine.activeToasts) { toast in
                    toastView(toast)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(16)

            // 타자기 텍스트
            if let tw = engine.typewriterText {
                typewriterView(tw)
            }

            // 프로그레스 바
            if let pb = engine.progressBarState {
                progressBarView(pb)
            }

            // 글로우 테두리
            if let glow = engine.glowState {
                glowOverlayView(glow)
            }
        }
        .allowsHitTesting(false)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: engine.comboCount)
    }

    // MARK: - Combo Counter

    private var comboView: some View {
        VStack(spacing: 2) {
            Text("\(engine.comboCount)")
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundColor(comboColor)
                .scaleEffect(engine.comboCount > 0 ? 1.0 + min(Double(engine.comboCount) / 100.0, 0.5) : 1.0)

            if engine.comboMultiplier > 1 {
                Text("×\(engine.comboMultiplier)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(comboColor.opacity(0.8))
            }

            Text("COMBO")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(comboColor.opacity(0.5))
                .tracking(3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(comboColor.opacity(0.3), lineWidth: 1))
        )
    }

    private var comboColor: Color {
        if engine.comboMultiplier >= 5 { return Color(hex: "f14c4c") }      // 빨강
        if engine.comboMultiplier >= 3 { return Color(hex: "f5a623") }      // 노랑
        if engine.comboMultiplier >= 2 { return Color(hex: "3ecf8e") }      // 초록
        return Color(hex: "3291ff")                                          // 파랑
    }

    // MARK: - Particles

    private func particleBurstView(_ burst: PluginEffectEngine.ParticleBurst) -> some View {
        GeometryReader { geo in
            let elapsed = Date().timeIntervalSince(burst.createdAt)
            let progress = min(elapsed / burst.duration, 1.0)

            ForEach(Array(burst.positions.enumerated()), id: \.offset) { idx, pos in
                let emoji = burst.emojis[idx % burst.emojis.count]
                Text(emoji)
                    .font(.system(size: 20))
                    .position(
                        x: geo.size.width * pos.x + pos.vx * CGFloat(progress),
                        y: geo.size.height * pos.y + pos.vy * CGFloat(progress) + 100 * CGFloat(progress * progress)
                    )
                    .opacity(1.0 - progress)
            }
        }
    }

    // MARK: - Confetti

    private var confettiView: some View {
        GeometryReader { geo in
            ForEach(engine.confettiPieces) { piece in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: piece.colorHex))
                    .frame(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 8...16))
                    .rotationEffect(.degrees(Double.random(in: 0...360)))
                    .position(x: geo.size.width * piece.x, y: -10)
                    .offset(y: geo.size.height + 20)
                    .animation(
                        .easeIn(duration: Double.random(in: 1.5...3.0)).delay(piece.delay),
                        value: engine.confettiPieces.count
                    )
            }
        }
    }

    // MARK: - Toast

    private func toastView(_ toast: PluginEffectEngine.EffectToast) -> some View {
        HStack(spacing: 6) {
            Image(systemName: toast.icon)
                .font(.system(size: 11, weight: .bold))
            Text(toast.text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.75))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }

    // MARK: - Typewriter

    private func typewriterView(_ state: PluginEffectEngine.TypewriterState) -> some View {
        let alignment: Alignment = {
            switch state.position {
            case "top": return .top
            case "bottom": return .bottom
            default: return .center
            }
        }()

        return Text(state.displayedText)
            .font(.system(size: state.fontSize, weight: .bold, design: .monospaced))
            .foregroundColor(Color(hex: state.colorHex))
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .transition(.opacity)
    }

    // MARK: - Progress Bar

    private func progressBarView(_ state: PluginEffectEngine.ProgressBarState) -> some View {
        VStack(spacing: 6) {
            if !state.label.isEmpty {
                Text(state.label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: state.trackColorHex))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: state.barColorHex))
                        .frame(width: geo.size.width * CGFloat(state.progress), height: 8)
                        .animation(.linear(duration: 0.05), value: state.progress)
                }
            }
            .frame(height: 8)

            Text("\(Int(state.progress * 100))%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: state.barColorHex).opacity(0.7))
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: 300)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: state.barColorHex).opacity(0.3), lineWidth: 1))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 60)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Glow Overlay

    private func glowOverlayView(_ state: PluginEffectEngine.GlowState) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color(hex: state.colorHex).opacity(state.intensity), lineWidth: 3)
            .shadow(color: Color(hex: state.colorHex).opacity(state.intensity * 0.8), radius: 12)
            .shadow(color: Color(hex: state.colorHex).opacity(state.intensity * 0.4), radius: 24)
            .ignoresSafeArea()
            .modifier(PulseModifier(speed: state.pulseSpeed))
    }
}

/// 펄스 애니메이션 모디파이어
private struct PulseModifier: ViewModifier {
    let speed: Double
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 1.0 : 0.4)
            .animation(
                .easeInOut(duration: speed).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
