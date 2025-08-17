# Task Completion Workflow for LeafTimer

## When a Development Task is Completed

### 1. Code Quality Checks
Since there are no specific linting or formatting commands in the Makefile, ensure code follows the established Swift/SwiftUI conventions:
- Check MARK comment organization
- Verify naming conventions (camelCase for variables, PascalCase for types)
- Ensure proper SwiftUI property wrapper usage
- Follow MVVM architecture patterns

### 2. Testing Requirements
**Always run tests before considering a task complete:**
```bash
cd app/
make tests
```
This command will:
- Sort the Xcode project file
- Run unit tests on iPhone 11 simulator
- Ensure all tests pass

### 3. Project File Maintenance
The `make sort` command is automatically included in `make tests`, but can be run separately:
```bash
make sort
```
This ensures the Xcode project file remains properly organized.

### 4. Dependency Management
If dependencies were modified:
```bash
make install  # or pod install
```

### 5. Build Verification
For significant changes, verify the app builds successfully:
```bash
# This is included in the test process, but can be run via:
xcodebuild -workspace 'LeafTimer.xcworkspace' -scheme "LeafTimer" -destination "platform=iOS Simulator,name=iPhone 11,OS=latest" build
```

### 6. Version Control
Standard git workflow:
- Commit changes with descriptive messages
- Follow established commit message patterns
- Do not commit unless explicitly requested

### 7. Deployment (When Ready)
For beta releases:
```bash
make beta  # or fastlane beta
```
This handles the complete deployment pipeline automatically.

## Important Notes
- Always work from the `app/` directory
- Test on iOS Simulator (iPhone 11 is the default)
- The project uses CocoaPods, so work with `.xcworkspace` files
- Japanese comments are acceptable and common in this codebase
- Follow the MVVM architecture pattern established in the project