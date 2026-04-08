import SwiftUI
import DesignSystem

// MARK: - Character Pixel Art Renderer (재사용 가능한 캐릭터 픽셀아트 렌더러)

public enum CharacterPixelRenderer {

    /// 캐릭터 픽셀아트를 Canvas 컨텍스트에 그립니다.
    public static func draw(character: WorkerCharacter, context: GraphicsContext, size: CGSize, scale: CGFloat = 2.5) {
        let s = scale
        let x: CGFloat = (size.width - 16 * s) / 2
        let y: CGFloat = (size.height - 22 * s) / 2 + 2

        let fur = Color(hex: character.skinTone)
        let hair = Color(hex: character.hairColor)
        let shirt = Color(hex: character.shirtColor)
        let pants = Color(hex: character.pantsColor)

        func px(_ px: CGFloat, _ py: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
            context.fill(Path(CGRect(x: x + px * s, y: y + py * s, width: w * s, height: h * s)), with: .color(c))
        }

        switch character.species {
        case .cat:
            px(3, -2, 3, 3, fur); px(10, -2, 3, 3, fur)
            px(4, -1, 1, 1, Color(hex: "f0a0a0")); px(11, -1, 1, 1, Color(hex: "f0a0a0"))
            px(4, 1, 8, 6, fur)
            px(5, 3, 2, 2, Color(hex: "60c060")); px(6, 3, 1, 2, Color(hex: "1a1a1a"))
            px(9, 3, 2, 2, Color(hex: "60c060")); px(10, 3, 1, 2, Color(hex: "1a1a1a"))
            px(7, 5, 2, 1, Color(hex: "f08080"))
            px(2, 5, 2, 1, Color(hex: "ddd")); px(12, 5, 2, 1, Color(hex: "ddd"))
            px(4, 7, 8, 7, shirt)
            px(3, 12, 3, 2, fur); px(10, 12, 3, 2, fur)
            px(4, 14, 3, 3, fur); px(9, 14, 3, 3, fur)
            px(13, 10, 2, 2, fur); px(14, 8, 2, 3, fur)

        case .dog:
            px(2, 1, 3, 5, hair); px(11, 1, 3, 5, hair)
            px(4, 0, 8, 7, fur)
            px(5, 3, 2, 2, .white); px(6, 4, 1, 1, Color(hex: "333"))
            px(9, 3, 2, 2, .white); px(10, 4, 1, 1, Color(hex: "333"))
            px(7, 5, 2, 1, Color(hex: "333"))
            px(7, 6, 2, 1, Color(hex: "f06060"))
            px(4, 7, 8, 7, shirt)
            px(3, 12, 3, 2, fur); px(10, 12, 3, 2, fur)
            px(4, 14, 3, 3, fur); px(9, 14, 3, 3, fur)
            px(13, 5, 2, 2, fur); px(14, 3, 2, 3, fur)

        case .rabbit:
            px(5, -5, 2, 6, fur); px(9, -5, 2, 6, fur)
            px(5, -4, 1, 4, Color(hex: "f0a0a0")); px(10, -4, 1, 4, Color(hex: "f0a0a0"))
            px(4, 1, 8, 6, fur)
            px(5, 3, 2, 2, Color(hex: "d04060")); px(6, 3, 1, 1, Color(hex: "1a1a1a"))
            px(9, 3, 2, 2, Color(hex: "d04060")); px(10, 3, 1, 1, Color(hex: "1a1a1a"))
            px(7, 5, 2, 1, Color(hex: "f0a0a0"))
            px(4, 7, 8, 7, shirt)
            px(3, 12, 3, 2, fur); px(10, 12, 3, 2, fur)
            px(5, 14, 3, 3, fur); px(8, 14, 3, 3, fur)
            px(13, 11, 3, 3, .white)

        case .bear:
            px(3, -1, 3, 3, fur); px(10, -1, 3, 3, fur)
            px(4, 0, 1, 1, Color(hex: "c09060")); px(11, 0, 1, 1, Color(hex: "c09060"))
            px(4, 1, 8, 7, fur)
            px(6, 5, 4, 3, Color(hex: "d0b090"))
            px(5, 3, 2, 2, Color(hex: "1a1a1a"))
            px(9, 3, 2, 2, Color(hex: "1a1a1a"))
            px(7, 5, 2, 1, Color(hex: "333"))
            px(3, 8, 10, 7, shirt)
            px(2, 10, 3, 3, fur); px(11, 10, 3, 3, fur)
            px(4, 15, 4, 3, fur); px(8, 15, 4, 3, fur)

        case .penguin:
            px(4, 0, 8, 5, Color(hex: "2a2a3a"))
            px(5, 2, 6, 4, .white)
            px(6, 3, 1, 1, Color(hex: "1a1a1a")); px(9, 3, 1, 1, Color(hex: "1a1a1a"))
            px(7, 5, 2, 1, Theme.yellow)
            px(3, 6, 10, 8, Color(hex: "2a2a3a"))
            px(5, 7, 6, 6, .white)
            px(2, 8, 2, 5, Color(hex: "2a2a3a")); px(12, 8, 2, 5, Color(hex: "2a2a3a"))
            px(5, 14, 3, 2, Theme.yellow); px(8, 14, 3, 2, Theme.yellow)

        case .fox:
            px(3, -2, 3, 4, Color(hex: "e07030")); px(10, -2, 3, 4, Color(hex: "e07030"))
            px(4, -1, 1, 2, .white); px(11, -1, 1, 2, .white)
            px(4, 1, 8, 6, fur)
            px(4, 4, 3, 3, .white); px(9, 4, 3, 3, .white)
            px(5, 3, 2, 1, Color(hex: "f0c020")); px(6, 3, 1, 1, Color(hex: "1a1a1a"))
            px(9, 3, 2, 1, Color(hex: "f0c020")); px(10, 3, 1, 1, Color(hex: "1a1a1a"))
            px(7, 5, 2, 1, Color(hex: "333"))
            px(4, 7, 8, 7, shirt)
            px(3, 12, 3, 2, fur); px(10, 12, 3, 2, fur)
            px(4, 14, 3, 3, fur); px(9, 14, 3, 3, fur)
            px(12, 9, 3, 2, fur); px(13, 7, 3, 4, fur); px(14, 11, 2, 1, .white)

        case .robot:
            px(7, -3, 2, 3, Color(hex: "8090a0"))
            px(6, -4, 4, 1, Color(hex: "60f0a0"))
            px(3, 0, 10, 7, Color(hex: "a0b0c0"))
            px(4, 1, 8, 5, Color(hex: "8090a0"))
            px(5, 3, 2, 2, Color(hex: "60f0a0")); px(9, 3, 2, 2, Color(hex: "60f0a0"))
            px(6, 5, 4, 1, Color(hex: "506070"))
            px(3, 7, 10, 8, shirt)
            px(3, 7, 10, 1, Color(hex: "8090a0"))
            px(1, 9, 2, 5, Color(hex: "8090a0")); px(13, 9, 2, 5, Color(hex: "8090a0"))
            px(4, 15, 3, 3, Color(hex: "708090")); px(9, 15, 3, 3, Color(hex: "708090"))

        case .claude:
            let c = Color(hex: character.shirtColor)
            let eye = Color(hex: "2a1810")
            px(4, 1, 8, 1, c)
            px(3, 2, 10, 7, c)
            px(1, 3, 2, 2, c); px(0, 4, 1, 1, c)
            px(13, 3, 2, 2, c); px(15, 4, 1, 1, c)
            px(5, 4, 1, 2, eye); px(10, 4, 1, 2, eye)
            px(4, 9, 1, 3, c); px(6, 9, 1, 3, c)
            px(9, 9, 1, 3, c); px(11, 9, 1, 3, c)

        case .alien:
            px(3, -1, 10, 2, fur)
            px(2, 1, 12, 6, fur)
            px(4, 3, 3, 3, Color(hex: "101010"))
            px(9, 3, 3, 3, Color(hex: "101010"))
            px(5, 4, 1, 1, Color(hex: "40ff80"))
            px(10, 4, 1, 1, Color(hex: "40ff80"))
            px(5, 7, 6, 5, shirt)
            px(3, 8, 2, 4, shirt); px(11, 8, 2, 4, shirt)
            px(5, 12, 2, 4, fur); px(9, 12, 2, 4, fur)
            px(7, -3, 2, 2, Color(hex: "40ff80")); px(8, -4, 1, 1, Color(hex: "80ffa0"))

        case .ghost:
            px(4, 0, 8, 3, fur)
            px(3, 3, 10, 6, fur)
            px(5, 4, 2, 2, Color(hex: "303040"))
            px(9, 4, 2, 2, Color(hex: "303040"))
            px(6, 7, 4, 1, Color(hex: "404050"))
            px(3, 9, 3, 3, fur); px(6, 10, 4, 2, fur); px(10, 9, 3, 3, fur)
            px(4, 12, 2, 1, fur); px(8, 12, 2, 1, fur); px(12, 12, 1, 1, fur)

        case .dragon:
            px(4, -2, 2, 2, Color(hex: "f0c030"))
            px(10, -2, 2, 2, Color(hex: "f0c030"))
            px(4, 0, 8, 6, fur)
            px(5, 2, 2, 2, Color(hex: "ff4020"))
            px(9, 2, 2, 2, Color(hex: "ff4020"))
            px(6, 5, 4, 1, Color(hex: "f06030"))
            px(3, 6, 10, 6, shirt)
            px(0, 5, 3, 5, shirt.opacity(0.6))
            px(13, 5, 3, 5, shirt.opacity(0.6))
            px(4, 12, 3, 4, fur); px(9, 12, 3, 4, fur)
            px(13, 10, 3, 2, shirt); px(14, 12, 2, 1, shirt)

        case .chicken:
            px(6, -2, 4, 2, Color(hex: "e03020"))
            px(5, 0, 6, 5, fur)
            px(6, 2, 2, 2, Color(hex: "101010"))
            px(11, 3, 2, 1, Color(hex: "f0a020"))
            px(6, 5, 1, 2, Color(hex: "f03020"))
            px(4, 5, 8, 7, shirt)
            px(2, 6, 2, 4, shirt.opacity(0.7))
            px(12, 6, 2, 4, shirt.opacity(0.7))
            px(5, 12, 2, 4, Color(hex: "f0a020"))
            px(9, 12, 2, 4, Color(hex: "f0a020"))

        case .owl:
            px(3, -1, 3, 3, hair)
            px(10, -1, 3, 3, hair)
            px(4, 1, 8, 6, fur)
            px(4, 3, 3, 3, Color(hex: "f0e0a0"))
            px(9, 3, 3, 3, Color(hex: "f0e0a0"))
            px(5, 4, 2, 2, Color(hex: "202020"))
            px(10, 4, 2, 2, Color(hex: "202020"))
            px(7, 6, 2, 1, Color(hex: "d09030"))
            px(3, 7, 10, 6, shirt)
            px(1, 8, 2, 4, hair); px(13, 8, 2, 4, hair)
            px(5, 13, 2, 3, fur); px(9, 13, 2, 3, fur)

        case .frog:
            px(3, 0, 4, 3, fur); px(9, 0, 4, 3, fur)
            px(4, 1, 2, 2, Color(hex: "101010")); px(10, 1, 2, 2, Color(hex: "101010"))
            px(3, 3, 10, 5, fur)
            px(4, 6, 8, 1, Color(hex: "f06060"))
            px(3, 8, 10, 5, shirt)
            px(1, 9, 2, 4, shirt); px(13, 9, 2, 4, shirt)
            px(4, 13, 3, 3, fur); px(9, 13, 3, 3, fur)

        case .panda:
            px(2, -1, 4, 3, Color(hex: "1a1a1a"))
            px(10, -1, 4, 3, Color(hex: "1a1a1a"))
            px(4, 1, 8, 6, fur)
            px(4, 3, 3, 3, Color(hex: "1a1a1a"))
            px(9, 3, 3, 3, Color(hex: "1a1a1a"))
            px(5, 4, 1, 1, .white); px(10, 4, 1, 1, .white)
            px(7, 5, 2, 1, Color(hex: "1a1a1a"))
            px(3, 7, 10, 6, shirt)
            px(1, 8, 2, 5, Color(hex: "1a1a1a")); px(13, 8, 2, 5, Color(hex: "1a1a1a"))
            px(4, 13, 3, 3, Color(hex: "1a1a1a")); px(9, 13, 3, 3, Color(hex: "1a1a1a"))

        case .unicorn:
            px(7, -4, 2, 1, Color(hex: "f0d040"))
            px(7, -3, 2, 1, Color(hex: "f0c040"))
            px(7, -2, 2, 2, Color(hex: "f0b040"))
            px(4, 0, 8, 6, fur)
            px(2, 0, 2, 5, hair)
            px(5, 2, 2, 2, .white); px(6, 3, 1, 1, Color(hex: "c060c0"))
            px(9, 2, 2, 2, .white); px(10, 3, 1, 1, Color(hex: "c060c0"))
            px(3, 6, 10, 7, shirt)
            px(1, 7, 2, 4, shirt); px(13, 7, 2, 4, shirt)
            px(4, 13, 3, 3, fur); px(9, 13, 3, 3, fur)

        case .skeleton:
            let bone = Color(hex: "f0f0e0")
            px(4, 0, 8, 6, bone)
            px(5, 2, 2, 2, Color(hex: "1a1a1a"))
            px(9, 2, 2, 2, Color(hex: "1a1a1a"))
            px(6, 4, 1, 1, Color(hex: "1a1a1a"))
            px(5, 5, 6, 1, Color(hex: "1a1a1a"))
            px(5, 5, 1, 1, bone); px(7, 5, 1, 1, bone); px(9, 5, 1, 1, bone)
            px(5, 6, 6, 6, Color(hex: "404040"))
            px(6, 7, 4, 1, bone); px(6, 9, 4, 1, bone)
            px(3, 7, 2, 5, Color(hex: "404040")); px(11, 7, 2, 5, Color(hex: "404040"))
            px(5, 12, 2, 4, bone); px(9, 12, 2, 4, bone)

        case .human:
            switch character.hatType {
            case .beanie: px(3, -2, 10, 3, Color(hex: "4040a0"))
            case .cap: px(2, -1, 12, 2, Color(hex: "c04040")); px(1, 0, 4, 1, Color(hex: "a03030"))
            case .hardhat: px(3, -2, 10, 3, Theme.yellow); px(2, -1, 12, 1, Theme.yellow)
            case .wizard: px(5, -5, 6, 2, Color(hex: "6040a0")); px(4, -3, 8, 2, Color(hex: "6040a0")); px(3, -1, 10, 2, Color(hex: "6040a0"))
            case .crown: px(4, -2, 8, 1, Theme.yellow); px(4, -3, 2, 1, Theme.yellow); px(7, -3, 2, 1, Theme.yellow); px(10, -3, 2, 1, Theme.yellow)
            case .headphones: px(2, 2, 2, 4, Color(hex: "404040")); px(12, 2, 2, 4, Color(hex: "404040")); px(3, 0, 10, 1, Color(hex: "505050"))
            case .beret: px(3, -1, 11, 2, Color(hex: "c04040")); px(3, -2, 8, 1, Color(hex: "c04040"))
            case .none: break
            }
            px(4, 0, 8, 3, hair); px(3, 1, 1, 2, hair); px(12, 1, 1, 2, hair)
            px(4, 3, 8, 5, fur)
            px(5, 4, 2, 2, .white); px(6, 5, 1, 1, Color(hex: "333"))
            px(9, 4, 2, 2, .white); px(10, 5, 1, 1, Color(hex: "333"))

            switch character.accessory {
            case .glasses: px(4, 4, 3, 1, Color(hex: "4060a0")); px(7, 4, 1, 1, Color(hex: "4060a0")); px(8, 4, 3, 1, Color(hex: "4060a0"))
            case .sunglasses: px(4, 4, 3, 2, Color(hex: "1a1a1a")); px(7, 4, 1, 1, Color(hex: "1a1a1a")); px(8, 4, 3, 2, Color(hex: "1a1a1a"))
            case .scarf: px(3, 7, 10, 2, Color(hex: "c04040"))
            case .mask: px(4, 5, 8, 3, Color(hex: "2a2a2a"))
            case .earring: px(13, 4, 1, 2, Theme.yellow)
            case .none: break
            }

            px(3, 8, 10, 6, shirt)
            px(1, 9, 2, 5, shirt); px(13, 9, 2, 5, shirt)
            px(0, 13, 2, 2, fur); px(14, 13, 2, 2, fur)
            px(4, 14, 4, 4, pants); px(8, 14, 4, 4, pants)
            px(4, 18, 3, 2, pants); px(9, 18, 3, 2, pants)
            px(3, 19, 4, 2, Color(hex: "4a5060")); px(9, 19, 4, 2, Color(hex: "4a5060"))
        }
    }
}

// MARK: - Character Mini Avatar View

public struct CharacterMiniAvatar: View {
    public let character: WorkerCharacter
    public var pixelScale: CGFloat
    public var bgOpacity: CGFloat

    public init(character: WorkerCharacter, pixelScale: CGFloat = 1.8, bgOpacity: CGFloat = 0.12) {
        self.character = character
        self.pixelScale = pixelScale
        self.bgOpacity = bgOpacity
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: character.shirtColor).opacity(bgOpacity))
            Canvas { context, size in
                CharacterPixelRenderer.draw(character: character, context: context, size: size, scale: pixelScale)
            }
        }
    }
}
