import 'dart:io';

import 'package:flutter/material.dart';

import '../model/ClothingItem.dart';
import '../services/CatalogService.dart';
import '../services/SmartStylistService.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
        body: const TabBarView(
          children: [
            RandomizerView(), // Sub-halaman 1.1
            CanvasView(), // Sub-halaman 1.2
          ],
        ),
      ),
    );
  }
}

// --- 1.1 Tampilan Randomizer ---
class RandomizerView extends StatefulWidget {
  const RandomizerView({super.key});

  @override
  State<RandomizerView> createState() => _RandomizerViewState();
}

class _RandomizerViewState extends State<RandomizerView> {
  bool includeOuter = false;

  // Instance dari Algoritma kita
  final SmartStylistService _stylistService = SmartStylistService();
  final CatalogService _catalogService = CatalogService();

  // Data State
  List<ClothingItem> _myWardrobe = [];
  OutfitResult? _currentOutfit;
  bool _isLoading = true;

  // Simulasi Profil User (Nanti bisa diambil dari Database Profil)
  final String _currentUserSeason = "Autumn";

  @override
  void initState() {
    super.initState();
    _loadWardrobe();
  }

  // Tarik semua baju dari HP/Supabase saat halaman dibuka
  Future<void> _loadWardrobe() async {
    final items = await _catalogService.fetchGallery();
    setState(() {
      _myWardrobe = items;
      _isLoading = false;
    });
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
              Colors.white.withOpacity(0.2),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black54,
                child: Text(
                  "$label: ${item.name}",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 1.2 Tampilan Canvas ---
class CanvasView extends StatelessWidget {
  const CanvasView({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Latar Belakang Canvas
        Container(color: Colors.grey.shade100),

        // Contoh Item yang bisa digeser (Nanti pakai Logic DragTarget)
        const Positioned(
          top: 50,
          left: 100,
          child: DraggableItem(label: "Atasan", color: Colors.blue),
        ),
        const Positioned(
          top: 200,
          left: 120,
          child: DraggableItem(label: "Bawahan", color: Colors.green),
        ),

        // Tombol Simpan
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Outfit disimpan ke Lookbook!")),
              );
            },
            child: const Icon(Icons.save),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          child: FloatingActionButton.extended(
            onPressed: () {},
            label: const Text("Add Item"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class DraggableItem extends StatelessWidget {
  final String label;
  final Color color;
  const DraggableItem({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Draggable(
      feedback: _buildBox(true),
      childWhenDragging: Container(), // Kosong saat di-drag
      child: _buildBox(false),
    );
  }

  Widget _buildBox(bool isDragging) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: color.withOpacity(isDragging ? 0.7 : 1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          if (!isDragging)
            BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
        ],
      ),
      child: Center(
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
