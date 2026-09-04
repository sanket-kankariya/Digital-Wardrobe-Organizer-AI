import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/bulk_item_data.dart';
import '../../models/clothing_item_model.dart';
import '../../models/category_model.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/image_service.dart';
import '../../services/database_service.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bulk_item_card.dart';

class BulkAddScreen extends ConsumerStatefulWidget {
  const BulkAddScreen({super.key});

  @override
  ConsumerState<BulkAddScreen> createState() => _BulkAddScreenState();
}

class _BulkAddScreenState extends ConsumerState<BulkAddScreen> {
  final List<BulkItemData> _items = [];
  final PageController _pageController = PageController(viewportFraction: 1.0);
  final ScrollController _thumbScrollController = ScrollController();
  int _currentPage = 0;
  bool _isSaving = false;
  int _saveProgress = 0;
  bool _hasPickedImages = false;
  bool _didSaveSuccessfully = false;

  // Queue for sequential background removal
  final List<int> _bgRemovalQueue = [];
  bool _isBgProcessing = false;

  // AI rate-limiting: max 4 concurrent requests
  static const int _maxConcurrentAi = 4;
  int _activeAiRequests = 0;
  final List<int> _aiQueue = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasPickedImages) {
        _showSourcePicker();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbScrollController.dispose();
    // Clean up orphaned temp images if the user didn't save
    if (!_didSaveSuccessfully) {
      BulkItemData.cleanupAll(_items);
    }
    super.dispose();
  }

  // ── Source Picker ────────────────────────────────────────────────
  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
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
            const Text(
              'Bulk Add Photos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Add up to 20 clothing items at once',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                child: const Icon(Icons.photo_library, color: AppTheme.primaryBlue, size: 20),
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select multiple photos at once'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryBlue,
                child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
              title: const Text('Take Photos'),
              subtitle: const Text('Capture items one by one'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera();
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Gallery Picker ──────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    final remaining = 20 - _items.length;
    if (remaining <= 0) {
      _showMaxLimitSnackbar();
      return;
    }
    final files = await ImageService.pickMultipleFromGallery(maxImages: remaining);
    if (files.isEmpty) {
      if (mounted && _items.isEmpty) Navigator.pop(context);
      return;
    }
    _onImagesPicked(files);
  }

  // ── Camera Picker (loop) ────────────────────────────────────────
  Future<void> _pickFromCamera() async {
    final List<File> captured = [];
    final maxCapture = 20 - _items.length;
    while (captured.length < maxCapture) {
      final file = await ImageService.pickFromCamera();
      if (file == null) break;
      captured.add(file);
      if (!mounted) break;

      final takeMore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('Photo ${captured.length} captured'),
          content: Text(
            captured.length >= maxCapture
                ? 'Maximum of 20 photos reached.'
                : 'Take another photo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Done (${captured.length} photos)'),
            ),
            if (captured.length < maxCapture)
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Take Another'),
              ),
          ],
        ),
      );
      if (takeMore != true) break;
    }

    if (captured.isEmpty) {
      if (mounted && _items.isEmpty) Navigator.pop(context);
      return;
    }
    _onImagesPicked(captured);
  }

  // ── Process Picked Images ──────────────────────────────────────
  void _onImagesPicked(List<File> files) {
    _hasPickedImages = true;
    final startIndex = _items.length;
    setState(() {
      for (final file in files) {
        _items.add(BulkItemData(imageFile: file));
      }
    });
    // Start background removal queue
    for (int i = startIndex; i < _items.length; i++) {
      _bgRemovalQueue.add(i);
    }
    _processBgQueue();
    // Start AI analysis with rate limiting
    _enqueueAiAnalysis(startIndex: startIndex);
  }

  // ── Background Removal Queue (sequential) ──────────────────────
  Future<void> _processBgQueue() async {
    if (_isBgProcessing || _bgRemovalQueue.isEmpty) return;
    _isBgProcessing = true;

    while (_bgRemovalQueue.isNotEmpty) {
      final idx = _bgRemovalQueue.removeAt(0);
      if (idx >= _items.length || _items[idx].isRemoved) continue;

      if (mounted) {
        setState(() => _items[idx].isProcessingBg = true);
      }

      try {
        final processed = await ImageService.removeBackground(_items[idx].imageFile);
        if (mounted && idx < _items.length) {
          setState(() {
            _items[idx].processedImage = processed;
            _items[idx].isProcessingBg = false;
          });
        }
      } catch (_) {
        if (mounted && idx < _items.length) {
          setState(() {
            _items[idx].processedImage = _items[idx].imageFile;
            _items[idx].isProcessingBg = false;
          });
        }
      }
    }
    _isBgProcessing = false;
  }

  // ── AI Analysis (rate-limited to _maxConcurrentAi) ─────────────
  Future<void> _enqueueAiAnalysis({int startIndex = 0}) async {
    final hasKey = await AiService.hasApiKey();
    if (!hasKey) return;

    for (int i = startIndex; i < _items.length; i++) {
      _aiQueue.add(i);
    }
    _drainAiQueue();
  }

  void _drainAiQueue() {
    while (_activeAiRequests < _maxConcurrentAi && _aiQueue.isNotEmpty) {
      final idx = _aiQueue.removeAt(0);
      _activeAiRequests++;
      _analyzeItem(idx).whenComplete(() {
        _activeAiRequests--;
        _drainAiQueue();
      });
    }
  }

  Future<void> _analyzeItem(int index) async {
    if (index >= _items.length || _items[index].isRemoved) return;

    final categories = ref.read(wardrobeCategoriesProvider);
    final categoryNames = categories.map((c) => c.name).toList();

    if (mounted) {
      setState(() => _items[index].isAnalyzingAi = true);
    }

    try {
      final result = await AiService.analyzeClothingImage(
        imageFile: _items[index].imageFile,
        existingCategories: categoryNames,
      );

      if (result != null && mounted && index < _items.length) {
        setState(() {
          if (result.name.isNotEmpty) {
            _items[index].name = result.name;
          }
          if (result.brand != null && result.brand!.isNotEmpty) {
            _items[index].brand = result.brand!;
          }
          if (result.colorValue != null) {
            _items[index].selectedColor = Color(result.colorValue!);
          }
          if (result.categorySuggestion != null && categories.isNotEmpty) {
            final suggestionLower = result.categorySuggestion!.toLowerCase();
            final matched = categories.firstWhere(
              (c) =>
                  c.name.toLowerCase() == suggestionLower ||
                  suggestionLower.contains(c.name.toLowerCase()) ||
                  c.name.toLowerCase().contains(suggestionLower),
              orElse: () => categories.first,
            );
            _items[index].categoryId = matched.id;
          }
          _items[index].isAnalyzingAi = false;
        });
      }
    } catch (_) {
      if (mounted && index < _items.length) {
        setState(() => _items[index].isAnalyzingAi = false);
      }
    }
  }

  Future<void> _retryAiForItem(int index) async {
    final hasKey = await AiService.hasApiKey();
    if (!hasKey) return;
    await _analyzeItem(index);
  }

  // ── Apply Category to All ─────────────────────────────────────
  void _showApplyCategoryToAll(List<CategoryModel> categories) {
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
            const Text(
              'Apply Category to All Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Sets category for all items without one',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...categories.map((cat) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(cat.colorValue),
                    radius: 16,
                  ),
                  title: Text(cat.name),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      for (final item in _items) {
                        if (!item.isRemoved && item.categoryId == null) {
                          item.categoryId = cat.id;
                        }
                      }
                    });
                    final count = _items
                        .where((i) => !i.isRemoved && i.categoryId == cat.id)
                        .length;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Applied "${cat.name}" to $count items'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Save All Items ─────────────────────────────────────────────
  Future<void> _saveAllItems() async {
    final activeItems = _items.where((i) => !i.isRemoved).toList();
    if (activeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items to save. Add or restore items first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate
    for (int i = 0; i < activeItems.length; i++) {
      if (activeItems[i].name.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item ${i + 1} needs a name'),
            backgroundColor: Colors.orange,
          ),
        );
        final realIndex = _items.indexOf(activeItems[i]);
        _goToPage(realIndex);
        return;
      }
      if (activeItems[i].categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item ${i + 1} "${activeItems[i].name}" needs a category'),
            backgroundColor: Colors.orange,
          ),
        );
        final realIndex = _items.indexOf(activeItems[i]);
        _goToPage(realIndex);
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _saveProgress = 0;
    });

    const uuid = Uuid();
    final itemModels = <ClothingItemModel>[];
    final affectedCategories = <String>{};

    for (int i = 0; i < activeItems.length; i++) {
      final item = activeItems[i];
      setState(() => _saveProgress = i);

      try {
        final savedImage = await ImageService.saveImagePermanently(item.displayImage);
        itemModels.add(ClothingItemModel(
          id: uuid.v4(),
          name: item.name.trim(),
          brand: item.brand.trim(),
          colorValue: item.selectedColor.toARGB32(),
          categoryId: item.categoryId!,
          imagePath: savedImage.path,
          addedAt: DateTime.now(),
        ));
        affectedCategories.add(item.categoryId!);
      } catch (e) {
        debugPrint('Error saving item ${item.name}: $e');
      }
    }

    if (itemModels.isNotEmpty) {
      await DatabaseService.addItems(itemModels);
    }

    for (final catId in affectedCategories) {
      ref.read(categoryItemsProvider(catId).notifier).refresh();
    }
    ref.read(wardrobeCategoriesProvider.notifier).refresh();

    _didSaveSuccessfully = true;

    // Clean up temp files for removed items only (saved items' images are now permanent)
    for (final item in _items.where((i) => i.isRemoved)) {
      item.cleanup();
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('${itemModels.length} items added to wardrobe!'),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  // ── Navigation helpers ─────────────────────────────────────────
  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollThumbIntoView(int index) {
    if (!_thumbScrollController.hasClients) return;
    const thumbWidth = 56.0; // 48 + 8 margin
    final targetOffset = (index * thumbWidth) - 100;
    _thumbScrollController.animateTo(
      targetOffset.clamp(0.0, _thumbScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _addMorePhotos() {
    if (_items.length >= 20) {
      _showMaxLimitSnackbar();
      return;
    }
    _showSourcePicker();
  }

  void _showMaxLimitSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Maximum 20 items per bulk session'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(wardrobeCategoriesProvider);
    final activeCount = _items.where((i) => !i.isRemoved).length;

    if (_isSaving) {
      return _buildSavingScreen(activeCount);
    }

    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bulk Add')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Item ${_currentPage + 1} of ${_items.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Apply category to all',
            onPressed: () => _showApplyCategoryToAll(categories),
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Add more photos',
            onPressed: _addMorePhotos,
          ),
        ],
      ),
      body: Column(
        children: [
          // Thumbnail strip
          _buildThumbnailStrip(),

          // PageView with item cards (limited cache for memory)
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _items.length,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
                _scrollThumbIntoView(page);
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: BulkItemCard(
                    key: ValueKey('item_${index}_${item.name}_${item.brand}_${item.categoryId}_${item.isAnalyzingAi}'),
                    item: item,
                    categories: categories,
                    index: index,
                    onRemove: () => setState(() => item.isRemoved = !item.isRemoved),
                    onNameChanged: (v) => _items[index].name = v,
                    onBrandChanged: (v) => _items[index].brand = v,
                    onCategoryChanged: (v) => setState(() => _items[index].categoryId = v),
                    onColorChanged: (c) => setState(() => _items[index].selectedColor = c),
                    onRetryAi: () => _retryAiForItem(index),
                  ),
                );
              },
            ),
          ),

          // Bottom bar
          _buildBottomBar(activeCount),
        ],
      ),
    );
  }

  // ── Thumbnail Strip ────────────────────────────────────────────
  Widget _buildThumbnailStrip() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        controller: _thumbScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final item = _items[i];
          final isActive = i == _currentPage;
          final isRemoved = item.isRemoved;

          return GestureDetector(
            onTap: () => _goToPage(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? AppTheme.primaryBlue
                      : Colors.transparent,
                  width: 2.5,
                ),
                color: isRemoved
                    ? Colors.grey[300]
                    : AppTheme.primaryBlue.withValues(alpha: 0.06),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: isRemoved ? 0.3 : 1.0,
                    child: Image.file(
                      item.displayImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (item.isProcessingBg)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (isRemoved)
                    const Center(
                      child: Icon(Icons.close, color: Colors.red, size: 20),
                    ),
                  // Item number badge
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(int activeCount) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: _currentPage > 0
                  ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: _currentPage < _items.length - 1
                  ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: activeCount > 0 ? _saveAllItems : null,
                icon: const Icon(Icons.check, size: 20),
                label: Text(
                  'Save All ($activeCount items)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingScreen(int total) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated checkmark circle
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: total > 0 ? (_saveProgress + 1) / total : 0),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) {
                  return SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: value,
                          strokeWidth: 6,
                          color: AppTheme.primaryBlue,
                          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                        ),
                        Text(
                          '${(_saveProgress + 1).clamp(0, total)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Saving items...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_saveProgress + 1} of $total',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    if (_items.isEmpty) {
      Navigator.pop(context);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard items?'),
        content: Text(
          '${_items.where((i) => !i.isRemoved).length} unsaved items will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
