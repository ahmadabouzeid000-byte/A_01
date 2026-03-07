import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../utils/excel_service.dart';

class EmployeeReportScreen extends StatefulWidget {
  const EmployeeReportScreen({super.key});

  @override
  State<EmployeeReportScreen> createState() => _EmployeeReportScreenState();
}

class _EmployeeReportScreenState extends State<EmployeeReportScreen> {
  List<Map<String, dynamic>> _report = [];
  String _currency = 'جنيه';
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper();
    final fromStr = DateFormat('yyyy-MM-dd').format(_from);
    final toStr = DateFormat('yyyy-MM-dd').format(_to);
    final report = await db.getAllEmployeesSalesReport(fromStr, toStr);
    final cur = await db.getSetting('currency');
    setState(() {
      _report = report;
      _currency = cur.isNotEmpty ? cur : 'جنيه';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = _report.fold(0.0, (s, r) => s + (r['sales_total'] as num));

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الموظفين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'تصدير Excel',
            onPressed: _report.isEmpty ? null : () async {
              final fromStr = DateFormat('yyyy-MM-dd').format(_from);
              final toStr = DateFormat('yyyy-MM-dd').format(_to);
              await ExcelService.exportEmployeesReport(
                report: _report, from: fromStr, to: toStr, currency: _currency,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1B5E20).withOpacity(0.08),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: DateTimeRange(start: _from, end: _to),
                      );
                      if (range != null) {
                        setState(() { _from = range.start; _to = range.end; });
                        _load();
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text('${DateFormat('dd/MM').format(_from)} - ${DateFormat('dd/MM').format(_to)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('إجمالي المبيعات', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text('${totalSales.toStringAsFixed(0)} $_currency',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _report.isEmpty
                    ? const Center(child: Text('لا توجد بيانات في هذه الفترة'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _report.length,
                        itemBuilder: (_, i) {
                          final r = _report[i];
                          final sales = (r['sales_total'] as num).toDouble();
                          final count = r['sales_count'];
                          final discount = (r['total_discount'] as num).toDouble();
                          final pct = totalSales > 0 ? (sales / totalSales * 100) : 0.0;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: const Color(0xFF1B5E20).withOpacity(0.15),
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(r['user_name'] ?? 'غير معروف',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                      Text('${sales.toStringAsFixed(0)} $_currency',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20))),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // شريط النسبة
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct / 100,
                                      backgroundColor: Colors.grey.shade200,
                                      color: const Color(0xFF1B5E20),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _infoChip(Icons.receipt, '$count فاتورة', Colors.blue),
                                      const SizedBox(width: 8),
                                      _infoChip(Icons.percent, '${pct.toStringAsFixed(1)}% من الإجمالي', Colors.purple),
                                      if (discount > 0) ...[
                                        const SizedBox(width: 8),
                                        _infoChip(Icons.discount, 'خصم: ${discount.toStringAsFixed(0)}', Colors.orange),
                                      ],
                                    ],
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
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
