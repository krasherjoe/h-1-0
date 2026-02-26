import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/company_model.dart';
import '../services/company_repository.dart';
import '../widgets/keyboard_inset_wrapper.dart';

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({Key? key}) : super(key: key);

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
    _taxRate = _info.defaultTaxRate;
    _taxDisplayMode = _info.taxDisplayMode;
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _info = _info.copyWith(sealPath: image.path);
      });
    }
  }

  Future<void> _save() async {
    final updated = _info.copyWith(
      name: _nameController.text,
      zipCode: _zipController.text,
      address: _addressController.text,
      tel: _telController.text,
      defaultTaxRate: _taxRate,
      taxDisplayMode: _taxDisplayMode,
    );
    await _companyRepo.saveCompanyInfo(updated);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("自社情報を保存しました")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text("自社設定"),
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
              const Text("印影（角印）撮影", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _info.sealPath != null
                      ? Image.file(File(_info.sealPath!), fit: BoxFit.contain)
                      : const Center(child: Icon(Icons.camera_alt, size: 50, color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 8),
              const Text("白い紙に押した判子を真上から撮影してください", style: TextStyle(fontSize: 12, color: Colors.grey)),
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
