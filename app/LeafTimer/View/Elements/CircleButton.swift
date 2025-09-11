//
//  CircleButton.swift
//  LeafTimer
//
//  Created by Ema Shinya on 2020/07/26.
//  Copyright © 2020 Ema Shinya. All rights reserved.
//

import SwiftUI

struct CircleButton: View {
    @ObservedObject var viewModel: TimerViewModel

    var body: some View {
        Circle()
            .fill(viewModel.getColor1())
            .frame(width: 150, height: 150, alignment: .center)
            .overlay(
                Circle()
                    .fill(viewModel.getColor2())
                    .frame(width: 140, height: 140, alignment: .center)
                    .overlay(
                        Circle()
                            .fill(viewModel.getColor3())
                            .frame(width: 120, height: 120, alignment: .center)
                            .overlay(
                                Circle()
                                    .fill(viewModel.getColor4())
                                    .frame(width: 105, height: 105, alignment: .center)
                                    .overlay(
                                        Text(viewModel.getButtonState())
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
        CircleButton(viewModel: TimerViewModel(
            timerManager: DefaultTimerManager(),
            audioManager: DefaultAudioManager(),
            userDefaultWrapper: LocalUserDefaultsWrapper()
        ))
    }
}
