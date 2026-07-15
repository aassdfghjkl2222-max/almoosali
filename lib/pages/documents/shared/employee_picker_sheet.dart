import 'package:flutter/material.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/employee.dart';

/// نافذة اختيار موظف واحد من موظفي كل الفنادق — بحث فوري بالاسم أو الرقم
/// الوظيفي، مع عرض اسم الفندق التابع له كل موظف. مشتركة بين أي مكان في محرك
/// المستندات يحتاج ربط مستند بموظف أو تصفية قائمة حسب موظف (بلا تكرار كود).
/// عند [allowClear]=true تُضاف خيار "كل الموظفين" أعلى القائمة، ويُعاد `0`
/// (لا يمكن أن يكون معرّف موظف حقيقي) كإشارة على إلغاء التصفية.
Future<int?> showEmployeePicker(
  BuildContext context, {
  required List<Employee> employees,
  required Map<int, String> hotelNames,
  bool allowClear = false,
  String title = "اختيار موظف",
}) {
  final controller = TextEditingController();
  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final query = controller.text.trim();
        final filtered = employees.where((e) {
          if (query.isEmpty) return true;
          return e.name.contains(query) || (e.employeeNumber?.contains(query) ?? false);
        }).toList();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.8),
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppTextStyles.title.copyWith(fontSize: 17)),
                const SizedBox(height: AppSizes.sm),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    hintText: "بحث بالاسم أو الرقم الوظيفي",
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (allowClear)
                        ListTile(
                          leading: const Icon(Icons.people_outline),
                          title: const Text("كل الموظفين"),
                          onTap: () => Navigator.pop(sheetContext, 0),
                        ),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSizes.md),
                          child: Center(child: Text("لا يوجد موظفون مطابقون", style: AppTextStyles.caption)),
                        )
                      else
                        ...filtered.map((e) => ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(e.name),
                              subtitle: Text("${e.position} — ${hotelNames[e.hotelId] ?? '—'}", style: AppTextStyles.caption),
                              onTap: () => Navigator.pop(sheetContext, e.id),
                            )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
