# 販売アシスト1号 / 母艦「お局様」プロジェクト概要

販売アシスト1号は **オフライン単体で見積・納品・請求・レジ業務まで完結できる販売アシスタント** であり、オプション機能として **オンライン接続時に母艦「お局様」とデータ同期・バックアップ・監視を行う二層構造** を目指しています。

---

## コアコンセプト

| モード | 目的 | 主な特徴 |
| --- | --- | --- |
| オフライン・スタンドアロン | 端末単体で全業務を完結 | SQLite に全データ保存、印影以外は非暗号化、AI などによる再利用も想定 |
| オンライン（システムオプション） | 母艦と接続しデータ交換・監視 | SSH/クラウドトンネル経由で同期、APK寿命チェックやバックアップを遠隔制御 |

母艦「お局様」はブリッジ／モニタリング／バックアップに専念し、実務機能は販売アシスト1号側に集約する方針です。TV BOX を母艦に据える運用や、単一端末で両役割を兼務するシナリオも想定しています。

---

## 現状の実装状況

- Flutter ベースの販売アシスト1号アプリ
  - 会社・担当者・銀行口座を統合管理する事業プロフィール画面
  - Phone ブック取り込みを共通化した `ContactPickerSheet`
  - 税率・税表示・印影の追加設定
  - 90 日寿命チェック（`BuildExpiryInfo`）と期限切れ画面
- ビルド用スクリプト `scripts/build_with_expiry.sh`
  - `--dart-define=APP_BUILD_TIMESTAMP` を自動付与し APK を生成
  - analyze 実行～APK ビルドのワンステップ化
- 連絡帳・顧客モジュールの共通化（BusinessProfileScreen / CustomerPickerModal / CustomerMasterScreen）

---

## 将来像・ロードマップ

1. **母艦お局様（Web UI 100%）**
   - 各クライアントのハッシュチェーン監視
   - SSH/Cloudflare/自社 DDNS いずれにも対応するブリッジ機能
   - Google Drive への自動バックアップ、容量推定
2. **販売アシスト1号の拡張モジュール化**
   - 売上（POS）、仕入、在庫、チャット、通知をモジュールとして追加
   - ダッシュボードにモジュールカードを組み込む方式へ刷新
3. **チャット＆サポート**
   - 「順次対応である」旨を明記した問い合わせチャットをローカル実装
   - 母艦側で受信・返信・履歴管理ができる仕組みを構築
4. **寿命延命と母艦同期**
   - 母艦と定期同期できた端末は自動で寿命を延長（例: 半年）

---

## リポジトリ構成（抜粋）

```
/home/user/dev/h-1.flutter.0
├── README.md                   … 本ファイル
├── analysis_options.yaml       … Lint 設定
├── lib/                        … Flutter アプリ本体
│   ├── screens/                … 各種画面（business_profile_screen 等）
│   ├── widgets/                … 共通ウィジェット（contact_picker_sheet 等）
│   ├── services/               … 永続化・ユーティリティ（company_profile_service 等）
│   └── utils/build_expiry_info.dart … ビルド寿命ユーティリティ
├── scripts/build_with_expiry.sh … dart-define 付きビルドスクリプト
├── android/, ios/, macos/, windows/, linux/ … 各プラットフォームテンプレート
├── assets/                     … 画像・リソース
├── test/                       … テストコード
└── 目標.md / 目的.md           … 設計メモ
```

※ フルツリーが必要になった場合は `tree` や `list_dir` の出力を README 末尾に追加して更新していきます。

---

## セットアップ & ビルド

1. Flutter 3.x 環境を用意し、依存パッケージを取得
   ```bash
   flutter pub get
   ```
2. 90 日寿命 APK の生成
   ```bash
   chmod +x scripts/build_with_expiry.sh
   ./scripts/build_with_expiry.sh [debug|profile|release]
   ```
   - スクリプト内で `APP_BUILD_TIMESTAMP` を UTC で自動付与
   - `flutter analyze` → `flutter build apk` を連続実行
3. 実機/エミュレータで起動すると、寿命切れ時には `ExpiredApp` が自動表示されます。

---

## 更新ポリシー

- README は **機能追加・アーキテクチャ変更・モジュール構成の見直し時に必ず更新** します。
- 変更履歴とファイルツリーは必要に応じて追記し、最新状態を反映させます。
- 設計検討中の内容（母艦 Web UI、チャット、モジュール化など）は本 README の「将来像」節で随時アップデートします。

---

ご要望・アイデアがあれば Issue/チャットで共有いただき、README に反映していきます。
