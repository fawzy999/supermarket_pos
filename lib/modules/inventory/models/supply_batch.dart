class SupplyBatch {
  final int? id;
  final int productId;
  final int? supplierId;
  final double quantityReceived;
  final double remainingQuantity;
  final String supplyDate;
  final String? expiryDate;
  final String? receivedBy;
  final String? notes;
  final String? invoiceImagePath;
  final String? receiptImagePath;

  SupplyBatch({
    this.id,
    required this.productId,
    this.supplierId,
    required this.quantityReceived,
    required this.remainingQuantity,
    required this.supplyDate,
    this.expiryDate,
    this.receivedBy,
    this.notes,
    this.invoiceImagePath,
    this.receiptImagePath,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'supplier_id': supplierId,
        'quantity_received': quantityReceived,
        'remaining_quantity': remainingQuantity,
        'supply_date': supplyDate,
        'expiry_date': expiryDate,
        'received_by': receivedBy,
        'notes': notes,
        'invoice_image_path': invoiceImagePath,
        'receipt_image_path': receiptImagePath,
      };

  factory SupplyBatch.fromMap(Map<String, dynamic> map) => SupplyBatch(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        supplierId: map['supplier_id'] as int?,
        quantityReceived: (map['quantity_received'] as num).toDouble(),
        remainingQuantity: (map['remaining_quantity'] as num).toDouble(),
        supplyDate: map['supply_date'] as String,
        expiryDate: map['expiry_date'] as String?,
        receivedBy: map['received_by'] as String?,
        notes: map['notes'] as String?,
        invoiceImagePath: map['invoice_image_path'] as String?,
        receiptImagePath: map['receipt_image_path'] as String?,
      );
}
