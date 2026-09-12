class Shift {
  final int? id;
  final int userId;
  final String loginTime;
  final String? logoutTime;
  final int? invoiceCount;
  final double? cashTotal;
  final double? cardTotal;
  final double? totalAmount;
  final int? confirmedBy;
  final String? confirmedAt;
  final double? receivedAmount;

  Shift({
    this.id,
    required this.userId,
    required this.loginTime,
    this.logoutTime,
    this.invoiceCount,
    this.cashTotal,
    this.cardTotal,
    this.totalAmount,
    this.confirmedBy,
    this.confirmedAt,
    this.receivedAmount,
  });

  bool get isConfirmed => confirmedBy != null;
  bool get isOpen => logoutTime == null;

  factory Shift.fromMap(Map<String, dynamic> map) => Shift(
        id: map['id'] as int?,
        userId: map['user_id'] as int,
        loginTime: map['login_time'] as String,
        logoutTime: map['logout_time'] as String?,
        invoiceCount: map['invoice_count'] as int?,
        cashTotal: (map['cash_total'] as num?)?.toDouble(),
        cardTotal: (map['card_total'] as num?)?.toDouble(),
        totalAmount: (map['total_amount'] as num?)?.toDouble(),
        confirmedBy: map['confirmed_by'] as int?,
        confirmedAt: map['confirmed_at'] as String?,
        receivedAmount: (map['received_amount'] as num?)?.toDouble(),
      );
}
