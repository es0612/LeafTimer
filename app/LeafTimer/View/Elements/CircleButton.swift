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

    /// Issue #64: AX5 で文言が「S…」に省略される対策。文字だけでなく円ごと
    /// Dynamic Type に追従させる (#58 のタイマー数字と同じ ScaledMetric + 上限方式)。
    @ScaledMetric(relativeTo: .title) private var scaledDiameter: CGFloat = 150

    static let maxDiameter: CGFloat = 210

    static func resolvedDiameter(scaled: CGFloat) -> CGFloat {
        min(scaled, maxDiameter)
    }

    var body: some View {
        let outer = Self.resolvedDiameter(scaled: scaledDiameter)
        Circle()
            .fill(viewModel.getColor1())
            .frame(width: outer, height: outer, alignment: .center)
            .overlay(
                Circle()
                    .fill(viewModel.getColor2())
                    .frame(width: outer * 140 / 150, height: outer * 140 / 150, alignment: .center)
                    .overlay(
                        Circle()
                            .fill(viewModel.getColor3())
                            .frame(width: outer * 120 / 150, height: outer * 120 / 150, alignment: .center)
                            .overlay(
                                Circle()
                                    .fill(viewModel.getColor4())
                                    .frame(width: outer * 105 / 150, height: outer * 105 / 150, alignment: .center)
                                    .overlay(
                                        Text(viewModel.getButtonState())
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                            .frame(width: outer * 105 / 150 * 0.95)
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
            userDefaultWrapper: LocalUserDefaultsWrapper(),
            sessionStatsRepository: LocalSessionStatsRepository()
        ))
    }
}
