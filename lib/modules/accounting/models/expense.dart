class Expense {
  final int? id;
  final String description;
  final double amount;
  final String date;
  final String? receiptImagePath;

  Expense({
    this.id,
    required this.description,
    required this.amount,
    required this.date,
    this.receiptImagePath,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'description': description,
        'amount': amount,
        'date': date,
        'receipt_image_path': receiptImagePath,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as int?,
        description: map['description'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: map['date'] as String,
        receiptImagePath: map['receipt_image_path'] as String?,
      );
}
