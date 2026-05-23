import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../server/client_config.dart';

class RemoteConfigScreen extends StatefulWidget {
  const RemoteConfigScreen({super.key});
  @override
  State<RemoteConfigScreen> createState() => _RemoteConfigScreenState();
}

class _RemoteConfigScreenState extends State<RemoteConfigScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _enabled = false;
  String? _testResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await RemoteConfig.load();
    _hostCtrl.text = cfg.host;
    _portCtrl.text = cfg.port.toString();
    _keyCtrl.text = cfg.apiKey;
    _enabled = cfg.enabled;
    setState(() {});
  }

  Future<void> _save() async {
    final cfg = RemoteConfig(
      host: _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text.trim()) ?? 8080,
      apiKey: _keyCtrl.text.trim(),
      enabled: _enabled,
    );
    await cfg.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('設定を保存しました')),
    );
  }

  Future<void> _test() async {
    setState(() { _testing = true; _testResult = null; });
    try {
      final host = _hostCtrl.text.trim();
      final port = int.tryParse(_portCtrl.text.trim()) ?? 8080;
      final key = _keyCtrl.text.trim();
      final res = await http.get(
        Uri.parse('http://$host:$port/health'),
        headers: {'x-api-key': key},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        setState(() => _testResult = '接続OK: ${json['version'] ?? ''}');
      } else {
        setState(() => _testResult = 'エラー: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _testResult = '接続失敗: $e');
    }
    setState(() => _testing = false);
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('RC:サーバー接続設定'),
        actions: [
          TextButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('サーバーモード'),
            subtitle: const Text('ON: リモートサーバー経由でデータ操作'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostCtrl,
            decoration: const InputDecoration(labelText: 'サーバーホスト', hintText: 'example.ddns.net', border: OutlineInputBorder()),
            enabled: _enabled,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ポート', hintText: '8080', border: OutlineInputBorder()),
            enabled: _enabled,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyCtrl,
            decoration: const InputDecoration(labelText: 'APIキー', border: OutlineInputBorder()),
            obscureText: true,
            enabled: _enabled,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: (_enabled && !_testing) ? _test : null,
            icon: _testing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_find),
            label: Text(_testing ? 'テスト中...' : '接続テスト'),
          ),
          if (_testResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_testResult!, style: TextStyle(
                color: _testResult!.startsWith('接続OK') ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              )),
            ),
        ],
      ),
    );
  }
}
