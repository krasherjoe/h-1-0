# 母艦「お局様」LAN 常駐サーバ叩き台
本ドキュメントは、Flutter/Dart プロジェクト内にヘッドレス構成の母艦サーバを実装し、LAN 上で販売アシスト1号クライアントと同期・監視・バックアップを行うための叩き台です。

## 目的と前提
- 端末 1 台だけの利用者から、複数クライアントを抱える小規模事業者までカバーする。
- まずは LAN 内で完結する通信を実現し、その後 SSH/Cloudflare/DDNS など外部経路へ拡張できる土台を用意する。
- 同一 Flutter プロジェクト内で UI アプリとサーバ常駐処理を併存させる（headless Isolate / `dart` エントリーポイント）。

## 最小構成
1. **同期 API サーバ**
   - Dart `HttpServer`（shelf など）で起動。
   - エンドポイント例:
     - `POST /sync/logs` : ハッシュチェーン・操作ログを受信。
     - `POST /sync/diff` : 伝票差分や顧客レコードを受信し、母艦側 DB に再構築。
     - `GET /status` : 各クライアントの最終同期状況を返す。
2. **データ保全レイヤ**
   - 受信データを `data/mothership/<client_id>/YYYY` 配下に JSON/SQLite/ZIP で保存。
   - 世代管理（例: 年度単位 10 パック）と最終ハッシュの保持。
3. **モニタリング Web UI**
   - 同じサーバで `GET /dashboard` を提供し、ブラウザで一覧表示。
   - 表示項目: クライアント名、最終同期、寿命残り、チャット未読、バックアップサイズ。
4. **バックアップトリガー**
   - 手動/定期ジョブで `data/` を ZIP 圧縮。
   - 将来的に Google Drive/API へ転送するフックを用意。

## 実装候補
- `bin/mothership_server.dart` : サーバ起動用 Dart エントリーポイント。
- `lib/mothership/` : サーバ用ロジック（API ハンドラ、リポジトリ、チャットキューなど）。
- `lib/mothership/ui/dashboard.dart` : Web UI（`shelf_static` で提供 or Flutter Web をビルドして同梱）。
- `lib/services/mothership_client.dart` : 販売アシスト1号側から呼び出すクライアント。

## データフロー概要
1. クライアントがオフラインで業務継続。
2. LAN で母艦に接続できたタイミングで `POST /sync/...` を実行。
3. 母艦は受信データを保存し、最終ハッシュと同期時刻を更新。
4. バックアップジョブが ZIP を生成、必要に応じて外部ストレージへ転送。
5. Web UI で状態を確認し、チャット/通知も同じ API でやり取り。

## API 叩き台
| メソッド | パス | 概要 |
| --- | --- | --- |
| `POST` | `/sync/heartbeat` | 端末 UUID・アプリバージョン・寿命残りを報告 |
| `POST` | `/sync/hash` | `{ clientId, chain }` を送信、整合性チェック |
| `POST` | `/sync/diff` | 伝票・顧客など差分データを送付 |
| `GET` | `/status` | 母艦が把握している全クライアントの状態を返却 |
| `GET` | `/chat/pending` | クライアント向け未読チャット取得 |
| `POST` | `/chat/send` | クライアント→母艦の問い合わせ送信 |

### 認証 (テスト期間)
- すべての API リクエストに固定キーを送付（例: `X-Api-Key: TEST_MOTHERSHIP_KEY`）。
- サーバ側は一致チェックのみを行い、不一致は `401 Unauthorized` を返す。
- 本番想定ではトークンローテーションや署名方式に置き換える前提で、キー値は設定ファイルまたは環境変数から読み込む実装とする。

## 実装ステップ案
1. `bin/mothership_server.dart` を追加し、LAN で HTTP をリッスン。
2. `lib/mothership/` に API ハンドラとファイル保存ロジックを実装。
3. `lib/services/mothership_client.dart` を作成し、販売アシスト1号側から API を叩けるようにする。
4. 簡易 Web UI（HTML/JS or Flutter Web）を `/dashboard` で提供。
5. バックアップ ZIP と世代管理ロジックを追加。
6. 将来の拡張（Google Drive 連携、Cloudflare/S SH/Tunneling）をこの土台に差し込む。

## 今後の課題
- 認証方式（LAN 内とはいえ API キーやシグネチャを検討）。
- データ移行/マイグレーション（年度パック＋最終ハッシュの保持方法）。
- フロントエンドからモジュール追加を制御するインターフェイス。
- チャット/通知の同期待ち行列設計。
