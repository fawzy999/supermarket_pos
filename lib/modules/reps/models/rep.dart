class Rep {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? nationalId;
  final String? address;
  final String? photoPath;
  final String? notes;
  final bool active;
  final String createdAt;

  Rep({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.nationalId,
    this.address,
    this.photoPath,
    this.notes,
    this.active = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'national_id': nationalId,
        'address': address,
        'photo_path': photoPath,
        'notes': notes,
        'active': active ? 1 : 0,
        'created_at': createdAt,
      };

  factory Rep.fromMap(Map<String, dynamic> map) => Rep(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        nationalId: map['national_id'] as String?,
        address: map['address'] as String?,
        photoPath: map['photo_path'] as String?,
        notes: map['notes'] as String?,
        active: (map['active'] as int) == 1,
        createdAt: map['created_at'] as String,
      );
}
