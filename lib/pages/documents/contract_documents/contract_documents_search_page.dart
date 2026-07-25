import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_page_route.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/contract_document_options.dart';
import '../../../repositories/contract_document_repository.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_text_field.dart';
import 'contract_folder_browser_page.dart';
import 'document_details_sheet.dart';
import 'widgets/contract_empty_state.dart';

/// بحث فوري عبر شجرة مستندات العقود بالكامل — اسم المجلد/المستند، الوسوم،
/// الوصف، الملاحظات، الفئة، اسم الملف (راجع ContractDocumentRepository.searchAll).
class ContractDocumentsSearchPage extends StatefulWidget {
  const ContractDocumentsSearchPage({super.key});

  @override
  State<ContractDocumentsSearchPage> createState() => _ContractDocumentsSearchPageState();
}

class _ContractDocumentsSearchPageState extends State<ContractDocumentsSearchPage> {
  final _repo = ContractDocumentRepository();
  final _controller = TextEditingController();
  List<ContractSearchResult> _results = [];
  bool _searched = false;

  Future<void> _onChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    final results = await _repo.searchAll(query);
    if (!mounted) return;
    setState(() { _results = results; _searched = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("بحث في مستندات العقود", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: AppTextField(controller: _controller, hint: "ابحث بالاسم، الوسوم، الفئة، الملاحظات...", icon: Icons.search_rounded, onChanged: _onChanged),
          ),
          Expanded(
            child: !_searched
                ? const ContractEmptyState(icon: Icons.search_rounded, title: "ابدأ الكتابة للبحث", message: "يشمل البحث كل المجلدات والمستندات في كل الأعماق.")
                : _results.isEmpty
                    ? const ContractEmptyState(icon: Icons.search_off_rounded, title: "لا نتائج مطابقة", message: "جرّب كلمات بحث مختلفة.")
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                        itemCount: _results.length,
                        itemBuilder: (context, i) => Padding(padding: const EdgeInsets.only(bottom: AppSizes.sm), child: _buildResult(_results[i])),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(ContractSearchResult result) {
    if (result.isFolder) {
      final f = result.folder!;
      final color = Color(f.colorValue);
      return AppCard(
        identityAccent: color,
        onTap: () => Navigator.push(context, premiumRoute(ContractFolderBrowserPage(folderId: f.id))),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)), child: Icon(ContractFolderIcons.iconFor(f.iconKey), color: color, size: 20)),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                  Text(result.pathLabel, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final d = result.document!;
    final color = ContractFileTypes.colorFor(d.fileType);
    return AppCard(
      identityAccent: color,
      onTap: () async {
        final result2 = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => DocumentDetailsSheet(document: d));
        if (result2 == true) _onChanged(_controller.text);
      },
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)), child: Icon(ContractFileTypes.iconFor(d.fileType), color: color, size: 20)),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                Text(result.pathLabel, style: AppTextStyles.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
