import 'package:flutter/foundation.dart';

/// バックアップ進捗を通知するクラス
class BackupProgressNotifier extends ChangeNotifier {
  static final BackupProgressNotifier _instance = BackupProgressNotifier._internal();

  factory BackupProgressNotifier() => _instance;

  BackupProgressNotifier._internal();

  bool _isBackingUp = false;
  String _currentMessage = '';
  double _progress = 0.0;

  bool get isBackingUp => _isBackingUp;
  String get currentMessage => _currentMessage;
  double get progress => _progress;

  /// バックアップ開始
  void startBackup() {
    _isBackingUp = true;
    _currentMessage = 'バックアップを開始しています...';
    _progress = 0.0;
    notifyListeners();
  }

  /// ローカルバックアップ進捗更新
  void updateLocalBackupProgress(String message) {
    _currentMessage = message;
    _progress = 0.33;
    notifyListeners();
  }

  /// Google Drive バックアップ進捗更新
  void updateDriveBackupProgress(String message) {
    _currentMessage = message;
    _progress = 0.66;
    notifyListeners();
  }

  /// バックアップ完了
  void completeBackup() {
    _currentMessage = 'バックアップが完了しました';
    _progress = 1.0;
    notifyListeners();
    
    // 2秒後に状態をリセット
    Future.delayed(const Duration(seconds: 2), () {
      _isBackingUp = false;
      _currentMessage = '';
      _progress = 0.0;
      notifyListeners();
    });
  }

  /// バックアップ失敗
  void failBackup(String error) {
    _currentMessage = 'バックアップに失敗しました: $error';
    _progress = 0.0;
    notifyListeners();
    
    // 3秒後に状態をリセット
    Future.delayed(const Duration(seconds: 3), () {
      _isBackingUp = false;
      _currentMessage = '';
      notifyListeners();
    });
  }

  /// 状態をリセット
  void reset() {
    _isBackingUp = false;
    _currentMessage = '';
    _progress = 0.0;
    notifyListeners();
  }
}
