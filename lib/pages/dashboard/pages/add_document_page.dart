import 'package:flutter/material.dart';
import '../../../models/document.dart';
import '../../../repositories/document_repository.dart';
import '../../../widgets/common/app_dialog.dart';

class AddDocumentPage extends StatefulWidget {
  final int hotelId;
  const AddDocumentPage({super.key, required this.hotelId});

  @override
  State<AddDocumentPage> createState() => _AddDocumentPageState();
}

class _AddDocumentPageState extends State<AddDocumentPage> {
  final nameController = TextEditingController();
  final expiryDateController = TextEditingController();
  DateTime? selectedDate;

  @override
  void dispose() {
    nameController.dispose();
    expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        expiryDateController.text = picked.toString().split(' ')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إضافة مستند"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "اسم المستند",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: expiryDateController,
              readOnly: true,
              onTap: () => _selectDate(context),
              decoration: const InputDecoration(
                labelText: "تاريخ الانتهاء",
                suffixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty && selectedDate != null) {
                    await AppDialog.confirmAction(
                      context: context,
                      title: "تأكيد إضافة المستند",
                      message: "هل تريد إضافة هذا المستند؟",
                      onConfirm: () async {
                        final repository = DocumentRepository();
                        final newDocument = Document(
                          hotelId: widget.hotelId,
                          name: name,
                          expiryDate: selectedDate!.toString().split(' ')[0],
                          createdAt: DateTime.now().toString().split(' ')[0],
                        );
                        await repository.addDocument(newDocument);
                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                    );
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("يرجى ملء جميع الحقول"),
                        ),
                      );
                    }
                  }
                },
                child: const Text("حفظ"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}