# 依頼内容
Flutterプロジェクトのビルドエラーを解消し、顧客マスター管理（GPSソート/電話帳連携）と請求書履歴一覧の機能を完成させてください。

# 現状の問題
1. `CustomerPickerModal` 内で DB の `Customer` 型とアプリ用 `Customer` モデルが衝突し、型エラーが発生している。
2. `pdf_list_screen.dart` で、DB から顧客情報付きの請求データを取得する `InvoiceWithCustomer` 型や `watchAllInvoices()` メソッドが見つからずエラーになっている。
3. `invoice_input_screen.dart` で `CustomerPickerModal` を呼び出す際、古い引数 `existingCustomers` を渡しておりエラーになっている。

# 実行ステップ
1. **lib/data/database.dart の更新**:
   - `Invoices` と `Customers` を結合して取得するための `InvoiceWithCustomer` クラスを定義してください。
   - `AppDatabase` クラスに、最新順でデータを流す `Stream<List<InvoiceWithCustomer>> watchAllInvoices()` メソッドを実装してください。
   - その後、`flutter pub run build_runner build --delete-conflicting-outputs` を実行してコード生成を完了させてください。

2. **lib/screens/customer_picker_modal.dart の修正**:
   - インポートで `../models/invoice_models.dart` を `app_model` として別名を付け、DBの `Customer` 型と明確に区別してください。
   - GPS座標（latitude/longitude）を使用して、現在地に近い順にリストをソートするロジックを実装してください。
   - 電話帳（flutter_contacts）からの取り込みと、DBへの保存（insertOnConflictUpdate）が正常に動くようにしてください。

3. **lib/screens/pdf_list_screen.dart の修正**:
   - `database.watchAllInvoices()` を使用して履歴一覧を表示するようにしてください。
   - リストタップ時に、DBのモデルからアプリ用の `Invoice` モデルへ変換して詳細画面へ遷移させてください。

4. **lib/screens/invoice_input_screen.dart の修正**:
   - `CustomerPickerModal` の呼び出し箇所から、存在しない引数 `existingCustomers` を削除してください。

# 完了条件
`flutter build apk --debug` がエラーなく通り、かつ顧客マスターのGPSソートが機能すること。