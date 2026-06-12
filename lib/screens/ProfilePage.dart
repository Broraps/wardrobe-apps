import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../services/ProfileService.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();

  UserColorProfile? _profile;
  bool _isLoading = true;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Public — dipanggil via GlobalKey saat tab Profile aktif
  void refresh() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.getProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  // ── Ambil selfie dan analisis warna kulit ─────────────────────────────
  Future<void> _takeSelfie(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 600,
      preferredCameraDevice: CameraDevice.front, // Kamera depan untuk selfie
    );

    if (pickedFile == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final imageFile = File(pickedFile.path);

      // 1. Simpan selfie ke direktori dokumen app (permanen)
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'selfie_${DateTime.now().millisecondsSinceEpoch}${p.extension(imageFile.path)}';
      final savedPath = '${directory.path}/$fileName';
      await imageFile.copy(savedPath);

      // 2. Ekstrak warna dominan dari foto (sama seperti AddItemPage)
      final PaletteGenerator generator =
          await PaletteGenerator.fromImageProvider(
        FileImage(File(savedPath)),
        size: const Size(200, 200),
        maximumColorCount: 10,
      );

      // Ambil warna kulit — prioritas: dominant > vibrant > muted
      Color skinColor = generator.dominantColor?.color ??
          generator.vibrantColor?.color ??
          generator.mutedColor?.color ??
          Colors.grey;

      // 3. Analisis warna kulit menggunakan logika HSV
      final profile = UserColorProfile.analyzeFromSkinColor(
        skinColor: skinColor,
        selfiePath: savedPath,
      );

      // 4. Simpan ke SharedPreferences
      await _profileService.saveProfile(profile);

      if (mounted) {
        setState(() {
          _profile = profile;
          _isAnalyzing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✨ Berdasarkan deteksi warna kulit, profil Anda adalah: ${profile.season.toUpperCase()}',
            ),
            backgroundColor: Colors.deepPurple,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menganalisis: $e')),
        );
      }
    }
  }

  // ── Pilih sumber gambar ───────────────────────────────────────────────
  void _showSelfieOptions() {
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
              'Foto Wajah untuk Analisis',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Pastikan foto di tempat terang dengan cahaya alami untuk hasil terbaik',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child:
                    const Icon(Icons.camera_alt, color: Colors.deepPurple),
              ),
              title: const Text('Selfie (Kamera Depan)'),
              subtitle: const Text('Direkomendasikan'),
              onTap: () {
                Navigator.pop(ctx);
                _takeSelfie(ImageSource.camera);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child: const Icon(Icons.photo_library,
                    color: Colors.deepPurple),
              ),
              title: const Text('Pilih dari Galeri'),
              subtitle: const Text('Gunakan foto wajah yang sudah ada'),
              onTap: () {
                Navigator.pop(ctx);
                _takeSelfie(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Reset profil ──────────────────────────────────────────────────────
  Future<void> _resetProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Profil?'),
        content: const Text(
          'Profil warna musim akan dihapus. Anda perlu melakukan selfie ulang untuk analisis baru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _profileService.clearProfile();
    if (mounted) {
      setState(() {
        _profile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil di-reset')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Warna'),
        centerTitle: false,
        actions: [
          if (_profile != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Analisis Ulang',
              onPressed: _showSelfieOptions,
            ),
        ],
      ),
      body: _isAnalyzing
          ? _buildAnalyzingState()
          : _profile == null
              ? _buildEmptyState()
              : _buildProfileResult(),
    );
  }

  // ── Tampilan saat sedang menganalisis ─────────────────────────────────
  Widget _buildAnalyzingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Menganalisis Warna Kulit...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mendeteksi undertone dan menentukan\nprofil warna musim Anda',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tampilan belum ada profil ─────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.face_retouching_natural,
                size: 60,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Analisis Warna Kulit',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ambil foto selfie di tempat terang untuk\nmendeteksi profil warna musim Anda.\n\n'
              'Aplikasi akan menganalisis warna kulit\nmenggunakan algoritma Color Season Analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showSelfieOptions,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Mulai Analisis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tampilan hasil profil ─────────────────────────────────────────────
  Widget _buildProfileResult() {
    final profile = _profile!;
    final seasonData = _seasonInfo[profile.season]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Selfie + Season Badge ──
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Foto selfie
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: seasonData['color'] as Color,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (seasonData['color'] as Color)
                          .withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.file(
                    File(profile.selfiePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.person,
                          size: 60, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              // Season badge
              Transform.translate(
                offset: const Offset(0, 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: seasonData['color'] as Color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    profile.season.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Hasil Analisis ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (seasonData['color'] as Color).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    (seasonData['color'] as Color).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Berdasarkan deteksi warna kulit,\nprofil Anda adalah:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  profile.season,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: seasonData['color'] as Color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  seasonData['emoji'] as String,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  seasonData['description'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Detail Analisis ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detail Analisis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                _detailRow(
                  'Undertone',
                  profile.undertone,
                  icon: Icons.thermostat,
                  iconColor: profile.undertone == 'Warm'
                      ? Colors.orange
                      : Colors.blue,
                ),
                const Divider(height: 20),
                _detailRow(
                  'Kecerahan',
                  profile.brightness,
                  icon: Icons.brightness_6,
                  iconColor: profile.brightness == 'Light'
                      ? Colors.amber
                      : Colors.brown,
                ),
                const Divider(height: 20),
                _detailRow(
                  'Warna Kulit Terdeteksi',
                  '',
                  icon: Icons.palette,
                  iconColor: Colors.deepPurple,
                  trailing: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: profile.skinColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const Divider(height: 20),
                _detailRow(
                  'Tanggal Analisis',
                  DateFormat('d MMMM yyyy, HH:mm', 'id')
                      .format(profile.analyzedAt),
                  icon: Icons.access_time,
                  iconColor: Colors.grey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Palet Warna yang Cocok ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Palet Warna yang Cocok',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Warna pakaian yang paling sesuai dengan profil ${profile.season} Anda',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (seasonData['palette'] as List<Color>)
                      .map(
                        (c) => Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.grey.shade300),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black12, blurRadius: 2),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Tombol Aksi ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetProfile,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showSelfieOptions,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Analisis Ulang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    required IconData icon,
    required Color iconColor,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        trailing ??
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
      ],
    );
  }

  // ── Data referensi tiap musim ──────────────────────────────────────────
  static final Map<String, Map<String, dynamic>> _seasonInfo = {
    'Spring': {
      'color': Colors.orange,
      'emoji': '🌸',
      'description':
          'Tipe Spring memiliki undertone warm dengan kecerahan kulit cerah. '
              'Warna-warna cerah dan hangat seperti coral, peach, dan kuning muda '
              'sangat cocok untuk Anda.',
      'palette': <Color>[
        const Color(0xFFFF7043), // Coral
        const Color(0xFFFFAB91), // Peach
        const Color(0xFFFFF176), // Kuning muda
        const Color(0xFF81C784), // Hijau cerah
        const Color(0xFF4FC3F7), // Biru muda
        const Color(0xFFFFCC80), // Oranye muda
        const Color(0xFFE57373), // Merah muda
        const Color(0xFFA5D6A7), // Sage
      ],
    },
    'Summer': {
      'color': Colors.blue,
      'emoji': '☀️',
      'description':
          'Tipe Summer memiliki undertone cool dengan kecerahan kulit cerah. '
              'Warna-warna lembut dan kalem seperti lavender, dusty rose, dan biru pastel '
              'sangat cocok untuk Anda.',
      'palette': <Color>[
        const Color(0xFFCE93D8), // Lavender
        const Color(0xFFF48FB1), // Dusty rose
        const Color(0xFF90CAF9), // Biru pastel
        const Color(0xFFB0BEC5), // Silver grey
        const Color(0xFFA5D6A7), // Mint
        const Color(0xFFE1BEE7), // Lilac
        const Color(0xFF80DEEA), // Aqua
        const Color(0xFFBCAAA4), // Mauve
      ],
    },
    'Autumn': {
      'color': Colors.brown,
      'emoji': '🍂',
      'description':
          'Tipe Autumn memiliki undertone warm dengan kecerahan kulit deep. '
              'Warna-warna earthy dan muted seperti burnt orange, olive, dan burgundy '
              'sangat cocok untuk Anda.',
      'palette': <Color>[
        const Color(0xFFBF360C), // Burnt orange
        const Color(0xFF795548), // Cokelat
        const Color(0xFF827717), // Olive
        const Color(0xFFC62828), // Burgundy
        const Color(0xFFFF8F00), // Mustard
        const Color(0xFF4E342E), // Dark brown
        const Color(0xFF558B2F), // Hijau zaitun
        const Color(0xFFD84315), // Terracotta
      ],
    },
    'Winter': {
      'color': Colors.indigo,
      'emoji': '❄️',
      'description':
          'Tipe Winter memiliki undertone cool dengan kontras yang kuat. '
              'Warna-warna bold dan kontras seperti hitam, putih, merah terang, dan biru royal '
              'sangat cocok untuk Anda.',
      'palette': <Color>[
        const Color(0xFF000000), // Hitam
        const Color(0xFFFFFFFF), // Putih
        const Color(0xFFD50000), // Merah terang
        const Color(0xFF1A237E), // Navy
        const Color(0xFF4A148C), // Ungu tua
        const Color(0xFF00695C), // Emerald
        const Color(0xFF0D47A1), // Royal blue
        const Color(0xFFC51162), // Magenta
      ],
    },
  };
}
