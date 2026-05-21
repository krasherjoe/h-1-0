import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../services/theme_controller.dart';

/// TH2: カラーカスタマイズ画面
/// プレビュー上の各要素をタップして色を割り当てるエディタ。
class ScreenTh2ThemeCustomizer extends StatefulWidget {
  const ScreenTh2ThemeCustomizer({super.key});

  @override
  State<ScreenTh2ThemeCustomizer> createState() =>
      _ScreenTh2ThemeCustomizerState();
}

class _ColorSlot {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  const _ColorSlot({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class _ScreenTh2ThemeCustomizerState extends State<ScreenTh2ThemeCustomizer> {
  static const List<_ColorSlot> _slots = [
    _ColorSlot(
      key: 'primary',
      label: 'AppBar・主要ボタン背景',
      description: 'タイトルバーやFABの背景色',
      icon: Icons.title,
    ),
    _ColorSlot(
      key: 'onPrimary',
      label: 'AppBar文字・アイコン',
      description: 'タイトルバー上の文字色（重要）',
      icon: Icons.text_fields,
    ),
    _ColorSlot(
      key: 'secondary',
      label: 'アクセント色',
      description: '強調・リンクなど',
      icon: Icons.auto_awesome,
    ),
    _ColorSlot(
      key: 'scaffoldBg',
      label: '画面背景',
      description: 'コンテンツ領域の背景',
      icon: Icons.layers,
    ),
    _ColorSlot(
      key: 'surface',
      label: 'カード背景',
      description: 'カード・ダイアログの背景',
      icon: Icons.crop_square,
    ),
    _ColorSlot(
      key: 'onSurface',
      label: 'カード文字',
      description: 'カード上の本文の色',
      icon: Icons.notes,
    ),
    _ColorSlot(
      key: 'error',
      label: 'エラー色',
      description: '削除・警告など',
      icon: Icons.error_outline,
    ),
  ];

  // パレット（16色）
  static const List<int> _palette = [
    0xFFFFFFFF, 0xFFF5F5F5, 0xFFE0E0E0, 0xFF9E9E9E,
    0xFF424242, 0xFF212121, 0xFF000000, 0xFFB00020,
    0xFF303F9F, 0xFF1976D2, 0xFF0288D1, 0xFF00897B,
    0xFF388E3C, 0xFFFBC02D, 0xFFFF7043, 0xFF8E24AA,
  ];

  late Map<String, int> _colors;
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    final current = AppThemeController.instance.customColorsNotifier.value;
    _colors = Map<String, int>.from(
      current.isEmpty ? AppThemeController.defaultCustomColors() : current,
    );
    _selectedKey = 'onPrimary'; // タイトルバー文字色を初期選択（よく問題になる）
  }

  Color _c(String key) =>
      Color(_colors[key] ?? AppThemeController.defaultCustomColors()[key]!);

  /// WCAG コントラスト比を計算（1.0〜21.0）
  double _contrastRatio(Color a, Color b) {
    double luminance(Color c) => c.computeLuminance();
    final la = luminance(a);
    final lb = luminance(b);
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  String _wcagLevel(double ratio) {
    if (ratio >= 7.0) return 'AAA';
    if (ratio >= 4.5) return 'AA';
    if (ratio >= 3.0) return 'AA(大)';
    return '不足';
  }

  Color _wcagColor(double ratio) {
    if (ratio >= 4.5) return Colors.green;
    if (ratio >= 3.0) return Colors.orange;
    return Colors.red;
  }

  Future<void> _pickColor(String key) async {
    setState(() => _selectedKey = key);
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ColorPickerSheet(
        currentColor: _c(key),
        slotLabel: _slots.firstWhere((s) => s.key == key).label,
        palette: _palette,
      ),
    );
    if (picked != null) {
      setState(() => _colors[key] = picked);
    }
  }

  Future<void> _save() async {
    await AppThemeController.instance.setCustomColors(_colors);
    await AppThemeController.instance.setTheme('custom');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ カスタムテーマを保存しました')),
    );
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _colors = Map<String, int>.from(
        AppThemeController.defaultCustomColors(),
      );
    });
  }

  /// カスタムテーマをJSONファイルとしてダウンロードフォルダにエクスポート
  Future<void> _exportTheme() async {
    try {
      final dir = await _getDownloadDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/theme_custom_$stamp.json');
      final Map<String, dynamic> data = {
        'version': 1,
        'colors': Map<String, int>.from(_colors),
      };
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📤 エクスポート完了: ${file.path}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ エクスポート失敗: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// ファイルからカスタムテーマをインポート
  Future<void> _importTheme() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        initialDirectory: Platform.isAndroid
            ? '/storage/emulated/0/Download'
            : (await getApplicationDocumentsDirectory()).path,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      final content = await File(path).readAsString();
      final decoded = jsonDecode(content);
      final Map<String, dynamic> raw = decoded is Map
          ? (decoded['colors'] as Map<String, dynamic>? ?? decoded.cast<String, dynamic>())
          : {};
      final imported = <String, int>{};
      raw.forEach((k, v) {
        if (v is int) imported[k] = v;
      });
      if (imported.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ 有効な色データが見つかりませんでした')),
        );
        return;
      }
      setState(() {
        _colors = Map<String, int>.from({
          ...AppThemeController.defaultCustomColors(),
          ...imported,
        });
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📥 インポート完了: ${imported.length}色'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ インポート失敗: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  static Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }
    return getApplicationDocumentsDirectory();
  }

  @override
  Widget build(BuildContext context) {
    final primary = _c('primary');
    final onPrimary = _c('onPrimary');
    final ratio = _contrastRatio(primary, onPrimary);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TH2:カラーカスタマイズ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'デフォルトに戻す',
            onPressed: _reset,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'JSONをインポート',
            onPressed: _importTheme,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'JSONをエクスポート',
            onPressed: _exportTheme,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存して適用',
            onPressed: _save,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          // ===== 上半分: ライブプレビュー =====
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildPreview(ratio),
              ),
            ),
          ),
          // ===== 下半分: 色スロット一覧 =====
          Expanded(
            flex: 6,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _slots.length,
              itemBuilder: (ctx, i) {
                final slot = _slots[i];
                final color = _c(slot.key);
                final selected = _selectedKey == slot.key;
                return Card(
                  elevation: selected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: selected
                        ? BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black26),
                          ),
                        ),
                        Icon(
                          slot.icon,
                          color: ThemeData.estimateBrightnessForColor(color) ==
                                  Brightness.dark
                              ? Colors.white70
                              : Colors.black54,
                          size: 20,
                        ),
                      ],
                    ),
                    title: Text(
                      slot.label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${slot.description}  •  #${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickColor(slot.key),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildPreview(double appBarContrastRatio) {
    final primary = _c('primary');
    final onPrimary = _c('onPrimary');
    final secondary = _c('secondary');
    final scaffoldBg = _c('scaffoldBg');
    final surface = _c('surface');
    final onSurface = _c('onSurface');
    final error = _c('error');

    return Container(
      color: scaffoldBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 模擬 AppBar
          GestureDetector(
            onTap: () => _pickColor('primary'),
            child: Container(
              color: primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.menu, color: onPrimary, size: 20),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _pickColor('onPrimary'),
                    child: Text(
                      'IH:伝票一覧 v1.5.09',
                      style: TextStyle(
                        color: onPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.search, color: onPrimary, size: 20),
                ],
              ),
            ),
          ),
          // WCAG コントラスト表示
          Container(
            color: scaffoldBg,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.contrast,
                    size: 14, color: _wcagColor(appBarContrastRatio)),
                const SizedBox(width: 6),
                Text(
                  'タイトルバー対比 ${appBarContrastRatio.toStringAsFixed(1)}:1 '
                  '[${_wcagLevel(appBarContrastRatio)}]',
                  style: TextStyle(
                    fontSize: 11,
                    color: _wcagColor(appBarContrastRatio),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 模擬カード
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () => _pickColor('surface'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _pickColor('onSurface'),
                            child: Text(
                              '株式会社サンプル様',
                              style: TextStyle(
                                color: onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '¥10,000',
                            style: TextStyle(
                              color: onSurface.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ボタン群
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickColor('primary'),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '保存',
                              style: TextStyle(
                                color: onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickColor('secondary'),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: secondary, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'アクション',
                              style: TextStyle(
                                color: secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _pickColor('error'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: error),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: error, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '削除確認メッセージ',
                            style: TextStyle(
                                color: error, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
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

/// 色選択ボトムシート: パレット + RGB スライダー
class _ColorPickerSheet extends StatefulWidget {
  final Color currentColor;
  final String slotLabel;
  final List<int> palette;

  const _ColorPickerSheet({
    required this.currentColor,
    required this.slotLabel,
    required this.palette,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.currentColor);
  }

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.slotLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '#${_color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('プリセット', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.palette.map((c) {
                final color = Color(c);
                return GestureDetector(
                  onTap: () => Navigator.pop(context, c),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('微調整 (HSV)', style: TextStyle(fontWeight: FontWeight.bold)),
            _buildSlider(
              '色相',
              _hsv.hue,
              0,
              360,
              (v) => setState(() => _hsv = _hsv.withHue(v)),
            ),
            _buildSlider(
              '彩度',
              _hsv.saturation,
              0,
              1,
              (v) => setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            _buildSlider(
              '明度',
              _hsv.value,
              0,
              1,
              (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _color.toARGB32()),
                    child: const Text('決定'),
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(max <= 1 ? 2 : 0),
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
