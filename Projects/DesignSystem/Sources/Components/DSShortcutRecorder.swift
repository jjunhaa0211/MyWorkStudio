import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSShortcutRecorder (Keyboard Shortcut Input)
// ═══════════════════════════════════════════════════════

public struct DSShortcutRecorder: View {
    @Binding public var shortcut: String
    public var placeholder: String

    @State private var isRecording = false
    @State private var monitor: Any?

    public init(shortcut: Binding<String>, placeholder: String = "Click to record...") {
        self._shortcut = shortcut
        self.placeholder = placeholder
    }

    public var body: some View {
        Button(action: toggleRecording) {
            HStack(spacing: 8) {
                if isRecording {
                    DSRing(tint: Theme.red, size: 12, lineWidth: 1.5, isAnimating: true)
                    Text("Recording...")
                        .font(Theme.mono(10, weight: .medium))
                        .foregroundColor(Theme.red)
                } else if shortcut.isEmpty {
                    Image(systemName: "record.circle")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textDim)
                    Text(placeholder)
                        .font(Theme.mono(10))
                        .foregroundColor(Theme.textDim)
                } else {
                    DSKeyboardShortcut(shortcut)
                    Spacer()
                    Button(action: { shortcut = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear shortcut")
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.sp3)
            .padding(.vertical, Theme.sp2)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(isRecording ? Theme.red.opacity(0.05) : Theme.bgInput)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(isRecording ? Theme.red : Theme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(shortcut.isEmpty ? "Record keyboard shortcut" : "Shortcut: \(shortcut)")
        .accessibilityHint(isRecording ? "Press a key combination to record" : "Click to start recording a shortcut")
        .onDisappear { stopRecording() }
    }

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            var parts: [String] = []
            if event.modifierFlags.contains(.command) { parts.append("Cmd") }
            if event.modifierFlags.contains(.shift) { parts.append("Shift") }
            if event.modifierFlags.contains(.option) { parts.append("Opt") }
            if event.modifierFlags.contains(.control) { parts.append("Ctrl") }

            if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
                let key = chars == "\r" ? "Enter" : chars == "\u{1b}" ? "Esc" : chars == "\t" ? "Tab" : chars
                if !["", " "].contains(key) || chars == " " {
                    parts.append(chars == " " ? "Space" : key)
                }
            }

            if !parts.isEmpty && parts.count > 1 {
                shortcut = parts.joined(separator: "+")
                stopRecording()
            }

            return nil  // consume the event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
