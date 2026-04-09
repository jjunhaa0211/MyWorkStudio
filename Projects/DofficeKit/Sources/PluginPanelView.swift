import Foundation
import SwiftUI
import WebKit
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Panel View (WKWebView 래퍼)
// ═══════════════════════════════════════════════════════

#if os(macOS)
public struct PluginPanelView: NSViewRepresentable {
    public let htmlURL: URL
    public let pluginName: String

    public init(htmlURL: URL, pluginName: String) {
        self.htmlURL = htmlURL
        self.pluginName = pluginName
    }

    public func makeNSView(context: Context) -> WKWebView {
        makeWebView()
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        loadContent(webView)
    }

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let handler = PluginMessageHandler(pluginName: pluginName)
        config.userContentController.add(handler, name: "doffice")

        // Inject doffice JS bridge helper
        let bridgeScript = WKUserScript(source: PluginBridge.injectedJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(bridgeScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        // Register for native → JS events
        PluginBridge.registerWebView(webView, pluginName: pluginName)

        return webView
    }

    private func loadContent(_ webView: WKWebView) {
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }
}
#elseif os(iOS)
public struct PluginPanelView: UIViewRepresentable {
    public let htmlURL: URL
    public let pluginName: String

    public init(htmlURL: URL, pluginName: String) {
        self.htmlURL = htmlURL
        self.pluginName = pluginName
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let handler = PluginMessageHandler(pluginName: pluginName)
        config.userContentController.add(handler, name: "doffice")

        let bridgeScript = WKUserScript(source: PluginBridge.injectedJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(bridgeScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        PluginBridge.registerWebView(webView, pluginName: pluginName)

        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }
}
#endif

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Message Handler (JS → Native)
// ═══════════════════════════════════════════════════════

/// 플러그인 JS → 앱 통신 핸들러 (확장된 API 지원)
public class PluginMessageHandler: NSObject, WKScriptMessageHandler {
    private let pluginName: String

    public init(pluginName: String = "") {
        self.pluginName = pluginName
        super.init()
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        PluginManager.shared.logDebug(.info, source: pluginName, message: "JS action: \(action)")

        switch action {

        // --- 기존 API ---
        case "getSessionInfo":
            NotificationCenter.default.post(name: .pluginRequestSessionInfo, object: message.webView)

        case "notify":
            if let text = body["text"] as? String {
                NotificationCenter.default.post(name: .pluginNotify, object: nil, userInfo: ["text": text])
            }

        // --- 새 API: 테마 색상 ---
        case "getThemeColors":
            let colors: [String: String] = [
                "accent": Theme.accent.hexString,
                "bg": Theme.bg.hexString,
                "bgCard": Theme.bgCard.hexString,
                "bgSurface": Theme.bgSurface.hexString,
                "textPrimary": Theme.textPrimary.hexString,
                "textSecondary": Theme.textSecondary.hexString,
                "textDim": Theme.textDim.hexString,
                "green": Theme.green.hexString,
                "red": Theme.red.hexString,
                "yellow": Theme.yellow.hexString,
                "purple": Theme.purple.hexString,
                "cyan": Theme.cyan.hexString,
                "orange": Theme.orange.hexString,
            ]
            respondToWebView(message.webView, callbackId: body["callbackId"] as? String, data: colors)

        // --- 새 API: 활성 탭 정보 ---
        case "getActiveTab":
            let manager = SessionManager.shared
            if let tab = manager.activeTab {
                let info: [String: Any] = [
                    "id": tab.id,
                    "projectName": tab.projectName,
                    "workerName": tab.workerName,
                    "tokensUsed": tab.tokensUsed,
                    "isProcessing": tab.isProcessing,
                    "provider": tab.provider.rawValue,
                ]
                respondToWebView(message.webView, callbackId: body["callbackId"] as? String, data: info)
            }

        // --- 새 API: 모든 탭 목록 ---
        case "getAllTabs":
            let manager = SessionManager.shared
            let tabs = manager.userVisibleTabs.map { tab -> [String: Any] in
                [
                    "id": tab.id,
                    "projectName": tab.projectName,
                    "workerName": tab.workerName,
                    "tokensUsed": tab.tokensUsed,
                    "isProcessing": tab.isProcessing,
                ]
            }
            respondToWebView(message.webView, callbackId: body["callbackId"] as? String, data: ["tabs": tabs])

        // --- 새 API: 이펙트 트리거 ---
        case "triggerEffect":
            if let effectType = body["effectType"] as? String {
                PluginManager.shared.logDebug(.effect, source: pluginName, message: "triggerEffect: \(effectType)")
                NotificationCenter.default.post(name: .pluginEffectEvent, object: nil, userInfo: ["type": effectType, "source": pluginName])
            }

        // --- 새 API: 토스트 (확장) ---
        case "showToast":
            let text = body["text"] as? String ?? ""
            let icon = body["icon"] as? String ?? "info.circle"
            let tint = body["tint"] as? String ?? ""
            NotificationCenter.default.post(name: .pluginNotify, object: nil, userInfo: [
                "text": text, "icon": icon, "tint": tint, "source": pluginName
            ])

        // --- 새 API: 플러그인 스토리지 ---
        case "readPluginStorage":
            if let key = body["key"] as? String {
                let storageKey = "plugin.\(pluginName).\(key)"
                let value = PersistenceService.shared.string(forKey: storageKey) ?? ""
                respondToWebView(message.webView, callbackId: body["callbackId"] as? String, data: ["value": value])
            }

        case "writePluginStorage":
            if let key = body["key"] as? String, let value = body["value"] as? String {
                let storageKey = "plugin.\(pluginName).\(key)"
                PersistenceService.shared.set(value, forKey: storageKey)
                respondToWebView(message.webView, callbackId: body["callbackId"] as? String, data: ["success": true])
            }

        // --- 새 API: 설정 열기 ---
        case "openSettings":
            NotificationCenter.default.post(name: Notification.Name("dofficeOpenSettings"), object: nil)

        default:
            PluginManager.shared.logDebug(.warning, source: pluginName, message: "Unknown JS action: \(action)")
        }
    }

    /// WebView에 JSON 응답 전송
    private func respondToWebView(_ webView: WKWebView?, callbackId: String?, data: Any) {
        guard let webView, let callbackId else { return }
        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let js = "window.__dofficeCallbacks && window.__dofficeCallbacks['\(callbackId)'] && window.__dofficeCallbacks['\(callbackId)'](\(jsonString))"
            DispatchQueue.main.async {
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Bridge (Native → JS 이벤트 전달)
// ═══════════════════════════════════════════════════════

public enum PluginBridge {
    private static var registeredWebViews: [String: WeakWebView] = [:]

    private struct WeakWebView {
        weak var webView: WKWebView?
    }

    /// 패널에서 주입할 JS 코드 — window.doffice API 제공
    static let injectedJS = """
    (function() {
        window.__dofficeCallbacks = {};
        var callbackCounter = 0;

        window.doffice = {
            // Request with callback (Promise-based)
            request: function(action, params) {
                return new Promise(function(resolve) {
                    var id = '__cb_' + (++callbackCounter);
                    window.__dofficeCallbacks[id] = function(data) {
                        delete window.__dofficeCallbacks[id];
                        resolve(data);
                    };
                    var msg = Object.assign({ action: action, callbackId: id }, params || {});
                    window.webkit.messageHandlers.doffice.postMessage(msg);
                });
            },

            // Convenience methods
            getThemeColors: function() { return this.request('getThemeColors'); },
            getActiveTab: function() { return this.request('getActiveTab'); },
            getAllTabs: function() { return this.request('getAllTabs'); },
            readStorage: function(key) { return this.request('readPluginStorage', { key: key }); },
            writeStorage: function(key, value) { return this.request('writePluginStorage', { key: key, value: value }); },

            // Fire-and-forget
            notify: function(text) {
                window.webkit.messageHandlers.doffice.postMessage({ action: 'notify', text: text });
            },
            showToast: function(text, icon, tint) {
                window.webkit.messageHandlers.doffice.postMessage({ action: 'showToast', text: text, icon: icon || '', tint: tint || '' });
            },
            triggerEffect: function(type) {
                window.webkit.messageHandlers.doffice.postMessage({ action: 'triggerEffect', effectType: type });
            },
            openSettings: function() {
                window.webkit.messageHandlers.doffice.postMessage({ action: 'openSettings' });
            },

            // Event listeners (native -> JS)
            _listeners: {},
            on: function(event, callback) {
                if (!this._listeners[event]) this._listeners[event] = [];
                this._listeners[event].push(callback);
            },
            off: function(event, callback) {
                if (!this._listeners[event]) return;
                this._listeners[event] = this._listeners[event].filter(function(cb) { return cb !== callback; });
            },
            _emit: function(event, data) {
                var cbs = this._listeners[event] || [];
                cbs.forEach(function(cb) { try { cb(data); } catch(e) { console.error('doffice event error:', e); } });
                // Also dispatch DOM event for compatibility
                window.dispatchEvent(new CustomEvent('doffice-event', { detail: { type: event, data: data } }));
            }
        };
    })();
    """

    /// WebView를 이벤트 수신 대상으로 등록
    public static func registerWebView(_ webView: WKWebView, pluginName: String) {
        registeredWebViews[pluginName] = WeakWebView(webView: webView)
    }

    /// 등록된 모든 패널에 이벤트 전달
    public static func dispatchEvent(_ event: String, data: [String: Any] = [:]) {
        let jsonData = (try? JSONSerialization.data(withJSONObject: data)) ?? Data()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let js = "window.doffice && window.doffice._emit('\(event)', \(jsonString))"

        DispatchQueue.main.async {
            // Clean up dead references
            registeredWebViews = registeredWebViews.filter { $0.value.webView != nil }

            for (_, weak) in registeredWebViews {
                weak.webView?.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Notification Names
// ═══════════════════════════════════════════════════════

extension Notification.Name {
    public static let pluginRequestSessionInfo = Notification.Name("pluginRequestSessionInfo")
    public static let pluginNotify = Notification.Name("pluginNotify")
    public static let pluginReload = Notification.Name("pluginReload")
    public static let pluginEffectEvent = Notification.Name("pluginEffectEvent")
}

// ═══════════════════════════════════════════════════════
// MARK: - Color hex helper
// ═══════════════════════════════════════════════════════

extension Color {
    /// Color → hex string (for JS bridge)
    var hexString: String {
        #if os(macOS)
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return "000000" }
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return String(format: "%02x%02x%02x", r, g, b)
        #else
        return "000000"
        #endif
    }
}
