import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/user_session.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await DatabaseHelper().getAllUsers();
    setState(() => _users = users);
  }

  Future<void> _addOrEdit(Map<String, dynamic>? user) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UserForm(user: user, onSaved: _load),
    );
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    if (user['role'] == 'admin' && _users.where((u) => u['role'] == 'admin').length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لازم يكون في أدمن واحد على الأقل')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف موظف'),
        content: Text('هل تريد حذف "${user['name']}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper().deactivateUser(user['id']);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الموظفين')),
      body: _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _users.length,
              itemBuilder: (_, i) {
                final u = _users[i];
                final isAdmin = u['role'] == 'admin';
                final isMe = u['id'] == UserSession.current?.id;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAdmin ? const Color(0xFF1B5E20) : Colors.blue.shade100,
                        child: Text(
                          (u['name'] as String)[0],
                          style: TextStyle(
                            color: isAdmin ? Colors.white : Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAdmin ? const Color(0xFF1B5E20).withOpacity(0.15) : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isAdmin ? 'مدير' : 'موظف',
                              style: TextStyle(
                                fontSize: 11,
                                color: isAdmin ? const Color(0xFF1B5E20) : Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10)),
                              child: const Text('أنت', style: TextStyle(fontSize: 10, color: Colors.orange)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: _buildPermissions(u),
                      trailing: PopupMenuButton(
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('تعديل')])),
                          if (!isMe)
                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.person_off, size: 18, color: Colors.red), SizedBox(width: 8), Text('حذف', style: TextStyle(color: Colors.red))])),
                        ],
                        onSelected: (v) {
                          if (v == 'edit') _addOrEdit(u);
                          if (v == 'delete') _delete(u);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(null),
        icon: const Icon(Icons.person_add),
        label: const Text('موظف جديد'),
      ),
    );
  }

  Widget _buildPermissions(Map<String, dynamic> u) {
    if (u['role'] == 'admin') {
      return const Text('كل الصلاحيات', style: TextStyle(color: Color(0xFF1B5E20), fontSize: 12));
    }
    final perms = <String>[];
    if (u['can_sell'] == 1) perms.add('بيع');
    if (u['can_add_products'] == 1) perms.add('منتجات');
    if (u['can_purchase'] == 1) perms.add('مشتريات');
    if (u['can_discount'] == 1) perms.add('خصم');
    if (u['can_view_reports'] == 1) perms.add('تقارير');
    return Text(perms.isEmpty ? 'لا توجد صلاحيات' : perms.join(' • '),
      style: TextStyle(fontSize: 11, color: Colors.grey.shade600));
  }
}

class _UserForm extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onSaved;
  const _UserForm({this.user, required this.onSaved});

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String _role = 'employee';
  bool _canSell = true;
  bool _canAddProducts = false;
  bool _canPurchase = false;
  bool _canDiscount = false;
  bool _canViewReports = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      final u = widget.user!;
      _nameCtrl.text = u['name'];
      _role = u['role'];
      _canSell = u['can_sell'] == 1;
      _canAddProducts = u['can_add_products'] == 1;
      _canPurchase = u['can_purchase'] == 1;
      _canDiscount = u['can_discount'] == 1;
      _canViewReports = u['can_view_reports'] == 1;
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل اسم الموظف')));
      return;
    }
    if (widget.user == null && _pinCtrl.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرقم السري 4 أرقام')));
      return;
    }
    if (_pinCtrl.text.isNotEmpty && _pinCtrl.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرقم السري 4 أرقام')));
      return;
    }

    final db = DatabaseHelper();

    // التحقق من عدم تكرار الرقم السري
    if (_pinCtrl.text.isNotEmpty) {
      final taken = await db.isPinTaken(_pinCtrl.text, excludeId: widget.user?['id']);
      if (taken) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرقم السري مستخدم من قِبل موظف آخر')));
        return;
      }
    }

    final data = {
      'name': _nameCtrl.text.trim(),
      'role': _role,
      'can_sell': _canSell ? 1 : 0,
      'can_add_products': _canAddProducts ? 1 : 0,
      'can_purchase': _canPurchase ? 1 : 0,
      'can_discount': _canDiscount ? 1 : 0,
      'can_view_reports': _canViewReports ? 1 : 0,
      'is_active': 1,
    };

    if (_pinCtrl.text.isNotEmpty) data['pin'] = _pinCtrl.text;

    if (widget.user == null) {
      await db.insertUser(data);
    } else {
      await db.updateUser(widget.user!['id'], data);
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.user == null ? 'موظف جديد' : 'تعديل الموظف',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم الموظف *', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: InputDecoration(
                labelText: widget.user == null ? 'الرقم السري (4 أرقام) *' : 'الرقم السري الجديد (اتركه فارغ للإبقاء)',
                prefixIcon: const Icon(Icons.lock),
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'الدور', prefixIcon: Icon(Icons.badge)),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('مدير - كل الصلاحيات')),
                DropdownMenuItem(value: 'employee', child: Text('موظف - صلاحيات محدودة')),
              ],
              onChanged: (v) => setState(() {
                _role = v!;
                if (_role == 'admin') {
                  _canSell = _canAddProducts = _canPurchase = _canDiscount = _canViewReports = true;
                }
              }),
            ),

            if (_role == 'employee') ...[
              const SizedBox(height: 16),
              const Text('الصلاحيات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _permSwitch('بيع (كاشير)', _canSell, (v) => setState(() => _canSell = v)),
                    _permSwitch('إضافة وتعديل المنتجات', _canAddProducts, (v) => setState(() => _canAddProducts = v)),
                    _permSwitch('تسجيل المشتريات', _canPurchase, (v) => setState(() => _canPurchase = v)),
                    _permSwitch('تطبيق خصم على الفواتير', _canDiscount, (v) => setState(() => _canDiscount = v)),
                    _permSwitch('عرض التقارير', _canViewReports, (v) => setState(() => _canViewReports = v)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: const Text('حفظ')),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _permSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF1B5E20),
      dense: true,
    );
  }
}
