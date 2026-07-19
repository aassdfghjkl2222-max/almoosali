import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_preferences.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../services/invoice_ai/invoice_ai_service.dart';
import '../../services/security_service.dart';

/// إعدادات القراءة الذكية للفواتير — تفعيل/تعطيل، اختيار المزوّد
/// (Claude/OpenAI/Gemini)، ومفتاح API الخاص بكل مزوّد (مخزَّن عبر
/// SecurityService الآمن، وليس AppPreferences). يُستخدَم فقط عند غياب/فشل
/// قراءة رمز QR — لا علاقة له بأي بيانات فاتورة أخرى.
class AiInvoiceOcrSettingsPage extends StatefulWidget {
  const AiInvoiceOcrSettingsPage({super.key});

  @override
  State<AiInvoiceOcrSettingsPage> createState() => _AiInvoiceOcrSettingsPageState();
}

class _AiInvoiceOcrSettingsPageState extends State<AiInvoiceOcrSettingsPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEnabled = false;
  String _selectedProviderId = 'claude';
  final Map<String, TextEditingController> _keyControllers = {
    for (final p in InvoiceAiService.availableProviders) p.id: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final enabled = await AppPreferences.getBool(AppPreferences.keyAiOcrEnabled);
    final providerId = await AppPreferences.getString(AppPreferences.keyAiOcrProvider, defaultValue: 'claude');
    for (final provider in InvoiceAiService.availableProviders) {
      final key = await SecurityService.instance.getAiApiKey(provider.id);
      _keyControllers[provider.id]!.text = key ?? '';
    }
    if (!mounted) return;
    setState(() {
      _isEnabled = enabled;
      _selectedProviderId = providerId;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await AppPreferences.setBool(AppPreferences.keyAiOcrEnabled, _isEnabled);
    await AppPreferences.setString(AppPreferences.keyAiOcrProvider, _selectedProviderId);
    for (final provider in InvoiceAiService.availableProviders) {
      await SecurityService.instance.setAiApiKey(provider.id, _keyControllers[provider.id]!.text.trim());
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ الإعدادات")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("القراءة الذكية للفواتير", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildDisclosureBanner(),
                const SizedBox(height: AppSizes.lg),
                _buildCard([
                  SwitchListTile(
                    title: const Text("تفعيل القراءة الذكية"),
                    subtitle: const Text(
                      "عند غياب/فشل قراءة رمز QR في الفاتورة، تُستخدم لاستخراج بياناتها تلقائياً",
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _isEnabled,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: (v) => setState(() => _isEnabled = v),
                  ),
                ]),
                if (_isEnabled) ...[
                  const SizedBox(height: AppSizes.lg),
                  Text("المزوّد", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSizes.sm),
                  _buildCard([
                    for (final provider in InvoiceAiService.availableProviders)
                      RadioListTile<String>(
                        title: Text(provider.displayName),
                        value: provider.id,
                        groupValue: _selectedProviderId,
                        onChanged: (v) => setState(() => _selectedProviderId = v!),
                      ),
                  ]),
                  const SizedBox(height: AppSizes.lg),
                  Text(
                    "مفتاح API — ${InvoiceAiService.providerById(_selectedProviderId)?.displayName ?? ''}",
                    style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  _buildCard([
                    Padding(
                      padding: const EdgeInsets.all(AppSizes.md),
                      child: TextField(
                        key: ValueKey(_selectedProviderId),
                        controller: _keyControllers[_selectedProviderId],
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: "الصق مفتاح API هنا",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: AppSizes.xl),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("حفظ"),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDisclosureBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(color: AppColors.info.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.info),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "عند التفعيل، تُرسَل صورة/ملف الفاتورة إلى خدمة الذكاء الاصطناعي الخارجية المُختارة لاستخراج بياناتها منها — فقط عند تعذّر قراءة رمز QR. لا تُرسَل أي صورة إن كانت قراءة الرمز وحدها كافية.",
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Column(children: children),
    );
  }
}
