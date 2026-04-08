# キーボード対応ガイド

キーボード出現時に自動的にボタン類をキーボード上に配置する仕組みを提供します。

## 📋 概要

`lib/widgets/keyboard_aware_scaffold.dart` に以下のコンポーネントを提供：

- **KeyboardAwareScaffold**: キーボード対応の Scaffold ラッパー
- **KeyboardAwareFAB**: キーボード対応の FloatingActionButton
- **KeyboardAwareButtonBar**: キーボード対応のボタンコンテナ
- **KeyboardAwareTextField**: キーボード対応のテキストフィールド
- **KeyboardUtils**: キーボード操作のユーティリティ

## 🔧 使用方法

### 1. FloatingActionButton をキーボード上に配置

```dart
import 'package:flutter/material.dart';
import '../widgets/keyboard_aware_scaffold.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('画面名')),
      body: const Center(child: Text('コンテンツ')),
      floatingActionButton: KeyboardAwareFAB(
        onPressed: () {
          // ボタン処理
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
      ),
    );
  }
}
```

### 2. 拡張 FloatingActionButton（ラベル付き）

```dart
floatingActionButton: KeyboardAwareFAB(
  onPressed: () {},
  extended: true,
  icon: const Icon(Icons.add),
  label: const Text('選択'),
  backgroundColor: Colors.indigo,
),
```

### 3. ボタンバーをキーボード上に配置

```dart
KeyboardAwareButtonBar(
  padding: const EdgeInsets.all(16),
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    ElevatedButton(
      onPressed: () {},
      child: const Text('キャンセル'),
    ),
    ElevatedButton(
      onPressed: () {},
      child: const Text('確定'),
    ),
  ],
)
```

### 4. キーボード高さの取得

```dart
final keyboardHeight = KeyboardUtils.getKeyboardHeight(context);
final isVisible = KeyboardUtils.isKeyboardVisible(context);
```

### 5. キーボードを閉じる

```dart
KeyboardUtils.hideKeyboard(context);
```

## 📱 実装例

### 検索画面での使用

```dart
class SearchScreen extends StatefulWidget {
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('検索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '検索キーワード',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                // 検索結果
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: KeyboardAwareFAB(
        onPressed: () {
          // 検索処理
        },
        extended: true,
        icon: const Icon(Icons.search),
        label: const Text('検索'),
      ),
    );
  }
}
```

### 入力フォームでの使用

```dart
class FormScreen extends StatefulWidget {
  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('フォーム')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名前',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'メール',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: KeyboardAwareButtonBar(
        children: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              // 送信処理
            },
            child: const Text('送信'),
          ),
        ],
      ),
    );
  }
}
```

## ✨ 特徴

- **自動オフセット**: キーボード出現時に自動的にボタンがオフセット
- **スムーズなアニメーション**: 300ms のアニメーション付き
- **複数のコンポーネント**: FAB、ボタンバー、テキストフィールド対応
- **ユーティリティ関数**: キーボード操作を簡単に

## 🎯 推奨される使用箇所

- **検索画面**: 検索ボタンがキーボードの裏に隠れる問題を解決
- **入力フォーム**: 送信ボタンがキーボードの裏に隠れる問題を解決
- **顧客選択画面**: 「＋選択」ボタンがキーボードの裏に隠れる問題を解決
- **ダイアログ**: キーボード出現時のボタン配置を改善

## 📝 注意事項

- `resizeToAvoidBottomInset: true` を使用している場合、自動的にレイアウトが調整されます
- キーボード高さは `MediaQuery.of(context).viewInsets.bottom` で取得しています
- アニメーション時間は 300ms に固定されています（必要に応じて変更可能）
