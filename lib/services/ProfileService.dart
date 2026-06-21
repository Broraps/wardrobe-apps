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

/// Model data profil warna musim user — berdasarkan Seasonal Color Theory
/// dengan 3 input: nuansa kulit, warna rambut, warna mata.
class UserColorProfile {
  final String season; // 'Winter', 'Summer', 'Spring', 'Autumn'
  final String undertone; // 'Warm', 'Cool'
  final String brightness; // 'Light', 'Deep'
  final int skinColorValue; // ARGB int dari warna kulit
  final int hairColorValue; // ARGB int dari warna rambut
  final int eyeColorValue; // ARGB int dari warna mata
  final String selfiePath; // path foto selfie
  final DateTime analyzedAt;

  UserColorProfile({
    required this.season,
    required this.undertone,
    required this.brightness,
    required this.skinColorValue,
    required this.hairColorValue,
    required this.eyeColorValue,
    required this.selfiePath,
    required this.analyzedAt,
  });

  Color get skinColor => Color(skinColorValue);
  Color get hairColor => Color(hairColorValue);
  Color get eyeColor => Color(eyeColorValue);

  Map<String, dynamic> toJson() => {
    'season': season,
    'undertone': undertone,
    'brightness': brightness,
    'skinColorValue': skinColorValue,
    'hairColorValue': hairColorValue,
    'eyeColorValue': eyeColorValue,
    'selfiePath': selfiePath,
    'analyzedAt': analyzedAt.toIso8601String(),
  };

  factory UserColorProfile.fromJson(Map<String, dynamic> json) {
    return UserColorProfile(
      season: json['season'] as String,
      undertone: json['undertone'] as String,
      brightness: json['brightness'] as String,
      skinColorValue: json['skinColorValue'] as int,
      // Backward-compat: data lama belum punya hairColorValue/eyeColorValue
      hairColorValue: (json['hairColorValue'] as int?) ?? 0xFF808080,
      eyeColorValue: (json['eyeColorValue'] as int?) ?? 0xFF808080,
      selfiePath: json['selfiePath'] as String,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SEASONAL COLOR THEORY ANALYSIS — 3-Input Algorithm
  // ═══════════════════════════════════════════════════════════════════════
  //
  // Berdasarkan Seasonal Color Theory:
  //   - UNDERTONE ditentukan oleh kombinasi warna kulit (50%), rambut (25%), mata (25%)
  //   - KECERAHAN ditentukan oleh Value rata-rata kulit
  //   - Warm + Light → Spring  |  Warm + Deep → Autumn
  //   - Cool + Light → Summer  |  Cool + Deep → Winter
  //
  // Referensi: teori 4-Season Color Analysis (Carole Jackson, 1980)
  // ═══════════════════════════════════════════════════════════════════════

  static UserColorProfile analyzeFromColors({
    required Color skinColor,
    required Color hairColor,
    required Color eyeColor,
    required String selfiePath,
    double skinWeight = 0.50,
    double hairWeight = 0.25,
    double eyeWeight = 0.25,
  }) {
    // ── 1. Hitung warmth score per komponen (0.0 = Cool, 1.0 = Warm) ──

    final skinWarmth = _warmthScore(skinColor);
    final hairWarmth = _warmthScore(hairColor);
    final eyeWarmth = _warmthScore(eyeColor);

    // Bobot: ditentukan oleh parameter (default: Kulit 50%, Rambut 25%, Mata 25%)
    final totalWarmth =
        (skinWarmth * skinWeight) + (hairWarmth * hairWeight) + (eyeWarmth * eyeWeight);

    // Threshold: > 0.5 = Warm, <= 0.5 = Cool
    final bool isWarm = totalWarmth > 0.5;
    final String undertone = isWarm ? 'Warm' : 'Cool';

    // ── 2. Deteksi Kecerahan dari kulit ──

    final skinHsv = HSVColor.fromColor(skinColor);
    final hairHsv = HSVColor.fromColor(hairColor);
    final eyeHsv = HSVColor.fromColor(eyeColor);

    // A. Kecerahan (Brightness): Rata-rata dari Value ketiga elemen
    // Jika rata-rata Value tinggi, berarti secara keseluruhan orang tersebut "Light"
    final double avgBrightness =
        (skinHsv.value + hairHsv.value + eyeHsv.value) / 3.0;

    // B. Tingkat Kontras: Seberapa beda kecerahan kulit terhadap rambut dan mata
    // Kontras tinggi biasanya rambut gelap (value rendah) + kulit terang (value tinggi)
    final double contrast =
        (skinHsv.value - hairHsv.value).abs() +
        (skinHsv.value - eyeHsv.value).abs();

    // Threshold (Nilai Batas Heuristik)
    // Jika cukup terang secara rata-rata, ATAU kontrasnya sangat rendah (pudar) -> Light
    // Jika rata-rata gelap, ATAU kontrasnya sangat tinggi (tajam) -> Deep
    final bool isLight = (avgBrightness >= 0.55) && (contrast < 0.85);
    final String brightness = isLight ? 'Light' : 'Deep';

    // ── 3. Tentukan Season ──

    String season;
    if (isWarm) {
      // Warm + Light/Low Contrast = Spring
      // Warm + Deep/High Contrast = Autumn
      season = isLight ? 'Spring' : 'Autumn';
    } else {
      // Cool + Light/Low Contrast = Summer
      // Cool + Deep/High Contrast = Winter
      season = isLight ? 'Summer' : 'Winter';
    }

    return UserColorProfile(
      season: season,
      undertone: undertone,
      brightness: brightness,
      skinColorValue: skinColor.toARGB32(),
      hairColorValue: hairColor.toARGB32(),
      eyeColorValue: eyeColor.toARGB32(),
      selfiePath: selfiePath,
      analyzedAt: DateTime.now(),
    );
  }

  /// Hitung "warmth score" sebuah warna (0.0 = sangat Cool, 1.0 = sangat Warm).
  ///
  /// Logika HSV:
  /// - Hue 0-60 atau 330-360 (merah/oranye/kuning) → Warm
  /// - Hue 150-270 (biru/ungu/cyan) → Cool
  /// - Area netral (60-150, 270-330) → tentukan dari saturation
  ///
  /// Warna netral (saturasi sangat rendah: hitam/putih/abu) → netral (0.5)
  static double _warmthScore(Color color) {
    final hsv = HSVColor.fromColor(color);
    final double hue = hsv.hue;
    final double saturation = hsv.saturation;
    final double value = hsv.value;

    // Warna hampir netral (abu-abu/hitam/putih) → score netral
    if (saturation < 0.10) return 0.5;
    if (value < 0.10) return 0.5; // Hitam pekat

    // Warm zones
    if ((hue >= 0 && hue < 60) || (hue > 330 && hue <= 360)) {
      // Semakin saturated dan semakin dekat ke 30° (oranye), semakin warm
      return 0.6 + (saturation * 0.4); // range 0.6 - 1.0
    }

    // Cool zones
    if (hue >= 150 && hue <= 270) {
      // Semakin saturated, semakin cool
      return 0.4 - (saturation * 0.4); // range 0.4 - 0.0
    }

    // Transisi zones (60-150 → kuning-hijau, 270-330 → ungu-merah)
    if (hue >= 60 && hue < 150) {
      // Hijau-kuning: transisi dari warm ke cool
      final t = (hue - 60) / 90; // 0 di hue=60, 1 di hue=150
      return 0.7 - (t * 0.4); // 0.7 → 0.3
    }

    // 270-330: ungu-merah muda
    final t = (hue - 270) / 60; // 0 di hue=270, 1 di hue=330
    return 0.3 + (t * 0.3); // 0.3 → 0.6
  }
}
