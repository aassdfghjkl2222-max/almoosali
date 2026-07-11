import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/note.dart';
import '../../repositories/note_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/app_loading.dart';
import '../../models/hotel.dart';
import '../../widgets/common/hotel_identity_title.dart';

class NotesPage extends StatefulWidget {
  final Hotel hotel;
  const NotesPage({super.key, required this.hotel});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _repository = NoteRepository();

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "المذكرات", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: AppDrawer(hotel: widget.hotel),
      body: FutureBuilder<List<Note>>(
        future: _repository.getAllNotes(widget.hotel.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }

          final notes = snapshot.data ?? [];

          if (notes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_alt_outlined, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: AppSizes.md),
                  Text(
                    "لا توجد مذكرات حتى الآن",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSizes.md),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.md),
                child: _buildNoteCard(note),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNoteDialog(context),
        backgroundColor: identityColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    return AppCard(
      onTap: () => _showNoteDetails(note),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.secondary, size: 20),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  note.title,
                  style: AppTextStyles.title.copyWith(fontSize: 16),
                ),
              ),
              Text(
                note.createdAt,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            note.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showNoteDetails(Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(note.title, style: AppTextStyles.title),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: AppSizes.md),
            Text(note.content, style: AppTextStyles.body),
            const SizedBox(height: AppSizes.xl),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteNote(note.id!);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text("حذف"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
          ],
        ),
      ),
    );
  }

  void _deleteNote(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("حذف المذكرة"),
        content: const Text("هل أنت متأكد من حذف هذه المذكرة؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("حذف", style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteNote(id);
      setState(() {});
    }
  }

  void _showAddNoteDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إضافة مذكرة جديدة"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(hintText: "العنوان"),
            ),
            const SizedBox(height: AppSizes.md),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(hintText: "المحتوى"),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                Navigator.pop(context);
                await AppDialog.confirmAction(
                  context: this.context,
                  title: "تأكيد إضافة المذكرة",
                  message: "هل تريد إضافة هذه المذكرة؟",
                  onConfirm: () async {
                    await _repository.addNote(Note(
                      hotelId: widget.hotel.id!,
                      title: titleController.text,
                      content: contentController.text,
                      createdAt: DateTime.now().toString().split(' ')[0],
                    ));
                    setState(() {});
                  },
                );
              }
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }
}
