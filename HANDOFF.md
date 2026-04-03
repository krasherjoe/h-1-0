# 🤖 AI引き継ぎドキュメント

**最終更新**: 2026-03-07 13:30

## 📋 新規AIセッション開始手順

### ステップ1: 必須ドキュメント確認（この順序で）

1. **`README.md`** を読む
   - プロジェクト概要・技術スタック
   - コーディング規約・画面ID規則
   - AI向けクイックスタート（詳細な実装パターン）

2. **`TODO.md`** を読む ← **最重要**
   - 🔴緊急タスクの有無
   - 進行中タスクの引き継ぎ事項
   - 優先度別の未着手タスク一覧
   - 完了済みタスクの履歴

3. **このファイル（`HANDOFF.md`）** を読む
   - 現在のプロジェクト状態
   - 直近の変更点
   - 既知の問題・注意事項

### ステップ2: ユーザー指示を待つ

上記確認後、ユーザーからの指示を待ってください。

---

## 📊 現在のプロジェクト状態

### 🎯 開発目標
**実運用可能な品質を達成** - 実際の業務で運用テストできるレベル

### ✅ 完了済み（本稼働準備完了）

#### 1. BCC設定のスムーズ化
- ヘルプダイアログ（Gmail設定手順、SMTP設定例）
- プレースホルダー・ヘルプアイコン
- Gmailアカウント自動挿入

#### 2. PDF送信機能
- 見積・納品・請求・領収書のPDF生成
- SMTP/デバイスメーラー両対応
- BCC必須チェック

#### 3. Google Driveバックアップ・リストア
- 手動バックアップ（即時実行）
- 自動バックアップ（24時間ごと）
- リストア機能（最新バックアップから復元）
- 初回起動時リストア提案

### 🚧 次の優先タスク（`TODO.md`参照）

**🟡 中優先度**
1. Google連携のOAuth設定（開発者側：SHA-1フィンガープリント）
2. 在庫移動機能（倉庫間）
3. 棚卸入力画面
4. 請求書発行機能

---

## 🗂️ プロジェクト構造

```
/home/user/dev/h-1.flutter.0/
├── README.md          # プロジェクト全体概要、AI作業フロー、クイックスタート
├── TODO.md            # タスク管理（最重要、常に最新状態を確認）
├── HANDOFF.md         # このファイル（AI引き継ぎ専用）
├── lib/
│   ├── main.dart                              # エントリーポイント
│   ├── screens/                               # UI画面
│   │   ├── settings_screen.dart              # S1:設定
│   │   ├── email_settings_screen.dart        # SM:メール設定
│   │   ├── dashboard_screen.dart             # ダッシュボード
│   │   └── ...
│   ├── services/                              # ビジネスロジック
│   │   ├── database_helper.dart              # SQLite管理
│   │   ├── app_settings_repository.dart      # 設定永続化
│   │   ├── pdf_generator.dart                # PDF生成
│   │   ├── email_sender.dart                 # メール送信
│   │   ├── google_account_service.dart       # Google Sign-In
│   │   ├── drive_backup_service.dart         # Drive操作
│   │   └── auto_backup_service.dart          # 自動バックアップ
│   ├── models/                                # データモデル
│   └── widgets/                               # 再利用可能ウィジェット
└── .windsurf/plans/                           # 長期実装計画
```

---

## 💡 重要な実装ルール

### 1. 画面ID規則（絶対遵守）
- **全画面のAppBarタイトル**: `XX:画面名` 形式必須
- 例: `S1:設定`, `SM:メール設定`, `P1:商品マスター`
- 新規画面追加時は既存IDと重複しないこと

### 2. Git運用
- **コミットメッセージは必ず日本語**
- 1行目: 変更内容の要約（50文字以内）
- 3行目以降: 詳細説明（箇条書き推奨）

### 3. 非同期処理
- 重い処理は `Future.microtask()` で起動をブロックしない
- Widget操作前に `if (!mounted) return;` チェック

### 4. エラーハンドリング
- すべてのDB操作・Google API呼び出しは try-catch
- ユーザーに `SnackBar` でエラー通知

---

## 🔧 よく使う技術情報

### データベース
- **ファイル**: `gemi_invoice.db`
- **場所**: `getDatabasesPath()` の返り値
- **バックアップ先**: Google Drive `SalesAssist Backups/<clientId>/`

### Google連携
- **認証**: `GoogleAccountService.instance`
- **必須スコープ**: email, gmail.modify, drive.file, spreadsheets, calendar.events
- **制限事項**: OAuth 2.0 Client ID設定が必要（SHA-1フィンガープリント）

### メール送信
- **SMTP**: Gmail推奨（アプリパスワード16桁）
- **BCC**: カンマ区切りで複数指定可能
- **設定画面**: `lib/screens/email_settings_screen.dart`

---

## ⚠️ 既知の問題・注意事項

### 1. Google OAuth未設定
- **状態**: SHA-1フィンガープリント未登録
- **影響**: Google Sign-In機能が動作しない
- **回避策**: エンドユーザーはGmailアプリパスワード使用を推奨
- **対応**: 開発者側でGoogle Cloud Console設定が必要

### 2. 初回起動時のリストア提案
- **動作**: DBが50KB未満 & バックアップ存在時にダイアログ表示
- **フラグ**: `first_launch_restore_checked` で1回のみ表示
- **リセット**: `AutoBackupService.resetFirstLaunchCheck()` 呼び出し

### 3. アプリ有効期限
- **デフォルト**: ビルドから90日間
- **設定**: `scripts/build_with_expiry.sh` で `APP_BUILD_TIMESTAMP` 付与
- **延長**: 母艦同期で自動延長予定（未実装）

---

## 📝 最近の主要変更（直近3セッション）

### 2026-03-07 セッション（コミット: 255859c, 90fa9d7, 73f7cea）

#### 変更内容
1. **プロジェクト管理基盤整備**
   - `TODO.md` 作成（AIタスク管理最適化）
   - `README.md` にプロジェクト管理方針追加

2. **BCC設定UI改善**
   - ヘルプダイアログ2種（BCC設定ガイド、SMTP設定例）
   - 全入力欄にプレースホルダー
   - ヘルプアイコン追加

3. **Google Drive完全対応**
   - 手動バックアップ機能
   - 自動バックアップ（24時間ごと）
   - リストア機能（最新バックアップから復元）
   - 初回起動時リストア提案

#### 影響範囲
- `lib/main.dart`: 自動バックアップチェック、初回リストア提案
- `lib/screens/settings_screen.dart`: バックアップ/リストアUI
- `lib/screens/email_settings_screen.dart`: BCC設定UI改善
- `lib/services/auto_backup_service.dart`: 新規作成
- `lib/services/drive_backup_service.dart`: リストアメソッド追加

---

## 🚀 次のセッションで取り組むべきこと

### 推奨タスク（優先度順）

1. **在庫移動機能（倉庫間）実装** 🟡中
   - 関連: 新規画面作成、DB操作
   - 画面ID候補: `IM:在庫移動`

2. **Google OAuth設定完了** 🟡中
   - 開発者側タスク（SHA-1登録）
   - ユーザー確認必要

3. **棚卸入力画面作成** 🟡中
   - 関連: 新規画面作成
   - 画面ID候補: `IC:棚卸入力`

**※ユーザーからの指示を最優先してください**

---

## 📞 困ったときの対処法

### Q: タスクの優先度が不明
→ `TODO.md` の優先度マーク（🔴🟡🟢）を確認、ユーザーに質問

### Q: 既存コードの場所が不明
→ `README.md` の「AI向けクイックスタート」セクション参照

### Q: 実装パターンが不明
→ `README.md` の「よくある実装パターン」セクション参照

### Q: 画面IDが重複しないか不安
→ `TODO.md` の「画面ID割り当て済み」セクションで確認

### Q: エラーが出て進まない
→ `flutter analyze` 実行、エラー内容をユーザーに報告

---

## ✅ セッション終了時のチェックリスト

- [ ] `TODO.md` を更新（進行中→完了、新規タスク追加）
- [ ] 変更をコミット（日本語メッセージ）
- [ ] 進行中タスクに引き継ぎ事項を記録
- [ ] ユーザーに完了内容を報告

---

**このドキュメントを読んだ後、`TODO.md` を確認してタスクに取り組んでください。**
