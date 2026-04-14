import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/company_model.dart';
import '../services/company_repository.dart';
import '../services/company_info_export_import.dart';
import '../widgets/keyboard_inset_wrapper.dart';

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({super.key});

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  final CompanyRepository _companyRepo = CompanyRepository();
  late CompanyInfo _info;
  bool _isLoading = true;

  final _nameController = TextEditingController();
  final _zipController = TextEditingController();
  final _addressController = TextEditingController();
  final _telController = TextEditingController();
  final _emailController = TextEditingController();
  final _faxController = TextEditingController();
  final _urlController = TextEditingController();
  double _taxRate = 0.10;
  String _taxDisplayMode = 'normal';
  bool _hasRegistrationNumber = false;
  final _regNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      _info = await _companyRepo.getCompanyInfo();
      if (!mounted) return;
      
      _nameController.text = _info.name;
      _zipController.text = _info.zipCode ?? "";
      _addressController.text = _info.address ?? "";
      _telController.text = _info.tel ?? "";
      _emailController.text = _info.email ?? "";
      _faxController.text = _info.fax ?? "";
      _urlController.text = _info.url ?? "";
      _taxRate = _info.defaultTaxRate;
      _taxDisplayMode = _info.taxDisplayMode;
      _hasRegistrationNumber = _info.registrationNumber != null && _info.registrationNumber!.isNotEmpty;
      // Tプレフィックスがあれば除去して表示（TextFieldにprefixText: 'T'があるため）
      _regNumberController.text = _info.registrationNumber?.replaceFirst('T', '') ?? '';
      setState(() => _isLoading = false);
    } catch (e) {
      print('F1 会社情報読み込みエラー: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showSealPicker({bool isReEdit = false}) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isReEdit && _info.sealPath != null)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('現在の角印を再編集', style: TextStyle(color: Colors.blue)),
                onTap: () => Navigator.pop(ctx, 'reedit'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('ギャラリーから選択'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('カメラで撮影'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (_info.sealPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('削除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  setState(() => _info = _info.copyWith(sealPath: null));
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // 再編集の場合
    if (source == 'reedit') {
      if (!mounted) return;
      final saved = await showDialog<String>(
        context: context,
        builder: (ctx) => _SealContrastDialog(imagePath: _info.sealPath!),
      );
      if (saved != null && mounted) {
        setState(() => _info = _info.copyWith(sealPath: saved));
      }
      return;
    }

    // 新規取得の場合
    final imageSource = source == 'gallery' ? ImageSource.gallery : ImageSource.camera;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: imageSource);
    if (image == null || !mounted) return;
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => _SealContrastDialog(imagePath: image.path),
    );
    if (saved != null && mounted) {
      setState(() => _info = _info.copyWith(sealPath: saved));
    }
  }

  Future<void> _save() async {
    final updated = _info.copyWith(
      name: _nameController.text,
      zipCode: _zipController.text,
      address: _addressController.text,
      tel: _telController.text,
      email: _emailController.text,
      fax: _faxController.text,
      url: _urlController.text,
      defaultTaxRate: _taxRate,
      taxDisplayMode: _taxDisplayMode,
      registrationNumber: _hasRegistrationNumber ? 'T${_regNumberController.text.trim()}' : null,
    );
    await _companyRepo.saveCompanyInfo(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("自社情報を保存しました")));
    Navigator.pop(context);
  }

  Future<void> _exportToJson() async {
    try {
      final file = await CompanyInfoExportImport.exportToJson(_info);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("JSON でエクスポートしました: ${file.path}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("エクスポート失敗: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportToCsv() async {
    try {
      final file = await CompanyInfoExportImport.exportToCsv(_info);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("CSV でエクスポートしました: ${file.path}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("エクスポート失敗: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importFromFile() async {
    try {
      // ダウンロードフォルダを初期ディレクトリとして設定
      String? initialDirectory;
      if (Platform.isAndroid) {
        initialDirectory = '/storage/emulated/0/Download';
      } else if (Platform.isIOS) {
        final docDir = await getApplicationDocumentsDirectory();
        initialDirectory = docDir.path;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
        initialDirectory: initialDirectory,
      );

      if (result == null || !mounted) return;

      final file = File(result.files.single.path!);
      final ext = file.path.split('.').last.toLowerCase();

      CompanyInfo imported;
      if (ext == 'json') {
        imported = await CompanyInfoExportImport.importFromJson(file);
      } else if (ext == 'csv') {
        imported = await CompanyInfoExportImport.importFromCsv(file);
      } else {
        throw Exception('サポートされていないファイル形式です');
      }

      if (!mounted) return;

      // 確認ダイアログを表示
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('インポート確認'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('以下の情報をインポートしますか？'),
              const SizedBox(height: 16),
              Text('自社名: ${imported.name}'),
              Text('住所: ${imported.address ?? '未設定'}'),
              Text('電話: ${imported.tel ?? '未設定'}'),
              Text('メール: ${imported.email ?? '未設定'}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('インポート'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // フォームに反映
      setState(() {
        _nameController.text = imported.name;
        _zipController.text = imported.zipCode ?? '';
        _addressController.text = imported.address ?? '';
        _telController.text = imported.tel ?? '';
        _emailController.text = imported.email ?? '';
        _faxController.text = imported.fax ?? '';
        _urlController.text = imported.url ?? '';
        _taxRate = imported.defaultTaxRate;
        _taxDisplayMode = imported.taxDisplayMode;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("インポートしました。保存ボタンで確定してください。")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("インポート失敗: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("F1:自社情報"),
        backgroundColor: Colors.indigo,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export_json') {
                _exportToJson();
              } else if (value == 'export_csv') {
                _exportToCsv();
              } else if (value == 'import') {
                _importFromFile();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'export_json',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18),
                    SizedBox(width: 8),
                    Text('JSON でエクスポート'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18),
                    SizedBox(width: 8),
                    Text('CSV でエクスポート'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload, size: 18),
                    SizedBox(width: 8),
                    Text('インポート'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: KeyboardInsetWrapper(
        basePadding: const EdgeInsets.all(16),
        extraBottom: 32,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // スロット1: 基本情報
              _buildSlot(
                title: '基本情報',
                icon: Icons.business,
                children: [
                  _buildTextField("自社名", _nameController),
                  const SizedBox(height: 12),
                  _buildTextField("郵便番号", _zipController),
                  const SizedBox(height: 12),
                  _buildTextField("住所", _addressController),
                  const SizedBox(height: 12),
                  _buildTextField("電話番号", _telController),
                  const SizedBox(height: 12),
                  _buildTextField("メールアドレス", _emailController),
                  const SizedBox(height: 12),
                  _buildTextField("FAX", _faxController),
                  const SizedBox(height: 12),
                  _buildTextField("ウェブサイト URL", _urlController),
                ],
              ),
              const SizedBox(height: 20),
              
              // スロット2: 税設定
              _buildSlot(
                title: '税設定',
                icon: Icons.percent,
                children: [
                  const Text("デフォルト消費税率", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(label: const Text("10%"), selected: _taxRate == 0.10, onSelected: (_) => setState(() => _taxRate = 0.10)),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text("8%"), selected: _taxRate == 0.08, onSelected: (_) => setState(() => _taxRate = 0.08)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("消費税の表示設定", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text("通常表示"),
                        selected: _taxDisplayMode == 'normal',
                        onSelected: (_) => setState(() => _taxDisplayMode = 'normal'),
                      ),
                      ChoiceChip(
                        label: const Text("表示しない"),
                        selected: _taxDisplayMode == 'hidden',
                        onSelected: (_) => setState(() => _taxDisplayMode = 'hidden'),
                      ),
                      ChoiceChip(
                        label: const Text("「税別」と表示"),
                        selected: _taxDisplayMode == 'text_only',
                        onSelected: (_) => setState(() => _taxDisplayMode = 'text_only'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "※ T番号非取得時などの表示方法を選択",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // スロット3: インボイス登録番号
              _buildSlot(
                title: 'インボイス登録番号',
                icon: Icons.receipt_long,
                children: [
                  SwitchListTile(
                    title: const Text('適格請求書発行事業者'),
                    subtitle: const Text('T番号取得済みの場合はオン'),
                    value: _hasRegistrationNumber,
                    onChanged: (v) => setState(() => _hasRegistrationNumber = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_hasRegistrationNumber) ...
                    [
                      const SizedBox(height: 8),
                      TextField(
                        controller: _regNumberController,
                        decoration: const InputDecoration(
                          labelText: '登録番号',
                          hintText: 'T1234567890123',
                          prefixText: 'T',
                          border: OutlineInputBorder(),
                          helperText: '半角数字13桁（T番号）',
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 13,
                      ),
                    ],
                ],
              ),
              const SizedBox(height: 20),

              // スロット4: 角印
              _buildSlot(
                title: '印影（角印）',
                icon: Icons.image,
                children: [
                  GestureDetector(
                    onTap: () => _showSealPicker(isReEdit: true),
                    child: Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _info.sealPath != null ? Colors.indigo : Colors.grey,
                          width: _info.sealPath != null ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _info.sealPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(_info.sealPath!), fit: BoxFit.contain),
                            )
                          : const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('タップして取り込む', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _info.sealPath != null
                        ? "タップして再編集 | 長押しで削除・変更"
                        : "ギャラリーから読み込むか、カメラで撮影してください",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlot({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.indigo.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.indigo.shade50,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // スロットヘッダー
          Row(
            children: [
              Icon(icon, color: Colors.indigo, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // スロットコンテンツ
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}

class _SealContrastDialog extends StatefulWidget {
  final String imagePath;
  const _SealContrastDialog({required this.imagePath});

  @override
  State<_SealContrastDialog> createState() => _SealContrastDialogState();
}

class _SealContrastDialogState extends State<_SealContrastDialog> {
  double _contrast = 1.0;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  final _repaintKey = GlobalKey();
  bool _saving = false;

  List<double> _contrastMatrix(double c) {
    final t = 128 * (1 - c);
    return [
      c, 0, 0, 0, t,
      0, c, 0, 0, t,
      0, 0, c, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image img = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('変換失敗');
      final pngBytes = byteData.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/seal_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      if (mounted) Navigator.pop(context, file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // タイトル
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '角印の調整',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade300),
          
          // 拡大プレビュー
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    RepaintBoundary(
                      key: _repaintKey,
                      child: Container(
                        width: 350,
                        height: 350,
                        color: Colors.white,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _offset += details.delta;
                            });
                          },
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix(_contrastMatrix(_contrast)),
                            child: Transform.translate(
                              offset: _offset,
                              child: Transform.scale(
                                scale: _scale,
                                child: Image.file(
                                  File(widget.imagePath),
                                  width: 350,
                                  height: 350,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // コントラスト調整
                    const Text('コントラスト', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Row(
                      children: [
                        const Icon(Icons.brightness_low, size: 20, color: Colors.grey),
                        Expanded(
                          child: Slider(
                            value: _contrast,
                            min: 0.5,
                            max: 3.0,
                            divisions: 25,
                            onChanged: (v) => setState(() => _contrast = v),
                          ),
                        ),
                        const Icon(Icons.brightness_high, size: 20, color: Colors.grey),
                      ],
                    ),
                    Text(
                      _contrast.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    
                    // リサイズ調整
                    const Text('サイズ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Row(
                      children: [
                        const Icon(Icons.zoom_out, size: 20, color: Colors.grey),
                        Expanded(
                          child: Slider(
                            value: _scale,
                            min: 0.5,
                            max: 3.0,
                            divisions: 25,
                            onChanged: (v) => setState(() => _scale = v),
                          ),
                        ),
                        const Icon(Icons.zoom_in, size: 20, color: Colors.grey),
                      ],
                    ),
                    Text(
                      '${(_scale * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    
                    // リセットボタン
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _contrast = 1.0;
                              _scale = 1.0;
                              _offset = Offset.zero;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('リセット'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ドラッグで位置調整 | スライダーで数値調整',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Divider(color: Colors.grey.shade300),
          
          // アクションボタン
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
