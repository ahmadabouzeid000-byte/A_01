import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../database/database_helper.dart';

class PdfService {
  // ==================== تحميل الخط العربي ====================
  static Future<pw.Font> _getArabicFont() async {
    return await PdfGoogleFonts.notoNaskhArabicRegular();
  }

  static Future<pw.Font> _getArabicBoldFont() async {
    return await PdfGoogleFonts.notoNaskhArabicBold();
  }

  // ==================== فاتورة البيع - طباعة ====================
  static Future<void> printSaleInvoice({
    required Sale sale,
    required List<SaleItem> items,
    required String storeName,
    required String currency,
  }) async {
    final db = DatabaseHelper();
    final phone = await db.getSetting('store_phone');
    final address = await db.getSetting('store_address');
    final thanks = await db.getSetting('invoice_thanks_msg');
    final font = await _getArabicFont();
    final boldFont = await _getArabicBoldFont();
    final pdf = _buildInvoicePdf(sale, items, storeName, currency, font, boldFont,
        storePhone: phone, storeAddress: address, thanksMsg: thanks);
    await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
  }

  // ==================== فاتورة البيع - مشاركة ====================
  static Future<void> shareSaleInvoice({
    required Sale sale,
    required List<SaleItem> items,
    required String storeName,
    required String currency,
  }) async {
    final db = DatabaseHelper();
    final phone = await db.getSetting('store_phone');
    final address = await db.getSetting('store_address');
    final thanks = await db.getSetting('invoice_thanks_msg');
    final font = await _getArabicFont();
    final boldFont = await _getArabicBoldFont();
    final pdf = _buildInvoicePdf(sale, items, storeName, currency, font, boldFont,
        storePhone: phone, storeAddress: address, thanksMsg: thanks);
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('\${dir.path}/invoice_\${sale.id ?? DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'فاتورة من $storeName');
  }

  // ==================== بناء فاتورة البيع ====================
  static pw.Document _buildInvoicePdf(
    Sale sale, List<SaleItem> items, String storeName, String currency,
    pw.Font font, pw.Font boldFont, {
    String storePhone = '', String storeAddress = '', String thanksMsg = '',
  }) {
    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(base: font, bold: boldFont);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      textDirection: pw.TextDirection.rtl,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // هيدر
          pw.Center(child: pw.Column(children: [
            pw.Text(storeName, style: pw.TextStyle(font: boldFont, fontSize: 20)),
            if (storePhone.isNotEmpty)
              pw.Text('📞 $storePhone', style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
            if (storeAddress.isNotEmpty)
              pw.Text(storeAddress, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text('فاتورة مبيعات', style: pw.TextStyle(font: font, fontSize: 13, color: PdfColors.grey700)),
            pw.Divider(thickness: 1.5, color: PdfColors.green800),
          ])),
          pw.SizedBox(height: 8),

          // بيانات الفاتورة
          _infoRow('رقم الفاتورة', '#${sale.id ?? '---'}', font, boldFont),
          _infoRow('التاريخ', _formatDate(sale.createdAt), font, boldFont),
          _infoRow('طريقة الدفع', sale.paymentMethod, font, boldFont),
          if (sale.userName != null) _infoRow('الكاشير', sale.userName!, font, boldFont),
          if (sale.customerName != null && sale.customerName!.isNotEmpty)
            _infoRow('العميل', sale.customerName!, font, boldFont),

          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey400),

          // جدول المنتجات
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green50),
                children: [
                  _tableCell('المنتج', font, boldFont, bold: true),
                  _tableCell('الكمية', font, boldFont, bold: true),
                  _tableCell('السعر', font, boldFont, bold: true),
                  _tableCell('الإجمالي', font, boldFont, bold: true),
                ],
              ),
              ...items.map((item) => pw.TableRow(children: [
                _tableCell(item.productName, font, boldFont),
                _tableCell('${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}', font, boldFont),
                _tableCell('${item.sellPrice.toStringAsFixed(2)}', font, boldFont),
                _tableCell('${item.total.toStringAsFixed(2)}', font, boldFont),
              ])),
            ],
          ),

          pw.SizedBox(height: 8),

          // الإجماليات
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(children: [
              _totalRow('المجموع', '${sale.total.toStringAsFixed(2)} $currency', font, boldFont),
              if (sale.discount > 0)
                _totalRow('خصم', '-${sale.discount.toStringAsFixed(2)} $currency', font, boldFont, color: PdfColors.red),
              if (sale.discount > 0)
                _totalRow('الإجمالي بعد الخصم', '${(sale.total - sale.discount).toStringAsFixed(2)} $currency', font, boldFont, bold: true),
              _totalRow('المدفوع', '${sale.paid.toStringAsFixed(2)} $currency', font, boldFont, bold: true),
              if (sale.remaining > 0)
                _totalRow('المتبقي', '${sale.remaining.toStringAsFixed(2)} $currency', font, boldFont, color: PdfColors.red, bold: true),
            ]),
          ),

          pw.Spacer(),
          pw.Center(child: pw.Text(
            thanksMsg.isNotEmpty ? thanksMsg : 'شكراً لتعاملكم معنا 🙏',
            style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600))),
        ],
      ),
    ));

    return pdf;
  }

  // ==================== تقرير يومي ====================
  static Future<void> shareDailyReport({
    required Map<String, dynamic> report,
    required String date,
    required String storeName,
    required String currency,
    required List<Sale> sales,
  }) async {
    final font = await _getArabicFont();
    final boldFont = await _getArabicBoldFont();
    final theme = pw.ThemeData.withFont(base: font, bold: boldFont);
    final pdf = pw.Document();

    final salesTotal = (report['sales_total'] as num? ?? 0).toDouble();
    final profit = (report['profit'] as num? ?? 0).toDouble();
    final expenses = (report['expenses'] as num? ?? 0).toDouble();
    final count = report['sales_count'] ?? 0;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: theme,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(child: pw.Column(children: [
            pw.Text(storeName, style: pw.TextStyle(font: boldFont, fontSize: 22)),
            pw.Text('التقرير اليومي - $date', style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey700)),
            pw.Divider(thickness: 2, color: PdfColors.green800),
          ])),
          pw.SizedBox(height: 12),

          // صناديق الملخص
          pw.Row(children: [
            _summaryBox('إجمالي المبيعات', '${salesTotal.toStringAsFixed(2)} $currency', PdfColors.blue100, font, boldFont),
            pw.SizedBox(width: 8),
            _summaryBox('الأرباح', '${profit.toStringAsFixed(2)} $currency', PdfColors.green100, font, boldFont),
            pw.SizedBox(width: 8),
            _summaryBox('المصروفات', '${expenses.toStringAsFixed(2)} $currency', PdfColors.orange100, font, boldFont),
            pw.SizedBox(width: 8),
            _summaryBox('صافي الربح', '${(profit - expenses).toStringAsFixed(2)} $currency',
              profit - expenses >= 0 ? PdfColors.lightGreen100 : PdfColors.red100, font, boldFont),
          ]),

          pw.SizedBox(height: 16),
          pw.Text('تفاصيل الفواتير ($count فاتورة)',
            style: pw.TextStyle(font: boldFont, fontSize: 14)),
          pw.SizedBox(height: 8),

          if (sales.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell('#', font, boldFont, bold: true),
                    _tableCell('الوقت', font, boldFont, bold: true),
                    _tableCell('الإجمالي', font, boldFont, bold: true),
                    _tableCell('المدفوع', font, boldFont, bold: true),
                    _tableCell('طريقة الدفع', font, boldFont, bold: true),
                  ],
                ),
                ...sales.asMap().entries.map((e) => pw.TableRow(children: [
                  _tableCell('${e.key + 1}', font, boldFont),
                  _tableCell(e.value.createdAt?.substring(11, 16) ?? '', font, boldFont),
                  _tableCell('${e.value.total.toStringAsFixed(2)}', font, boldFont),
                  _tableCell('${e.value.paid.toStringAsFixed(2)}', font, boldFont),
                  _tableCell(e.value.paymentMethod, font, boldFont),
                ])),
              ],
            )
          else
            pw.Center(child: pw.Text('لا توجد مبيعات',
              style: pw.TextStyle(font: font, color: PdfColors.grey))),
        ],
      ),
    ));

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/daily_report_$date.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'تقرير يومي - $date');
  }

  // ==================== مساعدات ====================
  static pw.Widget _infoRow(String label, String value, pw.Font font, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, color: PdfColors.grey700, fontSize: 11)),
          pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 11)),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(String text, pw.Font font, pw.Font boldFont, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: bold ? boldFont : font, fontSize: 10),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, pw.Font font, pw.Font boldFont,
      {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: bold ? boldFont : font, fontSize: 11, color: color)),
          pw.Text(value, style: pw.TextStyle(font: bold ? boldFont : font, fontSize: 11, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _summaryBox(String label, String value, PdfColor color,
      pw.Font font, pw.Font boldFont) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 10)),
        ]),
      ),
    );
  }

  static String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}
