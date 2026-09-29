---
name: leaftimer-xcode-deps
description: Use when touching LeafTimer's Xcode project or dependencies — adding/removing Swift files or targets (pbxproj), Podfile / Podfile.lock / Gemfile / Gemfile.lock, SPM Package.resolved, CI install steps for CocoaPods/Bundler, ruby checkers wired into make, or choosing a test framework / test pod version.
---

# LeafTimer Xcode 構成・依存

CLAUDE.md ルール 26 / 27 / 28 / 29 / 43 の実体。各項目の事故経緯は `docs/claude-lessons-archive.md` の「#171 で CLAUDE.md から退避したルール全文」節にある。

## CI の依存 install (ルール 26)

- マネージド CI runner は CocoaPods / Bundler 等の preinstall を保証しない。CI hook の冒頭で `set -euo pipefail` 配下の明示 install を先頭に置く。
- CocoaPods は `app/Gemfile.lock` で固定し、常に `bundle exec pod …` で動かす。Ruby は `app/.ruby-version`。CI は `ruby/setup-ruby@v1` の `working-directory: app` + `bundler-cache: true` が両方を読む。
- 素の `pod` / `gem install cocoapods` / `pod _<ver>_` に戻さない。macos runner の `pod` は brew ruby の RubyGems binstub で常に最新 install 版を activate するため、lock 版へ downgrade できない。
- Gemfile.lock と Podfile.lock の `COCOAPODS:` 行の一致は `make cocoapods-lock-check` (tests チェーン内) が守る。
- Xcode Cloud の `ci_post_clone.sh` は master 限定トリガーで PR 検証できない。bundle exec 化は #147 (未着手)。

## make に ruby checker を足す時 (ルール 27)

- Apple 同梱外の gem を `require` するなら `rescue LoadError` でガードし、gem 不在でも green を維持する。
- ただしガードは CI で silent green を生みうる。`bundler-cache: true` は gem を `app/vendor/bundle` に隔離し自身の Ruby を PATH 先頭に置くため、素の `ruby bin/*.rb` は lock の gem を `require` できずガードが黙って skip する。
- CI では `bundle exec make tests` のように make ごと bundle exec で包み、ガード付き checker の ✅ 行の存在と `skipped` 行の不在を受け入れ基準に入れる。

## pbxproj (ルール 28)

- 新規 Swift ファイルの配線は手編集せず `make add-file FILE=<project 相対パス> TARGET=app|test` を使う (sort + precheck まで自動、idempotent)。TARGET は必須 — app/test の取り違えは「テストが本番バイナリに入る」事故になる。
- 配線 (pbxproj 差分) はそのファイルを追加する commit 自体に含める。後送りすると task review で指摘され fix round が 1 つ増える。
- 未配線の .swift が複数あると `make add-file` を `&&` で連結できない (1 回目の内部 precheck が 2 つ目を orphan 判定して exit 2)。1 ファイルずつ実行する。
- orphan (target 未 attach) は `make precheck` が検出する。扱いは liveness grep でなく「放棄 → 削除 / 配線忘れ → attach」の意図判断で決める (材料: git log の最終更新時期 + live 等価実装の有無)。意図的な orphan は `ruby bin/xcode-precheck.rb --update-baseline` で baseline に追加する。
- target 削除も手編集せず xcodeproj gem の one-off で行う。`target.remove_from_project` は `XCBuildConfiguration` と `TargetAttributes` を連鎖削除しないので、受け入れは文字列 grep でなく構造検査 (`make pbxproj-structure-check`、precheck 内) で行い、`pod install && make sort` を 2 回回して pbxproj が安定することを確認する。
- SPM 参照の除去も同じ gem の one-off: `frameworks_build_phase.remove_build_file` → `package_product_dependencies.delete` + `remove_from_project` → `root_object.package_references.delete` + `remove_from_project`。検証は fresh な `-derivedDataPath` で `xcodebuild test` を回し、`SourcePackages/checkouts` が生成されないことを実測する (既定 DerivedData の stale な SPM 成果物がリンク切れを隠す)。

## SPM の Package.resolved (ルール 29)

- `app/.gitignore` の `*.xcworkspace` は `xcshareddata/swiftpm/Package.resolved` を巻き込む。SPM 依存の追加・更新時は `git status` に `Package.resolved` が出るか確認し、出なければ `git add -f` するか `.gitignore` に `!**/Package.resolved` を足す。

## テストフレームワークと test pod (ルール 43)

- 新規テストは XCTest、View 構造の検証は ViewInspector。Quick/Nimble (`*Spec.swift`) は新規追加禁止・既存は据え置き (一括移行しない)。`OnboardingViewSpec` は既に XCTest。
- `app/Podfile` の制約は 2 段構え: Quick `~> 7.6` / Nimble `~> 13.7` は major 越えだけを止める optimistic 制約。ViewInspector は strict pin `'0.10.3'` (patch 差だけで accessibility テストの結果が変わった実績があるため、patch も明示的な Podfile 編集にする)。
- `~>` は patch を固定しない (`~> 7.6` = `>= 7.6, < 8.0`)。Quick/Nimble の patch を止めているのは `Podfile.lock` だけ。
- 引数なしの `bundle exec pod update` と `Podfile.lock` の喪失は lock を無視して解決し直す (`cocoapods-1.16.2/lib/cocoapods/installer/analyzer.rb:934-947` の `update_mode == :all` / `!lockfile` 分岐)。更新は必ず pod を名指しした `bundle exec pod update <pod>` で行う。
