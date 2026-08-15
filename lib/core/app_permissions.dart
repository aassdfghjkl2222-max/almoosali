/// كتالوج صلاحيات ثابت في الكود (وليس جدولاً في قاعدة البيانات) — كل كود
/// يقابل شاشة/فعلاً معروفاً وقت التصريف، فلا حاجة لبنية بيانات وقت التشغيل.
/// user_permissions.permission_code يخزّن هذه القيم كنص حر (نفس نمط
/// financial_categories.type). راجع PermissionService لكيفية الفحص.
class PermissionDef {
  final String code;
  final String label;
  const PermissionDef(this.code, this.label);
}

class AppPermissions {
  AppPermissions._();

  // ---------------- التقارير المالية ----------------
  static const financialReportsView = 'financial_reports.view';
  static const financialReportsCreate = 'financial_reports.create';
  static const financialReportsEdit = 'financial_reports.edit';
  static const financialReportsDelete = 'financial_reports.delete';
  static const financialReportsExport = 'financial_reports.export';

  // ---------------- البيانات المالية ----------------
  static const financialDataView = 'financial_data.view';
  static const financialDataCreate = 'financial_data.create';
  static const financialDataEdit = 'financial_data.edit';
  static const financialDataDelete = 'financial_data.delete';

  // ---------------- الموظفون ----------------
  static const employeesView = 'employees.view';
  static const employeesCreate = 'employees.create';
  static const employeesEdit = 'employees.edit';
  static const employeesDelete = 'employees.delete';

  // ---------------- المستندات ----------------
  static const documentsView = 'documents.view';
  static const documentsCreate = 'documents.create';
  static const documentsEdit = 'documents.edit';
  static const documentsDelete = 'documents.delete';
  static const documentsDownload = 'documents.download';
  static const documentsShare = 'documents.share';

  // ---------------- الموردون ----------------
  static const suppliersView = 'suppliers.view';
  static const suppliersCreate = 'suppliers.create';
  static const suppliersEdit = 'suppliers.edit';
  static const suppliersDelete = 'suppliers.delete';

  // ---------------- الخزنة / الحركة المالية ----------------
  static const vaultView = 'vault.view';
  static const vaultCreate = 'vault.create';
  static const vaultEdit = 'vault.edit';
  static const vaultDelete = 'vault.delete';

  // ---------------- المخزون (توسّعي — لا شاشة تستهلكه بعد) ----------------
  static const inventoryView = 'inventory.view';
  static const inventoryCreate = 'inventory.create';
  static const inventoryEdit = 'inventory.edit';
  static const inventoryDelete = 'inventory.delete';
  static const inventoryMovement = 'inventory.movement';

  // ---------------- العقود ----------------
  static const contractsView = 'contracts.view';
  static const contractsCreate = 'contracts.create';
  static const contractsEdit = 'contracts.edit';
  static const contractsDelete = 'contracts.delete';

  // ---------------- الإعدادات ----------------
  static const settingsAccess = 'settings.access';
  static const settingsHotels = 'settings.hotels';
  static const settingsFinancialCategories = 'settings.financial_categories';
  static const settingsNotifications = 'settings.notifications';

  // ---------------- إدارة المستخدمين (حساسة إدارياً) ----------------
  static const usersView = 'users.view';
  static const usersCreate = 'users.create';
  static const usersEdit = 'users.edit';
  static const usersDisable = 'users.disable';
  static const usersChangePassword = 'users.change_password';
  static const usersManagePermissions = 'users.manage_permissions';
  static const usersManageHotelAccess = 'users.manage_hotel_access';

  /// دليل مُنظَّم حسب الوحدة — تبنيه شاشة تحديد صلاحيات المستخدم (شبكة
  /// checkboxes) تلقائياً بدل تكرار القوائم يدوياً في الواجهة.
  static const Map<String, List<PermissionDef>> catalog = {
    'التقارير المالية': [
      PermissionDef(financialReportsView, 'عرض التقرير المالي'),
      PermissionDef(financialReportsCreate, 'إضافة تقرير مالي'),
      PermissionDef(financialReportsEdit, 'تعديل التقرير المالي'),
      PermissionDef(financialReportsDelete, 'حذف التقرير المالي'),
      PermissionDef(financialReportsExport, 'تصدير التقرير'),
    ],
    'البيانات المالية': [
      PermissionDef(financialDataView, 'عرض البيانات المالية'),
      PermissionDef(financialDataCreate, 'إضافة بيانات مالية'),
      PermissionDef(financialDataEdit, 'تعديل البيانات المالية'),
      PermissionDef(financialDataDelete, 'حذف البيانات المالية'),
    ],
    'الموظفون': [
      PermissionDef(employeesView, 'عرض الموظفين'),
      PermissionDef(employeesCreate, 'إضافة موظف'),
      PermissionDef(employeesEdit, 'تعديل موظف'),
      PermissionDef(employeesDelete, 'حذف موظف'),
    ],
    'المستندات': [
      PermissionDef(documentsView, 'عرض المستندات'),
      PermissionDef(documentsCreate, 'إضافة مستند'),
      PermissionDef(documentsEdit, 'تعديل مستند'),
      PermissionDef(documentsDelete, 'حذف مستند'),
      PermissionDef(documentsDownload, 'تحميل مستند'),
      PermissionDef(documentsShare, 'مشاركة مستند'),
    ],
    'الموردون': [
      PermissionDef(suppliersView, 'عرض الموردين'),
      PermissionDef(suppliersCreate, 'إضافة مورد'),
      PermissionDef(suppliersEdit, 'تعديل مورد'),
      PermissionDef(suppliersDelete, 'حذف مورد'),
    ],
    'الخزنة': [
      PermissionDef(vaultView, 'عرض حركة الخزنة'),
      PermissionDef(vaultCreate, 'إضافة حركة خزنة'),
      PermissionDef(vaultEdit, 'تعديل حركة خزنة'),
      PermissionDef(vaultDelete, 'حذف حركة خزنة'),
    ],
    'العقود': [
      PermissionDef(contractsView, 'عرض العقود'),
      PermissionDef(contractsCreate, 'إضافة عقد'),
      PermissionDef(contractsEdit, 'تعديل عقد'),
      PermissionDef(contractsDelete, 'حذف عقد'),
    ],
    'الإعدادات': [
      PermissionDef(settingsAccess, 'الوصول للإعدادات'),
      PermissionDef(settingsHotels, 'تعديل إعدادات الفنادق'),
      PermissionDef(settingsFinancialCategories, 'تعديل الفئات المالية'),
      PermissionDef(settingsNotifications, 'إدارة الإشعارات'),
    ],
    'المستخدمون والصلاحيات': [
      PermissionDef(usersView, 'عرض المستخدمين'),
      PermissionDef(usersCreate, 'إضافة مستخدم'),
      PermissionDef(usersEdit, 'تعديل مستخدم'),
      PermissionDef(usersDisable, 'تعطيل/تفعيل مستخدم'),
      PermissionDef(usersChangePassword, 'تغيير كلمة مرور مستخدم'),
      PermissionDef(usersManagePermissions, 'إدارة الصلاحيات'),
      PermissionDef(usersManageHotelAccess, 'إدارة الوصول للفنادق'),
    ],
  };
}
