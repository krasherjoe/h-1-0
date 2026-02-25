import 'package:flutter/material.dart';
import 'company_info_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showPlaceholder(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title の設定は後で追加してください')),
    );
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('テーマ選択', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.brightness_5),
              title: const Text('ライト'),
              onTap: () {
                Navigator.pop(context);
                _showPlaceholder(context, 'ライトテーマ適用');
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_3),
              title: const Text('ダーク'),
              onTap: () {
                Navigator.pop(context);
                _showPlaceholder(context, 'ダークテーマ適用');
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('システムに従う'),
              onTap: () {
                Navigator.pop(context);
                _showPlaceholder(context, 'システムテーマ適用');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('自社情報'),
            subtitle: const Text('会社名・住所・登録番号など'),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const CompanyInfoScreen()));
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('担当者情報'),
            subtitle: const Text('自社担当者の署名・連絡先'),
            onTap: () => _showPlaceholder(context, '担当者情報'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('SMTP情報'),
            subtitle: const Text('メール送信サーバ設定'),
            onTap: () => _showPlaceholder(context, 'SMTP情報'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('バックアップドライブ'),
            subtitle: const Text('バックアップ先のクラウド/ローカルドライブ'),
            onTap: () => _showPlaceholder(context, 'バックアップドライブ'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('テーマ選択'),
            subtitle: const Text('配色や見た目を切り替え'),
            onTap: () => _showThemePicker(context),
          ),
        ],
      ),
    );
  }
}
