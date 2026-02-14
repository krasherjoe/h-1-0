# React Native版 販売アシスト1号
// Version: 2026-02-15

FlutterからReact Native (Expo)に移行した請求書管理アプリケーション

## セットアップ

```bash
cd react_native_app
npm install
```

## 開発サーバー起動

```bash
npm start
```

## ビルド

- Android: `npm run android`
- iOS: `npm run ios` (macOS required)
- Web: `npm run web`

## 実装済み機能

### ✅ Phase 1-3完了
- TypeScript型定義(Invoice, Customer, Product, Company)
- SQLiteデータベースサービス(expo-sqlite)
- リポジトリ層(CRUD操作)
- 基本UIコンポーネント
- ナビゲーション(React Navigation)

### 🚧 Phase 4: 残りのタスク
- 請求書入力画面の完成
- 詳細画面の実装
- PDF生成機能
- Bluetooth印刷機能
- マスター管理画面
- GPS機能

## プロジェクト構造

```
react_native_app/
├── App.tsx                    # エントリーポイント
├── src/
│   ├── models/                # TypeScript型定義
│   ├── services/
│   │   ├── database.ts        # SQLite
│   │   └── repositories/      # データアクセス層
│   └── components/
│       └── InvoiceForm/       # UIコンポーネント
└── assets/
    └── fonts/
        └── ipaexg.ttf         # 日本語フォント
```

## 移行状況

Flutterコードベース → React Native移行率: **約40%完了**

### 完了
- [x] データモデル
- [x] データベース層
- [x] リポジトリ層
- [x] 基本コンポーネント

### 未完了
- [ ] 全画面の実装
- [ ] PDF生成
- [ ] 印刷機能
- [ ] バーコードスキャン
- [ ] GPS連携
