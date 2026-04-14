# 顧客マスター HASH チェーン修復ツール

## 概要

このディレクトリには、顧客マスターの HASH チェーンを修復するためのスクリプトと関連ファイルが格納されています。

### 問題状況

- 同じ `display_name` の顧客が複数の ID で存在（フォーク事故）
- `content_hash` と `previous_hash` が正しく設定されていない、または断絶している
- HASH チェーンが無効になっているため、改ざん検出機能が機能しない

### 修復方針

1. 同じ `display_name` の顧客をグループ化
2. バージョン番号でソートして正しいチェーンを構築
3. 各レコードに適切な `content_hash` と `previous_hash` を設定
4. `is_current=1` のレコードは最新バージョンとして残す

---

## ファイル構成

```
workshops/repair_customer_hash_chain/
├── repair_customer_hash_chain.dart  # メイン修復スクリプト
├── README.md                        # このファイル
└── test_customers.db                # テスト用データベース（実行時に生成）
```

---

## 使用方法

### 1. テスト環境での動作確認

まずテスト用データベースで動作を確認します：

```bash
cd /home/user/code/h-1.flutter.0

# ダートパッケージの取得（必要な場合）
dart pub get

# スクリプトを実行
dart --enable-asserts workshops/repair_customer_hash_chain.dart
```

### 2. バックアップの作成

**本番環境で実行する前に必ずバックアップを作成してください：**

```bash
cd /home/user/code/h-1.flutter.0

# メインデータベースをバックアップ
cp data/gemi_invoice.db backups/customer_backup_$(date +%Y%m%d_%H%M%S).db
```

### 3. 本番環境での実行

スクリプト内の `kDatabasePath` を実際のパスに更新：

```dart
// workshops/repair_customer_hash_chain.dart の変更
const String kDatabasePath = 'data/gemi_invoice.db';  // 実際のパスに更新
```

その後、本番データベースで実行：

```bash
dart --enable-asserts workshops/repair_customer_hash_chain.dart
```

---

## スクリプトの詳細機能

### 1. 修復処理（`repairHashChain`）

- 同じ `display_name` の顧客をグループ化
- バージョン番号でソート
- 各レコードに正しい `content_hash` と `previous_hash` を設定
- `next_version_id` カラムがある場合、フォーク追跡用のリンクを設定

### 2. 整合性検証（`verifyHashChainIntegrity`）

- 修復後の HASH チェーンが正しいか検証
- 各レコードの `content_hash` が再計算値と一致するか確認
- `previous_hash` の連鎖が正しく続いているか確認

### 3. バックアップ機能

- 実行時に自動でバックアップを作成
- タイムスタンプ付きディレクトリに保存
- 最大 3 件のバックアップを保持

---

## HASH チェーン計算式

顧客の `content_hash` は以下の形式で計算されます：

```
SHA256(ID|display_name|formal_name|title|department|address|tel|email|
       contact_version_id|odoo_id|is_locked|is_hidden|head_char1|head_char2|
       valid_from|valid_to|is_current|version|previous_hash)
```

- `previous_hash` は前のバージョンの `content_hash`（最初のバージョンは空文字）
- 全フィールドを `|` で連結して SHA256 ハッシュ化

---

## 実行ログの例

```
[2024-08-15 10:30:00.000] === テスト環境 ===
[2024-08-15 10:30:00.100] テストデータベースを作成・初期化中...
[2024-08-15 10:30:00.200] customers テーブル作成完了
[2024-08-15 10:30:00.300] テストデータベース作成完了
[2024-08-15 10:30:00.400] テストデータを挿入中...
[2024-08-15 10:30:00.500] テストデータ挿入完了：6 件

修复前の顧客データ:
  - CUST-001-V1 (山田商店): ❌ 不正
  - CUST-001-V2 (山田商店): ❌ 不正
  - CUST-001-V3 (山田商店): ⚠️ 未設定
  - CUST-002 (鈴木商事): ⚠️ 未設定
  - CUST-003-V1 (高橋製作所): ❌ 不正
  - CUST-003-V2 (高橋製作所): ❌ 不正

HASH チェーン修復を開始します...
フォーク検出："山田商店" (3 件)
  - CUST-001-V1: 修復 (content_hash 不一致，previous_hash 不一致，)
  - CUST-001-V2: 修復 (content_hash 不一致，previous_hash 不一致，)
  - CUST-001-V3: 修復 (content_hash 不一致，previous_hash 不一致，)
フォーク検出："高橋製作所" (2 件)
  - CUST-003-V1: 修復 (content_hash 不一致，previous_hash 不一致，)
  - CUST-003-V2: 修復 (content_hash 不一致，previous_hash 不一致，)

=== 修复完了 ===
フォーク検出数：2
正常な顧客数：1
修复したレコード数：5

整合性チェック済み：6 件
エラー数：0
正常：6
✅ すべての顧客で HASH チェーンが正常に構築されています
```

---

## 注意事項

### ⚠️ 重要

1. **必ずバックアップを作成**
   - 修復処理は `UPDATE` のみですが、予期せぬ結果を防ぐため必ず事前にバックアップ
   - バックアップが実際に復元可能か確認すること

2. **テスト環境で動作確認**
   - 本番環境で実行する前に、テスト用データベースで必ず動作確認
   - スクリプトはデフォルトでテストモードで起動します

3. **本番環境での実行**
   - `kDatabasePath` を実際のパスに更新
   - バックアップディレクトリに十分な空き容量があることを確認

4. **ロールバック手順**
   ```bash
   # バックアップから復元
   cp backups/customer_hash_chain_repair_TIMESTAMP/customers_backup_TIMESTAMP.db data/gemi_invoice.db
   
   # アプリを再起動
   flutter run
   ```

---

## 技術的詳細

### 使用ライブラリ

- `sqflite`: SQLite データベース操作
- `crypto`: SHA256 ハッシュ計算
- `path`: ファイルパス操作

### HASH チェーン構造

```
バージョン 1: content_hash=H1, previous_hash=null
              ↓ (next_version_id="CUST-001-V2")
バージョン 2: content_hash=H2, previous_hash=H1
              ↓ (next_version_id="CUST-001-V3")
バージョン 3: content_hash=H3, previous_hash=H2, is_current=1
```

### エラーハンドリング

- データベース操作はすべて `try-catch` で囲む
- エラー発生時はロールバック可能に設計
- ログ出力で詳細な状態を把握可能

---

## 関連ドキュメント

- [README.md](../../README.md) - プロジェクト概要
- [TODO.md](../../TODO.md) - 開発タスク管理
- [lib/services/hash_utils.dart](../../lib/services/hash_utils.dart) - HASH 計算ユーティリティ
- [lib/services/database_helper.dart](../../lib/services/database_helper.dart) - データベース操作

---

## バージョン履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|----------|
| 1.0.0 | 2024-08-15 | 初版リリース - HASH チェーン修復機能実装 |

---

## ライセンス

このスクリプトはプロジェクト全体と同じライセンスに従います。
