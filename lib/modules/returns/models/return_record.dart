class ReturnRecord {
  final int? id;
  final String type; // 'customer' or 'supplier'
  final int productId;
  final double quantity;
  final double? unitPrice;
  final int? referenceSaleId;
  final int? supplierId;
  final int? batchId;
  final String? reason;
  final String date;
  final String? processedBy;

  ReturnRecord({
    this.id,
    required this.type,
    required this.productId,
    required this.quantity,
    this.unitPrice,
    this.referenceSaleId,
    this.supplierId,
    this.batchId,
    this.reason,
    required this.date,
    this.processedBy,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'type': type,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'reference_sale_id': referenceSaleId,
        'supplier_id': supplierId,
        'batch_id': batchId,
        'reason': reason,
        'date': date,
        'processed_by': processedBy,
      };

  factory ReturnRecord.fromMap(Map<String, dynamic> map) => ReturnRecord(
        id: map['id'] as int?,
        type: map['type'] as String,
        productId: map['product_id'] as int,
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num?)?.toDouble(),
        referenceSaleId: map['reference_sale_id'] as int?,
        supplierId: map['supplier_id'] as int?,
        batchId: map['batch_id'] as int?,
        reason: map['reason'] as String?,
        date: map['date'] as String,
        processedBy: map['processed_by'] as String?,
      );
}
