class Sale {
  final int? id;
  final int? userId;
  final String date;
  final double totalAmount;
  final String paymentMethod;
  final String? customerName;
  final String? customerPhone;
  final int? customerId;
  final double subtotalAmount;
  final double discountPercent;
  final double discountAmount;
  final int? repId; // لو الفاتورة اتسجلت "حساب مندوب" - المندوب المرتبط بها

  Sale({
    this.id,
    this.userId,
    required this.date,
    required this.totalAmount,
    required this.paymentMethod,
    this.customerName,
    this.customerPhone,
    this.customerId,
    double? subtotalAmount,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.repId,
  }) : subtotalAmount = subtotalAmount ?? totalAmount;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'date': date,
        'total_amount': totalAmount,
        'payment_method': paymentMethod,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_id': customerId,
        'subtotal_amount': subtotalAmount,
        'discount_percent': discountPercent,
        'discount_amount': discountAmount,
        'rep_id': repId,
      };

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'] as int?,
        userId: map['user_id'] as int?,
        date: map['date'] as String,
        totalAmount: (map['total_amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String,
        customerName: map['customer_name'] as String?,
        customerPhone: map['customer_phone'] as String?,
        customerId: map['customer_id'] as int?,
        subtotalAmount: (map['subtotal_amount'] as num?)?.toDouble(),
        discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
        discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
        repId: map['rep_id'] as int?,
      );
}
