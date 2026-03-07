# 販売アシスト1号 開発タスク

最終更新: 2026-03-07 12:54

## 🔴 緊急・高優先度

### 進行中
なし

### 未着手
なし

## 🟡 中優先度

### 未着手
- [ ] Google Drive自動バックアップ実装
  - 起動時24時間経過チェック→自動実行
  - 最終バックアップ日時の表示
  - 自動バックアップON/OFF切り替え

- [ ] Google Driveリストア機能実装
  - 初回起動時の自動リストアチェック
  - 手動リストア機能
  - リストア前の確認ダイアログ

- [ ] Google連携のOAuth設定完了（開発者側で実施）
  - 関連: `lib/services/google_account_service.dart`
  - ブロッカー: SHA-1フィンガープリント登録が必要
  - メモ: エンドユーザーはGmailアプリパスワード推奨

- [ ] 在庫移動機能（倉庫間）実装
- [ ] 棚卸入力画面作成
- [ ] 請求書発行機能実装

## 🟢 低優先度

- [ ] ダッシュボードカスタマイズ機能
- [ ] テーマカラー追加オプション
- [ ] 多言語対応検討

## ✅ 完了 (直近7日)

- [x] S1:設定画面に戻るボタン追加 (2026-03-07)
  - 関連: `lib/screens/settings_screen.dart`
  - 内容: `automaticallyImplyLeading: false` を削除

- [x] メール設定のBCC欄にGmail自動挿入 (2026-03-07)
  - 関連: `lib/screens/email_settings_screen.dart`
  - 内容: `_pickBccFromDeviceAccount` メソッド改善、重複チェック、カーソル位置調整

- [x] 設定画面レイアウト改善（メール設定とGoogle連携を隣接配置） (2026-03-07)
  - 関連: `lib/screens/settings_screen.dart`
  - 内容: UI要素の並び順変更

- [x] Gmail API Label.labelId → Label.id修正 (2026-03-06)
  - 関連: `lib/services/gmail_sync_client.dart`
  - 内容: googleapis v13対応

- [x] 実装計画立案（本稼働品質への道筋） (2026-03-07)
  - 関連: `/home/user/.windsurf/plans/production-ready-implementation-c2736e.md`

## 📝 メモ・留意事項

### 開発ルール
- **Google連携**: 開発者向けオプション機能（一般ユーザーはGmailアプリパスワード使用を推奨）
- **画面ID規則**: 全画面タイトルに2文字ID必須（例: S1:設定、SM:メール設定）
- **Gitルール**: コミットメッセージは必ず日本語
- **セキュリティ**: アプリパスワードはデバイス暗号化ストレージで保護

### 技術スタック
- Flutter + Dart
- SQLite (sqflite) - DB: `gemi_invoice.db`
- Google APIs: `google_sign_in`, `googleapis` (Gmail, Drive, Sheets, Calendar)
- PDF生成: `pdf`, `printing`
- メール送信: `mailer` (SMTP), `flutter_email_sender` (デバイスメーラー)

### データバックアップ戦略
- 手動バックアップ: Google Drive経由
- 自動バックアップ: 起動時24時間経過で実行（実装予定）
- リストア: 初回起動時チェック（実装予定）

### 現在の目標
**実運用可能な品質を達成**
1. BCC設定がスムーズに完了できる
2. 見積・納品・請求・領収書のPDF送信が可能
3. データベースがGoogle Driveに自動バックアップされる
4. アプリ再インストール後もデータが引き継がれる

---

## 🔄 AI作業フロー

### セッション開始時
1. `README.md` でプロジェクト概要を把握
2. このファイル (`TODO.md`) で現在のタスク状況を確認
3. ユーザーからの指示を待つ

### 作業実施時
1. タスク開始時に該当項目を「進行中」に更新
2. コミット時は必ず日本語メッセージ
3. 関連ファイルをタスクに記録

### 作業完了時
1. 該当タスクを「✅完了」セクションに移動
2. 完了日とコミットハッシュを記録
3. 新たに発見したタスクがあれば追加

### セッション終了時
1. 「進行中」タスクに現在の状況を記録
2. 次のセッションへの引き継ぎ事項をメモ
