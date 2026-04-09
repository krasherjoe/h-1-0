# 販売アシスト1号 開発タスク

最終更新: 2026-04-09 15:30

## 🔴 緊急・高優先度

### 完了
- [x] Google 統合の復元とデータベース場所の変更 (2026-04-09, commit: fe6e875)
  - 関連：`lib/services/database_helper.dart`, `lib/screens/management_screen.dart`, `lib/services/google_api_service_base.dart`, `lib/services/google_account_service.dart`, `lib/services/drive_backup_service.dart`, `lib/services/gmail_sync_client.dart`, `lib/screens/settings_screen.dart`, `lib/services/app_settings_repository.dart`
  - 内容:
    - DB フォルダを `/storage/emulated/0/販売アシスト 1 号/` に変更
    - ファイル名を `gemi_invoice.db` → `販売アシスト 1 号.db` に変更（バージョン v33→v43）
    - `_migrateDatabaseIfNeeded()` 実装で既存データ移行対応
    - Google Drive バックアップ機能復元（drive_backup_service.dart, gmail_sync_client.dart）
    - Google API サービス基底クラス実装（google_api_service_base.dart）
    - Gmail Sync Client 互換性修正（getCurrentAccount() 追加）
    - 設定画面に Google 機能切替スイッチ追加（オン/オフ切り替え可能）
    - データ保管場所ドキュメント作成（データ保管場所_重要.md）

### 未着手
なし

## 🟡 中優先度

### 未着手

## 🟢 低優先度

- [ ] ダッシュボードカスタマイズ機能
- [ ] テーマカラー追加オプション
- [ ] 多言語対応検討

## ✅ 完了 (直近7日)

- [x] SUP/WH/STテンプレート画面実装 (2026-03-07)
  - 関連: `lib/screens/support_desk_screen.dart`, `lib/screens/warehouse_dashboard_screen.dart`, `lib/screens/staff_management_screen.dart`, `lib/constants/menu_catalog.dart`, `lib/screens/dashboard_screen.dart`
  - 内容:
    - SUP:サポート窓口管理画面（チケット管理テンプレート）を新規作成
    - WH:倉庫ダッシュボード画面（在庫状況可視化テンプレート）を新規作成
    - ST:スタッフ管理画面（スタッフ・権限管理テンプレート）を新規作成
    - メニューカタログに3画面を登録、ダッシュボード連携完了
    - `flutter test` で動作確認

- [x] 請求書発行機能実装 (2026-03-07)
  - 関連: `lib/screens/invoice_issue_screen.dart`, `lib/screens/dashboard_screen.dart`
  - 内容:
    - 請求書発行画面（IV）を新規追加
    - 未発行/発行済フィルタ、検索、期間フィルタを実装
    - Dashboardメニューと連携し、PDFプレビュー・正式発行まで完結
    - `flutter test` で動作確認

- [x] Google連携のOAuth設定完了（開発者側で実施） (2026-03-07)
  - 関連: `lib/services/google_account_service.dart`, `docs/google_oauth_setup.md`, `README.md`
  - 内容:
    - Google Cloud ConsoleでのOAuthクライアント登録手順・SHA-1取得方法をドキュメント化
    - READMEに詳細手順ドキュメントへの導線を追加
    - 設定画面の案内文と連携UIの確認手順を整理

- [x] 在庫移動機能（倉庫間）実装 (2026-03-07)
  - 関連: `lib/services/database_helper.dart`, `lib/models/stock_transfer_models.dart`, `lib/services/warehouse_stock_repository.dart`, `lib/services/stock_transfer_service.dart`, `lib/screens/stock_transfer_screen.dart`, `lib/screens/dashboard_screen.dart`
  - 内容:
    - 倉庫別在庫・在庫移動テーブルのマイグレーション追加
    - WarehouseStockRepository / StockTransferService 実装
    - IM:在庫移動画面を追加し、Dashboardからアクセス可能に
    - `flutter test` で動作確認

- [x] 棚卸入力画面作成 (2026-03-07)
  - 関連: `lib/screens/stocktake_input_screen.dart`, `lib/services/product_repository.dart`, `lib/screens/dashboard_screen.dart`
  - 内容:
    - 全商品リストの棚卸入力フォーム追加
    - 在庫数の検索・並び替え・一括保存
    - Dashboardメニューから遷移可能に対応

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

## 🔴 緊急・高優先度

### 進行中 - メール送信機能のリファクタリング（2026-04-07）

仕様変更：Gmail 直接制御と SMTP 送信機能を削除し、スマホ標準のメールアプリに委ねる方針に変更

**変更内容**:
- ✅ SMTP サーバー設定（ホスト、ポート、ユーザー、パスワード）をすべて削除
- ✅ Gmail アカウント連携機能とテスト送信機能を削除  
- ✅ TLS/証明書関連設定を削除
- ✅ BCC 設定のみを維持（端末メールアプリの控え用として必須）
- ✅ メールテンプレート（ヘッダー/フッター）は維持
- ⏳ 「メールで共有」ボタンはスマホ標準メーラーに委ねる実装へ変更

**関連ファイル**:
- `lib/screens/email_settings_screen.dart` - SMTP/Gmail 機能削除完了、BCC/テンプレートのみ維持（LSP エラー修正中）
- `lib/widgets/invoice_pdf_preview_page.dart` - SMTP 依存コード削除と share_plus 実装が必要
- `lib/services/google_account_service.dart` - Gmail 連携用、削除検討
- `lib/services/email_sender.dart` - SMTP 送信用、削除検討
- `pubspec.yaml` - google_sign_in 依存削除

**残タスク**:
1. [ ] email_settings_screen.dart の LSP エラー修正（_selectingBccFromDevice 変数未定義）
2. [ ] invoice_pdf_preview_page.dart の SMTP 依存コード削除と share_plus 実装
3. [ ] settings_screen.dart のメール設定画面へのリンク確認・更新
4. [ ] google_account_service.dart と email_sender.dart の削除/非推奨化
5. [ ] pubspec.yaml から不要な依存（google_sign_in など）を削除
6. [ ] flutter analyze でエラー確認・修正
7. [ ] git commit & push（日本語メッセージ）

**理由**:
- 既存実装が過度に複雑（email_settings_screen.dart は 979 行にも及んでいた）
- Google OAuth 設定の煩雑さから一般ユーザーにとって導入障壁が高かった
- スマホ標準のメールアプリで十分機能するため、依存関係を簡素化
- BCC 機能は取引先への送信控えとして必須のため維持

