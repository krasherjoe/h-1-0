# LINT-FIX-002: lint警告修正（StatefulWidget変換）

**タスクID**: LINT-FIX-002  
**優先度**: 🔴 高  
**担当**: SWE1.5  
**推定時間**: 30分  
**作成日**: 2026-03-08

---

## 📝 タスク概要

残りのlint警告を修正する。具体的には、3つの画面ファイルを`StatelessWidget`から`StatefulWidget`に変換し、非同期処理後のUI更新前に`mounted`チェックを追加する。

### 背景
`quotation_input_screen.dart`で既に実施したのと同じパターンを適用します。lint警告は「StatelessWidgetのbuildメソッド内で非同期処理後にcontextを使用している」というもので、これはウィジェットが破棄された後にcontextを使用しようとする可能性があるため発生します。

---

## ✅ 前提条件確認

- [x] `quotation_input_screen.dart` が既に完了していることを確認
- [x] 同じパターンを適用できることを確認
- [ ] 対象ファイルが存在することを確認

---

## 🎯 対象ファイル

1. `lib/screens/order_input_screen.dart` - 受注入力画面
2. `lib/screens/sales_entry_screen.dart` - 売上入力画面
3. `lib/screens/sales_return_input_screen.dart` - 売上返品入力画面

---

## 📋 実行手順

### Step 1: order_input_screen.dart の変換

**ファイル**: `lib/screens/order_input_screen.dart`

#### 1-1. ファイルを読む
```bash
read_file lib/screens/order_input_screen.dart
```

#### 1-2. クラス定義を変更

**変更前**:
```dart
class OrderInputScreen extends StatelessWidget {
  const OrderInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
```

**変更後**:
```dart
class OrderInputScreen extends StatefulWidget {
  const OrderInputScreen({super.key});

  @override
  State<OrderInputScreen> createState() => _OrderInputScreenState();
}

class _OrderInputScreenState extends State<OrderInputScreen> {
  @override
  Widget build(BuildContext context) {
```

#### 1-3. mounted チェック追加箇所

以下の箇所に`if (!mounted) return;`を追加：

1. **onTap コールバック**（行35付近）
```dart
onTap: () {
  if (!mounted) return;  // ← 追加
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('受注詳細画面は今後実装予定です')),
  );
},
```

2. **コピーアクション**（行49付近）
```dart
onPressed: () async {
  try {
    await repo.copyOrder(order);
    if (!mounted) return;  // ← 追加
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('受注をコピーしました')),
    );
    onRefresh();
  } catch (e) {
    if (!mounted) return;  // ← 追加
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('コピーに失敗しました: $e')),
    );
  }
},
```

3. **受注変換アクション**（行60付近）
```dart
onPressed: () {
  if (!mounted) return;  // ← 追加
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('受注変換機能は今後実装予定です')),
  );
},
```

4. **削除アクション**（行100付近）
```dart
if (confirmed == true) {
  try {
    await repo.deleteOrder(order.id);
    if (!mounted) return;  // ← 追加
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('受注を削除しました')),
    );
    onRefresh();
  } catch (e) {
    if (!mounted) return;  // ← 追加
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('削除に失敗しました: $e')),
    );
  }
}
```

5. **onCreateNew**（行143付近）
```dart
onCreateNew: () async {
  if (!mounted) return;  // ← 追加
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('受注作成画面は今後実装予定です')),
  );
},
```

6. **emptyWidget.onAction**（行158付近）
```dart
onAction: () {
  if (!mounted) return;  // ← 追加
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('受注作成画面は今後実装予定です')),
  );
},
```

---

### Step 2: sales_entry_screen.dart の変換

**ファイル**: `lib/screens/sales_entry_screen.dart`

Step 1と同じパターンを適用：
1. クラス定義を`StatefulWidget`に変更
2. `_SalesEntryScreenState`クラスを作成
3. 非同期処理後のUI更新前に`if (!mounted) return;`を追加

**注意**: ファイル内の具体的な行番号や関数名は異なる可能性があるため、`quotation_input_screen.dart`を参考にしながら適切な箇所を特定してください。

---

### Step 3: sales_return_input_screen.dart の変換

**ファイル**: `lib/screens/sales_return_input_screen.dart`

Step 1と同じパターンを適用：
1. クラス定義を`StatefulWidget`に変更
2. `_SalesReturnInputScreenState`クラスを作成
3. 非同期処理後のUI更新前に`if (!mounted) return;`を追加

---

### Step 4: 確認

すべてのファイル変更後、以下のコマンドで確認：

```bash
cd /home/user/dev/h-1.flutter.0
flutter analyze
```

**期待結果**: エラー0件

---

### Step 5: 完了報告

`docs/PROGRESS.md` の末尾に追記：

```markdown
## 2026-03-08 LINT-FIX-002
- ✅ order_input_screen.dart: StatefulWidget変換完了
- ✅ sales_entry_screen.dart: StatefulWidget変換完了
- ✅ sales_return_input_screen.dart: StatefulWidget変換完了
- ✅ 全ファイルでmountedチェック追加完了
- ✅ flutter analyze: エラー0件
```

チャットにも同じ内容を報告：

```
LINT-FIX-002 完了

✅ order_input_screen.dart: StatefulWidget変換完了
✅ sales_entry_screen.dart: StatefulWidget変換完了
✅ sales_return_input_screen.dart: StatefulWidget変換完了
✅ 全ファイルでmountedチェック追加完了
✅ flutter analyze: エラー0件

次のタスク指示を待機します。
```

---

## ✅ 完了条件

- [ ] `order_input_screen.dart` をStatefulWidgetに変換
- [ ] `sales_entry_screen.dart` をStatefulWidgetに変換
- [ ] `sales_return_input_screen.dart` をStatefulWidgetに変換
- [ ] すべてのファイルでmountedチェックを適切に追加
- [ ] `flutter analyze` エラー0件
- [ ] `docs/PROGRESS.md` に完了報告を追記
- [ ] チャットに完了報告

---

## 🔧 トラブルシューティング

### エラー: "The getter 'mounted' isn't defined"
**原因**: StatelessWidgetのままになっている  
**解決**: クラス定義をStatefulWidgetに変更し、Stateクラスを作成

### エラー: "Context is used after being disposed"
**原因**: mountedチェックが不足している  
**解決**: 非同期処理（await）の直後、UI更新の直前に`if (!mounted) return;`を追加

### mountedの位置が不明
**原因**: どこに追加すべきか分からない  
**解決**: 以下のパターンを探す
```dart
await someAsyncOperation();
// ← ここに if (!mounted) return; を追加
ScaffoldMessenger.of(context).showSnackBar(...);
```

### 参考ファイルが見つからない
**原因**: quotation_input_screen.dartの場所が分からない  
**解決**: 
```bash
read_file lib/screens/quotation_input_screen.dart
```

---

## 📚 参考資料

### 必須
- **完了済みファイル**: `lib/screens/quotation_input_screen.dart`
- **クイックリファレンス**: `docs/QUICK_REF.md`

### 補足
- **コーディング規約**: `docs/CODING_GUIDE.md`
- **自動進行ルール**: `docs/AUTO_PROGRESS.md`

---

## 🔄 次のタスク

このタスク完了後、`docs/NEXT_TASK.md` を以下に更新：

**次のタスクID**: TEST-ADD-001  
**タスク名**: 単体テスト追加

---

このタスクを完了したら、必ず完了報告を行ってください。
