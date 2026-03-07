import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

/// Googleアカウント連携とアクセストークン管理を司るサービス。
/// Gmail／Drive／Sheets／Calendarで共通利用するOAuthセッションを一元管理する。
class GoogleAccountService {
  GoogleAccountService._internal() {
    _googleSignIn.onCurrentUserChanged.listen(_accountController.add);
  }

  static final GoogleAccountService instance = GoogleAccountService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const [
      'email',
      'https://www.googleapis.com/auth/gmail.modify',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/spreadsheets',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  final StreamController<GoogleSignInAccount?> _accountController = StreamController.broadcast();

  /// 現在の連携アカウント。
  GoogleSignInAccount? get currentAccount => _googleSignIn.currentUser;

  /// 連携アカウントが変化した際に通知されるストリーム。
  Stream<GoogleSignInAccount?> get accountStream => _accountController.stream;

  /// サイレントログインで既存のセッションを復元する。
  Future<GoogleSignInAccount?> recoverAccount() async {
    try {
      final account = await _googleSignIn.signInSilently();
      return account ?? _googleSignIn.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// ユーザーにアカウント選択UIを提示する。
  Future<GoogleSignInAccount?> pickAccount() async {
    final account = await _googleSignIn.signIn();
    return account;
  }

  /// 連携を解除し、トークンを破棄する。
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } finally {
      _accountController.add(null);
    }
  }

  /// Google API呼び出し時に使用するHTTPヘッダを取得する。
  Future<Map<String, String>> getAuthHeaders() async {
    final account = currentAccount ?? await recoverAccount();
    if (account == null) {
      throw StateError('Googleアカウントに未連携です');
    }
    return account.authHeaders;
  }

  /// Bearerトークンのみ必要なケース向けにトークン文字列を返す。
  Future<String?> getAccessToken() async {
    final headers = await getAuthHeaders();
    final auth = headers['Authorization'];
    if (auth == null) return null;
    if (!auth.startsWith('Bearer ')) return auth;
    return auth.substring(7);
  }
}
