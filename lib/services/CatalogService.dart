import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/ClothingItem.dart';

class CatalogService {
  final _supabase = Supabase.instance.client;
  static const _storageBucket = 'wardrobe_files';

  // SharedPreferences keys
  static const _galleryCloudIdsKey = 'gallery_cloud_ids';
  static const _galleryCloudMetaKey =
      'gallery_cloud_meta'; // metadata lengkap cloud items
  static const _localItemsKey = 'local_items';

  // ── 1. CLOUD: Mengambil data langsung dari TABEL catalog_items ─────────────────
  Future<List<ClothingItem>> fetchAllCloudItems() async {
    try {
      final List<dynamic> response = await _supabase
          .from('catalog_items')
          .select();

      return response.map((data) {
        // --- Helper internal: Parse Hex ke Color (Sangat Aman) ---
        String hexStr = data['hex_color']?.toString() ?? 'FFFFFF';

        // 1. Bersihkan semua simbol yang membuat Dart crash (#, 0x, atau 0X)
        hexStr = hexStr
            .replaceAll('#', '')
            .replaceAll('0x', '')
            .replaceAll('0X', '');

        // 2. Jika panjangnya 6 karakter (hanya RGB), tambahkan FF di depan untuk Alpha (Opacity 100%)
        if (hexStr.length == 6) {
          hexStr = 'FF$hexStr';
        }

        // 3. Coba parse warnanya. Gunakan blok try-catch agar tidak merusak seluruh halaman jika 1 item gagal
        Color parsedColor;
        try {
          parsedColor = Color(int.parse(hexStr, radix: 16));
        } catch (e) {
          debugPrint('Gagal parse warna untuk item ${data['name']}: $hexStr');
          parsedColor = Colors
              .grey
              .shade400; // Warna cadangan jika database kosong/format salah
        }
        // ----------------------------------------------------------

        // --- Helper internal: Kapitalisasi kategori ("top" menjadi "Top") ---
        String rawCategory = data['category'] ?? 'Cloud';
        String formattedCategory = rawCategory.isNotEmpty
            ? rawCategory[0].toUpperCase() +
                  rawCategory.substring(1).toLowerCase()
            : 'Cloud';
        // --------------------------------------------------------------------

        return ClothingItem(
          id: data['id'].toString(),
          name: data['name'] ?? 'Unnamed',
          category: formattedCategory,
          color: parsedColor,
          imageUrl: data['image_url'] ?? '',
          season: data['season'] ?? 'Unknown',
          isLocal: false,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching database catalog_items: $e');
      rethrow;
    }
  }

  // ── Helper: ambil public URL satu file ────────────────────────────────────
  String getPublicUrl(String fileName) {
    return _supabase.storage.from(_storageBucket).getPublicUrl(fileName);
  }

  // ── 2. GALLERY: Manajemen cloud items per device ──────────────────────────
  Future<Set<String>> getGalleryCloudIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_galleryCloudIdsKey) ?? []).toSet();
  }

  /// Simpan cloud item ke gallery DENGAN metadata lengkap (kategori, warna, season)
  Future<void> addCloudToGallery(
    String id, {
    required ClothingItem itemMeta,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Simpan ID
    final currentIds = (prefs.getStringList(_galleryCloudIdsKey) ?? []).toSet();
    currentIds.add(id);
    await prefs.setStringList(_galleryCloudIdsKey, currentIds.toList());
    // Simpan metadata lengkap
    final metaItems = await _getCloudMetaItems();
    metaItems.removeWhere((item) => item.id == id); // hindari duplikat
    metaItems.add(itemMeta);
    final encoded = jsonEncode(metaItems.map((e) => e.toLocalJson()).toList());
    await prefs.setString(_galleryCloudMetaKey, encoded);
  }

  Future<void> removeCloudFromGallery(String id) async {
    final prefs = await SharedPreferences.getInstance();
    // Hapus ID
    final currentIds = (prefs.getStringList(_galleryCloudIdsKey) ?? []).toSet();
    currentIds.remove(id);
    await prefs.setStringList(_galleryCloudIdsKey, currentIds.toList());
    // Hapus metadata
    final metaItems = await _getCloudMetaItems();
    metaItems.removeWhere((item) => item.id == id);
    final encoded = jsonEncode(metaItems.map((e) => e.toLocalJson()).toList());
    await prefs.setString(_galleryCloudMetaKey, encoded);
  }

  /// Ambil metadata cloud items yang sudah disimpan di gallery
  Future<List<ClothingItem>> _getCloudMetaItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_galleryCloudMetaKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((e) => ClothingItem.fromLocalJson(e as Map<String, dynamic>))
        .map(
          (item) => ClothingItem(
            id: item.id,
            name: item.name,
            category: item.category,
            color: item.color,
            imageUrl: item.imageUrl,
            season: item.season,
            isLocal: false, // tetap cloud
          ),
        )
        .toList();
  }

  /// Update metadata cloud item (misalnya setelah edit kategori)
  Future<void> updateCloudMeta(ClothingItem updatedItem) async {
    final prefs = await SharedPreferences.getInstance();
    final metaItems = await _getCloudMetaItems();
    final index = metaItems.indexWhere((item) => item.id == updatedItem.id);
    if (index == -1) return;
    metaItems[index] = updatedItem;
    final encoded = jsonEncode(metaItems.map((e) => e.toLocalJson()).toList());
    await prefs.setString(_galleryCloudMetaKey, encoded);
  }

  // ── 3. LOCAL ITEMS: Manajemen item lokal per device ───────────────────────
  Future<List<ClothingItem>> getLocalItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_localItemsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((e) => ClothingItem.fromLocalJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveLocalItem(ClothingItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getLocalItems();
    current.add(item);
    final encoded = jsonEncode(current.map((e) => e.toLocalJson()).toList());
    await prefs.setString(_localItemsKey, encoded);
  }

  Future<void> deleteLocalItem(String id, String localPath) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getLocalItems();
    current.removeWhere((item) => item.id == id);
    final encoded = jsonEncode(current.map((e) => e.toLocalJson()).toList());
    await prefs.setString(_localItemsKey, encoded);

    // Hapus file gambar dari storage HP
    final file = File(localPath);
    if (await file.exists()) await file.delete();
  }

  // ── Update item lokal yang sudah ada (nama, kategori, musim) ──────────────
  Future<void> updateLocalItem(ClothingItem updatedItem) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getLocalItems();
    final index = current.indexWhere((item) => item.id == updatedItem.id);
    if (index == -1) return; // item tidak ditemukan
    current[index] = updatedItem;
    final encoded = jsonEncode(current.map((e) => e.toLocalJson()).toList());
    await prefs.setString(_localItemsKey, encoded);
  }

  // ── 4. GALLERY: Gabung cloud (yg dipilih + metadata) + lokal ──────────────
  // Dipakai di WardrobePage & Randomizer
  Future<List<ClothingItem>> fetchGallery() async {
    try {
      final cloudItems = await _getCloudMetaItems();
      final localItems = await getLocalItems();
      return [...cloudItems, ...localItems];
    } catch (e) {
      debugPrint('Error fetching gallery: $e');
      rethrow;
    }
  }
}
