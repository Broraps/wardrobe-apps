import 'package:flutter/material.dart';
import 'dart:math';
import '../model/ClothingItem.dart';

// Class untuk menampung hasil acakan
class OutfitResult {
  final ClothingItem top;
  final ClothingItem bottom;
  final ClothingItem? outer;
  final ClothingItem? shoes;
  final bool isPerfectMatch; // True jika sesuai dengan Season Kulit User

  OutfitResult({
    required this.top,
    required this.bottom,
    this.outer,
    this.shoes,
    required this.isPerfectMatch,
  });
}

class SmartStylistService {
  final Random _random = Random();

  // 1. RUMUS MATEMATIKA: Cek Harmoni 2 Warna (HSV Distance)
  bool isColorHarmonious(Color color1, Color color2) {
    HSVColor hsv1 = HSVColor.fromColor(color1);
    HSVColor hsv2 = HSVColor.fromColor(color2);

    // Aturan 1: Cek apakah salah satu warna adalah Netral (Hitam/Putih/Abu)
    // Saturasi rendah (< 15%) atau Value sangat gelap (< 20%) / terang (> 90%)
    bool isNeutral(HSVColor hsv) {
      return hsv.saturation < 0.15 || hsv.value < 0.2 || hsv.value > 0.9;
    }

    if (isNeutral(hsv1) || isNeutral(hsv2)) {
      return true; // Netral selalu cocok dengan warna apa saja
    }

    // Aturan 2: Hitung Jarak Sudut Hue (Warna)
    double hueDiff = (hsv1.hue - hsv2.hue).abs();
    if (hueDiff > 180) {
      hueDiff = 360 - hueDiff; // Normalisasi jarak terpendek
    }

    // Toleransi Analogous (Warna Senada/Mirip) -> Jarak <= 35 derajat
    if (hueDiff <= 35) return true;

    // Toleransi Complementary (Warna Kontras) -> Jarak >= 150 derajat
    if (hueDiff >= 150) return true;

    return false; // Tabrak lari (Tidak harmonis)
  }

  // 2. FUNGSI UTAMA: Generate Outfit (The Smart Randomizer)
  OutfitResult? rollOutfit(
    List<ClothingItem> wardrobe,
    String userSeason,
    bool includeOuter,
  ) {
    // Pisahkan baju berdasarkan kategori
    List<ClothingItem> tops = wardrobe
        .where((i) => i.category == 'Top')
        .toList();
    List<ClothingItem> bottoms = wardrobe
        .where((i) => i.category == 'Bottom')
        .toList();
    List<ClothingItem> outers = wardrobe
        .where((i) => i.category == 'Outer')
        .toList();
    List<ClothingItem> shoes = wardrobe
        .where((i) => i.category == 'Shoes')
        .toList();

    // Jika atasan atau bawahan kosong, batalkan
    if (tops.isEmpty || bottoms.isEmpty) return null;

    // STEP 1: Acak 1 Atasan sebagai Patokan (Anchor)
    ClothingItem selectedTop = tops[_random.nextInt(tops.length)];

    // STEP 2: Cari Bawahan yang HARMONIS dengan Atasan
    List<ClothingItem> matchingBottoms = bottoms.where((bottom) {
      return isColorHarmonious(selectedTop.color, bottom.color);
    }).toList();

    // Jika tidak ada bawahan yang harmonis, ambil sembarang (Fallback)
    ClothingItem selectedBottom;
    if (matchingBottoms.isNotEmpty) {
      selectedBottom = matchingBottoms[_random.nextInt(matchingBottoms.length)];
    } else {
      selectedBottom = bottoms[_random.nextInt(bottoms.length)];
    }

    // STEP 3: Cari Outer & Sepatu (Opsional, logika sama)
    ClothingItem? selectedOuter;
    if (includeOuter && outers.isNotEmpty) {
      List<ClothingItem> matchingOuters = outers
          .where((o) => isColorHarmonious(selectedTop.color, o.color))
          .toList();
      selectedOuter = matchingOuters.isNotEmpty
          ? matchingOuters[_random.nextInt(matchingOuters.length)]
          : outers[_random.nextInt(outers.length)];
    }

    ClothingItem? selectedShoes;
    if (shoes.isNotEmpty) {
      // Sepatu disamakan harmoninya dengan celana
      List<ClothingItem> matchingShoes = shoes
          .where((s) => isColorHarmonious(selectedBottom.color, s.color))
          .toList();
      selectedShoes = matchingShoes.isNotEmpty
          ? matchingShoes[_random.nextInt(matchingShoes.length)]
          : shoes[_random.nextInt(shoes.length)];
    }

    // STEP 4: SOFT CONSTRAINT (Cek apakah sesuai dengan kulit User)
    // Jika baju dan celana masuk ke dalam kategori Season user, beri nilai TRUE
    bool isSeasonMatch =
        (selectedTop.season == userSeason) ||
        (selectedBottom.season == userSeason);

    return OutfitResult(
      top: selectedTop,
      bottom: selectedBottom,
      outer: selectedOuter,
      shoes: selectedShoes,
      isPerfectMatch: isSeasonMatch, // Ini yang akan memicu Popup/Badge nanti!
    );
  }
}
