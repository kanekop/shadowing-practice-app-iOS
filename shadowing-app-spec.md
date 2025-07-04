# シャドウィング練習アプリ 詳細仕様書

## 1. アプリ概要

### 1.1 目的
日本人の英語学習者向けに、シャドウィング（音声を聞きながら同時に発音する練習法）と音読練習を通じて、英語の発音を改善するiOSアプリ。

### 1.2 ターゲットユーザー
- 日本人の英語学習者
- 英語の発音を改善したい人
- TOEICやビジネス英語の発音練習をしたい人

### 1.3 主要機能
1. **音声録音機能**: 練習用音声の録音と保存
2. **音声認識機能**: 録音した音声の文字起こし（英語のみ）
3. **練習モード**: 音読練習とシャドウィング練習
4. **評価機能**: 発音の正確性を評価し、フィードバックを提供

## 2. 技術仕様

### 2.1 開発環境
- **IDE**: Xcode 16.3
- **言語**: Swift 5.0
- **最小iOS**: iOS 18.4
- **UI Framework**: SwiftUI
- **アーキテクチャ**: MVVM風（ViewとServiceの分離）

### 2.2 使用フレームワーク
- **AVFoundation**: 音声録音・再生
- **Speech Framework**: 音声認識（Apple標準）
- **Combine**: リアクティブプログラミング

### 2.3 外部依存
- なし（将来的にOpenAI APIを検討）

## 3. 機能詳細

### 3.1 録音機能（RecordingView + AudioRecorder）

#### 機能要件
- 高品質録音（44.1kHz、AAC、ステレオ）
- 録音ファイルは`Documents/[UUID].m4a`に保存
- 録音中はリアルタイムで経過時間を表示
- 録音完了後、自動的に文字起こしを開始

#### 技術詳細
```swift
// 録音設定
AVFormatIDKey: kAudioFormatMPEG4AAC
AVSampleRateKey: 44100.0
AVNumberOfChannelsKey: 2
AVEncoderAudioQualityKey: AVAudioQuality.high
```

#### UIフロー
1. 赤い録音ボタンをタップ
2. 録音中はボタンがパルスアニメーション
3. 停止ボタンをタップで録音終了
4. 自動的に文字起こし処理開始
5. 完了後、録音リストに追加

### 3.2 音声認識機能（SpeechRecognizer）

#### 機能要件
- **言語**: 英語（en-US）のみ対応
- ファイルベースの音声認識（ストリーミングではない）
- 認識進捗をパーセンテージで表示
- 認識結果は`Documents/[UUID].txt`に保存

#### 権限設定（Info.plist）
```xml
<key>NSMicrophoneUsageDescription</key>
<string>音声入力のためにマイクを使用します</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>文字に変換するために使用します</string>
```

### 3.3 練習モード（PracticeView）

#### 3.3.1 音読モード
- お手本テキストを表示
- ユーザーがテキストを見ながら音読
- 録音して評価

#### 3.3.2 シャドウィングモード
- お手本音声を再生
- 同時にユーザーが発音
- 録音して評価

#### 3.3.3 共通処理フロー
1. 練習モード選択
2. お手本テキスト表示
3. 録音開始
4. 録音終了時に`AudioRecorder.stopRecording(completion:)`を使用
5. 完了ハンドラで録音URLを取得
6. 音声認識処理
7. テキスト比較・評価
8. 結果表示

### 3.4 評価機能（TextComparisonService）

#### アルゴリズム
- Levenshtein距離による単語レベルの比較
- Word Error Rate (WER) の計算
- 精度は0-100%で表示

#### 評価項目
- **正解単語数**: 正しく発音された単語
- **置換エラー**: 違う単語として認識
- **削除エラー**: 発音されなかった単語
- **挿入エラー**: 余分に発音された単語

#### フィードバック
- 90%以上: "Excellent!"
- 70-89%: "Good job!"
- 50-69%: "Keep practicing!"
- 50%未満: "Let's work on pronunciation"

## 4. データモデル

### 4.1 Recording
```swift
struct Recording {
    let id: UUID
    let url: URL  // 音声ファイルのパス
    let createdAt: Date
    var duration: TimeInterval
    var transcription: String?  // 文字起こし結果
    var isTranscribing: Bool  // 処理中フラグ
}
```

### 4.2 PracticeSession
```swift
struct PracticeSession {
    let id: UUID
    let practiceType: PracticeType  // 音読/シャドウィング
    let originalText: String  // お手本テキスト
    let userText: String  // 認識されたテキスト
    let score: Double  // 0-100%
    let wordErrors: [WordError]  // エラー詳細
    let createdAt: Date
}
```

## 5. 現在の問題と対応

### 5.1 練習モードでの0%問題
**症状**: 
- 録音タブでは正常に文字起こしができる
- 練習タブでは常に0%の評価になる

**原因の可能性**:
1. 録音ファイルが完全に保存される前に音声認識を開始
2. AVAudioSessionの設定競合
3. 音声認識が空文字列を返している

**実装済みの対策**:
- `AudioRecorder.stopRecording`に完了ハンドラを追加
- デバッグログによる処理フローの追跡
- ファイル存在確認の実装

## 6. ファイル構成

```
ShadowingPractice/
├── Models/
│   ├── Recording.swift        # 録音データモデル
│   └── PracticeSession.swift  # 練習セッションモデル
├── Views/
│   ├── ContentView.swift      # メインタブビュー
│   ├── RecordingView.swift    # 録音画面
│   └── PracticeView.swift     # 練習画面
├── Services/
│   ├── AudioRecorder.swift    # 録音サービス
│   ├── SpeechRecognizer.swift # 音声認識サービス
│   └── TextComparisonService.swift # テキスト比較サービス
└── ShadowingPracticeApp.swift # アプリエントリーポイント
```

## 7. 今後の拡張予定

### 7.1 短期目標（MVP完成）
- [ ] 練習モードの0%問題の解決
- [ ] 基本的な練習フローの完成
- [ ] 結果画面の実装

### 7.2 中期目標
- [ ] 練習履歴の表示
- [ ] 進捗グラフの実装
- [ ] 複数の練習テキストの追加

### 7.3 長期目標
- [ ] OpenAI API統合による高精度評価
- [ ] カスタム練習テキストのインポート
- [ ] 学習カリキュラムの実装

## 8. 重要な実装ポイント

### 8.1 非同期処理
- 録音完了は`AVAudioRecorderDelegate`で検知
- 音声認識は非同期で実行
- UIの更新は必ず`DispatchQueue.main.async`で実行

### 8.2 エラーハンドリング
- 録音権限がない場合の対応
- 音声認識権限がない場合の対応
- ファイルアクセスエラーの対応

### 8.3 メモリ管理
- 大きな音声ファイルの適切な削除
- Timerの適切な無効化
- 循環参照を避けるための`[weak self]`の使用