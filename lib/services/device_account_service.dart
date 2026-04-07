import 'package:flutter/services.dart';

/// Android AccountManager 経由でデバイスに登録済みの
/// Google アカウント一覧を取得するサービス。
/// OAuth 不要でローカルの com.google アカウントを列挙する。
class DeviceAccountService {
  static const _channel = MethodChannel('com.example.h_1/device_accounts');

  /// デバイスに登録されている Google アカウントのメールアドレス一覧を返す。
  /// 取得できない場合は空リストを返す。
  static Future<List<String>> getGoogleAccounts() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getGoogleAccounts');
      return result?.cast<String>() ?? [];
    } catch (e) {
      return [];
    }
  }
}
