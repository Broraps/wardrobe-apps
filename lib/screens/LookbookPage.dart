import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../model/LookbookItem.dart';
import '../services/LookbookService.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Halaman utama Lookbook (grid semua outfit tersimpan)
// ─────────────────────────────────────────────────────────────────────────────
class LookbookPage extends StatefulWidget {
  const LookbookPage({super.key});

  @override
  State<LookbookPage> createState() => LookbookPageState();
}

class LookbookPageState extends State<LookbookPage> {
  final LookbookService _service = LookbookService();
  late Future<List<LookbookItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAll();
  }

  /// Public agar bisa dipanggil dari luar via GlobalKey saat tab aktif
  void refresh() {
    final future = _service.getAll();
    setState(() {
      _future = future;
    });
  }

  Future<void> _confirmDelete(LookbookItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus dari Lookbook?'),
        content: Text('"${item.name}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${item.name}" dihapus dari Lookbook.')),
        );
        refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Lookbook',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: FutureBuilder<List<LookbookItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) return _buildEmptyState();

          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.70,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (ctx, i) => _LookbookCard(
              item: items[i],
              onDelete: () => _confirmDelete(items[i]),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LookbookDetailPage(item: items[i]),
                  ),
                );
                refresh();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_album_outlined,
                size: 52,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Lookbook Masih Kosong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Susun outfit di tab Styling → Canvas DIY,\nlalu tekan tombol Simpan 💾',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card item di grid
// ─────────────────────────────────────────────────────────────────────────────
class _LookbookCard extends StatelessWidget {
  final LookbookItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LookbookCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shadowColor: Colors.black26,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Thumbnail ──
            Image.file(
              File(item.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: const Icon(
                  Icons.broken_image,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            ),

            // ── Gradient overlay bawah ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Tanggal dijadwalkan (jika ada)
                    if (item.scheduledDate != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.amberAccent,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('d MMM yyyy')
                                .format(item.scheduledDate!),
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        DateFormat('d MMM yyyy').format(item.createdAt),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Tombol hapus ──
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ),

            // ── Badge "Dijadwalkan" ──
            if (item.scheduledDate != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today,
                          color: Colors.white, size: 10),
                      SizedBox(width: 3),
                      Text(
                        'Planned',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Halaman Detail Lookbook (full screen image viewer + edit & share)
// ─────────────────────────────────────────────────────────────────────────────
class LookbookDetailPage extends StatefulWidget {
  final LookbookItem item;
  const LookbookDetailPage({super.key, required this.item});

  @override
  State<LookbookDetailPage> createState() => _LookbookDetailPageState();
}

class _LookbookDetailPageState extends State<LookbookDetailPage> {
  final LookbookService _service = LookbookService();
  late LookbookItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  // ── Edit nama & jadwal ──────────────────────────────────────────────────
  Future<void> _showEditDialog() async {
    final nameController = TextEditingController(text: _item.name);
    DateTime? pickedDate = _item.scheduledDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Edit Outfit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Outfit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tanggal jadwal
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.calendar_today,
                        color: pickedDate != null
                            ? Colors.deepPurple
                            : Colors.grey,
                      ),
                      title: Text(
                        pickedDate != null
                            ? DateFormat('d MMMM yyyy', 'id')
                                .format(pickedDate!)
                            : 'Belum dijadwalkan',
                      ),
                      subtitle: const Text('Jadwal pemakaian'),
                      trailing: pickedDate != null
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setDialogState(() {
                                  pickedDate = null;
                                });
                              },
                            )
                          : null,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: pickedDate ?? DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            pickedDate = date;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Nama tidak boleh kosong'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx, {
                      'name': name,
                      'scheduledDate': pickedDate,
                    });
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      final updated = _item.copyWith(
        name: result['name'] as String,
        scheduledDate: result['scheduledDate'] as DateTime?,
        clearScheduledDate: result['scheduledDate'] == null,
      );
      await _service.update(updated);
      if (mounted) {
        setState(() {
          _item = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${updated.name}" berhasil diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui: $e')),
        );
      }
    }
  }

  // ── Share gambar outfit ─────────────────────────────────────────────────
  Future<void> _shareOutfit() async {
    final file = File(_item.imagePath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File gambar tidak ditemukan')),
        );
      }
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(_item.imagePath)],
        text: '👗 Outfit: ${_item.name}\nDari Smart Wardrobe',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal share: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _item.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Tombol Edit
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit',
            onPressed: _showEditDialog,
          ),
          // Tombol Share
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share',
            onPressed: _shareOutfit,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Gambar full ──
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: Image.file(
                  File(_item.imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Panel info bawah ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  _item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow(
                  icon: Icons.access_time,
                  color: Colors.white60,
                  text:
                      'Dibuat: ${DateFormat('EEEE, d MMMM yyyy', 'id').format(_item.createdAt)}',
                  textColor: Colors.white60,
                ),
                if (_item.scheduledDate != null) ...[
                  const SizedBox(height: 6),
                  _infoRow(
                    icon: Icons.calendar_today,
                    color: Colors.amberAccent,
                    text:
                        'Dijadwalkan: ${DateFormat('EEEE, d MMMM yyyy', 'id').format(_item.scheduledDate!)}',
                    textColor: Colors.amberAccent,
                  ),
                ],

                const SizedBox(height: 16),

                // ── Tombol aksi cepat ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showEditDialog,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _shareOutfit,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color color,
    required String text,
    required Color textColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
