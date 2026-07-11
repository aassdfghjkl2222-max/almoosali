import '../core/database/database_service.dart';
import '../models/expense_category.dart';
import '../models/pending_expense.dart';

class ExpenseRepository {
  final _dbService = DatabaseService();

  Future<List<ExpenseCategory>> getCategories(int hotelId) async {
    final data = await _dbService.getExpenseCategories(hotelId);
    return data.map((map) => ExpenseCategory.fromMap(map)).toList();
  }

  Future<int> addCategory(ExpenseCategory category) async {
    return await _dbService.insertExpenseCategory(category.toMap());
  }

  Future<int> updateCategory(ExpenseCategory category) async {
    if (category.id == null) return 0;
    return await _dbService.updateById('expense_categories', category.toMap(), category.id!);
  }

  Future<int> deleteCategory(int id) async {
    return await _dbService.deleteById('expense_categories', id);
  }

  Future<void> updateCategoriesOrder(List<ExpenseCategory> categories) async {
    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i].copyWith(sortOrder: i);
      await updateCategory(cat);
    }
  }

  Future<List<PendingExpense>> getPendingExpenses({int? hotelId, bool? isTransferred}) async {
    if (hotelId == null) return [];
    final data = await _dbService.getPendingExpenses(hotelId: hotelId, isTransferred: isTransferred);
    return data.map((map) => PendingExpense.fromMap(map)).toList();
  }

  Future<int> addPendingExpense(PendingExpense expense) async {
    return await _dbService.insertPendingExpense(expense.toMap());
  }

  Future<int> updatePendingExpense(PendingExpense expense) async {
    if (expense.id == null) return 0;
    return await _dbService.updateById('pending_expenses', expense.toMap(), expense.id!);
  }

  Future<int> deletePendingExpense(int id) async {
    return await _dbService.deleteById('pending_expenses', id);
  }

  Future<void> transferExpenses(List<int> ids) async {
    await _dbService.transferPendingExpenses(ids);
  }
}
