import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loading = false;
  Map<String, int> _stats = {};
  String _dbSize = '';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await BackupService.getStats();
    final size = await BackupService.getDatabaseSize();
    if (mounted) setState(() { _stats = stats; _dbSize = size; });
  }

  Future<void> _export() async {
    setState(() => _loading = true);
    try {
      await BackupService.shareBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تصدير النسخة الاحتياطية'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التصدير: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _import() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('تحذير مهم'),
        ]),
        content: const Text(
          'سيتم استبدال جميع البيانات الحالية بالبيانات من ملف النسخة الاحتياطية.\n\n'
          'يُنصح بعمل تصدير أولاً قبل الاستيراد.\n\n'
          'هل تريد المتابعة؟',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'اختر ملف النسخة الاحتياطية (.json)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الملف: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر الوصول للملف'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (mounted) setState(() => _loading = true);
    final importResult = await BackupService.importBackup(path);

    if (mounted) {
      setState(() => _loading = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Row(children: [
            Icon(importResult.success ? Icons.check_circle : Icons.error,
                color: importResult.success ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Text(importResult.success ? 'تم الاستيراد' : 'فشل الاستيراد'),
          ]),
          content: Text(importResult.message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (importResult.success) _loadStats();
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والاستعادة')),
      body: _loading
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري المعالجة...', style: TextStyle(fontSize: 16)),
              ],
            ))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بيانات التطبيق
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  // تصدير
                  _buildExportCard(),
                  const SizedBox(height: 24),
                  // استيراد
                  _buildImportCard(),
                  const SizedBox(height: 24),
                  // تعليمات
                  _buildInstructionsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.storage, color: Color(0xFF1B5E20)),
          SizedBox(width: 8),
          Text('بيانات التطبيق الحالية',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 12),
        _statRow('المنتجات', '${_stats['products'] ?? 0}', Icons.inventory_2),
        _statRow('الفواتير', '${_stats['sales'] ?? 0}', Icons.receipt_long),
        _statRow('الموردين', '${_stats['suppliers'] ?? 0}', Icons.people),
        _statRow('المصروفات', '${_stats['expenses'] ?? 0}', Icons.money_off),
        const Divider(),
        _statRow('حجم قاعدة البيانات', _dbSize, Icons.sd_storage),
      ]),
    );
  }

  Widget _buildExportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📤 تصدير النسخة الاحتياطية',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'يصدّر كل البيانات في ملف JSON يمكن:\n'
          '• إرساله على واتساب أو تيليجرام\n'
          '• حفظه على Google Drive أو OneDrive\n'
          '• نقله لأي هاتف آخر فيه التطبيق',
          style: TextStyle(fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _export,
          icon: const Icon(Icons.share),
          label: const Text('تصدير ومشاركة البيانات'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        )),
      ]),
    );
  }

  Widget _buildImportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📥 استيراد من نسخة احتياطية',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 16),
          SizedBox(width: 6),
          Text('سيستبدل البيانات الحالية بالكامل',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        const Text(
          'اختر ملف النسخة الاحتياطية (.json) من الهاتف\nوسيتم استعادة كل البيانات تلقائياً.',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _import,
          icon: const Icon(Icons.folder_open),
          label: const Text('اختر ملف الاستيراد'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        )),
      ]),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.phone_android, color: Colors.grey),
          SizedBox(width: 8),
          Text('كيف تنقل البيانات لهاتف جديد؟',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        SizedBox(height: 10),
        Text(
          '١. على الهاتف القديم: اضغط "تصدير" وأرسل الملف لنفسك على واتساب\n'
          '٢. على الهاتف الجديد: ثبّت التطبيق\n'
          '٣. افتح الـ Drawer ← النسخ الاحتياطي\n'
          '٤. اضغط "اختر ملف الاستيراد" واختر الملف من واتساب\n'
          '٥. تأكيد — وكل البيانات هتتحول تلقائياً',
          style: TextStyle(fontSize: 13, height: 1.9, color: Colors.black87),
        ),
      ]),
    );
  }

  Widget _statRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}
