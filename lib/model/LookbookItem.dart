class LookbookItem {
  final String id;
  final String name;
  final String imagePath; // path lokal file PNG screenshot canvas
  final DateTime createdAt;
  final DateTime? scheduledDate; // tanggal rencana pemakaian (opsional)
  final List<String> itemIds; // ID ClothingItem yang dipakai di canvas

  LookbookItem({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.createdAt,
    this.scheduledDate,
    this.itemIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'scheduledDate': scheduledDate?.toIso8601String(),
      'itemIds': itemIds,
    };
  }

  factory LookbookItem.fromJson(Map<String, dynamic> json) {
    return LookbookItem(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'] as String)
          : null,
      itemIds: List<String>.from(json['itemIds'] ?? []),
    );
  }
}
