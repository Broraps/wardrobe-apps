import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk menyimpan & mengambil profil warna musim user.
/// Data disimpan di SharedPreferences (lokal device).
class ProfileService {
  static const _key = 'user_color_profile';

  /// Ambil profil yang tersimpan (null jika belum pernah analisis)
  Future<UserColorProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    return UserColorProfile.fromJson(
      jsonDecode(jsonStr) as Map<String, dynamic>,
    );
  }

  /// Simpan hasil analisis profil
  Future<void> saveProfile(UserColorProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  /// Hapus profil (reset)
  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Model data profil warna musim user
class UserColorProfile {
  final String season; // 'Winter', 'Summer', 'Spring', 'Autumn'
  final String undertone; // 'Warm', 'Cool'
  final String brightness; // 'Light', 'Deep'
  final int skinColorValue; // ARGB int dari warna kulit terdeteksi
  final String selfiePath; // path foto selfie
  final DateTime analyzedAt;

  UserColorProfile({
    required this.season,
    required this.undertone,
    required this.brightness,
    required this.skinColorValue,
    required this.selfiePath,
    required this.analyzedAt,
  });

  Color get skinColor => Color(skinColorValue);

  Map<String, dynamic> toJson() => {
        'season': season,
        'undertone': undertone,
        'brightness': brightness,
        'skinColorValue': skinColorValue,
        'selfiePath': selfiePath,
        'analyzedAt': analyzedAt.toIso8601String(),
      };

  factory UserColorProfile.fromJson(Map<String, dynamic> json) {
    return UserColorProfile(
      season: json['season'] as String,
      undertone: json['undertone'] as String,
      brightness: json['brightness'] as String,
      skinColorValue: json['skinColorValue'] as int,
      selfiePath: json['selfiePath'] as String,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
    );
  }

  /// Deteksi profil warna musim dari warna kulit (HSV Rule-Based).
  /// Menggunakan logika yang sama persis dengan _guessSeasonFromColor di AddItemPage.
  static UserColorProfile analyzeFromSkinColor({
    required Color skinColor,
    required String selfiePath,
  }) {
    final hsv = HSVColor.fromColor(skinColor);
    final double hue = hsv.hue;
    final double saturation = hsv.saturation;
    final double value = hsv.value;

    // Deteksi Undertone: Warm vs Cool
    // Warm: Merah, Oranye, Kuning (0-50, 330-360)
    // Cool: Biru, Ungu, Cyan (150-270)
    // Netral/skin-toned: sisanya (50-150, 270-330)
    bool isWarm =
        (hue >= 0 && hue < 50) || (hue > 330 && hue <= 360);
    bool isCool = (hue >= 150 && hue <= 270);

    // Untuk warna kulit, hue biasanya di range warm (10-40)
    // atau netral. Jika di area netral, tentukan dari saturation.
    if (!isWarm && !isCool) {
      // Area netral (50-150 atau 270-330)
      // Skin tone biasanya jatuh di sini (hue ~10-45 untuk kulit)
      // Gunakan saturation sebagai penentu:
      // Saturation tinggi -> Warm, Saturation rendah -> Cool
      isWarm = saturation >= 0.3;
      isCool = !isWarm;
    }

    String undertone = isWarm ? 'Warm' : 'Cool';

    // Deteksi Kecerahan: Light vs Deep
    // Value tinggi (cerah) vs value rendah (gelap)
    bool isLight = value >= 0.6;
    String brightness = isLight ? 'Light' : 'Deep';

    // Tentukan Season berdasarkan kombinasi
    String season;
    if (isWarm) {
      if (isLight) {
        // Kulit Cerah & Warm -> Spring
        season = 'Spring';
      } else {
        // Kulit Gelap & Warm -> Autumn
        season = 'Autumn';
      }
    } else {
      // Cool
      if (isLight) {
        // Kulit Cerah & Cool -> Summer
        season = 'Summer';
      } else {
        // Kulit Gelap/Kontras & Cool -> Winter
        season = 'Winter';
      }
    }

    return UserColorProfile(
      season: season,
      undertone: undertone,
      brightness: brightness,
      skinColorValue: skinColor.toARGB32(),
      selfiePath: selfiePath,
      analyzedAt: DateTime.now(),
    );
  }
}
