// lib/main.dart
// version: 1.5.02 (Update: Date selection & Tax fix)
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'services/chat_sync_scheduler.dart';
import 'services/mothership_client.dart';
import 'services/theme_controller.dart';
import 'services/auto_backup_service.dart';
import 'services/backup_progress_notifier.dart';
import 'services/google_account_service.dart';
import 'screens/settings_screen.dart';
import 'utils/build_expiry_info.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.instance.load();
  final expiryInfo = BuildExpiryInfo.fromEnvironment();
  if (expiryInfo.isExpired) {
    runApp(ExpiredApp(expiryInfo: expiryInfo));
    return;
  }
  // 起動時に自動バックアップチェック（非同期、アプリ起動を妨げない）
  // WebプラットフォームではGoogle Driveバックアップはスキップ
  if (!kIsWeb) {
    AutoBackupService.checkAndBackupOnStartup();
  }
  runApp(MyApp(expiryInfo: expiryInfo));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.expiryInfo});

  final BuildExpiryInfo expiryInfo;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final MothershipClient? _mothershipClient = kIsWeb
      ? null
      : MothershipClient();
  final ChatSyncScheduler? _chatSyncScheduler = kIsWeb
      ? null
      : ChatSyncScheduler();
  late BackupProgressNotifier _backupProgressNotifier;

  @override
  void initState() {
    super.initState();
    _backupProgressNotifier = BackupProgressNotifier();
    _backupProgressNotifier.addListener(_onBackupProgressChanged);
    _sendHeartbeat();
    _chatSyncScheduler?.start();
    _checkFirstLaunchRestore();
  }

  void _onBackupProgressChanged() {
    if (!mounted) return;
    if (_backupProgressNotifier.isBackingUp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_backupProgressNotifier.currentMessage),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _backupProgressNotifier.progress,
                  minHeight: 4,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 60),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blue.shade700,
        ),
      );
    } else if (_backupProgressNotifier.currentMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_backupProgressNotifier.currentMessage),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _backupProgressNotifier.currentMessage.contains('失敗')
              ? Colors.red.shade700
              : Colors.green.shade700,
        ),
      );
    }
  }

  void _checkFirstLaunchRestore() {
    // Webプラットフォームでは復元機能はスキップ
    if (kIsWeb) return;
    Future.microtask(() async {
      final shouldOffer = await AutoBackupService.shouldOfferRestore();
      if (shouldOffer && mounted) {
        _showRestoreDialog();
      }
    });
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('バックアップからの復元'),
        content: const Text(
          'Google Driveにバックアップが見つかりました。\n'
          'データを復元しますか？\n\n'
          '※設定画面からいつでも復元できます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('後で'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 設定画面へ誘導（リストア機能がある）
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('設定 > データバックアップ > バックアップから復元 で復元できます'),
                  duration: Duration(seconds: 5),
                ),
              );
            },
            child: const Text('設定画面を開く'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _backupProgressNotifier.removeListener(_onBackupProgressChanged);
    _chatSyncScheduler?.dispose();
    super.dispose();
  }

  void _sendHeartbeat() {
    if (kIsWeb) return; // Webプラットフォームではハートビートを送信しない
    Future.microtask(() => _mothershipClient?.sendHeartbeat(widget.expiryInfo));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.instance.notifier,
      builder: (context, mode, _) => MaterialApp(
        title: '販売アシスト 1 号',
        // NOTE: InteractiveViewer 削除に伴い、ズームリセット Observer は不要
        // navigatorObservers: [_ZoomResetObserver(_zoomController)],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo.shade700)
              .copyWith(
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: const CardThemeData(
            color: Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Colors.white70),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF2C2C2C),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.indigoAccent,
                width: 1.4,
              ),
            ),
            labelStyle: const TextStyle(color: Colors.white70),
            hintStyle: const TextStyle(color: Colors.white54),
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF2C2C2C),
            contentTextStyle: TextStyle(color: Colors.white),
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
          fontFamily: 'IPAexGothic',
        ),
        themeMode: mode,
        builder: (context, child) {
          // キーボード表示時のせり上がり問題を回避するため、InteractiveViewer は削除
          // ズーム機能が必要な画面のみに個別に適用する（必要に応じて）
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: child ?? const SizedBox.shrink(),
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'ビルド日時: $buildText',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '有効期限: $expiryText',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                const Text(
                  '最新版を取得してインストールしてください。',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                  ),
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

class _HomeDecider extends StatefulWidget {
  const _HomeDecider();

  @override
  State<_HomeDecider> createState() => _HomeDeciderState();
}

class _HomeDeciderState extends State<_HomeDecider> {
  final _settings = AppSettingsRepository();
  StreamSubscription<String>? _homeSub;
  String? _mode;

  @override
  void initState() {
    super.initState();
    _loadHome();
    _homeSub = _settings.watchHomeMode().listen((mode) {
      if (!mounted) return;
      setState(() => _mode = mode);
    });
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkGoogleAccountSetup(),
      );
    }
  }

  Future<void> _checkGoogleAccountSetup() async {
    final dismissed =
        await _settings.getString('google_setup_dismissed') == 'true';
    if (dismissed) return;
    final account = await GoogleAccountService.instance.recoverAccount();
    if (account != null) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GoogleSetupGuideDialog(
        onSetup: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
        onLater: () => Navigator.pop(ctx),
        onDismissForever: () async {
          await _settings.setString('google_setup_dismissed', 'true');
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _loadHome() async {
    final mode = await _settings.getHomeMode();
    if (!mounted) return;
    setState(() => _mode = mode);
  }

  @override
  void dispose() {
    _homeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    if (mode == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (mode == 'dashboard') {
      return const DashboardScreen();
    }
    return const InvoiceHistoryScreen();
  }
}

class _GoogleSetupGuideDialog extends StatelessWidget {
  final VoidCallback onSetup;
  final VoidCallback onLater;
  final VoidCallback onDismissForever;

  const _GoogleSetupGuideDialog({
    required this.onSetup,
    required this.onLater,
    required this.onDismissForever,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.cloud_sync, size: 48, color: Colors.indigo),
      title: const Text('Googleアカウントを連携しますか？', textAlign: TextAlign.center),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('連携すると以下の機能が使えます：'),
          SizedBox(height: 12),
          _FeatureRow(icon: Icons.backup, text: 'Google Drive へ自動バックアップ'),
          _FeatureRow(icon: Icons.sync, text: 'Gmail でチャット同期'),
          _FeatureRow(icon: Icons.restore, text: '機種変更時にデータを復元'),
          SizedBox(height: 8),
          Text(
            '設定は後からでも変更できます',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: onSetup,
              icon: const Icon(Icons.account_circle),
              label: const Text('今すぐ設定する'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onLater, child: const Text('後で')),
            TextButton(
              onPressed: onDismissForever,
              child: const Text(
                '今後は表示しない',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
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
          await customerRepo.addGpsHistory(
            invoice.customer.id,
            position.latitude,
            position.longitude,
          );
          debugPrint("GPS recorded for customer ${invoice.customer.id}");
        }
        _handleInvoiceGenerated(invoice, path);
        if (widget.onComplete != null) widget.onComplete!();
      },
    );
  }
}
