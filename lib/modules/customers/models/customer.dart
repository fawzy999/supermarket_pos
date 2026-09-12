class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final double balance; // موجب = العميل مديون للمحل (بيع آجل لسه ماتحصلش)
  final int loyaltyPoints;
  final String createdAt;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    this.balance = 0,
    this.loyaltyPoints = 0,
    required this.createdAt,
  });

  bool get hasDebt => balance > 0;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
        'balance': balance,
        'loyalty_points': loyaltyPoints,
        'created_at': createdAt,
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        address: map['address'] as String?,
        notes: map['notes'] as String?,
        balance: (map['balance'] as num).toDouble(),
        loyaltyPoints: (map['loyalty_points'] as num?)?.toInt() ?? 0,
        createdAt: map['created_at'] as String,
      );
}
