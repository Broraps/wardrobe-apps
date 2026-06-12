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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final GlobalKey<RandomizerViewState> _randomizerKey = GlobalKey();

  /// Public — dipanggil dari main.dart via GlobalKey saat tab Styling aktif
  void refresh() {
    _randomizerKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Outfit Studio'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Randomizer', icon: Icon(Icons.casino)),
              Tab(text: 'Canvas DIY', icon: Icon(Icons.gesture)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RandomizerView(key: _randomizerKey), // Sub-halaman 1.1
            const CanvasView(),                  // Sub-halaman 1.2
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1.1 Tampilan Randomizer
// ─────────────────────────────────────────────────────────────────────────────
class RandomizerView extends StatefulWidget {
  const RandomizerView({super.key});

  @override
  State<RandomizerView> createState() => RandomizerViewState();
}

class RandomizerViewState extends State<RandomizerView> {
  bool includeOuter = false;

  // Instance dari Algoritma kita
  final SmartStylistService _stylistService = SmartStylistService();
  final CatalogService _catalogService = CatalogService();
  final ProfileService _profileService = ProfileService();

  // Data State
  List<ClothingItem> _myWardrobe = [];
  OutfitResult? _currentOutfit;
  bool _isLoading = true;

  // Profil warna user (diambil dari ProfileService, bukan hardcode)
  String _currentUserSeason = 'Autumn'; // fallback default

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadWardrobe();
  }

  /// Public refresh — dipanggil via GlobalKey saat tab Styling aktif
  void refresh() {
    _loadProfile();
    _loadWardrobe();
  }

  /// Muat profil user dari SharedPreferences
  Future<void> _loadProfile() async {
    final profile = await _profileService.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _currentUserSeason = profile.season;
      });
    }
  }

  // Tarik semua baju dari HP/Supabase saat halaman dibuka
  Future<void> _loadWardrobe() async {
    try {
      final items = await _catalogService.fetchGallery();
      setState(() {
        _myWardrobe = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat gallery: $e')));
      }
    }
  }

  // FUNGSI SAAT TOMBOL DADU DITEKAN
  void _rollDice() {
    if (_myWardrobe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lemari kamu masih kosong!")),
      );
      return;
    }

    // Panggil Algoritma Cerdas
    OutfitResult? result = _stylistService.rollOutfit(
      _myWardrobe,
      _currentUserSeason,
      includeOuter,
    );

    if (result != null) {
      setState(() {
        _currentOutfit = result;
      });

      // Tampilkan Efek "Perfect Match" jika algoritmanya bilang True
      if (result.isPerfectMatch) {
        _showPerfectMatchDialog();
      }
    }
  }

  // Animasi/Popup Bonus untuk User
  void _showPerfectMatchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.amber.shade50,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber, size: 30),
            SizedBox(width: 10),
            Text(
              "Perfect Match!",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Kombinasi pakaian ini sangat cocok dengan kulit $_currentUserSeason kamu!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Keren!"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // Toggle Switch
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Include Outer?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: includeOuter,
                onChanged: (val) {
                  setState(() => includeOuter = val);
                },
              ),
            ],
          ),
        ),

        // Area Tampilan Outfit (Grid)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _currentOutfit == null
                ? const Center(child: Text("Tekan Dadu untuk Mix & Match!"))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (includeOuter && _currentOutfit!.outer != null)
                        _buildOutfitBox("Outer", _currentOutfit!.outer!),

                      const SizedBox(height: 10),
                      _buildOutfitBox("Atasan", _currentOutfit!.top),

                      const SizedBox(height: 10),
                      _buildOutfitBox("Bawahan", _currentOutfit!.bottom),

                      const SizedBox(height: 10),
                      if (_currentOutfit!.shoes != null)
                        _buildOutfitBox("Sepatu", _currentOutfit!.shoes!),
                    ],
                  ),
          ),
        ),

        // Tombol Dadu
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton.icon(
            onPressed: _rollDice,
            icon: const Icon(Icons.casino, size: 28),
            label: const Text("SHUFFLE OUTFIT"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget untuk menampilkan kotak baju yang sudah diacak
  Widget _buildOutfitBox(String label, ClothingItem item) {
    bool isLocalImage = !item.imageUrl.startsWith('http');

    return Expanded(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          image: DecorationImage(
            image: isLocalImage
                ? FileImage(File(item.imageUrl)) as ImageProvider
                : NetworkImage(item.imageUrl),
            fit: BoxFit.cover,
            // Efek transparan biar teks label tetap terbaca
            colorFilter: ColorFilter.mode(
                Colors.white.withValues(alpha: 0.2),
              BlendMode.lighten,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black54,
                child: Text(
                  "$label: ${item.name}",
                  style:
                      const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
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

  // Key untuk RepaintBoundary — dipakai saat screenshot canvas
  final GlobalKey _canvasKey = GlobalKey();

  // Flag untuk menyembunyikan tombol hapus saat screenshot
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
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // ── Simpan canvas ke Lookbook ─────────────────────────────────────────
  Future<void> _saveToLookbook() async {
    if (_canvasItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Canvas masih kosong! Tambah item dulu.'),
        ),
      );
      return;
    }

    // Sembunyikan tombol hapus agar tidak ikut ter-capture di screenshot
    setState(() => _isCapturing = true);

    // Tunggu frame berikutnya agar UI sempat rebuild tanpa tombol hapus
    await Future.delayed(const Duration(milliseconds: 100));

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SaveLookbookSheet(
        canvasKey: _canvasKey,
        itemIds: _canvasItems.map((d) => d.item.id).toList(),
        lookbookService: _lookbookService,
      ),
    );

    // Tampilkan kembali tombol hapus setelah bottom sheet ditutup
    if (mounted) setState(() => _isCapturing = false);

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
        // ── Canvas area (dibungkus RepaintBoundary untuk screenshot) ──
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
                        Icon(
                          Icons.gesture,
                          size: 60,
                          color: Colors.grey[300],
                        ),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Gambar item
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 120,
                  height: 140,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
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
  final GlobalKey canvasKey;
  final List<String> itemIds;
  final LookbookService lookbookService;

  const _SaveLookbookSheet({
    required this.canvasKey,
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
      // 1. Capture screenshot dari RepaintBoundary canvas
      final boundary = widget.canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Canvas tidak ditemukan');

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Gagal mengambil gambar canvas');
      final Uint8List bytes = byteData.buffer.asUint8List();

      // 2. Simpan file PNG ke direktori dokumen app
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      final fileName = 'lookbook_$timestamp.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // 3. Buat & simpan LookbookItem (pakai timestamp yang sama)
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            : DateFormat('EEEE, d MMMM yyyy')
                                .format(_scheduledDate!),
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
