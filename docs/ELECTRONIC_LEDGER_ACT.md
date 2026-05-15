# 電子帳簿保存法 対応仕様書

**対象アプリ**: 販売アシスト 1 号（お局様サーバー）  
**バージョン**: 1.5.26+171 以降  
**最終更新**: 2026-05-16  

---

## 目次

1. [対象法令と適用範囲](#1-対象法令と適用範囲)
2. [要件マッピング](#2-要件マッピング)
3. [実装アーキテクチャ](#3-実装アーキテクチャ)
4. [データベース構造](#4-データベース構造)
5. [ハッシュチェーン仕様](#5-ハッシュチェーン仕様)
6. [タイムスタンプ保護](#6-タイムスタンプ保護)
7. [伝票ロック・訂正・削除](#7-伝票ロック訂正削除)
8. [活動ログ（監査証跡）](#8-活動ログ監査証跡)
9. [検索機能](#9-検索機能)
10. [PDF出力](#10-pdf出力)
11. [バックアップ・保存期間](#11-バックアップ保存期間)
12. [定期検証手順](#12-定期検証手順)
13. [改ざん検出時の対応手順](#13-改ざん検出時の対応手順)
14. [訂正・削除の正規手順](#14-訂正削除の正規手順)

---

## 1. 対象法令と適用範囲

### 対象法令

- **電子帳簿等保存（電帳法 第4条）**: 国税関係帳簿・書類をデジタルで作成・保存
- **電子取引データ保存（電帳法 第7条）**: 電子で授受した請求書・見積書等の保存

### 適用対象書類

| 書類種別 | 本アプリの対応帳票 |
|----------|------------------|
| 請求書 | `document_type = 'invoice'` |
| 見積書 | `document_type = 'estimate'` |
| 受注書 | `document_type = 'order'` |
| 納品書 | `document_type = 'delivery'` |
| 領収書 | `document_type = 'receipt'` |
| 仕入書 | `document_type = 'purchase'` |

---

## 2. 要件マッピング

### 真実性の確保（電帳法 規則第3条第1項）

| 法的要件 | 実装機能 | 実装ファイル |
|----------|---------|-------------|
| 訂正・削除の履歴が残ること | ロック済み伝票の上書き・削除禁止 + 赤伝による訂正履歴 | `lib/services/invoice_repository.dart` |
| 訂正・削除ができないシステム | `is_locked=1` の伝票は `saveInvoice` / `deleteInvoice` / `applyInboundSnapshot` すべてで例外をスロー | `lib/services/invoice_repository.dart` |
| ハッシュ値等による改ざん検出 | SHA-256 による `content_hash` / `meta_hash` / `document_hash` の3層保護 | `lib/services/hash_utils.dart`, `lib/services/electronic_ledger_repository.dart` |
| タイムスタンプ | `created_at` / `updated_at` + SharedPreferences + DBログの3層異常検出 | `lib/services/electronic_ledger_repository.dart` |

### 可視性の確保（電帳法 規則第3条第1項第2号）

| 法的要件 | 実装機能 | 実装ファイル |
|----------|---------|-------------|
| ディスプレイで明瞭に表示 | 各帳票画面での閲覧機能 | `lib/screens/invoice_history_screen.dart` |
| プリンタで印刷（PDF） | PDF生成・保存機能 | `lib/services/invoice_repository.dart`（`pdf`パッケージ） |
| 取引年月日で検索 | 日付範囲フィルター | `lib/screens/invoice_issue_screen.dart` |
| 取引金額で検索 | 全文検索 + 画面フィルター | `lib/services/full_text_search_service.dart` |
| 取引先で検索 | 全文検索（FTS5） | `lib/services/full_text_search_service.dart` |

### 保存期間（国税通則法 第74条の2）

| 帳簿種別 | 保存義務期間 | 本システムの設定 |
|----------|------------|----------------|
| 国税関係帳簿 | 7年 | `_retentionDays = 365 * 7`（`database_helper.dart`） |
| 国税関係書類 | 7年 | 同上 |

---

## 3. 実装アーキテクチャ

```
伝票入力 (invoice_input_screen.dart)
    │
    ▼
saveInvoice (invoice_repository.dart)
    │
    ├─ [1] ロック済みチェック → ロック済みなら例外スロー
    │
    ├─ [2] 正式発行時に is_locked = 1 をセット
    │       ＋ company_snapshot（会社情報スナップショット）
    │       ＋ content_hash（SHA-256 by 伝票内容）
    │       ＋ meta_json / meta_hash（メタデータハッシュ）
    │
    ├─ [3] invoices テーブルへ INSERT（conflictAlgorithm: replace）
    │
    ├─ [4] activity_logs へ SAVE_INVOICE ログ記録
    │
    ├─ [5] electronic_ledgers へ追記 INSERT（saveElectronicLedger）
    │       ＋ document_hash（SHA-256 v2: seq+時刻+データ+前ハッシュ）
    │       ＋ sequence_number（グローバルシーケンス）
    │       ＋ タイムスタンプ3層異常検出
    │
    └─ [6] Tail-5 ハッシュチェーン検証（異常時ログ記録）

起動時 (main.dart)
    └─ Tail-5 検証 → 異常時 HASH_CHAIN_BROKEN_ON_STARTUP ログ

設定画面 (settings_screen.dart)
    ├─ 直近5件ハッシュチェーン手動検証
    └─ 全件ハッシュチェーン手動検証
```

---

## 4. データベース構造

### `invoices` テーブル（電帳法関連フィールド）

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `is_draft` | INTEGER | 0=正式発行, 1=下書き |
| `is_locked` | INTEGER | **1=ロック済み（変更・削除禁止）** |
| `content_hash` | TEXT | 伝票内容の SHA-256 ハッシュ |
| `meta_json` | TEXT | メタデータ JSON（ID・顧客・日付・合計・会社情報・明細） |
| `meta_hash` | TEXT | `meta_json` の SHA-256 ハッシュ |
| `company_snapshot` | TEXT | 発行時点の会社情報スナップショット（JSON） |
| `company_seal_hash` | TEXT | 発行時点の社印ファイルの SHA-256 ハッシュ |
| `source_document_id` | TEXT | 赤伝の場合：元伝票 ID |
| `created_at` / `updated_at` | TEXT | ISO 8601 形式タイムスタンプ |

### `electronic_ledgers` テーブル

追記専用（`document_data` の UPDATE 禁止）の電子帳簿テーブル。

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `id` | TEXT | 行ID（`EL-{millis}-{random6}` 形式） |
| `document_id` | TEXT | 対応する伝票 ID |
| `document_type` | TEXT | 帳票種別（請求書・見積書等） |
| `document_data` | TEXT | 伝票データ全体 JSON（**変更禁止**） |
| `document_hash` | TEXT | SHA-256 v2 ハッシュ（seq+時刻+データ+前ハッシュ） |
| `previous_hash` | TEXT | 前バージョンの `document_hash`（チェーン連結） |
| `sequence_number` | INTEGER | グローバルシーケンス番号（ギャップ検出用） |
| `version` | INTEGER | バージョン番号（訂正履歴管理） |
| `is_current` | INTEGER | 1=最新バージョン |
| `is_active` | INTEGER | 0=論理削除（物理削除禁止） |
| `valid_from` / `valid_to` | TEXT | バージョン有効期間 |
| `metadata` | TEXT | ハッシュバージョン・シーケンス等のメタ情報（JSON） |

### `electronic_ledger_history` テーブル

更新時の旧バージョンを退避する冗長バックアップテーブル。

### `electronic_ledger_archive` テーブル

7年を超えた古いデータのアーカイブ先（元テーブルからは論理削除のみ、物理削除なし）。

### `activity_logs` テーブル

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `id` | TEXT | UUID |
| `action` | TEXT | アクション種別（下表参照） |
| `target_type` | TEXT | 操作対象種別（`INVOICE` 等） |
| `target_id` | TEXT | 操作対象 ID |
| `details` | TEXT | 詳細情報 |
| `timestamp` | TEXT | 操作日時（ISO 8601） |

**ログアクション種別**

| アクション | 意味 |
|-----------|------|
| `SAVE_INVOICE` | 伝票保存（正式発行） |
| `HASH_CHAIN_BROKEN` | Tail-5 検証で改ざん検出 |
| `HASH_CHAIN_BROKEN_ON_STARTUP` | 起動時検証で改ざん検出 |
| `ELECTRONIC_LEDGER_SAVE_ERROR` | 電子帳簿テーブルへの保存エラー |

---

## 5. ハッシュチェーン仕様

### 伝票ハッシュ（invoices テーブル）

#### `content_hash`
伝票本体内容のハッシュ。`Invoice.contentHash` ゲッターで算出。

```
content_hash = SHA-256(
  id + "|" + invoiceNumber + "|" + customerId + "|" +
  date.toIso8601() + "|" + totalAmount + "|" + documentType +
  items.map(i => i.productId + ":" + i.quantity + ":" + i.unitPrice).join(",")
)
```

#### `meta_hash`
メタデータ JSON の整合性ハッシュ。発行後に改ざんされていないか検証するための主要なフィールド。

```
meta_json = JSON.stringify({
  id, invoiceNumber, customer, date, total, documentType,
  hash, lockStatement, companySnapshot, companySealHash,
  items: [{productId, productName, quantity, unitPrice, subtotal, taxRate}]
})
meta_hash = SHA-256(meta_json)
```

### 電子帳簿ハッシュ（electronic_ledgers テーブル）

#### v2 ハッシュ（現行）
シーケンス番号と作成日時をハッシュ入力に含め、「ハッシュチェーンを壊さずに順序・時刻のみ改ざん」を防止。

```
document_hash = SHA-256(
  "v2" + "|" + sequenceNumber + "|" + createdAt + "|" +
  documentData + "|" + (previousHash ?? "")
)
```

#### v1 ハッシュ（旧バージョン互換）
```
document_hash = SHA-256(documentData + "|" + (previousHash ?? ""))
```

### Tail-N 検証

軽量なハッシュチェーン検証。直近 N 件のロック済み伝票について `meta_json` を SHA-256 で再計算し `meta_hash` と照合する。

- **実行タイミング**: ① アプリ起動時（Tail-5）、② 伝票保存時（Tail-5）、③ 設定画面で手動実行
- **全件検証**: 設定画面から手動実行可能

---

## 6. タイムスタンプ保護

`ElectronicLedgerRepository.saveElectronicLedger` / `updateElectronicLedger` 呼び出し時に 3 層でタイムスタンプ異常を検出する。

| レイヤー | 検出方法 | 信頼性 |
|---------|---------|--------|
| Layer 1 | SharedPreferences と現在時刻を比較（逆行検出） | 低（改ざん容易） |
| Layer 2 | DB ログ最新レコードの `updated_at` と比較（逆行検出） | 高（ハッシュチェーン保護） |
| Layer 3 | 過去10件のログ間隔中央値から許容範囲を算出し飛躍検出 | 中（統計的） |

いずれかの異常が検出された場合、`Exception` をスローして保存を中断する。エラーは `ELECTRONIC_LEDGER_SAVE_ERROR` として `activity_logs` に記録される（ベストエフォート継続）。

---

## 7. 伝票ロック・訂正・削除

### ロック機構

正式発行時（`isDraft = false` で `saveInvoice` を呼び出した時点）に `is_locked = 1` がセットされる。

**ロック後に禁止される操作**:

| 操作 | 実装箇所 | 挙動 |
|------|---------|------|
| 上書き保存 | `saveInvoice` | Exception スロー |
| 削除 | `deleteInvoice` | Exception スロー |
| 同期上書き | `applyInboundSnapshot` | サイレントスキップ（return） |

**エラーメッセージ例**:
```
ハッシュチェーン保護: ロック済み伝票 {id} は変更できません。
複写または新規IDで保存してください。

ハッシュチェーン保護: ロック済み伝票 {id} は削除できません。
訂正が必要な場合は赤伝（訂正伝票）を作成してください。
```

### 赤伝（訂正伝票）

元伝票を取り消す場合、**負の金額** で新規伝票を作成し、`source_document_id` に元伝票 ID を記録する。

```
訂正伝票: totalAmount < 0 かつ source_document_id = {元伝票ID}
```

これにより電帳法が要求する「訂正・削除の履歴」を追記形式で担保する。

### 物理削除の禁止

- **`electronic_ledgers`**: `is_active = 0` の論理削除のみ。物理 DELETE 禁止。
- **`invoices`**: ロック済みは物理削除禁止。ロック前の下書きのみ削除可能。

---

## 8. 活動ログ（監査証跡）

`ActivityLogRepository.logAction()` で全操作を `activity_logs` テーブルに記録する。

### 監査証跡として記録される操作

- 伝票の保存（正式発行）
- ハッシュチェーン異常検出（起動時・保存時）
- 電子帳簿テーブルへの保存エラー

### ログ確認方法

設定画面（`S1: 設定`）の「活動ログ」セクションから参照可能。

---

## 9. 検索機能

電帳法は「取引年月日」「取引金額」「取引先」の3条件での検索を要件とする。

| 検索軸 | 実装方法 | 備考 |
|--------|---------|------|
| **取引年月日** | 日付範囲フィルター（`_startDate` / `_endDate`） | `invoice_issue_screen.dart` 等の画面レベル実装 |
| **取引金額** | FTS5 全文検索（`full_text_search_service.dart`） | `invoice_history_screen.dart` 等で利用 |
| **取引先** | FTS5 全文検索（`invoices_fts` テーブル） | 取引先名で横断検索可能 |

### 全文検索インデックス（FTS5）

```sql
-- invoices_fts: 請求書の全文検索インデックス
SELECT i.*
FROM invoices i
JOIN invoices_fts ON i.id = invoices_fts.rowid
WHERE invoices_fts MATCH ?
ORDER BY invoices_fts.rank DESC
```

---

## 10. PDF出力

正式発行済み伝票の PDF を生成・保存する。

- **使用パッケージ**: `pdf: ^3.10.7`
- **保存先**: システムダウンロードフォルダ（`/storage/emulated/0/Download`）
- **ファイルパス**: `invoices.file_path` カラムに保存
- **会社情報**: 発行時点の `company_snapshot` から取得（後から会社情報が変わっても PDF 内容は不変）

---

## 11. バックアップ・保存期間

### 自動バックアップ（`LocalBackupService`）

| 設定値 | 内容 |
|--------|------|
| `_retentionDays = 365 * 7` | 保存期間: **7年間**（2555日） |
| `_backupPrefix = 'backup_'` | バックアップファイルプレフィックス |
| 整合性検証 | SHA-256 ハッシュファイル（`.sha256`）で検証 |
| 実行頻度 | 毎日（`_dailyBackupKey` で管理） |

### 保存期間ポリシー

```
保存期間満了（7年）→ electronic_ledger_archive テーブルへ移動
  ↓
元テーブルで is_current=0 に変更（物理削除禁止）
  ↓
アーカイブデータも永続保持（法的要件を満たす最低ラインの保護）
```

---

## 12. 定期検証手順

### アプリ起動時（自動）

アプリ起動時に `_verifyHashChainOnStartup()` が非同期実行される。

1. `InvoiceRepository().verifyTailN(n: 5)` を実行
2. 正常: `debugPrint('[HashChain] 起動時Tail-5検証OK ({件数}件)')`
3. 異常: `activity_logs` に `HASH_CHAIN_BROKEN_ON_STARTUP` を記録

### 手動検証（設定画面から）

設定画面（`S1: 設定` → ハッシュチェーン整合性検証セクション）

| ボタン | 内容 |
|--------|------|
| **直近5件を検証** | `verifyTailN(n: 5)` 実行。数ms で完了。 |
| **全件を検証** | `verifyAllLocked()` 実行。件数に応じて数秒かかる場合あり。 |

検証結果はダイアログで表示される。改ざん検出時は伝票IDのリストが表示される。

### 電子帳簿テーブルの整合性検証

`ElectronicLedgerRepository.verifyDataIntegrity()` により以下を検証：

1. 単体ハッシュ整合性（v1/v2両対応）
2. ハッシュチェーン連結整合性（`previous_hash` の連鎖確認）
3. シーケンス番号の連続性（同一ドキュメント内）
4. グローバルシーケンス番号のギャップ検出

---

## 13. 改ざん検出時の対応手順

### 検出経路

1. **起動時自動検出** → `activity_logs` に `HASH_CHAIN_BROKEN_ON_STARTUP` が記録される
2. **保存時自動検出** → `activity_logs` に `HASH_CHAIN_BROKEN` が記録される
3. **手動検証** → 設定画面のダイアログで改ざん伝票 ID が表示される

### 対応手順

```
1. 設定画面 → 活動ログ で HASH_CHAIN_BROKEN イベントを確認
   └─ target_id に改ざん伝票IDのカンマ区切りリストが記録されている

2. 改ざん伝票IDをメモし、証拠として activity_logs をエクスポート

3. バックアップから当該伝票の正規データを復元

4. 復元が不可能な場合、管轄税務署へ相談（国税庁ガイダンス参照）

5. 再発防止策：
   - デバイスのセキュリティ設定を確認
   - DBファイルへの直接アクセスを遮断
```

---

## 14. 訂正・削除の正規手順

### 訂正の場合

ロック済み伝票は変更できないため、赤伝（訂正伝票）を作成する。

```
1. 元伝票を開く
2. 「複写」機能で新規伝票を作成
3. 金額をマイナスに修正（取消仕訳）
4. source_document_id に元伝票IDを記録
5. 必要であれば、正しい内容で別途新規伝票を作成
```

これにより：
- 元伝票（`is_locked=1`）は変更されない → 電帳法上の訂正前記録保存
- 赤伝（`source_document_id` あり）が訂正履歴 → 電帳法上の訂正後記録保存

### 削除の場合

ロック済み伝票は物理削除できない。論理的な取消のみ可能。

```
1. 取消したい伝票に対して赤伝（訂正伝票）を作成（金額マイナス）
2. 元伝票は electronic_ledgers に保存されたまま残る
3. 必要に応じて is_active=0 で論理削除（税務調査時に提示義務あり）
```

---

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `lib/services/invoice_repository.dart` | 伝票保存・ロック・Tail-N検証・削除保護 |
| `lib/services/electronic_ledger_repository.dart` | 追記専用電子帳簿テーブル・タイムスタンプ保護 |
| `lib/services/activity_log_repository.dart` | 監査証跡ログ |
| `lib/services/hash_utils.dart` | SHA-256 ハッシュ計算ユーティリティ |
| `lib/services/database_helper.dart` | DBスキーマ・LocalBackupService（7年保存） |
| `lib/screens/settings_screen.dart` | 手動ハッシュチェーン検証UI |
| `lib/main.dart` | 起動時Tail-5自動検証 |
| `lib/services/full_text_search_service.dart` | 取引先・金額・日付の検索機能 |
