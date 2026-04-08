# SOLUTION: キーボードせり上がり現象の包括的解決策

## 試したアプローチ（分析結果）
1. 個別画面での `resizeToAvoidBottomInset: false` 設定 → 部分的に効果ありだが根本解決にならない
2. `MediaQuery.removeViewInsets` の使用 → 複雑化のみで問題の再発可能性

## 最終的な解決策
**「Scaffold のみに Zoom 機能を限定する」**手法：

### 1. `lib/main.dart` の変更
- `MaterialApp.builder` 内の `InteractiveViewer` を削除
- ズーム機能が必要な場合のみ、個別画面で `InteractiveViewer(constrained: false, clipBehavior: Clip.none)` を使用

### 2. 入力画面の修正方針
- 全ての入力画面で `resizeToAvoidBottomInset: true` を明示設定（デフォルト動作を信頼）
- `MediaQuery.removeViewInsets` のような複雑なワークアラウンドは不要

### 3. 実装ステップ
1. `lib/main.dart` の builder 関数を簡素化
2. `stocktake_input_screen.dart`, `estimate_input_screen.dart` で `resizeToAvoidBottomInset: true` を追加
3. 他の入力画面も同様に確認・修正

## 学んだこと
- Flutter のキーボード処理は `Scaffold.resizeToAvoidBottomInset` に依存している
- ルートレベルのウィジェット（InteractiveViewer）が子に与える制約が、システム機能と競合する可能性
- 包括的解決には「共通基盤の修正」が効果的
