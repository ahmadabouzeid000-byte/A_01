import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../utils/excel_service.dart';
import '../utils/pdf_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic> _daily = {};
  Map<String, dynamic> _monthly = {};
  List<Map<String, dynamic>> _topProducts = [];
  String _currency = 'جنيه';
  DateTime _selectedDate = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final today = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final daily = await db.getDailyReport(today);
    final monthly = await db.getMonthlyReport(_selectedYear, _selectedMonth);
    final monthStart = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-01';
    final monthEnd = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-31';
    final top = await db.getTopProducts(monthStart, monthEnd);
    final cur = await db.getSetting('currency');
    setState(() {
      _daily = daily;
      _monthly = monthly;
      _topProducts = top;
      _currency = cur.isNotEmpty ? cur : 'جنيه';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: 'تصدير',
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'pdf_daily', child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.red, size: 18), SizedBox(width: 8), Text('PDF يومي')])),
              const PopupMenuItem(value: 'excel_monthly', child: Row(children: [Icon(Icons.table_chart, color: Colors.green, size: 18), SizedBox(width: 8), Text('Excel شهري')])),
              const PopupMenuItem(value: 'excel_inventory', child: Row(children: [Icon(Icons.inventory, color: Colors.blue, size: 18), SizedBox(width: 8), Text('Excel المخزون')])),
            ],
            onSelected: (v) async {
              final storeName = await DatabaseHelper().getSetting('store_name');
              if (v == 'pdf_daily') {
                final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
                final sales = await DatabaseHelper().getSalesByDate(date);
                await PdfService.shareDailyReport(
                  report: _daily, date: DateFormat('dd/MM/yyyy').format(_selectedDate),
                  storeName: storeName.isNotEmpty ? storeName : 'محل البقالة',
                  currency: _currency, sales: sales,
                );
              } else if (v == 'excel_monthly') {
                await ExcelService.exportMonthlyReport(
                  year: _selectedYear, month: _selectedMonth,
                  storeName: storeName.isNotEmpty ? storeName : 'محل البقالة',
                  currency: _currency,
                );
              } else if (v == 'excel_inventory') {
                final products = await DatabaseHelper().getAllProducts();
                await ExcelService.exportInventory(products: products, currency: _currency);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'يومي'),
            Tab(text: 'شهري'),
            Tab(text: 'أفضل المنتجات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildDailyReport(),
          _buildMonthlyReport(),
          _buildTopProducts(),
        ],
      ),
    );
  }

  Widget _buildDailyReport() {
    final sales = (_daily['sales_total'] as num? ?? 0).toDouble();
    final profit = (_daily['profit'] as num? ?? 0).toDouble();
    final expenses = (_daily['expenses'] as num? ?? 0).toDouble();
    final count = _daily['sales_count'] ?? 0;
    final net = profit - expenses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) {
                      setState(() => _selectedDate = d);
                      _load();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('dd/MM/yyyy', 'ar').format(_selectedDate)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _reportCard('إجمالي المبيعات', sales, _currency, Icons.trending_up, Colors.blue),
          _reportCard('الأرباح الإجمالية', profit, _currency, Icons.attach_money, Colors.green),
          _reportCard('المصروفات', expenses, _currency, Icons.money_off, Colors.orange),
          _reportCard('صافي الأرباح', net, _currency, Icons.account_balance, net >= 0 ? Colors.green : Colors.red),
          _reportCard('عدد الفواتير', count.toDouble(), 'فاتورة', Icons.receipt, Colors.purple, isCurrency: false),
        ],
      ),
    );
  }

  Widget _buildMonthlyReport() {
    final sales = (_monthly['sales_total'] as num? ?? 0).toDouble();
    final profit = (_monthly['profit'] as num? ?? 0).toDouble();
    final expenses = (_monthly['expenses'] as num? ?? 0).toDouble();
    final purchases = (_monthly['purchases'] as num? ?? 0).toDouble();
    final count = _monthly['sales_count'] ?? 0;
    final net = profit - expenses;

    final months = ['يناير','فبراير','مارس','إبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth,
                  decoration: const InputDecoration(labelText: 'الشهر'),
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))),
                  onChanged: (v) { setState(() => _selectedMonth = v!); _load(); },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: const InputDecoration(labelText: 'السنة'),
                  items: [2023, 2024, 2025, 2026].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                  onChanged: (v) { setState(() => _selectedYear = v!); _load(); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _reportCard('إجمالي المبيعات', sales, _currency, Icons.trending_up, Colors.blue),
          _reportCard('الأرباح', profit, _currency, Icons.attach_money, Colors.green),
          _reportCard('المصروفات', expenses, _currency, Icons.money_off, Colors.orange),
          _reportCard('المشتريات', purchases, _currency, Icons.shopping_cart, Colors.indigo),
          _reportCard('صافي الأرباح', net, _currency, Icons.account_balance, net >= 0 ? Colors.green : Colors.red),
          _reportCard('عدد الفواتير', count.toDouble(), 'فاتورة', Icons.receipt, Colors.purple, isCurrency: false),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return _topProducts.isEmpty
        ? const Center(child: Text('لا توجد بيانات'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _topProducts.length,
            itemBuilder: (_, i) {
              final p = _topProducts[i];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1B5E20).withOpacity(0.15),
                    child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                  ),
                  title: Text(p['product_name'] ?? ''),
                  subtitle: Text('الكمية المباعة: ${p['qty']}'),
                  trailing: Text('${(p['revenue'] as num).toStringAsFixed(0)} $_currency',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                ),
              );
            },
          );
  }

  Widget _reportCard(String title, double value, String unit, IconData icon, Color color, {bool isCurrency = true}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Text(
                  isCurrency ? '${value.toStringAsFixed(2)} $unit' : '${value.toStringAsFixed(0)} $unit',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
