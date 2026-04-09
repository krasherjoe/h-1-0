import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 認証ヘッダー付き HTTP クライアント
class _AuthenticatedClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();

  _AuthenticatedClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // 認証ヘッダーを追加
    request.headers['Authorization'] = 'Bearer $_token';
    return await _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

/// Google API 基底サービス
/// 認証トークンの管理とリフレッシュを提供する抽象クラス
abstract class GoogleApiServiceBase {
  static const String _keyAccessToken = 'google_access_token';
  static const String _keyRefreshToken = 'google_refresh_token';
  static const String _keyTokenExpiry = 'google_token_expiry';
  // クライアント認証情報（保存用）
  static const String kClientId = 'google_client_id';
  static const String kClientSecret = 'google_client_secret';

  /// HTTP クライアントを構築するためのヘルパーメソッド
  /// トークンベースの認証を行う Google API リクエスト用
  http.Client _buildHttpClient(String token) {
    // インターセプター付きクライアントを作成
    return _AuthenticatedClient(token);
  }

  /// Google API クライアントで実行
  /// トークンを取得して HTTP クライアントを生成し、コールバックを実行
  Future<T> withClient<T>(
    Future<T> Function(http.Client client) callback,
  ) async {
    final token = await getAccessToken();
    if (token == null) {
      throw Exception('アクセストークンがありません。まず認証を行ってください。');
    }

    final httpClient = _buildHttpClient(token);
    return await callback(httpClient);
  }

  /// アクセストークンが存在するかチェック
  Future<bool> hasAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyAccessToken);
    return token != null && token.isNotEmpty;
  }

  /// アクセストークンを取得（必要に応じてリフレッシュ）
  Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_keyAccessToken);
      final expiryStr = prefs.getString(_keyTokenExpiry);

      // トークンが存在しない場合は null を返す
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[GoogleAPI] アクセストークンが存在しません');
        return null;
      }

      // 有効期限が切れていないかチェック
      if (expiryStr != null) {
        final expiry = DateTime.parse(expiryStr);
        final now = DateTime.now();

        // 5 分前に有効期限を切る（余裕を持たせる）
        if (now.isAfter(expiry.subtract(const Duration(minutes: 5)))) {
          debugPrint('[GoogleAPI] トークンが期限切れ間近です。リフレッシュ中...');
          return await _refreshAccessToken();
        }
      }

      debugPrint('[GoogleAPI] アクセストークンを取得（有効）');
      return accessToken;
    } catch (e) {
      debugPrint('[GoogleAPI] トークン取得エラー：$e');
      return null;
    }
  }

  /// リフレッシュトークンでアクセストークンをリフレッシュ
  Future<String?> _refreshAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_keyRefreshToken);
      final clientId = prefs.getString(kClientId);
      final clientSecret = prefs.getString(kClientSecret);

      if (refreshToken == null || clientId == null || clientSecret == null) {
        debugPrint('[GoogleAPI] リフレッシュに必要な情報が不足しています');
        await clearTokens();
        return null;
      }

      // Google のトークンエンドポイント
      const tokenUrl = 'https://oauth2.googleapis.com/token';

      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['access_token'] as String?;
        final expiresIn = data['expires_in'] as int?;

        if (newAccessToken != null && expiresIn != null) {
          // 新しいトークンを保存
          await prefs.setString(_keyAccessToken, newAccessToken);

          // 有効期限を計算して保存（現在時刻 + 有効時間 -5 分）
          final expiry = DateTime.now().add(
            Duration(seconds: expiresIn) - const Duration(minutes: 5),
          );
          await prefs.setString(_keyTokenExpiry, expiry.toIso8601String());

          debugPrint('[GoogleAPI] トークンリフレッシュ成功');
          return newAccessToken;
        }
      } else {
        debugPrint('[GoogleAPI] トークンリフレッシュ失敗：${response.body}');
      }

      // リフレッシュに失敗した場合はトークンをクリア
      await clearTokens();
      return null;
    } catch (e) {
      debugPrint('[GoogleAPI] トークンリフレッシュエラー：$e');
      return null;
    }
  }

  /// トークンを保存（認証後）
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    int expiresIn = 3600, // デフォルト 1 時間
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_keyAccessToken, accessToken);
      await prefs.setString(_keyRefreshToken, refreshToken);

      // 有効期限を計算して保存（現在時刻 + 有効時間 -5 分）
      final expiry = DateTime.now().add(
        Duration(seconds: expiresIn) - const Duration(minutes: 5),
      );
      await prefs.setString(_keyTokenExpiry, expiry.toIso8601String());

      debugPrint('[GoogleAPI] トークンを保存しました');
    } catch (e) {
      debugPrint('[GoogleAPI] トークン保存エラー：$e');
      rethrow;
    }
  }

  /// クライアント ID/シークレットを保存（設定用）
  Future<void> saveClientCredentials({
    required String clientId,
    required String clientSecret,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(kClientId, clientId);
      await prefs.setString(kClientSecret, clientSecret);

      debugPrint('[GoogleAPI] クライアント情報を保存しました');
    } catch (e) {
      debugPrint('[GoogleAPI] クライアント情報保存エラー：$e');
      rethrow;
    }
  }

  /// トークンをクリア（ログアウト時）
  Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyTokenExpiry);

      debugPrint('[GoogleAPI] トークンをクリアしました');
    } catch (e) {
      debugPrint('[GoogleAPI] トークンクリアエラー：$e');
    }
  }

  /// クライアント情報を削除
  Future<void> clearClientCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(kClientId);
      await prefs.remove(kClientSecret);

      debugPrint('[GoogleAPI] クライアント情報を削除しました');
    } catch (e) {
      debugPrint('[GoogleAPI] クライアント情報削除エラー：$e');
    }
  }

  /// トークンが存在し、有効期限が切れていないかチェック
  Future<bool> isTokenValid() async {
    final token = await getAccessToken();
    return token != null;
  }

  /// HTTP ヘッダーに認証情報を追加
  Map<String, String> getAuthHeaders() {
    return {'Authorization': 'Bearer {{ACCESS_TOKEN}}'};
  }

  /// Google API へのリクエスト（自動認証付与）
  Future<http.Response?> authenticatedGet(
    String url, {
    Map<String, String>? headers,
  }) async {
    final token = await getAccessToken();
    if (token == null) {
      debugPrint('[GoogleAPI] アクセストークンがありません。認証が必要です。');
      return null;
    }

    final authHeaders = {...getAuthHeaders(), ...?headers};

    try {
      final response = await http.get(Uri.parse(url), headers: authHeaders);
      return response;
    } catch (e) {
      debugPrint('[GoogleAPI] リクエストエラー：$e');
      return null;
    }
  }

  /// Google API への POST リクエスト（自動認証付与）
  Future<http.Response?> authenticatedPost(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final token = await getAccessToken();
    if (token == null) {
      debugPrint('[GoogleAPI] アクセストークンがありません。認証が必要です。');
      return null;
    }

    final authHeaders = {...getAuthHeaders(), ...?headers};

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: authHeaders,
        body: body != null ? json.encode(body) : null,
      );
      return response;
    } catch (e) {
      debugPrint('[GoogleAPI] POST リクエストエラー：$e');
      return null;
    }
  }
}
