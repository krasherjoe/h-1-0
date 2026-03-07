import 'package:http/http.dart' as http;

import 'google_account_service.dart';

/// Google API 呼び出し時に共通で利用する HTTP クライアント。
/// GoogleSignIn で取得したトークン付きヘッダを各リクエストへ自動付与する。
class GoogleAuthHttpClient extends http.BaseClient {
  GoogleAuthHttpClient(Map<String, String> baseHeaders, {http.Client? inner})
      : _headers = Map<String, String>.unmodifiable(baseHeaders),
        _inner = inner ?? http.Client();

  final Map<String, String> _headers;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Google API サービス実装が継承する共通ベースクラス。
/// 認証付き HTTP クライアントを安全に生成・破棄するためのユーティリティを提供する。
abstract class GoogleApiServiceBase {
  GoogleApiServiceBase({GoogleAccountService? accountService}) : _accountService = accountService ?? GoogleAccountService.instance;

  final GoogleAccountService _accountService;

  Future<T> withClient<T>(Future<T> Function(GoogleAuthHttpClient client) action) async {
    final headers = await _accountService.getAuthHeaders();
    final client = GoogleAuthHttpClient(headers);
    try {
      return await action(client);
    } finally {
      client.close();
    }
  }
}
