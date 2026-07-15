import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/hotel.dart';
import '../../../models/relationship_txn.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import 'relationship_txn_detail_page.dart';

/// قائمة عمليات — تُستخدم لكل من: كل عمليات فندق/شخص/مورد محدد (البند ٣)،
/// وكل العمليات التي كوّنت رقماً مُعيَّناً عند الضغط عليه (البند ٩) — نفس
/// المكوّن يخدم الحالتين لتفادي تكرار الملفات.
class RelationshipTxnListPage extends StatelessWidget {
  final Hotel contextHotel;
  final String title;
  final List<RelationshipTxn> txns;
  final Color color;

  const RelationshipTxnListPage({super.key, required this.contextHotel, required this.title, required this.txns, required this.color});

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(contextHotel);
    final total = txns.fold(0.0, (s, t) => s + (t.isReceivable ? t.amount : -t.amount));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: title, hotel: contextHotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
      ),
      body: txns.isEmpty
          ? const Center(child: Text("لا توجد عمليات مسجلة", style: TextStyle(color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Column(
                      children: [
                        const Text("صافي العمليات المعروضة", style: AppTextStyles.caption),
                        Text(_format(total), style: AppTextStyles.title.copyWith(fontSize: 24, color: color, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                Text("العمليات (${txns.length})", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: AppSizes.sm),
                ...txns.map((t) => _buildRow(context, t)),
              ],
            ),
    );
  }

  Widget _buildRow(BuildContext context, RelationshipTxn t) {
    final rowColor = t.isReceivable ? AppColors.success : AppColors.danger;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: rowColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(t.isReceivable ? Icons.call_received : Icons.call_made, color: rowColor, size: 18),
        ),
        title: Text(t.counterpartyName, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text("${DateFormat('yyyy-MM-dd').format(t.date)} · ${t.operationType}", style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_format(t.amount), style: AppTextStyles.bodyBold.copyWith(color: rowColor)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => RelationshipTxnDetailPage(contextHotel: contextHotel, txn: t, color: color)));
        },
      ),
    );
  }
}
