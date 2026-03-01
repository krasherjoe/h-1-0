// lib/main.dart
// version: 1.5.02 (Update: Date selection & Tax fix)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- 独自モジュールのインポート ---
import 'models/invoice_models.dart'; // Invoice, InvoiceItem モデル
import 'screens/invoice_input_screen.dart'; // 入力フォーム画面
import 'screens/invoice_detail_page.dart'; // 詳細表示・編集画面
import 'screens/invoice_history_screen.dart'; // 履歴画面
import 'screens/dashboard_screen.dart'; // ダッシュボード
import 'services/location_service.dart'; // 位置情報サービス
import 'services/customer_repository.dart'; // 顧客リポジトリ
import 'services/app_settings_repository.dart';
import 'services/theme_controller.dart';
import 'utils/build_expiry_info.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.instance.load();
  final expiryInfo = BuildExpiryInfo.fromEnvironment();
  if (expiryInfo.isExpired) {
    runApp(ExpiredApp(expiryInfo: expiryInfo));
    return;
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TransformationController _zoomController = TransformationController();
  int _activePointers = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.instance.notifier,
      builder: (context, mode, _) => MaterialApp(
        title: '販売アシスト1号',
        navigatorObservers: [
          _ZoomResetObserver(_zoomController),
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo.shade700).copyWith(
            primary: Colors.indigo.shade700,
            secondary: Colors.deepOrange.shade400,
            surface: Colors.grey.shade100,
            onSurface: Colors.blueGrey.shade900,
          ),
          scaffoldBackgroundColor: Colors.grey.shade100,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.indigo.shade700,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.indigo.shade700),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.indigo.shade700, width: 1.4),
            ),
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
          fontFamily: 'IPAexGothic',
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme(
            brightness: Brightness.dark,
            primary: const Color(0xFF66D9EF),
            onPrimary: const Color(0xFF1E1F1C),
            secondary: const Color(0xFFF92672),
            onSecondary: const Color(0xFF1E1F1C),
            surface: const Color(0xFF272822),
            onSurface: const Color(0xFFF8F8F2),
            error: Colors.red.shade300,
            onError: const Color(0xFF1E1F1C),
          ),
          scaffoldBackgroundColor: const Color(0xFF272822),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF32332A),
            foregroundColor: Color(0xFFF8F8F2),
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF66D9EF),
              foregroundColor: const Color(0xFF1E1F1C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: Color(0xFF66D9EF)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFF32332A),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF66D9EF), width: 1.4),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF32332A),
            contentTextStyle: TextStyle(color: Color(0xFFF8F8F2)),
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
          fontFamily: 'IPAexGothic',
        ),
        themeMode: mode,
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return Listener(
            onPointerDown: (_) => setState(() => _activePointers++),
            onPointerUp: (_) => setState(() => _activePointers = (_activePointers - 1).clamp(0, 10)),
            onPointerCancel: (_) => setState(() => _activePointers = (_activePointers - 1).clamp(0, 10)),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
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
            ),
          );
        },
        home: const _HomeDecider(),
      ),
    );
  }
}

class ExpiredApp extends StatelessWidget {
  final BuildExpiryInfo expiryInfo;
  const ExpiredApp({super.key, required this.expiryInfo});

  String _format(DateTime? timestamp) {
    if (timestamp == null) return '不明';
    final local = timestamp.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final buildText = _format(expiryInfo.buildTimestamp);
    final expiryText = _format(expiryInfo.expiryTimestamp);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.lock_clock, size: 72, color: Colors.white),
                const SizedBox(height: 24),
                const Text(
                  'このビルドは有効期限を過ぎています',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text('ビルド日時: $buildText', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text('有効期限: $expiryText', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                const Text(
                  '最新版を取得してインストールしてください。',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                  onPressed: () => SystemNavigator.pop(),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('アプリを終了する'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomResetObserver extends NavigatorObserver {
  final TransformationController controller;
  _ZoomResetObserver(this.controller);

  void _reset() {
    controller.value = Matrix4.identity();
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _reset();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    _reset();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _reset();
  }
}

class _HomeDecider extends StatefulWidget {
  const _HomeDecider();

  @override
  State<_HomeDecider> createState() => _HomeDeciderState();
}

class _HomeDeciderState extends State<_HomeDecider> {
  final _settings = AppSettingsRepository();
  late Future<String> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = _settings.getHomeMode();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final mode = snapshot.data ?? 'invoice_history';
        if (mode == 'dashboard') {
          return const DashboardScreen();
        }
        return const InvoiceHistoryScreen();
      },
    );
  }
}

// 従来の InvoiceFlowScreen は新規作成用ウィジェットとして維持
class InvoiceFlowScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const InvoiceFlowScreen({super.key, this.onComplete});

  @override
  State<InvoiceFlowScreen> createState() => _InvoiceFlowScreenState();
}

class _InvoiceFlowScreenState extends State<InvoiceFlowScreen> {
  // PDF 生成後に呼び出され、詳細ページへ遷移するコールバック
  void _handleInvoiceGenerated(Invoice generatedInvoice, String filePath) {
    // 詳細ページへ遷移
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceDetailPage(invoice: generatedInvoice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 入力フォーム自身が Scaffold を持つため、ここではそのまま返す
    return InvoiceInputForm(
      onInvoiceGenerated: (invoice, path) async {
        // GPSの記録を試みる
        final locationService = LocationService();
        final position = await locationService.getCurrentLocation();
        if (position != null) {
          final customerRepo = CustomerRepository();
          await customerRepo.addGpsHistory(invoice.customer.id, position.latitude, position.longitude);
          debugPrint("GPS recorded for customer ${invoice.customer.id}");
        }
        _handleInvoiceGenerated(invoice, path);
        if (widget.onComplete != null) widget.onComplete!();
      },
    );
  }
}
