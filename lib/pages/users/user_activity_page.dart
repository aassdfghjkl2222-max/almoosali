import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/user.dart';

/// سجل نشاط مستخدم واحد — عرض فقط. آخر تسجيل دخول والأجهزة وعدد العمليات
/// وسجل العمليات تحتاج نظام دخول متعدد مستخدمين فعلياً مرتبطاً بهذه الحسابات
/// (التطبيق حالياً يعتمد دخولاً موحّداً برمز PIN لا يميّز بين المستخدمين)،
/// لذا تُعرض هذه الحقول بصدق كبيانات غير متوفرة بعد بدل تلفيقها، وجاهزة
/// للتفعيل الفعلي فور ربط تسجيل الدخول بحساب كل مستخدم.
class UserActivityPage extends StatelessWidget {
  final User user;

  const UserActivityPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("سجل النشاط", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Card(
            elevation: 0,
            color: primary.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: primary.withOpacity(0.15),
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName.substring(0, 1) : "?",
                      style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: AppTextStyles.title.copyWith(fontSize: 17)),
                        Text(user.username, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (user.isActive ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      user.isActive ? "نشط" : "معلَّق",
                      style: TextStyle(color: user.isActive ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(color: AppColors.info.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.info),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "التطبيق يعتمد حالياً دخولاً موحّداً برمز PIN، لذا لا يوجد بعد تتبّع فعلي لتسجيل الدخول أو الأجهزة أو العمليات لكل مستخدم على حِدة. ستُعرض هذه البيانات فعلياً فور ربط تسجيل الدخول بحساب كل مستخدم.",
                    style: TextStyle(fontSize: 11, color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          _buildInfoCard(context, [
            _InfoRow(Icons.login_rounded, "آخر تسجيل دخول", user.createdAt != null ? "منذ إنشاء الحساب: ${_formatDate(user.createdAt!)}" : "غير متوفر"),
            _InfoRow(Icons.devices_other_outlined, "الأجهزة المستخدمة", "غير متوفر بعد"),
            _InfoRow(Icons.bar_chart_outlined, "عدد العمليات", "غير متوفر بعد"),
            _InfoRow(Icons.access_time_outlined, "آخر نشاط", "غير متوفر بعد"),
          ]),
          const SizedBox(height: AppSizes.lg),
          Text("سجل العمليات المنفَّذة", style: AppTextStyles.subtitle.copyWith(color: primary, fontSize: 15)),
          const SizedBox(height: AppSizes.sm),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
                  const SizedBox(height: AppSizes.sm),
                  const Text("لا يوجد سجل عمليات مسجَّل بعد لهذا المستخدم", style: AppTextStyles.caption, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return DateFormat('yyyy/MM/dd', 'ar').format(date);
  }

  Widget _buildInfoCard(BuildContext context, List<_InfoRow> rows) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            ListTile(
              leading: Icon(rows[i].icon, color: primary),
              title: Text(rows[i].label, style: AppTextStyles.body.copyWith(fontSize: 13)),
              trailing: Text(rows[i].value, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
            ),
            if (i != rows.length - 1) const Divider(height: 1, indent: 50),
          ],
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);
}
