import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../database/database_helper.dart';

class BackupService {
  // ==================== تصدير ====================
  static Future<String> exportBackup() async {
    final db = await DatabaseHelper().db;

    // جلب كل البيانات
    final users = await db.query('users');
    final products = await db.query('products');
    final suppliers = await db.query('suppliers');
    final sales = await db.query('sales');
    final saleItems = await db.query('sale_items');
    final purchases = await db.query('purchases');
    final purchaseItems = await db.query('purchase_items');
    final expenses = await db.query('expenses');
    final settings = await db.query('settings');
    final productCategories = await db.query('product_categories');
    final productUnits = await db.query('product_units');
    final expenseCategories = await db.query('expense_categories');

    final backup = {
      'version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'grocery_store_manager',
      'data': {
        'users': users,
        'products': products,
        'suppliers': suppliers,
        'sales': sales,
        'sale_items': saleItems,
        'purchases': purchases,
        'purchase_items': purchaseItems,
        'expenses': expenses,
        'settings': settings,
        'product_categories': productCategories,
        'product_units': productUnits,
        'expense_categories': expenseCategories,
      }
    };

    final json = const JsonEncoder.withIndent('  ').convert(backup);
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${dir.path}/grocery_backup_$date.json');
    await file.writeAsString(json, encoding: utf8);
    return file.path;
  }

  static Future<void> shareBackup() async {
    final path = await exportBackup();
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/json')],
      text: 'نسخة احتياطية من بيانات محل البقالة',
      subject: 'Grocery Backup',
    );
  }

  // ==================== استيراد ====================
  static Future<BackupResult> importBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return BackupResult(success: false, message: 'الملف غير موجود');
      }

      final content = await file.readAsString(encoding: utf8);
      final Map<String, dynamic> backup = json.decode(content);

      // التحقق من صحة الملف
      if (backup['app'] != 'grocery_store_manager') {
        return BackupResult(success: false, message: 'ملف غير صالح — ليس ملف نسخة احتياطية للتطبيق');
      }

      final data = backup['data'] as Map<String, dynamic>;
      final db = await DatabaseHelper().db;

      await db.transaction((txn) async {
        // حذف البيانات القديمة بالترتيب الصحيح
        await txn.delete('purchase_items');
        await txn.delete('sale_items');
        await txn.delete('sales');
        await txn.delete('purchases');
        await txn.delete('expenses');
        await txn.delete('products');
        await txn.delete('suppliers');
        await txn.delete('users');
        await txn.delete('settings');
        await txn.delete('product_categories');
        await txn.delete('product_units');
        await txn.delete('expense_categories');

        // استيراد البيانات الجديدة
        await _insertAll(txn, 'users', data['users']);
        await _insertAll(txn, 'products', data['products']);
        await _insertAll(txn, 'suppliers', data['suppliers']);
        await _insertAll(txn, 'sales', data['sales']);
        await _insertAll(txn, 'sale_items', data['sale_items']);
        await _insertAll(txn, 'purchases', data['purchases']);
        await _insertAll(txn, 'purchase_items', data['purchase_items']);
        await _insertAll(txn, 'expenses', data['expenses']);
        await _insertAll(txn, 'settings', data['settings']);
        await _insertAll(txn, 'product_categories', data['product_categories']);
        await _insertAll(txn, 'product_units', data['product_units']);
        await _insertAll(txn, 'expense_categories', data['expense_categories']);
      });

      // إحصائيات
      final productCount = (data['products'] as List?)?.length ?? 0;
      final salesCount = (data['sales'] as List?)?.length ?? 0;
      final exportedAt = backup['exported_at'] ?? '';

      return BackupResult(
        success: true,
        message: 'تم الاستيراد بنجاح!\n'
            '• $productCount منتج\n'
            '• $salesCount فاتورة\n'
            '• تاريخ النسخة: ${exportedAt.substring(0, 10)}',
      );
    } catch (e) {
      return BackupResult(success: false, message: 'خطأ في الاستيراد: $e');
    }
  }

  static Future<void> _insertAll(Transaction txn, String table, dynamic rows) async {
    if (rows == null) return;
    for (final row in (rows as List)) {
      try {
        await txn.insert(table, Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    }
  }

  // ==================== حجم قاعدة البيانات ====================
  static Future<String> getDatabaseSize() async {
    try {
      final path = join(await getDatabasesPath(), 'grocery_store.db');
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        if (size < 1024) return '$size بايت';
        if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} كيلوبايت';
        return '${(size / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
      }
    } catch (_) {}
    return 'غير معروف';
  }

  // ==================== معلومات آخر نسخة ====================
  static Future<Map<String, int>> getStats() async {
    final db = await DatabaseHelper().db;
    final products = (await db.rawQuery('SELECT COUNT(*) as c FROM products')).first['c'] as int;
    final sales = (await db.rawQuery('SELECT COUNT(*) as c FROM sales')).first['c'] as int;
    final suppliers = (await db.rawQuery('SELECT COUNT(*) as c FROM suppliers')).first['c'] as int;
    final expenses = (await db.rawQuery('SELECT COUNT(*) as c FROM expenses')).first['c'] as int;
    return {'products': products, 'sales': sales, 'suppliers': suppliers, 'expenses': expenses};
  }
}

class BackupResult {
  final bool success;
  final String message;
  BackupResult({required this.success, required this.message});
}
