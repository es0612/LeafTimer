# Project Structure

## Root Directory Organization

```
LeafTimer/
├── .kiro/                     # Spec-driven development files
│   └── steering/              # Project steering documents
├── CLAUDE.md                  # Claude Code configuration
├── README.md                  # Project documentation
└── app/                       # Main iOS application
    ├── Gemfile                # Ruby dependencies (fastlane)
    ├── Makefile               # Common development commands
    ├── Podfile                # CocoaPods dependencies
    ├── Podfile.lock           # Locked dependency versions
    ├── LeafTimer.xcodeproj/   # Xcode project configuration
    ├── LeafTimer.xcworkspace/ # CocoaPods workspace
    ├── LeafTimer/             # Main app source code
    ├── LeafTimerTests/        # Unit tests
    ├── LeafTimerUITests/      # UI tests
    ├── bin/                   # Development scripts
    └── fastlane/              # CI/CD configuration
```

## Subdirectory Structures

### Main App (`app/LeafTimer/`)
```
LeafTimer/
├── App/                       # Application lifecycle
│   ├── AppDelegate.swift      # App delegate
│   ├── Assets.xcassets/       # Image and sound assets
│   └── Base.lproj/           # Localization (English base)
├── Components/               # Reusable business logic
│   ├── DateManager.swift     # Date utility functions
│   ├── DefaultAudioManager.swift     # Audio playback implementation
│   ├── DefaultTimerManager.swift     # Timer implementation
│   ├── KeyManager.swift      # UserDefaults key management
│   ├── LocalUserDefaultWrapper.swift # UserDefaults wrapper
│   └── UserDefaultItem.swift # UserDefaults data models
├── Info.plist               # App configuration
├── Sound/                   # Audio asset files
├── View/                    # SwiftUI views
│   ├── AdsView.swift        # Advertisement display
│   ├── Binding+extension.swift # SwiftUI binding extensions
│   ├── Elements/            # Reusable UI components
│   ├── SettingView.swift    # Settings screen
│   └── TimerView.swift      # Main timer screen
└── ViewModel/               # MVVM view models
    ├── SettingViewModel.swift       # Settings logic
    ├── TimerViewModel.swift         # Timer logic
    └── TimerViewModel+extensions.swift # Timer extensions
```

### Testing Structure
```
LeafTimerTests/
├── Info.plist              # Test bundle configuration
├── SpyAudioManager.swift   # Audio manager test double
├── SpyTimerManager.swift   # Timer manager test double
└── TimerViewSpec.swift     # Timer functionality tests

LeafTimerUITests/
├── Info.plist              # UI test configuration
└── LeafTimerUITests.swift  # End-to-end UI tests
```

## Code Organization Patterns

### MVVM Architecture
```
View (SwiftUI) ↔ ViewModel (ObservableObject) ↔ Model/Components
```

### Dependency Injection Pattern
- **Protocols**: `TimerManager`, `AudioManager`, `UserDefaultsWrapper`
- **Implementations**: `DefaultTimerManager`, `DefaultAudioManager`, `LocalUserDefaultWrapper`
- **Test Doubles**: `SpyTimerManager`, `SpyAudioManager`

### Component Responsibilities
- **Components/**: Business logic, data management, external integrations
- **View/**: UI presentation, user interaction handling
- **ViewModel/**: State management, business logic coordination
- **Elements/**: Reusable UI components

## File Naming Conventions

### Swift Files
- **Views**: `[Feature]View.swift` (e.g., `TimerView.swift`)
- **ViewModels**: `[Feature]ViewModel.swift` (e.g., `TimerViewModel.swift`)
- **Components**: `[Purpose][Type].swift` (e.g., `DefaultAudioManager.swift`)
- **Protocols**: `[Capability]Manager.swift` (e.g., `TimerManager.swift`)
- **Extensions**: `[Type]+[extension].swift` (e.g., `Binding+extension.swift`)
- **Test Doubles**: `Spy[Protocol].swift` (e.g., `SpyAudioManager.swift`)
- **Tests**: `[Feature]Spec.swift` (e.g., `TimerViewSpec.swift`)

### Asset Files
- **Images**: descriptive names (`splashIcon`, `settingIcon`, `reloadIcon`)
- **Sounds**: `[type][number].mp3` (e.g., `rain1.mp3`, `river1.mp3`)
- **GIFs**: `[theme][number].gif` (e.g., `leaf1.gif`, `leaf2.gif`)

### Configuration Files
- **Xcode**: `LeafTimer.xcodeproj`, `LeafTimer.xcworkspace`
- **CocoaPods**: `Podfile`, `Podfile.lock`
- **fastlane**: `Fastfile`, `Appfile`

## Import Organization

### Import Order (Swift)
1. **System frameworks**: `Foundation`, `UIKit`, `SwiftUI`
2. **Third-party libraries**: CocoaPods dependencies
3. **Local modules**: Project-specific imports

### Import Examples
```swift
// TimerViewModel.swift
import Foundation
import UIKit

// View files with SwiftUI
import SwiftUI
```

## Key Architectural Principles

### 1. Separation of Concerns
- **Views**: Only UI and user interaction
- **ViewModels**: State management and business logic coordination
- **Components**: Specific business capabilities (timer, audio, storage)

### 2. Protocol-Oriented Programming
- All external dependencies defined as protocols
- Concrete implementations for production
- Test doubles for unit testing

### 3. Reactive State Management
- `@Published` properties for observable state
- `ObservableObject` ViewModels
- SwiftUI automatic UI updates

### 4. Dependency Injection
- Constructor injection for all dependencies
- No static dependencies or singletons
- Easy mocking for testing

### 5. Single Responsibility
- Each file has one clear purpose
- Components handle one specific capability
- ViewModels manage one feature area

### 6. Testability
- Protocol-based architecture enables mocking
- Separation allows isolated unit testing
- Test files mirror production structure

## Configuration Management

### UserDefaults Keys
- Centralized in `UserDefaultItem.swift`
- Enum-based key management
- Type-safe value handling

### Asset Management
- Centralized in `Assets.xcassets`
- Organized by type (images, sounds, data)
- Localization support structure

### Build Configuration
- `Info.plist` for app metadata
- Xcode project settings for build configuration
- fastlane for deployment automation

## Code Style Guidelines

### Swift Style
- **Variables**: camelCase (`currentTimeSecond`)
- **Functions**: camelCase (`onPressedTimerButton()`)
- **Types**: PascalCase (`TimerViewModel`)
- **Constants**: camelCase with meaningful names
- **Protocols**: [Capability] + Manager pattern

### Documentation
- MARK comments for organizing code sections
- Descriptive variable and function names
- Protocol documentation for public interfaces

### Error Handling
- Optional unwrapping for safe operations
- Protocol-based error propagation
- Graceful degradation for non-critical features