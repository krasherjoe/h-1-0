# InteractiveViewer キーボード表示影響分析レポート

## 作成日
2026-04-08

## 概要
本レポートは、Flutter の `InteractiveViewer` ウィジェットがキーボード表示時に与える影響について、公式ドキュメントとプロジェクト内の実装を基に詳細に分析したものです。

---

## 1. InteractiveViewer のデフォルト挙動

### 1.1 clipBehavior のデフォルト値
**デフォルト値**: `Clip.hardEdge`

```dart
InteractiveViewer({
  // ... 省略 ...
  Clip clipBehavior = Clip.hardEdge,  // デフォルト値
  // ... 省略 ...
})
```

**影響**:
- `Clip.hardEdge` は、子ウィジェットが親の境界を超えて描画されないように硬性クリップを適用します
- キーボード表示時に `MediaQuery.viewInsets.bottom` が変化すると、InteractiveViewer のサイズ計算にクリップ処理が影響
- クリップ領域外の子要素は描画されず、ジェスチャーも受信できなくなる

**公式ドキュメント引用**:
> If set to Clip.none, the child may extend beyond the size of the InteractiveViewer, but it will not receive gestures in these areas. Be sure that the InteractiveViewer is the size of the area that should be interactive.

### 1.2 constrained のデフォルト値
**デフォルト値**: `true`

```dart
InteractiveViewer({
  // ... 省略 ...
  bool constrained = true,  // デフォルト値
  // ... 省略 ...
})
```

**影響**:
- `constrained: true` の場合、子ウィジェットは通常のサイズ制約（親のサイズ）を適用されます
- キーボード表示時に画面下部が圧縮されると、InteractiveViewer が子に与える制約も変化
- 子ウィジェットがキーボード表示に合わせてリサイズする際、InteractiveViewer の制約が干渉する可能性

**公式ドキュメント引用**:
> Whether the normal size constraints at this point in the widget tree are applied to the child.
> If set to false, then the child will be given infinite constraints.

### 1.3 キーボード表示時のレイアウト計算への影響

**レイアウトフローの連鎖**:
```
MediaQuery.viewInsets.bottom 増加
    ↓
Scaffold.body のサイズ制約が変化（resizeToAvoidBottomInset: true の場合）
    ↓
InteractiveViewer のサイズが再計算される
    ↓
constrained: true のため、子ウィジェットにも制限された制約が適用
    ↓
clipBehavior: Clip.hardEdge により、クリップ領域外は非表示
```

**問題の発生メカニズム**:
1. キーボードが表示されると `MediaQuery.viewInsets.bottom` がキーボードの高さ分増加
2. InteractiveViewer は親（MaterialApp）から受け取ったサイズ制約を子に伝播
3. `constrained: true` により、子ウィジェットは InteractiveViewer のサイズ以内に制限される
4. クリップ処理が適用されるため、表示領域外の子要素は視覚的に消える

---

## 2. Flutter のキーボード処理との相互作用

### 2.1 Scaffold.resizeToAvoidBottomInset との競合可能性

**プロジェクト内の現状**:
```dart
// lib/screens/stocktake_input_screen.dart
Scaffold(
  // resizeToAvoidBottomInset は明示設定されていない（デフォルト: true）
  body: Column(...),
)
```

**デフォルト値の確認**:
- `resizeToAvoidBottomInset` のデフォルト値は `true`
- ただし、プロジェクト内の多くの入力画面では `resizeToAvoidBottomInset: false` が明示設定されている

**競合の発生パターン**:
```dart
// 問題が発生する組み合わせ
MaterialApp(
  builder: (context, child) {
    return InteractiveViewer(
      constrained: true,  // デフォルト
      clipBehavior: Clip.hardEdge,  // デフォルト
      child: child,
    );
  },
  home: Scaffold(
    resizeToAvoidBottomInset: true,  // デフォルトまたは明示
    body: TextField(...),
  ),
)
```

**競合メカニズム**:
1. `InteractiveViewer` は `MaterialApp.builder` でラップされているため、アプリ全体に適用
2. `Scaffold` がキーボード表示を検知してボディをリサイズしようとする
3. しかし `InteractiveViewer` の制約が先に適用されるため、リサイズが正しく伝播しない
4. 結果として、画面の上部に空白が発生し、入力フィールドが見えなくなる

### 2.2 MediaQuery.viewInsets.bottom の変化が InteractiveViewer に与える影響

**MediaQuery の役割**:
```dart
// キーボード表示時の MediaQueryData 例
MediaQueryData(
  viewInsets: EdgeInsetsGeometry(
    bottom: 300.0,  // キーボードの高さ
    left: 0.0,
    right: 0.0,
    top: 0.0,
  ),
  // ... 他のプロパティ ...
)
```

**InteractiveViewer の影響範囲**:
- `InteractiveViewer` は `MediaQuery` からサイズ情報を取得
- キーボード表示時に `viewInsets.bottom` が変化すると、InteractiveViewer のサイズ計算に直接使用される
- ただし、`constrained: true` の場合、子ウィジェットへの制約伝播が不完全になる

**公式ドキュメントからの知見**:
> For example, if there is an onscreen keyboard displayed above the scaffold, the body can be resized to avoid overlapping the keyboard, which prevents widgets inside the body from being obscured by the keyboard.

これは `Scaffold.resizeToAvoidBottomInset: true` の場合の挙動であり、`InteractiveViewer` がその間に挟まると干渉する可能性があります。

---

## 3. 考えられる問題パターン

### 3.1 InteractiveViewer が子ウィジェットに適用する制約

**制約の伝播チェーン**:
```
MediaBox（画面全体）
    ↓ (size: 412x915, example)
MaterialApp
    ↓ (builder パターンでラップ)
InteractiveViewer
    ├─ constrained: true（デフォルト）
    └─ clipBehavior: Clip.hardEdge（デフォルト）
        ↓ (サイズ制約を伝播)
Scaffold
    ├─ resizeToAvoidBottomInset: true/false
    └─ body: Column/ListView
        ↓ (キーボード表示時に再計算)
TextField
```

**問題の具体例**:
```dart
// lib/main.dart の実装
InteractiveViewer(
  panEnabled: false,
  scaleEnabled: true,
  minScale: 0.8,
  maxScale: 4.0,
  // clipBehavior と constrained はデフォルト使用
  transformationController: _zoomController,
  child: IgnorePointer(
    ignoring: _activePointers > 1,
    child: child ?? const SizedBox.shrink(),
  ),
)
```

**制約による問題**:
1. **サイズ制限**: `constrained: true` のため、子ウィジェットは InteractiveViewer のサイズ以内に制限される
2. **クリップ損失**: `clipBehavior: Clip.hardEdge` により、表示領域外の子要素は完全に非表示
3. **リサイズ阻害**: キーボード表示時に Scaffold がボディをリサイズしても、InteractiveViewer の制約がそれを妨げる

### 3.2 キーボード表示時に子ウィジェットが適切にリサイズされない理由

**根本原因の分析**:

#### 原因 1: レイアウト順序の問題
```
正しい順序（理想）:
Scaffold (resizeToAvoidBottomInset)
    ↓
    TextField (MediaQuery.viewInsets で自動調整)

現在の順序（問題あり）:
InteractiveViewer (親のサイズ制約を適用)
    ↓
Scaffold (リサイズしようとするが InteractiveViewer に阻害)
    ↓
TextField (リサイズ情報が伝播しない)
```

#### 原因 2: クリップ処理の影響
- `Clip.hardEdge` は硬い境界でクリップするため、子ウィジェットの一部が完全に隠れる
- キーボード表示時に画面下部が圧縮されると、上部に空白が生じる
- この空白はユーザーが見ることができない領域（死領域）となる

#### 原因 3: 無限制約の不在
- `constrained: true` の場合、子ウィジェットには有限の制約が適用される
- キーボード表示時にリサイズが必要でも、InteractiveViewer がその制約を提供しない

**プロジェクト内の具体例**:
```dart
// lib/screens/stocktake_input_screen.dart（resizeToAvoidBottomInset 未設定）
Scaffold(
  // resizeToAvoidBottomInset: true（デフォルト）
  body: Column(
    children: [
      Padding(...),  // キーボード表示時に上に押し上げられる
      Expanded(
        child: ListView(...),  // スクロール可能だが、一部が見えない
      ),
    ],
  ),
)

// lib/screens/invoice_input_screen.dart（resizeToAvoidBottomInset: false）
Scaffold(
  resizeToAvoidBottomInset: false,
  body: Column(...),
)
```

**結果として**:
- `resizeToAvoidBottomInset: true` の場合、InteractiveViewer の制約によりリサイズが不完全
- `resizeToAvoidBottomInset: false` の場合、キーボードが画面を覆い、入力フィールドが見えなくなる

---

## 4. 解決策の候補

### 4.1 clipBehavior: Clip.none の明示的設定

**実装例**:
```dart
InteractiveViewer(
  panEnabled: false,
  scaleEnabled: true,
  minScale: 0.8,
  maxScale: 4.0,
  clipBehavior: Clip.none,  // クリップを無効化
  constrained: true,
  transformationController: _zoomController,
  child: IgnorePointer(
    ignoring: _activePointers > 1,
    child: child ?? const SizedBox.shrink(),
  ),
)
```

**メリット**:
- 子ウィジェットが InteractiveViewer の境界を超えて描画可能
- キーボード表示時に画面下部が圧縮されても、クリップによる隠蔽が発生しない

**デメリット**:
- クリップを無効化すると、InteractiveViewer の外側でもジェスチャーを受け取る必要がある
- `MediaQuery.viewInsets.bottom` が変化しても、子ウィジェットは InteractiveViewer のサイズ内に制限される（constrained: true の場合）

**推奨度**: ⭐⭐⭐（中程度）
- 部分的な解決にはなるが、根本的な制約問題までは解決しない

### 4.2 constrained: false の検討

**実装例**:
```dart
InteractiveViewer(
  panEnabled: false,
  scaleEnabled: true,
  minScale: 0.8,
  maxScale: 4.0,
  clipBehavior: Clip.hardEdge,
  constrained: false,  // 無限制約を適用
  transformationController: _zoomController,
  child: IgnorePointer(
    ignoring: _activePointers > 1,
    child: child ?? const SizedBox.shrink(),
  ),
)
```

**メリット**:
- 子ウィジェットに無限の制約が与えられるため、キーボード表示時に自由なリサイズが可能
- `constrained: false` のドキュメント引用：
  > If set to false, then the child will be given infinite constraints. This is often useful when a child should be bigger than the InteractiveViewer.

**デメリット**:
- 子ウィジェットが画面外に拡大し、ユーザーが見えない領域が発生する可能性
- `panEnabled: false` の場合、ズーム後の移動ができず、一部の内容にアクセスできない

**推奨度**: ⭐⭐（低）
- キーボード問題の解決には有効だが、ズーム機能との競合リスクが高い

### 4.3 InteractiveViewer 外でのズーム機能実装

**アプローチ**:
```dart
// main.dart の builder を変更
MaterialApp(
  // InteractiveViewer を削除
  home: Scaffold(
    resizeToAvoidBottomInset: true,
    body: ZoomableWidget(  // 独自のズーム実装
      child: _HomeDecider(),
    ),
  ),
)

// zoomable_widget.dart
class ZoomableWidget extends StatefulWidget {
  final Widget child;
  
  @override
  State<ZoomableWidget> createState() => _ZoomableWidgetState();
}

class _ZoomableWidgetState extends State<ZoomableWidget> {
  double _scale = 1.0;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_scale * details.scale).clamp(0.8, 4.0);
        });
      },
      child: Transform.scale(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
```

**メリット**:
- `InteractiveViewer` の制約問題から解放される
- `Scaffold.resizeToAvoidBottomInset` との競合がなくなる
- ズームロジックを細かく制御可能

**デメリット**:
- 実装コストが高い（ジェスチャー処理、コントローラー管理など）
- `InteractiveViewer` が提供する機能（パン、アライメントなど）を手動で実装する必要がある

**推奨度**: ⭐⭐⭐⭐（高）
- 根本的な解決となるが、実装労力が必要

### 4.4 Scaffold 内のみに Zoom 機能を限定する手法

**アプローチ**:
```dart
// main.dart の builder を変更
MaterialApp(
  builder: (context, child) {
    return Listener(
      onPointerDown: (_) => setState(() => _activePointers++),
      onPointerUp: (_) => setState(() => _activePointers = (_activePointers - 1).clamp(0, 10)),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        // InteractiveViewer を削除
        child: child ?? const SizedBox.shrink(),
      ),
    );
  },
  home: Scaffold(
    resizeToAvoidBottomInset: true,
    body: ZoomableContainer(  // 特定の画面でのみズーム機能
      child: _HomeDecider(),
    ),
  ),
)

// zoomable_container.dart
class ZoomableContainer extends StatefulWidget {
  final Widget child;
  
  @override
  State<ZoomableContainer> createState() => _ZoomableContainerState();
}

class _ZoomableContainerState extends State<ZoomableContainer> {
  final TransformationController _controller = TransformationController();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      panEnabled: false,
      scaleEnabled: true,
      minScale: 0.8,
      maxScale: 4.0,
      constrained: false,  // 無限制約でリサイズを許可
      clipBehavior: Clip.none,  // クリップなし
      transformationController: _controller,
      child: widget.child,
    );
  }
}
```

**メリット**:
- ズーム機能が必要な画面のみに適用するため、不要な制約が発生しない
- `Scaffold` 内でのみ動作するため、キーボード処理との競合が少ない
- `constrained: false` と `clipBehavior: Clip.none` を併用することで、リサイズと表示を両立

**デメリット**:
- 各画面で個別にズーム機能を設定する必要がある
- コードの重複が発生する可能性

**推奨度**: ⭐⭐⭐⭐⭐（最高）
- 問題の本質的な解決となり、実装コストも適切

---

## 5. 具体的なコード例と推奨アプローチ

### 5.1 推奨する修正パターン

**lib/main.dart の変更**:
```dart
// 変更前
MaterialApp(
  builder: (context, child) {
    return Listener(
      onPointerDown: (_) => setState(() => _activePointers++),
      onPointerUp: (_) => setState(() => _activePointers = (_activePointers - 1).clamp(0, 10)),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: InteractiveViewer(
          panEnabled: false,
          scaleEnabled: true,
          minScale: 0.8,
          maxScale: 4.0,
          transformationController: _zoomController,
          child: IgnorePointer(
            ignoring: _activePointers > 1,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  },
  // ...
)

// 変更後（案 1：InteractiveViewer を削除）
MaterialApp(
  builder: (context, child) {
    return Listener(
      onPointerDown: (_) => setState(() => _activePointers++),
      onPointerUp: (_) => setState(() => _activePointers = (_activePointers - 1).clamp(0, 10)),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        // InteractiveViewer を削除してキーボード問題の根本原因を排除
        child: child ?? const SizedBox.shrink(),
      ),
    );
  },
  // ...
)

// 変更後（案 2：Zoom 機能を画面固有に）
MaterialApp(
  builder: (context, child) {
    return Listener(
      onPointerDown: (_) => setState(() => _activePointers++),
      onPointerUp: (_) => setState(() => _activePointers = (_activePointers - 1).clamp(0, 10)),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        // InteractiveViewer を削除
        child: child ?? const SizedBox.shrink(),
      ),
    );
  },
  home: Scaffold(
    resizeToAvoidBottomInset: true,
    body: ZoomableContent(
      zoomEnabledScreens: ['S1', 'P2', 'A3'],  // ズームを有効にする画面 ID を指定
      child: _HomeDecider(),
    ),
  ),
)
```

### 5.2 各解決策の比較

| 解決策 | キーボード問題 | ズーム機能 | 実装コスト | 推奨度 |
|--------|----------------|------------|------------|--------|
| clipBehavior: Clip.none | △（部分解決） | ○ | 低 | ⭐⭐⭐ |
| constrained: false | ○（有効） | △（パン不能） | 低 | ⭐⭐ |
| InteractiveViewer 外実装 | ○（完全解決） | ○（カスタム） | 高 | ⭐⭐⭐⭐ |
| Scaffold 内限定 | ○（完全解決） | ○（維持） | 中 | ⭐⭐⭐⭐⭐ |

### 5.3 最終推奨案

**Scaffold 内のみに Zoom 機能を限定する手法** を採用することを強く推奨します。

**理由**:
1. **根本解決**: InteractiveViewer がアプリ全体に適用されることを防ぎ、キーボード処理との競合を排除
2. **柔軟性**: ズーム機能が必要な画面のみに適用できる
3. **保守性**: 各画面でズーム機能を個別に制御可能
4. **互換性**: `Scaffold.resizeToAvoidBottomInset` との競合がなくなる

---

## 6. 関連する Flutter ドキュメント

### InteractiveViewer クラス
- [公式ドキュメント](https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html)
- [clipBehavior プロパティ](https://api.flutter.dev/flutter/widgets/InteractiveViewer/clipBehavior.html)
- [constrained プロパティ](https://api.flutter.dev/flutter/widgets/InteractiveViewer/constrained.html)

### Scaffold クラス
- [resizeToAvoidBottomInset プロパティ](https://api.flutter.dev/flutter/material/Scaffold/resizeToAvoidBottomInset.html)

### 参考サンプル
- [Flutter Gallery Transformations Demo](https://github.com/flutter/gallery/blob/main/lib/demos/reference/transformations_demo.dart)
- [flutter-go Demo](https://github.com/justinmc/flutter-go)

---

## 7. 結論

**InteractiveViewer のデフォルト設定**:
- `clipBehavior: Clip.hardEdge`（クリップあり）
- `constrained: true`（有限制約）

**キーボード表示時の問題**:
1. InteractiveViewer が子ウィジェットに制限されたサイズ制約を適用
2. クリップ処理により、表示領域外の子要素が隠れる
3. Scaffold のリサイズ処理と競合し、空白が発生する

**推奨解決策**:
- `InteractiveViewer` を `MaterialApp.builder` から削除
- ズーム機能が必要な画面のみに限定して適用
- `constrained: false` と `clipBehavior: Clip.none` を併用

**実装ステップ**:
1. `lib/main.dart` から InteractiveViewer を削除
2. 各入力画面で独自のズームコンポーネントを実装
3. `Scaffold.resizeToAvoidBottomInset: true` を明示設定
4. テスト環境でキーボード表示を確認

---

## 8. 追加調査事項

- [ ] プロジェクト内の全入力画面で `resizeToAvoidBottomInset` の設定状況を確認
- [ ] ズーム機能が必要な画面の特定
- [ ] 独自のズーム実装プロトタイプ作成
- [ ] キーボード表示時の動作テスト

---

**レポート作成者**: AI エージェント  
**最終更新日**: 2026-04-08
