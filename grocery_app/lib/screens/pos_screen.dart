import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/user_session.dart';
import '../utils/pdf_service.dart';
import '../utils/whatsapp_service.dart';
import '../utils/sound_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final List<CartItem> _cart = [];
  final _searchCtrl = TextEditingController();
  List<Product> _searchResults = [];
  bool _scanning = false;
  double _discount = 0;
  String _paymentMethod = 'كاش';
  String _currency = 'جنيه';
  List<String> _paymentMethods = ['كاش', 'أجل', 'فودافون كاش', 'انستاباي'];

  double get _subtotal => _cart.fold(0, (s, i) => s + i.total);
  double get _total => _subtotal - _discount;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = DatabaseHelper();
    final c = await db.getSetting('currency');
    final methods = await db.getPaymentMethods();
    await SoundService.init();
    if (mounted) setState(() {
      _currency = c.isNotEmpty ? c : 'جنيه';
      if (methods.isNotEmpty) {
        _paymentMethods = methods;
        _paymentMethod = methods.first;
      }
    });
  }

  void _search(String q) async {
    if (q.isEmpty) { setState(() => _searchResults = []); return; }
    final results = await DatabaseHelper().searchProducts(q);
    if (mounted) setState(() => _searchResults = results);
  }

  void _addToCart(Product p) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == p.id);
      if (idx >= 0) {
        if (_cart[idx].quantity < p.quantity) {
          _cart[idx].quantity++;
        } else {
          _showMsg('لا يوجد مخزون كافٍ');
        }
      } else {
        if (p.quantity <= 0) { _showMsg('المنتج غير متوفر'); return; }
        _cart.add(CartItem(product: p));
      }
      _searchResults = [];
      _searchCtrl.clear();
    });
  }

  void _removeFromCart(int idx) => setState(() => _cart.removeAt(idx));

  void _changeQty(int idx, double delta) {
    setState(() {
      final item = _cart[idx];
      final newQty = item.quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(idx);
      } else if (newQty > item.product.quantity) {
        _showMsg('لا يوجد مخزون كافٍ');
      } else {
        item.quantity = newQty;
      }
    });
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _onBarcode(String barcode) async {
    setState(() => _scanning = false);
    final p = await DatabaseHelper().getProductByBarcode(barcode);
    if (p == null) { _showMsg('منتج غير موجود: $barcode'); } else { _addToCart(p); }
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    await _showCheckoutDialog();
  }

  Future<void> _showCheckoutDialog() async {
    double paid = _total;
    String method = _paymentMethod;
    double localDiscount = _discount;
    final paidCtrl = TextEditingController(text: _total.toStringAsFixed(0));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final finalTotal = _subtotal - localDiscount;
          return AlertDialog(
            title: const Text('إتمام البيع'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('الإجمالي: ${finalTotal.toStringAsFixed(2)} $_currency',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                    items: _paymentMethods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setS(() => method = v!),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: paidCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'المبلغ المدفوع'),
                    onChanged: (v) => paid = double.tryParse(v) ?? finalTotal,
                  ),
                  if (UserSession.current?.canDiscount == true || UserSession.current?.isAdmin == true) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'خصم (اختياري)'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        setS(() {
                          localDiscount = double.tryParse(v) ?? 0;
                          paidCtrl.text = (_subtotal - localDiscount).toStringAsFixed(0);
                          paid = _subtotal - localDiscount;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final session = UserSession.current;
                  final finalTotalForSale = _subtotal - localDiscount;
                  final sale = Sale(
                    total: finalTotalForSale,
                    discount: localDiscount,
                    paid: paid,
                    paymentMethod: method,
                    userId: session?.id,
                    userName: session?.name,
                  );
                  final saleItems = _cart.map((c) => SaleItem(
                    saleId: 0, productId: c.product.id!,
                    productName: c.product.name, quantity: c.quantity,
                    sellPrice: c.product.sellPrice, buyPrice: c.product.buyPrice,
                  )).toList();

                  final saleId = await DatabaseHelper().insertSale(sale, saleItems);

                  // تشغيل صوت الكاشير
                  await SoundService.playSaleSound();

                  final completedSale = Sale(
                    id: saleId, total: sale.total, discount: sale.discount,
                    paid: paid, paymentMethod: method,
                    userId: session?.id, userName: session?.name,
                    createdAt: DateTime.now().toIso8601String(),
                  );

                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() { _cart.clear(); _discount = 0; });
                    final storeName = await DatabaseHelper().getSetting('store_name');
                    if (mounted) {
                      _showPostSaleOptions(completedSale, saleItems,
                          storeName.isNotEmpty ? storeName : 'محل البقالة');
                    }
                  }
                },
                child: const Text('تأكيد البيع'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPostSaleOptions(Sale sale, List<SaleItem> items, String storeName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 8),
            Text('✅ تم البيع بنجاح — ${sale.total.toStringAsFixed(2)} $_currency',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            const Text('ماذا تريد؟', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _actionBtn(Icons.print, 'طباعة\nالفاتورة', Colors.blue, () async {
                Navigator.pop(context);
                await PdfService.printSaleInvoice(
                    sale: sale, items: items, storeName: storeName, currency: _currency);
              })),
              const SizedBox(width: 10),
              Expanded(child: _actionBtn(Icons.picture_as_pdf, 'مشاركة\nPDF', Colors.red, () async {
                Navigator.pop(context);
                await PdfService.shareSaleInvoice(
                    sale: sale, items: items, storeName: storeName, currency: _currency);
              })),
              const SizedBox(width: 10),
              Expanded(child: _actionBtn(Icons.chat, 'إرسال\nواتساب', const Color(0xFF25D366), () async {
                Navigator.pop(context);
                await WhatsAppService.sendInvoice(
                    sale: sale, items: items, storeName: storeName, currency: _currency,
                    phone: sale.customerName);
              })),
              const SizedBox(width: 10),
              Expanded(child: _actionBtn(Icons.close, 'إغلاق', Colors.grey, () => Navigator.pop(context))),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  void _showMsg2(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        actions: [
          if (_cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                label: Text('${_cart.length}'),
                child: const Icon(Icons.shopping_cart),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // شريط البحث
        Container(
          color: const Color(0xFF1B5E20).withOpacity(0.05),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
                onChanged: _search,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(10)),
              child: IconButton(
                icon: Icon(_scanning ? Icons.close : Icons.qr_code_scanner, color: Colors.white),
                onPressed: () => setState(() => _scanning = !_scanning),
              ),
            ),
          ]),
        ),

        // ماسح الباركود
        if (_scanning)
          Container(
            height: 200, color: Colors.black,
            child: Stack(children: [
              MobileScanner(onDetect: (c) {
                final barcode = c.barcodes.first.rawValue;
                if (barcode != null) _onBarcode(barcode);
              }),
              Center(child: Container(
                  width: 200, height: 2, color: Colors.greenAccent.withOpacity(0.8))),
            ]),
          ),

        // نتائج البحث
        if (_searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            color: Colors.white,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (_, i) {
                final p = _searchResults[i];
                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: p.isLowStock ? Colors.orange.shade100 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.inventory_2, size: 18,
                        color: p.isLowStock ? Colors.orange : Colors.green),
                  ),
                  title: Text(p.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text('${p.quantity} ${p.unit}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Text('${p.sellPrice.toStringAsFixed(2)} $_currency',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                  onTap: () => _addToCart(p),
                );
              },
            ),
          ),

        // السلة
        Expanded(
          child: _cart.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 64,
                        color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('ابدأ بإضافة منتجات',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _cart.length,
                  itemBuilder: (_, i) {
                    final item = _cart[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(
                                '${item.product.sellPrice.toStringAsFixed(2)} × '
                                '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} = '
                                '${item.total.toStringAsFixed(2)} $_currency',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          )),
                          Row(children: [
                            _qtyBtn(Icons.remove, () => _changeQty(i, -1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            _qtyBtn(Icons.add, () => _changeQty(i, 1)),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _removeFromCart(i),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
        ),

        // شريط الإجمالي
        if (_cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                  blurRadius: 8, color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, -2))],
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('المجموع:', style: TextStyle(fontSize: 16)),
                Text('${_subtotal.toStringAsFixed(2)} $_currency',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              if (_discount > 0) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('خصم:', style: TextStyle(color: Colors.red)),
                  Text('-${_discount.toStringAsFixed(2)} $_currency',
                      style: const TextStyle(color: Colors.red)),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('الإجمالي:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${_total.toStringAsFixed(2)} $_currency',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20))),
                ]),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _checkout,
                  icon: const Icon(Icons.check_circle),
                  label: Text('إتمام البيع (${_total.toStringAsFixed(2)} $_currency)'),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20).withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF1B5E20)),
      ),
    );
  }
}
