import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/features/categories/domain/category.dart';
import 'package:uuid/uuid.dart';

class CategoryManagementDialog extends ConsumerStatefulWidget {
  const CategoryManagementDialog({super.key});

  @override
  ConsumerState<CategoryManagementDialog> createState() =>
      _CategoryManagementDialogState();
}

class _CategoryManagementDialogState
    extends ConsumerState<CategoryManagementDialog> {
  final _nameController = TextEditingController();
  int _selectedColorValue = 0xFF3B82F6; // Blue default
  Category? _editingCategory;

  static const List<int> _colorPalette = [
    0xFF3B82F6, // Blue
    0xFF10B981, // Emerald Green
    0xFF8B5CF6, // Purple
    0xFFF59E0B, // Amber
    0xFFEF4444, // Red
    0xFFEC4899, // Pink
    0xFF06B6D4, // Cyan
    0xFF6366F1, // Indigo
    0xFF14B8A6, // Teal
    0xFF64748B, // Slate
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEdit(Category category) {
    setState(() {
      _editingCategory = category;
      _nameController.text = category.name;
      _selectedColorValue = category.colorValue;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCategory = null;
      _nameController.clear();
      _selectedColorValue = 0xFF3B82F6;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final repo = ref.read(categoryRepositoryProvider);
    final now = DateTime.now();

    if (_editingCategory != null) {
      final updated = _editingCategory!.copyWith(
        name: name,
        colorValue: _selectedColorValue,
        updatedAt: now,
      );
      await repo.updateCategory(updated);
    } else {
      final newCategory = Category(
        id: const Uuid().v4(),
        name: name,
        colorValue: _selectedColorValue,
        createdAt: now,
        updatedAt: now,
      );
      await repo.createCategory(newCategory);
    }

    _cancelEdit();
  }

  Future<void> _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
          '¿Seguro que deseas eliminar la categoría "${category.name}"?\n'
          'Las tareas vinculadas NO se eliminarán; conservarán sus datos y quedarán "Sin categoría".',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final categories = categoriesAsync.asData?.value ?? [];
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.category_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Gestión de Categorías',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Form to Add/Edit Category
            Text(
              _editingCategory != null ? 'Editar Categoría' : 'Nueva Categoría',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Nombre de categoría...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 8),
                if (_editingCategory != null)
                  TextButton(
                    onPressed: _cancelEdit,
                    child: const Text('Cancelar'),
                  ),
                ElevatedButton.icon(
                  icon: Icon(
                    _editingCategory != null ? Icons.check : Icons.add,
                    size: 18,
                  ),
                  label: Text(_editingCategory != null ? 'Guardar' : 'Crear'),
                  onPressed: _save,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Color Picker Row
            Row(
              children: [
                Text('Color:', style: theme.textTheme.bodySmall),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _colorPalette.map((colorVal) {
                        final isSelected = _selectedColorValue == colorVal;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColorValue = colorVal),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(colorVal),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.primary,
                                      width: 2.5,
                                    )
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),

            // Categories List
            Text(
              'Categorías existentes (${categories.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Text(
                        'No hay categorías creadas',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Color(cat.colorValue),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Editar',
                                onPressed: () => _startEdit(cat),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                tooltip: 'Eliminar',
                                onPressed: () => _deleteCategory(cat),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
