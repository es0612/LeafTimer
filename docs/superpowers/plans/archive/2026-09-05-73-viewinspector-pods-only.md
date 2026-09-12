# #73 ViewInspector の CocoaPods / SPM 二重管理を CocoaPods に一本化する — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** テストターゲット `LeafTimerTests` にリンクされている ViewInspector を CocoaPods (Podfile の `pod 'ViewInspector'`、Podfile.lock 0.10.2) だけにし、pbxproj の SPM 参照 (`XCRemoteSwiftPackageReference` / `XCSwiftPackageProductDependency` / `ViewInspector in Frameworks`) と 2 つの `Package.resolved` を除去する。pbxproj の変更は手編集せず xcodeproj gem の one-off で行い、受け入れは文字列 grep でなく構造検査 + `bundle exec pod install && make sort` 2 回の安定性で行う (CLAUDE.md ルール 28)。

**Architecture:** (1) pbxproj の dangling UUID / orphan `TargetAttributes` を検出する再利用可能なチェッカー `pbxproj-structure-check` を `app/bin/` の 3 層構成で追加し `make precheck` に組み込む (ルール 40: 機械的かつプロジェクト固有 → repo 内スクリプト + make ターゲット)。(2) その後に one-off の xcodeproj gem スクリプトで SPM 参照 3 オブジェクト (PBXBuildFile / XCSwiftPackageProductDependency / XCRemoteSwiftPackageReference) を除去し、tracked な `Package.resolved` はユーザーの `git rm` で消す。(3) 検証は fresh な `-derivedDataPath` で `xcodebuild test` を回し、SPM checkout が生成されず Pods 版 `ViewInspector.framework` だけが Products に出ることを実測する (既定の DerivedData には SPM checkout の残骸があり、stale なビルド成果物がリンク切れを隠すため)。

**Tech Stack:** Ruby 3.4.4 (`app/.ruby-version`) / xcodeproj gem 1.28.1 (cocoapods の依存として `bundle install` 済み) / minitest / CocoaPods 1.16.2 (`bundle exec pod`) / xcodebuild

**Spec:** issue #73 本文 (方針: Firebase/AdMob が Pods 前提なので CocoaPods 側へ一本化) + 2026-09-05 セッションでの決定:
- `.gitignore` の Package.resolved whitelist ladder (#31) と `bin/gitignore-doctor-expectations.txt` の `keep:` 期待値は**残す** (対象ファイルが無くても `check-ignore --no-index` は動き害がない。将来 SPM を足した時の #31 再発防止の保険)
- brainstorming は省略 (設計は issue に明記、2026-09-05 に事実確認済み)

**2026-09-05 に確認した事実:**
- pbxproj の SPM 参照は 6 箇所: L36 (PBXBuildFile `ViewInspector in Frameworks`、`productRef`)、L227 (LeafTimerTests の Frameworks phase)、L479-481 (`packageProductDependencies`)、L515-517 (`packageReferences`)、L1031-1040 (`XCRemoteSwiftPackageReference`、`minimumVersion = 0.4.0` upToNextMajor)、L1042-1048 (`XCSwiftPackageProductDependency`)
- テストターゲットは `Pods_LeafTimerTests.framework` (L226) と SPM (L227) の二重リンク
- `Package.resolved` は 2 つ: `app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved` (tracked、0.10.3) と `app/LeafTimer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (untracked・gitignore 済み、0.10.2)
- 既定の DerivedData (`~/Library/Developer/Xcode/DerivedData/LeafTimer-*/`) には `SourcePackages/checkouts/ViewInspector` と Pods 版 `Build/Products/Debug-iphonesimulator/ViewInspector/` の**両方**が存在する
- `import ViewInspector` するテストファイルは 5 つ
- one-off 除去スクリプトと構造検査スクリプトは scratchpad のコピーで dry-run 済み: 除去は上記 6 箇所のみの削除で他の再シリアライズなし (objects 232 → 229)、構造検査は GREEN/GREEN/注入 dangling で RED を実証

## Global Constraints

- pbxproj は**手編集禁止**。変更は Task 2 の one-off スクリプト (`Xcodeproj::Project#save`) と `bundle exec pod install` / `make sort` だけが行う。
- 受け入れは grep でなく構造検査 (`make pbxproj-structure-check`: 参照 UUID ⊆ 定義 UUID、`TargetAttributes.keys ⊆ targets.uuid`) と「`bundle exec pod install && make sort` を 2 回回して pbxproj が安定」で行う (ルール 28)。
- `git rm` / `rm` はユーザー turn (ルール 14): `app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved` (tracked) は `! git rm`、`app/LeafTimer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (untracked) は `! rm`。subagent は削除しない。
- CocoaPods は常に `bundle exec pod …` (ルール 26)。`app/` 配下では Ruby 3.4.4 が自動で有効。
- ビルド/テスト系コマンドは `cd /Users/shinya/workspace/claude/LeafTimer/app &&` を前置し、Bash timeout 600000。成否は `** TEST SUCCEEDED **` の存在 + `** TEST FAILED **` / `Error 6x` の不在で判定 (ルール 1)。`Mach error -308` / `Lost connection to testmanagerd` は Simulator 再起動して 1 回リトライ。
- Simulator は `app/Makefile` の `SIMULATOR ?= iPhone 17` を使う。
- `.gitignore` / `gitignore-doctor-expectations.txt` / CLAUDE.md ルール 29 は変更しない (ユーザー決定)。
- Makefile のレシピ行は TAB インデント。新規 `.rb` は `app/bin/` の 3 層 (`foo_bar.rb` 純粋 / `test_foo_bar.rb` minitest / `foo-bar.rb` CLI)。
- plan に merge ステップを含めない (PR 作成まで)。

---

## 想定済みの分岐 (Task 2 Step 5 が失敗した時)

Pods は 0.10.2、SPM は 0.10.3 で解決されており、これまでコンパイラがどちらのモジュールを拾っていたかは不明。Step 5 でテストのコンパイルエラー (ViewInspector API 差分) が出た場合の ruling: `cd app && bundle exec pod update ViewInspector` で Pods 側を上げる (Podfile に制約なし、`COCOAPODS:` 行は変わらないので `cocoapods-lock-check` は green のまま)。`Podfile.lock` を Task 2 の commit に含める。それでも失敗するなら BLOCKED 報告。

## 事前条件 (コントローラが Task 2 dispatch 前に確認)

- [ ] `git ls-files app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved` が空 (ユーザーが `! git rm` 済み)
- [ ] `ls app/LeafTimer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` が `No such file` (ユーザーが `! rm` 済み)

---

### Task 1: `pbxproj-structure-check` — dangling UUID / orphan TargetAttributes 検出器

**Files:**
- Create: `app/bin/pbxproj_structure_check.rb` (純粋ロジック、I/O なし)
- Create: `app/bin/test_pbxproj_structure_check.rb` (minitest)
- Create: `app/bin/pbxproj-structure-check.rb` (CLI、xcodeproj gem を `rescue LoadError` でガード — ルール 27)
- Modify: `app/Makefile` — `pbxproj-structure-check` ターゲット追加、`precheck:` の末尾に組み込み

**Interfaces:**
- Produces: `PbxprojStructureCheck.referenced_uuids(pbxproj_text) -> Set<String>`、`PbxprojStructureCheck.report(defined_uuids:, referenced_uuids:, target_uuids:, target_attribute_keys:) -> { ok:, dangling: Array, orphan_target_attrs: Array }`。CLI は引数なしで `app/LeafTimer.xcodeproj` を検査し、1 引数で別パスも受ける。成功時 `✅ pbxproj-structure-check passed (N objects, 0 dangling, 0 orphan TargetAttributes)`、失敗時 stderr に `❌ pbxproj-structure-check failed: …` で exit 1。xcodeproj gem 不在時は `⚠️  pbxproj-structure-check skipped (xcodeproj gem not available)` で exit 0 (CI は `bundle exec make tests` なので gem は必ず見える — PR #146)。

- [ ] **Step 1: 失敗するテストを書く**

`app/bin/test_pbxproj_structure_check.rb`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Unit tests for the pure functions in pbxproj_structure_check.rb.
# Run: ruby bin/test_pbxproj_structure_check.rb
require 'minitest/autorun'
require 'set'
require_relative 'pbxproj_structure_check'

class PbxprojStructureCheckTest < Minitest::Test
  PBXPROJ = <<~PBX
    // !$*UTF8*$!
    {
    	objects = {
    		3857B9BA24A77C1B00B21CCD /* ViewInspector in Frameworks */ = {isa = PBXBuildFile; productRef = 3857B9B924A77C1B00B21CCD /* ViewInspector */; };
    		3857B9B624A7734300B21CCD /* App */ = {
    			isa = PBXGroup;
    			children = (
    				3857B9B424A7725000B21CCD /* Assets.xcassets */,
    			);
    		};
    	};
    	rootObject = 3857B9A824A7725000B21CCD /* Project object */;
    }
  PBX

  # --- referenced_uuids ---------------------------------------------------

  def test_referenced_uuids_collects_every_24_hex_token
    got = PbxprojStructureCheck.referenced_uuids(PBXPROJ)
    assert_equal Set['3857B9BA24A77C1B00B21CCD', '3857B9B924A77C1B00B21CCD',
                     '3857B9B624A7734300B21CCD', '3857B9B424A7725000B21CCD',
                     '3857B9A824A7725000B21CCD'], got
  end

  # 23 桁や小文字 hex は UUID ではない (SHA 等の誤検出を防ぐ)
  def test_referenced_uuids_ignores_non_uuid_hex
    text = "deadbeefdeadbeefdeadbeef 3857B9A824A7725000B21CC 3857B9A824A7725000B21CCDEF"
    assert_empty PbxprojStructureCheck.referenced_uuids(text)
  end

  # --- report -------------------------------------------------------------

  def test_report_ok_when_every_reference_is_defined
    r = PbxprojStructureCheck.report(
      defined_uuids: Set['A' * 24, 'B' * 24],
      referenced_uuids: Set['A' * 24, 'B' * 24],
      target_uuids: ['A' * 24],
      target_attribute_keys: ['A' * 24]
    )
    assert r[:ok]
    assert_empty r[:dangling]
    assert_empty r[:orphan_target_attrs]
  end

  def test_report_flags_dangling_reference
    r = PbxprojStructureCheck.report(
      defined_uuids: Set['A' * 24],
      referenced_uuids: Set['A' * 24, 'D' * 24],
      target_uuids: ['A' * 24],
      target_attribute_keys: []
    )
    refute r[:ok]
    assert_equal ['D' * 24], r[:dangling]
  end

  # PR #140 で実測: target.remove_from_project は TargetAttributes を連鎖削除しない
  def test_report_flags_orphan_target_attributes
    r = PbxprojStructureCheck.report(
      defined_uuids: Set['A' * 24, 'B' * 24],
      referenced_uuids: Set['A' * 24, 'B' * 24],
      target_uuids: ['A' * 24],
      target_attribute_keys: ['A' * 24, 'B' * 24]
    )
    refute r[:ok]
    assert_equal ['B' * 24], r[:orphan_target_attrs]
  end

  def test_report_results_are_sorted_for_stable_output
    r = PbxprojStructureCheck.report(
      defined_uuids: Set[],
      referenced_uuids: Set['F' * 24, 'C' * 24],
      target_uuids: [],
      target_attribute_keys: ['E' * 24, 'D' * 24]
    )
    assert_equal ['C' * 24, 'F' * 24], r[:dangling]
    assert_equal ['D' * 24, 'E' * 24], r[:orphan_target_attrs]
  end
end
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_pbxproj_structure_check.rb
```

Expected: `cannot load such file -- .../pbxproj_structure_check (LoadError)`。

- [ ] **Step 3: 純粋ロジックを実装する**

`app/bin/pbxproj_structure_check.rb`:

```ruby
# frozen_string_literal: true

require 'set'

# Pure helpers for pbxproj-structure-check (Issue #73, CLAUDE.md rule 28).
# Kept free of I/O so they can be unit-tested (see
# test_pbxproj_structure_check.rb). The CLI glue lives in
# bin/pbxproj-structure-check.rb.
#
# Why this exists: editing project.pbxproj through the xcodeproj gem (target
# removal, SPM reference removal) can leave two kinds of residue that a
# string grep for the removed name never sees (PR #140 measured both):
#   - a UUID referenced somewhere but no longer defined in `objects`
#   - a TargetAttributes entry keyed by a target UUID that no longer exists
module PbxprojStructureCheck
  # Xcode object UUIDs are exactly 24 upper-case hex digits.
  UUID = /\b([0-9A-F]{24})\b/.freeze

  # Every 24-hex token in the file, as a Set (definitions and references
  # alike — callers subtract the defined set to find dangling references).
  def self.referenced_uuids(pbxproj_text)
    pbxproj_text.scan(UUID).flatten.to_set
  end

  # { ok:, dangling: [uuid...], orphan_target_attrs: [uuid...] } — both
  # arrays sorted so output is stable across runs.
  def self.report(defined_uuids:, referenced_uuids:, target_uuids:, target_attribute_keys:)
    dangling = (referenced_uuids - defined_uuids).to_a.sort
    orphans  = (target_attribute_keys - target_uuids).sort
    { ok: dangling.empty? && orphans.empty?, dangling: dangling, orphan_target_attrs: orphans }
  end
end
```

- [ ] **Step 4: テストが通ることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby bin/test_pbxproj_structure_check.rb
```

Expected: `6 runs, ... 0 failures, 0 errors`。

- [ ] **Step 5: CLI を書く**

`app/bin/pbxproj-structure-check.rb`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# pbxproj-structure-check: verify project.pbxproj has no dangling UUID
# references and no orphan TargetAttributes (Issue #73, CLAUDE.md rule 28).
#
# Usage:
#   ruby bin/pbxproj-structure-check.rb                       # app/LeafTimer.xcodeproj
#   ruby bin/pbxproj-structure-check.rb <path/to/Foo.xcodeproj>
#
# Exit 0 = clean (or xcodeproj gem absent → skipped with a warning, rule 27);
# exit 1 = residue found or the project cannot be opened.

require 'set'
require_relative 'pbxproj_structure_check'

XCODEPROJ_AVAILABLE =
  begin
    require 'xcodeproj'
    true
  rescue LoadError
    false
  end

unless XCODEPROJ_AVAILABLE
  warn '⚠️  pbxproj-structure-check skipped (xcodeproj gem not available — run under `bundle exec`)'
  exit 0
end

PROJECT_DIR = File.expand_path('..', __dir__) # app/
path = ARGV[0] || File.join(PROJECT_DIR, 'LeafTimer.xcodeproj')

unless File.directory?(path)
  warn "❌ pbxproj-structure-check failed: #{path} が無い"
  exit 1
end

# Xcodeproj discards unknown UUIDs on open (with a warning on stderr), so the
# defined set comes from the parsed object graph while the referenced set is
# taken from the raw text — that asymmetry is what exposes dangling refs.
project = Xcodeproj::Project.open(path)
text    = File.read(File.join(path, 'project.pbxproj'))

report = PbxprojStructureCheck.report(
  defined_uuids: project.objects.map(&:uuid).to_set,
  referenced_uuids: PbxprojStructureCheck.referenced_uuids(text),
  target_uuids: project.targets.map(&:uuid),
  target_attribute_keys: (project.root_object.attributes['TargetAttributes'] || {}).keys
)

if report[:ok]
  puts "✅ pbxproj-structure-check passed (#{project.objects.size} objects, 0 dangling, 0 orphan TargetAttributes)"
  exit 0
end

warn "❌ pbxproj-structure-check failed: #{report[:dangling].size} dangling UUID(s), #{report[:orphan_target_attrs].size} orphan TargetAttributes"
report[:dangling].each { |u| warn "   dangling: #{u}" }
report[:orphan_target_attrs].each { |u| warn "   orphan TargetAttributes: #{u}" }
warn '   pbxproj を手編集せず、xcodeproj gem で残骸オブジェクトを remove_from_project してから `make sort` する (ルール 28)'
exit 1
```

- [ ] **Step 6: CLI を本物の pbxproj で GREEN、壊した fixture で RED にする (ルール 8)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && chmod +x bin/pbxproj-structure-check.rb && ruby bin/pbxproj-structure-check.rb && FX=$(mktemp -d /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/c932d6f5-09e8-49c6-b657-a7691d795c50/scratchpad/pbxfix.XXXXXX) && cp -R LeafTimer.xcodeproj "$FX/Broken.xcodeproj" && sed -i '' 's|3857B9B424A7725000B21CCD /\* Assets.xcassets \*/,|3857B9B424A7725000B21CCD /* Assets.xcassets */, DEADBEEFDEADBEEFDEADBEEF /* bogus */,|' "$FX/Broken.xcodeproj/project.pbxproj" && { ruby bin/pbxproj-structure-check.rb "$FX/Broken.xcodeproj" 2>&1; echo "mutated exit=$?"; }
```

Expected: 1 行目 `✅ pbxproj-structure-check passed (232 objects, 0 dangling, 0 orphan TargetAttributes)` (Task 2 前なので 232)。続いて Xcodeproj の `attempted to initialize an object with an unknown UUID` 警告、`❌ pbxproj-structure-check failed: 1 dangling UUID(s), 0 orphan TargetAttributes`、`   dangling: DEADBEEFDEADBEEFDEADBEEF`、`mutated exit=1`。tracked ファイルは触らない (`git status --short` に `LeafTimer.xcodeproj` が出ないこと)。

- [ ] **Step 7: Makefile に配線する**

`app/Makefile` の `precheck:` ターゲット:

```makefile
precheck:
	@echo "Running xcode-precheck..."
	@ruby bin/test_xcode_precheck.rb
	@ruby bin/xcode-precheck.rb
```

を次に置換:

```makefile
precheck:
	@echo "Running xcode-precheck..."
	@ruby bin/test_xcode_precheck.rb
	@ruby bin/xcode-precheck.rb
	@$(MAKE) pbxproj-structure-check
```

ファイル末尾 (`cocoapods-lock-check:` ターゲットの後) に追加:

```makefile

# Issue #73 / ルール 28: pbxproj の dangling UUID と orphan TargetAttributes を検出する。
# xcodeproj gem 経由の target / SPM 参照削除は文字列 grep で見えない残骸を残す (PR #140 で実測)。
pbxproj-structure-check:
	@echo "Running pbxproj-structure-check..."
	@ruby bin/test_pbxproj_structure_check.rb
	@ruby bin/pbxproj-structure-check.rb
```

- [ ] **Step 8: make 経由で GREEN を確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make precheck 2>&1 | tail -6
```

Expected: 末尾に `Running pbxproj-structure-check...` → minitest `6 runs, ... 0 failures` → `✅ pbxproj-structure-check passed (232 objects, 0 dangling, 0 orphan TargetAttributes)`。

- [ ] **Step 9: Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/bin/pbxproj_structure_check.rb app/bin/test_pbxproj_structure_check.rb app/bin/pbxproj-structure-check.rb app/Makefile && git commit -m "build(#73): pbxproj-structure-check で dangling UUID / orphan TargetAttributes を precheck で検出する (ルール 28 の構造検査を repo 化)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hx9VyAySQibLnLZarSn4f5"
```

---

### Task 2: pbxproj から SPM ViewInspector 参照を除去し、Pods 版だけでテストが通ることを実測する

**Files:**
- Modify: `app/LeafTimer.xcodeproj/project.pbxproj` (one-off スクリプト経由のみ)
- Create (scratchpad、commit しない): `<scratchpad>/remove_spm_viewinspector.rb`
- 削除確認: `app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved` (ユーザー `git rm` 済み)、`app/LeafTimer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (ユーザー `rm` 済み)

**Interfaces:**
- Consumes: Task 1 の `make pbxproj-structure-check` (GREEN 判定に使う)

- [ ] **Step 1: 事前条件 (Package.resolved 2 つが消えていること) を確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git ls-files app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved; ls app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved app/LeafTimer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved 2>&1; git status --short
```

Expected: `git ls-files` が空、`ls` が 2 行とも `No such file or directory`、`git status --short` は `D  app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved` (staged 削除) のみ。**残っていれば削除せず**コントローラに報告して止まる (ルール 14)。

- [ ] **Step 2: one-off スクリプトを scratchpad に書く**

`/private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/c932d6f5-09e8-49c6-b657-a7691d795c50/scratchpad/remove_spm_viewinspector.rb` (2026-09-05 にコピーで dry-run 済み):

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
# Issue #73: remove the SPM ViewInspector reference (CocoaPods stays the single source).
# Usage: ruby remove_spm_viewinspector.rb <path/to/LeafTimer.xcodeproj>
require 'xcodeproj'

path = ARGV[0] or abort "usage: #{$0} <xcodeproj>"
project = Xcodeproj::Project.open(path)

# 1. build files whose product_ref is the SPM product (LeafTimerTests Frameworks phase)
removed_build_files = 0
project.targets.each do |t|
  t.frameworks_build_phase.files.dup.each do |bf|
    next unless bf.product_ref && bf.product_ref.product_name == 'ViewInspector'

    t.frameworks_build_phase.remove_build_file(bf)
    removed_build_files += 1
  end
  # 2. target-level package product dependencies
  t.package_product_dependencies.dup.each do |dep|
    next unless dep.product_name == 'ViewInspector'

    t.package_product_dependencies.delete(dep)
    dep.remove_from_project
  end
end

# 3. project-level remote package reference
project.root_object.package_references.dup.each do |ref|
  next unless ref.respond_to?(:repositoryURL) && ref.repositoryURL.to_s.include?('nalexn/ViewInspector')

  project.root_object.package_references.delete(ref)
  ref.remove_from_project
end

project.save
puts "removed build files: #{removed_build_files}"
puts "remaining package_references: #{project.root_object.package_references.size}"
puts "remaining product deps: #{project.targets.sum { |t| t.package_product_dependencies.size }}"
```

- [ ] **Step 3: 実行して diff が削除のみであることを確認する**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && ruby /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/c932d6f5-09e8-49c6-b657-a7691d795c50/scratchpad/remove_spm_viewinspector.rb LeafTimer.xcodeproj && git diff --stat -- LeafTimer.xcodeproj/project.pbxproj && git diff -- LeafTimer.xcodeproj/project.pbxproj | /usr/bin/grep -c "^+[^+]"; /usr/bin/grep -c "ViewInspector\|XCRemoteSwiftPackageReference\|XCSwiftPackageProductDependency\|packageProductDependencies\|packageReferences" LeafTimer.xcodeproj/project.pbxproj
```

Expected: `removed build files: 1` / `remaining package_references: 0` / `remaining product deps: 0`。diff stat は `project.pbxproj | 26 -----` 前後 (削除のみ)、追加行カウント `0`、残骸 grep は `0` (grep は exit 1 を返すが「本当に 0 件」)。追加行が 1 行でもあれば diff を報告して止まる。

- [ ] **Step 4: 構造検査 GREEN + `bundle exec pod install && make sort` 2 回で安定**

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make pbxproj-structure-check && bundle exec pod install && make sort && git diff -- LeafTimer.xcodeproj/project.pbxproj > /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/c932d6f5-09e8-49c6-b657-a7691d795c50/scratchpad/pbx-round1.diff && bundle exec pod install && make sort && git diff -- LeafTimer.xcodeproj/project.pbxproj > /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/c932d6f5-09e8-49c6-b657-a7691d795c50/scratchpad/pbx-round2.diff && cmp /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/c932d6f5-09e8-49c6-b657-a7691d795c50/scratchpad/pbx-round1.diff /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/c932d6f5-09e8-49c6-b657-a7691d795c50/scratchpad/pbx-round2.diff && echo "PBXPROJ_STABLE_ACROSS_ROUNDS" && git status --short
```

Expected: `✅ pbxproj-structure-check passed (229 objects, 0 dangling, 0 orphan TargetAttributes)`、`PBXPROJ_STABLE_ACROSS_ROUNDS`。`git status --short` は `M app/LeafTimer.xcodeproj/project.pbxproj` と staged `D … Package.resolved` の 2 つだけ (Podfile.lock / Pods 配下に変化なし。`?? …Package.resolved` が再生成されていないこと)。

- [ ] **Step 5: fresh DerivedData で `xcodebuild test` を回し、SPM checkout が無く Pods 版だけがリンクされることを実測する** (cold build は Firebase / GoogleMobileAds も含むため 10 分を超えうる — `run_in_background: true` で scratchpad のログにリダイレクトし、完了通知後にログを読む)

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && DD=$(mktemp -d /private/tmp/claude-501/-Users-shinya-workspace-claude-LeafTimer/c932d6f5-09e8-49c6-b657-a7691d795c50/scratchpad/dd73.XXXXXX) && echo "DD=$DD" && set -o pipefail && xcodebuild -workspace LeafTimer.xcworkspace -scheme LeafTimer -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -derivedDataPath "$DD" build test 2>&1 | /usr/bin/grep -E "\*\* TEST (SUCCEEDED|FAILED) \*\*|Executed [0-9]+ tests|error:|Fetching|Resolved source packages" | tail -8; echo "--- SourcePackages ---"; ls "$DD/SourcePackages/checkouts" 2>&1; echo "--- Pods ViewInspector product ---"; ls -d "$DD"/Build/Products/Debug-iphonesimulator/ViewInspector/ViewInspector.framework 2>&1; echo "--- SPM build product (must be absent) ---"; ls -d "$DD"/Build/Products/Debug-iphonesimulator/ViewInspector.swiftmodule "$DD"/Build/Products/Debug-iphonesimulator/ViewInspector.o 2>&1
```

Expected: `** TEST SUCCEEDED **` があり `** TEST FAILED **` / `error:` / `Fetching` / `Resolved source packages` が無い。`Executed 199 tests, with 2 tests skipped and 0 failures` (2026-09-05 時点の件数。増減は可、failures 0 が条件)。`ls "$DD/SourcePackages/checkouts"` は `No such file or directory` (SPM checkout ゼロ)、Pods 版 `ViewInspector.framework` のパスが表示される。SPM のビルド成果物 `ViewInspector.swiftmodule` / `ViewInspector.o` (既定 DerivedData には存在する) は `No such file or directory` 2 行。

- [ ] **Step 6: 既定の DerivedData でも `make tests` が通る** (`run_in_background: true` + scratchpad ログ)

```bash
cd /Users/shinya/workspace/claude/LeafTimer/app && make tests 2>&1 | /usr/bin/grep -E "\*\* TEST (SUCCEEDED|FAILED) \*\*|Executed [0-9]+ tests|✅|❌|Error 6|No rule to make" | tail -12
```

Expected: `✅ pbxproj-structure-check passed (229 …)`、`✅ cocoapods-lock-check passed (1.16.2)`、`** TEST SUCCEEDED **`、`** TEST FAILED **` / `Error 6x` / `No rule to make target` なし。

- [ ] **Step 7: Commit (pbxproj + staged な Package.resolved 削除を同一 commit に)**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git add app/LeafTimer.xcodeproj/project.pbxproj && git status --short && git commit -m "build(#73): ViewInspector の SPM 参照と Package.resolved を除去し CocoaPods (0.10.2) に一本化

pbxproj は xcodeproj gem の one-off で PBXBuildFile / XCSwiftPackageProductDependency /
XCRemoteSwiftPackageReference の 3 オブジェクトを削除 (232 → 229 objects)。
make pbxproj-structure-check GREEN、bundle exec pod install && make sort を 2 回回して安定、
fresh DerivedData で xcodebuild test を回し SourcePackages/checkouts が生成されないことを実測。

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hx9VyAySQibLnLZarSn4f5"
```

Expected: commit に含まれるのは `app/LeafTimer.xcodeproj/project.pbxproj` (M) と `app/LeafTimer.xcworkspace/xcshareddata/swiftpm/Package.resolved` (D) の 2 つ。

---

### Task 3: CLAUDE.md ルール 28 に `make pbxproj-structure-check` を書き足す

**Files:**
- Modify: `CLAUDE.md` — ルール 28 (行頭 `28.` の 1 行) の末尾に追記

- [ ] **Step 1: ルール 28 の末尾に追記する**

`CLAUDE.md` の `28.` で始まる行の**末尾** (現在 `…残骸 2 種あり)。` で終わる) に、次の文をスペース 1 つ挟んで追加する (行の他の部分は変更しない):

```text
**この構造検査は `make pbxproj-structure-check` (precheck 内、#73 で repo 化) が行う** — SPM 参照の除去も同じ gem の one-off (`frameworks_build_phase.remove_build_file` → `package_product_dependencies.delete` + `remove_from_project` → `root_object.package_references.delete` + `remove_from_project`) で行い、検証は fresh な `-derivedDataPath` で `xcodebuild test` を回して `SourcePackages/checkouts` が生成されないことを実測する (既定 DerivedData の stale な SPM 成果物がリンク切れを隠す — #73)。
```

- [ ] **Step 2: 確認と Commit**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && /usr/bin/grep -c "^28\. " CLAUDE.md && /usr/bin/grep -c "make pbxproj-structure-check" CLAUDE.md && git diff --stat && git add CLAUDE.md && git commit -m "docs(#73): ルール 28 に pbxproj-structure-check と SPM 参照除去の手順を追記

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hx9VyAySQibLnLZarSn4f5"
```

Expected: 両 grep が `1`、diff stat は `CLAUDE.md | 2 +-`。

---

### Task 4: PR 作成 (コントローラが実行)

- [ ] **Step 1: 既存 PR 確認と push**

```bash
cd /Users/shinya/workspace/claude/LeafTimer && git fetch && gh pr list --state all --head feature/73-viewinspector-pods-only && git push -u origin feature/73-viewinspector-pods-only
```

- [ ] **Step 2: PR 作成** — 本文に「一本化の方向 (Pods)」「除去した 3 オブジェクト」「Package.resolved 2 つの削除と #31 ladder を残す決定」「fresh DerivedData 実測」「受け入れ基準」を書く。

## 受け入れ基準 (ルール 23: CI ログ行)

pr-tests run の `gh run view <id> --log` を**メッセージパターンで** grep し (step 列は `UNKNOWN STEP` になりうる)、次が全て存在すること:

| 期待ログ行 | 意味 |
| --- | --- |
| `✅ pbxproj-structure-check passed (229 objects, 0 dangling, 0 orphan TargetAttributes)` | 構造検査が CI で live かつ GREEN |
| `✅ targets: no new orphan Swift files` | 既存 orphan gate が引き続き live |
| `** TEST SUCCEEDED **` | Pods 版 ViewInspector だけでテストがリンク・実行できた |

不合格条件: `pbxproj-structure-check skipped` / `orphan check skipped` / `** TEST FAILED **` のいずれかが 1 行でも出る。加えて `Sort gate` step が pass (pbxproj が CI の `bundle exec pod install` で動かない)。

```bash
RUN_ID=$(gh pr checks <PR> --json name,link --jq '.[] | select(.name=="pr-tests") | .link' | sed 's#.*/runs/##; s#/job.*##')
gh run view "$RUN_ID" --log | /usr/bin/grep -E "pbxproj-structure-check (passed|skipped)|targets: (no new orphan|orphan check skipped)|\*\* TEST (SUCCEEDED|FAILED) \*\*" | head
```

## 自己レビュー

- **Spec coverage**: issue #73 の「CocoaPods 側へ一本化し、pbxproj の SPM 参照と余分な Package.resolved を除去」→ Task 2 (SPM 3 オブジェクト除去 + Package.resolved 2 つ削除)。ルール 28 の「構造検査で受け入れ」→ Task 1 (repo 化) + Task 2 Step 4。「`pod install && make sort` を 2 回」→ Task 2 Step 4。#31 ladder を残す決定 → Global Constraints。
- **Placeholder scan**: 全 step にコマンド・期待出力・コード全文あり。`<PR>` / `<id>` は実行時に確定。
- **Type consistency**: `PbxprojStructureCheck.referenced_uuids` / `report(defined_uuids:, referenced_uuids:, target_uuids:, target_attribute_keys:)` → `{ ok:, dangling:, orphan_target_attrs: }` はテスト (6 件) / 実装 / CLI で一致。Makefile ターゲット名 `pbxproj-structure-check` は Task 1 / Task 2 / Task 3 / 受け入れ基準で一致。object 数 232 (Task 1 Step 6/8、Task 2 前) と 229 (Task 2 Step 4 以降) の使い分けを確認済み。
