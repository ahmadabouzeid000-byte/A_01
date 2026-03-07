import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<Purchase> _purchases = [];
  String _currency = 'جنيه';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final p = await db.getAllPurchases();
    final c = await db.getSetting('currency');
    setState(() {
      _purchases = p;
      _currency = c.isNotEmpty ? c : 'جنيه';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المشتريات')),
      body: _purchases.isEmpty
          ? const Center(child: Text('لا توجد مشتريات مسجلة'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _purchases.length,
              itemBuilder: (_, i) {
                final p = _purchases[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shopping_cart, color: Colors.orange),
                    ),
                    title: Text(p.supplierName ?? 'بدون مورد',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الإجمالي: ${p.total.toStringAsFixed(2)} $_currency'),
                        if (p.remaining > 0)
                          Text('متبقي: ${p.remaining.toStringAsFixed(2)} $_currency',
                            style: const TextStyle(color: Colors.red, fontSize: 12)),
                        Text(p.createdAt?.substring(0, 10) ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    trailing: p.remaining > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('دين', style: TextStyle(color: Colors.red, fontSize: 12)),
                          )
                        : const Icon(Icons.check_circle, color: Colors.green),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPurchaseScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('شراء جديد'),
      ),
    );
  }
}

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  List<Product> _products = [];
  List<Supplier> _suppliers = [];
  final List<Map<String, dynamic>> _items = [];
  Supplier? _selectedSupplier;
  String _currency = 'جنيه';
  final _paidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  double get _total => _items.fold(0, (s, i) => s + (i['qty'] as double) * (i['price'] as double));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final prods = await db.getAllProducts();
    final sups = await db.getAllSuppliers();
    final cur = await db.getSetting('currency');
    setState(() {
      _products = prods;
      _suppliers = sups;
      _currency = cur.isNotEmpty ? cur : 'جنيه';
    });
  }

  void _addItem() async {
    Product? selected;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('إضافة منتج'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                decoration: const InputDecoration(labelText: 'المنتج'),
                items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (p) {
                  setS(() {
                    selected = p;
                    priceCtrl.text = p?.buyPrice.toString() ?? '';
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الكمية'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'سعر الشراء', suffixText: _currency),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (selected == null) return;
                setState(() {
                  _items.add({
                    'product': selected!,
                    'qty': double.tryParse(qtyCtrl.text) ?? 1,
                    'price': double.tryParse(priceCtrl.text) ?? selected!.buyPrice,
                  });
                });
                Navigator.pop(ctx);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_items.isEmpty) return;
    final purchase = Purchase(
      supplierId: _selectedSupplier?.id,
      supplierName: _selectedSupplier?.name,
      total: _total,
      paid: double.tryParse(_paidCtrl.text) ?? 0,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    final items = _items.map((i) => PurchaseItem(
      purchaseId: 0,
      productId: (i['product'] as Product).id!,
      productName: (i['product'] as Product).name,
      quantity: i['qty'],
      buyPrice: i['price'],
    )).toList();

    await DatabaseHelper().insertPurchase(purchase, items);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تسجيل الشراء')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شراء جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<Supplier>(
              decoration: const InputDecoration(labelText: 'المورد (اختياري)'),
              items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
              onChanged: (s) => setState(() => _selectedSupplier = s),
              value: _selectedSupplier,
            ),
            const SizedBox(height: 12),
            const Text('المنتجات المشتراة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((e) {
              final item = e.value;
              final p = item['product'] as Product;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  dense: true,
                  title: Text(p.name),
                  subtitle: Text('${item['qty']} ${p.unit} × ${item['price']} $_currency'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${((item['qty'] as double) * (item['price'] as double)).toStringAsFixed(2)} $_currency',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        onPressed: () => setState(() => _items.removeAt(e.key)),
                      ),
                    ],
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('إضافة منتج'),
            ),
            const SizedBox(height: 16),
            if (_items.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${_total.toStringAsFixed(2)} $_currency',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B5E20))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _paidCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'المدفوع', suffixText: _currency, hintText: '${_total.toStringAsFixed(0)}'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(onPressed: _save, child: const Text('تسجيل الشراء')),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
