# LeafTimer Development Commands

## CocoaPods Management
- `make install` or `pod install` - Install dependencies
- `make update` or `pod update` - Update dependencies

## Testing
- `make tests` - Run complete test suite (includes sorting + unit tests)
- `make unit-tests` - Run unit tests only
- Direct xcodebuild: `xcodebuild -workspace 'LeafTimer.xcworkspace' -scheme "LeafTimer" -destination "platform=iOS Simulator,name=iPhone 11,OS=latest" build test`

## Project Maintenance
- `make sort` - Sort Xcode project file using Perl script
- Perl script location: `./bin/sortXcodeProject`

## Deployment
- `make beta` or `fastlane beta` - Deploy to TestFlight
- Fastlane lanes available:
  - `fastlane unittests` - Run tests with iPhone 12 simulator
  - `fastlane beta` - Full deployment pipeline (test + build + upload)

## Build Commands
The fastlane beta process includes:
1. Run unit tests
2. Increment build number
3. Commit version bump
4. Push to git remote
5. Build app with Release scheme
6. Upload to TestFlight

## System Requirements
- macOS (Darwin system)
- Xcode with iOS 13.5+ support
- CocoaPods installed
- Ruby with bundler for fastlane
- Git for version control

## Working Directory
All commands should be run from the `app/` directory where the Makefile and Podfile are located.