import 'package:task_check/features/categories/domain/category.dart';

abstract class CategoryRepository {
  Stream<List<Category>> watchCategories();
  Future<List<Category>> getAllCategories();
  Future<Category?> getCategoryById(String id);
  Future<void> createCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> deleteCategory(String id);
}
