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

# Issue #95: coverage は常に計測する。RESULT_BUNDLE を渡した時だけ .xcresult を書き出す
# (CI が xccov で summary を作る)。xcodebuild は既存の bundle があると失敗するので事前に消す。
#   make unit-tests RESULT_BUNDLE=$(PWD)/build/TestResults.xcresult
RESULT_BUNDLE ?=

unit-tests:
	@if [ -n "$(RESULT_BUNDLE)" ]; then rm -rf "$(RESULT_BUNDLE)"; fi
	@/usr/bin/time xcodebuild \
	-workspace 'LeafTimer.xcworkspace' \
	-scheme "LeafTimer" \
	-destination "platform=iOS Simulator,name=$(SIMULATOR),OS=latest" \
	-enableCodeCoverage YES \
	$(if $(RESULT_BUNDLE),-resultBundlePath '$(RESULT_BUNDLE)') \
	build test

precheck:
	@echo "Running xcode-precheck..."
	@ruby bin/test_xcode_precheck.rb
	@ruby bin/xcode-precheck.rb

sort:
	@perl ./bin/sortXcodeProject "LeafTimer.xcodeproj/project.pbxproj"

# 新規 Swift ファイルの pbxproj 配線 (Issue #130)。TARGET は取り違え事故防止のため必須。
#   make add-file FILE=LeafTimer/Components/Foo.swift TARGET=app
#   make add-file FILE=LeafTimerTests/FooTests.swift TARGET=test
add-file:
	@test -n "$(FILE)" && test -n "$(TARGET)" || { \
		echo "usage: make add-file FILE=<project-relative path> TARGET=app|test"; exit 1; }
	@test -f "$(FILE)" || { echo "error: file not found: $(FILE)"; exit 1; }
	@case "$(TARGET)" in \
		app)  XCTARGET=LeafTimer ;; \
		test) XCTARGET=LeafTimerTests ;; \
		*) echo "error: TARGET must be 'app' or 'test' (got '$(TARGET)')"; exit 1 ;; \
	esac; \
	ruby bin/test_add_to_target.rb && \
	ruby bin/add-to-target.rb LeafTimer.xcodeproj "$(FILE)" "$$XCTARGET" "$$(dirname "$(FILE)")"
	@$(MAKE) sort
	@$(MAKE) precheck

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

tests: precheck localization-check dynamic-type-check sort lint unit-tests

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

dynamic-type-check:
	@echo "Running dynamic-type-check..."
	@ruby bin/test_dynamic_type_check.rb
	@ruby bin/dynamic-type-check.rb
