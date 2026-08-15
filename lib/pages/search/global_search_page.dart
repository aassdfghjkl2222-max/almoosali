import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/hotel.dart';
import '../../repositories/hotel_repository.dart';
import '../../services/search/global_search_result.dart';
import '../../services/search/global_search_service.dart';

/// شاشة البحث الشامل — تُفتح حصراً من الشاشة الرئيسية (راجع hotels_page.dart).
/// تركيز تلقائي فوري + لوحة مفاتيح تفتح مباشرة + بحث فوري أثناء الكتابة
/// (بلا زر بحث)، مع تأخير قصير (debounce) قبل كل استعلام فعلي لتفادي تنفيذ
/// استعلام كامل عبر كل الوحدات مع كل ضغطة مفتاح — لا يزال هذا "بحثاً فورياً"
/// من منظور المستخدم (أقل من ربع ثانية)، لكنه يحمي الأداء مع قواعد بيانات
/// كبيرة فعلاً.
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  static const _debounceDuration = Duration(milliseconds: 200);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _service = GlobalSearchService();

  Timer? _debounceTimer;
  int _requestId = 0;
  List<Hotel> _allHotels = [];
  List<GlobalSearchModuleResults> _results = [];
  bool _isLoadingHotels = true;
  bool _isSearching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  Future<void> _bootstrap() async {
    final hotels = await HotelRepository().getAllHotels();
    if (!mounted) return;
    setState(() {
      _allHotels = hotels;
      _isLoadingHotels = false;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounceTimer = Timer(_debounceDuration, () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    final requestId = ++_requestId;
    final results = await _service.search(value, allHotels: _allHotels);
    // نتيجة استعلام سابق أبطأ قد تصل بعد استعلام أحدث — تُهمَل حتى لا
    // "تُرجع" النتائج المعروضة إلى نص بحث قديم.
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  int get _totalResultCount => _results.fold(0, (sum, group) => sum + group.results.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: AppSizes.sm,
        title: _buildSearchField(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        onChanged: _onQueryChanged,
        decoration: InputDecoration(
          hintText: 'ابحث في كل أقسام التطبيق...',
          hintStyle: AppTextStyles.caption,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _controller.clear();
                    _onQueryChanged('');
                  },
                ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingHotels) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_query.trim().isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        message: 'ابدأ الكتابة للبحث في الفنادق والموظفين والمستندات والعقود وكل أقسام التطبيق',
      );
    }
    // يُعرَض المؤشر فقط عند أول بحث (لا نتائج سابقة بعد) — بعدها، ولو كان
    // استعلام جديد قيد التنفيذ بسبب الكتابة المستمرة، تبقى آخر نتائج معروفة
    // ظاهرة حتى تصل النتائج الجديدة، بدل وميض مؤشر تحميل مع كل ضغطة مفتاح.
    if (_isSearching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isSearching && _totalResultCount == 0) {
      return _buildEmptyState(icon: Icons.search_off, message: 'لا توجد نتائج مطابقة لـ"$_query"');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildModuleGroup(_results[index]),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: AppSizes.md),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleGroup(GlobalSearchModuleResults group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.xs),
          child: Row(
            children: [
              Icon(group.provider.moduleIcon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '${group.provider.moduleLabel} (${group.results.length})',
                style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.primary),
              ),
            ],
          ),
        ),
        ...group.results.map((r) => _buildResultTile(r, group.provider.moduleIcon)),
      ],
    );
  }

  Widget _buildResultTile(GlobalSearchResult result, IconData moduleIcon) {
    final subtitleParts = <String>[
      if (result.subtitle != null && result.subtitle!.trim().isNotEmpty) result.subtitle!,
      if (result.relatedHotelName != null && result.relatedHotelName!.trim().isNotEmpty) result.relatedHotelName!,
    ];
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: Icon(moduleIcon, size: 18, color: AppColors.primary),
      ),
      title: Text(result.title, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(subtitleParts.join(' • '), style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      onTap: () {
        FocusScope.of(context).unfocus();
        result.onTap(context);
      },
    );
  }
}
