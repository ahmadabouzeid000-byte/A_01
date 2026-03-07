import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../database/database_helper.dart';

class ExcelService {
  // ==================== تصدير المبيعات ====================
  static Future<void> exportSales({
    required List<Sale> sales,
    required String from,
    required String to,
    required String currency,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['المبيعات'];
    excel.delete('Sheet1');

    _setRow(sheet, 0, ['#', 'التاريخ', 'الوقت', 'الإجمالي', 'الخصم', 'المدفوع', 'المتبقي', 'طريقة الدفع', 'العميل', 'الكاشير']);

    for (int i = 0; i < sales.length; i++) {
      final s = sales[i];
      final dt = s.createdAt != null ? DateTime.tryParse(s.createdAt!) : null;
      _setRow(sheet, i + 1, [
        i + 1,
        dt != null ? DateFormat('dd/MM/yyyy').format(dt) : '',
        dt != null ? DateFormat('HH:mm').format(dt) : '',
        s.total, s.discount, s.paid, s.remaining,
        s.paymentMethod, s.customerName ?? '', s.userName ?? '',
      ]);
    }

    await _saveAndShare(excel, 'sales_${from}_$to.xlsx', 'تصدير المبيعات من $from إلى $to');
  }

  // ==================== تصدير المخزون ====================
  static Future<void> exportInventory({
    required List<Product> products,
    required String currency,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['المخزون'];
    excel.delete('Sheet1');

    _setRow(sheet, 0, ['#', 'اسم المنتج', 'الباركود', 'الفئة', 'سعر الشراء', 'سعر البيع', 'الكمية', 'الوحدة', 'الحد الأدنى', 'الحالة']);

    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      _setRow(sheet, i + 1, [
        i + 1, p.name, p.barcode ?? '', p.category,
        p.buyPrice, p.sellPrice, p.quantity, p.unit,
        p.minQuantity, p.isLowStock ? 'منخفض' : 'طبيعي',
      ]);
    }

    await _saveAndShare(excel, 'inventory_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx', 'تصدير المخزون');
  }

  // ==================== تصدير تقرير الموظفين ====================
  static Future<void> exportEmployeesReport({
    required List<Map<String, dynamic>> report,
    required String from,
    required String to,
    required String currency,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['تقرير الموظفين'];
    excel.delete('Sheet1');

    _setRow(sheet, 0, ['#', 'الموظف', 'عدد الفواتير', 'إجمالي المبيعات', 'إجمالي الخصومات', 'النسبة %']);

    final totalSales = report.fold(0.0, (s, r) => s + (r['sales_total'] as num));

    for (int i = 0; i < report.length; i++) {
      final r = report[i];
      final sales = (r['sales_total'] as num).toDouble();
      final pct = totalSales > 0 ? (sales / totalSales * 100) : 0.0;
      _setRow(sheet, i + 1, [
        i + 1,
        r['user_name'] ?? 'غير معروف',
        r['sales_count'],
        sales,
        (r['total_discount'] as num? ?? 0).toDouble(),
        double.parse(pct.toStringAsFixed(1)),
      ]);
    }

    await _saveAndShare(excel, 'employees_${from}_$to.xlsx', 'تقرير الموظفين من $from إلى $to');
  }

  // ==================== تصدير تقرير شهري ====================
  static Future<void> exportMonthlyReport({
    required int year,
    required int month,
    required String storeName,
    required String currency,
  }) async {
    final db = DatabaseHelper();
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final from = '$monthStr-01';
    final to = '$monthStr-31';

    // شيت المبيعات
    final sales = await db.getSalesByRange(from, to);
    final salesSheet = excel['المبيعات'];
    _setRow(salesSheet, 0, ['#', 'التاريخ', 'الوقت', 'الإجمالي', 'المدفوع', 'طريقة الدفع', 'الكاشير']);
    for (int i = 0; i < sales.length; i++) {
      final s = sales[i];
      final dt = s.createdAt != null ? DateTime.tryParse(s.createdAt!) : null;
      _setRow(salesSheet, i + 1, [
        i + 1,
        dt != null ? DateFormat('dd/MM/yyyy').format(dt) : '',
        dt != null ? DateFormat('HH:mm').format(dt) : '',
        s.total, s.paid, s.paymentMethod, s.userName ?? '',
      ]);
    }

    // شيت المصروفات
    final expenses = await db.getExpensesByRange(from, to);
    final expSheet = excel['المصروفات'];
    _setRow(expSheet, 0, ['#', 'العنوان', 'المبلغ', 'الفئة', 'التاريخ']);
    for (int i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      _setRow(expSheet, i + 1, [i + 1, e.title, e.amount, e.category, e.createdAt?.substring(0, 10) ?? '']);
    }

    // شيت المشتريات
    final purchases = await db.getAllPurchases();
    final monthPurchases = purchases.where((p) => p.createdAt?.startsWith(monthStr) == true).toList();
    final purSheet = excel['المشتريات'];
    _setRow(purSheet, 0, ['#', 'المورد', 'الإجمالي', 'المدفوع', 'المتبقي', 'التاريخ']);
    for (int i = 0; i < monthPurchases.length; i++) {
      final p = monthPurchases[i];
      _setRow(purSheet, i + 1, [i + 1, p.supplierName ?? '', p.total, p.paid, p.remaining, p.createdAt?.substring(0, 10) ?? '']);
    }

    // شيت الملخص
    final summary = await db.getMonthlyReport(year, month);
    final sumSheet = excel['ملخص الشهر'];
    _setRow(sumSheet, 0, ['البيان', 'القيمة ($currency)']);
    _setRow(sumSheet, 1, ['إجمالي المبيعات', (summary['sales_total'] as num? ?? 0).toDouble()]);
    _setRow(sumSheet, 2, ['الأرباح', (summary['profit'] as num? ?? 0).toDouble()]);
    _setRow(sumSheet, 3, ['المصروفات', (summary['expenses'] as num? ?? 0).toDouble()]);
    _setRow(sumSheet, 4, ['المشتريات', (summary['purchases'] as num? ?? 0).toDouble()]);
    final profit = (summary['profit'] as num? ?? 0).toDouble();
    final exp = (summary['expenses'] as num? ?? 0).toDouble();
    _setRow(sumSheet, 5, ['صافي الربح', profit - exp]);
    _setRow(sumSheet, 6, ['عدد الفواتير', (summary['sales_count'] as num? ?? 0).toDouble()]);

    final months = ['يناير','فبراير','مارس','إبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    await _saveAndShare(excel, 'monthly_${months[month-1]}_$year.xlsx', 'تقرير ${months[month-1]} $year');
  }

  // ==================== مساعدات ====================
  static void _setRow(Sheet sheet, int row, List<dynamic> values) {
    for (int i = 0; i < values.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
      final v = values[i];
      if (v is double) {
        cell.value = DoubleCellValue(v);
      } else if (v is int) {
        cell.value = IntCellValue(v);
      } else {
        cell.value = TextCellValue(v.toString());
      }
    }
  }

  static Future<void> _saveAndShare(Excel excel, String filename, String text) async {
    final bytes = excel.save();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: text);
  }
}
