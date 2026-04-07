import 'package:flutter/services.dart';

/// Android OS 標準アカウントピッカーを呼び出すサービス。
/// AccountManager.newChooseAccountIntent を使い、
/// OAuth 不要・権限不要で全 Google アカウントを表示して選択させる。
class DeviceAccountService {
  static const _channel = MethodChannel('com.example.h_1/device_accounts');

  /// OS 標準の Google アカウント選択 UI を起動し、
  /// ユーザーが選択したメールアドレスを返す。
  /// キャンセル時は null を返す。
  static Future<String?> pickGoogleAccount() async {
    try {
      final email = await _channel.invokeMethod<String>('pickGoogleAccount');
      return email;
    } catch (e) {
      return null;
    }
  }
}
