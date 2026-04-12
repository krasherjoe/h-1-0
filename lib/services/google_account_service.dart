import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_api_service_base.dart';

/// Google アカウント管理サービス
/// ユーザーの Google アカウント認証とトークン管理を担当
class GoogleAccountService extends GoogleApiServiceBase {
  static const String _keyGoogleEmail = 'google_email';
  static const String _keyGoogleName = 'google_name';
  static const String _keyGoogleId = 'google_id';

  // シングルトンインスタンス
  static final GoogleAccountService instance = GoogleAccountService._internal();

  factory GoogleAccountService() {
    return instance;
  }

  GoogleAccountService._internal();

  // Google Sign-In インスタンス（開発用）
  late final GoogleSignIn _googleSignIn;

  // 初期化状態管理
  bool _isInitialized = false;

  // 初期化メソッド（ランチャーから呼び出し）
  void init() {
    _googleSignIn = GoogleSignIn(
      scopes: [
        'email',
        'https://www.googleapis.com/auth/drive.file',
        'https://www.googleapis.com/auth/gmail.send',
      ],
    );
    _isInitialized = true;
  }

  /// Google アカウントにログイン
  /// [forceAccountPicker] true の場合、アカウント選択画面を強制表示（複数アカウント対応）
  Future<bool> signIn({bool forceAccountPicker = true}) async {
    try {
      debugPrint('[GoogleAccount] ログイン開始');

      // Google Sign-In が未初期化の場合は初期化
      if (!_isInitialized) {
        init();
      }

      // 既にログインしている場合は確認
      final currentUser = _googleSignIn.currentUser;
      if (currentUser != null) {
        // 強制選択モード：サインアウトして選択画面を表示
        if (forceAccountPicker) {
          debugPrint('[GoogleAccount] アカウント選択画面を強制表示');
          await _googleSignIn.signOut();
        } else {
          debugPrint('[GoogleAccount] 既にログイン済み');
          return true;
        }
      }

      // Google ログイン実行（複数アカウントがある場合は選択画面が表示される）
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('[GoogleAccount] ログインキャンセル');
        return false;
      }

      // トークン情報を取得
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        debugPrint('[GoogleAccount] トークン取得に失敗');
        return false;
      }

      // トークンを保存（リフレッシュトークンは ID トークンから取得）
      await saveTokens(
        accessToken: accessToken,
        refreshToken: idToken, // 開発環境では ID トークンをリフレッシュ用に使用
        expiresIn: 3600,
      );

      // ユーザー情報を保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyGoogleEmail, googleUser.email);
      await prefs.setString(_keyGoogleName, googleUser.displayName ?? '');
      await prefs.setString(_keyGoogleId, googleUser.id);

      debugPrint('[GoogleAccount] ログイン成功：${googleUser.email}');
      return true;
    } catch (e) {
      debugPrint('[GoogleAccount] ログインエラー：$e');
      return false;
    }
  }

  /// Google アカウントからログアウト
  Future<bool> signOut() async {
    try {
      debugPrint('[GoogleAccount] ログアウト開始');

      // トークンをクリア
      await clearTokens();

      // ユーザー情報を削除
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyGoogleEmail);
      await prefs.remove(_keyGoogleName);
      await prefs.remove(_keyGoogleId);

      // Google Sign-In をログアウト（初期化されている場合のみ）
      if (_isInitialized) {
        await _googleSignIn.signOut();
        _isInitialized = false;
      }

      debugPrint('[GoogleAccount] ログアウト成功');
      return true;
    } catch (e) {
      debugPrint('[GoogleAccount] ログアウトエラー：$e');
      return false;
    }
  }

  /// 現在ログイン中のユーザー情報を取得
  Future<Map<String, String>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_keyGoogleEmail);
      final name = prefs.getString(_keyGoogleName);
      final id = prefs.getString(_keyGoogleId);

      if (email == null) {
        return null; // ログインしていない
      }

      return {'email': email, 'name': name ?? '', 'id': id ?? ''};
    } catch (e) {
      debugPrint('[GoogleAccount] ユーザー情報取得エラー：$e');
      return null;
    }
  }

  /// Google アカウントがログイン済みかチェック
  Future<bool> isSignedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_keyGoogleEmail);
      return email != null && email.isNotEmpty;
    } catch (e) {
      debugPrint('[GoogleAccount] ログイン状態チェックエラー：$e');
      return false;
    }
  }

  /// クライアント ID/シークレットを設定（管理者用）
  Future<void> setClientCredentials({
    required String clientId,
    required String clientSecret,
  }) async {
    await saveClientCredentials(clientId: clientId, clientSecret: clientSecret);
  }

  /// クライアント情報を取得
  Future<Map<String, String>?> getClientCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString(GoogleApiServiceBase.kClientId);
      final clientSecret = prefs.getString(GoogleApiServiceBase.kClientSecret);

      if (clientId == null || clientSecret == null) {
        return null;
      }

      return {
        'clientId': clientId,
        'clientSecret': clientSecret, // 本番環境では非推奨（ログ出力に注意）
      };
    } catch (e) {
      debugPrint('[GoogleAccount] クライアント情報取得エラー：$e');
      return null;
    }
  }

  /// Google Drive API のスコープを持つリクエストヘッダーを取得
  Map<String, String> getDriveAuthHeaders() {
    final baseHeaders = getAuthHeaders();
    baseHeaders['X-Upload-Type'] = 'multipart';
    return baseHeaders;
  }

  /// Gmail API のスコープを持つリクエストヘッダーを取得
  Map<String, String> getGmailAuthHeaders() {
    return getAuthHeaders();
  }

  /// 現在ログイン中のユーザー情報を取得
  Future<GoogleSignInAccount?> getCurrentAccount() async {
    // 既にログインしている場合は確認
    try {
      if (_googleSignIn == null) {
        init();
      }
      return _googleSignIn.currentUser;
    } catch (e) {
      debugPrint('[GoogleAccount] 現在アカウント取得エラー：$e');
      return null;
    }
  }

  /// トークン情報をデバッグ用に出力
  Future<void> debugPrintTokenInfo() async {
    final hasToken = await hasAccessToken();
    debugPrint('[GoogleAccount] トークン存在：$hasToken');

    if (hasToken) {
      final user = await getCurrentUser();
      if (user != null) {
        debugPrint(
          '[GoogleAccount] 現在のユーザー：${user['email']} (${user['name']})',
        );
      }

      // クライアント情報を確認（シークレットはハッシュ化して表示）
      final creds = await getClientCredentials();
      if (creds != null) {
        debugPrint('[GoogleAccount] クライアント ID: ${creds['clientId']}');
        // セキュリティのためシークレットは一部のみ表示
        final secret = creds['clientSecret'] ?? '';
        debugPrint(
          '[GoogleAccount] クライアントシークレット：${secret.substring(0, 4)}...${secret.substring(secret.length - 4)}',
        );
      }
    }
  }
}
