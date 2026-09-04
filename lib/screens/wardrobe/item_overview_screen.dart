import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/category_model.dart';
import '../../models/clothing_item_model.dart';
import '../../providers/wardrobe_provider.dart';
import '../../theme/app_theme.dart';
import '../add_item/add_item_screen.dart';

enum SortOption { recent, name, color }

class ItemOverviewScreen extends ConsumerStatefulWidget {
  final CategoryModel category;
  const ItemOverviewScreen({super.key, required this.category});

  @override
  ConsumerState<ItemOverviewScreen> createState() => _ItemOverviewScreenState();
}

class _ItemOverviewScreenState extends ConsumerState<ItemOverviewScreen> {
  SortOption _sort = SortOption.recent;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(categoryItemsProvider(widget.category.id));
    final catColor = Color(widget.category.colorValue);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category.name} (${items.length})'),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (opt) {
              setState(() => _sort = opt);
              final notifier = ref.read(categoryItemsProvider(widget.category.id).notifier);
              if (opt == SortOption.recent) notifier.sortByRecent();
              if (opt == SortOption.name) notifier.sortByName();
              if (opt == SortOption.color) notifier.sortByColor();
            },
            itemBuilder: (_) => [
              _sortItem(SortOption.recent, 'Recently Added', Icons.access_time),
              _sortItem(SortOption.name, 'Name', Icons.sort_by_alpha),
              _sortItem(SortOption.color, 'Color', Icons.palette),
            ],
          ),
        ],
      ),
      body: items.isEmpty
          ? _emptyState(catColor)
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => _ItemCard(
                item: items[i],
                catColor: catColor,
                categoryId: widget.category.id,
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddItemScreen(preselectedCategoryId: widget.category.id),
          ),
        ).then((_) => ref.read(categoryItemsProvider(widget.category.id).notifier).refresh()),
        child: const Icon(Icons.add),
      ),
    );
  }

  PopupMenuItem<SortOption> _sortItem(SortOption opt, String label, IconData icon) {
    return PopupMenuItem<SortOption>(
      value: opt,
      child: Row(
        children: [
          Icon(icon, size: 18, color: _sort == opt ? AppTheme.primaryBlue : null),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(
            color: _sort == opt ? AppTheme.primaryBlue : null,
            fontWeight: _sort == opt ? FontWeight.w600 : null,
          )),
        ],
      ),
    );
  }

  Widget _emptyState(Color catColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checkroom_outlined, size: 72, color: catColor.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('No items yet', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tap + to add your first item', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final ClothingItemModel item;
  final Color catColor;
  final String categoryId;

  const _ItemCard({required this.item, required this.catColor, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = File(item.imagePath);
    final theme = Theme.of(context);

    return GestureDetector(
      onLongPress: () => _showOptions(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: catColor.withOpacity(0.15)),
          boxShadow: theme.brightness == Brightness.light
              ? [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Color(item.colorValue).withOpacity(0.08),
                child: file.existsSync()
                    ? Image.file(file, fit: BoxFit.cover)
                    : Icon(Icons.checkroom, color: catColor, size: 36),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                item.name,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.brand.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 6, bottom: 4),
                child: Text(
                  item.brand,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.checkroom, color: AppTheme.primaryBlue),
                  const SizedBox(width: 10),
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Item', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Delete "${item.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(categoryItemsProvider(categoryId).notifier).deleteItem(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
