/// بيولّد باركود EAN-13 صحيح رياضيًا للاستخدام الداخلي
/// النطاق 20-29 محجوز عالميًا للاستخدام الداخلي لمحلات التجزئة
/// فمستحيل يتعارض مع أي باركود حقيقي من شركة مصنّعة
class BarcodeGenerator {
  /// بيولّد باركود مبني على رقم الصنف الداخلي (فريد تلقائيًا لأن الـ id فريد)
  static String generateForProductId(int productId) {
    // "20" + 10 أرقام من رقم الصنف (padded بأصفار) = 12 رقم
    final paddedId = productId.toString().padLeft(10, '0');
    final first12Digits = '20$paddedId';
    final checkDigit = _calculateEan13CheckDigit(first12Digits);
    return '$first12Digits$checkDigit';
  }

  /// خوارزمية رقم التحقق القياسية لباركود EAN-13
  static int _calculateEan13CheckDigit(String digits12) {
    int sum = 0;
    for (int i = 0; i < digits12.length; i++) {
      final digit = int.parse(digits12[i]);
      // الأرقام في المواضع الفردية (0-indexed: 0,2,4...) تتضرب في 1
      // والأرقام في المواضع الزوجية (1,3,5...) تتضرب في 3
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    final remainder = sum % 10;
    return remainder == 0 ? 0 : 10 - remainder;
  }
}
