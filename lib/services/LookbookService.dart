import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/LookbookItem.dart';

class LookbookService {
  static const _key = 'lookbook_items';

  // ── Ambil semua item (diurutkan terbaru dulu) ─────────────────────────────
  Future<List<LookbookItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    final items = decoded
        .map((e) => LookbookItem.fromJson(e as Map<String, dynamic>))
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first
    return items;
  }

  // ── Simpan item baru ───────────────────────────────────────────────────────
  Future<void> save(LookbookItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getAll();
    current.add(item);
    final encoded = jsonEncode(current.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  // ── Hapus item berdasarkan ID (dan file gambarnya) ─────────────────────────
  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getAll();

    // Hapus file PNG screenshot
    final toDelete = current.where((item) => item.id == id).firstOrNull;
    if (toDelete != null) {
      final file = File(toDelete.imagePath);
      if (await file.exists()) await file.delete();
    }

    current.removeWhere((item) => item.id == id);
    final encoded = jsonEncode(current.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  // ── Filter item berdasarkan tanggal yang dijadwalkan ──────────────────────
  List<LookbookItem> getForDate(List<LookbookItem> items, DateTime date) {
    return items.where((item) {
      if (item.scheduledDate == null) return false;
      final d = item.scheduledDate!;
      return d.year == date.year &&
          d.month == date.month &&
          d.day == date.day;
    }).toList();
  }
}
