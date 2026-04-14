import 'package:flutter/material.dart';
import '../services/app_settings_repository.dart';
import '../services/theme_controller.dart';
import 'invoice_input_screen.dart';

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
        title: const Text('S1:テーマ設定'),
      ),
      body: Column(
        children: [
          // テーマ選択セクション
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'アプリテーマ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'system',
                      label: Text('システム'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: 'light',
                      label: Text('ライト'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: 'dark',
                      label: Text('ダーク'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {_theme},
                  onSelectionChanged: (s) async {
                    await AppThemeController.instance.setTheme(s.first);
                    setState(() => _theme = s.first);
                  },
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
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'サマリーテーマ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'white',
                      label: Text('ホワイト'),
                      icon: Icon(Icons.brightness_7),
                    ),
                    ButtonSegment(
                      value: 'gray',
                      label: Text('グレー'),
                      icon: Icon(Icons.color_lens),
                    ),
                  ],
                  selected: {_summaryTheme},
                  onSelectionChanged: (s) async {
                    await _repo.setSummaryTheme(s.first);
                    setState(() => _summaryTheme = s.first);
                  },
                ),
              ],
            ),
          ),
          // プレビューセクション
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.grey.shade50,
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
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    // 伝票入力画面の簡易プレビュー
    final themeColor = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final labelColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return Container(
      color: themeColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AppBar
          Container(
            color: Colors.blue.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.arrow_back, color: Colors.white),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "A1:請求書",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                        const Divider(color: Colors.grey),
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
                      color: isDark ? const Color(0xFF3A3A3A) : Colors.blue.shade50,
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
                            color: Colors.blue.shade700,
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
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
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
}
