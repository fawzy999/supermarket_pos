import 'package:url_launcher/url_launcher.dart';

/// أداة عامة لفتح محادثة واتساب مباشرة مع رقم معين مع نص جاهز -
/// مفيدة لإرسال تذكيرات، طلبات شراء، أو ملخصات تقارير نصية بدون
/// أي حساب/API رسمي، بتستخدم رابط wa.me العادي اللي بيفتح تطبيق
/// واتساب المثبت على الجهاز.
///
/// ملحوظة مهمة: رابط wa.me بيفتح محادثة بنص جاهز بس، مش بيقدر
/// يرفق ملف (PDF/صورة) تلقائيًا - ده قيد من واتساب نفسه مش من
/// التطبيق. عشان ترفق ملف (سند/فاتورة/تقرير) على واتساب، استخدم
/// زرار "مشاركة" العادي في نفس الشاشة واختار واتساب من قائمة
/// المشاركة اللي هتظهر - وقتها هيتفتح واتساب مع الملف مرفق جاهز
/// تختار له المستلم.
class WhatsAppHelper {
  /// بيحول رقم متخزن بالشكل المصري المحلي (01xxxxxxxxx) لصيغة دولية
  /// من غير علامة + (زي ما واتساب محتاج) - لو الرقم مكتوب أصلًا
  /// بصيغة دولية بيسيبه زي ما هو.
  static String normalizePhone(String phone) {
    var p = phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (p.isEmpty) return p;
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('00')) p = p.substring(2);
    // رقم مصري محلي بيبدأ بصفر (01xxxxxxxxx) - نبدله بكود مصر الدولي
    if (p.startsWith('0')) p = '2${p.substring(1)}';
    return p;
  }

  /// بيفتح محادثة واتساب مباشرة مع الرقم ده، مع نص جاهز لو اتبعت.
  /// بيرجع false لو مفيش واتساب متثبت أو الرابط فشل يتفتح.
  static Future<bool> openChat({required String phone, String? text}) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return false;
    final uri = Uri.https('wa.me', '/$normalized', text != null && text.isNotEmpty ? {'text': text} : null);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
