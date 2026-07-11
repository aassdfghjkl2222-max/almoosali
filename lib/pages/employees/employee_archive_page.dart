import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/hotel_visual_identity.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/employee.dart';
import '../../models/hotel.dart';
import '../../repositories/employee_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/hotel_identity_title.dart';
import 'employee_details_page.dart';

/// أرشيف الموظفين — لا يوجد حذف نهائي في النظام؛ كل موظف مؤرشف يحتفظ بكامل سجله.
class EmployeeArchivePage extends StatefulWidget {
  final Hotel hotel;
  const EmployeeArchivePage({super.key, required this.hotel});

  @override
  State<EmployeeArchivePage> createState() => _EmployeeArchivePageState();
}

class _EmployeeArchivePageState extends State<EmployeeArchivePage> {
  final _repository = EmployeeRepository();
  late Future<List<Employee>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _repository.getArchivedEmployees(widget.hotel.id);
    });
  }

  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "أرشيف الموظفين", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: _identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Employee>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }
          final employees = snapshot.data ?? [];
          if (employees.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.archive_outlined, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: AppSizes.md),
                  const Text("الأرشيف فارغ", style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSizes.md),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employee = employees[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.md),
                child: AppCard(
                  identityAccent: _identityColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EmployeeDetailsPage(hotel: widget.hotel, employee: employee)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.textSecondary.withOpacity(0.1),
                        child: const Icon(Icons.person_off_outlined, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(employee.name, style: AppTextStyles.bodyBold),
                            Text(employee.position, style: AppTextStyles.caption),
                            if (employee.employeeNumber != null)
                              Text(employee.employeeNumber!, style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_left, color: _identityColor, size: 20),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
