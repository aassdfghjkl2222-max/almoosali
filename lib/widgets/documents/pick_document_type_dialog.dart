import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/document_type.dart';
import '../../repositories/document_type_repository.dart';

/// اختيار نوع مستند من البيانات المرجعية — نقطة الدخول الوحيدة لإضافة
/// مستند جديد لأي جهة يُشترط عليها اختيار نوع مرجعي بدل اسم حر (كالموردين)،
/// بلا أي إنشاء نوع جديد من هنا (ممنوع صراحة على مستوى الجهات المالكة).
Future<DocumentType?> showPickDocumentTypeDialog({
  required BuildContext context,
  String title = "اختر نوع المستند",
}) async {
  final types = await DocumentTypeRepository().getTypes(includeInactive: false);
  if (!context.mounted) return null;

  if (types.isEmpty) {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("لا توجد أنواع مستندات"),
        content: const Text("لم يتم تعريف أي نوع مستند مفعَّل بعد في البيانات المرجعية. أضف الأنواع أولاً من قسم البيانات المرجعية."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً"))],
      ),
    );
    return null;
  }

  String query = '';
  return showModalBottomSheet<DocumentType>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final visible = query.trim().isEmpty
            ? types
            : types.where((t) => t.name.contains(query.trim()) || (t.categoryName?.contains(query.trim()) ?? false)).toList();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppTextStyles.title.copyWith(fontSize: 17)),
                const SizedBox(height: AppSizes.sm),
                TextField(
                  autofocus: false,
                  onChanged: (v) => setSheetState(() => query = v),
                  decoration: InputDecoration(
                    hintText: "بحث عن نوع مستند",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                const Divider(height: 1),
                Flexible(
                  child: visible.isEmpty
                      ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text("لا توجد نتائج مطابقة", style: AppTextStyles.caption)))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final type = visible[index];
                            return ListTile(
                              leading: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(color: Color(type.categoryColor ?? 0xFF7A1E2C), shape: BoxShape.circle),
                              ),
                              title: Text(type.name, style: AppTextStyles.bodyBold),
                              subtitle: Text(type.categoryName ?? '', style: AppTextStyles.caption),
                              onTap: () => Navigator.pop(sheetContext, type),
                            );
                          },
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
