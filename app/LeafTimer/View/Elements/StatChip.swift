import SwiftUI

/// トップ画面の「今日 / 連続」などを表示する角丸ピル。
/// 背景は `.ultraThinMaterial` で work/break × light/dark の全状態に自動適応する。
/// 純表示コンポーネント（内部状態を持たない）。
struct StatChip: View {
    let systemImage: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundColor(tint)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct StatChip_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 10) {
            StatChip(systemImage: "leaf.fill", tint: .green, text: "今日 3")
            StatChip(systemImage: "flame.fill", tint: .orange, text: "連続 5")
        }
        .padding(40)
        .background(
            LinearGradient(
                colors: [.green.opacity(0.35), .green.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
