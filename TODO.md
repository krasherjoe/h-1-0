# 販売アシスト1号 開発タスク

最終更新: 2026-03-07 13:30

## 🔴 緊急・高優先度

### 進行中
なし

### 未着手
なし

## 🟡 中優先度

### 未着手
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

- [x] プロジェクト管理基盤整備 (2026-03-07, commit: 255859c)
  - 関連: `TODO.md`, `README.md`
  - 内容: TODO.md作成（AI管理用）、README.mdにプロジェクト管理方針追加

- [x] BCC設定UI改善 (2026-03-07, commit: 255859c)
  - 関連: `lib/screens/email_settings_screen.dart`
  - 内容: ヘルプダイアログ、プレースホルダー、ヘルプアイコン追加

- [x] Google Drive手動バックアップ機能追加 (2026-03-07, commit: 255859c)
  - 関連: `lib/screens/settings_screen.dart`, `lib/services/drive_backup_service.dart`
  - 内容: バックアップセクション、今すぐバックアップボタン、最終バックアップ日時表示

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

---

## 🔍 実装時のクイックリファレンス

### よく使うファイルパス
- DB管理: `lib/services/database_helper.dart`
- 設定保存: `lib/services/app_settings_repository.dart`
- PDF生成: `lib/services/pdf_generator.dart`
- メール送信: `lib/services/email_sender.dart`
- Google連携: `lib/services/google_account_service.dart`
- Driveバックアップ: `lib/services/drive_backup_service.dart`

### 技術スタック詳細
- **Flutter SDK**: 3.x
- **言語**: Dart
- **データベース**: SQLite (`sqflite` パッケージ)
- **状態管理**: StatefulWidget + setState
- **PDF**: `pdf` + `printing` パッケージ
- **メール**: `mailer` (SMTP) + `flutter_email_sender` (デバイス)
- **Google API**: `google_sign_in` + `googleapis`

### データベース情報
- **ファイル名**: `gemi_invoice.db`
- **主要テーブル**: customers, products, invoices, suppliers, warehouses
- **バックアップ先**: Google Drive (`SalesAssist Backups/<clientId>/`)

### 設定キー一覧（SharedPreferences）
- `smtp_host` - SMTPホスト名
- `smtp_port` - SMTPポート番号
- `smtp_user` - SMTPユーザー名
- `smtp_bcc` - BCC（カンマ区切り）
- `mail_send_method` - 送信方法（smtp/device_mailer）
- `last_backup_time` - 最終バックアップ日時
- `auto_backup_enabled` - 自動バックアップON/OFF

### 画面ID割り当て済み
- S1:設定, SM:メール設定
- P1:商品マスター, C1:得意先マスター, SI:仕入先マスター
- WH:倉庫マスター, ST:担当者マスター
- ES:見積入力, OR:受注入力
- IQ:在庫照会, CS:得意先別売上推移, PA:商品別粗利分析
- M1:マスター管理, D2:ダッシュボード設定, CH:母艦チャット

### デバッグコマンド
```bash
# コード検証
flutter analyze --no-fatal-infos

# アプリ再ビルド
flutter build apk --release

# 開発サーバー起動（ホットリロード）
flutter run

# DBリセット（開発時）
adb uninstall com.example.h_1
```

---

## 📚 関連ドキュメント

- **README.md**: プロジェクト全体概要、AI作業フロー、クイックスタート
- **TODO.md**: このファイル（タスク管理）
- **.windsurf/plans/**: 実装計画ファイル（長期タスク用）

---
