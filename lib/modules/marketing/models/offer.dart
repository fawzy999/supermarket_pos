/// عرض تسويقي بيتحفظ في التطبيق عشان يتشارك بسهولة على واتساب أو
/// السوشيال ميديا - عنوان، وصف، وصورة اختيارية.
class Offer {
  final int? id;
  final String title;
  final String? description;
  final String? imagePath;
  final String createdAt;

  const Offer({
    this.id,
    required this.title,
    this.description,
    this.imagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'image_path': imagePath,
        'created_at': createdAt,
      };

  factory Offer.fromMap(Map<String, dynamic> map) => Offer(
        id: map['id'] as int?,
        title: map['title'] as String,
        description: map['description'] as String?,
        imagePath: map['image_path'] as String?,
        createdAt: map['created_at'] as String,
      );
}
