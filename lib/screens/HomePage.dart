import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../model/ClothingItem.dart';
import '../model/LookbookItem.dart';
import '../services/CatalogService.dart';
import '../services/LookbookService.dart';
import '../services/ProfileService.dart';
import '../services/SmartStylistService.dart';
import 'ChatScreen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<RandomizerViewState> _randomizerKey = GlobalKey();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Public — dipanggil dari main.dart via GlobalKey saat tab Styling aktif
  void refresh() {
    _randomizerKey.currentState?.refresh();
  }

  /// Public — berpindah ke sub-tab Canvas DIY (index 1)
  void openCanvasTab() {
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outfit Studio'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Randomizer', icon: Icon(Icons.casino)),
            Tab(text: 'Canvas DIY', icon: Icon(Icons.gesture)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RandomizerView(key: _randomizerKey), // Sub-halaman 1.1
          const CanvasView(), // Sub-halaman 1.2
        ],
      ),
      // // ── FAB: Tanya AI ──
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(builder: (_) => const ChatScreen()),
      //     );
      //   },
      //   icon: const Icon(Icons.auto_awesome, size: 20),
      //   label: const Text('Tanya AI'),
      //   backgroundColor: Colors.deepPurple,
      //   foregroundColor: Colors.white,
      // ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1.1 Tampilan Randomizer — Slot Machine Fashion
// ─────────────────────────────────────────────────────────────────────────────
class RandomizerView extends StatefulWidget {
  const RandomizerView({super.key});

  @override
  State<RandomizerView> createState() => RandomizerViewState();
}

class RandomizerViewState extends State<RandomizerView>
    with TickerProviderStateMixin {
  // Services
  final SmartStylistService _stylistService = SmartStylistService();
  final CatalogService _catalogService = CatalogService();
  final ProfileService _profileService = ProfileService();

  // Data pool per kategori
  List<ClothingItem> _outers = [];
  List<ClothingItem> _tops = [];
  List<ClothingItem> _bottoms = [];
  List<ClothingItem> _shoes = [];

  // PageController per baris
  late PageController _topController;
  late PageController _bottomController;
  late PageController _outerController;
  late PageController _shoeController;

  // Index yang sedang tampil per baris
  int _topIndex = 0;
  int _bottomIndex = 0;
  int _outerIndex = 0;
  int _shoeIndex = 0;

  // State
  bool includeOuter = false;
  bool _isLoading = true;
  bool _isShuffling = false;
  bool _isPerfectMatch = false;
  String _currentUserSeason =
      'Unknown'; // Diisi oleh _loadProfile() dari ProfileService

  // Animasi shimmer untuk shuffle
  late AnimationController _shuffleGlowController;
  late Animation<double> _shuffleGlow;

  @override
  void initState() {
    super.initState();
    _topController = PageController(viewportFraction: 0.92);
    _bottomController = PageController(viewportFraction: 0.92);
    _outerController = PageController(viewportFraction: 0.92);
    _shoeController = PageController(viewportFraction: 0.92);

    _shuffleGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _shuffleGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shuffleGlowController, curve: Curves.easeInOut),
    );

    _loadProfile();
    _loadWardrobe();
  }

  @override
  void dispose() {
    _outerController.dispose();
    _topController.dispose();
    _bottomController.dispose();
    _shoeController.dispose();
    _shuffleGlowController.dispose();
    super.dispose();
  }

  /// Public refresh — dipanggil via GlobalKey saat tab Styling aktif
  void refresh() {
    _loadProfile();
    _loadWardrobe();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.getProfile();
    if (profile != null && mounted) {
      setState(() => _currentUserSeason = profile.season);
    }
  }

  Future<void> _loadWardrobe() async {
    try {
      final items = await _catalogService.fetchGallery();
      if (!mounted) return;
      setState(() {
        _outers = items.where((i) => i.category == 'Outer').toList();
        _tops = items.where((i) => i.category == 'Top').toList();
        _bottoms = items.where((i) => i.category == 'Bottom').toList();
        _shoes = items.where((i) => i.category == 'Shoes').toList();

        // Reset semua index dan PageView ke 0 agar dot indicator sinkron
        _topIndex = 0;
        _bottomIndex = 0;
        _outerIndex = 0;
        _shoeIndex = 0;

        if (_topController.hasClients && _tops.isNotEmpty) {
          _topController.jumpToPage(0);
        }
        if (_bottomController.hasClients && _bottoms.isNotEmpty) {
          _bottomController.jumpToPage(0);
        }
        if (_outerController.hasClients && _outers.isNotEmpty) {
          _outerController.jumpToPage(0);
        }
        if (_shoeController.hasClients && _shoes.isNotEmpty) {
          _shoeController.jumpToPage(0);
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat gallery: $e')));
      }
    }
  }

  // ── SHUFFLE ──────────────────────────────────────────────────────────────
  Future<void> _rollDice() async {
    if (_tops.isEmpty || _bottoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 Atasan dan 1 Bawahan'),
        ),
      );
      return;
    }

    setState(() {
      _isShuffling = true;
      _isPerfectMatch = false;
    });

    // Beri peringatan jika profil musim kulit belum dianalisis
    if (_currentUserSeason == 'Unknown') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profil musim kulit belum diatur. '
            'Buka Profil dan analisis kulit agar Perfect Match bekerja!',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }

    // Jalankan algoritma — pass list yang sudah dipisah per kategori
    final result = _stylistService.rollOutfit(
      tops: _tops,
      bottoms: _bottoms,
      outers: _outers,
      shoes: _shoes,
      userSeason: _currentUserSeason,
      includeOuter: includeOuter,
    );

    if (result == null) {
      setState(() => _isShuffling = false);
      return;
    }

    // Cari index target di masing-masing list
    final topTarget = _tops.indexWhere((i) => i.id == result.top.id);
    final bottomTarget = _bottoms.indexWhere((i) => i.id == result.bottom.id);
    final outerTarget = result.outer != null
        ? _outers.indexWhere((i) => i.id == result.outer!.id)
        : -1;
    final shoeTarget = result.shoes != null
        ? _shoes.indexWhere((i) => i.id == result.shoes!.id)
        : -1;

    // Animasikan semua PageView serentak
    const duration = Duration(milliseconds: 500);
    const curve = Curves.easeInOutCubic;

    final futures = <Future>[];

    if (topTarget >= 0 && _topController.hasClients) {
      futures.add(
        _topController.animateToPage(
          topTarget,
          duration: duration,
          curve: curve,
        ),
      );
    }
    if (bottomTarget >= 0 && _bottomController.hasClients) {
      futures.add(
        _bottomController.animateToPage(
          bottomTarget,
          duration: duration,
          curve: curve,
        ),
      );
    }
    if (outerTarget >= 0 && _outerController.hasClients) {
      futures.add(
        _outerController.animateToPage(
          outerTarget,
          duration: duration,
          curve: curve,
        ),
      );
    }
    if (shoeTarget >= 0 && _shoeController.hasClients) {
      futures.add(
        _shoeController.animateToPage(
          shoeTarget,
          duration: duration,
          curve: curve,
        ),
      );
    }

    await Future.wait(futures);

    if (mounted) {
      setState(() {
        _isShuffling = false;
        _isPerfectMatch = result.isPerfectMatch;
        if (outerTarget >= 0) _outerIndex = outerTarget;
        if (topTarget >= 0) _topIndex = topTarget;
        if (bottomTarget >= 0) _bottomIndex = bottomTarget;
        if (shoeTarget >= 0) _shoeIndex = shoeTarget;
      });

      if (result.isPerfectMatch) {
        _shuffleGlowController.forward(from: 0);
      }
    }
  }

  // ── BUILD ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // ── Slot rows ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            children: [
              _buildCategoryRow(
                label: 'ATASAN',
                items: _tops,
                controller: _topController,
                currentIndex: _topIndex,
                onPageChanged: (i) => setState(() => _topIndex = i),
                accentColor: Colors.blue,
                icon: Icons.checkroom,
                emptyHint: 'Tambah Atasan di Wardrobe',
              ),
              _buildCategoryRow(
                label: 'BAWAHAN',
                items: _bottoms,
                controller: _bottomController,
                currentIndex: _bottomIndex,
                onPageChanged: (i) => setState(() => _bottomIndex = i),
                accentColor: Colors.green,
                icon: Icons.accessibility_new,
                emptyHint: 'Tambah Bawahan di Wardrobe',
              ),
              // Outer — hanya tampil jika toggle ON
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: includeOuter
                    ? _buildCategoryRow(
                        label: 'OUTER',
                        items: _outers,
                        controller: _outerController,
                        currentIndex: _outerIndex,
                        onPageChanged: (i) => setState(() => _outerIndex = i),
                        accentColor: Colors.orange,
                        icon: Icons.dry_cleaning,
                        emptyHint: 'Tambah Outer di Wardrobe',
                      )
                    : const SizedBox.shrink(),
              ),
              _buildCategoryRow(
                label: 'SEPATU',
                items: _shoes,
                controller: _shoeController,
                currentIndex: _shoeIndex,
                onPageChanged: (i) => setState(() => _shoeIndex = i),
                accentColor: Colors.brown,
                icon: Icons.ice_skating,
                emptyHint: 'Tambah Sepatu di Wardrobe',
              ),
            ],
          ),
        ),

        // ── Bottom controls ──
        _buildBottomControls(),
      ],
    );
  }

  // ── Category Row ────────────────────────────────────────────────────────
  Widget _buildCategoryRow({
    required String label,
    required List<ClothingItem> items,
    required PageController controller,
    required int currentIndex,
    required ValueChanged<int> onPageChanged,
    required Color accentColor,
    required IconData icon,
    required String emptyHint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  items.isEmpty
                      ? '(kosong)'
                      : '${currentIndex + 1}/${items.length}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // PageView atau empty card
          SizedBox(
            height: 140,
            child: items.isEmpty
                ? _buildEmptyCard(emptyHint, accentColor)
                : PageView.builder(
                    controller: controller,
                    itemCount: items.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      return _buildItemCard(item, accentColor);
                    },
                  ),
          ),

          // Dot indicators
          if (items.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  items.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == currentIndex ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == currentIndex
                          ? accentColor
                          : accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Item Card (di dalam PageView) ───────────────────────────────────────
  Widget _buildItemCard(ClothingItem item, Color accent) {
    final isLocal = !item.imageUrl.startsWith('http');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Gambar item (60%)
            Expanded(
              flex: 3,
              child: SizedBox.expand(
                child: isLocal
                    ? Image.file(
                        File(item.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildBrokenImage(),
                      )
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => _buildBrokenImage(),
                      ),
              ),
            ),
            // Info item (40%)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.season,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrokenImage() {
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
      ),
    );
  }

  // ── Empty Card ──────────────────────────────────────────────────────────
  Widget _buildEmptyCard(String hint, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accent.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 32,
                color: accent.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 6),
              Text(
                hint,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom Controls ─────────────────────────────────────────────────────
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Perfect Match badge (non-intrusive)
          AnimatedBuilder(
            animation: _shuffleGlow,
            builder: (context, child) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isPerfectMatch
                    ? Container(
                        key: const ValueKey('match'),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade300,
                              Colors.orange.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(
                                alpha: 0.4 * _shuffleGlow.value,
                              ),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Perfect Match — cocok dengan kulit $_currentUserSeason!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('no-match')),
              );
            },
          ),

          // Shuffle button + outer toggle
          Row(
            children: [
              // Outer toggle
              GestureDetector(
                onTap: () => setState(() => includeOuter = !includeOuter),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: includeOuter
                        ? Colors.orange.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: includeOuter
                          ? Colors.orange.withValues(alpha: 0.4)
                          : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.dry_cleaning,
                        size: 18,
                        color: includeOuter ? Colors.orange : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Outer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: includeOuter
                              ? Colors.orange[800]
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Shuffle button (utama)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isShuffling ? null : _rollDice,
                  icon: _isShuffling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.casino, size: 22),
                  label: Text(_isShuffling ? 'Shuffling...' : 'SHUFFLE OUTFIT'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.deepPurple.shade300,
                    disabledForegroundColor: Colors.white70,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1.2 Tampilan Canvas DIY
// ─────────────────────────────────────────────────────────────────────────────
class CanvasView extends StatefulWidget {
  const CanvasView({super.key});

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasItemData {
  final ClothingItem item;
  Offset position;

  _CanvasItemData({required this.item, required this.position});
}

class _CanvasViewState extends State<CanvasView> {
  final CatalogService _catalogService = CatalogService();
  final LookbookService _lookbookService = LookbookService();
  final List<_CanvasItemData> _canvasItems = [];

  final GlobalKey _canvasKey = GlobalKey();
  bool _isCapturing = false;

  // ── Buka bottom sheet untuk pilih item dari wardrobe ────────────────────
  Future<void> _showItemPicker() async {
    List<ClothingItem> wardrobeItems = [];
    String? errorMsg;

    try {
      wardrobeItems = await _catalogService.fetchGallery();
    } catch (e) {
      errorMsg = e.toString();
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return Column(
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
                const SizedBox(height: 12),
                const Text(
                  'Pilih Item untuk Canvas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ketuk item untuk menambahkan ke canvas',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: errorMsg != null
                      ? Center(child: Text('Error: $errorMsg'))
                      : wardrobeItems.isEmpty
                      ? const Center(
                          child: Text(
                            'Lemari masih kosong.\nTambah item di tab Wardrobe dulu.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: wardrobeItems.length,
                          itemBuilder: (context, index) {
                            final item = wardrobeItems[index];
                            return _buildPickerCard(ctx, item);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPickerCard(BuildContext ctx, ClothingItem item) {
    final isLocalImage = !item.imageUrl.startsWith('http');
    return GestureDetector(
      onTap: () {
        setState(() {
          _canvasItems.add(
            _CanvasItemData(
              item: item,
              position: Offset(
                80 + (_canvasItems.length * 20.0) % 120,
                60 + (_canvasItems.length * 30.0) % 200,
              ),
            ),
          );
        });
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.name}" ditambahkan ke canvas'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: isLocalImage
                  ? Image.file(
                      File(item.imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Icon(Icons.broken_image)),
                    )
                  : Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hapus item dari canvas ─────────────────────────────────────────────
  void _removeFromCanvas(int index) {
    setState(() => _canvasItems.removeAt(index));
  }

  // ── Decode gambar item ke ui.Image (untuk offscreen render) ────────────
  // Future<ui.Image> _decodeItemImage(ClothingItem item) async {
  //   Uint8List bytes;
  //   if (item.imageUrl.startsWith('http')) {
  //     final uri = Uri.parse(item.imageUrl);
  //     final client = HttpClient();
  //     final request = await client.getUrl(uri);
  //     final response = await request.close();
  //     bytes = await consolidateHttpClientResponseBytes(response);
  //     client.close();
  //   } else {
  //     bytes = await File(item.imageUrl).readAsBytes();
  //   }
  //   final codec = await ui.instantiateImageCodec(bytes);
  //   final frame = await codec.getNextFrame();
  //   return frame.image;
  // }

  /// Helper untuk membaca bytes dari HTTP response
  // static Future<Uint8List> consolidateHttpClientResponseBytes(
  //   HttpClientResponse response,
  // ) {
  //   final chunks = <List<int>>[];
  //   final completer = Completer<Uint8List>();
  //   response.listen(
  //     chunks.add,
  //     onDone: () => completer.complete(
  //       Uint8List.fromList(chunks.expand((c) => c).toList()),
  //     ),
  //     onError: completer.completeError,
  //     cancelOnError: true,
  //   );
  //   return completer.future;
  // }

  // // ── Capture canvas secara offscreen (memuat SEMUA item) ────────────────
  // Future<Uint8List> _captureCanvas() async {
  //   const itemWidth = 120.0;
  //   const itemHeight = 140.0;
  //   const padding = 20.0;
  //
  //   // 1. Hitung bounding box semua item
  //   double minX = double.infinity, minY = double.infinity;
  //   double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  //   for (final d in _canvasItems) {
  //     if (d.position.dx < minX) minX = d.position.dx;
  //     if (d.position.dy < minY) minY = d.position.dy;
  //     if (d.position.dx + itemWidth > maxX) maxX = d.position.dx + itemWidth;
  //     if (d.position.dy + itemHeight > maxY) maxY = d.position.dy + itemHeight;
  //   }
  //
  //   final contentW = maxX - minX + padding * 2;
  //   final contentH = maxY - minY + padding * 2;
  //
  //   // 2. Decode semua gambar ke PNG bytes
  //   final decodedImageBytes = <Uint8List>[];
  //   for (final d in _canvasItems) {
  //     final uiImg = await _decodeItemImage(d.item);
  //     final byteData = await uiImg.toByteData(format: ui.ImageByteFormat.png);
  //     uiImg.dispose(); // Dispose ui.Image setelah dikonversi ke bytes
  //     decodedImageBytes.add(byteData!.buffer.asUint8List());
  //   }
  //
  //   // 3. Bangun render tree offscreen
  //   final boundary = RenderRepaintBoundary();
  //   final stack = RenderStack(textDirection: ui.TextDirection.ltr);
  //   boundary.child = stack;
  //
  //   // Background (dengan ukuran eksplisit = ukuran canvas)
  //   final bg = RenderConstrainedBox(
  //     additionalConstraints: BoxConstraints.tightFor(
  //       width: contentW,
  //       height: contentH,
  //     ),
  //     child: RenderDecoratedBox(
  //       decoration: BoxDecoration(color: Colors.grey.shade100),
  //     ),
  //   );
  //   stack.add(bg);
  //
  //   // Items
  //   for (int i = 0; i < _canvasItems.length; i++) {
  //     final d = _canvasItems[i];
  //     final relX = d.position.dx - minX + padding;
  //     final relY = d.position.dy - minY + padding;
  //
  //     // Image (BoxFit.contain di dalam container putih)
  //     final imageRender = RenderDecoratedBox(
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(8),
  //         image: DecorationImage(
  //           image: MemoryImage(decodedImageBytes[i]),
  //           fit: BoxFit.contain,
  //         ),
  //       ),
  //     );
  //
  //     // Label nama
  //     final tp = TextPainter(
  //       text: TextSpan(
  //         text: d.item.name,
  //         style: const TextStyle(color: Colors.white, fontSize: 10),
  //       ),
  //       textDirection: ui.TextDirection.ltr,
  //       textAlign: TextAlign.center,
  //       maxLines: 1,
  //       ellipsis: '...',
  //     )..layout(maxWidth: itemWidth);
  //
  //     final labelBg = RenderDecoratedBox(
  //       decoration: const BoxDecoration(
  //         color: Color(0x8A000000),
  //         borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
  //       ),
  //       child: RenderPadding(
  //         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
  //         child: RenderParagraph(tp.text!, textDirection: ui.TextDirection.ltr),
  //       ),
  //     );
  //
  //     // Stack item: image + label overlay
  //     final itemStack = RenderStack(textDirection: ui.TextDirection.ltr);
  //     itemStack.add(imageRender);
  //
  //     // Label di bawah (positioned bottom)
  //     final labelPositioned = RenderPositionedBox(
  //       alignment: Alignment.bottomCenter,
  //       child: labelBg,
  //     );
  //     // Bungkus dalam Stack agar label overlay di bawah
  //     final overlayStack = RenderStack(textDirection: ui.TextDirection.ltr);
  //     overlayStack.add(itemStack);
  //     overlayStack.add(labelPositioned);
  //
  //     final labelParentData = labelPositioned.parentData as StackParentData;
  //     labelParentData.bottom = 0.0;
  //     labelParentData.left = 0.0;
  //     labelParentData.right = 0.0;
  //
  //     // Border + shadow container
  //     final borderedBox = RenderDecoratedBox(
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(10),
  //         border: Border.all(color: d.item.color, width: 2),
  //         boxShadow: const [
  //           BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1),
  //         ],
  //       ),
  //       child: RenderClipRRect(
  //         borderRadius: BorderRadius.circular(8),
  //         child: overlayStack,
  //       ),
  //     );
  //
  //     // Positioned dalam canvas stack
  //     final positioned = RenderPositionedBox(
  //       alignment: Alignment.topLeft,
  //       widthFactor: null,
  //       heightFactor: null,
  //       child: borderedBox,
  //     );
  //
  //     // Add ke stack DULU, baru set offset
  //     stack.add(positioned);
  //     final parentData = positioned.parentData as StackParentData;
  //     parentData.left = relX;
  //     parentData.top = relY;
  //   }
  //
  //   // 4. Layout + Paint
  //   final PipelineOwner owner = PipelineOwner();
  //   owner.rootNode = boundary;
  //
  //   boundary.layout(BoxConstraints.tightFor(width: contentW, height: contentH));
  //   owner.flushLayout();
  //   owner.flushCompositingBits();
  //   owner.flushPaint();
  //
  //   final offsetLayer = OffsetLayer();
  //   final context = PaintingContext(
  //     offsetLayer,
  //     Rect.fromLTWH(0, 0, contentW, contentH),
  //   );
  //   context.paintChild(boundary, Offset.zero);
  //
  //   // 5. Capture
  //   final image = await boundary.toImage(pixelRatio: 2.0);
  //   final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  //   image.dispose();
  //
  //   return byteData!.buffer.asUint8List();
  // }

  // ── Simpan canvas ke Lookbook ─────────────────────────────────────────
  Future<void> _saveToLookbook() async {
    if (_canvasItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canvas masih kosong! Tambah item dulu.')),
      );
      return;
    }
    setState(() {
      _isCapturing = true;
    });

    await Future.delayed(const Duration(milliseconds: 50));

    // Capture gambar canvas (offscreen, mencakup semua item)
    Uint8List? capturedBytes;
    try {
      // 2. Ambil gambar utuh dari RepaintBoundary (seluruh area canvas)
      RenderRepaintBoundary boundary =
          _canvasKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      // pixelRatio 2.0 atau 3.0 membuat gambar HD/tajam
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      capturedBytes = byteData?.buffer.asUint8List();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal capture canvas: $e')));
      }
      return;
    } finally {
      // 3. Kembalikan tombol delete (X) terlepas dari berhasil/gagal
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }

    if (!mounted || capturedBytes == null) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SaveLookbookSheet(
        imageBytes: capturedBytes!,
        itemIds: _canvasItems.map((d) => d.item.id).toList(),
        lookbookService: _lookbookService,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Outfit tersimpan di Lookbook!'),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Canvas area ──
        Positioned.fill(
          child: RepaintBoundary(
            key: _canvasKey,
            child: Stack(
              children: [
                // Latar Belakang Canvas
                Container(color: Colors.grey.shade100),

                // Hint jika canvas kosong
                if (_canvasItems.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gesture, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'Tekan "Add Item" untuk menambahkan\npakaian ke canvas',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Item-item di canvas (bisa digeser)
                for (int i = 0; i < _canvasItems.length; i++)
                  _CanvasItemWidget(
                    key: ValueKey('${_canvasItems[i].item.id}_$i'),
                    data: _canvasItems[i],
                    hideDeleteButton: _isCapturing,
                    onPositionChanged: (newPos) {
                      _canvasItems[i].position = newPos;
                    },
                    onDelete: () => _removeFromCanvas(i),
                  ),
              ],
            ),
          ),
        ),

        // ── Tombol Simpan ke Lookbook ─────────────────────────────────────
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            heroTag: 'canvas_save',
            onPressed: _saveToLookbook,
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            tooltip: 'Simpan ke Lookbook',
            child: const Icon(Icons.bookmark_add),
          ),
        ),

        // ── Tombol Add Item ───────────────────────────────────────────────
        Positioned(
          bottom: 20,
          left: 20,
          child: FloatingActionButton.extended(
            heroTag: 'canvas_add',
            onPressed: _showItemPicker,
            label: const Text("Add Item"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.white,
            foregroundColor: Colors.deepPurple,
            elevation: 4,
          ),
        ),

        // ── Counter item di canvas ────────────────────────────────────────
        if (_canvasItems.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_canvasItems.length} item',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget item di canvas (draggable dengan gambar asli)
// ─────────────────────────────────────────────────────────────────────────────
class _CanvasItemWidget extends StatefulWidget {
  final _CanvasItemData data;
  final bool hideDeleteButton;
  final ValueChanged<Offset> onPositionChanged;
  final VoidCallback onDelete;

  const _CanvasItemWidget({
    super.key,
    required this.data,
    this.hideDeleteButton = false,
    required this.onPositionChanged,
    required this.onDelete,
  });

  @override
  State<_CanvasItemWidget> createState() => _CanvasItemWidgetState();
}

class _CanvasItemWidgetState extends State<_CanvasItemWidget> {
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = widget.data.position;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.data.item;
    final isLocalImage = !item.imageUrl.startsWith('http');

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
          widget.onPositionChanged(_position);
        },
        child: Container(
          width: 120,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: item.color, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1),
            ],
          ),
          child: Stack(
            children: [
              // Gambar item — gunakan contain agar tidak terpotong
              // saat screenshot disimpan ke Lookbook
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 120,
                  height: 140,
                  color: Colors.white,
                  child: isLocalImage
                      ? Image.file(
                          File(item.imageUrl),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)),
                        )
                      : Image.network(
                          item.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                ),
              ),
              // Label nama di bawah
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
              // Tombol hapus (disembunyikan saat capture screenshot)
              if (!widget.hideDeleteButton)
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheet: Form simpan ke Lookbook
// ─────────────────────────────────────────────────────────────────────────────
class _SaveLookbookSheet extends StatefulWidget {
  final Uint8List imageBytes;
  final List<String> itemIds;
  final LookbookService lookbookService;

  const _SaveLookbookSheet({
    required this.imageBytes,
    required this.itemIds,
    required this.lookbookService,
  });

  @override
  State<_SaveLookbookSheet> createState() => _SaveLookbookSheetState();
}

class _SaveLookbookSheetState extends State<_SaveLookbookSheet> {
  final _nameController = TextEditingController();
  DateTime? _scheduledDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill nama dengan tanggal hari ini
    _nameController.text =
        'Outfit ${DateFormat('d MMM yyyy').format(DateTime.now())}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Pilih Tanggal Pemakaian',
      confirmText: 'Pilih',
      cancelText: 'Batal',
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama outfit tidak boleh kosong!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Simpan file PNG ke direktori dokumen app
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      final fileName = 'lookbook_$timestamp.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(widget.imageBytes);

      // 2. Buat & simpan LookbookItem (pakai timestamp yang sama)
      final lookbookItem = LookbookItem(
        id: 'lb_$timestamp',
        name: name,
        imagePath: file.path,
        createdAt: now,
        scheduledDate: _scheduledDate,
        itemIds: widget.itemIds,
      );
      await widget.lookbookService.save(lookbookItem);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Naik saat keyboard muncul
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle bar ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Judul ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bookmark_add,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Simpan ke Lookbook',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Nama Outfit ──
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nama Outfit',
                hintText: 'cth: Casual Friday, Date Night...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 14),

            // ── Jadwalkan Tanggal (opsional) ──
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _scheduledDate != null
                        ? Colors.deepPurple
                        : Colors.grey.shade400,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _scheduledDate != null
                      ? Colors.deepPurple.withValues(alpha: 0.06)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: _scheduledDate != null
                          ? Colors.deepPurple
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _scheduledDate == null
                            ? 'Jadwalkan pemakaian (opsional)'
                            : DateFormat(
                                'EEEE, d MMMM yyyy',
                              ).format(_scheduledDate!),
                        style: TextStyle(
                          color: _scheduledDate != null
                              ? Colors.deepPurple
                              : Colors.grey[600],
                          fontWeight: _scheduledDate != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (_scheduledDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _scheduledDate = null),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Tombol Simpan ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'SIMPAN KE LOOKBOOK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
