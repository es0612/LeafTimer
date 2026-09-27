# LeafTimer App Store メタデータ

- `asc-submission-prep` skill が説明文・キーワード・サブタイトル・URL・著作権の入力元として読む (What's New は `docs/RELEASE_v<ver>.md`)
- 記載の無い項目は skill の `skip` 扱い (ASC の live 値を変えない)
- 本文の機能記述はコードに合わせる: 作業時間 `ItemValue.workingTimeList` (5〜60 分)、休憩 `breakTimeList` (1〜10 分)、サウンド `soundList`

## ja

- marketing_url: https://note.com/es0612swift
- copyright: 2026 AsaPapaLab.

### description

ASC の 1.4 の値から、コードと食い違う 3 箇所だけを直したもの (作業時間 5〜60 分 / 「完全オフライン動作」削除 / 「iOS 17最適化」削除)。

```text
LeafTimerは、ポモドーロテクニックを活用した集中力向上タイマーアプリです。

【主な機能】
・ポモドーロタイマー：25分作業 + 5分休憩の集中サイクル
・カスタマイズ可能な時間設定：5分〜60分の作業時間、1分〜10分の休憩時間
・豊富なサウンド選択：雨音、川のせせらぎ、無音から選択可能
・今日の達成回数表示：モチベーション維持をサポート
・バイブレーション通知：サイレントモードでも安心
・シンプルで美しいインターフェース：集中を妨げないデザイン

【ポモドーロテクニックとは】
25分間の集中作業と5分間の短い休憩を繰り返す時間管理術です。
集中力の維持と疲労の軽減により、生産性の向上を図ります。

【こんな方におすすめ】
・在宅ワークで集中力を高めたい方
・ 勉強の効率を上げたい学生の方
・ プロジェクト作業に集中したい方
・ 時間管理を改善したい方

【主な特徴】
・バッテリー効率重視：最適化された電力消費
・プライバシー重視：個人データは端末内のみ保存

LeafTimerで、より集中的で生産的な時間を過ごしましょう。
```

## en-US (v1.5 で英語ローカリゼーションを新規追加)

### name

LeafTimer

### subtitle

Pomodoro Focus Timer

### keywords

pomodoro,timer,focus,productivity,study,work,break,concentration,habit,streak

### support_url

https://note.com/es0612swift

### marketing_url

https://note.com/es0612swift

### description

LeafTimer is a simple Pomodoro timer that helps you build a focus habit. As you keep focusing, a small leaf grows into a big tree.

Features
- Pomodoro timer: alternate focused work and short breaks
- Custom durations: 5 to 60 minutes of work, 1 to 10 minutes of break
- Background sounds: rain, river, three BGM tracks, or silence
- Notifications when a work or break session ends, even when the app is closed
- History: current streak, longest streak, total sessions, and the last 7 days
- Haptic feedback and vibration
- VoiceOver and Dynamic Type support

What is the Pomodoro Technique?
A time management method that repeats 25 minutes of focused work followed by a 5-minute break. Short, regular breaks help you stay focused and reduce fatigue.

Great for
- Working from home
- Studying for exams
- Staying focused on projects
- Improving your time management

Your session history is stored only on your device.
