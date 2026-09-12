import '../../inventory/models/product.dart';

/// نوع عنصر السلة: صنف حقيقي من المخزون، صنف يدوي غير مسجل بالمخزون،
/// أو خدمة (زي التوصيل) - الاتنين الأخيرين ملهمش تأثير على المخزون.
enum CartItemType { product, manual, service }

/// عنصر في سلة البيع الحالية على شاشة الكاشير
/// (ده كائن مؤقت في الذاكرة، مش جدول في قاعدة البيانات)
class CartItem {
  final Product? product;
  final CartItemType type;
  final String manualName;
  double quantity;
  double unitPrice;

  CartItem({required Product this.product, this.quantity = 1})
      : type = CartItemType.product,
        manualName = '',
        unitPrice = product.salePrice;

  CartItem.manual({required String name, required double price, this.quantity = 1})
      : product = null,
        type = CartItemType.manual,
        manualName = name,
        unitPrice = price;

  CartItem.service({required String name, required double price, this.quantity = 1})
      : product = null,
        type = CartItemType.service,
        manualName = name,
        unitPrice = price;

  String get displayName => type == CartItemType.product ? product!.name : manualName;

  double get lineTotal => unitPrice * quantity;
}
