# 実装タスクテンプレート集

**SWE1.5向け - コピー＆ペーストで使えるタスク定義**

**最終更新**: 2026-03-08

---

## 📋 使い方

1. 該当するテンプレートをコピー
2. `{}`部分を実際の値に置き換え
3. タスクとしてAIに渡す
4. チェックリストで進捗確認

---

## テンプレート1: 新規リスト画面追加

```markdown
## タスク: {画面名}画面の実装

### 概要
{この画面の目的を1-2行で説明}

例: 配送記録の一覧表示と管理を行う画面

### 仕様
- 画面ID: {2文字のID}（例: DL）
- 画面タイトル: {画面名}（例: 配送記録一覧）
- カテゴリ: {sales/master/inventory/analysis}
- アイコン: {Icons.xxx}（例: Icons.local_shipping）

### データモデル
- エンティティ名: {Delivery}
- 主要フィールド:
  - id: String
  - documentNumber: String
  - date: DateTime
  - customerId: String
  - address: String
  - status: DeliveryStatus
  - {その他必要なフィールド}

### 実装手順

#### 1. モデル作成
- ファイル: `lib/models/{delivery}_model.dart`
- BaseDocumentを継承
- toJson/fromJson実装
- 参考: `lib/models/quotation_model.dart`

#### 2. リポジトリ作成
- ファイル: `lib/services/{delivery}_repository.dart`
- CRUD操作実装（getAll, getById, insert, update, delete）
- 参考: `lib/services/quotation_repository.dart`

#### 3. データベーステーブル作成
- ファイル: `lib/services/database_helper.dart`
- バージョン: {34}（現在33なので+1）
- テーブル名: {deliveries}
- インデックス: date, customer_id
- 参考: `docs/CODING_GUIDE.md` パターン3

#### 4. 画面作成
- ファイル: `lib/screens/{delivery}_list_screen.dart`
- GenericListScreen<{Delivery}>を使用
- DocumentCardで表示
- 参考: `lib/screens/quotation_input_screen.dart`

#### 5. メニュー追加
- ファイル: `lib/constants/menu_catalog.dart`
- MenuDefinition追加
- 参考: `docs/CODING_GUIDE.md` パターン4

#### 6. ルート追加
- ファイル: `lib/screens/dashboard_screen.dart`
- import追加
- _getScreenにcase追加

### チェックリスト
- [ ] モデルクラス作成完了
- [ ] リポジトリクラス作成完了
- [ ] データベーステーブル作成完了
- [ ] 画面クラス作成完了
- [ ] メニューカタログ追加完了
- [ ] ダッシュボードルート追加完了
- [ ] `flutter analyze` エラー0件
- [ ] 画面表示確認
- [ ] データ保存・取得確認
- [ ] Gitコミット（日本語メッセージ）

### 参考ドキュメント
- `docs/CODING_GUIDE.md` - パターン1
- `lib/screens/quotation_input_screen.dart` - 類似実装
```

---

## テンプレート2: フォーム画面追加

```markdown
## タスク: {画面名}フォーム画面の実装

### 概要
{この画面の目的を1-2行で説明}

例: 配送記録の新規作成・編集を行うフォーム画面

### 仕様
- 画面ID: {DF}（例: DF）
- 画面タイトル: {配送記録入力}
- 編集モード対応: あり/なし
- 必須フィールド: {documentNumber, date, address}

### フォーム項目
1. {伝票番号} - TextFormField - 必須
2. {日付} - DatePicker - 必須
3. {配送先住所} - TextFormField - 必須
4. {備考} - TextFormField - 任意
5. {その他}

### 実装手順

#### 1. フォーム画面作成
- ファイル: `lib/screens/{delivery}_form_screen.dart`
- StatefulWidget
- FormKey使用
- バリデーション実装
- 参考: `docs/CODING_GUIDE.md` パターン2

#### 2. コントローラー定義
```dart
final _documentNumberController = TextEditingController();
final _addressController = TextEditingController();
// その他必要なコントローラー
```

#### 3. 保存処理実装
- try-catchでエラーハンドリング
- mounted チェック
- SnackBarで結果通知

#### 4. リスト画面からの遷移追加
- ファイル: `lib/screens/{delivery}_list_screen.dart`
- onAddハンドラーでNavigator.push

### チェックリスト
- [ ] フォーム画面作成完了
- [ ] 全フィールドのバリデーション実装
- [ ] 新規作成動作確認
- [ ] 編集動作確認
- [ ] エラーハンドリング確認
- [ ] `flutter analyze` エラー0件
- [ ] Gitコミット

### 参考ドキュメント
- `docs/CODING_GUIDE.md` - パターン2
- `lib/screens/customer_master_screen.dart` - 複雑なフォーム例
```

---

## テンプレート3: データベーステーブル追加のみ

```markdown
## タスク: {テーブル名}テーブルの追加

### 概要
{テーブルの目的}

例: 配送ルート情報を保存するテーブル

### テーブル仕様
- テーブル名: {delivery_routes}
- カラム:
  - id TEXT PRIMARY KEY
  - route_name TEXT NOT NULL
  - start_location TEXT
  - end_location TEXT
  - distance REAL
  - created_at TEXT
  - updated_at TEXT

### インデックス
- idx_{delivery_routes}_name ON {delivery_routes}(route_name)

### 実装手順

#### 1. バージョンアップ
- ファイル: `lib/services/database_helper.dart`
- `_databaseVersion` を {34} に変更

#### 2. マイグレーション追加
```dart
if (oldVersion < 34) {
  await db.execute('''
    CREATE TABLE {delivery_routes} (
      id TEXT PRIMARY KEY,
      route_name TEXT NOT NULL,
      start_location TEXT,
      end_location TEXT,
      distance REAL,
      created_at TEXT,
      updated_at TEXT
    )
  ''');
  
  await db.execute('''
    CREATE INDEX idx_{delivery_routes}_name 
    ON {delivery_routes}(route_name)
  ''');
}
```

### チェックリスト
- [ ] バージョン番号更新
- [ ] CREATE TABLE文追加
- [ ] インデックス作成
- [ ] `flutter analyze` エラー0件
- [ ] アプリ起動確認（マイグレーション実行）
- [ ] Gitコミット

### 参考ドキュメント
- `docs/CODING_GUIDE.md` - パターン3
```

---

## テンプレート4: 既存機能の修正

```markdown
## タスク: {機能名}の修正

### 概要
{何を修正するか}

例: 見積入力画面で顧客選択時にクラッシュする問題を修正

### 問題の詳細
{現在の問題}

例:
- 現象: 顧客選択時にアプリがクラッシュ
- エラーメッセージ: "Null check operator used on a null value"
- 発生箇所: `quotation_input_screen.dart` 123行目

### 原因
{問題の原因}

例: customer.nameがnullの場合の処理が不足

### 修正内容
{どう修正するか}

例: null安全演算子を使用してnullチェックを追加

### 実装手順

#### 1. 該当ファイルを開く
- ファイル: `lib/screens/{quotation_input_screen.dart}`
- 行: {123}

#### 2. 修正実施
```dart
// 修正前
Text(customer.name)

// 修正後
Text(customer.name ?? '名称未設定')
```

#### 3. 同様の問題がないか確認
- 同じファイル内の他の箇所
- 類似の画面

### チェックリスト
- [ ] 修正実施
- [ ] `flutter analyze` エラー0件
- [ ] 動作確認（修正箇所）
- [ ] 回帰テスト（関連機能）
- [ ] Gitコミット

### 参考ドキュメント
- `docs/CODING_GUIDE.md` - よくある間違い
```

---

## テンプレート5: 新規サービスクラス追加

```markdown
## タスク: {サービス名}サービスの実装

### 概要
{サービスの目的}

例: 配送ルート最適化サービス

### 仕様
- クラス名: {RouteOptimizationService}
- 主要メソッド:
  - {optimizeRoute}(List<Location> locations): Future<List<Location>>
  - {calculateDistance}(Location a, Location b): double

### 実装手順

#### 1. サービスクラス作成
- ファイル: `lib/services/{route_optimization}_service.dart`

```dart
class {RouteOptimization}Service {
  // シングルトンパターン（必要に応じて）
  static final {RouteOptimization}Service _instance = 
    {RouteOptimization}Service._internal();
  factory {RouteOptimization}Service() => _instance;
  {RouteOptimization}Service._internal();
  
  // メソッド実装
  Future<List<Location>> optimizeRoute(List<Location> locations) async {
    // 実装
  }
  
  double calculateDistance(Location a, Location b) {
    // 実装
  }
}
```

#### 2. 依存パッケージ追加（必要に応じて）
- ファイル: `pubspec.yaml`
- パッケージ: {google_maps_flutter}

#### 3. 使用例作成
```dart
final service = RouteOptimizationService();
final optimized = await service.optimizeRoute(locations);
```

### チェックリスト
- [ ] サービスクラス作成
- [ ] 全メソッド実装
- [ ] エラーハンドリング実装
- [ ] `flutter analyze` エラー0件
- [ ] 動作確認
- [ ] Gitコミット

### 参考ドキュメント
- `lib/services/gps_service.dart` - サービスクラス例
```

---

## テンプレート6: ウィジェット追加

```markdown
## タスク: {ウィジェット名}ウィジェットの実装

### 概要
{ウィジェットの目的}

例: 配送状況を表示するステータスバッジウィジェット

### 仕様
- ウィジェット名: {DeliveryStatusBadge}
- タイプ: StatelessWidget
- プロパティ:
  - status: DeliveryStatus（必須）
  - size: double（オプション、デフォルト: 24）

### 表示内容
- 配送前: 灰色、"未配送"
- 配送中: 青色、"配送中"
- 配送完了: 緑色、"完了"

### 実装手順

#### 1. ウィジェット作成
- ファイル: `lib/widgets/{delivery_status_badge}.dart`

```dart
import 'package:flutter/material.dart';

class {DeliveryStatusBadge} extends StatelessWidget {
  final DeliveryStatus status;
  final double size;
  
  const {DeliveryStatusBadge}({
    Key? key,
    required this.status,
    this.size = 24,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 実装
  }
  
  Color _getColor() {
    switch (status) {
      case DeliveryStatus.pending:
        return Colors.grey;
      case DeliveryStatus.inProgress:
        return Colors.blue;
      case DeliveryStatus.completed:
        return Colors.green;
    }
  }
  
  String _getLabel() {
    // 実装
  }
}
```

#### 2. 使用例
```dart
DeliveryStatusBadge(status: delivery.status)
```

### チェックリスト
- [ ] ウィジェットクラス作成
- [ ] 全ステータス対応
- [ ] constコンストラクタ使用
- [ ] `flutter analyze` エラー0件
- [ ] 表示確認
- [ ] Gitコミット

### 参考ドキュメント
- `lib/widgets/document_card.dart` - ウィジェット例
```

---

## 🎯 タスク実行の流れ

### 1. タスク受領
- テンプレートを選択
- `{}`を実際の値に置き換え

### 2. 実装
- 実装手順に従って順番に実施
- 各ステップ完了後にチェック

### 3. 確認
- `flutter analyze` 実行
- 動作確認
- チェックリスト完了

### 4. コミット
- 日本語でコミットメッセージ作成
- 変更内容を明確に記載

---

## 📝 コミットメッセージテンプレート

```
{画面名/機能名}を実装

- {主要な変更1}
- {主要な変更2}
- {主要な変更3}

関連: {画面ID}
```

例:
```
配送記録一覧画面を実装

- DeliveryモデルとRepositoryを作成
- GenericListScreenを使用して実装
- データベースバージョンを34に更新
- メニューカタログとダッシュボードに追加

関連: DL
```

---

## 🔍 トラブルシューティング

### エラー: "Table already exists"
- 原因: データベースバージョンが正しく更新されていない
- 解決: アプリをアンインストールして再インストール

### エラー: "No such table"
- 原因: マイグレーションが実行されていない
- 解決: バージョン番号を確認、アプリ再起動

### エラー: "Null check operator used on a null value"
- 原因: null安全性の問題
- 解決: `??` 演算子または `?.` 演算子を使用

---

このテンプレート集を使えば、SWE1.5でも迷わず実装できます！
