//
//  GIFView.swift
//  LeafTimer
//
//  Created by Ema Shinya on 2020/08/07.
//  Copyright © 2020 Ema Shinya. All rights reserved.
//

import SwiftUI

struct GIFView: UIViewRepresentable {
    var gifName: String

    // Issue #62: 「視差効果を減らす」有効時は葉 GIF を静止画に切り替える。
    // 設定変更は環境値の変化 → updateUIView 経由で実行中にも追従する
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func updateUIView(_ uiView: GIFPlayerView, context: UIViewRepresentableContext<GIFView>) {
        uiView.setReduceMotion(reduceMotion)
    }

    func makeUIView(context: Context) -> GIFPlayerView {
        let view = GIFPlayerView(gifName: gifName)
        view.setReduceMotion(reduceMotion)
        return view
    }
}
