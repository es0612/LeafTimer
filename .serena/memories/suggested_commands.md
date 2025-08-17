# LeafTimer Suggested Commands

## Essential Development Commands

### Setup & Dependencies
```bash
cd app/
make install          # Install CocoaPods dependencies
make update           # Update dependencies
```

### Testing & Quality
```bash
make tests            # Complete test suite (sort + unit tests) - RUN THIS AFTER EVERY TASK
make unit-tests       # Unit tests only
make sort             # Sort Xcode project file
```

### Deployment
```bash
make beta             # Deploy to TestFlight (full pipeline)
fastlane unittests    # Run tests with fastlane
fastlane beta         # Alternative beta deployment
```

### Direct Xcode Commands
```bash
# Manual test execution
xcodebuild -workspace 'LeafTimer.xcworkspace' -scheme "LeafTimer" -destination "platform=iOS Simulator,name=iPhone 11,OS=latest" build test

# Build only
xcodebuild -workspace 'LeafTimer.xcworkspace' -scheme "LeafTimer" -destination "platform=iOS Simulator,name=iPhone 11,OS=latest" build
```

### System Commands (Darwin/macOS specific)
```bash
ls                    # List files
find . -name "*.swift" # Find Swift files
grep -r "pattern" .   # Search in files
cd path/              # Change directory
git status            # Git status
git add .             # Stage files
git commit -m "msg"   # Commit changes
```

## Critical Workflow Commands

### After Every Development Task:
1. `cd app/`
2. `make tests` (This is mandatory - includes sorting and testing)
3. Verify all tests pass before considering task complete

### For New Features:
1. Follow MVVM pattern
2. Add appropriate tests
3. Run `make tests`
4. Consider `make beta` for deployment when ready

## File Navigation
- Main source: `app/LeafTimer/`
- Tests: `app/LeafTimerTests/`
- Project config: `app/LeafTimer.xcodeproj/`
- Dependencies: `app/Podfile`