import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = [];
  List<String> _categories = [];
  String _currency = 'جنيه';
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  double get _total => _expenses.fold(0, (s, e) => s + e.amount);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final cur = await db.getSetting('currency');
    final cats = await db.getExpenseCategories();
    final expenses = await db.getExpensesByRange(_selectedDate, _selectedDate);
    setState(() {
      _currency = cur.isNotEmpty ? cur : 'جنيه';
      _categories = cats;
      _expenses = expenses;
    });
  }

  Future<void> _showAddDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = _categories.isNotEmpty ? _categories.first : 'عام';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('إضافة مصروف',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'عنوان المصروف *', prefixIcon: Icon(Icons.title)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'المبلغ *',
                  prefixIcon: const Icon(Icons.attach_money),
                  suffix: Text(_currency)),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'الفئة', prefixIcon: Icon(Icons.category)),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setS(() => category = v!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظات', prefixIcon: Icon(Icons.note)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('حفظ المصروف'),
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty || amountCtrl.text.isEmpty) return;
                  final e = Expense(
                    title: titleCtrl.text.trim(),
                    amount: double.tryParse(amountCtrl.text) ?? 0,
                    category: category,
                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text : null,
                  );
                  await DatabaseHelper().insertExpense(e);
                  if (mounted) { Navigator.pop(ctx); _load(); }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المصروفات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('إضافة مصروف'),
      ),
      body: Column(children: [
        Container(
          color: const Color(0xFF1B5E20).withOpacity(0.05),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 18, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Text(
              DateFormat('EEEE dd/MM/yyyy', 'ar').format(DateTime.parse(_selectedDate)),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse(_selectedDate),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (d != null) {
                  setState(() => _selectedDate = DateFormat('yyyy-MM-dd').format(d));
                  _load();
                }
              },
              child: const Text('تغيير'),
            ),
          ]),
        ),
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.money_off, color: Colors.red),
            const SizedBox(width: 8),
            const Text('إجمالي المصروفات:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${_total.toStringAsFixed(2)} $_currency',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
          ]),
        ),
        Expanded(
          child: _expenses.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.money_off_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('لا توجد مصروفات هذا اليوم',
                      style: TextStyle(color: Colors.grey.shade400)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _expenses.length,
                  itemBuilder: (_, i) {
                    final e = _expenses[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.receipt_long,
                              color: Colors.red, size: 20),
                        ),
                        title: Text(e.title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${e.category}${e.notes != null ? ' · ${e.notes}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          '${e.amount.toStringAsFixed(2)} $_currency',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 15),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
