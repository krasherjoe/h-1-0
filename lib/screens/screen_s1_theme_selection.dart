import 'package:flutter/material.dart';
import '../services/app_settings_repository.dart';
import '../services/theme_controller.dart';
import 'invoice_input_screen.dart';
import 'screen_th2_theme_customizer.dart';

class ThemeSelectionScreen extends StatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  State<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends State<ThemeSelectionScreen> {
  final _repo = AppSettingsRepository();
  String _theme = 'system';
  String _summaryTheme = 'white';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final theme = await _repo.getTheme();
    final summaryTheme = await _repo.getSummaryTheme();
    setState(() {
      _theme = theme;
      _summaryTheme = summaryTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TH:テーマ設定'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // テーマ選択セクション
            Container(
              padding: const EdgeInsets.all(16),
              margin: const  EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'アプリテーマ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildThemeListTile(
                    value: 'system',
                    title: 'システム設定に従う',
                    subtitle: '端末の設定に合わせて自動的に切り替え',
                    icon: Icons.brightness_auto,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _buildThemeListTile(
                    value: 'light',
                    title: 'ライト',
                    subtitle: '明るい白ベースのテーマ',
                    icon: Icons.light_mode,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  _buildThemeListTile(
                    value: 'gray',
                    title: 'グレー',
                    subtitle: '落ち着いた灰色ベースのテーマ',
                    icon: Icons.color_lens,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  _buildThemeListTile(
                    value: 'dark-gray',
                    title: 'ダークグレー',
                    subtitle: '落ち着いた濃い灰色のテーマ（明るめ）',
                    icon: Icons.nights_stay,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  _buildThemeListTile(
                    value: 'dark',
                    title: 'ダーク',
                    subtitle: '黒ベースのダークテーマ',
                    icon: Icons.dark_mode,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _buildThemeListTile(
                    value: 'custom',
                    title: 'カスタム',
                    subtitle: '色を自由にカスタマイズ',
                    icon: Icons.palette,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(height: 8),
                  // カスタムテーマ編集ボタン
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.tune),
                      label: const Text('カラーをカスタマイズ (TH2)'),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScreenTh2ThemeCustomizer(),
                          ),
                        );
                        if (mounted) await _loadSettings();
                      },
                    ),
                  ),
                ],
              ),
            ),
            // サマリーテーマ選択セクション
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'サマリーテーマ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryThemeListTile(
                    value: 'white',
                    title: 'ホワイト',
                    subtitle: '白背景で表示',
                    icon: Icons.brightness_7,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  _buildSummaryThemeListTile(
                    value: 'gray',
                    title: 'グレー',
                    subtitle: 'グレー背景で表示',
                    icon: Icons.color_lens,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
            ),
            // プレビューセクション
            Container(
              height: 400,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '伝票入力画面プレビュー',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: _buildPreview(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    // 伝票入力画面の簡易プレビュー
    final themeColor = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Theme.of(context).colorScheme.surface;
    final borderColor = isDark ? Theme.of(context).colorScheme.outlineVariant : Theme.of(context).colorScheme.outlineVariant;
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      color: themeColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AppBar
          Container(
            color: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "",
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // コンテンツ
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 得意先セクション
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '得意先',
                          style: TextStyle(
                            fontSize: 14,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '株式会社サンプル',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 明細セクション
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '品名',
                          style: TextStyle(
                            fontSize: 14,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'サンプル商品',
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '単価',
                              style: TextStyle(
                                fontSize: 14,
                                color: labelColor,
                              ),
                            ),
                            Text(
                              '¥5,000',
                              style: TextStyle(
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '数量',
                              style: TextStyle(
                                fontSize: 14,
                                color: labelColor,
                              ),
                            ),
                            Text(
                              '2',
                              style: TextStyle(
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(color: Theme.of(context).colorScheme.outlineVariant),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '小計',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: labelColor,
                              ),
                            ),
                            Text(
                              '¥10,000',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 合計セクション
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                       color: isDark ? const Color(0xFF3A3A3A) : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           '合計',
                           style: TextStyle(
                             fontSize: 18,
                             fontWeight: FontWeight.bold,
                             color: textColor,
                           ),
                         ),
                         Text(
                           '¥10,000',
                           style: TextStyle(
                             fontSize: 24,
                             fontWeight: FontWeight.bold,
                             color: Theme.of(context).colorScheme.primary,
                           ),
                         ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ボタン
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('保存', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('キャンセル', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeListTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _theme == value;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? color.withOpacity(0.15) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: color)
            : Icon(Icons.circle_outlined, color: Theme.of(context).colorScheme.outlineVariant),
        onTap: () async {
          await AppThemeController.instance.setTheme(value);
          setState(() => _theme = value);
        },
      ),
    );
  }

  Widget _buildSummaryThemeListTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _summaryTheme == value;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? color.withOpacity(0.15) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
            : Icon(Icons.circle_outlined, color: Theme.of(context).colorScheme.outlineVariant),
        onTap: () async {
          await _repo.setSummaryTheme(value);
          setState(() => _summaryTheme = value);
        },
      ),
    );
  }
}
