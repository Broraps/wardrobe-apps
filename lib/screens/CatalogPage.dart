import 'package:flutter/material.dart';
import '../model/ClothingItem.dart';
import '../services/CatalogService.dart';

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

  // ── Variabel Filtering, Sorting, & Search ──
  String _searchQuery = '';
  String _selectedStatus = 'Semua';
  String _selectedCategory = 'Semua';
  String _sortOrder = 'A-Z'; // Opsi: 'A-Z', 'Z-A'

  static const List<String> _statusOptions = [
    'Semua',
    'Belum di Gallery',
    'Sudah di Gallery',
  ];

  static const List<String> _categoryOptions = [
    'Semua',
    'Top',
    'Bottom',
    'Outer',
    'Shoes',
  ];

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat katalog: $e')));
      }
    }
  }

  Future<void> _toggleItem(ClothingItem item) async {
    final inGallery = _galleryIds.contains(item.id);

    if (inGallery) {
      await _service.removeCloudFromGallery(item.id);
      setState(() => _galleryIds.remove(item.id));
      _changed = true;
      return;
    }

    await _service.addCloudToGallery(item.id, itemMeta: item);
    setState(() => _galleryIds.add(item.id));
    _changed = true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${item.name}" ditambahkan ke gallery!'),
          backgroundColor: Colors.deepPurple,
          duration: const Duration(seconds: 1),
        ),
      );
    }
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
            // Tombol Sorting A-Z / Z-A
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Urutkan',
              onSelected: (val) => setState(() => _sortOrder = val),
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'A-Z',
                  checked: _sortOrder == 'A-Z',
                  child: const Text('Nama (A - Z)'),
                ),
                CheckedPopupMenuItem(
                  value: 'Z-A',
                  checked: _sortOrder == 'Z-A',
                  child: const Text('Nama (Z - A)'),
                ),
              ],
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

            // ── LOGIKA FILTERING, SEARCH, & SORTING ──
            var filteredItems = _allCloudItems.where((item) {
              // 1. Filter Status
              final inGallery = _galleryIds.contains(item.id);
              bool passStatus = true;
              if (_selectedStatus == 'Belum di Gallery')
                passStatus = !inGallery;
              if (_selectedStatus == 'Sudah di Gallery') passStatus = inGallery;

              // 2. Filter Kategori
              bool passCategory =
                  _selectedCategory == 'Semua' ||
                  item.category.toLowerCase() ==
                      _selectedCategory.toLowerCase();

              // 3. Search
              bool passSearch = item.name.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );

              return passStatus && passCategory && passSearch;
            }).toList();

            // 4. Sorting
            filteredItems.sort((a, b) {
              if (_sortOrder == 'A-Z') return a.name.compareTo(b.name);
              return b.name.compareTo(a.name); // Z-A
            });

            return Column(
              children: [
                // ── Kotak Pencarian (Search Bar) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama baju atau sepatu...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),

                // ── Filter Status (Gallery) ──
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _statusOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final label = _statusOptions[i];
                      final isSelected = _selectedStatus == label;
                      return FilterChip(
                        selected: isSelected,
                        label: Text(label),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontSize: 12,
                        ),
                        selectedColor: Colors.deepPurple,
                        backgroundColor: Colors.grey[200],
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide.none,
                        onSelected: (_) =>
                            setState(() => _selectedStatus = label),
                      );
                    },
                  ),
                ),

                // ── Filter Kategori Pakaian ──
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    itemCount: _categoryOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final label = _categoryOptions[i];
                      final isSelected = _selectedCategory == label;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(label),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.deepPurple
                              : Colors.grey[600],
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                        selectedColor: Colors.deepPurple.withOpacity(0.1),
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.deepPurple
                              : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategory = label),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // ── Grid View Item ──
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            'Item tidak ditemukan.',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final inGallery = _galleryIds.contains(item.id);
                            return _CatalogCard(
                              item: item,
                              inGallery: inGallery,
                              onToggle: () => _toggleItem(item),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Kartu Item Katalog ──
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
                trailing: CircleAvatar(backgroundColor: item.color, radius: 10),
              ),
            ],
          ),
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
