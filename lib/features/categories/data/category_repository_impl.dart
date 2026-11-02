import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/features/categories/domain/category.dart';
import 'package:task_check/features/categories/domain/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final AppDatabase _db;

  CategoryRepositoryImpl(this._db);

  @override
  Stream<List<Category>> watchCategories() {
    return _db.watchCategories();
  }

  @override
  Future<List<Category>> getAllCategories() {
    return _db.getAllCategories();
  }

  @override
  Future<Category?> getCategoryById(String id) {
    return _db.getCategoryById(id);
  }

  @override
  Future<void> createCategory(Category category) {
    return _db.insertCategory(category);
  }

  @override
  Future<void> updateCategory(Category category) {
    return _db.updateCategory(category);
  }

  @override
  Future<void> deleteCategory(String id) {
    return _db.deleteCategory(id);
  }
}
