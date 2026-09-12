class ConnectedDevice {
  final int? id;
  final String name;
  final String type; // printer / customer_display / scanner / other
  final String connectionType; // bluetooth / wifi / usb
  final String? address; // MAC أو IP حسب نوع الاتصال
  final bool isDefault;
  final String status; // connected / disconnected / unknown / error
  final String? lastCheckedAt;
  final String? notes;
  final String createdAt;

  ConnectedDevice({
    this.id,
    required this.name,
    this.type = 'printer',
    this.connectionType = 'bluetooth',
    this.address,
    this.isDefault = false,
    this.status = 'unknown',
    this.lastCheckedAt,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type,
        'connection_type': connectionType,
        'address': address,
        'is_default': isDefault ? 1 : 0,
        'status': status,
        'last_checked_at': lastCheckedAt,
        'notes': notes,
        'created_at': createdAt,
      };

  factory ConnectedDevice.fromMap(Map<String, dynamic> map) => ConnectedDevice(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: (map['type'] as String?) ?? 'printer',
        connectionType: (map['connection_type'] as String?) ?? 'bluetooth',
        address: map['address'] as String?,
        isDefault: (map['is_default'] as int? ?? 0) == 1,
        status: (map['status'] as String?) ?? 'unknown',
        lastCheckedAt: map['last_checked_at'] as String?,
        notes: map['notes'] as String?,
        createdAt: map['created_at'] as String,
      );
}
