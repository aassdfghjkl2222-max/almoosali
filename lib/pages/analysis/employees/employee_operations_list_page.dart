import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/hotel.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';

/// عنصر عملية موظف عام (سلفة/خصم/بدل/حركة سجل وظيفي) — تمثيل موحّد يخدم كل
/// أنواع عمليات الموظفين بشاشة واحدة بدل تكرار أربع شاشات شبه متطابقة.
class EmployeeOperationItem {
  final String employeeName;
  final String title;
  final String subtitle;
  final double? amount;
  final String date;
  const EmployeeOperationItem({required this.employeeName, required this.title, required this.subtitle, this.amount, required this.date});
}

class EmployeeOperationsListPage extends StatelessWidget {
  final Hotel hotel;
  final String title;
  final List<EmployeeOperationItem> items;
  final Color color;

  const EmployeeOperationsListPage({super.key, required this.hotel, required this.title, required this.items, required this.color});

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    final total = items.fold(0.0, (s, i) => s + (i.amount ?? 0));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: title, hotel: hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
      ),
      body: items.isEmpty
          ? const Center(child: Text("لا توجد عمليات مسجلة", style: TextStyle(color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                if (total > 0)
                  AppCard(
                    identityAccent: color,
                    child: Column(
                      children: [
                        const Text("الإجمالي", style: AppTextStyles.caption),
                        Text(_format(total), style: AppTextStyles.title.copyWith(fontSize: 24, color: color, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                if (total > 0) const SizedBox(height: AppSizes.lg),
                Text("العمليات (${items.length})", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: AppSizes.sm),
                ...items.map((i) => Card(
                      margin: const EdgeInsets.only(bottom: AppSizes.sm),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(Icons.person_outline, color: color, size: 18),
                        ),
                        title: Text(i.employeeName, style: AppTextStyles.bodyBold),
                        subtitle: Text("${i.subtitle} · ${i.date}", style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: i.amount != null ? Text(_format(i.amount!), style: AppTextStyles.bodyBold.copyWith(color: color)) : null,
                      ),
                    )),
              ],
            ),
    );
  }
}
