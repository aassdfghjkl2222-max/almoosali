import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/database/database_service.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/hotel_identity_title.dart';

/// كل حركات حساب معيّن (نقد/بنك) عبر الفنادق المختارة — بيانات حقيقية من
/// financial_ledger مباشرة، للقراءة فقط. يُستخدم من بطاقات "النقد/البنك/الخزنة"
/// في مركز التحليل، حيث لا يوجد لهذه البطاقات صفحة تفصيل جاهزة أصلاً.
class CashMovementsListPage extends StatefulWidget {
  final Hotel hotel;
  final String title;
  final String category; // 'cash' أو 'bank'
  final List<int> hotelIds;
  final Map<int, String> hotelNames;
  final DateTime? fromDate;
  final DateTime? toDate;
  final Color color;

  const CashMovementsListPage({
    super.key,
    required this.hotel,
    required this.title,
    required this.category,
    required this.hotelIds,
    required this.hotelNames,
    required this.color,
    this.fromDate,
    this.toDate,
  });

  @override
  State<CashMovementsListPage> createState() => _CashMovementsListPageState();
}

class _CashMovementsListPageState extends State<CashMovementsListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _entries = [];
  final _searchController = TextEditingController();
  String _search = "";

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredEntries {
    if (_search.isEmpty) return _entries;
    final q = _search.toLowerCase();
    return _entries.where((e) {
      return (e['description'] as String).toLowerCase().contains(q) ||
          (e['date'] as String).contains(q) ||
          e['amount'].toString().contains(q) ||
          (widget.hotelNames[e['hotel_id']] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _load() async {
    final db = await DatabaseService().database;
    if (widget.hotelIds.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    final where = <String>[
      'fl.hotel_id IN (${List.filled(widget.hotelIds.length, '?').join(',')})',
      'fa.category = ?',
    ];
    final args = <dynamic>[...widget.hotelIds, widget.category];
    if (widget.fromDate != null) {
      where.add('fl.date >= ?');
      args.add(_fmt(widget.fromDate!));
    }
    if (widget.toDate != null) {
      where.add('fl.date <= ?');
      args.add(_fmt(widget.toDate!));
    }
    final rows = await db.rawQuery(
      '''
      SELECT fl.* FROM financial_ledger fl JOIN financial_accounts fa ON fl.account_id = fa.id
      WHERE ${where.join(' AND ')}
      ORDER BY fl.date DESC, fl.time DESC
      LIMIT 500
      ''',
      args,
    );
    if (!mounted) return;
    setState(() {
      _entries = rows;
      _isLoading = false;
    });
  }

  String _fmt(DateTime d) => "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  String _format(num v) => NumberFormat("#,##0.##").format(v);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    final filtered = _filteredEntries;
    final total = filtered.fold(0.0, (s, e) => s + (e['type'] == 'debit' ? (e['amount'] as num) : -(e['amount'] as num)));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: widget.title, hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text("لا توجد حركات مسجلة", style: TextStyle(color: Colors.grey)))
              : ListView(
                  padding: const EdgeInsets.all(AppSizes.md),
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v.trim()),
                      decoration: InputDecoration(
                        hintText: "بحث بالوصف أو التاريخ أو المبلغ أو الفندق...",
                        hintStyle: AppTextStyles.caption,
                        prefixIcon: Icon(Icons.search, color: widget.color),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: widget.color.withOpacity(0.2))),
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    AppCard(
                      identityAccent: widget.color,
                      child: Column(
                        children: [
                          const Text("صافي الحركات المعروضة", style: AppTextStyles.caption),
                          Text(_format(total), style: AppTextStyles.title.copyWith(fontSize: 24, color: widget.color, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.lg),
                    Text("الحركات (${filtered.length}${_entries.length >= 500 ? '+' : ''})", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: AppSizes.sm),
                    if (filtered.isEmpty)
                      const Padding(padding: EdgeInsets.all(16), child: Center(child: Text("لا توجد نتائج مطابقة", style: AppTextStyles.caption)))
                    else
                      ...filtered.map((e) => _buildRow(e)),
                  ],
                ),
    );
  }

  Widget _buildRow(Map<String, dynamic> e) {
    final isPositive = e['type'] == 'debit';
    final color = isPositive ? AppColors.success : AppColors.danger;
    final hotelName = widget.hotelNames[e['hotel_id']] ?? 'فندق #${e['hotel_id']}';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline, color: color, size: 18),
        ),
        title: Text(e['description'] as String, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text("$hotelName · ${e['date']} ${e['time']}", style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text("${isPositive ? '+' : '-'}${_format(e['amount'] as num)}", style: AppTextStyles.bodyBold.copyWith(color: color)),
      ),
    );
  }
}
