# Pods/ is intentionally not committed and may be absent locally.
# Run `make install` to fetch dependencies before the first build.
install:
	pod install
update:
	pod update

unit-tests:
	@/usr/bin/time xcodebuild \
	-workspace 'LeafTimer.xcworkspace' \
	-scheme "LeafTimer" \
	-destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
	build test

precheck:
	@echo "Running xcode-precheck..."
	@ruby bin/test_xcode_precheck.rb
	@ruby bin/xcode-precheck.rb

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

tests: precheck sort lint unit-tests

beta:
	@/usr/bin/time fastlane beta
