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
import 'utils/build_expiry_info.dart';

// --- バックアップ進捗状態のデータクラス ---
/// バックアップ進捗表示用の状態管理クラス
class BackupProgressState {
  final String message;
  final double progress;
  final bool isBackingUp;
  final int? currentFileIndex;
  final int? totalFiles;
  final String? fileName;

  const BackupProgressState({
    required this.message,
    required this.progress,
    required this.isBackingUp,
    this.currentFileIndex,
    this.totalFiles,
    this.fileName,
  });

  /// 詳細メッセージを取得（ファイル名や進行度がある場合）
  String get detailedMessage {
    if (fileName != null || currentFileIndex != null) {
      final parts = <String>[message];
      if (fileName != null) {
        parts.add('📄 $fileName');
      }
      if (currentFileIndex != null && totalFiles != null) {
        parts.add('(${currentFileIndex}/${totalFiles})');
      }
      return parts.join(' ');
    }
    return message;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.instance.load();
  final expiryInfo = BuildExpiryInfo.fromEnvironment();
  // 起動時に自動バックアップチェック（非同期、アプリ起動を妨げない）
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

  // バックアップ進捗表示用の状態管理
  BackupProgressState? _backupProgressState;

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
    // 非同期リスナーからの呼び出しを防止するために mounted チェック
    if (!mounted) return;

    final isBackingUp = _backupProgressNotifier.isBackingUp;
    final message = _backupProgressNotifier.currentMessage;
    final progress = _backupProgressNotifier.progress;
    final currentFileIndex = _backupProgressNotifier.currentFileIndex;
    final totalFiles = _backupProgressNotifier.totalFiles;
    final fileName = _backupProgressNotifier.fileName;

    // 進捗中またはメッセージがある場合のみ状態更新
    if (isBackingUp || message.isNotEmpty) {
      setState(() {
        _backupProgressState = BackupProgressState(
          message: message,
          progress: progress,
          isBackingUp: isBackingUp,
          currentFileIndex: currentFileIndex,
          totalFiles: totalFiles,
          fileName: fileName,
        );
      });

      // 完了メッセージは自動的に消去されるタイマーを設定
      if (!isBackingUp && message.isNotEmpty) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _backupProgressState = null;
            });
          }
        });
      }
    } else {
      // メッセージが空の場合はクリア
      setState(() {
        _backupProgressState = null;
      });
    }
  }

  /// バックアップ進捗詳細ダイアログを表示
  void _showBackupProgressDetails(BackupProgressState state) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              state.isBackingUp
                  ? Icons.cloud_upload
                  : (state.message.contains('失敗')
                        ? Icons.error
                        : Icons.check_circle),
              color: state.isBackingUp
                  ? Colors.blue
                  : (state.message.contains('失敗') ? Colors.red : Colors.green),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.isBackingUp
                    ? 'バックアップ中'
                    : (state.message.contains('失敗')
                          ? 'バックアップ完了（失敗）'
                          : 'バックアップ完了'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 詳細メッセージ（ファイル名、進行度）
              if (state.detailedMessage.isNotEmpty) ...[
                const Text(
                  '詳細情報',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(state.detailedMessage),
                const SizedBox(height: 16),
              ],

              // 進行状況バー（拡大表示）
              const Text(
                '進行状況',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 20,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    state.isBackingUp
                        ? Colors.blue
                        : (state.message.contains('失敗')
                              ? Colors.red
                              : Colors.green),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(state.progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // ステータス情報
              const SizedBox(height: 16),
              const Text(
                'ステータス',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: state.isBackingUp
                      ? Colors.blue.shade50
                      : (state.message.contains('失敗')
                            ? Colors.red.shade50
                            : Colors.green.shade50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: state.isBackingUp
                        ? Colors.blue.shade200
                        : (state.message.contains('失敗')
                              ? Colors.red.shade200
                              : Colors.green.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.isBackingUp
                          ? Icons.hourglass_empty
                          : (state.message.contains('失敗')
                                ? Icons.error_outline
                                : Icons.check_circle_outline),
                      color: state.isBackingUp
                          ? Colors.blue.shade700
                          : (state.message.contains('失敗')
                                ? Colors.red.shade700
                                : Colors.green.shade700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.isBackingUp
                            ? 'バックアップ処理中...'
                            : (state.message.contains('失敗')
                                  ? 'エラーが発生しました'
                                  : '完了'),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: state.isBackingUp
                              ? Colors.blue.shade900
                              : (state.message.contains('失敗')
                                    ? Colors.red.shade900
                                    : Colors.green.shade900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // エラー詳細（ある場合）
              if (state.message.contains('失敗') ||
                  state.message.contains('エラー')) ...[
                const SizedBox(height: 16),
                const Text(
                  'エラー詳細',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    state.message,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if (!state.isBackingUp)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // 完了メッセージをクリア
                setState(() {
                  _backupProgressState = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
        ],
      ),
    );
  }

  void _checkFirstLaunchRestore() {
    // Web プラットフォームでは復元機能はスキップ
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
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('バックアップからの復元'),
        content: const Text(
          'Google Drive にバックアップが見つかりました。\n'
          'データを復元しますか？\n\n'
          '※現在のデータは失われます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('スキップ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performImmediateRestore();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('今すぐ復元'),
          ),
        ],
      ),
    );
  }

  // Google Drive バックアップ機能は削除されました
  // ローカルバックアップのみ利用可能です
  Future<void> _performImmediateRestore() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('復元機能について'),
        content: const Text(
          'Google Drive 連携機能は削除されました。\n'
          '代わりに、設定画面から手動でバックアップ・復元を行ってください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
    if (kIsWeb) return; // Web プラットフォームではハートビートを送信しない
    Future.microtask(() => _mothershipClient?.sendHeartbeat(widget.expiryInfo));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppThemeController.instance.notifier,
      builder: (context, themeString, _) {
        ThemeData theme;
        if (themeString == 'dark') {
          theme = ThemeData(
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
          );
        } else if (themeString == 'dark-gray') {
          theme = ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.grey.shade700,
              brightness: Brightness.dark,
              primary: Colors.grey.shade400,
              secondary: Colors.blueGrey.shade400,
              surface: Colors.grey.shade900,
              onSurface: Colors.grey.shade100,
            ),
            scaffoldBackgroundColor: const Color(0xFF1A1A1A),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey.shade900,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: Colors.grey.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade700,
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
                side: BorderSide(color: Colors.grey.shade400),
                foregroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade400,
                  width: 1.4,
                ),
              ),
              labelStyle: TextStyle(color: Colors.grey.shade400),
              hintStyle: TextStyle(color: Colors.grey.shade600),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: Colors.grey.shade800,
              contentTextStyle: TextStyle(color: Colors.grey.shade100),
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
            useMaterial3: true,
            fontFamily: 'IPAexGothic',
          );
        } else if (themeString == 'gray') {
          theme = ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.grey.shade700,
              primary: Colors.grey.shade700,
              secondary: Colors.blueGrey.shade400,
              surface: Colors.grey.shade200,
              onSurface: Colors.grey.shade900,
            ),
            scaffoldBackgroundColor: Colors.grey.shade200,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade700,
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
                side: BorderSide(color: Colors.grey.shade700),
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade700, width: 1.4),
              ),
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
            useMaterial3: true,
            fontFamily: 'IPAexGothic',
          );
        } else {
          // light or system (default to light)
          theme = ThemeData(
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
          );
        }
        
        return MaterialApp(
          title: '販売アシスト 1 号',
          theme: theme,
          themeMode: themeString == 'system' ? ThemeMode.system : ThemeMode.light,
          builder: (context, child) {
          // キーボード表示時のせり上がり問題を回避するため、InteractiveViewer は削除
          // ズーム機能が必要な画面のみに個別に適用する（必要に応じて）
          Widget widget = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: child ?? const SizedBox.shrink(),
          );

          // バックアップ進捗表示
          if (_backupProgressState != null) {
            final state = _backupProgressState!;
            widget = Stack(
              children: [
                widget,
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showBackupProgressDetails(state),
                      borderRadius: BorderRadius.circular(8),
                      child: SnackBar(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    state.message,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: state.progress,
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                        duration: state.isBackingUp
                            ? const Duration(seconds: 60)
                            : const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: state.isBackingUp
                            ? Colors.blue.shade700
                            : (state.message.contains('失敗')
                                  ? Colors.red.shade700
                                  : Colors.green.shade700),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return widget;
        },
          home: const _HomeDecider(),
        );
      },
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
                  'ビルド日時：$buildText',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '有効期限：$expiryText',
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
        // GPS の記録を試みる
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
