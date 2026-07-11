/// مستند خاص بالموظف نفسه (وليس بالفندق) — ينتقل معه تلقائياً عند النقل بين الفنادق.
class EmployeeDocument {
  final int? id;
  final int employeeId;
  final String type; // هوية | إقامة | عقد | جواز | شهادة | أخرى
  final String name;
  final String? expiryDate;
  final String? notes;
  final String createdAt;

  const EmployeeDocument({
    this.id,
    required this.employeeId,
    required this.type,
    required this.name,
    this.expiryDate,
    this.notes,
    required this.createdAt,
  });

  static const types = ['هوية', 'إقامة', 'عقد عمل', 'جواز سفر', 'شهادة', 'أخرى'];

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'type': type,
      'name': name,
      'expiry_date': expiryDate,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory EmployeeDocument.fromMap(Map<String, dynamic> map) {
    return EmployeeDocument(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      type: map['type'] as String,
      name: map['name'] as String,
      expiryDate: map['expiry_date'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
