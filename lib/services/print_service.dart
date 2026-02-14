import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/invoice_models.dart';
import 'package:intl/intl.dart';
import 'company_repository.dart';

class PrintService {
  /// ペアリング済みのBluetoothデバイス一覧を取得
  Future<List<BluetoothInfo>> getPairedDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  /// 指定したデバイスに接続
  Future<bool> connect(String macAddress) async {
    return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  /// 接続状態の確認
  Future<bool> get isConnected async => await PrintBluetoothThermal.connectionStatus;

  /// レシートを生成して印刷
  Future<bool> printReceipt(Invoice invoice) async {
    if (!await isConnected) return false;

    // 日本語フォントサポート等のために、本来は画像生成が必要な場合が多いが
    // ここでは標準的なESC/POSテキスト出力を実装
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // 自社情報の取得（税表示設定のため）
    final companyRepo = CompanyRepository();
    final companyInfo = await companyRepo.getCompanyInfo();

    // ヘッダー
    bytes += generator.text(
      invoice.documentTypeName,
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2, bold: true),
    );
    bytes += generator.text("--------------------------------", styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text("No: ${invoice.invoiceNumber}", styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text("Date: ${DateFormat('yyyy/MM/dd HH:mm').format(invoice.date)}", styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text("--------------------------------", styles: const PosStyles(align: PosAlign.center));

    bytes += generator.text("Customer:", styles: const PosStyles(bold: true));
    bytes += generator.text(invoice.customerNameForDisplay);
    bytes += generator.feed(1);

    bytes += generator.text("Items:", styles: const PosStyles(bold: true));
    for (var item in invoice.items) {
      bytes += generator.text(item.description);
      bytes += generator.row([
        PosColumn(text: "  ${item.quantity} x ${item.unitPrice}", width: 8),
        PosColumn(text: "￥${item.subtotal}", width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.text("--------------------------------");
    bytes += generator.row([
      PosColumn(text: "Subtotal", width: 8),
      PosColumn(text: "￥${invoice.subtotal}", width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    
    if (companyInfo.taxDisplayMode == 'normal') {
      bytes += generator.row([
        PosColumn(text: "Tax", width: 8),
        PosColumn(text: "￥${invoice.tax}", width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    } else if (companyInfo.taxDisplayMode == 'text_only') {
      bytes += generator.row([
        PosColumn(text: "Tax", width: 8),
        PosColumn(text: "(Tax Excl.)", width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.row([
       PosColumn(text: companyInfo.taxDisplayMode == 'hidden' ? "TOTAL" : "TOTAL(Incl)", width: 7, styles: const PosStyles(bold: true, height: PosTextSize.size1)),
      PosColumn(text: "￥${invoice.totalAmount}", width: 5, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size1)),
    ]);
    
    bytes += generator.feed(3);
    bytes += generator.cut();

    return await PrintBluetoothThermal.writeBytes(bytes);
  }
}
