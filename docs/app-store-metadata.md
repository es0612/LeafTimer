# LeafTimer App Store メタデータ

- `asc-submission-prep` skill が説明文・キーワード・サブタイトル・URL・著作権の入力元として読む (What's New は `docs/RELEASE_v<ver>.md`)
- 記載の無い項目は skill の `skip` 扱い (ASC の live 値を変えない)
- name / subtitle を変えるには新しいバージョンの提出が必要 (ASC のアプリ情報ページの注記、2026-11-07)
- 本文の機能記述はコードに合わせる: 作業時間 `ItemValue.workingTimeList` (5〜60 分)、休憩 `breakTimeList` (1〜10 分)、サウンド `soundList`

## ja

- marketing_url: https://note.com/es0612swift
- copyright: 2026 AsaPapaLab.

### name

LeafTimer - 葉が育つ集中タイマー

### subtitle

ポモドーロで勉強も作業もはかどる

### keywords

時間管理,休憩,生産性,仕事効率化,フォーカス,習慣,記録,学習,受験,資格,読書,テレワーク,在宅,雨音,自然音,BGM,カウントダウン,朝活,ルーティン,スタディ,試験,25分,気分転換

### promotional_text

雨音や川のせせらぎを流しながら、25分の集中と5分の休憩をくり返すだけ。タイマーが進むと、小さな葉が芽から木へと育ちます。静かに続けられるポモドーロタイマーです。

### description

1.6.2 で書き直したもの (#197)。機能は en-US の description と同じ内容をコードで確かめた。

```text
LeafTimerは、静かに集中するためのシンプルなポモドーロタイマーです。
25分の作業と5分の休憩をくり返すあいだ、画面の小さな葉がタイマーの進みに合わせて、芽から若木、木へと育ちます。

【主な機能】
・ポモドーロタイマー：作業と休憩を交互にくり返す
・時間の設定：作業は5〜60分、休憩は1〜10分
・バックグラウンドの音：雨音、川のせせらぎ、BGM 3曲、無音から選べます
・終了のお知らせ：アプリを閉じていても、作業や休憩の終わりを通知します
・履歴：連続日数、最長の連続日数、累計セッション数、過去7日の回数
・バイブレーション
・VoiceOverと文字サイズの変更に対応

【ポモドーロテクニックとは】
25分の集中と5分の短い休憩をくり返す時間管理の方法です。こまめに休むことで集中が続き、疲れにくくなります。

【こんな方に】
・在宅ワークで集中したい方
・試験や資格の勉強をしている方
・読書や作業の時間を区切りたい方
・時間の使い方を見直したい方

記録はすべて端末の中だけに保存されます。
```

## en-US (v1.5 で英語ローカリゼーションを新規追加)

### name

LeafTimer - Pomodoro Focus

### subtitle

Calm timer for study and work

### keywords

productivity,concentration,habit,streak,break,routine,rain,sounds,student,exam,tomato,flow,rest

### promotional_text

Focus for 25 minutes, rest for 5, with soft rain or a river in the background. As the timer runs, a small leaf grows into a tree. A quiet Pomodoro timer.

### support_url

https://note.com/es0612swift

### marketing_url

https://note.com/es0612swift

### description

LeafTimer is a quiet, simple Pomodoro timer for focused work and study. As the timer runs, a small leaf grows from a sprout into a tree.

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
