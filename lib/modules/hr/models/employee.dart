class Employee {
  final int? id;
  final String name;
  final String? phone;
  final String? nationalId;
  final String? address;
  final String? position; // الوظيفة
  final String? qualification; // المؤهل
  final String salaryType; // monthly / daily
  final double baseSalary; // مرتب شهري أو يومية
  final String? hireDate;
  final String? photoPath;
  final String? nationalIdImagePath;
  final String? qualificationDocPath;
  final String? addressProofPath;
  final String? contractDocPath;
  final String? notes;
  final bool active;
  final String createdAt;

  Employee({
    this.id,
    required this.name,
    this.phone,
    this.nationalId,
    this.address,
    this.position,
    this.qualification,
    this.salaryType = 'monthly',
    this.baseSalary = 0,
    this.hireDate,
    this.photoPath,
    this.nationalIdImagePath,
    this.qualificationDocPath,
    this.addressProofPath,
    this.contractDocPath,
    this.notes,
    this.active = true,
    required this.createdAt,
  });

  bool get isMonthly => salaryType == 'monthly';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'national_id': nationalId,
        'address': address,
        'position': position,
        'qualification': qualification,
        'salary_type': salaryType,
        'base_salary': baseSalary,
        'hire_date': hireDate,
        'photo_path': photoPath,
        'national_id_image_path': nationalIdImagePath,
        'qualification_doc_path': qualificationDocPath,
        'address_proof_path': addressProofPath,
        'contract_doc_path': contractDocPath,
        'notes': notes,
        'active': active ? 1 : 0,
        'created_at': createdAt,
      };

  factory Employee.fromMap(Map<String, dynamic> map) => Employee(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        nationalId: map['national_id'] as String?,
        address: map['address'] as String?,
        position: map['position'] as String?,
        qualification: map['qualification'] as String?,
        salaryType: (map['salary_type'] as String?) ?? 'monthly',
        baseSalary: (map['base_salary'] as num?)?.toDouble() ?? 0,
        hireDate: map['hire_date'] as String?,
        photoPath: map['photo_path'] as String?,
        nationalIdImagePath: map['national_id_image_path'] as String?,
        qualificationDocPath: map['qualification_doc_path'] as String?,
        addressProofPath: map['address_proof_path'] as String?,
        contractDocPath: map['contract_doc_path'] as String?,
        notes: map['notes'] as String?,
        active: (map['active'] as int) == 1,
        createdAt: map['created_at'] as String,
      );
}
