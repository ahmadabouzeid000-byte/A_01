import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class WhatsAppService {
  // ==================== إرسال فاتورة للعميل ====================
  static Future<void> sendInvoice({
    required Sale sale,
    required List<SaleItem> items,
    required String storeName,
    required String currency,
    String? phone,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('🏪 *$storeName*');
    buffer.writeln('─────────────────');
    buffer.writeln('🧾 *فاتورة رقم:* #${sale.id}');
    buffer.writeln('📅 *التاريخ:* ${_formatDate(sale.createdAt)}');
    buffer.writeln('');
    buffer.writeln('📦 *المنتجات:*');

    for (final item in items) {
      buffer.writeln('• ${item.productName}');
      buffer.writeln('  ${item.quantity} × ${item.sellPrice.toStringAsFixed(2)} = ${item.total.toStringAsFixed(2)} $currency');
    }

    buffer.writeln('');
    buffer.writeln('─────────────────');
    buffer.writeln('💰 *الإجمالي:* ${sale.total.toStringAsFixed(2)} $currency');
    if (sale.discount > 0) {
      buffer.writeln('🎁 *خصم:* -${sale.discount.toStringAsFixed(2)} $currency');
      buffer.writeln('💵 *بعد الخصم:* ${(sale.total - sale.discount).toStringAsFixed(2)} $currency');
    }
    buffer.writeln('✅ *المدفوع:* ${sale.paid.toStringAsFixed(2)} $currency');
    if (sale.remaining > 0) {
      buffer.writeln('⏳ *المتبقي:* ${sale.remaining.toStringAsFixed(2)} $currency');
    }
    buffer.writeln('💳 *طريقة الدفع:* ${sale.paymentMethod}');
    buffer.writeln('');
    buffer.writeln('شكراً لتعاملكم معنا 🙏');

    await _openWhatsApp(phone: phone, message: buffer.toString());
  }

  // ==================== تذكير بالدين ====================
  static Future<void> sendDebtReminder({
    required String customerName,
    required double amount,
    required String storeName,
    required String currency,
    String? phone,
  }) async {
    final message = '''
🏪 *$storeName*
─────────────────
عزيزنا *$customerName*،

نود تذكيركم بأن لديكم رصيد مستحق:

💸 *المبلغ المستحق:* ${amount.toStringAsFixed(2)} $currency

نرجو التكرم بسداد المبلغ في أقرب وقت ممكن.

شكراً لتفهمكم 🙏
    ''';

    await _openWhatsApp(phone: phone, message: message.trim());
  }

  // ==================== رسالة ترحيب / عروض ====================
  static Future<void> sendPromoMessage({
    required String storeName,
    required String message,
    String? phone,
  }) async {
    final fullMessage = '''
🏪 *$storeName*
─────────────────
$message

للاستفسار تواصل معنا 📞
    ''';

    await _openWhatsApp(phone: phone, message: fullMessage.trim());
  }

  // ==================== رسالة تأكيد طلب ====================
  static Future<void> sendOrderConfirmation({
    required String customerName,
    required double total,
    required String storeName,
    required String currency,
    String? phone,
  }) async {
    final message = '''
🏪 *$storeName*
─────────────────
مرحباً *$customerName* 👋

✅ تم استلام طلبكم بنجاح!

💰 *الإجمالي:* ${total.toStringAsFixed(2)} $currency

سيتم التواصل معكم قريباً 📞

شكراً لثقتكم بنا 🙏
    ''';

    await _openWhatsApp(phone: phone, message: message.trim());
  }

  // ==================== فتح واتساب ====================
  static Future<void> _openWhatsApp({String? phone, required String message}) async {
    final encodedMsg = Uri.encodeComponent(message);
    String urlStr;

    if (phone != null && phone.isNotEmpty) {
      // تنظيف رقم الهاتف
      final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final fullPhone = cleanPhone.startsWith('+') ? cleanPhone : '+2$cleanPhone';
      urlStr = 'https://wa.me/$fullPhone?text=$encodedMsg';
    } else {
      // فتح واتساب بدون رقم محدد (المستخدم يختار)
      urlStr = 'https://wa.me/?text=$encodedMsg';
    }

    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}
