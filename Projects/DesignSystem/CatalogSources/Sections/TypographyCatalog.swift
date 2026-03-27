import SwiftUI
import DesignSystem

struct TypographyCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Typography System")

            catalogSection("UI Text — mono()") {
                VStack(alignment: .leading, spacing: 12) {
                    typeSample("mono(16, .bold)", Theme.mono(16, weight: .bold))
                    typeSample("mono(14, .semibold)", Theme.mono(14, weight: .semibold))
                    typeSample("mono(12, .medium)", Theme.mono(12, weight: .medium))
                    typeSample("mono(11)", Theme.mono(11))
                    typeSample("mono(10)", Theme.mono(10))
                    typeSample("mono(9)", Theme.mono(9))
                    typeSample("mono(8)", Theme.mono(8))
                }
            }

            catalogSection("Code Text — code()") {
                VStack(alignment: .leading, spacing: 12) {
                    typeSample("code(12, .bold)", Theme.code(12, weight: .bold))
                    typeSample("code(11)", Theme.code(11))
                    typeSample("code(10)", Theme.code(10))
                    typeSample("code(9)", Theme.code(9))
                }
            }

            catalogSection("Chrome Text — chrome()") {
                VStack(alignment: .leading, spacing: 12) {
                    typeSample("chrome(12, .semibold)", Theme.chrome(12, weight: .semibold))
                    typeSample("chrome(10, .medium)", Theme.chrome(10, weight: .medium))
                    typeSample("chrome(9)", Theme.chrome(9))
                    typeSample("chrome(8)", Theme.chrome(8))
                }
            }

            catalogSection("Pre-scaled Fonts") {
                VStack(alignment: .leading, spacing: 12) {
                    typeSample("monoTiny", Theme.monoTiny)
                    typeSample("monoSmall", Theme.monoSmall)
                    typeSample("monoNormal", Theme.monoNormal)
                    typeSample("monoBold", Theme.monoBold)
                    typeSample("pixel", Theme.pixel)
                }
            }
        }
    }

    private func typeSample(_ label: String, _ font: Font) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .font(Theme.code(9))
                .foregroundColor(Theme.textDim)
                .frame(width: 200, alignment: .trailing)
            Text("도피스 Design System 0123")
                .font(font)
                .foregroundColor(Theme.textPrimary)
        }
    }
}
