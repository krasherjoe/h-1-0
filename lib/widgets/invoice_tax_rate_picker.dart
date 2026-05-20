import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../services/edit_log_repository.dart';

/// 消費税率選択ダイアログ（税込みモード対応）
class InvoiceTaxRatePicker extends StatelessWidget {
  final double taxRate;
  final bool includeTax;
  final bool isTaxInclusiveMode;
  final VoidCallback onTaxRateChanged;
  final String logMsg;

  const InvoiceTaxRatePicker({
    super.key,
    required this.taxRate,
    required this.includeTax,
    required this.isTaxInclusiveMode,
    required this.onTaxRateChanged,
    required this.logMsg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SimpleDialog(
      title: const Text('消費税率を選択'),
      children: [
        _buildTaxOption(context, '10', '10%', Icons.percent, null),
        _buildTaxOption(context, '8', '8%', Icons.percent, null),
        _buildTaxOption(context, '0', '非課税 (0%)', Icons.money_off, null),
        const Divider(),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'tax_inclusive_10'),
          child: ListTile(
            leading: Icon(Icons.shopping_cart, color: isDark ? theme.colorScheme.tertiary : Colors.orange),
            title: const Text('税込み (10%)'),
            subtitle: Text('単価を税込価格として扱い、消費税を逆算', style: TextStyle(fontSize: 11)),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'tax_inclusive_8'),
          child: ListTile(
            leading: Icon(Icons.shopping_cart, color: isDark ? theme.colorScheme.tertiary : Colors.orange),
            title: const Text('税込み (8%)'),
            subtitle: Text('単価を税込価格として扱い、消費税を逆算', style: TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _buildTaxOption(BuildContext context, String value, String label, IconData icon, Color? iconColor) {
    final theme = Theme.of(context);
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, value),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? theme.colorScheme.primary),
        title: Text(label),
      ),
    );
  }
}

/// 税率変更結果を処理するヘルパー
class InvoiceTaxRateResult {
  final double taxRate;
  final bool includeTax;
  final bool isTaxInclusiveMode;
  final String logMsg;

  const InvoiceTaxRateResult({
    required this.taxRate,
    required this.includeTax,
    required this.isTaxInclusiveMode,
    required this.logMsg,
  });

  static InvoiceTaxRateResult fromSelection(String selected) {
    String logMsg;
    double taxRate;
    bool includeTax;
    bool isTaxInclusiveMode;

    switch (selected) {
      case '10':
        logMsg = '消費税率を 10% に変更しました';
        taxRate = 0.10;
        includeTax = true;
        isTaxInclusiveMode = false;
        break;
      case '8':
        logMsg = '消費税率を 8% に変更しました';
        taxRate = 0.08;
        includeTax = true;
        isTaxInclusiveMode = false;
        break;
      case '0':
        logMsg = '非課税 (0%) に変更しました';
        taxRate = 0.0;
        includeTax = false;
        isTaxInclusiveMode = false;
        break;
      case 'tax_inclusive_10':
        logMsg = '税込みモード (10% 逆算) に変更しました';
        taxRate = 0.10;
        includeTax = true;
        isTaxInclusiveMode = true;
        break;
      case 'tax_inclusive_8':
        logMsg = '税込みモード (8% 逆算) に変更しました';
        taxRate = 0.08;
        includeTax = true;
        isTaxInclusiveMode = true;
        break;
      default:
        logMsg = '';
        taxRate = 0.10;
        includeTax = true;
        isTaxInclusiveMode = false;
    }

    return InvoiceTaxRateResult(
      taxRate: taxRate,
      includeTax: includeTax,
      isTaxInclusiveMode: isTaxInclusiveMode,
      logMsg: logMsg,
    );
  }
}
