# Pods/ is intentionally not committed and may be absent locally.
# Run `make install` to fetch dependencies before the first build.

# Simulator used by `make unit-tests`, validated by `make precheck`, and read
# back by fastlane (app/fastlane/Fastfile). Single source of truth — Issue #80.
# Xcode を更新して機種が消えたら、この1行だけを直す。
#
# 注意: precheck は Makefile を「テキストとして」読んでこの代入を解決するため、
# `make unit-tests SIMULATOR="iPhone SE (3rd generation)"` のようなコマンドライン
# 上書きは precheck からは見えない (precheck は下の既定値を検証したまま通る)。
# 別機種で回す時は、この行そのものを書き換えること。
SIMULATOR ?= iPhone 17

install:
	pod install
update:
	pod update

unit-tests:
	@/usr/bin/time xcodebuild \
	-workspace 'LeafTimer.xcworkspace' \
	-scheme "LeafTimer" \
	-destination "platform=iOS Simulator,name=$(SIMULATOR),OS=latest" \
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

tests: precheck localization-check sort lint unit-tests

beta:
	@/usr/bin/time fastlane beta

gitignore-check:
	@echo "Running gitignore-doctor..."
	@ruby bin/test_gitignore_doctor.rb
	@ruby bin/gitignore-doctor.rb

localization-check:
	@echo "Running localization-check..."
	@ruby bin/test_localization_check.rb
	@ruby bin/localization-check.rb
