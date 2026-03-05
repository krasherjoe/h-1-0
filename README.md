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

## メインメニュー構成（必須機能のベースライン）

実運用で必須になるメニューをツリー形式で整理し、ダッシュボード設定やモジュール化の土台とします。

- **01. マスタ管理**
  - 商品マスタ
  - 得意先マスタ
  - 仕入先マスタ
  - 倉庫マスタ
  - 担当者マスタ
- **02. 販売管理**
  - 見積入力
  - 受注入力
  - 売上入力（レジモードの主戦場）
  - 売上返品入力
  - 請求書発行
- **03. 仕入管理**
  - 発注入力
  - 仕入入力（未入荷管理を含む）
  - 仕入返品入力
  - 支払予定管理
- **04. 在庫管理**
  - 在庫照会
  - 在庫移動（倉庫間）
  - 棚卸入力
  - 在庫調整
- **05. 集計分析**
  - 売上日報
  - 得意先別売上推移
  - 商品別粗利分析
  - 在庫評価額一覧
- **06. システム設定**
  - ユーザー権限設定
  - ログ管理

上記を D2（ダッシュボード設定）画面のデフォルトメニューや並べ替え対象として順次実装していきます。

---

## Base System - Universal Sales Assistant

クラウド連携やバックエンド処理で共通化したい基盤機能のリファレンスです。Google エコシステム連携や台帳層を切り出しておくことで、オフラインPOSと母艦クラウドのハイブリッド連携を容易にします。

- **00. System Setup & Security**
  - Google OAuth 認証管理
  - 環境設定管理（`.env` はデフォルトでブラックリスト化）
  - API 接続制限・クォータ管理
  - ログ出力・エラー通知設定
- **01. Google Ecosystem Integration**
  - Calendar Sync Engine（イベント取得 / 解析 / 更新）
  - Drive File Manager（バックアップディレクトリ・テンプレPDF管理）
  - Sheets Data Provider（スプレッドシートをDBとして接続、ストリーミング書き込み）
- **02. Data Ledger (Transaction Core)**
  - 取引データの登録・照会・修正・削除（履歴保持）
- **03. Calculation Engine (Common Rules)**
  - 日時フォーマット統一
  - 通貨・数値型キャスト処理
  - 共通利益計算（売上 − 原価）
- **04. Output & Notification**
  - PDF 帳票生成エンジン（テンプレ変数差し込み）
  - Mailer（Gmail API、BCC 自動送付制御含む）

これらの層を意識しつつ Flutter アプリ／母艦サーバ双方で責務分担を進めます。

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

## 母艦「お局様」LAN サーバの起動

1. Dart/Flutter SDK が入った Linux / Android（Termux 等）端末でリポジトリを取得
2. 監視サーバを起動
   ```bash
   dart run bin/mothership_server.dart
   ```
   - 環境変数 `MOTHERSHIP_HOST`, `MOTHERSHIP_PORT`, `MOTHERSHIP_API_KEY`, `MOTHERSHIP_DATA_DIR` で上書き可能
   - 既定値: `0.0.0.0:8787`, API キー `TEST_MOTHERSHIP_KEY`, 保存先 `data/mothership`
   - `data/mothership/status.json` に各クライアントの心拍/ハッシュを保存
3. ブラウザで `http://<host>:<port>/` を開くとステータス一覧を閲覧できます（CUI 常駐で OK）

### クライアント（販売アシスト1号）からの接続設定

1. アプリの `S1:設定` → 「外部同期（母艦システム『お局様』連携）」で以下を入力
   - ホストドメイン: `http://192.168.0.10:8787` のようにプロトコル付きで指定
   - パスワード: サーバ側 API キー（例: `TEST_MOTHERSHIP_KEY`）
2. 保存するとアプリ起動時に `POST /sync/heartbeat` が自動送信され、寿命残時間が母艦に表示されます。
3. 同じ設定でチャット送受信・ハッシュ送信が有効になります（下記参照）。

### チャット同期（最小構成）

- Flutter アプリ側では 10 秒間隔の軽量ポーリングをバックグラウンドで実行し、`/chat/send` / `/chat/pending` / `/chat/ack` とローカル SQLite を同期します。
- 設定画面からチャット画面を開かなくても新着が取り込まれ、開いた瞬間に最新ログが表示されます。
- 端末がスリープに入るとポーリングを停止し、アプリが前面に戻ったタイミングで即時同期→再開します。

---

## 更新ポリシー

- README は **機能追加・アーキテクチャ変更・モジュール構成の見直し時に必ず更新** します。
- 変更履歴とファイルツリーは必要に応じて追記し、最新状態を反映させます。
- 設計検討中の内容（母艦 Web UI、チャット、モジュール化など）は本 README の「将来像」節で随時アップデートします。

---

ご要望・アイデアがあれば Issue/チャットで共有いただき、README に反映していきます。
