import Foundation
import SwiftUI

extension AppSettings {
    public var coffeeSupportDisplayTitle: String {
        let trimmed = coffeeSupportButtonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("coffee.default.button", comment: "") : trimmed
    }

    public var trimmedCoffeeSupportBankName: String {
        coffeeSupportBankName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedCoffeeSupportAccountNumber: String {
        coffeeSupportAccountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var coffeeSupportAccountDisplayText: String {
        let bank = trimmedCoffeeSupportBankName.isEmpty ? NSLocalizedString("coffee.default.bank", comment: "") : trimmedCoffeeSupportBankName
        let account = trimmedCoffeeSupportAccountNumber.isEmpty ? "7777015832634" : trimmedCoffeeSupportAccountNumber
        return "\(bank) \(account)"
    }

    public var trimmedCoffeeSupportURL: String {
        coffeeSupportURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedCoffeeSupportCopyValue: String {
        coffeeSupportCopyValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var normalizedCoffeeSupportURL: URL? {
        Self.normalizedCoffeeSupportURL(from: trimmedCoffeeSupportURL)
    }

    public var hasCoffeeSupportDestination: Bool {
        !trimmedCoffeeSupportAccountNumber.isEmpty || normalizedCoffeeSupportURL != nil || !trimmedCoffeeSupportCopyValue.isEmpty
    }

    public func ensureCoffeeSupportPreset() {
        let targetVersion = 1
        guard coffeeSupportPresetVersion < targetVersion else { return }

        let currentTitle = coffeeSupportButtonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentTitle.isEmpty || currentTitle == "커피 후원" {
            coffeeSupportButtonTitle = "후원하기"
        }

        let currentMessage = coffeeSupportMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentMessage.isEmpty || currentMessage == "이 앱이 도움이 되셨다면 커피 한 잔으로 응원해주세요." {
            coffeeSupportMessage = "카카오뱅크 7777015832634로 커피 후원해주세요. 카카오뱅크나 토스를 열면 계좌가 먼저 복사됩니다."
        }

        if trimmedCoffeeSupportBankName.isEmpty {
            coffeeSupportBankName = "카카오뱅크"
        }
        if trimmedCoffeeSupportAccountNumber.isEmpty {
            coffeeSupportAccountNumber = "7777015832634"
        }
        if trimmedCoffeeSupportCopyValue.isEmpty {
            coffeeSupportCopyValue = coffeeSupportAccountDisplayText
        }

        coffeeSupportPresetVersion = targetVersion
    }

    public func coffeeSupportURL(for tier: CoffeeSupportTier) -> URL? {
        Self.normalizedCoffeeSupportURL(from: renderCoffeeSupportTemplate(trimmedCoffeeSupportURL, tier: tier))
    }

    public func coffeeSupportCopyText(for tier: CoffeeSupportTier) -> String {
        renderCoffeeSupportTemplate(trimmedCoffeeSupportCopyValue, tier: tier)
    }

    func renderCoffeeSupportTemplate(_ template: String, tier: CoffeeSupportTier) -> String {
        guard !template.isEmpty else { return "" }
        let replacements: [String: String] = [
            "{{amount}}": "\(tier.amount)",
            "{{amount_text}}": tier.amountLabel,
            "{{tier}}": tier.title,
            "{{app_name}}": appDisplayName
        ]

        var rendered = template
        for (token, value) in replacements {
            rendered = rendered.replacingOccurrences(of: token, with: value)
        }
        return rendered.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedCoffeeSupportURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            return url
        }

        return URL(string: "https://" + trimmed)
    }
}
