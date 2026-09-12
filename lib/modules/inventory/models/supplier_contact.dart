/// شخص تواصل عند المورد (مندوب مبيعات، محاسب، مسؤول شحن...) - المورد
/// الواحد ممكن يكون ليه أكتر من شخص متسجل.
class SupplierContact {
  final int? id;
  final int supplierId;
  final String name;
  final String? role;
  final String? phone;
  final String? email;
  final String? notes;

  SupplierContact({
    this.id,
    required this.supplierId,
    required this.name,
    this.role,
    this.phone,
    this.email,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'supplier_id': supplierId,
        'name': name,
        'role': role,
        'phone': phone,
        'email': email,
        'notes': notes,
      };

  factory SupplierContact.fromMap(Map<String, dynamic> map) => SupplierContact(
        id: map['id'] as int?,
        supplierId: map['supplier_id'] as int,
        name: map['name'] as String,
        role: map['role'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        notes: map['notes'] as String?,
      );
}
