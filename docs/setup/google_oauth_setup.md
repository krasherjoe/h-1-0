# Google OAuth 設定ガイド

販売アシスト1号で Google 連携（Gmail / Drive / Sheets / Calendar）を利用するために必要な設定手順です。開発者ごと、ビルド（デバッグ / リリース）ごとに OAuth クライアントを登録してください。

---

## 1. 前提条件

- Google Cloud Console へアクセスできる Google アカウント
- Flutter プロジェクトのパッケージ名: `com.example.h_1`
- Android デバッグ/リリース用 keystore（SHA-1 が取得できること）

---

## 2. Cloud Console 側の設定

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセスし、対象プロジェクトを開く（または新規作成）。
2. 左メニューの **「API とサービス」→「OAuth 同意画面」** を開き、ユーザータイプを「外部」に設定して最低限の情報（アプリ名・サポートメール）を入力して保存します。
3. 同じ「API とサービス」内の **「認証情報」→「認証情報を作成」→「OAuth クライアント ID」** を選択。
4. アプリケーションの種類に **「Android」** を選択し、以下を入力:
   - **名前**: 任意（`SalesAssist Debug` など）
   - **パッケージ名**: `com.example.h_1`
   - **SHA-1 証明書フィンガープリント**: 後述コマンドで取得した値
5. 「作成」を押し、クライアント ID を控えておきます。
6. リリースビルド用 keystore を使用する場合は、同じ手順で SHA-1 を差し替えて別のクライアント ID を登録してください。

> **補足:** `google_sign_in` パッケージのみを使用する場合は `google-services.json` は不要です。Firebase を使う場合のみ追加してください。

---

## 3. SHA-1 フィンガープリント取得コマンド

### デバッグ keystore
```
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android
```

### リリース keystore（例）
```
keytool -list -v -keystore /path/to/your-release-key.jks \
  -alias your_alias_name
```
> ※ パスワードやエイリアスはプロジェクト固有のものに置き換えてください。

出力の `SHA1:` 行を Cloud Console に登録します。

---

## 4. アプリ側の確認手順

1. Android デバイス/エミュレータにアプリをインストール。
2. **S1:設定** 画面を開き、Google 連携セクションで「Google アカウントを連携」をタップ。
3. 正しく設定されていればアカウント選択ダイアログが表示され、選択後に連携メールアドレスが表示されます。
4. 連携後、`メール設定` 画面の BCC 自動入力など Google 連携が必要な機能を試して動作確認してください。

### エラー対処
- **"Googleアカウントに未連携です"**: OAuth クライアント ID が未登録または SHA-1 が一致していません。Cloud Console を確認してください。
- **アカウント選択ダイアログが出ない**: デバイスに Google アカウントが登録されているか、Google Play Services が最新化されているか確認してください。

---

## 5. 変更履歴
- 2026-03-07: 初版作成
