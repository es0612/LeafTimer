# Design Document

## Overview

LeafTimerアプリの近代化プロジェクトの技術設計です。MVVM アーキテクチャとSwiftUIを基盤とした既存システムを活用しながら、iOS 17とXcode 15に対応し、UI/UXの大幅な改善と新機能の追加を実現します。Protocol-oriented programmingと依存注入パターンを維持し、テスタブルで保守性の高い設計を目指します。

## Design Principles

### 1. 既存アーキテクチャの継承と進化
- **MVVM Pattern**: 既存のView-ViewModel-Component構造を維持
- **Protocol-Based DI**: `TimerManager`, `AudioManager`, `UserDefaultsWrapper`プロトコルの拡張
- **SwiftUI Native**: UIKitからの完全移行、最新SwiftUI APIの活用

### 2. 段階的移行戦略
- **Phase 1**: ビルド互換性とコア機能の動作確認
- **Phase 2**: UI/UX近代化と新機能追加
- **Phase 3**: パフォーマンス最適化と品質保証

## Technical Architecture

### System Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    iOS 17 + Xcode 15                   │
├─────────────────────────────────────────────────────────┤
│  SwiftUI Views (Modernized)                           │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │
│  │ TimerView   │ │SettingView  │ │ StatsView   │      │
│  │ (Enhanced)  │ │ (Enhanced)  │ │   (New)     │      │
│  └─────────────┘ └─────────────┘ └─────────────┘      │
├─────────────────────────────────────────────────────────┤
│  ViewModels (Enhanced)                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │
│  │TimerVM      │ │SettingVM    │ │ StatsVM     │      │
│  │(Modernized) │ │(Modernized) │ │  (New)      │      │
│  └─────────────┘ └─────────────┘ └─────────────┘      │
├─────────────────────────────────────────────────────────┤
│  Enhanced Components Layer                             │
│  ┌─────────────────┐ ┌─────────────────┐              │
│  │ Core Components │ │ New Components  │              │
│  │ (Modernized)    │ │                 │              │
│  │ • TimerManager  │ │ • StatsManager  │              │
│  │ • AudioManager  │ │ • WidgetManager │              │
│  │ • DataManager   │ │ • CloudManager  │              │
│  └─────────────────┘ └─────────────────┘              │
├─────────────────────────────────────────────────────────┤
│  iOS System Integration                                │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │
│  │WidgetKit    │ │Focus Mode   │ │ Shortcuts   │      │
│  │ iCloud      │ │Background   │ │ UserNotif   │      │
│  └─────────────┘ └─────────────┘ └─────────────┘      │
└─────────────────────────────────────────────────────────┘
```

## Component Design Details

### 1. Modernized Core Components

#### TimerManager (Enhanced)
```swift
protocol TimerManager {
    // 既存機能
    func start(target: Any)
    func stop()
    
    // 新機能
    func pause()
    func resume()
    func scheduleNext(workDuration: TimeInterval, breakDuration: TimeInterval)
    var timerState: TimerState { get }
}

enum TimerState {
    case idle
    case running(remaining: TimeInterval)
    case paused(remaining: TimeInterval)
    case completed
}

class ModernTimerManager: TimerManager {
    // iOS 17対応のTimer実装
    // Focus Mode連携
    // Background処理最適化
}
```

#### AudioManager (Enhanced)
```swift
protocol AudioManager {
    // 既存機能
    func start()
    func stop()
    func vibration()
    func setUp(workingSound: String)
    
    // 新機能
    func setCustomSound(url: URL)
    func enableSpatialAudio()
    var currentAudioSession: AudioSessionConfiguration { get }
}

class ModernAudioManager: AudioManager {
    // AVAudioEngine使用
    // カスタムサウンド対応
    // 空間音響対応
}
```

#### DataManager (New)
```swift
protocol DataManager {
    func save<T: Codable>(_ object: T, key: String)
    func load<T: Codable>(_ type: T.Type, key: String) -> T?
    func syncToCloud()
    func getStatistics(period: StatsPeriod) -> TimerStatistics
}

enum StatsPeriod {
    case today, week, month, year
}

struct TimerStatistics: Codable {
    let totalSessions: Int
    let totalWorkTime: TimeInterval
    let averageSessionLength: TimeInterval
    let productivity: Double
}
```

### 2. New Component Integration

#### StatsManager
```swift
protocol StatsManager {
    func recordSession(workTime: TimeInterval, breakTime: TimeInterval)
    func getProductivityTrend(days: Int) -> [ProductivityPoint]
    func getWeeklyReport() -> WeeklyReport
    func exportData(format: ExportFormat) -> Data
}

class ModernStatsManager: StatsManager {
    private let dataManager: DataManager
    private let analyticsEngine: AnalyticsEngine
    
    // Core Data / CloudKit統合
    // 詳細な分析機能
}
```

#### WidgetManager
```swift
protocol WidgetManager {
    func updateWidgetContent()
    func configureWidgetIntent()
    var currentTimerState: WidgetTimerState { get }
}

// WidgetKit統合
class WidgetTimerProvider: TimelineProvider {
    // ホーム画面ウィジェット
    // ロック画面ウィジェット（iOS 16+）
    // インタラクティブウィジェット（iOS 17+）
}
```

## User Interface Design

### 1. Design System Modernization

#### Color System (iOS 17準拠)
```swift
extension Color {
    static let primaryGreen = Color("PrimaryGreen")
    static let secondaryGreen = Color("SecondaryGreen")
    static let backgroundPrimary = Color("BackgroundPrimary")
    static let backgroundSecondary = Color("BackgroundSecondary")
    
    // Dynamic Type対応
    // Dark Mode完全対応
    // アクセシビリティ配慮
}
```

#### Typography System
```swift
extension Font {
    static let timerDisplay = Font.system(size: 72, weight: .ultraLight, design: .monospaced)
    static let sessionCount = Font.system(size: 24, weight: .semibold)
    static let settingLabel = Font.system(size: 17, weight: .medium)
    
    // Dynamic Type対応
    // 多言語対応
}
```

### 2. Enhanced Views

#### TimerView (Modernized)
```swift
struct TimerView: View {
    @StateObject private var viewModel: TimerViewModel
    @State private var isAnimating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // モダンなタイマー表示
                TimerDisplayView(
                    currentTime: viewModel.currentTimeSecond,
                    isRunning: viewModel.executeState,
                    mode: viewModel.breakState ? .break : .work
                )
                .modifier(PulseAnimation(isAnimating: $isAnimating))
                
                // アップデートされたコントロール
                TimerControlsView(
                    onPlayPause: viewModel.onPressedTimerButton,
                    onReset: viewModel.reset,
                    state: viewModel.timerState
                )
                
                // 新しい統計表示
                SessionStatsView(
                    todayCount: viewModel.todaysCount,
                    weeklyAverage: viewModel.weeklyAverage
                )
            }
            .navigationTitle("LeafTimer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingView()) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
}
```

#### StatsView (New)
```swift
struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // 今日の統計
                    TodayStatsCard(stats: viewModel.todayStats)
                    
                    // 週間トレンド
                    WeeklyTrendChart(data: viewModel.weeklyData)
                    
                    // 月間レポート
                    MonthlyReportCard(report: viewModel.monthlyReport)
                    
                    // エクスポート機能
                    ExportSection(onExport: viewModel.exportData)
                }
                .padding()
            }
            .navigationTitle("統計")
        }
    }
}
```

## Data Architecture

### 1. Local Storage Evolution

#### UserDefaults → Core Data Migration
```swift
// 段階的移行戦略
class DataMigrationManager {
    func migrateUserDefaultsToCoreData() {
        // 既存UserDefaultsデータの保護
        // Core Dataスキーマ設定
        // 段階的データ移行
    }
}

// Core Data Stack
class CoreDataStack {
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "LeafTimer")
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
            forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        return container
    }()
}
```

### 2. Cloud Synchronization

#### iCloud Integration Design
```swift
protocol CloudSyncManager {
    func enableCloudSync()
    func syncSettings()
    func syncStatistics()
    func resolveConflicts()
}

class iCloudSyncManager: CloudSyncManager {
    private let cloudKitContainer: CKContainer
    private let coreDataStack: CoreDataStack
    
    // CloudKitとCore Dataの連携
    // コンフリクト解決機能
    // オフライン対応
}
```

## Performance Architecture

### 1. Memory Management
```swift
// メモリ効率化戦略
class MemoryOptimizedTimerManager: TimerManager {
    // Weak references
    // Lazy loading
    // Background queue処理
    
    private weak var target: AnyObject?
    private lazy var backgroundQueue = DispatchQueue(label: "timer.background")
}
```

### 2. Battery Optimization
```swift
// バッテリー最適化
class EfficientAudioManager: AudioManager {
    // Audio Session最適化
    // Background処理制限
    // ハードウェア活用最小化
    
    private func optimizeForBatteryLife() {
        // iOS 17 Power efficiency APIs
    }
}
```

## Integration Design

### 1. iOS System Integration

#### WidgetKit Integration
```swift
// ホーム画面ウィジェット
struct TimerWidget: Widget {
    let kind: String = "TimerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerProvider()) { entry in
            TimerWidgetView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("タイマー")
        .description("現在のタイマー状態を表示します")
    }
}

// インタラクティブウィジェット (iOS 17)
struct InteractiveTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "InteractiveTimer", provider: InteractiveTimerProvider()) { entry in
            InteractiveTimerWidgetView(entry: entry)
        }
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
```

#### Focus Mode Integration
```swift
class FocusModeManager {
    func enableWorkFocus() {
        // Do Not Disturbアクティベーション
        // 通知制限
        // 他アプリとの連携制限
    }
    
    func enableBreakFocus() {
        // リラックスモード
        // 制限解除
    }
}
```

#### Shortcuts Integration
```swift
class ShortcutsManager {
    func setupTimerShortcuts() {
        // Siri Shortcuts
        // ショートカットアプリ連携
        // 音声コマンド対応
    }
}
```

## Testing Strategy

### 1. Unit Testing Enhancement
```swift
// プロトコルベーステスト
class MockModernTimerManager: TimerManager {
    var startCallCount = 0
    var stopCallCount = 0
    var currentState: TimerState = .idle
    
    func start(target: Any) {
        startCallCount += 1
        currentState = .running(remaining: 1500)
    }
}

// ViewInspector対応
class TimerViewTests: XCTestCase {
    func testTimerDisplayUpdates() throws {
        let viewModel = TimerViewModel(
            timerManager: MockModernTimerManager(),
            audioManager: MockAudioManager(),
            userDefaultWrapper: MockUserDefaultWrapper()
        )
        
        let view = TimerView(viewModel: viewModel)
        let inspectedView = try view.inspect()
        
        // SwiftUI View テスト
    }
}
```

### 2. Integration Testing
```swift
// Widget テスト
class WidgetIntegrationTests: XCTestCase {
    func testWidgetUpdatesWithTimerState() {
        // WidgetKit統合テスト
    }
}

// CloudKit テスト
class CloudSyncTests: XCTestCase {
    func testDataSynchronization() {
        // iCloud同期テスト
    }
}
```

## Deployment Strategy

### 1. Migration Path
```
Phase 1: Foundation (1-2 weeks)
├── Xcode 15 / iOS 17 compatibility
├── Dependencies update
├── Basic functionality verification
└── Critical bug fixes

Phase 2: UI/UX Modernization (2-3 weeks)
├── SwiftUI API updates
├── Design system implementation
├── Dark mode complete support
└── Accessibility improvements

Phase 3: Feature Enhancement (3-4 weeks)
├── Statistics module
├── Widget implementation
├── Focus Mode integration
└── Cloud sync setup

Phase 4: Quality & Performance (1-2 weeks)
├── Performance optimization
├── Memory leak fixes
├── Battery optimization
└── Comprehensive testing
```

### 2. Release Strategy
```
Beta Release (TestFlight)
├── Internal testing (1 week)
├── External beta testing (2 weeks)
├── Feedback incorporation (1 week)
└── Final QA (1 week)

Production Release
├── App Store submission
├── Review process (1-7 days)
├── Release coordination
└── Post-release monitoring
```

## Risk Mitigation

### 1. Technical Risks
- **Migration失敗**: 段階的移行とロールバック計画
- **Performance低下**: 継続的なプロファイリングと最適化
- **Data loss**: バックアップ機能と移行テスト

### 2. Business Risks
- **App Store拒否**: 事前ガイドライン確認とプリサブミッション
- **ユーザー不満**: ベータテストとフィードバック収集
- **競合対応**: 差別化機能の明確化

## Success Metrics

### Technical Metrics
- ビルド成功率: 100%
- クラッシュ率: <0.1%
- 起動時間: <3秒
- メモリ使用量: <50MB

### Business Metrics
- App Store承認: 初回サブミッション成功
- ユーザー評価: 4.5+ stars
- ダウンロード数: 前バージョン比150%増
- 収益: 広告収入20%向上

この設計により、LeafTimerアプリは現代のiOSエコシステムに適合し、ユーザー体験の大幅な向上と技術的な持続可能性を実現します。