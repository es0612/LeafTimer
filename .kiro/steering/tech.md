# Technology Stack

## Architecture
- **Pattern**: MVVM (Model-View-ViewModel) アーキテクチャ
- **UI Framework**: SwiftUI（宣言的UI）
- **Dependency Injection**: プロトコルベースの依存性注入
- **State Management**: ObservableObject + @Published プロパティによるリアクティブ状態管理
- **Testing Architecture**: Protocol-based mocking for unit testing

## Frontend Technology
- **Language**: Swift 5+
- **UI Framework**: SwiftUI
- **Target Platform**: iOS 13.5以降
- **Layout**: PureLayout（AutoLayoutヘルパー）
- **Animation**: SwiftUIネイティブアニメーション + GIFアニメーション
- **Device Support**: iPhone（縦向きのみ）、iPad（全方向対応）

## Backend/Services
- **Analytics**: Firebase Analytics
- **Monetization**: Firebase AdMob + Google Mobile Ads SDK
- **Local Storage**: UserDefaults（設定データ、日別カウント）
- **Audio Management**: AVFoundation
- **Background Processing**: Timer + Background audio capabilities

## Development Environment

### Required Tools
- **Xcode**: 12.0以降（iOS 13.5サポートのため）
- **CocoaPods**: 依存関係管理
- **fastlane**: CI/CD自動化
- **Make**: コマンド簡素化
- **Git**: バージョン管理

### Dependencies (Podfile)
```ruby
platform :ios, '13.5'
use_frameworks!

# Main App Dependencies
pod 'PureLayout'                # AutoLayoutヘルパー
pod 'Firebase/Analytics'        # 利用分析
pod 'Firebase/AdMob'           # 広告配信
pod 'Google-Mobile-Ads-SDK'    # 広告SDK

# Testing Dependencies
pod 'Quick'                    # BDD testing framework
pod 'Nimble'                   # Matcher library
pod 'ViewInspector'            # SwiftUI testing
```

## Common Commands

### Dependency Management
```bash
# CocoaPods installation/update
make install    # pod install
make update     # pod update
```

### Testing
```bash
# Unit tests (via Makefile)
make unit-tests # xcodebuild test

# Testing with fastlane
fastlane unittests

# Full test suite
make tests      # sort + unit-tests
```

### Build & Deploy
```bash
# Beta deployment
make beta       # fastlane beta
fastlane beta   # increment build → test → build → TestFlight

# Project file sorting
make sort       # Xcode project file organization
```

## Environment Variables

### Build Configuration
- `DEVELOPMENT_LANGUAGE`: プロジェクト言語設定
- `PRODUCT_BUNDLE_IDENTIFIER`: アプリケーションID
- `MARKETING_VERSION`: マーケティングバージョン

### Firebase Configuration
- `GADApplicationIdentifier`: AdMob アプリケーションID
- SKAdNetwork設定（iOS 14.5+ ATT対応）

## Port Configuration
N/A（iOSアプリのためサーバーポート設定なし）

## Build Settings

### iOS Deployment Target
- **Minimum iOS Version**: 13.5
- **Device Family**: iPhone, iPad
- **Orientation**: Portrait (iPhone), All (iPad)

### Background Capabilities
- **Audio Background Mode**: バックグラウンドでのタイマー音再生
- **Idle Timer**: 作業中の画面自動ロック無効化

### Security & Privacy
- **SKAdNetwork**: iOS 14.5以降のプライバシー対応
- **AdMob Integration**: GDPR/CCPA準拠の広告配信

## Testing Strategy

### Unit Testing
- **Framework**: Quick + Nimble (BDD style)
- **Mocking**: Protocol-based test doubles (SpyAudioManager, SpyTimerManager)
- **Coverage**: ViewModel layer + Component layer

### UI Testing
- **Framework**: XCUITest + Quick/Nimble
- **Target**: Core user flows and timer functionality

### Testing Devices
- **Primary**: iPhone 11 (simulator)
- **Secondary**: iPhone 12 (fastlane)

## CI/CD Pipeline (fastlane)

### Lanes
1. **unittests**: 単体テスト実行
2. **beta**: 包括的なビルド・デプロイ
   - Unit tests → Build number increment → Git commit/push → App build → TestFlight upload

### Integration
- **Version Control**: 自動バージョン増加 + Git tag
- **Distribution**: TestFlight自動アップロード
- **Build Processing**: Skip waiting for App Store Connect processing