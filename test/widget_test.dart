// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:h_1/main.dart';
import 'package:h_1/utils/build_expiry_info.dart';
// import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('アプリが初期化されてホーム画面を描画できる', (WidgetTester tester) async {
    final expiryInfo = BuildExpiryInfo.fromEnvironment();
    await tester.pumpWidget(MyApp(expiryInfo: expiryInfo));

    // 初期化ローディングの完了をある程度待つ
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // 描画完了後、MaterialApp が存在しホーム遷移が完了していることを確認
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
