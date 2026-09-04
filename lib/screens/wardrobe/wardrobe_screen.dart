import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/wardrobe_provider.dart';
import '../../models/category_model.dart';
import '../../models/clothing_item_model.dart';
import '../../theme/app_theme.dart';
import 'item_overview_screen.dart';
import '../add_item/add_item_screen.dart';

class WardrobeScreen extends ConsumerWidget {
  const WardrobeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(wardrobeCategoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Wardrobe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Category',
            onPressed: () => _showAddCategoryDialog(context, ref),
          ),
        ],
      ),
      body: categories.isEmpty
          ? _emptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: categories.length,
              itemBuilder: (context, i) {
                return _CategoryCard(category: categories[i]);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddItemScreen()),
        ).then((_) => ref.read(wardrobeCategoriesProvider.notifier).refresh()),
        child: const Icon(Icons.add),
        tooltip: 'Add Clothing Item',
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checkroom_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Your wardrobe is empty',
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tap + to add your first item', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name', hintText: 'e.g. Dresses'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(wardrobeCategoriesProvider.notifier).addCategory(
                  controller.text.trim(),
                  AppTheme.primaryBlue.toARGB32(),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final CategoryModel category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(categoryItemsProvider(category.id));
    final theme = Theme.of(context);
    final catColor = Color(category.colorValue);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemOverviewScreen(category: category),
          ),
        ).then((_) => ref.read(categoryItemsProvider(category.id).notifier).refresh()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6, height: 28,
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${category.name} (${items.length})',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (val) {
                      if (val == 'rename') _renameDialog(context, ref);
                      if (val == 'delete') _deleteConfirm(context, ref);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 22),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddItemScreen(preselectedCategoryId: category.id),
                      ),
                    ).then((_) => ref.read(categoryItemsProvider(category.id).notifier).refresh()),
                    tooltip: 'Add to ${category.name}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: items.isEmpty
                    ? _emptyThumbnail(context, catColor)
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        itemBuilder: (_, i) => _ItemThumb(item: items[i], catColor: catColor),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyThumbnail(BuildContext context, Color color) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Icon(Icons.add, color: color.withOpacity(0.4), size: 28),
    );
  }

  void _renameDialog(BuildContext context, WidgetRef ref) {
    final c = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                ref.read(wardrobeCategoriesProvider.notifier).renameCategory(category.id, c.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Delete "${category.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(wardrobeCategoriesProvider.notifier).deleteCategory(category.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ItemThumb extends StatelessWidget {
  final ClothingItemModel item;
  final Color catColor;
  const _ItemThumb({required this.item, required this.catColor});

  @override
  Widget build(BuildContext context) {
    final file = File(item.imagePath);
    return Container(
      width: 80,
      height: 90,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Color(item.colorValue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: catColor.withOpacity(0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: file.existsSync()
          ? Image.file(file, fit: BoxFit.cover)
          : Icon(Icons.checkroom, color: catColor, size: 36),
    );
  }
}
