import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/company_model.dart';
import '../models/customer_model.dart';
import '../models/invoice_models.dart';
import '../services/company_repository.dart';
import '../services/company_info_export_import.dart';
import '../services/company_profile_service.dart';
import '../services/pdf_generator.dart';
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
  final _address2Controller = TextEditingController();
  final _telController = TextEditingController();
  final _emailController = TextEditingController();
  final _faxController = TextEditingController();
  final _urlController = TextEditingController();
  double _taxRate = 0.10;
  String _taxDisplayMode = 'normal';
  bool _hasRegistrationNumber = false;
  final _regNumberController = TextEditingController();
  int _defaultBankIndex = 0;
  final List<List<TextEditingController>> _bankControllers = [
    [TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController()],
    [TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController()],
    [TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController()],
  ];
  final List<String> _bankLabels = ['銀行名', '支店名', '口座種別', '口座番号', '口座名義'];
  final List<bool> _bankActive = [false, false, false];

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
      _address2Controller.text = _info.address2 ?? "";
      _telController.text = _info.tel ?? "";
      _emailController.text = _info.email ?? "";
      _faxController.text = _info.fax ?? "";
      _urlController.text = _info.url ?? "";
      _taxRate = _info.defaultTaxRate;
      _taxDisplayMode = _info.taxDisplayMode;
      _hasRegistrationNumber = _info.registrationNumber != null && _info.registrationNumber!.isNotEmpty;
      _regNumberController.text = _info.registrationNumber?.replaceFirst('T', '') ?? '';
      _defaultBankIndex = _info.defaultBankAccountIndex;
      final accounts = _decodeBankAccounts(_info.bankAccounts);
      for (int i = 0; i < 3; i++) {
        if (i < accounts.length) {
          _bankControllers[i][0].text = accounts[i].bankName;
          _bankControllers[i][1].text = accounts[i].branchName;
          _bankControllers[i][2].text = accounts[i].accountType;
          _bankControllers[i][3].text = accounts[i].accountNumber;
          _bankControllers[i][4].text = accounts[i].holderName;
          _bankActive[i] = accounts[i].isActive;
        } else {
          _bankActive[i] = false;
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      print('F1 会社情報読み込みエラー: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e'), backgroundColor: Theme.of(context).colorScheme.error),
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
                 leading: Icon(Icons.edit, color: Theme.of(ctx).colorScheme.primary),
                 title: Text('現在の角印を再編集', style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
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
                leading: Icon(Icons.delete, color: Theme.of(ctx).colorScheme.error),
                title: Text('削除', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
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
    // copyWithはnullを正しく扱えないため、直接CompanyInfoを作成
    final updated = CompanyInfo(
      name: _nameController.text,
      zipCode: _zipController.text.isEmpty ? null : _zipController.text,
      address: _addressController.text.isEmpty ? null : _addressController.text,
      address2: _address2Controller.text.isEmpty ? null : _address2Controller.text,
      tel: _telController.text.isEmpty ? null : _telController.text,
      email: _emailController.text.isEmpty ? null : _emailController.text,
      fax: _faxController.text.isEmpty ? null : _faxController.text,
      url: _urlController.text.isEmpty ? null : _urlController.text,
      defaultTaxRate: _taxRate,
      sealPath: _info.sealPath,
      sealOffsetX: _info.sealOffsetX,
      sealOffsetY: _info.sealOffsetY,
      sealRotation: _info.sealRotation,
      taxDisplayMode: _taxDisplayMode,
      registrationNumber: _hasRegistrationNumber && _regNumberController.text.isNotEmpty
          ? 'T${_regNumberController.text.trim()}'
          : null,
      bankAccounts: _encodeBankAccounts(),
      defaultBankAccountIndex: _defaultBankIndex,
    );
    print('DEBUG: _save() - _hasRegistrationNumber: $_hasRegistrationNumber');
    print('DEBUG: _save() - registrationNumber: ${updated.registrationNumber}');
    await _companyRepo.saveCompanyInfo(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("自社情報を保存しました")));
    Navigator.pop(context);
  }

  List<CompanyBankAccount> _decodeBankAccounts(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => CompanyBankAccount.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  String _encodeBankAccounts() {
    final accounts = <CompanyBankAccount>[];
    for (int i = 0; i < 3; i++) {
      accounts.add(CompanyBankAccount(
        bankName: _bankControllers[i][0].text,
        branchName: _bankControllers[i][1].text,
        accountType: _bankControllers[i][2].text.isEmpty ? '普通' : _bankControllers[i][2].text,
        accountNumber: _bankControllers[i][3].text,
        holderName: _bankControllers[i][4].text,
        isActive: _bankActive[i],
      ));
    }
    return jsonEncode(accounts.map((e) => e.toJson()).toList());
  }

  Future<void> _showSealPdfPreview() async {
    if (_info.sealPath == null) return;

    await _companyRepo.saveCompanyInfo(_info);

    if (!mounted) return;
    await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => _SealOffsetAdjustPage(
          sealPath: _info.sealPath!,
          initialOffsetX: _info.sealOffsetX,
          initialOffsetY: _info.sealOffsetY,
          companyInfo: _info,
        ),
      ),
    );

    if (mounted) {
      _loadInfo();
    }
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
        SnackBar(content: Text("エクスポート失敗: $e"), backgroundColor: Theme.of(context).colorScheme.error),
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
        SnackBar(content: Text("エクスポート失敗: $e"), backgroundColor: Theme.of(context).colorScheme.error),
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
        _address2Controller.text = imported.address2 ?? '';
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
        SnackBar(content: Text("インポート失敗: $e"), backgroundColor: Theme.of(context).colorScheme.error),
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
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                  _buildTextField("住所1", _addressController),
                  const SizedBox(height: 12),
                  _buildTextField("住所2", _address2Controller),
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
                  Row(
                    children: [
                      const Text("デフォルト消費税率", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 12),
                      Text(
                        "${(_taxRate * 100).round()}%",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: (_taxRate * 100).round() <= 0
                            ? null
                            : () => setState(() => _taxRate = ((_taxRate * 100).round() - 1) / 100.0),
                      ),
                      Expanded(
                        child: Slider(
                          value: (_taxRate * 100).roundToDouble().clamp(0, 25),
                          min: 0,
                          max: 25,
                          divisions: 25,
                          label: "${(_taxRate * 100).round()}%",
                          onChanged: (v) => setState(() => _taxRate = v.round() / 100.0),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: (_taxRate * 100).round() >= 25
                            ? null
                            : () => setState(() => _taxRate = ((_taxRate * 100).round() + 1) / 100.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text("8%"),
                        selected: (_taxRate * 100).round() == 8,
                        onSelected: (_) => setState(() => _taxRate = 0.08),
                      ),
                      ChoiceChip(
                        label: const Text("10%"),
                        selected: (_taxRate * 100).round() == 10,
                        onSelected: (_) => setState(() => _taxRate = 0.10),
                      ),
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
         Text(
             "※ T番号非取得時などの表示方法を選択",
             style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                    onChanged: (v) {
                      setState(() {
                        _hasRegistrationNumber = v;
                        if (!v) {
                          _regNumberController.clear();
                        }
                      });
                    },
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

              // スロット4: 銀行口座
              _buildSlot(
                title: '銀行口座',
                icon: Icons.account_balance,
                children: [
                  Text('請求書で使用する銀行口座を登録してください（最大3件）', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  for (int i = 0; i < 3; i++) ...[
                    Row(
                      children: [
                        Checkbox(
                          value: _bankActive[i],
                          onChanged: (v) => setState(() => _bankActive[i] = v ?? false),
                        ),
                        Text('口座 ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (_bankActive[i])
                          Text('請求書に表示', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (int j = 0; j < 5; j++) ...[
                      TextField(
                        controller: _bankControllers[i][j],
                        decoration: InputDecoration(
                          labelText: _bankLabels[j],
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    const Divider(height: 24),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // スロット5: 角印
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
                          color: _info.sealPath != null ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                          width: _info.sealPath != null ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _info.sealPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Transform.rotate(
                                angle: -_info.sealRotation * 3.14159265359 / 180,
                                child: Image.file(File(_info.sealPath!), fit: BoxFit.contain),
                              ),
                            )
                          : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_photo_alternate, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    SizedBox(height: 8),
                                    Text('タップして取り込む', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  if (_info.sealPath != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: '左回転',
                          icon: const Icon(Icons.rotate_left),
                          onPressed: () => setState(() {
                            _info = _info.copyWith(
                              sealRotation: _info.sealRotation + 1.0,
                            );
                          }),
                        ),
                        Text(
                          '${_info.sealRotation.toStringAsFixed(0)}°',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          tooltip: '右回転',
                          icon: const Icon(Icons.rotate_right),
                          onPressed: () => setState(() {
                            _info = _info.copyWith(
                              sealRotation: _info.sealRotation - 1.0,
                            );
                          }),
                        ),
                        TextButton(
                          onPressed: _info.sealRotation == 0.0
                              ? null
                              : () => setState(() {
                                    _info = _info.copyWith(sealRotation: 0.0);
                                  }),
                          child: const Text('リセット'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push<Map<String, double>>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _SealOffsetAdjustPage(
                              sealPath: _info.sealPath!,
                              initialOffsetX: _info.sealOffsetX,
                              initialOffsetY: _info.sealOffsetY,
                              companyInfo: _info,
                            ),
                          ),
                        );

                        if (result != null && mounted) {
                          setState(() {
                            _info = _info.copyWith(
                              sealOffsetX: result['x'],
                              sealOffsetY: result['y'],
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.tune),
                      label: Text(
                        '角印位置調整  X:${_info.sealOffsetX.toStringAsFixed(1)}  Y:${_info.sealOffsetY.toStringAsFixed(1)}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showSealPdfPreview(),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDFプレビュー'),
                    ),
                  ],
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
        border: Border.all(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // スロットヘッダー
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
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
          Divider(color: Theme.of(context).colorScheme.outline),
          
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
                        color: Theme.of(context).colorScheme.surface,
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
                         const Icon(Icons.brightness_low, size: 20),
                         Expanded(
                           child: Slider(
                             value: _contrast,
                             min: 0.5,
                             max: 3.0,
                             divisions: 25,
                             onChanged: (v) => setState(() => _contrast = v),
                           ),
                         ),
                         const Icon(Icons.brightness_high, size: 20),
                       ],
                     ),
                     Text(
                       _contrast.toStringAsFixed(1),
                       style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    
                    // リサイズ調整
                    const Text('サイズ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                   Row(
                       children: [
                         const Icon(Icons.zoom_out, size: 20),
                         Expanded(
                           child: Slider(
                             value: _scale,
                             min: 0.5,
                             max: 3.0,
                             divisions: 25,
                             onChanged: (v) => setState(() => _scale = v),
                           ),
                         ),
                         const Icon(Icons.zoom_in, size: 20),
                       ],
                     ),
                     Text(
                       '${(_scale * 100).toStringAsFixed(0)}%',
                       style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                             backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 8),
                     Text(
                       'ドラッグで位置調整 | スライダーで数値調整',
                       style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Divider(color: Theme.of(context).colorScheme.outline),
          
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

// ─────────────────────────────────────────────────────────────────
// 角印オフセット調整ページ
// ─────────────────────────────────────────────────────────────────
class _SealOffsetAdjustPage extends StatefulWidget {
  final String sealPath;
  final double initialOffsetX;
  final double initialOffsetY;
  final CompanyInfo companyInfo;

  const _SealOffsetAdjustPage({
    required this.sealPath,
    required this.initialOffsetX,
    required this.initialOffsetY,
    required this.companyInfo,
  });

  @override
  State<_SealOffsetAdjustPage> createState() => _SealOffsetAdjustPageState();
}

class _SealOffsetAdjustPageState extends State<_SealOffsetAdjustPage> {
  late double _offsetX;
  late double _offsetY;
  int _rebuildKey = 0;
  final _companyRepo = CompanyRepository();

  @override
  void initState() {
    super.initState();
    _offsetX = widget.initialOffsetX;
    _offsetY = widget.initialOffsetY;
  }

  Future<Uint8List> _buildPreviewBytes(PdfPageFormat format) async {
    final doc = await buildInvoiceDocument(
      _dummyInvoiceForSealPreview(widget.companyInfo),
      pageFormat: format,
      sealOffsetXOverride: _offsetX,
      sealOffsetYOverride: _offsetY,
    );
    return Uint8List.fromList(await doc.save());
  }

  /// 方向ボタンで角印を移動。
  /// X: right座標 → 大きいほど左、小さいほど右
  /// Y: top座標   → 大きいほど下、小さいほど上
  void _moveSeal(bool isX, {required bool toIncreaseDirection, required double amount}) {
    setState(() {
      if (isX) {
        // X: 右移動 = _offsetX を減らす / 左移動 = _offsetX を増やす
        // toIncreaseDirection=true は「右へ移動」と定義
        _offsetX = (_offsetX + (toIncreaseDirection ? -amount : amount)).clamp(-200.0, 500.0);
      } else {
        // Y: 下移動 = _offsetY を増やす / 上移動 = _offsetY を減らす
        // toIncreaseDirection=true は「下へ移動」と定義
        _offsetY = (_offsetY + (toIncreaseDirection ? amount : -amount)).clamp(-200.0, 700.0);
      }
      _rebuildKey++;
    });
  }

  Widget _nudgeRow({
    required String label,
    required double value,
    required bool isX,
  }) {
    final decBig = isX ? Icons.keyboard_double_arrow_left : Icons.keyboard_double_arrow_up;
    final decOne = isX ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_up;
    final incOne = isX ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down;
    final incBig = isX ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_down;
    final decBigTip = isX ? '左 ×5' : '上 ×5';
    final decOneTip = isX ? '左 ×1' : '上 ×1';
    final incOneTip = isX ? '右 ×1' : '下 ×1';
    final incBigTip = isX ? '右 ×5' : '下 ×5';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: Icon(decBig),
            onPressed: () => _moveSeal(isX, toIncreaseDirection: false, amount: 5),
            tooltip: decBigTip,
          ),
          IconButton(
            icon: Icon(decOne),
            onPressed: () => _moveSeal(isX, toIncreaseDirection: false, amount: 1),
            tooltip: decOneTip,
          ),
          SizedBox(
            width: 56,
            child: Center(
              child: Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: Icon(incOne),
            onPressed: () => _moveSeal(isX, toIncreaseDirection: true, amount: 1),
            tooltip: incOneTip,
          ),
          IconButton(
            icon: Icon(incBig),
            onPressed: () => _moveSeal(isX, toIncreaseDirection: true, amount: 5),
            tooltip: incBigTip,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('F1:角印位置調整'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          TextButton.icon(
            onPressed: () async {
              final updated = widget.companyInfo.copyWith(
                sealOffsetX: _offsetX,
                sealOffsetY: _offsetY,
              );
              await _companyRepo.saveCompanyInfo(updated);
              if (!mounted) return;
              final nav = Navigator.of(context);
              nav.pop({'x': _offsetX, 'y': _offsetY});
            },
            icon: const Icon(Icons.check),
            label: const Text('確定'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: PdfPreview(
                    key: ValueKey(_rebuildKey),
                    initialPageFormat: kSealPreviewPageFormat,
                    build: _buildPreviewBytes,
                    allowPrinting: false,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    actions: const [],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '方向ボタンで角印を移動 | X:右端からの距離 Y:上端からの距離',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _nudgeRow(label: '横 (左右)', value: _offsetX, isX: true),
                      _nudgeRow(label: '縦 (上下)', value: _offsetY, isX: false),
                      Text(
                        '単位: PDF pt（1pt = 1/72インチ）',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final updated = widget.companyInfo.copyWith(
                        sealOffsetX: _offsetX,
                        sealOffsetY: _offsetY,
                      );
                      await _companyRepo.saveCompanyInfo(updated);
                      if (!mounted) return;
                      final nav = Navigator.of(context);
                      nav.pop({'x': _offsetX, 'y': _offsetY});
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('確定'),
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

/// 角印オフセット調整プレビュー用のダミー請求書
Invoice _dummyInvoiceForSealPreview(CompanyInfo info) {
  final customer = Customer(
    id: '__preview__',
    displayName: 'サンプル得意先',
    formalName: 'サンプル株式会社',
    title: HonorificCode.onchu,
  );
  return Invoice(
    id: '__preview__',
    customer: customer,
    date: DateTime.now(),
    items: [
      InvoiceItem(
        productId: 'p1',
        description: 'サンプル商品',
        quantity: 1,
        unitPrice: 10000,
      ),
    ],
    documentType: DocumentType.invoice,
    taxRate: info.defaultTaxRate,
    isDraft: false,
    isLocked: false,
    includeTax: true,
  );
}
