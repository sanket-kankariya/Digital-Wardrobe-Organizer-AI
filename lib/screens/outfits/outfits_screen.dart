import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/outfit_provider.dart';
import '../../models/category_model.dart';
import '../../models/outfit_model.dart';
import '../../services/database_service.dart';
import '../../models/clothing_item_model.dart';
import '../../theme/app_theme.dart';
import 'create_outfit_screen.dart';


class OutfitsScreen extends ConsumerWidget {
  const OutfitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(outfitCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Outfits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Style Category',
            onPressed: () => _showAddCategoryDialog(context, ref),
          ),
        ],
      ),
      body: categories.isEmpty
          ? _emptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: categories.length,
              itemBuilder: (_, i) => _StyleCard(category: categories[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CreateOutfitScreen(),
          ),
        ),
        icon: const Icon(Icons.style),
        label: const Text('New Outfit', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No outfit styles yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Create your first stylish outfit', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateOutfitScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create Outfit'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final c = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Style Category'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Style name', hintText: 'e.g. Beach')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                ref.read(outfitCategoriesProvider.notifier).addCategory(c.text.trim(), AppTheme.primaryBlue.toARGB32());
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




class _StyleCard extends ConsumerWidget {
  final CategoryModel category;
  const _StyleCard({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfits = ref.watch(outfitsByStyleProvider(category.id));
    final catColor = Color(category.colorValue);
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6, height: 28,
                    decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${category.name} (${outfits.length})',
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
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: outfits.isEmpty
                    ? _emptySlot(context, catColor)
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: outfits.length,
                        itemBuilder: (_, i) => _OutfitThumb(outfit: outfits[i], catColor: catColor, styleId: category.id),
                      ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _emptySlot(BuildContext context, Color color) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateOutfitScreen(initialStyleId: category.id),
        ),
      ),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _renameDialog(BuildContext context, WidgetRef ref) {
    final c = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Style'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                ref.read(outfitCategoriesProvider.notifier).renameCategory(category.id, c.text.trim());
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
        title: const Text('Delete Style?'),
        content: Text('Delete "${category.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(outfitCategoriesProvider.notifier).deleteCategory(category.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _OutfitThumb extends ConsumerWidget {
  final OutfitModel outfit;
  final Color catColor;
  final String styleId;
  const _OutfitThumb({required this.outfit, required this.catColor, required this.styleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItems = DatabaseService.getAllItems();
    final outfitItems = allItems.where((i) => outfit.itemIds.contains(i.id)).toList();

    return GestureDetector(
      onTap: () => _showOutfitDetails(context, ref, outfitItems),
      onLongPress: () => _confirmDelete(context, ref),
      child: Container(
        width: 80,
        height: 90,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: catColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: catColor.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: outfitItems.isNotEmpty && File(outfitItems.first.imagePath).existsSync()
                  ? Image.file(File(outfitItems.first.imagePath), fit: BoxFit.cover, width: double.infinity, filterQuality: FilterQuality.medium)
                  : Icon(Icons.style, color: catColor, size: 30),
            ),
            Container(
              color: Colors.black.withOpacity(0.04),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      outfit.name,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${outfit.itemIds.length}',
                    style: TextStyle(fontSize: 8, color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOutfitDetails(BuildContext context, WidgetRef ref, List<ClothingItemModel> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    outfit.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context, ref);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${items.length} items in this outfit:',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: items.isEmpty
                  ? const Center(child: Text('No items found'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                  child: File(item.imagePath).existsSync()
                                      ? Image.file(File(item.imagePath), fit: BoxFit.cover, filterQuality: FilterQuality.medium)
                                      : Container(color: Colors.grey[200]),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Outfit?'),
        content: Text('Delete "${outfit.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(outfitsByStyleProvider(styleId).notifier).deleteOutfit(outfit.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
