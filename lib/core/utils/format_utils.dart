/// بيعرض الكمية كرقم صحيح لو مافيهاش كسور (زي ما كان بالظبط)، أو
/// بأقصى منزلتين عشريتين لو فيها كسر (0.5 كجم، 1.25 لتر، إلخ) - مستخدمة
/// في كل شاشات عرض الفاتورة والسلة والـ PDF عشان تدعم البيع بالكسور
/// (منتجات الوزن زي الجبنة والطحينة).
String formatQuantity(num quantity) {
  if (quantity == quantity.roundToDouble()) return quantity.toStringAsFixed(0);
  return quantity
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
