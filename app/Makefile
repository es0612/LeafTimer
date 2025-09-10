install:
	pod install
update:
	pod update

unit-tests:
	@/usr/bin/time xcodebuild \
	-workspace 'LeafTimer.xcworkspace' \
	-scheme "LeafTimer" \
	-destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
	build test

sort:
	@perl ./bin/sortXcodeProject "LeafTimer.xcodeproj/project.pbxproj"

tests: sort unit-tests

beta:
	@/usr/bin/time fastlane beta
