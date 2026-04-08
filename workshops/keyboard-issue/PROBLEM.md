# キーボード表示時の空白発生問題

## 問題概要
Flutter アプリの入力画面で、キーボードがアクティブになるとキーボードの上に空白が発生し、入力部分を除いて画面が無くなる現象

## 発生状況
- **発生日時**: 2026-04-08（調査開始日）
- **影響範囲**: 複数入力画面（stocktake_input_screen, invoice_input_screen 等）
- **再現ステップ**:
  1. 任意の入力画面を開く
  2. テキストフィールドをタップしてキーボードを表示
  3. キーボード上に不要な空白が発生し、画面が切り捨てられる

## エラー情報
### 症状の詳細
- キーボード表示時に画面の上部に余白が発生
- 入力フィールドがキーボードの下に隠れる、または表示領域から逸脱
- スクロールによってのみ内容へのアクセスが可能になる

## 調査した内容
### 推定原因
`lib/main.dart` の `MaterialApp.builder` で使用されている `InteractiveViewer` が、キーボード表示時のレイアウト計算に干渉している可能性

### 技術的考察
1. **InteractiveViewer の影響**
   - パン・ズーム機能を提供するウィジェット
   - クリップ処理（clipBehavior）がキーボード表示時のリサイズ計算に影響
   - 親コンテナとしての制約が子要素に過剰に適用される可能性

2. **Scaffold の設定**
   - `resizeToAvoidBottomInset` のデフォルト値（true）
   - キーボード表示時の自動リサイズ挙動との競合

3. **レイアウトツリーの制約**
   - InteractiveViewer が適用するボクシング処理
   - メインウィンドウの制限との相互作用

## 既知のファイル
- `lib/main.dart`: InteractiveViewer の実装場所
- `lib/screens/screen_st_stocktake_input.dart`: 影響を受ける入力画面の一例
- `lib/screens/screen_iv_invoice_input.dart`: 請求書入力画面

## 関連リソース
- Flutter ドキュメント：InteractiveViewer
- Flutter ドキュメント：Scaffold.resizeToAvoidBottomInset
- メインウィンドウ設定：lib/main.dart の builder パターン
