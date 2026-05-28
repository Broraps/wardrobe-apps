import 'dart:io';

import 'package:flutter/material.dart';
import '../components/AddItemPage.dart';
import '../model/ClothingItem.dart';
import '../services/CatalogService.dart';
import 'CatalogPage.dart';

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  final CatalogService _catalogService = CatalogService();
  late Future<List<ClothingItem>> _futureGallery;

  @override
  void initState() {
    super.initState();
    _futureGallery = _catalogService.fetchGallery();
  }

  void _refresh() {
    setState(() {
      _futureGallery = _catalogService.fetchGallery();
    });
  }

  // ── FAB: pilih tambah dari katalog cloud atau upload lokal ────────────────
  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tambah ke Gallery',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade700,
                child: const Icon(Icons.cloud, color: Colors.white),
              ),
              title: const Text('Pilih dari Katalog Cloud'),
              subtitle: const Text('Item biru — tersedia di semua device'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CatalogPage()),
                );
                if (result == true) _refresh();
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade700,
                child: const Icon(Icons.smartphone, color: Colors.white),
              ),
              title: const Text('Upload Manual (Lokal)'),
              subtitle: const Text('Item hijau — hanya di device ini'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddItemPage()),
                );
                if (result == true) _refresh();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(ClothingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus dari Gallery?'),
        content: Text(
          item.isLocal
              ? '"${item.name}" adalah item lokal dan akan dihapus permanen dari perangkat ini.'
              : '"${item.name}" adalah item cloud. Item akan dihapus dari gallery perangkat ini, '
                  'tapi masih bisa ditambahkan ulang dari Katalog Cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (item.isLocal) {
        await _catalogService.deleteLocalItem(item.id, item.imageUrl);
      } else {
        await _catalogService.removeCloudFromGallery(item.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item.isLocal
                  ? '"${item.name}" dihapus permanen.'
                  : '"${item.name}" dihapus dari gallery. Bisa ditambah lagi dari Katalog.',
            ),
          ),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wardrobe'),
        actions: [
          // Legend kecil di AppBar
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                _SourceDot(color: Colors.blue.shade700),
                const SizedBox(width: 2),
                const Text('Cloud', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 10),
                _SourceDot(color: Colors.green.shade700),
                const SizedBox(width: 2),
                const Text('Lokal', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah ke Gallery',
        onPressed: _showAddOptions,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<ClothingItem>>(
        future: _futureGallery,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.checkroom_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Gallery masih kosong.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tekan + untuk menambahkan item\ndari katalog cloud atau upload manual.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _buildItemCard(items[index]),
          );
        },
      ),
    );
  }

  // ── CARD ───────────────────────────────────────────────────────────────────
  Widget _buildItemCard(ClothingItem item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isLocal
              ? Colors.green.shade300
              : Colors.blue.shade300,
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // ── Image + Info ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: item.isLocal
                    ? Image.file(
                        File(item.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, size: 40),
                        ),
                      )
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, size: 40),
                        ),
                      ),
              ),
              ListTile(
                dense: true,
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(item.category),
                trailing: CircleAvatar(
                  backgroundColor: item.color,
                  radius: 10,
                ),
              ),
            ],
          ),

          // ── Sumber Badge (kiri atas) ──
          Positioned(
            top: 8,
            left: 8,
            child: _SourceBadge(isLocal: item.isLocal),
          ),

          // ── Tombol Hapus (kanan atas) ──
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _confirmDelete(item),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge Widget ──────────────────────────────────────────────────────────────
class _SourceBadge extends StatelessWidget {
  final bool isLocal;
  const _SourceBadge({required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLocal ? Colors.green.shade700 : Colors.blue.shade700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLocal ? Icons.smartphone : Icons.cloud,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            isLocal ? 'Lokal' : 'Cloud',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceDot extends StatelessWidget {
  final Color color;
  const _SourceDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
