import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/category_model.dart';
import '../../providers/outfit_provider.dart';

import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

class CreateOutfitScreen extends ConsumerStatefulWidget {
  final String? initialStyleId;
  const CreateOutfitScreen({super.key, this.initialStyleId});

  @override
  ConsumerState<CreateOutfitScreen> createState() => _CreateOutfitScreenState();
}

class _CreateOutfitScreenState extends ConsumerState<CreateOutfitScreen> {
  final _nameCtrl = TextEditingController();
  String? _selectedStyleId;
  String _selectedCategoryFilter = 'all'; // 'all' or category ID
  final Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _selectedStyleId = widget.initialStyleId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveOutfit(List<CategoryModel> styles) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an outfit name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedStyleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a style category'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 item from your wardrobe'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ref.read(outfitsByStyleProvider(_selectedStyleId!).notifier).addOutfit(
          name,
          _selectedItemIds.toList(),
        );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Outfit "$name" created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final styles = ref.watch(outfitCategoriesProvider);
    final wardrobeCategories = DatabaseService.getCategories('wardrobe');
    final allItems = DatabaseService.getAllItems();
    final theme = Theme.of(context);

    if (_selectedStyleId == null && styles.isNotEmpty) {
      _selectedStyleId = styles.first.id;
    }

    final selectedItems = allItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList();

    final filteredItems = _selectedCategoryFilter == 'all'
        ? allItems
        : allItems
            .where((item) => item.categoryId == _selectedCategoryFilter)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outfit Studio'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _saveOutfit(styles),
              icon: const Icon(Icons.check, color: Colors.white, size: 20),
              label: const Text(
                'SAVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Outfit metadata (Name & Style selector)
          Container(
            color: theme.cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Outfit Name (e.g. Summer Date Night)',
                    prefixIcon: const Icon(Icons.style, color: AppTheme.primaryBlue),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: theme.brightness == Brightness.dark
                        ? AppTheme.darkSurface
                        : AppTheme.lightBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Style: ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: styles.map((s) {
                            final isSelected = _selectedStyleId == s.id;
                            final color = Color(s.colorValue);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(s.name),
                                selected: isSelected,
                                selectedColor: color.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSelected ? color : null,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                side: BorderSide(
                                  color: isSelected ? color : Colors.transparent,
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedStyleId = s.id);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 2. Interactive Canvas / Preview Stage
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 160,
            width: double.infinity,
            color: theme.brightness == Brightness.dark
                ? AppTheme.darkBg
                : Colors.grey[100],
            child: selectedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.checkroom_outlined,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select clothes below to build your outfit',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedItems.length,
                    itemBuilder: (ctx, i) {
                      final item = selectedItems[i];
                      return Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    child: File(item.imagePath).existsSync()
                                        ? Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Image.file(
                                              File(item.imagePath),
                                              fit: BoxFit.contain,
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.checkroom),
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _selectedItemIds.remove(item.id));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // 3. Category Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All Items'),
                    selected: _selectedCategoryFilter == 'all',
                    onSelected: (_) => setState(() => _selectedCategoryFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ...wardrobeCategories.map((c) {
                    final isSel = _selectedCategoryFilter == c.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(c.name),
                        selected: isSel,
                        onSelected: (_) => setState(() => _selectedCategoryFilter = c.id),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // 4. Wardrobe Items Grid
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Text(
                      'No clothes found in this category',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (ctx, i) {
                      final item = filteredItems[i];
                      final isSelected = _selectedItemIds.contains(item.id);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedItemIds.remove(item.id);
                            } else {
                              _selectedItemIds.add(item.id);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : Colors.grey.withOpacity(0.2),
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? AppTheme.primaryBlue.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.04),
                                blurRadius: isSelected ? 8 : 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(10),
                                      ),
                                      child: File(item.imagePath).existsSync()
                                          ? Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Image.file(
                                                File(item.imagePath),
                                                fit: BoxFit.contain,
                                              ),
                                            )
                                          : Container(
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.checkroom),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.brand.isNotEmpty)
                                          Text(
                                            item.brand,
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey[500],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
