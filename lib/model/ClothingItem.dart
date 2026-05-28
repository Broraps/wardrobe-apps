import 'dart:ui';

class ClothingItem {
  final String id;
  final String name;
  final String category;
  final Color color;
  final String imageUrl;
  final String season;
  final bool isLocal; // true = upload manual, false = dari cloud Supabase

  ClothingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.imageUrl,
    required this.season,
    this.isLocal = false,
  });

  /// Parse hex color string yang mungkin berbentuk '0xFFAABBCC' atau 'FFAABBCC'
  static Color _parseHexColor(String hex) {
    String cleaned = hex.replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
    return Color(int.parse(cleaned, radix: 16));
  }

  // Factory: dari JSON Supabase (selalu cloud)
  factory ClothingItem.fromJson(Map<String, dynamic> json) {
    return ClothingItem(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      color: _parseHexColor(json['hex_color'].toString()),
      imageUrl: json['image_url'],
      season: json['season'] ?? 'Unknown',
      isLocal: false,
    );
  }

  // Factory: dari JSON SharedPreferences (selalu lokal)
  factory ClothingItem.fromLocalJson(Map<String, dynamic> json) {
    return ClothingItem(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      color: _parseHexColor(json['hex_color'].toString()),
      imageUrl: json['image_url'],
      season: json['season'] ?? 'Unknown',
      isLocal: true,
    );
  }

  // Konversi ke Map untuk disimpan di SharedPreferences
  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'hex_color': '0x${color.toARGB32().toRadixString(16).toUpperCase()}',
      'image_url': imageUrl,
      'season': season,
    };
  }
}
