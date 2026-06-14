import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../components/ColorPickerDialog.dart';
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

  // ── State untuk color picking step (setelah foto diambil) ──
  String? _selfieSavedPath; // path file selfie yang sudah disimpan
  Color? _pickedSkinColor;
  Color? _pickedHairColor;
  Color? _pickedEyeColor;

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

  // ── Step 1: Ambil foto selfie ─────────────────────────────────────────
  Future<void> _takeSelfie(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 600,
      preferredCameraDevice: CameraDevice.front,
    );

    if (pickedFile == null) return;

    try {
      final imageFile = File(pickedFile.path);

      // Simpan selfie ke direktori dokumen app (permanen)
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'selfie_${DateTime.now().millisecondsSinceEpoch}${p.extension(imageFile.path)}';
      final savedPath = '${directory.path}/$fileName';
      await imageFile.copy(savedPath);

      // Pindah ke step color picking — reset semua warna
      if (mounted) {
        setState(() {
          _selfieSavedPath = savedPath;
          _pickedSkinColor = null;
          _pickedHairColor = null;
          _pickedEyeColor = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan foto: $e')),
        );
      }
    }
  }

  // ── Step 2: Pick warna dari gambar ────────────────────────────────────
  Future<void> _pickColorFor(String target) async {
    if (_selfieSavedPath == null) return;

    final initialColor = switch (target) {
      'skin' => _pickedSkinColor ?? Colors.grey,
      'hair' => _pickedHairColor ?? Colors.grey,
      'eye' => _pickedEyeColor ?? Colors.grey,
      _ => Colors.grey,
    };

    final picked = await ColorPickerDialog.show(
      context,
      _selfieSavedPath!,
      initialColor,
    );

    if (picked != null && mounted) {
      setState(() {
        switch (target) {
          case 'skin':
            _pickedSkinColor = picked;
            break;
          case 'hair':
            _pickedHairColor = picked;
            break;
          case 'eye':
            _pickedEyeColor = picked;
            break;
        }
      });
    }
  }

  // ── Step 3: Jalankan analisis ─────────────────────────────────────────
  Future<void> _runAnalysis() async {
    if (_selfieSavedPath == null ||
        _pickedSkinColor == null ||
        _pickedHairColor == null ||
        _pickedEyeColor == null) {
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final profile = UserColorProfile.analyzeFromColors(
        skinColor: _pickedSkinColor!,
        hairColor: _pickedHairColor!,
        eyeColor: _pickedEyeColor!,
        selfiePath: _selfieSavedPath!,
      );

      await _profileService.saveProfile(profile);

      if (mounted) {
        setState(() {
          _profile = profile;
          _isAnalyzing = false;
          _selfieSavedPath = null; // keluar dari color picking step
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✨ Berdasarkan analisis 3 warna, profil Anda adalah: ${profile.season.toUpperCase()}',
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
        _selfieSavedPath = null;
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
          if (_selfieSavedPath != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Batal',
              onPressed: () => setState(() => _selfieSavedPath = null),
            ),
          if (_profile != null && _selfieSavedPath == null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Analisis Ulang',
              onPressed: _showSelfieOptions,
            ),
        ],
      ),
      body: _isAnalyzing
          ? _buildAnalyzingState()
          : _selfieSavedPath != null
              ? _buildColorPickingStep()
              : _profile == null
                  ? _buildEmptyState()
                  : _buildProfileResult(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UI STATES
  // ═══════════════════════════════════════════════════════════════════════

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
              'Menganalisis Profil Warna...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Menghitung undertone dari kulit, rambut,\ndan mata untuk menentukan season Anda',
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
              'Seasonal Color Analysis',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ambil foto selfie di tempat terang, lalu tentukan '
              'warna kulit, rambut, dan mata Anda secara manual '
              'dari foto tersebut.\n\n'
              'Aplikasi akan menganalisis 3 warna tersebut '
              'menggunakan Seasonal Color Theory untuk menentukan '
              'profil warna musim Anda.',
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

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 2: COLOR PICKING — user pick 3 warna dari foto
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildColorPickingStep() {
    final allPicked = _pickedSkinColor != null &&
        _pickedHairColor != null &&
        _pickedEyeColor != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Preview foto selfie ──
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.file(
                File(_selfieSavedPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Instruksi ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.deepPurple.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 20, color: Colors.deepPurple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ketuk tombol "Pick" pada setiap baris untuk mengambil warna dari foto di atas.',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3 Color Picker Rows ──
          _buildColorPickRow(
            label: 'Nuansa Kulit',
            subtitle: 'Area wajah / leher',
            icon: Icons.face,
            pickedColor: _pickedSkinColor,
            onPick: () => _pickColorFor('skin'),
            accentColor: Colors.orange.shade700,
          ),
          const SizedBox(height: 10),
          _buildColorPickRow(
            label: 'Warna Rambut',
            subtitle: 'Area rambut yang natural',
            icon: Icons.content_cut,
            pickedColor: _pickedHairColor,
            onPick: () => _pickColorFor('hair'),
            accentColor: Colors.brown.shade600,
          ),
          const SizedBox(height: 10),
          _buildColorPickRow(
            label: 'Warna Mata',
            subtitle: 'Area iris mata',
            icon: Icons.visibility,
            pickedColor: _pickedEyeColor,
            onPick: () => _pickColorFor('eye'),
            accentColor: Colors.blue.shade600,
          ),
          const SizedBox(height: 24),

          // ── Tombol Analisis ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: allPicked ? _runAnalysis : null,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text('ANALISIS SEKARANG'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade500,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (!allPicked)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pilih warna untuk ketiga komponen di atas',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Baris input warna — dengan tombol Pick yang membuka ColorPickerDialog
  Widget _buildColorPickRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color? pickedColor,
    required VoidCallback onPick,
    required Color accentColor,
  }) {
    final bool hasPicked = pickedColor != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasPicked
            ? accentColor.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPicked
              ? accentColor.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasPicked
                  ? accentColor.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: hasPicked ? accentColor : Colors.grey),
          ),
          const SizedBox(width: 12),

          // Label & subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: hasPicked ? Colors.black87 : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // Lingkaran warna hasil pick
          if (hasPicked)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: pickedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
            ),

          // Tombol Pick
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: onPick,
              icon: Icon(
                hasPicked ? Icons.edit : Icons.colorize,
                size: 14,
              ),
              label: Text(hasPicked ? 'Ubah' : 'Pick'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasPicked ? accentColor : Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HASIL PROFIL
  // ═══════════════════════════════════════════════════════════════════════
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
                  'Berdasarkan analisis warna kulit, rambut,\ndan mata, profil Anda adalah:',
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

          // ── Detail Analisis (3 warna) ──
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
                // 3 warna yang dianalisis
                _detailRow(
                  'Nuansa Kulit',
                  '',
                  icon: Icons.face,
                  iconColor: Colors.orange.shade700,
                  trailing: _colorCircle(profile.skinColor),
                ),
                const Divider(height: 20),
                _detailRow(
                  'Warna Rambut',
                  '',
                  icon: Icons.content_cut,
                  iconColor: Colors.brown.shade600,
                  trailing: _colorCircle(profile.hairColor),
                ),
                const Divider(height: 20),
                _detailRow(
                  'Warna Mata',
                  '',
                  icon: Icons.visibility,
                  iconColor: Colors.blue.shade600,
                  trailing: _colorCircle(profile.eyeColor),
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

  // ── Helper widgets ────────────────────────────────────────────────────

  Widget _colorCircle(Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300),
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
