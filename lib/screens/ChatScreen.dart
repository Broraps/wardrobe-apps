import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../model/ClothingItem.dart';
import '../services/CatalogService.dart';
import '../services/ProfileService.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ChatScreen — Fitur "Tanya AI" (Gemini-powered Fashion Consultant)
//
// Menggunakan Gemini REST API langsung (tanpa package deprecated).
// AI merespons dengan teks + gambar item dari lemari user.
// Setiap item yang direferensikan AI menggunakan tag [ITEM:id]
// yang di-parse menjadi kartu gambar item inline.
// ═══════════════════════════════════════════════════════════════════════════

/// Model pesan chat lokal
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ── Services ──
  final CatalogService _catalogService = CatalogService();
  final ProfileService _profileService = ProfileService();

  // ── Gemini Config ──
  late final String _apiKey;
  // Model: ganti di sini jika ingin model lain
  // Contoh: 'gemini-2.0-flash', 'gemini-3-flash-preview', dll.
  static const String _modelName = 'gemini-2.5-flash';

  // ── Chat History (untuk multi-turn conversation) ──
  final List<Map<String, dynamic>> _chatHistory = [];

  // ── UI State ──
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  // ── Context Data (diambil dari device) ──
  String _profileContext = '';
  String _wardrobeContext = '';
  List<ClothingItem> _wardrobeItems = [];

  // ── System Instruction ──
  static const String _systemInstruction = '''
Kamu adalah PocketCloset AI — asisten fashion pribadi.

ATURAN:
1. HANYA jawab topik fashion, outfit, mix & match, warna pakaian, color harmony, seasonal color.
2. Jika topik di luar fashion, tolak dengan JSON: {"pesan_teks": "Maaf, saya hanya bisa membantu seputar fashion 👗", "rekomendasi_utama": [], "rekomendasi_alternatif": []}
3. Jawab dalam Bahasa Indonesia, SINGKAT dan LANGSUNG ke inti. Tidak perlu basa-basi.
4. Gunakan emoji secukupnya.

ALGORITMA SEASONAL COLOR THEORY:
Setiap item memiliki season (Spring/Summer/Autumn/Winter). Profil pengguna juga punya season.
Gunakan aturan kecocokan warna berikut:

- PALING COCOK (Complementary): Season item = Season profil pengguna.
- COCOK (Harmonious): Pasangan harmonis:
  * Spring ↔ Autumn (sama-sama Warm)
  * Summer ↔ Winter (sama-sama Cool)
- KONTRAS MENARIK: Warm ↔ Cool bisa dipakai untuk aksen/statement piece, tapi BUKAN sebagai mayoritas outfit.

ATURAN OUTFIT:
1. Setiap outfit WAJIB terdiri dari KATEGORI BERBEDA (Top, Bottom, Outer, Shoes). JANGAN pilih 2 item dari kategori yang sama dalam 1 outfit.
2. Minimal outfit: 1 Top + 1 Bottom. Outer dan Shoes opsional tapi dianjurkan jika ada.
3. Pastikan warna antar item dalam 1 outfit HARMONIS — gunakan prinsip color harmony (analogous, complementary, atau monochromatic).
4. JANGAN menampilkan item yang sama di rekomendasi_utama dan rekomendasi_alternatif.

FORMAT RESPONS — WAJIB JSON:
{
  "pesan_teks": "Penjelasan singkat tentang rekomendasi dan alasan pemilihan warna.",
  "rekomendasi_utama": ["id1", "id2", "id3"],
  "rekomendasi_alternatif": ["id4", "id5", "id6"]
}

PENJELASAN FIELD:
- "pesan_teks": MAKSIMAL 2 kalimat. Singkat, padat, langsung ke poin. Jelaskan alasan pemilihan warna berdasarkan seasonal color theory.
- "rekomendasi_utama": outfit SET pertama — item yang PALING COCOK dengan profil seasonal color pengguna. Prioritaskan item dengan season yang sama dengan profil pengguna.
- "rekomendasi_alternatif": outfit SET kedua — kombinasi KREATIF dan BEBAS yang tetap harmonis secara warna, boleh lintas season asalkan color harmony terjaga. Gunakan item BERBEDA dari rekomendasi_utama.
- Kedua list berisi ID PERSIS dari daftar lemari. JANGAN buat ID sendiri.
- Jika item di lemari tidak cukup untuk 2 outfit berbeda, kosongkan rekomendasi_alternatif: []
''';

  @override
  void initState() {
    super.initState();
    // ── API Key ──
    // Ambil dari .env file. Tambahkan GEMINI_API_KEY=your_key di file .env
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      debugPrint('⚠️ GEMINI_API_KEY belum diset di .env!');
    }
    _loadContextData();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LOAD CONTEXT DATA (dari device asli)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _loadContextData() async {
    try {
      // 1. Tarik Data Profil
      final profile = await _profileService.getProfile();
      if (profile != null) {
        _profileContext =
            'Profil warna pengguna: '
            'Season = ${profile.season}, '
            'Undertone = ${profile.undertone}, '
            'Kecerahan = ${profile.brightness}.';
      } else {
        _profileContext = 'Pengguna belum melakukan analisis profil warna.';
      }

      // 2. Tarik Data Lemari Pakaian
      final items = await _catalogService.fetchGallery();
      _wardrobeItems = items;
      if (items.isNotEmpty) {
        _wardrobeContext = _buildWardrobeSummary(items);
      } else {
        _wardrobeContext = 'Lemari pakaian pengguna masih kosong.';
      }
    } catch (e) {
      debugPrint('Error loading context: $e');
      _profileContext = 'Gagal memuat profil pengguna.';
      _wardrobeContext = 'Gagal memuat data lemari pakaian.';
    }

    if (mounted) {
      setState(() => _isInitialized = true);

      // Pesan pembuka AI
      _messages.add(
        _ChatMessage(
          text:
              'Halo! 👋 Saya PocketCloset AI, asisten fashion pribadimu.\n\n'
              'Kamu bisa bertanya seputar:\n'
              '• 🎨 Rekomendasi outfit dari lemari kamu\n'
              '• 🌈 Kombinasi warna yang cocok\n'
              '• 👗 Tips styling & mix-and-match\n\n'
              'Apa yang bisa saya bantu hari ini?',
          isUser: false,
        ),
      );
      setState(() {});
    }
  }

  /// Konversikan list ClothingItem menjadi ringkasan teks untuk AI
  /// Menyertakan hex color agar AI bisa reasoning tentang color harmony
  String _buildWardrobeSummary(List<ClothingItem> items) {
    final grouped = <String, List<String>>{};
    for (final item in items) {
      final hexColor = '#${(item.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      grouped
          .putIfAbsent(item.category, () => [])
          .add('"${item.name}" [ID: ${item.id}] (season: ${item.season}, warna: $hexColor)');
    }

    final buffer = StringBuffer('Daftar lemari pakaian pengguna:\n');
    for (final entry in grouped.entries) {
      buffer.writeln('${entry.key}:');
      for (final itemDesc in entry.value) {
        buffer.writeln('  - $itemDesc');
      }
    }
    buffer.writeln(
      '\nGunakan ID dari daftar di atas untuk field rekomendasi_utama dan rekomendasi_alternatif.',
    );
    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GEMINI REST API — Direct HTTP Call
  // ═══════════════════════════════════════════════════════════════════════

  /// Kirim pesan ke Gemini REST API dan terima respons.
  /// Mendukung multi-turn conversation via _chatHistory.
  Future<String> _callGeminiApi(String userMessage) async {
    // Bangun prompt dengan context injection
    final contextMessage =
        '''
[KONTEKS TERSEMBUNYI — jangan sebutkan bagian ini secara eksplisit kepada pengguna]
$_profileContext

$_wardrobeContext

ATURAN PEMILIHAN:
- rekomendasi_utama: pilih item yang season-nya COCOK dengan profil pengguna (prioritas: same season > harmonious pair).
- rekomendasi_alternatif: pilih item BERBEDA yang tetap harmonis secara warna, boleh kreatif lintas season.
- Setiap set outfit harus terdiri dari KATEGORI BERBEDA (jangan 2 Top dalam 1 set).
- JANGAN gunakan item yang sama di kedua list.
[AKHIR KONTEKS]

Pesan pengguna: $userMessage
''';

    // Tambahkan ke history
    _chatHistory.add({
      'role': 'user',
      'parts': [
        {'text': contextMessage},
      ],
    });

    // Bangun request body
    final requestBody = {
      'system_instruction': {
        'parts': [
          {'text': _systemInstruction},
        ],
      },
      'contents': _chatHistory,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 8192,
        'responseMimeType': 'application/json',
      },
    };

    // REST API endpoint
    // Docs: https://ai.google.dev/api/generate-content
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent?key=$_apiKey',
    );

    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(url);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.add(utf8.encode(jsonEncode(requestBody)));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        // Parse error message
        try {
          final errorJson = jsonDecode(responseBody) as Map<String, dynamic>;
          final errorMsg = errorJson['error']?['message'] ?? responseBody;
          throw Exception('API Error (${response.statusCode}): $errorMsg');
        } catch (e) {
          if (e is Exception && e.toString().contains('API Error')) {
            rethrow;
          }
          throw Exception('API Error (${response.statusCode}): $responseBody');
        }
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      // Extract text dari response
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Tidak ada respons dari AI.');
      }

      final parts = candidates[0]['content']?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw Exception('Respons AI kosong.');
      }

      final aiText = parts.map((p) => p['text'] ?? '').join();

      // Simpan respons AI ke history untuk multi-turn
      _chatHistory.add({
        'role': 'model',
        'parts': [
          {'text': aiText},
        ],
      });

      return aiText;
    } finally {
      httpClient.close();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // KIRIM PESAN
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _sendMessage() async {
    final userText = _inputController.text.trim();
    if (userText.isEmpty) return;

    // 1. Tambah pesan user ke UI
    setState(() {
      _messages.add(_ChatMessage(text: userText, isUser: true));
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      // 2. Kirim ke Gemini REST API
      final rawText = await _callGeminiApi(userText);

      // 3. Parse JSON respons AI
      String aiText = '';
      List<ClothingItem> rekUtama = [];
      List<ClothingItem> rekAlternatif = [];

      try {
        // 1. Ekstrak HANYA bagian di dalam kurawal { ... }
        String cleanJson = rawText;
        int startIndex = rawText.indexOf('{');
        int endIndex = rawText.lastIndexOf('}');

        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          cleanJson = rawText.substring(startIndex, endIndex + 1);
        }

        // 2. Parsing JSON dengan aman
        final decoded = jsonDecode(cleanJson);

        // Teks utama untuk bubble chat
        aiText = decoded['pesan_teks'] ?? "Ini rekomendasi outfit untukmu:";

        // 3. Ambil ID pakaian dan cocokkan dengan database lokal
        final allItems = await _catalogService.fetchGallery();

        // Helper: cocokkan list ID ke ClothingItem, hindari duplikat kategori
        List<ClothingItem> _matchItems(List<dynamic> ids) {
          final matched = <ClothingItem>[];
          final usedCategories = <String>{};
          for (var id in ids) {
            final item = allItems.where((e) => e.id.toString() == id.toString()).firstOrNull;
            if (item != null && !usedCategories.contains(item.category)) {
              matched.add(item);
              usedCategories.add(item.category);
            }
          }
          return matched;
        }

        // Parse rekomendasi_utama (berdasarkan profil seasonal color)
        List<dynamic> idsUtama = decoded['rekomendasi_utama'] ?? [];
        rekUtama = _matchItems(idsUtama);

        // Parse rekomendasi_alternatif (outfit kreatif bebas)
        List<dynamic> idsAlternatif = decoded['rekomendasi_alternatif'] ?? [];
        rekAlternatif = _matchItems(idsAlternatif);

        // Hapus item dari alternatif yang sudah ada di utama
        final utamaIds = rekUtama.map((e) => e.id).toSet();
        rekAlternatif.removeWhere((item) => utamaIds.contains(item.id));

      } catch (e) {
        // Fallback jika parsing JSON gagal
        aiText = rawText;
        debugPrint("Error Parsing JSON AI: $e");
      }

      // 4. Bangun pesan AI dengan item cards (2 section)
      if (mounted) {
        String displayText = aiText;

        // Section 1: Rekomendasi Utama (berdasarkan profil)
        if (rekUtama.isNotEmpty) {
          displayText += '\n\n🎯 Outfit Utama (Sesuai Profil):';
          for (var item in rekUtama) {
            displayText += '\n[ITEM:${item.id}]';
          }
        }

        // Section 2: Rekomendasi Alternatif (bebas & kreatif)
        if (rekAlternatif.isNotEmpty) {
          displayText += '\n\n✨ Alternatif Outfit:';
          for (var item in rekAlternatif) {
            displayText += '\n[ITEM:${item.id}]';
          }
        }

        setState(() {
          _messages.add(_ChatMessage(text: displayText, isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: 'Maaf, terjadi error: ${e.toString().split('\n').first}',
              isUser: false,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ITEM LOOKUP & PARSING
  // ═══════════════════════════════════════════════════════════════════════

  ClothingItem? _findItemById(String id) {
    try {
      return _wardrobeItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Parse teks AI menjadi segments: teks biasa dan item cards
  List<_MessageSegment> _parseMessage(String text) {
    final segments = <_MessageSegment>[];
    final regex = RegExp(r'\[ITEM:([^\]]+)\]');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        final textBefore = text.substring(lastEnd, match.start).trim();
        if (textBefore.isNotEmpty) {
          segments.add(_MessageSegment.text(textBefore));
        }
      }

      final itemId = match.group(1)!.trim();
      final item = _findItemById(itemId);
      if (item != null) {
        segments.add(_MessageSegment.item(item));
      } else {
        segments.add(_MessageSegment.text('[Item: $itemId]'));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        segments.add(_MessageSegment.text(remaining));
      }
    }

    if (segments.isEmpty) {
      segments.add(_MessageSegment.text(text));
    }

    return segments;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD UI
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 22, color: Colors.amber),
            SizedBox(width: 8),
            Text('Tanya AI'),
          ],
        ),
        centerTitle: false,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: !_isInitialized
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.deepPurple),
                        SizedBox(height: 16),
                        Text(
                          'Memuat data lemari & profil...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Bubble pesan (rich: teks + gambar item) ───────────────────────────
  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.purple.shade300],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? Colors.deepPurple : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isUser
                  ? SelectableText(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    )
                  : _buildRichContent(message.text),
            ),
          ),

          if (!isUser) const SizedBox(width: 40),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Render konten rich AI: campuran teks + kartu gambar item
  Widget _buildRichContent(String text) {
    final segments = _parseMessage(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: segments.map((segment) {
        if (segment.isItem) {
          return _buildItemCard(segment.item!);
        }
        return SelectableText(
          segment.text!,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            height: 1.4,
          ),
        );
      }).toList(),
    );
  }

  /// Kartu item inline — menampilkan gambar + nama + kategori
  Widget _buildItemCard(ClothingItem item) {
    final isLocal = !item.imageUrl.startsWith('http');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: SizedBox(
              width: 72,
              height: 72,
              child: isLocal
                  ? Image.file(
                      File(item.imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _brokenImage(),
                    )
                  : Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _brokenImage(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.deepPurple.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
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
                      const SizedBox(width: 4),
                      Text(
                        item.season,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _brokenImage() {
    return Container(
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.broken_image, size: 24, color: Colors.grey),
      ),
    );
  }

  // ── Typing indicator ──────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade400, Colors.purple.shade300],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.deepPurple.shade300,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI sedang berpikir...',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Tanya seputar fashion...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Colors.deepPurple.shade200,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.deepPurple.shade700],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: const Icon(Icons.send_rounded, size: 20),
                color: Colors.white,
                disabledColor: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper: Segment pesan (teks biasa atau item card)
// ═══════════════════════════════════════════════════════════════════════════
class _MessageSegment {
  final String? text;
  final ClothingItem? item;

  _MessageSegment._({this.text, this.item});

  factory _MessageSegment.text(String text) => _MessageSegment._(text: text);
  factory _MessageSegment.item(ClothingItem item) =>
      _MessageSegment._(item: item);

  bool get isItem => item != null;
}
