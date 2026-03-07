import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/user_session.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  List<Product> _filtered = [];
  List<String> _categories = [];
  List<String> _units = [];
  String _search = '';
  String _filterCat = 'الكل';
  String _currency = 'جنيه';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final prods = await db.getAllProducts();
    final cats = await db.getProductCategories();
    final units = await db.getProductUnits();
    final cur = await db.getSetting('currency');
    setState(() {
      _products = prods;
      _categories = cats;
      _units = units;
      _currency = cur.isNotEmpty ? cur : 'جنيه';
      _applyFilter();
    });
  }

  void _applyFilter() {
    _filtered = _products.where((p) {
      final matchSearch = _search.isEmpty ||
          p.name.contains(_search) ||
          (p.barcode?.contains(_search) ?? false);
      final matchCat = _filterCat == 'الكل' || p.category == _filterCat;
      return matchSearch && matchCat;
    }).toList();
  }

  Future<void> _showProductDialog([Product? product]) async {
    final isEdit = product != null;
    final nameCtrl = TextEditingController(text: product?.name);
    final barcodeCtrl = TextEditingController(text: product?.barcode);
    final buyCtrl = TextEditingController(text: product?.buyPrice.toString() ?? '');
    final sellCtrl = TextEditingController(text: product?.sellPrice.toString() ?? '');
    final qtyCtrl = TextEditingController(text: product?.quantity.toString() ?? '0');
    final minQtyCtrl = TextEditingController(text: product?.minQuantity.toString() ?? '5');
    String category = product?.category ?? (_categories.isNotEmpty ? _categories.first : 'عام');
    String unit = product?.unit ?? (_units.isNotEmpty ? _units.first : 'قطعة');

    // تحقق أن القيم الافتراضية موجودة في القوائم
    if (!_categories.contains(category) && _categories.isNotEmpty) category = _categories.first;
    if (!_units.contains(unit) && _units.isNotEmpty) unit = _units.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(isEdit ? 'تعديل منتج' : 'إضافة منتج',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const Divider(),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج *', prefixIcon: Icon(Icons.inventory))),
                const SizedBox(height: 10),
                TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'باركود (اختياري)', prefixIcon: Icon(Icons.qr_code))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: buyCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'سعر الشراء *', prefixIcon: Icon(Icons.arrow_downward, color: Colors.red)))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: sellCtrl, keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'سعر البيع *', prefixIcon: const Icon(Icons.arrow_upward, color: Colors.green),
                          suffix: Text(_currency, style: const TextStyle(fontSize: 12))))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الكمية', prefixIcon: Icon(Icons.numbers)))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: minQtyCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'حد التنبيه', prefixIcon: Icon(Icons.warning_amber, color: Colors.orange)))),
                ]),
                const SizedBox(height: 10),
                // وحدة القياس مع اقتراحات
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: const InputDecoration(labelText: 'وحدة القياس', prefixIcon: Icon(Icons.straighten)),
                  items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setS(() => unit = v!),
                ),
                const SizedBox(height: 10),
                // الفئة مع اقتراحات
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'الفئة', prefixIcon: Icon(Icons.category)),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(isEdit ? Icons.save : Icons.add_circle),
                    label: Text(isEdit ? 'حفظ التعديلات' : 'إضافة المنتج'),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل اسم المنتج')));
                        return;
                      }
                      final p = Product(
                        id: product?.id,
                        name: nameCtrl.text.trim(),
                        barcode: barcodeCtrl.text.trim().isNotEmpty ? barcodeCtrl.text.trim() : null,
                        buyPrice: double.tryParse(buyCtrl.text) ?? 0,
                        sellPrice: double.tryParse(sellCtrl.text) ?? 0,
                        quantity: double.tryParse(qtyCtrl.text) ?? 0,
                        minQuantity: double.tryParse(minQtyCtrl.text) ?? 5,
                        unit: unit,
                        category: category,
                      );
                      if (isEdit) { await DatabaseHelper().updateProduct(p); }
                      else { await DatabaseHelper().insertProduct(p); }
                      if (mounted) { Navigator.pop(ctx); _load(); }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowStock = _products.where((p) => p.isLowStock).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          if (lowStock > 0)
            Padding(padding: const EdgeInsets.only(right: 8),
              child: Badge(label: Text('$lowStock'),
                child: const Icon(Icons.warning_amber))),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: (UserSession.current?.canAddProducts == true || UserSession.current?.isAdmin == true)
          ? FloatingActionButton.extended(
              onPressed: () => _showProductDialog(),
              icon: const Icon(Icons.add),
              label: const Text('منتج جديد'),
            )
          : null,
      body: Column(children: [
        Container(
          color: const Color(0xFF1B5E20).withOpacity(0.05),
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الباركود...',
                prefixIcon: const Icon(Icons.search),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onChanged: (v) { setState(() { _search = v; _applyFilter(); }); },
            ),
            const SizedBox(height: 8),
            SizedBox(height: 36, child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['الكل', ..._categories].map((c) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FilterChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  selected: _filterCat == c,
                  onSelected: (_) { setState(() { _filterCat = c; _applyFilter(); }); },
                  selectedColor: const Color(0xFF1B5E20).withOpacity(0.2),
                ),
              )).toList(),
            )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Text('${_filtered.length} منتج', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Spacer(),
            if (lowStock > 0) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
              child: Text('$lowStock منتج قارب النفاد',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
            ),
          ]),
        ),
        Expanded(child: _filtered.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('لا توجد منتجات', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final p = _filtered[i];
                final isLow = p.isLowStock;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isLow ? BorderSide(color: Colors.orange.shade300, width: 1.5) : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isLow ? Colors.orange.shade100 : const Color(0xFF1B5E20).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(isLow ? Icons.warning_amber : Icons.inventory_2,
                          color: isLow ? Colors.orange : const Color(0xFF1B5E20), size: 22),
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${p.category} · ${p.unit}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      Row(children: [
                        Text('المخزون: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        Text(
                          '${p.quantity % 1 == 0 ? p.quantity.toInt() : p.quantity} ${p.unit}',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold,
                            color: isLow ? Colors.orange.shade700 : Colors.grey.shade700)),
                      ]),
                    ]),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${p.sellPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20))),
                      Text(_currency, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ]),
                    onTap: () => _showProductDialog(p),
                    onLongPress: () => _confirmDelete(p),
                  ),
                );
              },
            )),
      ]),
    );
  }

  Future<void> _confirmDelete(Product p) async {
    if (UserSession.current?.isAdmin != true) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف منتج'),
        content: Text('هل تريد حذف "${p.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true && p.id != null) { await DatabaseHelper().deleteProduct(p.id!); _load(); }
  }
}
