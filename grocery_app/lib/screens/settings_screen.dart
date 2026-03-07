import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/sound_service.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // إعدادات عامة
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _thanksMsgCtrl = TextEditingController();
  String _currency = 'جنيه';
  bool _lowStockAlert = true;
  bool _soundOnSale = true;

  // قوائم ديناميكية
  List<String> _productCategories = [];
  List<String> _productUnits = [];
  List<String> _expenseCategories = [];
  List<String> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final name = await db.getSetting('store_name');
    final phone = await db.getSetting('store_phone');
    final address = await db.getSetting('store_address');
    final thanks = await db.getSetting('invoice_thanks_msg');
    final cur = await db.getSetting('currency');
    final alert = await db.getSetting('low_stock_alert');
    final sound = await db.getSetting('sound_on_sale');
    final cats = await db.getProductCategories();
    final units = await db.getProductUnits();
    final expCats = await db.getExpenseCategories();
    final methods = await db.getPaymentMethods();
    setState(() {
      _nameCtrl.text = name;
      _phoneCtrl.text = phone;
      _addressCtrl.text = address;
      _thanksMsgCtrl.text = thanks.isNotEmpty ? thanks : 'شكراً لتعاملكم معنا 🙏';
      _currency = cur.isNotEmpty ? cur : 'جنيه';
      _lowStockAlert = alert != 'false';
      _soundOnSale = sound != 'false';
      _productCategories = cats;
      _productUnits = units;
      _expenseCategories = expCats;
      _paymentMethods = methods;
    });
  }

  Future<void> _saveGeneral() async {
    final db = DatabaseHelper();
    await db.setSetting('store_name', _nameCtrl.text.trim());
    await db.setSetting('store_phone', _phoneCtrl.text.trim());
    await db.setSetting('store_address', _addressCtrl.text.trim());
    await db.setSetting('invoice_thanks_msg', _thanksMsgCtrl.text.trim());
    await db.setSetting('currency', _currency);
    await db.setSetting('low_stock_alert', _lowStockAlert.toString());
    await db.setSetting('sound_on_sale', _soundOnSale.toString());
    SoundService.setEnabled(_soundOnSale);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ الإعدادات'), backgroundColor: Colors.green));
    }
  }

  Future<void> _addToList(String table, String label) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('إضافة $label'),
        content: TextField(controller: ctrl,
            decoration: InputDecoration(labelText: label, hintText: 'مثال: ...'),
            autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              bool ok = false;
              final db = DatabaseHelper();
              if (table == 'product_categories') ok = await db.addProductCategory(ctrl.text);
              else if (table == 'product_units') ok = await db.addProductUnit(ctrl.text);
              else if (table == 'expense_categories') ok = await db.addExpenseCategory(ctrl.text);
              else if (table == 'payment_methods') ok = await db.addPaymentMethod(ctrl.text);
              if (mounted) {
                Navigator.pop(context);
                if (ok) { _load(); }
                else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الاسم موجود بالفعل')));
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String table, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف'),
        content: Text('حذف "$name"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper().deleteCustomCategory(table, name);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.store, size: 18), text: 'عام'),
            Tab(icon: Icon(Icons.category, size: 18), text: 'الفئات'),
            Tab(icon: Icon(Icons.straighten, size: 18), text: 'الوحدات'),
            Tab(icon: Icon(Icons.payment, size: 18), text: 'الدفع'),
            Tab(icon: Icon(Icons.backup, size: 18), text: 'النسخ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildGeneralTab(),
          _buildListTab('product_categories', 'فئة منتجات', _productCategories),
          _buildListTab('product_units', 'وحدة قياس', _productUnits),
          _buildListTab('payment_methods', 'طريقة دفع', _paymentMethods),
          _buildBackupTab(),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _section('معلومات المحل', Icons.store),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextFormField(controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم المحل', prefixIcon: Icon(Icons.store))),
            const SizedBox(height: 10),
            TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم التلفون (يظهر في الفاتورة)', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 10),
            TextFormField(controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'العنوان (اختياري)', prefixIcon: Icon(Icons.location_on))),
            const SizedBox(height: 10),
            TextFormField(controller: _thanksMsgCtrl,
                decoration: const InputDecoration(labelText: 'رسالة الشكر في أسفل الفاتورة', prefixIcon: Icon(Icons.favorite))),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(labelText: 'العملة', prefixIcon: Icon(Icons.attach_money)),
              items: ['جنيه', 'دولار', 'يورو', 'ريال سعودي', 'دينار كويتي', 'درهم']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _currency = v!),
            ),
          ]),
        )),

        const SizedBox(height: 16),
        _section('الصوت والإشعارات', Icons.notifications),
        Card(child: Column(children: [
          SwitchListTile(
            title: const Text('صوت الكاشير عند البيع'),
            subtitle: const Text('رنة عند إتمام كل عملية بيع'),
            secondary: const Icon(Icons.volume_up),
            value: _soundOnSale,
            onChanged: (v) => setState(() => _soundOnSale = v),
            activeColor: const Color(0xFF1B5E20),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('تنبيه المخزون المنخفض'),
            subtitle: const Text('تظهر في الصفحة الرئيسية'),
            secondary: const Icon(Icons.warning_amber),
            value: _lowStockAlert,
            onChanged: (v) => setState(() => _lowStockAlert = v),
            activeColor: const Color(0xFF1B5E20),
          ),
        ])),

        const SizedBox(height: 16),
        _section('الأمان', Icons.security),
        Card(child: ListTile(
          leading: const Icon(Icons.lock),
          title: const Text('تغيير رقم المدير السري'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _changeMgrPin,
        )),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveGeneral,
            icon: const Icon(Icons.save),
            label: const Text('حفظ الإعدادات'),
          ),
        ),
      ]),
    );
  }

  Widget _buildListTab(String table, String label, List<String> items) {
    // الأشياء المحمية من الحذف
    final protectedItems = ['كاش', 'أجل', 'فودافون كاش', 'انستاباي', 'عام', 'قطعة', 'كيلو'];

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Text('${items.length} عنصر', style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _addToList(table, label),
            icon: const Icon(Icons.add, size: 18),
            label: Text('إضافة $label'),
          ),
        ]),
      ),
      Expanded(
        child: items.isEmpty
            ? const Center(child: Text('لا يوجد عناصر'))
            : ListView.builder(
                itemCount: items.length,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final isProtected = protectedItems.contains(item);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20)))),
                      ),
                      title: Text(item),
                      trailing: isProtected
                          ? const Tooltip(
                              message: 'عنصر افتراضي لا يمكن حذفه',
                              child: Icon(Icons.lock_outline, size: 18, color: Colors.grey))
                          : IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _deleteItem(table, item)),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _buildBackupTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.backup, size: 64, color: Color(0xFF1B5E20)),
          const SizedBox(height: 16),
          const Text('النسخ الاحتياطي والاستعادة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('صدّر بياناتك وانقلها لأي هاتف بسهولة',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const BackupScreen())),
              icon: const Icon(Icons.backup),
              label: const Text('إدارة النسخ الاحتياطي'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF1B5E20)),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
      ]),
    );
  }

  Future<void> _changeMgrPin() async {
    final c1 = TextEditingController(), c2 = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير رقم المدير السري'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c1, keyboardType: TextInputType.number,
              maxLength: 4, obscureText: true,
              decoration: const InputDecoration(labelText: 'الرقم الجديد')),
          TextField(controller: c2, keyboardType: TextInputType.number,
              maxLength: 4, obscureText: true,
              decoration: const InputDecoration(labelText: 'تأكيد الرقم')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (c1.text.length != 4) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('4 أرقام فقط'))); return; }
              if (c1.text != c2.text) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الأرقام غير متطابقة'))); return; }
              await DatabaseHelper().updateUser(1, {'pin': c1.text});
              if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم التغيير'))); }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
