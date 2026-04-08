# TODO: キーボードせり上がり現象の根本解決

## 既知の問題
- 入力画面でキーボード表示時に空白が発生し、画面が切り捨てられる
- 複数スクリーンで発生しており、個別修正ではきりがない

## アクションアイテム
- [ ] InteractiveViewer のキーボード影響分析
- [ ] Scaffold の resizeToAvoidBottomInset 設定確認
- [ ] MaterialApp の builder パラメータ見直し
- [ ] 包括的解決策の実装と全画面テスト
