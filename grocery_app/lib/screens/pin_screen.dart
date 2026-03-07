import 'package:flutter/material.dart';
import 'home_screen.dart';

class PinScreen extends StatefulWidget {
  final String correctPin;
  const PinScreen({super.key, required this.correctPin});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _entered = '';
  bool _error = false;

  void _press(String val) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += val;
      _error = false;
    });
    if (_entered.length == 4) _check();
  }

  void _delete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  void _check() {
    if (_entered == widget.correctPin) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      setState(() {
        _entered = '';
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store, size: 64, color: Colors.white),
            const SizedBox(height: 8),
            const Text('إدارة البقالة', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            const Text('أدخل الرقم السري', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16, height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _entered.length ? Colors.white : Colors.white30,
                ),
              )),
            ),
            if (_error) ...[
              const SizedBox(height: 12),
              const Text('رقم سري خاطئ', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ],
            const SizedBox(height: 40),
            _buildPad(),
          ],
        ),
      ),
    );
  }

  Widget _buildPad() {
    final keys = [
      ['1','2','3'],
      ['4','5','6'],
      ['7','8','9'],
      ['','0','⌫'],
    ];
    return Column(
      children: keys.map((row) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.map((k) => GestureDetector(
          onTap: () => k == '⌫' ? _delete() : k.isNotEmpty ? _press(k) : null,
          child: Container(
            width: 70, height: 70,
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: k.isEmpty ? Colors.transparent : Colors.white24,
            ),
            child: Center(
              child: Text(k, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ),
        )).toList(),
      )).toList(),
    );
  }
}
