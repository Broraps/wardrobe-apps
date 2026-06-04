import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path/path.dart' as p;
import '../model/ClothingItem.dart';
import '../services/CatalogService.dart';
import 'ColorPickerDialog.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  // Helper Function: Tebak Musim dari Warna (HSV)
  String _guessSeasonFromColor(Color color) {
    HSVColor hsv = HSVColor.fromColor(color);
    double hue = hsv.hue;
    double saturation = hsv.saturation;
    double value = hsv.value;

    // Logika Sederhana (Bisa diperkompleks sesuai Bab 2 Skripsi)
    bool isWarm =
        (hue >= 0 && hue < 50) ||
        (hue > 330 && hue <= 360); // Merah, Oranye, Kuning
    bool isCool = (hue >= 150 && hue <= 270); // Biru, Ungu, Cyan

    if (isWarm) {
      // Jika Warm & Gelap/Muted -> Autumn
      if (value < 0.6 || saturation < 0.6) return 'Autumn';
      // Jika Warm & Terang/Cerah -> Spring
      return 'Spring';
    } else if (isCool) {
      // Jika Cool & Gelap/Kontras -> Winter
      if (value < 0.4 || saturation > 0.8) return 'Winter';
      // Sisanya Summer
      return 'Summer';
    }

    // Default fallback
    return 'Winter';
  }

  // Variabel Form
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  // Variabel Data
  File? _imageFile;
  Color _detectedColor = Colors.grey; // Default sebelum detect
  String _hexColorString = "#808080"; // Default Hex

  // Pilihan Dropdown (Sesuai Teori Skripsi)
  String? _selectedCategory;
  final List<String> _categories = ['Top', 'Bottom', 'Outer', 'Shoes'];

  String? _selectedSeason;
  final List<String> _seasons = ['Winter', 'Summer', 'Spring', 'Autumn'];

  bool _isLoading = false;

  // 1. FUNGSI AMBIL GAMBAR
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, maxWidth: 600);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isLoading = true;
      });

      // 1. Deteksi Warna Dulu — mengembalikan warna yang terdeteksi
      final detectedColor = await _extractDominantColor(_imageFile!);

      // 2. Deteksi Objek & Isi Form Otomatis — pass warna langsung
      await _autoFillData(_imageFile!, detectedColor);

      setState(() => _isLoading = false);
    }
  }

  // 2. FUNGSI CERDAS: DETEKSI WARNA (Palette Generator)
  Future<Color> _extractDominantColor(File image) async {
    final PaletteGenerator generator = await PaletteGenerator.fromImageProvider(
      FileImage(image),
      size: const Size(200, 200), // Resize biar cepat prosesnya
      maximumColorCount: 10,
    );

    // Ambil warna dominan, kalau gagal ambil warna vibrant
    Color picked =
        generator.dominantColor?.color ?? generator.vibrantColor?.color ?? Colors.grey;

    setState(() {
      _detectedColor = picked;
      // Ubah ke format Hex String untuk Database (cth: 0xFF123456)
      _hexColorString = '0x${picked.toARGB32().toRadixString(16).toUpperCase()}';
    });

    return picked;
  }

  // 3. SIMPAN ITEM LOKAL ke SharedPreferences (bukan ke Supabase)
  Future<void> _saveLocalAndUploadMeta() async {
    if (!_formKey.currentState!.validate() ||
        _imageFile == null ||
        _selectedCategory == null ||
        _selectedSeason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lengkapi semua data & foto!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Salin gambar ke folder dokumen app (permanen)
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}${p.extension(_imageFile!.path)}';
      final String localPath = '${directory.path}/$fileName';
      await _imageFile!.copy(localPath);

      // 2. Buat objek ClothingItem lokal
      final newItem = ClothingItem(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        category: _selectedCategory!,
        season: _selectedSeason!,
        color: _detectedColor,
        imageUrl: localPath,
        isLocal: true,
      );

      // 3. Simpan ke SharedPreferences (hanya device ini)
      await CatalogService().saveLocalItem(newItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tersimpan di lokal device ini!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Gagal simpan: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _autoFillData(File image, Color colorForSeason) async {
    // 1. Siapkan Labeler
    final InputImage inputImage = InputImage.fromFile(image);
    final ImageLabelerOptions options = ImageLabelerOptions(
      confidenceThreshold: 0.5,
    );
    final imageLabeler = ImageLabeler(options: options);

    try {
      // 2. Proses Gambar
      final List<ImageLabel> labels = await imageLabeler.processImage(
        inputImage,
      );

      String detectedName = "";
      String detectedCategory = "Top"; // Default

      // 3. Cek Label yang keluar (Cth: "Jeans", "Shirt", "Shoe")
      for (ImageLabel label in labels) {
        String text = label.label.toLowerCase();

        // Simpan label pertama sebagai nama (biasanya paling akurat)
        if (detectedName.isEmpty) detectedName = label.label;

        // Mapping Kategori Sederhana
        if (text.contains('shirt') ||
            text.contains('top') ||
            text.contains('jersey') ||
            text.contains('blouse')) {
          detectedCategory = 'Top';
        } else if (text.contains('jeans') ||
            text.contains('trousers') ||
            text.contains('skirt') ||
            text.contains('shorts') ||
            text.contains('pants')) {
          detectedCategory = 'Bottom';
        } else if (text.contains('jacket') ||
            text.contains('coat') ||
            text.contains('blazer') ||
            text.contains('cardigan')) {
          detectedCategory = 'Outer';
        } else if (text.contains('shoe') ||
            text.contains('sneaker') ||
            text.contains('boot') ||
            text.contains('sandal')) {
          detectedCategory = 'Shoes';
        }
      }

      // 4. Update UI (Isi Form Otomatis)
      setState(() {
        // Isi Nama Barang (Kalo kosong kasih nama generic)
        _nameController.text = detectedName.isNotEmpty
            ? detectedName
            : "Unknown Item";

        // Pilih Kategori di Dropdown
        _selectedCategory = detectedCategory;

        // Tebak Musim dari warna yang di-pass langsung (bukan dari state)
        _selectedSeason = _guessSeasonFromColor(colorForSeason);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ Data terisi otomatis! Silakan koreksi jika perlu."),
        ),
      );
    } catch (e) {
      print("Error labeling: $e");
    } finally {
      imageLabeler.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Koleksi")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- AREA GAMBAR ---
              GestureDetector(
                onTap: () => _showPickerOptions(),
                child: Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: _imageFile != null
                      ? Image.file(
                          _imageFile!,
                          fit: BoxFit.cover,
                        ) // Preview Gambar Lokal
                      : const Icon(Icons.camera_alt, size: 50),
                ),
              ),
              const SizedBox(height: 20),
              // --- HASIL DETEKSI WARNA + PILIH MANUAL ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _detectedColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(blurRadius: 2, color: Colors.black26),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Warna Item:",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _hexColorString,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _imageFile == null
                            ? null
                            : () async {
                                final picked = await ColorPickerDialog.show(
                                  context,
                                  _imageFile!.path,
                                  _detectedColor,
                                );
                                if (picked != null) {
                                  setState(() {
                                    _detectedColor = picked;
                                    _hexColorString =
                                        '0x${picked.toARGB32().toRadixString(16).toUpperCase()}';
                                    // Recalculate season berdasarkan warna baru
                                    _selectedSeason = _guessSeasonFromColor(picked);
                                  });
                                }
                              },
                        icon: const Icon(Icons.colorize, size: 18),
                        label: const Text('Pilih Warna dari Gambar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          side: const BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- FORM INPUT ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Nama Barang (cth: Kemeja Navy)",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Isi nama barang' : null,
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Kategori",
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: _selectedSeason,
                decoration: const InputDecoration(
                  labelText: "Tipe Musim (Analisis Manual)",
                  border: OutlineInputBorder(),
                ),
                items: _seasons
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedSeason = val),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveLocalAndUploadMeta,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SIMPAN KE LEMARI"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
