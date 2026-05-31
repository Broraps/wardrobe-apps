import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../model/LookbookItem.dart';
import '../services/LookbookService.dart';
import 'LookbookPage.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  final LookbookService _lookbookService = LookbookService();

  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<LookbookItem> _allItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLookbook();
  }

  Future<void> _loadLookbook() async {
    final items = await _lookbookService.getAll();
    setState(() {
      _allItems = items;
      _isLoading = false;
    });
  }

  /// Ambil outfit yang dijadwalkan untuk hari tertentu (dipakai eventLoader)
  List<LookbookItem> _getEventsForDay(DateTime day) {
    return _lookbookService.getForDate(_allItems, day);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outfit Planner'),
        actions: [
          // Tombol refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadLookbook,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Kalender ──────────────────────────────────────────────────────
          TableCalendar<LookbookItem>(
            locale: 'id_ID',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            calendarStyle: CalendarStyle(
              // Dot marker untuk hari yang ada outfit
              markerDecoration: BoxDecoration(
                color: Colors.deepPurple.shade400,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              formatButtonTextStyle: TextStyle(color: Colors.white),
            ),
          ),

          const Divider(height: 1),

          // ── Konten bawah kalender ─────────────────────────────────────────
          Expanded(
            child: _selectedDay == null
                ? _buildNoDateSelected()
                : _buildDayContent(_selectedDay!),
          ),
        ],
      ),
    );
  }

  // ── Belum pilih tanggal ───────────────────────────────────────────────────
  Widget _buildNoDateSelected() {
    return Center(
      child: Text(
        'Pilih tanggal untuk melihat\nrencana outfit kamu 👗',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[500], fontSize: 15),
      ),
    );
  }

  // ── Konten untuk tanggal yang dipilih ────────────────────────────────────
  Widget _buildDayContent(DateTime day) {
    final outfits = _getEventsForDay(day);
    final isToday = isSameDay(day, DateTime.now());
    final isPast = day.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    return RefreshIndicator(
      onRefresh: _loadLookbook,
      child: CustomScrollView(
        slivers: [
          // Header tanggal
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE').format(day),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        DateFormat('d MMMM yyyy').format(day),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Hari Ini',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Jika tidak ada outfit untuk hari ini
          if (outfits.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyDay(isPast),
            )
          else
            // List outfit yang dijadwalkan
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _OutfitPlanCard(
                    item: outfits[i],
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              LookbookDetailPage(item: outfits[i]),
                        ),
                      );
                      _loadLookbook();
                    },
                  ),
                  childCount: outfits.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Empty state untuk hari tanpa outfit ──────────────────────────────────
  Widget _buildEmptyDay(bool isPast) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPast ? Icons.history : Icons.add_a_photo_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isPast
                  ? 'Tidak ada outfit\npada hari ini.'
                  : 'Belum ada rencana outfit.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPast
                  ? 'Outfit masa lalu tidak bisa ditambah.'
                  : 'Buat outfit di Canvas DIY, lalu jadwalkan\nke tanggal ini saat menyimpan ke Lookbook.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
            if (!isPast) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  // Navigasi ke tab Styling (index 0)
                  // Menggunakan DefaultTabController tidak bisa dari sini,
                  // jadi tampilkan hint ke user
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '💡 Pergi ke tab Styling → Canvas DIY untuk membuat outfit!',
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.gesture),
                label: const Text('Buat di Canvas DIY'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card outfit di Planner
// ─────────────────────────────────────────────────────────────────────────────
class _OutfitPlanCard extends StatelessWidget {
  final LookbookItem item;
  final VoidCallback onTap;

  const _OutfitPlanCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Thumbnail outfit
            SizedBox(
              width: 90,
              height: 90,
              child: Image.file(
                File(item.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.bookmark,
                          size: 13,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Dari Lookbook',
                          style: TextStyle(
                            color: Colors.deepPurple[300],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dibuat ${DateFormat('d MMM yyyy').format(item.createdAt)}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Arrow icon
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
