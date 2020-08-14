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

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<GIFView>) {

    }


    func makeUIView(context: Context) -> UIView {
        return GIFPlayerView(gifName: gifName)
    }
}
