# 次のタスク

**最終更新**: 2026-03-08 21:37

---

## 🎯 今すぐ実行するタスク

### タスクID: STAGE-IV
**タスク名**: 在庫オペレーション強化 + BusinessProfile Lite  
**優先度**: 🔴 高  
**担当**: SWE1.5  
**推定時間**: 8時間  
**状態**: 🚧 実装予定

---

## 📝 タスク概要

在庫モジュールの運用レベルを強化し、今後の業種カスタマイズ（Phase1）に繋がる BusinessProfile Lite を実装する。倉庫ロケーション、棚卸・移動履歴、業種別の必要機能フラグを整備し、集計分析の精度をさらに高める。

### 背景

- `docs/PROJECT_MASTER_PLAN.md` の Phase0 残タスク「Stage J: 在庫オペレーション強化」が未着手。  
- `docs/05_FUTURE_PLANS.md` Phase1 の BusinessProfile/CustomField 計画に向け、軽量なプロファイル管理を先行実装したい。  
- STAGE-III で集計分析は整備済。正確な在庫データと業種情報が揃えば、分析価値が向上する。

---

## 🎯 対象ファイル

### モデル/サービス/DB
1. `lib/models/business_profile_model.dart`（新規）  
2. `lib/services/business_profile_repository.dart`（新規）  
3. `lib/services/inventory_repository.dart`（既存拡張：ロケーション/移動API）  
4. `lib/services/database_helper.dart`（DBスキーマ更新：`business_profiles`, `inventory_locations`, `inventory_movements`）

### 画面/ウィジェット
1. `lib/screens/business_profile_screen.dart`（新規：業種設定画面、ID: B1）  
2. `lib/screens/inventory_location_screen.dart`（新規：ロケーション管理、ID: I4）  
3. `lib/screens/inventory_movement_screen.dart`（新規：棚卸/移動登録、ID: I5）  
4. `lib/screens/inventory_management_screen.dart`（既存：ロケーション列/最新棚卸日の表示追加）  
5. `lib/widgets/inventory_forms.dart`（新規：共通フォームコンポーネント）

### メニュー/ルーティング/設定
1. `lib/constants/menu_catalog.dart`（在庫オペレーション系メニュー追加）  
2. `lib/screens/dashboard_screen.dart`（新ルート登録）  
3. `lib/screens/settings_screen.dart`（業種設定エントリ追加）

---

## 📋 実行手順

1. **BusinessProfile Lite 基盤**  
   - モデル/リポジトリ/DBテーブルを実装し、設定画面（B1）からCRUD可能にする。  
   - プロファイルには業種ID、GPS要否、写真要否、在庫ロケーション利用有無等のフラグを持たせる。  
2. **在庫ロケーション＆移動データ層**  
   - `inventory_locations` と `inventory_movements` を追加し、リポジトリでCRUDとロケーション別集計を提供。  
3. **UI/UX強化**  
   - I4: ロケーション管理画面、I5: 在庫移動（棚卸）画面を実装。AppBarは2文字ID + タイトル。  
   - 既存在庫画面にロケーション列、最新棚卸日、業種フラグに応じたUI表示を追加。  
4. **接続とナビゲーション**  
   - メニュー、ダッシュボード、設定画面から新規画面へ遷移可能にする。  
5. **検証**  
   - `flutter analyze`（既存lintは別タスク扱いだが、新規差分は0件）  
   - `flutter test`（在庫/業種関連の新テストを含む）  
   - `flutter build apk --debug`

---

## ✅ 完了条件

- [ ] BusinessProfile Lite（モデル/リポジトリ/設定画面）が動作  
- [ ] 在庫ロケーション管理（I4）と棚卸/移動記録（I5）が追加され、データが保存される  
- [ ] 在庫一覧でロケーション列・最新棚卸日が表示される  
- [ ] メニュー/ダッシュボード/設定から新画面へアクセスできる  
- [ ] DBスキーママイグレーションが追加される（例: version 38）  
- [ ] `flutter analyze`（新規差分で警告/エラーなし）  
- [ ] `flutter test` すべてパス  
- [ ] `flutter build apk --debug` 成功  
- [ ] `docs/PROGRESS.md` にSTAGE-IV完了を追記し、日本語コミット実施

---

## 🔄 完了後の次タスク

このタスク完了後、`docs/NEXT_TASK.md` を次のタスクに更新：

**次のタスク**: TBD

---

## 📚 参考ドキュメント

- `docs/PROJECT_MASTER_PLAN.md` Phase0 > Stage J  
- `docs/05_FUTURE_PLANS.md` Phase1（BusinessProfile/CustomField）  
- 既存在庫関連: `lib/screens/inventory_management_screen.dart`, `lib/services/inventory_repository.dart`  
- 集計参考: `lib/screens/analytics_dashboard_screen.dart`

---

## 🚀 開始方法

```
1. docs/NEXT_TASK.md（本ファイル）と docs/tasks/STAGE-III.md を確認
2. BusinessProfile Lite のモデル/DBを実装
3. 在庫ロケーション/移動機能 → UI → メニュー/ルートの順で進める
```

---

## ⚠️ 注意事項

- すべての画面タイトルはユニークな2文字IDから開始するルールを遵守 
- 業種フラグに応じたUI分岐はまだ限定的にし、後続フェーズで拡張できるよう拡張性を残す  
- データベースマイグレーションは既存バージョンからのアップグレード手順を明記  
- 既存lintタスク（LINT-FIX-002）は本タスク完了後に別途対応する

---

## 📝 完了報告テンプレート

- BusinessProfile Lite 実装完了（モデル/リポジトリ/画面）  
- 在庫ロケーション & 棚卸/移動ワークフロー完了（I4/I5）  
- UI/メニュー/ルーティング更新完了  
- DBマイグレーション version 38 反映  
- `flutter analyze/test/build` OK  
- 日本語コミット完了  
- `docs/PROGRESS.md` へSTAGE-IV追記済

---

このタスク完了後は、`docs/TASK_QUEUE.md` の LINT-FIX-002 / TEST-ADD-001 の再優先付け、または Phase1 (業種カスタマイズ) の詳細設計へ移行する。

---

## 📚 参考ドキュメント

- `docs/PROJECT_MASTER_PLAN.md` Phase0 > Stage J  
- `docs/05_FUTURE_PLANS.md` Phase1（BusinessProfile/CustomField）  
- 既存在庫関連: `lib/screens/inventory_management_screen.dart`, `lib/services/inventory_repository.dart`  
- 集計参考: `lib/screens/analytics_dashboard_screen.dart`

---

## 🚀 開始方法

```
1. docs/NEXT_TASK.md（本ファイル）と docs/tasks/STAGE-III.md を確認
2. BusinessProfile Lite のモデル/DBを実装
3. 在庫ロケーション/移動機能 → UI → メニュー/ルートの順で進める
```

---

## ⚠️ 注意事項

- すべての画面タイトルはユニークな2文字IDから開始するルールを遵守 
- 業種フラグに応じたUI分岐はまだ限定的にし、後続フェーズで拡張できるよう拡張性を残す  
- データベースマイグレーションは既存バージョンからのアップグレード手順を明記  
- 既存lintタスク（LINT-FIX-002）は本タスク完了後に別途対応する

---

## 📝 完了報告テンプレート

- BusinessProfile Lite 実装完了（モデル/リポジトリ/画面）  
- 在庫ロケーション & 棚卸/移動ワークフロー完了（I4/I5）  
- UI/メニュー/ルーティング更新完了  
- DBマイグレーション version 38 反映  
- `flutter analyze/test/build` OK  
- 日本語コミット完了  
- `docs/PROGRESS.md` へSTAGE-IV追記済

---

このタスク完了後は、`docs/TASK_QUEUE.md` の LINT-FIX-002 / TEST-ADD-001 の再優先付け、または Phase1 (業種カスタマイズ) の詳細設計へ移行する。
