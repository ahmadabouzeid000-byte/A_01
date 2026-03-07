import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/user_session.dart';
import '../utils/sound_service.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'suppliers_screen.dart';
import 'purchases_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';
import 'employees_screen.dart';
import 'settings_screen.dart';
import 'backup_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _storeName = 'محل البقالة';
  Map<String, dynamic> _todayStats = {};
  List<Map<String, dynamic>> _lowStock = [];
  bool _loading = true;
  String _currency = 'جنيه';

  @override
  void initState() {
    super.initState();
    _loadData();
    SoundService.init();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper();
    final name = await db.getSetting('store_name');
    final cur = await db.getSetting('currency');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final stats = await db.getDailyReport(today);
    final low = await db.getLowStockProducts();
    setState(() {
      _storeName = name.isNotEmpty ? name : 'محل البقالة';
      _currency = cur.isNotEmpty ? cur : 'جنيه';
      _todayStats = stats;
      _lowStock = low.take(5).map((p) => {'name': p.name, 'qty': p.quantity, 'unit': p.unit}).toList();
      _loading = false;
    });
  }

  void _goTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadData());
  }

  void _logout() {
    UserSession.clear();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession.current;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      // ===== Drawer جانبي =====
      drawer: _buildDrawer(context, user, isAdmin),
      appBar: AppBar(
        title: Text(_storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      // ===== زر البيع الرئيسي =====
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => _goTo(const PosScreen()),
        backgroundColor: const Color(0xFF1B5E20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.point_of_sale, size: 28, color: Colors.white),
            Text('بيع', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    final salesTotal = (_todayStats['sales_total'] as num? ?? 0).toDouble();
    final profit = (_todayStats['profit'] as num? ?? 0).toDouble();
    final salesCount = _todayStats['sales_count'] ?? 0;
    final expenses = (_todayStats['expenses'] as num? ?? 0).toDouble();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== ترحيب =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const CircleAvatar(
                  backgroundColor: Colors.white24,
                  radius: 24,
                  child: Icon(Icons.person, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مرحباً، ${UserSession.current?.name ?? ""}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(DateTime.now().toString().substring(0, 10),
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                  child: Text(UserSession.current?.isAdmin == true ? 'مدير' : 'موظف',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ]),
            ),

            const SizedBox(height: 20),
            const Text('إحصائيات اليوم',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),

            // ===== إحصائيات اليوم =====
            Row(children: [
              Expanded(child: _statCard('المبيعات', '${salesTotal.toStringAsFixed(0)} $_currency',
                  Icons.attach_money, Colors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('الأرباح', '${profit.toStringAsFixed(0)} $_currency',
                  Icons.trending_up, Colors.green)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _statCard('الفواتير', '$salesCount فاتورة',
                  Icons.receipt_long, Colors.purple)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('المصروفات', '${expenses.toStringAsFixed(0)} $_currency',
                  Icons.money_off, Colors.red)),
            ]),

            // ===== تنبيه المخزون المنخفض =====
            if (_lowStock.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                const SizedBox(width: 6),
                const Text('منتجات تحتاج تجديد',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange)),
                const Spacer(),
                TextButton(
                  onPressed: () => _goTo(const ProductsScreen()),
                  child: const Text('عرض الكل'),
                ),
              ]),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: _lowStock.asMap().entries.map((e) {
                    final item = e.value;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.inventory_2, color: Colors.orange, size: 18),
                      title: Text(item['name'], style: const TextStyle(fontSize: 13)),
                      trailing: Text(
                        '${item['qty']} ${item['unit']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // ===== أزرار سريعة =====
            const SizedBox(height: 20),
            const Text('وصول سريع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: [
                _quickBtn(Icons.inventory_2, 'المنتجات', Colors.blue,
                    () => _goTo(const ProductsScreen())),
                if (UserSession.current?.canViewReports == true || UserSession.current?.isAdmin == true)
                  _quickBtn(Icons.bar_chart, 'التقارير', Colors.purple,
                      () => _goTo(const ReportsScreen())),
                if (UserSession.current?.canPurchase == true || UserSession.current?.isAdmin == true)
                  _quickBtn(Icons.shopping_cart, 'المشتريات', Colors.teal,
                      () => _goTo(const PurchasesScreen())),
                _quickBtn(Icons.receipt_long, 'المصروفات', Colors.red,
                    () => _goTo(const ExpensesScreen())),
                if (UserSession.current?.isAdmin == true) ...[
                  _quickBtn(Icons.people, 'الموردين', Colors.brown,
                      () => _goTo(const SuppliersScreen())),
                  _quickBtn(Icons.badge, 'الموظفين', Colors.indigo,
                      () => _goTo(const EmployeesScreen())),
                ],
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ])),
      ]),
    );
  }

  Widget _quickBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ===== Drawer الجانبي =====
  Widget _buildDrawer(BuildContext context, dynamic user, bool isAdmin) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CircleAvatar(
                radius: 28, backgroundColor: Colors.white24,
                child: Icon(Icons.store, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 8),
              Text(_storeName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(user?.name ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),

          // ===== نقطة البيع =====
          _drawerItem(Icons.point_of_sale, 'نقطة البيع', Colors.green,
              () { Navigator.pop(context); _goTo(const PosScreen()); }),

          const Divider(),
          const Padding(
            padding: EdgeInsets.only(right: 16, top: 4, bottom: 4),
            child: Text('الإدارة', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),

          _drawerItem(Icons.inventory_2, 'المنتجات', Colors.blue,
              () { Navigator.pop(context); _goTo(const ProductsScreen()); }),
          _drawerItem(Icons.receipt_long, 'المصروفات', Colors.red,
              () { Navigator.pop(context); _goTo(const ExpensesScreen()); }),

          if (user?.canPurchase == true || isAdmin)
            _drawerItem(Icons.shopping_cart, 'المشتريات', Colors.teal,
                () { Navigator.pop(context); _goTo(const PurchasesScreen()); }),

          if (isAdmin) ...[
            _drawerItem(Icons.people, 'الموردين', Colors.brown,
                () { Navigator.pop(context); _goTo(const SuppliersScreen()); }),
            _drawerItem(Icons.badge, 'الموظفين', Colors.indigo,
                () { Navigator.pop(context); _goTo(const EmployeesScreen()); }),
          ],

          if (user?.canViewReports == true || isAdmin)
            _drawerItem(Icons.bar_chart, 'التقارير', Colors.purple,
                () { Navigator.pop(context); _goTo(const ReportsScreen()); }),

          const Divider(),
          const Padding(
            padding: EdgeInsets.only(right: 16, top: 4, bottom: 4),
            child: Text('النظام', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),

          if (isAdmin)
            _drawerItem(Icons.settings, 'الإعدادات', Colors.grey,
                () { Navigator.pop(context); _goTo(const SettingsScreen()); }),

          if (isAdmin)
            _drawerItem(Icons.backup, 'النسخ الاحتياطي', Colors.orange,
                () { Navigator.pop(context); _goTo(const BackupScreen()); }),

          _drawerItem(Icons.logout, 'تسجيل الخروج', Colors.red, _logout),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
      dense: true,
    );
  }
}
