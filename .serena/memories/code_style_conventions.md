# LeafTimer Code Style & Conventions

## Swift Coding Conventions

### Naming Conventions
- **Classes/Structs**: PascalCase (e.g., `TimerViewModel`, `AppDelegate`)
- **Variables/Functions**: camelCase (e.g., `fullTimeSecond`, `didTapTimerButton`)
- **Constants**: camelCase (e.g., `backgroundTaskID`)
- **Files**: PascalCase matching main type (e.g., `TimerView.swift`)

### Code Organization
Uses MARK comments for code section organization:
```swift
// MARK: - Dependency Injection
// MARK: - State
// MARK: - View
// MARK: - Private methods
// MARK: - Initialization
// MARK: - methods
```

### SwiftUI Patterns
- **Views**: Structs conforming to `View` protocol
- **State Management**: `@ObservedObject` for ViewModels, `@Published` for reactive properties
- **Property Wrappers**: Extensive use of `@ObservedObject`, `@Published`, `@State`
- **Styling**: Inline styling with method chaining

### Architecture Patterns
- **MVVM**: Clear separation between View, ViewModel, and Model/Components
- **Dependency Injection**: Constructor injection pattern in ViewModels
- **Protocol-Oriented**: Uses protocols for manager interfaces

### File Organization
- **Extensions**: Separate files for extensions (e.g., `TimerViewModel+extensions.swift`)
- **Grouping**: Related functionality grouped in directories
- **Single Responsibility**: Each file focuses on one main type

### Code Style Characteristics
- **Indentation**: Standard Swift formatting
- **Line Length**: Reasonable line breaks, especially in SwiftUI view builders
- **Comments**: Primarily Japanese comments for business logic explanation
- **Error Handling**: Uses do-catch blocks and print statements for debugging

### SwiftUI Specific Patterns
- **View Composition**: Breaking down complex views into smaller components
- **State Binding**: Proper use of two-way data binding
- **Navigation**: NavigationView with NavigationLink patterns
- **Lifecycle**: `.onAppear()` for view initialization

### Testing Conventions
- **Framework**: Quick & Nimble for BDD-style testing
- **Structure**: Separate test targets for unit and UI tests
- **Naming**: Test files match source file names with "Tests" suffix