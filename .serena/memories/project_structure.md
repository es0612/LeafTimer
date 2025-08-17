# LeafTimer Project Structure

## Root Level
- `README.md` - Basic project description in Japanese
- `CLAUDE.md` - Claude Code development instructions and workflow
- `app/` - Main iOS application directory

## App Directory (`app/`)
- `Makefile` - Development commands and shortcuts
- `Podfile` & `Podfile.lock` - CocoaPods dependencies
- `Gemfile` - Ruby gems (fastlane)
- `LeafTimer.xcodeproj/` - Xcode project files
- `LeafTimer/` - Main source code
- `LeafTimerTests/` - Unit tests
- `LeafTimerUITests/` - UI tests
- `fastlane/` - Deployment automation
- `bin/` - Build scripts

## Source Code Structure (`app/LeafTimer/`)
- `App/` - Application lifecycle and main entry point
  - `AppDelegate.swift` - App delegate with Firebase/AdMob setup
  - `Assets.xcassets/` - Images and assets
  - `Base.lproj/` & `ja.lproj/` - Localization files
- `View/` - SwiftUI views and UI components
  - `TimerView.swift` - Main timer interface
  - `SettingView.swift` - Settings screen
  - `AdsView.swift` - Advertisement integration
  - `Elements/` - Reusable UI components
- `ViewModel/` - MVVM view models
  - `TimerViewModel.swift` - Timer logic and state
  - `SettingViewModel.swift` - Settings management
- `Components/` - Business logic and utilities
  - Manager classes (Timer, Audio, UserDefaults)
  - Data persistence utilities
- `Sound/` - Audio assets for timer notifications

## Architecture Pattern
Follows MVVM (Model-View-ViewModel) with:
- Views: SwiftUI components
- ViewModels: ObservableObject classes managing state
- Components: Business logic and data management