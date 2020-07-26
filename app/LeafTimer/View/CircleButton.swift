//
//  CircleButton.swift
//  LeafTimer
//
//  Created by Ema Shinya on 2020/07/26.
//  Copyright © 2020 Ema Shinya. All rights reserved.
//

import SwiftUI

struct CircleButton: View {
    let buttonState: String

    let color1 = Color(.init(red: 0.35, green: 0.47, blue: 0.35, alpha: 1))
    let color2 = Color(.init(red: 0.57, green: 0.73, blue: 0.52, alpha: 1))
    let color3 = Color(.init(red: 0.49, green: 0.71, blue: 0.41, alpha: 1))
    let color4 = Color(.init(red: 0.35, green: 0.67, blue: 0.29, alpha: 1))

    var body: some View {
        Circle()
            .fill(color1)
            .frame(width: 150, height: 150, alignment: .center)
            .overlay(
                Circle()
                    .fill(color2)
                    .frame(width: 140, height: 140, alignment: .center)
                    .overlay(
                        Circle()
                            .fill(color3)
                            .frame(width: 120, height: 120, alignment: .center)
                            .overlay(
                                Circle()
                                    .fill(color4)
                                    .frame(width: 105, height: 105, alignment: .center)
                                .overlay(
                                    Text(buttonState)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                        )
                )
        ).shadow(color: .gray, radius: 1, x: 0, y: 1)
    }
}

struct CircleButton_Previews: PreviewProvider {
    static var previews: some View {
        CircleButton(buttonState: "test")
    }
}
