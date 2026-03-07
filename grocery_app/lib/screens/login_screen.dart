import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/user_session.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  bool _error = false;
  bool _loading = false;

  void _press(String val) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += val;
      _error = false;
    });
    if (_pin.length == 4) _login();
  }

  void _delete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final userData = await DatabaseHelper().loginWithPin(_pin);
    if (!mounted) return;

    if (userData == null) {
      setState(() { _pin = ''; _error = true; _loading = false; });
      return;
    }

    UserSession.login(UserSession.fromMap(userData));
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store, size: 72, color: Colors.white),
            const SizedBox(height: 10),
            const Text('إدارة البقالة', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('أدخل رقمك السري', style: TextStyle(color: Colors.white60, fontSize: 15)),
            const SizedBox(height: 32),

            // نقاط الرقم السري
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: i < _pin.length ? 18 : 14,
                height: i < _pin.length ? 18 : 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? Colors.white : Colors.white30,
                ),
              )),
            ),

            if (_error) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade400.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('رقم سري غير صحيح ❌', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],

            const SizedBox(height: 36),

            if (_loading)
              const CircularProgressIndicator(color: Colors.white)
            else
              _buildPad(),

            const SizedBox(height: 24),
            const Text('المدير الافتراضي: 1234', style: TextStyle(color: Colors.white30, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildPad() {
    final keys = [['1','2','3'], ['4','5','6'], ['7','8','9'], ['','0','⌫']];
    return Column(
      children: keys.map((row) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.map((k) => GestureDetector(
          onTap: () => k == '⌫' ? _delete() : k.isNotEmpty ? _press(k) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 72, height: 72,
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: k.isEmpty ? Colors.transparent : Colors.white.withOpacity(0.15),
              border: k.isNotEmpty && k != '⌫' ? Border.all(color: Colors.white24, width: 1) : null,
            ),
            child: Center(
              child: k == '⌫'
                  ? const Icon(Icons.backspace_outlined, color: Colors.white70, size: 22)
                  : Text(k, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500)),
            ),
          ),
        )).toList(),
      )).toList(),
    );
  }
}
