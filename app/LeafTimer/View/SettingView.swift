//
//  SettingView.swift
//  LeafTimer
//
//  Created by Ema Shinya on 2020/07/26.
//  Copyright © 2020 Ema Shinya. All rights reserved.
//

import SwiftUI

struct SettingView: View {
    // MARK: - State
    @ObservedObject var settingViewModel: SettingViewModel

    let products = ["Mac", "iPod", "touch", "iPhone", "TV", "Watch"]

    var body: some View {
        NavigationView{
            Form{

//                Section(header: Text("タイマー")){
//                    Picker("test", selection: settingViewModel.workingSound) {
//                        ForEach(0..<6) {
//                           Text(self.products[$0]).tag($0)
//                        }
//                    }
//                }

                Section(header: Text("サウンド")){
                    Text("test")
                    Toggle("バイブレーション", isOn: Binding(
                        get: { self.settingViewModel.vibrationIsOn },
                        set: { self.settingViewModel.vibrationIsOn = $0 }
                    )
                    )
                }

                Section(header: Text("モード")){
                    Text("ポモドーロ")
                }


            }
            .navigationBarTitle(
                "設定",displayMode: .inline
            )
            
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView(settingViewModel: SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper()))
    }
}
