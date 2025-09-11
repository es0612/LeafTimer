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

lint:
	@echo "Running SwiftLint..."
	@swiftlint lint

lint-strict:
	@echo "Running SwiftLint in strict mode..."
	@swiftlint lint --strict

lint-fix:
	@echo "Running SwiftLint with auto-correct..."
	@swiftlint lint --fix

format:
	@echo "Running SwiftFormat..."
	@swiftformat .

format-check:
	@echo "Checking SwiftFormat..."
	@swiftformat --lint .

quality: lint format-check
	@echo "Code quality checks completed"

tests: sort lint unit-tests

beta:
	@/usr/bin/time fastlane beta
