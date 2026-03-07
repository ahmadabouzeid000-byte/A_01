import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/whatsapp_service.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Supplier> _suppliers = [];
  String _currency = 'جنيه';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final s = await db.getAllSuppliers();
    final c = await db.getSetting('currency');
    setState(() {
      _suppliers = s;
      _currency = c.isNotEmpty ? c : 'جنيه';
    });
  }

  Future<void> _addOrEdit(Supplier? s) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SupplierForm(supplier: s),
    );
    _load();
  }

  Future<void> _payDebt(Supplier s) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('سداد دين - ${s.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المتبقي: ${s.balance.toStringAsFixed(2)} $_currency',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text) ?? 0;
              if (amount > 0) {
                await DatabaseHelper().paySupplier(s.id!, amount);
                if (mounted) {
                  Navigator.pop(context);
                  _load();
                }
              }
            },
            child: const Text('دفع'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDebt = _suppliers.fold(0.0, (s, sup) => s + sup.balance);

    return Scaffold(
      appBar: AppBar(title: const Text('الموردين')),
      body: Column(
        children: [
          if (totalDebt > 0)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('إجمالي الديون: ${totalDebt.toStringAsFixed(2)} $_currency',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ),
          Expanded(
            child: _suppliers.isEmpty
                ? const Center(child: Text('لا يوجد موردين'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _suppliers.length,
                    itemBuilder: (_, i) {
                      final s = _suppliers[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: s.balance > 0 ? Colors.red.shade100 : Colors.green.shade100,
                            child: Text(s.name[0], style: TextStyle(
                              color: s.balance > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            )),
                          ),
                          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s.phone != null) Text(s.phone!, style: const TextStyle(fontSize: 12)),
                              Text(
                                s.balance > 0 ? 'مديون: ${s.balance.toStringAsFixed(2)} $_currency' : 'لا يوجد ديون',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: s.balance > 0 ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (s.balance > 0) ...[
                                IconButton(
                                  icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                                  onPressed: () async {
                                    final storeName = await DatabaseHelper().getSetting('store_name');
                                    await WhatsAppService.sendDebtReminder(
                                      customerName: s.name,
                                      amount: s.balance,
                                      storeName: storeName.isNotEmpty ? storeName : 'المحل',
                                      currency: _currency,
                                      phone: s.phone,
                                    );
                                  },
                                  tooltip: 'تذكير واتساب',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.payment, color: Colors.green),
                                  onPressed: () => _payDebt(s),
                                  tooltip: 'سداد دين',
                                ),
                              ],
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _addOrEdit(s),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(null),
        icon: const Icon(Icons.person_add),
        label: const Text('مورد جديد'),
      ),
    );
  }
}

class _SupplierForm extends StatefulWidget {
  final Supplier? supplier;
  const _SupplierForm({this.supplier});

  @override
  State<_SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<_SupplierForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name, _phone, _address, _notes;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.supplier?.name ?? '');
    _phone = TextEditingController(text: widget.supplier?.phone ?? '');
    _address = TextEditingController(text: widget.supplier?.address ?? '');
    _notes = TextEditingController(text: widget.supplier?.notes ?? '');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final s = Supplier(
      id: widget.supplier?.id,
      name: _name.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      balance: widget.supplier?.balance ?? 0,
    );
    final db = DatabaseHelper();
    if (s.id == null) {
      await db.insertSupplier(s);
    } else {
      await db.updateSupplier(s);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.supplier == null ? 'مورد جديد' : 'تعديل المورد',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم المورد *'),
                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _save, child: const Text('حفظ')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
