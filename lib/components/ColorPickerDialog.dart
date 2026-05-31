import 'package:flutter/material.dart';

/// Dialog pemilih warna manual untuk pakaian.
/// Menampilkan grid warna umum pakaian + slider HSV untuk warna custom.
class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const ColorPickerDialog({super.key, required this.initialColor});

  /// Helper untuk menampilkan dialog dan mengembalikan warna yang dipilih.
  static Future<Color?> show(BuildContext context, Color initialColor) {
    return showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(initialColor: initialColor),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSVColor _hsvColor;

  // Warna-warna umum pakaian
  static const List<Color> _presetColors = [
    Color(0xFF000000), // Hitam
    Color(0xFFFFFFFF), // Putih
    Color(0xFF808080), // Abu-abu
    Color(0xFF1B1B1B), // Charcoal
    Color(0xFF2C3E50), // Navy
    Color(0xFF1A237E), // Dark Blue
    Color(0xFF1565C0), // Blue
    Color(0xFF42A5F5), // Light Blue
    Color(0xFF004D40), // Dark Teal
    Color(0xFF2E7D32), // Green
    Color(0xFF66BB6A), // Light Green
    Color(0xFFA5D6A7), // Sage
    Color(0xFFC62828), // Red
    Color(0xFFE53935), // Bright Red
    Color(0xFFEF5350), // Coral
    Color(0xFFF48FB1), // Pink
    Color(0xFF6A1B9A), // Purple
    Color(0xFF9C27B0), // Violet
    Color(0xFFCE93D8), // Lavender
    Color(0xFFFF6F00), // Orange
    Color(0xFFFFA726), // Light Orange
    Color(0xFFFDD835), // Yellow
    Color(0xFF795548), // Brown
    Color(0xFF8D6E63), // Light Brown
    Color(0xFFD7CCC8), // Beige
    Color(0xFFF5F5DC), // Cream
    Color(0xFFBCAAA4), // Taupe
    Color(0xFFA1887F), // Mauve
  ];

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
  }

  void _selectPreset(Color color) {
    setState(() {
      _hsvColor = HSVColor.fromColor(color);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = _hsvColor.toColor();

    return AlertDialog(
      title: const Text('Pilih Warna'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Preview warna terpilih ──
            Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                color: selectedColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              child: Center(
                child: Text(
                  '0x${selectedColor.toARGB32().toRadixString(16).toUpperCase()}',
                  style: TextStyle(
                    color: _hsvColor.value > 0.5 && _hsvColor.saturation < 0.5
                        ? Colors.black87
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Grid warna preset ──
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Warna Umum:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _presetColors.map((color) {
                final isSelected =
                    (color.toARGB32() == selectedColor.toARGB32());
                return GestureDetector(
                  onTap: () => _selectPreset(color),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Colors.deepPurple
                            : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.deepPurple.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: HSVColor.fromColor(color).value > 0.5
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Slider HSV untuk custom ──
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Warna Custom:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Hue slider
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: Text('Hue', style: TextStyle(fontSize: 11)),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 10,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      trackShape: _HueTrackShape(),
                    ),
                    child: Slider(
                      value: _hsvColor.hue,
                      min: 0,
                      max: 360,
                      onChanged: (val) {
                        setState(() {
                          _hsvColor = _hsvColor.withHue(val);
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),

            // Saturation slider
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: Text('Saturasi', style: TextStyle(fontSize: 11)),
                ),
                Expanded(
                  child: Slider(
                    value: _hsvColor.saturation,
                    min: 0,
                    max: 1,
                    activeColor: selectedColor,
                    onChanged: (val) {
                      setState(() {
                        _hsvColor = _hsvColor.withSaturation(val);
                      });
                    },
                  ),
                ),
              ],
            ),

            // Value/brightness slider
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: Text('Terang', style: TextStyle(fontSize: 11)),
                ),
                Expanded(
                  child: Slider(
                    value: _hsvColor.value,
                    min: 0,
                    max: 1,
                    activeColor: selectedColor,
                    onChanged: (val) {
                      setState(() {
                        _hsvColor = _hsvColor.withValue(val);
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, selectedColor),
          child: const Text('Pilih'),
        ),
      ],
    );
  }
}

/// Custom track shape untuk slider hue (menampilkan spektrum warna)
class _HueTrackShape extends SliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 10;
    final trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackLeft = offset.dx + 8;
    final trackWidth = parentBox.size.width - 16;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    // Buat gradient dengan spektrum warna (hue 0-360)
    final colors = List<Color>.generate(
      7,
      (i) => HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
    );

    final gradient = LinearGradient(colors: colors);
    final paint = Paint()..shader = gradient.createShader(rect);

    context.canvas.drawRRect(rrect, paint);
  }
}
