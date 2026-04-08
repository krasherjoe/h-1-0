import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/company_model.dart';
import '../services/company_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    _info = await _companyRepo.getCompanyInfo();
    _nameController.text = _info.name;
    _zipController.text = _info.zipCode ?? "";
    _addressController.text = _info.address ?? "";
    _telController.text = _info.tel ?? "";
    _emailController.text = _info.email ?? "";
    _faxController.text = _info.fax ?? "";
    _urlController.text = _info.url ?? "";
    _taxRate = _info.defaultTaxRate;
    _taxDisplayMode = _info.taxDisplayMode;
    setState(() => _isLoading = false);
  }

  Future<void> _showSealPicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('ギャラリーから選択'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('カメラで撮影'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
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
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
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
    );
    await _companyRepo.saveCompanyInfo(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("自社情報を保存しました")));
    Navigator.pop(context);
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
              const SizedBox(height: 20),
              const Text("デフォルト消費税率", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  ChoiceChip(label: const Text("10%"), selected: _taxRate == 0.10, onSelected: (_) => setState(() => _taxRate = 0.10)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text("8%"), selected: _taxRate == 0.08, onSelected: (_) => setState(() => _taxRate = 0.08)),
                ],
              ),
              const SizedBox(height: 20),
              const Text("消費税の表示設定（T番号非取得時など）", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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
              const SizedBox(height: 24),
              const Text("印影（角印）", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showSealPicker,
                child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
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
              const SizedBox(height: 8),
              const Text("ギャラリーから読み込むか、カメラで撮影してください", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
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
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
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
