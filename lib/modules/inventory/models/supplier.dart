class Supplier {
  final int? id;
  final String companyName;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final String? logoPath;
  final double balance;

  Supplier({
    this.id,
    required this.companyName,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.logoPath,
    this.balance = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'company_name': companyName,
        'contact_person': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'logo_path': logoPath,
        'balance': balance,
      };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'] as int?,
        companyName: map['company_name'] as String,
        contactPerson: map['contact_person'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        notes: map['notes'] as String?,
        logoPath: map['logo_path'] as String?,
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
      );
}
