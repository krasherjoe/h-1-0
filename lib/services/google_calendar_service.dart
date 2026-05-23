import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

/// Google Calendar 入金予定連携サービス（簡易版）
class GoogleCalendarService {
  static final GoogleCalendarService _instance = GoogleCalendarService._();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._();

  /// Bearerトークン付きHTTPクライアント
  http.Client _client(String token) {
    return _AuthClient(token);
  }

  /// 入金予定をGoogleカレンダーに追加
  Future<bool> addPaymentEvent({
    required String title,
    required DateTime dueDate,
    String? description,
  }) async {
    try {
      final googleUser = await GoogleSignIn().signInSilently();
      if (googleUser == null) {
        debugPrint('[GoogleCalendar] 未認証');
        return false;
      }

      final authHeaders = await googleUser.authHeaders;
      final token = authHeaders['Authorization']?.replaceFirst('Bearer ', '');
      if (token == null) return false;

      final dateStr = '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
      final body = '''
{
  "summary": "${_escapeJson(title)}",
  "description": "${_escapeJson(description ?? '')}",
  "start": {"date": "$dateStr", "timeZone": "Asia/Tokyo"},
  "end": {"date": "$dateStr", "timeZone": "Asia/Tokyo"}
}''';

      final res = await _client(token).post(
        Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (res.statusCode == 200) {
        debugPrint('[GoogleCalendar] イベント作成成功');
        final eventJson = jsonDecode(res.body);
        return true;
      }
      debugPrint('[GoogleCalendar] エラー: ${res.statusCode} ${res.body}');
      return false;
    } catch (e) {
      debugPrint('[GoogleCalendar] エラー: $e');
      return false;
    }
  }

  /// 入金予定イベントを削除（タイトルで検索して削除）
  Future<bool> deletePaymentEvent(String titleKeyword) async {
    try {
      final googleUser = await GoogleSignIn().signInSilently();
      if (googleUser == null) return false;
      final authHeaders = await googleUser.authHeaders;
      final token = authHeaders['Authorization']?.replaceFirst('Bearer ', '');
      if (token == null) return false;

      // イベントを検索
      final query = Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events')
          .replace(queryParameters: {'q': titleKeyword, 'maxResults': '10'});
      final res = await _client(token).get(query);
      if (res.statusCode != 200) return false;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final eventId = (item as Map<String, dynamic>)['id'] as String?;
        if (eventId != null) {
          await _client(token).delete(
            Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId'),
          );
        }
      }
      debugPrint('[GoogleCalendar] ${items.length}件削除');
      return items.isNotEmpty;
    } catch (e) {
      debugPrint('[GoogleCalendar] 削除エラー: $e');
      return false;
    }
  }

  String _escapeJson(String s) => s.replaceAll('"', '\\"').replaceAll('\n', '\\n');
}

/// Bearerトークン認証を行うHTTPクライアント
class _AuthClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();
  _AuthClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
