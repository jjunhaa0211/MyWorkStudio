import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Effect Engine (이펙트 런타임)
// ═══════════════════════════════════════════════════════

class PluginEffectEngine: ObservableObject {
    static let shared = PluginEffectEngine()

    // ── 시각 상태 ──
    @Published var comboCount: Int = 0
    @Published var comboMultiplier: Int = 1
    @Published var activeParticles: [ParticleBurst] = []
    @Published var shakeOffset: CGSize = .zero
    @Published var flashColor: Color?
    @Published var activeToasts: [EffectToast] = []
    @Published var confettiPieces: [ConfettiPiece] = []

    private var comboDecayTimer: Timer?
    private var flashDismissWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    struct ParticleBurst: Identifiable {
        let id = UUID()
        let emojis: [String]
        let positions: [(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat)]
        let createdAt: Date
        let duration: Double
    }

    struct EffectToast: Identifiable {
        let id = UUID()
        let text: String
        let icon: String
        let tintHex: String
    }

    struct ConfettiPiece: Identifiable {
        let id = UUID()
        let colorHex: String
        let x: CGFloat
        let delay: Double
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

        // 타임스탬프 기반 만료: duration + 1초 이상 지난 파티클 제거
        let now = Date()
        activeParticles.removeAll { now.timeIntervalSince($0.createdAt) > $0.duration + 1.0 }

        // 하드 캡: 최대 100개 파티클 유지
        if activeParticles.count >= 100 {
            activeParticles.removeFirst(activeParticles.count - 99)
        }
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
        // 안전망: 2초 후에도 shakeOffset이 남아있으면 강제 리셋
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.shakeOffset != .zero {
                self?.shakeOffset = .zero
            }
        }
    }

    // MARK: - Flash

    private func executeFlash(_ config: [String: EffectValue]) {
        let hex = config["colorHex"]?.stringValue ?? "ffffff"
        let duration = config["duration"]?.doubleValue ?? 0.3

        // 이전 플래시 해제 작업 취소 (연속 호출 시 race condition 방지)
        flashDismissWork?.cancel()

        withAnimation(.easeIn(duration: 0.05)) {
            flashColor = Color(hex: hex)
        }

        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) {
                self?.flashColor = nil
            }
        }
        flashDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)

        // 안전망: duration의 2배 후에도 flashColor가 남아있으면 강제 해제
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 1.0) { [weak self] in
            if self?.flashColor != nil {
                withAnimation(.easeOut(duration: 0.15)) {
                    self?.flashColor = nil
                }
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
            // 토스트 최대 5개 유지
            if activeToasts.count >= 5 {
                activeToasts.removeFirst()
            }
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
}

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Effect Overlay (SwiftUI 오버레이)
// ═══════════════════════════════════════════════════════

struct PluginEffectOverlay: View {
    @ObservedObject var engine = PluginEffectEngine.shared
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // 플래시 (최대 표시 시간 제한)
            if let color = engine.flashColor {
                color.opacity(0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .onAppear {
                        // 안전망: 3초 후에도 남아있으면 강제 해제
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            if engine.flashColor != nil {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    engine.flashColor = nil
                                }
                            }
                        }
                    }
            }

            // 콤보 카운터 (우상단)
            if engine.comboCount > 0 {
                comboView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(20)
            }

            // 파티클 (최대 20개 제한)
            ForEach(Array(engine.activeParticles.suffix(20))) { burst in
                particleBurstView(burst)
            }

            // 컨페티
            if !engine.confettiPieces.isEmpty {
                confettiView
            }

            // 토스트 (좌하단, 최대 5개)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(engine.activeToasts.suffix(5))) { toast in
                    toastView(toast)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(16)
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
            let progress = min(elapsed / max(0.001, burst.duration), 1.0)

            ForEach(Array(burst.positions.enumerated()), id: \.offset) { idx, pos in
                let emoji = burst.emojis.isEmpty ? "✨" : burst.emojis[idx % burst.emojis.count]
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
}
