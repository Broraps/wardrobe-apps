import 'package:flutter/material.dart';

/// Utility bersama untuk menebak season pakaian dari warnanya.
/// Logika HSV Rule-Based — dipakai di AddItemPage, CatalogPage, dll.
///
/// Aturan:
/// - Warm (Hue 0-50, 330-360) + Gelap/Muted → Autumn
/// - Warm + Cerah → Spring
/// - Cool (Hue 150-270) + Gelap/Kontras → Winter
/// - Cool + Cerah → Summer
/// - Default fallback → Winter
String guessSeasonFromColor(Color color) {
  final HSVColor hsv = HSVColor.fromColor(color);
  final double hue = hsv.hue;
  final double saturation = hsv.saturation;
  final double value = hsv.value;

  bool isWarm =
      (hue >= 0 && hue < 50) || (hue > 330 && hue <= 360); // Merah, Oranye, Kuning
  bool isCool = (hue >= 150 && hue <= 270); // Biru, Ungu, Cyan

  if (isWarm) {
    // Jika Warm & Gelap/Muted -> Autumn
    if (value < 0.6 || saturation < 0.6) return 'Autumn';
    // Jika Warm & Terang/Cerah -> Spring
    return 'Spring';
  } else if (isCool) {
    // Jika Cool & Gelap/Kontras -> Winter
    if (value < 0.4 || saturation > 0.8) return 'Winter';
    // Sisanya Summer
    return 'Summer';
  }

  // Default fallback
  return 'Winter';
}
