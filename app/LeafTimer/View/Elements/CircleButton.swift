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

    /// Issue #70: 入れ子の円の直径比。元は 140/150・120/150・105/150 のリテラル
    /// 重複で、105/150 は 2 箇所に散っていた。デザイン変更時の取りこぼしを防ぐため集約。
    static let innerRatios: (second: CGFloat, third: CGFloat, inner: CGFloat) = (
        second: 140.0 / 150.0,
        third: 120.0 / 150.0,
        inner: 105.0 / 150.0
    )

    /// 最内円のテキスト幅は最内円直径の 95%。
    private static let innerTextWidthRatio: CGFloat = 0.95

    static func resolvedDiameter(scaled: CGFloat) -> CGFloat {
        min(scaled, maxDiameter)
    }

    var body: some View {
        let outer = Self.resolvedDiameter(scaled: scaledDiameter)
        let second = outer * Self.innerRatios.second
        let third = outer * Self.innerRatios.third
        let inner = outer * Self.innerRatios.inner
        Circle()
            .fill(viewModel.getColor1())
            .frame(width: outer, height: outer, alignment: .center)
            .overlay(
                Circle()
                    .fill(viewModel.getColor2())
                    .frame(width: second, height: second, alignment: .center)
                    .overlay(
                        Circle()
                            .fill(viewModel.getColor3())
                            .frame(width: third, height: third, alignment: .center)
                            .overlay(
                                Circle()
                                    .fill(viewModel.getColor4())
                                    .frame(width: inner, height: inner, alignment: .center)
                                    .overlay(
                                        Text(viewModel.getButtonState())
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                            .frame(width: inner * Self.innerTextWidthRatio)
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
