import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  // Singleton pattern صحيح
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'grocery_store.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ==================== إنشاء الجداول ====================
  Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
    await _insertAllDefaults(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // إضافة تدريجية لكل إصدار
    if (oldVersion < 2) {
      try {
        await db.execute('''CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, pin TEXT NOT NULL,
          role TEXT DEFAULT 'employee', can_sell INTEGER DEFAULT 1,
          can_add_products INTEGER DEFAULT 0, can_purchase INTEGER DEFAULT 0,
          can_discount INTEGER DEFAULT 0, can_view_reports INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1, created_at TEXT DEFAULT (datetime('now')))''');
        await db.execute('ALTER TABLE sales ADD COLUMN user_id INTEGER');
        await db.execute('ALTER TABLE sales ADD COLUMN user_name TEXT');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      await db.execute('''CREATE TABLE IF NOT EXISTS product_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_default INTEGER DEFAULT 0)''');
      await db.execute('''CREATE TABLE IF NOT EXISTS product_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_default INTEGER DEFAULT 0)''');
      await db.execute('''CREATE TABLE IF NOT EXISTS expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_default INTEGER DEFAULT 0)''');
      await _seedCategories(db);
      try { await db.insert('settings', {'key': 'sound_on_sale', 'value': 'true'}); } catch (_) {}
    }
    if (oldVersion < 4) {
      await db.execute('''CREATE TABLE IF NOT EXISTS payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_default INTEGER DEFAULT 0)''');
      for (final p in ['كاش', 'أجل', 'فودافون كاش', 'انستاباي']) {
        try { await db.insert('payment_methods', {'name': p, 'is_default': 1}); } catch (_) {}
      }
      try { await db.insert('settings', {'key': 'store_phone', 'value': ''}); } catch (_) {}
      try { await db.insert('settings', {'key': 'store_address', 'value': ''}); } catch (_) {}
      try { await db.insert('settings', {'key': 'invoice_thanks_msg', 'value': 'شكراً لتعاملكم معنا 🙏'}); } catch (_) {}
    }
  }

  Future<void> _createAllTables(Database db) async {
    await db.execute('''CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, pin TEXT NOT NULL,
      role TEXT DEFAULT 'employee', can_sell INTEGER DEFAULT 1,
      can_add_products INTEGER DEFAULT 0, can_purchase INTEGER DEFAULT 0,
      can_discount INTEGER DEFAULT 0, can_view_reports INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1, created_at TEXT DEFAULT (datetime('now')))''');

    await db.execute('''CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, barcode TEXT,
      category TEXT DEFAULT 'عام', buy_price REAL NOT NULL DEFAULT 0,
      sell_price REAL NOT NULL DEFAULT 0, quantity REAL NOT NULL DEFAULT 0,
      min_quantity REAL DEFAULT 5, unit TEXT DEFAULT 'قطعة', supplier_id INTEGER,
      created_at TEXT DEFAULT (datetime('now')), updated_at TEXT DEFAULT (datetime('now')))''');

    await db.execute('''CREATE TABLE suppliers (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT,
      address TEXT, balance REAL DEFAULT 0, notes TEXT,
      created_at TEXT DEFAULT (datetime('now')))''');

    await db.execute('''CREATE TABLE sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT, total REAL NOT NULL, discount REAL DEFAULT 0,
      paid REAL NOT NULL, payment_method TEXT DEFAULT 'كاش', customer_name TEXT,
      notes TEXT, user_id INTEGER, user_name TEXT,
      created_at TEXT DEFAULT (datetime('now')))''');

    await db.execute('''CREATE TABLE sale_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL, product_name TEXT NOT NULL, quantity REAL NOT NULL,
      sell_price REAL NOT NULL, buy_price REAL NOT NULL,
      FOREIGN KEY(sale_id) REFERENCES sales(id),
      FOREIGN KEY(product_id) REFERENCES products(id))''');

    await db.execute('''CREATE TABLE purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT, supplier_id INTEGER, supplier_name TEXT,
      total REAL NOT NULL, paid REAL DEFAULT 0, notes TEXT, user_id INTEGER, user_name TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY(supplier_id) REFERENCES suppliers(id))''');

    await db.execute('''CREATE TABLE purchase_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL, product_name TEXT NOT NULL,
      quantity REAL NOT NULL, buy_price REAL NOT NULL,
      FOREIGN KEY(purchase_id) REFERENCES purchases(id))''');

    await db.execute('''CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, amount REAL NOT NULL,
      category TEXT DEFAULT 'عام', notes TEXT, user_id INTEGER,
      created_at TEXT DEFAULT (datetime('now')))''');

    await db.execute('''CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)''');

    await db.execute('''CREATE TABLE product_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_default INTEGER DEFAULT 0)''');

    await db.execute('''CREATE TABLE product_units (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_default INTEGER DEFAULT 0)''');

    await db.execute('''CREATE TABLE expense_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_default INTEGER DEFAULT 0)''');

    await db.execute('''CREATE TABLE payment_methods (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_default INTEGER DEFAULT 0)''');
  }

  Future<void> _insertAllDefaults(Database db) async {
    // إعدادات افتراضية
    final settingsList = [
      {'key': 'store_name', 'value': 'محل البقالة'},
      {'key': 'currency', 'value': 'جنيه'},
      {'key': 'low_stock_alert', 'value': 'true'},
      {'key': 'sound_on_sale', 'value': 'true'},
      {'key': 'store_phone', 'value': ''},
      {'key': 'store_address', 'value': ''},
      {'key': 'invoice_thanks_msg', 'value': 'شكراً لتعاملكم معنا 🙏'},
    ];
    for (final s in settingsList) {
      try { await db.insert('settings', s); } catch (_) {}
    }

    // مدير افتراضي
    await db.insert('users', {
      'name': 'المدير', 'pin': '1234', 'role': 'admin',
      'can_sell': 1, 'can_add_products': 1, 'can_purchase': 1,
      'can_discount': 1, 'can_view_reports': 1, 'is_active': 1,
    });

    await _seedCategories(db);
  }

  Future<void> _seedCategories(Database db) async {
    final cats = ['عام', 'مشروبات', 'أغذية', 'منظفات', 'ألبان ومنتجاتها',
      'خضار وفاكهة', 'حلويات وشيبسي', 'مجمدات', 'مخبوزات',
      'عصائر وعلب', 'بقوليات', 'توابل وبهارات'];
    for (final c in cats) {
      try { await db.insert('product_categories', {'name': c, 'is_default': 1}); } catch (_) {}
    }

    final units = ['قطعة', 'كيلو', 'جرام', 'لتر', 'مل',
      'علبة', 'كرتون', 'دستة', 'باكت', 'رول', 'زجاجة', 'صينية', 'شوال'];
    for (final u in units) {
      try { await db.insert('product_units', {'name': u, 'is_default': 1}); } catch (_) {}
    }

    final expCats = ['عام', 'إيجار', 'فواتير كهرباء/مياه', 'مرتبات',
      'صيانة', 'نقل وتوصيل', 'تسويق وإعلان', 'أخرى'];
    for (final e in expCats) {
      try { await db.insert('expense_categories', {'name': e, 'is_default': 1}); } catch (_) {}
    }

    final payments = ['كاش', 'أجل', 'فودافون كاش', 'انستاباي'];
    for (final p in payments) {
      try { await db.insert('payment_methods', {'name': p, 'is_default': 1}); } catch (_) {}
    }
  }

  // ==================== المستخدمين ====================
  Future<Map<String, dynamic>?> loginWithPin(String pin) async {
    final d = await db;
    final r = await d.query('users', where: 'pin = ? AND is_active = 1', whereArgs: [pin]);
    return r.isEmpty ? null : Map<String, dynamic>.from(r.first);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async =>
      (await db).query('users', where: 'is_active = 1', orderBy: 'role DESC, name ASC');

  Future<int> insertUser(Map<String, dynamic> user) async =>
      (await db).insert('users', user);

  Future<void> updateUser(int id, Map<String, dynamic> data) async =>
      (await db).update('users', data, where: 'id = ?', whereArgs: [id]);

  Future<void> deactivateUser(int id) async =>
      (await db).update('users', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);

  Future<bool> isPinTaken(String pin, {int? excludeId}) async {
    final d = await db;
    final where = excludeId != null ? 'pin = ? AND id != ? AND is_active = 1' : 'pin = ? AND is_active = 1';
    final args = excludeId != null ? [pin, excludeId] : [pin];
    return (await d.query('users', where: where, whereArgs: args)).isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getAllEmployeesSalesReport(String from, String to) async =>
      (await db).rawQuery(
        '''SELECT user_id, user_name, COUNT(*) as sales_count,
           COALESCE(SUM(total),0) as sales_total, COALESCE(SUM(discount),0) as total_discount
           FROM sales WHERE date(created_at) BETWEEN ? AND ? AND user_id IS NOT NULL
           GROUP BY user_id ORDER BY sales_total DESC''', [from, to]);

  Future<Map<String, dynamic>> getEmployeeSalesReport(int userId, String from, String to) async {
    final d = await db;
    final s = await d.rawQuery(
      'SELECT COALESCE(SUM(total),0) as total, COUNT(*) as count FROM sales WHERE user_id=? AND date(created_at) BETWEEN ? AND ?',
      [userId, from, to]);
    final p = await d.rawQuery(
      '''SELECT COALESCE(SUM((si.sell_price-si.buy_price)*si.quantity),0) as profit
         FROM sale_items si JOIN sales s ON si.sale_id=s.id WHERE s.user_id=? AND date(s.created_at) BETWEEN ? AND ?''',
      [userId, from, to]);
    return {'total': s.first['total'], 'count': s.first['count'], 'profit': p.first['profit']};
  }

  // ==================== الفئات والوحدات ====================
  Future<List<String>> getProductCategories() async {
    final maps = await (await db).query('product_categories', orderBy: 'is_default DESC, name ASC');
    return maps.map((m) => m['name'] as String).toList();
  }

  Future<List<String>> getProductUnits() async {
    final maps = await (await db).query('product_units', orderBy: 'is_default DESC, name ASC');
    return maps.map((m) => m['name'] as String).toList();
  }

  Future<List<String>> getExpenseCategories() async {
    final maps = await (await db).query('expense_categories', orderBy: 'is_default DESC, name ASC');
    return maps.map((m) => m['name'] as String).toList();
  }

  Future<List<String>> getPaymentMethods() async {
    try {
      final maps = await (await db).query('payment_methods', orderBy: 'is_default DESC, name ASC');
      if (maps.isEmpty) return ['كاش', 'أجل', 'فودافون كاش', 'انستاباي'];
      return maps.map((m) => m['name'] as String).toList();
    } catch (_) {
      return ['كاش', 'أجل', 'فودافون كاش', 'انستاباي'];
    }
  }

  Future<bool> addProductCategory(String name) async {
    try {
      await (await db).insert('product_categories', {'name': name.trim(), 'is_default': 0});
      return true;
    } catch (_) { return false; }
  }

  Future<bool> addProductUnit(String name) async {
    try {
      await (await db).insert('product_units', {'name': name.trim(), 'is_default': 0});
      return true;
    } catch (_) { return false; }
  }

  Future<bool> addExpenseCategory(String name) async {
    try {
      await (await db).insert('expense_categories', {'name': name.trim(), 'is_default': 0});
      return true;
    } catch (_) { return false; }
  }

  Future<bool> addPaymentMethod(String name) async {
    try {
      await (await db).insert('payment_methods', {'name': name.trim(), 'is_default': 0});
      return true;
    } catch (_) { return false; }
  }

  Future<void> deleteCustomCategory(String table, String name) async =>
      (await db).delete(table, where: 'name = ? AND is_default = 0', whereArgs: [name]);

  // ==================== المنتجات ====================
  Future<int> insertProduct(Product p) async =>
      (await db).insert('products', p.toMap());

  Future<List<Product>> getAllProducts() async {
    final maps = await (await db).query('products', orderBy: 'name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final maps = await (await db).query('products', where: 'barcode = ?', whereArgs: [barcode]);
    return maps.isEmpty ? null : Product.fromMap(maps.first);
  }

  Future<List<Product>> searchProducts(String query) async {
    final maps = await (await db).query('products',
        where: 'name LIKE ? OR barcode LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<List<Product>> getLowStockProducts() async {
    final maps = await (await db).rawQuery(
        'SELECT * FROM products WHERE quantity <= min_quantity ORDER BY quantity ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<int> updateProduct(Product p) async =>
      (await db).update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<int> deleteProduct(int id) async =>
      (await db).delete('products', where: 'id = ?', whereArgs: [id]);

  // ==================== المبيعات ====================
  Future<int> insertSale(Sale sale, List<SaleItem> items) async {
    final d = await db;
    return d.transaction((txn) async {
      final saleId = await txn.insert('sales', sale.toMap());
      for (final item in items) {
        await txn.insert('sale_items', {...item.toMap(), 'sale_id': saleId});
        await txn.rawUpdate(
            'UPDATE products SET quantity = quantity - ? WHERE id = ?',
            [item.quantity, item.productId]);
      }
      return saleId;
    });
  }

  Future<List<Sale>> getSalesByDate(String date) async {
    final maps = await (await db).query('sales',
        where: 'date(created_at) = ?', whereArgs: [date], orderBy: 'created_at DESC');
    return maps.map(Sale.fromMap).toList();
  }

  Future<List<Sale>> getSalesByRange(String from, String to) async {
    final maps = await (await db).query('sales',
        where: 'date(created_at) BETWEEN ? AND ?', whereArgs: [from, to],
        orderBy: 'created_at DESC');
    return maps.map(Sale.fromMap).toList();
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final maps = await (await db).query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    return maps.map(SaleItem.fromMap).toList();
  }

  // ==================== المشتريات ====================
  Future<int> insertPurchase(Purchase purchase, List<PurchaseItem> items) async {
    final d = await db;
    return d.transaction((txn) async {
      final purchaseId = await txn.insert('purchases', purchase.toMap());
      for (final item in items) {
        await txn.insert('purchase_items', {...item.toMap(), 'purchase_id': purchaseId});
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ?, buy_price = ?, updated_at = datetime("now") WHERE id = ?',
          [item.quantity, item.buyPrice, item.productId]);
      }
      if (purchase.supplierId != null) {
        final debt = purchase.total - purchase.paid;
        if (debt > 0) {
          await txn.rawUpdate(
              'UPDATE suppliers SET balance = balance + ? WHERE id = ?',
              [debt, purchase.supplierId]);
        }
      }
      return purchaseId;
    });
  }

  Future<List<Purchase>> getAllPurchases() async {
    final maps = await (await db).query('purchases', orderBy: 'created_at DESC');
    return maps.map(Purchase.fromMap).toList();
  }

  // ==================== الموردين ====================
  Future<int> insertSupplier(Supplier s) async =>
      (await db).insert('suppliers', s.toMap());

  Future<List<Supplier>> getAllSuppliers() async {
    final maps = await (await db).query('suppliers', orderBy: 'name ASC');
    return maps.map(Supplier.fromMap).toList();
  }

  Future<int> updateSupplier(Supplier s) async =>
      (await db).update('suppliers', s.toMap(), where: 'id = ?', whereArgs: [s.id]);

  Future<void> paySupplier(int supplierId, double amount) async =>
      (await db).rawUpdate(
          'UPDATE suppliers SET balance = balance - ? WHERE id = ?', [amount, supplierId]);

  // ==================== المصروفات ====================
  Future<int> insertExpense(Expense e) async =>
      (await db).insert('expenses', e.toMap());

  Future<List<Expense>> getExpensesByRange(String from, String to) async {
    final maps = await (await db).query('expenses',
        where: 'date(created_at) BETWEEN ? AND ?', whereArgs: [from, to],
        orderBy: 'created_at DESC');
    return maps.map(Expense.fromMap).toList();
  }

  // ==================== التقارير ====================
  Future<Map<String, dynamic>> getDailyReport(String date) async {
    final d = await db;
    final s = await d.rawQuery(
        'SELECT COALESCE(SUM(total),0) as total, COALESCE(SUM(paid),0) as paid, COUNT(*) as count FROM sales WHERE date(created_at)=?',
        [date]);
    final p = await d.rawQuery(
        '''SELECT COALESCE(SUM((si.sell_price-si.buy_price)*si.quantity),0) as profit
           FROM sale_items si JOIN sales s ON si.sale_id=s.id WHERE date(s.created_at)=?''', [date]);
    final e = await d.rawQuery(
        'SELECT COALESCE(SUM(amount),0) as total FROM expenses WHERE date(created_at)=?', [date]);
    return {
      'sales_total': s.first['total'], 'sales_paid': s.first['paid'],
      'sales_count': s.first['count'], 'profit': p.first['profit'],
      'expenses': e.first['total'],
    };
  }

  Future<Map<String, dynamic>> getMonthlyReport(int year, int month) async {
    final d = await db;
    final m = '$year-${month.toString().padLeft(2, '0')}';
    final s = await d.rawQuery(
        "SELECT COALESCE(SUM(total),0) as total, COUNT(*) as count FROM sales WHERE strftime('%Y-%m',created_at)=?", [m]);
    final p = await d.rawQuery(
        """SELECT COALESCE(SUM((si.sell_price-si.buy_price)*si.quantity),0) as profit
           FROM sale_items si JOIN sales s ON si.sale_id=s.id WHERE strftime('%Y-%m',s.created_at)=?""", [m]);
    final e = await d.rawQuery(
        "SELECT COALESCE(SUM(amount),0) as total FROM expenses WHERE strftime('%Y-%m',created_at)=?", [m]);
    final pu = await d.rawQuery(
        "SELECT COALESCE(SUM(total),0) as total FROM purchases WHERE strftime('%Y-%m',created_at)=?", [m]);
    return {
      'sales_total': s.first['total'], 'sales_count': s.first['count'],
      'profit': p.first['profit'], 'expenses': e.first['total'],
      'purchases': pu.first['total'],
    };
  }

  Future<List<Map<String, dynamic>>> getTopProducts(String from, String to) async =>
      (await db).rawQuery(
        '''SELECT si.product_name, SUM(si.quantity) as qty, SUM(si.quantity*si.sell_price) as revenue
           FROM sale_items si JOIN sales s ON si.sale_id=s.id WHERE date(s.created_at) BETWEEN ? AND ?
           GROUP BY si.product_id ORDER BY qty DESC LIMIT 10''', [from, to]);

  // ==================== الإعدادات ====================
  Future<String> getSetting(String key) async {
    final result = await (await db).query('settings', where: 'key = ?', whereArgs: [key]);
    return result.isEmpty ? '' : (result.first['value'] as String? ?? '');
  }

  Future<void> setSetting(String key, String value) async =>
      (await db).insert('settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
}
