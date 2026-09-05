import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/category_model.dart';
import '../../models/clothing_item_model.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/database_service.dart';
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
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  void _toggleSelectMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      _selectedIds.clear();
    });
  }

  void _toggleItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<ClothingItemModel> items) {
    setState(() {
      if (_selectedIds.length == items.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(items.map((i) => i.id));
      }
    });
  }

  // ── Move selected items to another category ────────────────────
  void _showMoveToCategorySheet() {
    final allCategories = ref.read(wardrobeCategoriesProvider);
    // Exclude current category from the list
    final otherCategories = allCategories
        .where((c) => c.id != widget.category.id)
        .toList();


    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Move ${_selectedIds.length} item${_selectedIds.length > 1 ? 's' : ''} to...',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                radius: 16,
                child: const Icon(Icons.add, color: AppTheme.primaryBlue, size: 18),
              ),
              title: const Text('Create New Category', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateCategoryAndMove();
              },
            ),
            if (otherCategories.isNotEmpty) const Divider(height: 1),
            ...otherCategories.map((cat) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(cat.colorValue),
                    radius: 16,
                    child: const Icon(Icons.checkroom, color: Colors.white, size: 16),
                  ),
                  title: Text(cat.name),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _moveItemsToCategory(cat);
                  },
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showCreateCategoryAndMove() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g. Dresses',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final navigator = Navigator.of(ctx);
              // Create the category
              await ref.read(wardrobeCategoriesProvider.notifier).addCategory(
                    name,
                    AppTheme.primaryBlue.toARGB32(),
                  );
              if (!mounted) return;
              navigator.pop();
              // Find the newly created category and move items to it
              final categories = ref.read(wardrobeCategoriesProvider);
              final newCat = categories.where(
                (c) => c.name == name && c.type == 'wardrobe',
              );
              if (newCat.isNotEmpty) {
                _moveItemsToCategory(newCat.first);
              }
            },
            child: const Text('Create & Move'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveItemsToCategory(CategoryModel targetCategory) async {
    final items = ref.read(categoryItemsProvider(widget.category.id));
    final toMove = items.where((i) => _selectedIds.contains(i.id)).toList();

    for (final item in toMove) {
      item.categoryId = targetCategory.id;
      await DatabaseService.updateItem(item);
    }

    // Refresh both source and target category providers
    ref.read(categoryItemsProvider(widget.category.id).notifier).refresh();
    ref.read(categoryItemsProvider(targetCategory.id).notifier).refresh();
    ref.read(wardrobeCategoriesProvider.notifier).refresh();

    final count = toMove.length;
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Moved $count item${count > 1 ? 's' : ''} to "${targetCategory.name}"'),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(categoryItemsProvider(widget.category.id));
    final catColor = Color(widget.category.colorValue);

    return Scaffold(
      appBar: _isSelecting ? _buildSelectionAppBar(items) : _buildNormalAppBar(items),
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
              itemBuilder: (_, i) => _buildItemCard(items[i], catColor),
            ),
      floatingActionButton: _isSelecting
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddItemScreen(preselectedCategoryId: widget.category.id),
                ),
              ).then((_) => ref.read(categoryItemsProvider(widget.category.id).notifier).refresh()),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: _isSelecting && _selectedIds.isNotEmpty
          ? _buildSelectionBottomBar()
          : null,
    );
  }

  PreferredSizeWidget _buildNormalAppBar(List<ClothingItemModel> items) {
    return AppBar(
      title: Text('${widget.category.name} (${items.length})'),
      actions: [
        if (items.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: 'Select items',
            onPressed: _toggleSelectMode,
          ),
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
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(List<ClothingItemModel> items) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _toggleSelectMode,
      ),
      title: Text('${_selectedIds.length} selected'),
      actions: [
        TextButton(
          onPressed: () => _selectAll(items),
          child: Text(
            _selectedIds.length == items.length ? 'Deselect All' : 'Select All',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBottomBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton.icon(
          onPressed: _showMoveToCategorySheet,
          icon: const Icon(Icons.drive_file_move_outlined, size: 20),
          label: Text(
            'Move to Category (${_selectedIds.length})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(ClothingItemModel item, Color catColor) {
    final file = File(item.imagePath);
    final theme = Theme.of(context);
    final isSelected = _selectedIds.contains(item.id);

    return GestureDetector(
      onTap: _isSelecting ? () => _toggleItem(item.id) : null,
      onLongPress: _isSelecting ? null : () {
        if (!_isSelecting) {
          // Enter selection mode with this item pre-selected
          setState(() {
            _isSelecting = true;
            _selectedIds.add(item.id);
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : catColor.withValues(alpha: 0.15),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: theme.brightness == Brightness.light
              ? [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: Color(item.colorValue).withValues(alpha: 0.08),
                    child: file.existsSync()
                        ? Padding(
                            padding: const EdgeInsets.all(4),
                            child: Image.file(file, fit: BoxFit.contain),
                          )
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
            // Selection checkbox overlay
            if (_isSelecting)
              Positioned(
                top: 4,
                right: 4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryBlue : Colors.white70,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ),
          ],
        ),
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
          Icon(Icons.checkroom_outlined, size: 72, color: catColor.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No items yet', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tap + to add your first item', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}
