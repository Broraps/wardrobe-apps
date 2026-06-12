import 'package:flutter/material.dart';
import '../model/ClothingItem.dart';
import '../services/CatalogService.dart';
import '../utils/color_season_utils.dart';

/// Halaman untuk browse semua item cloud dari Supabase.
/// User bisa memilih item mana yang ingin ditambahkan ke gallery device ini.
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final CatalogService _service = CatalogService();

  late Future<void> _loadFuture;
  List<ClothingItem> _allCloudItems = [];
  Set<String> _galleryIds = {};

  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
  }

  Future<void> _loadData() async {
    try {
      final items = await _service.fetchAllCloudItems();
      final ids = await _service.getGalleryCloudIds();
      setState(() {
        _allCloudItems = items;
        _galleryIds = ids;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat katalog: $e')),
        );
      }
    }
  }

  Future<void> _toggleItem(ClothingItem item) async {
    final inGallery = _galleryIds.contains(item.id);

    if (inGallery) {
      // Hapus dari gallery — langsung, tanpa dialog
      await _service.removeCloudFromGallery(item.id);
      setState(() => _galleryIds.remove(item.id));
      _changed = true;
      return;
    }

    // ── Tambah ke gallery: minta user pilih kategori ──
    final category = await _showCategoryPicker();
    if (category == null) return; // user cancel

    // Buat ClothingItem dengan metadata lengkap
    final detectedSeason = guessSeasonFromColor(item.color);
    final itemWithMeta = ClothingItem(
      id: item.id,
      name: item.name,
      category: category,
      color: item.color,
      imageUrl: item.imageUrl,
      season: detectedSeason,
      isLocal: false,
    );

    await _service.addCloudToGallery(item.id, itemMeta: itemWithMeta);
    setState(() => _galleryIds.add(item.id));
    _changed = true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${item.name}" ditambahkan sebagai $category'),
        ),
      );
    }
  }

  /// Dialog pilih kategori saat menambahkan cloud item ke gallery
  Future<String?> _showCategoryPicker() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pilih Kategori'),
        content: const Text(
          'Tentukan kategori item ini agar bisa digunakan di Randomizer outfit.',
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _categoryButton(ctx, 'Top', Icons.checkroom),
              _categoryButton(ctx, 'Bottom', Icons.accessibility_new),
              _categoryButton(ctx, 'Outer', Icons.dry_cleaning),
              _categoryButton(ctx, 'Shoes', Icons.ice_skating),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryButton(BuildContext ctx, String category, IconData icon) {
    return SizedBox(
      width: 110,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pop(ctx, category),
        icon: Icon(icon, size: 18),
        label: Text(category),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pop(context, _changed ? true : null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _changed ? true : null),
          ),
          title: const Text('Katalog Cloud'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  _LegendDot(color: Colors.blue.shade700, label: 'Belum di gallery'),
                  const SizedBox(width: 12),
                  _LegendDot(color: Colors.green.shade700, label: 'Sudah di gallery'),
                ],
              ),
            ),
          ],
        ),
        body: FutureBuilder(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_allCloudItems.isEmpty) {
              return const Center(child: Text('Tidak ada item di katalog.'));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _allCloudItems.length,
              itemBuilder: (context, index) {
                final item = _allCloudItems[index];
                final inGallery = _galleryIds.contains(item.id);
                return _CatalogCard(
                  item: item,
                  inGallery: inGallery,
                  onToggle: () => _toggleItem(item),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ── Kartu Item Katalog ────────────────────────────────────────────────────────
class _CatalogCard extends StatelessWidget {
  final ClothingItem item;
  final bool inGallery;
  final VoidCallback onToggle;

  const _CatalogCard({
    required this.item,
    required this.inGallery,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: inGallery ? Colors.green.shade600 : Colors.blue.shade300,
          width: inGallery ? 2.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image, size: 40)),
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

          // Badge status gallery
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: inGallery ? Colors.green.shade700 : Colors.blue.shade700,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    inGallery ? Icons.check_circle : Icons.cloud,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    inGallery ? 'Di Gallery' : 'Cloud',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tombol tambah/hapus dari gallery
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: inGallery ? Colors.green.shade700 : Colors.blue.shade700,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    inGallery ? Icons.remove : Icons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Legend dot helper ─────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
