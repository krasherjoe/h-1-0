# 案件パイプライン＆タスク管理 — 実装仕様書

**作成日**: 2026-05-21  
**対象画面**: PJ1（案件一覧）、PJ2（案件詳細）  
**DB変更**: v33 → v34  
**ステータス**: 🟡 設計完了・実装待ち

---

## 1. 背景・要件

### ユーザー要求
「営業アシスト機能として、見積〜入金までのパイプライン管理と、  
長期案件（Web/アプリ開発）向けのマイルストーン・タスク・工数管理が欲しい」

### 対象業務
- **短期案件（商品販売）**: 見積→受注→発注→発送→着荷確認→請求→入金
- **長期案件（開発業務）**: 提案→契約→要件定義→設計→開発中→テスト→検収→請求→入金
- 1案件に複数の伝票（分割請求など）が紐付く構造は既存のまま維持

---

## 2. 現行PJ1/PJ2の状態

### ファイルパス
- `lib/screens/screen_pj1_project_list.dart` — 案件一覧（フラットリスト + FilterChip）
- `lib/screens/screen_pj2_project_detail.dart` — 案件詳細（伝票紐付け一覧）
- `lib/models/project_model.dart` — Projectモデル・ProjectStatusEnum
- `lib/services/project_repository.dart` — CRUD操作

### 現行 ProjectStatus（要変更）
```dart
enum ProjectStatus {
  active,    // 進行中
  won,       // 成約
  lost,      // 失注
  suspended, // 保留
}
```
→ これを**案件種別別パイプラインステージ**に置き換える

### 現行 Projectモデルフィールド
```dart
String id, name;
String? customerId, customerName, notes;
ProjectStatus status;
DateTime? startDate, endDate;
double totalAmount; // 集計値（computed）
```

---

## 3. 新データモデル設計

### 3-1. Project（拡張）

```dart
enum ProjectType {
  sales,       // 商品販売（短期）
  development, // Web/アプリ開発（長期）
  other,       // その他
}

class Project {
  // 既存フィールドはすべて維持
  final String id, name;
  final String? customerId, customerName, notes;
  final DateTime? startDate, endDate;

  // 追加フィールド
  final ProjectType type;         // 案件種別（デフォルト: sales）
  final String pipelineStage;     // 現在のステージ名（文字列で柔軟に管理）
  final int progress;             // 進捗率 0〜100
}
```

### 3-2. パイプラインステージ定義（定数）

```dart
// lib/models/pipeline_stages.dart

const kSalesStages = [
  '見積',
  '受注',
  '発注',
  '発送',
  '着荷確認',
  '請求',
  '入金済',
];

const kDevStages = [
  '提案',
  '契約',
  '要件定義',
  '設計',
  '開発中',
  'テスト',
  '検収',
  '請求',
  '入金済',
];

// ProjectTypeからステージリストを取得
List<String> stagesFor(ProjectType type) {
  switch (type) {
    case ProjectType.sales: return kSalesStages;
    case ProjectType.development: return kDevStages;
    case ProjectType.other: return kSalesStages; // デフォルト
  }
}
```

### 3-3. Milestone（新規）

```dart
// lib/models/milestone_model.dart
class Milestone {
  final String id;
  final String projectId;
  final String title;
  final DateTime? dueDate;
  final DateTime? completedDate;
  final int sortOrder;

  bool get isCompleted => completedDate != null;
}
```

### 3-4. Task（新規）

```dart
// lib/models/task_model.dart
enum TaskStatus { todo, doing, done }

class Task {
  final String id;
  final String projectId;
  final String? milestoneId;    // nullなら案件直下
  final String title;
  final TaskStatus status;
  final DateTime? dueDate;
  final double estimatedHours;  // 見積工数（0=未設定）
  final double actualHours;     // 実績工数（集計）
  final int sortOrder;
}
```

### 3-5. TimeLog（新規）

```dart
// lib/models/time_log_model.dart
class TimeLog {
  final String id;
  final String taskId;
  final String projectId;
  final DateTime date;
  final double hours;           // 例: 1.5 = 1時間30分
  final String? memo;
}
```

---

## 4. DB マイグレーション（v33 → v34）

`lib/services/database_helper.dart` の `onUpgrade` に追記：

```dart
if (oldVersion < 34) {
  // 1. projects テーブルに新カラム追加
  await db.execute("ALTER TABLE projects ADD COLUMN type TEXT NOT NULL DEFAULT 'sales'");
  await db.execute("ALTER TABLE projects ADD COLUMN pipeline_stage TEXT NOT NULL DEFAULT '見積'");
  await db.execute("ALTER TABLE projects ADD COLUMN progress INTEGER NOT NULL DEFAULT 0");

  // 既存データの status → pipeline_stage 変換
  await db.execute("""
    UPDATE projects SET pipeline_stage = CASE status
      WHEN 'active'    THEN '進行中'
      WHEN 'won'       THEN '入金済'
      WHEN 'lost'      THEN '失注'
      WHEN 'suspended' THEN '保留'
      ELSE '見積'
    END
  """);

  // 2. milestones テーブル
  await db.execute('''
    CREATE TABLE milestones (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      title TEXT NOT NULL,
      due_date TEXT,
      completed_date TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES projects(id)
    )
  ''');

  // 3. tasks テーブル
  await db.execute('''
    CREATE TABLE tasks (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      milestone_id TEXT,
      title TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'todo',
      due_date TEXT,
      estimated_hours REAL NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES projects(id),
      FOREIGN KEY (milestone_id) REFERENCES milestones(id)
    )
  ''');

  // 4. time_logs テーブル
  await db.execute('''
    CREATE TABLE time_logs (
      id TEXT PRIMARY KEY,
      task_id TEXT NOT NULL,
      project_id TEXT NOT NULL,
      date TEXT NOT NULL,
      hours REAL NOT NULL,
      memo TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (task_id) REFERENCES tasks(id),
      FOREIGN KEY (project_id) REFERENCES projects(id)
    )
  ''');
}
```

**⚠️ 重要**: `database_helper.dart` の `version:` を **33 → 34** に変更すること。

---

## 5. 画面設計

### 5-1. PJ1（案件一覧）→ カンバンボード化

**レイアウト**: 横スクロール可能なカラム群

```
AppBar: PJ1:案件管理  [＋新規]  [販売|開発 切り替えタブ]

[見積(2)]  [受注(3)]  [発注(1)]  ...  [入金済(1)]
─────────  ─────────  ─────────       ─────────
 案件A      案件B      案件E           案件G
 得意先X    得意先Y    得意先Z
 ¥100,000

 案件C
 得意先W
```

**実装ポイント**:
- `PageView` or `SingleChildScrollView(scrollDirection: Axis.horizontal)` でカラム横スクロール
- 各カラムは `SizedBox(width: 220)` + 内部縦スクロール
- カラムヘッダー: ステージ名 + 件数バッジ
- カードタップ → PJ2詳細へ
- カードロングプレス → ステージ変更ボトムシート（ドラッグDrag&Dropは後回し可）
- `ProjectType` タブ（販売/開発）でステージ列が切り替わる

### 5-2. PJ2（案件詳細）→ 大幅拡張

**セクション構成**（タブ or アコーディオン）:

```
① 概要  → 既存情報 + 種別/ステージ/進捗バー
② 伝票  → 既存: 見積・請求書・売上の一覧
③ タスク → マイルストーン別タスクリスト + チェックボックス
④ 工数  → タスク別工数入力・合計表示
```

**③ タスクセクション UI**:
```
[マイルストーン1: 要件定義] ──────────── 期日: 6/1 ✅
  ☑ ヒアリングシート作成
  ☑ 仕様書ドラフト
  ☐ クライアント確認 [期日: 5/30]

[マイルストーン2: 設計] ──────────────── 期日: 7/1
  ☐ ワイヤーフレーム
  ☐ DB設計

[＋マイルストーン追加]
```

---

## 6. 実装フェーズ（推奨順序）

### Phase A: DB拡張（前提作業）
1. `database_helper.dart` バージョン 33→34、マイグレーション追加
2. `project_model.dart` に `type`, `pipelineStage`, `progress` 追加
3. `project_repository.dart` の CRUD更新
4. `pipeline_stages.dart` 定数ファイル作成

### Phase B: モデル・リポジトリ（新規）
1. `milestone_model.dart` 作成
2. `task_model.dart` 作成
3. `time_log_model.dart` 作成
4. `milestone_repository.dart` 作成（CRUD）
5. `task_repository.dart` 作成（CRUD）
6. `time_log_repository.dart` 作成（CRUD）

### Phase C: PJ2拡張（タスク機能）
1. PJ2に「概要」タブ追加（ステージ変更UI・進捗スライダー）
2. PJ2に「タスク」タブ追加（マイルストーン＋タスクリスト）
3. PJ2に「工数」タブ追加（時間入力・合計）

### Phase D: PJ1カンバン化
1. フラットリストをカンバンボードUIに変更
2. タイプ別タブ（販売/開発）の実装
3. ステージ変更ボトムシート実装

### Phase E: 伝票連携（自動ステージ更新）
1. 見積書作成時 → 対応案件の pipelineStage を「見積」へ
2. 請求書発行時 → 「請求」へ自動更新

---

## 7. コーディング規則（本プロジェクト固有）

```
画面ID: PJ1（案件一覧）, PJ2（案件詳細）— 変更なし
新リポジトリはすべて lib/services/ に配置
新モデルはすべて lib/models/ に配置
非同期後は if (!mounted) return; 必須
コミットメッセージは日本語のみ
```

---

## 8. 注意事項・リスク

| リスク | 対策 |
|-------|------|
| 既存 ProjectStatus enum を参照している箇所が壊れる | grep で全参照を確認後、段階移行 |
| DB マイグレーション失敗でアプリ起動不能 | 実機テスト前にアンインストール→再インストールで検証 |
| PJ2が巨大化してファイル分割必要 | タブごとに `_PJ2OverviewTab`, `_PJ2TaskTab` 等のWidgetクラスに分割 |
| カンバンの横スクロールがスマホで狭い | カラム幅 210〜240px、最低2.2カラム見えるよう設計 |

---

## 9. 引き継ぎ用プロンプト（次のAIへ）

```
あなたは Flutter アプリ「販売アシスト1号」の開発を引き継ぐ AI です。
まず以下を順番に読んでください：

1. AGENTS.md（コーディング規則・必須ルール）
2. HANDOFF.md（プロジェクト概要・直近変更）
3. docs/tasks/PROJECT_PIPELINE_SPEC.md（★今回の実装仕様）
4. lib/models/project_model.dart（現行モデル確認）
5. lib/services/database_helper.dart（DB構造確認、現在 v33）

今回の実装タスク：
「案件パイプライン＆タスク管理機能」を上記 SPEC の Phase A → B → C → D → E の順で実装してください。

必須遵守事項：
- コミットは日本語のみ
- 画面IDは既存と重複しないこと（SCREEN_IDS.md 参照）
- DB変更時は version を 34 に上げること
- 非同期後は mounted チェック必須
- 1フェーズ完了ごとに flutter analyze --no-fatal-infos を実行してエラーなし確認
- ファイルパスは絶対パスで記述

不明点はユーザーに質問してから実装してください。
```
