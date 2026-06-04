import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Dialog image color picker — user mengetuk gambar untuk mengambil warna.
/// Seperti fitur eyedropper / pipet warna.
class ColorPickerDialog extends StatefulWidget {
  final String imagePath; // path file gambar lokal
  final Color initialColor;

  const ColorPickerDialog({
    super.key,
    required this.imagePath,
    required this.initialColor,
  });

  /// Helper untuk menampilkan dialog dan mengembalikan warna yang dipilih.
  static Future<Color?> show(
    BuildContext context,
    String imagePath,
    Color initialColor,
  ) {
    return showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(
        imagePath: imagePath,
        initialColor: initialColor,
      ),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _pickedColor;
  ui.Image? _uiImage;
  ByteData? _pixelData;
  int _imageWidth = 0;
  int _imageHeight = 0;

  // Posisi sentuhan terakhir (koordinat widget, bukan gambar)
  Offset? _touchPosition;

  // Key untuk mendapat ukuran widget gambar
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pickedColor = widget.initialColor;
    _loadImage();
  }

  /// Decode file gambar ke ui.Image dan ambil pixel data (RGBA)
  Future<void> _loadImage() async {
    try {
      final file = File(widget.imagePath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (mounted) {
        setState(() {
          _uiImage = image;
          _pixelData = byteData;
          _imageWidth = image.width;
          _imageHeight = image.height;
        });
      }
    } catch (e) {
      debugPrint('Error loading image for color picker: $e');
    }
  }

  /// Ambil warna dari posisi sentuhan pada widget gambar
  void _onTouch(Offset localPosition) {
    if (_pixelData == null || _imageWidth == 0 || _imageHeight == 0) return;

    // Dapatkan ukuran widget gambar yang sedang ditampilkan
    final renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final widgetSize = renderBox.size;

    // Hitung skala dan offset karena BoxFit.contain
    final scaleX = widgetSize.width / _imageWidth;
    final scaleY = widgetSize.height / _imageHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final renderedWidth = _imageWidth * scale;
    final renderedHeight = _imageHeight * scale;
    final offsetX = (widgetSize.width - renderedWidth) / 2;
    final offsetY = (widgetSize.height - renderedHeight) / 2;

    // Konversi posisi sentuhan ke koordinat piksel gambar asli
    final imgX =
        ((localPosition.dx - offsetX) / scale).round().clamp(0, _imageWidth - 1);
    final imgY =
        ((localPosition.dy - offsetY) / scale).round().clamp(0, _imageHeight - 1);

    // Baca warna RGBA dari pixel data (4 byte per pixel)
    final pixelIndex = (imgY * _imageWidth + imgX) * 4;
    if (pixelIndex < 0 || pixelIndex + 3 >= _pixelData!.lengthInBytes) return;

    final r = _pixelData!.getUint8(pixelIndex);
    final g = _pixelData!.getUint8(pixelIndex + 1);
    final b = _pixelData!.getUint8(pixelIndex + 2);
    final a = _pixelData!.getUint8(pixelIndex + 3);

    setState(() {
      _pickedColor = Color.fromARGB(a, r, g, b);
      _touchPosition = localPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hexString =
        '0x${_pickedColor.toARGB32().toRadixString(16).toUpperCase()}';

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Row(
              children: [
                const Icon(Icons.colorize, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Pilih Warna dari Gambar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ketuk pada area gambar untuk mengambil warna',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),

            // ── Area gambar (touchable) ──
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _uiImage == null
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : GestureDetector(
                        onTapDown: (details) =>
                            _onTouch(details.localPosition),
                        onPanUpdate: (details) =>
                            _onTouch(details.localPosition),
                        onPanStart: (details) =>
                            _onTouch(details.localPosition),
                        child: Stack(
                          children: [
                            // Gambar utama
                            SizedBox(
                              key: _imageKey,
                              height: 280,
                              width: double.infinity,
                              child: Image.file(
                                File(widget.imagePath),
                                fit: BoxFit.contain,
                              ),
                            ),

                            // Crosshair / indicator posisi sentuhan
                            if (_touchPosition != null)
                              Positioned(
                                left: _touchPosition!.dx - 20,
                                top: _touchPosition!.dy - 20,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          blurRadius: 4,
                                          color: Colors.black38,
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _pickedColor,
                                        border: Border.all(
                                          color: Colors.black54,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Preview warna yang dipilih ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  // Lingkaran warna
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _pickedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(blurRadius: 4, color: Colors.black26),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Warna Terpilih:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hexString,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Tombol aksi ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _pickedColor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Pilih Warna Ini'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
