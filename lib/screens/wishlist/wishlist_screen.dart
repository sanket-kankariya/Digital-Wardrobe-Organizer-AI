import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../models/wishlist_item_model.dart';
import '../../services/image_service.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(wishlistProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist ❤️')),
      body: items.isEmpty
          ? _emptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => _WishCard(item: items[i]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        child: const Icon(Icons.add),
        tooltip: 'Add to Wishlist',
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Your wishlist is empty', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Save items you want to buy', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _AddWishlistItemScreen()),
    );
  }
}

class _WishCard extends ConsumerWidget {
  final WishlistItemModel item;
  const _WishCard({required this.item});

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
          boxShadow: theme.brightness == Brightness.light
              ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: Color(item.colorValue).withOpacity(0.1),
                    child: file.existsSync()
                        ? Image.file(file, fit: BoxFit.cover, width: double.infinity, filterQuality: FilterQuality.medium)
                        : const Icon(Icons.favorite, color: Colors.pink, size: 48),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.pink, shape: BoxShape.circle),
                      child: const Icon(Icons.favorite, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (item.brand.isNotEmpty)
                    Text(item.brand, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (item.price != null && item.price!.isNotEmpty)
                    Text('₹${item.price}', style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    final categories = DatabaseService.getCategories('wardrobe');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.pink),
                  const SizedBox(width: 10),
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
            ),
            const Divider(height: 1),
            if (categories.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.checkroom_outlined, color: AppTheme.primaryBlue),
                title: const Text('Move to Wardrobe'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMoveDialog(context, ref, categories);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove from Wishlist', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(wishlistProvider.notifier).deleteItem(item.id);
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

  void _showMoveDialog(BuildContext context, WidgetRef ref, List categories) {
    String? selectedCatId = categories.first.id;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Move to Wardrobe'),
          content: DropdownButtonFormField<String>(
            value: selectedCatId,
            decoration: const InputDecoration(labelText: 'Select Category'),
            items: categories.map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => selectedCatId = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedCatId != null) {
                  ref.read(wishlistProvider.notifier).moveToWardrobe(item, selectedCatId!);
                  ref.read(categoryItemsProvider(selectedCatId!).notifier).refresh();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Move'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWishlistItemScreen extends ConsumerStatefulWidget {
  const _AddWishlistItemScreen();

  @override
  ConsumerState<_AddWishlistItemScreen> createState() => _AddWishlistItemScreenState();
}

class _AddWishlistItemScreenState extends ConsumerState<_AddWishlistItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  Color _selectedColor = Colors.pink;
  File? _imageFile;
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
    final file = source == ImageSource.camera
        ? await ImageService.pickFromCamera()
        : await ImageService.pickFromGallery();
    if (file == null) return;
    setState(() => _isProcessing = true);
    try {
      final processed = await ImageService.removeBackground(file);
      setState(() { _imageFile = processed; _isProcessing = false; });
    } catch (_) {
      final saved = await ImageService.saveImagePermanently(file);
      setState(() { _imageFile = saved; _isProcessing = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a photo')));
      return;
    }
    setState(() => _isProcessing = true);
    final saved = await ImageService.saveImagePermanently(_imageFile!);
    await ref.read(wishlistProvider.notifier).addItem(
      name: _nameCtrl.text.trim(),
      brand: _brandCtrl.text.trim(),
      colorValue: _selectedColor.toARGB32(),
      imagePath: saved.path,
      price: _priceCtrl.text.trim().isNotEmpty ? _priceCtrl.text.trim() : null,
      storeNote: _storeCtrl.text.trim().isNotEmpty ? _storeCtrl.text.trim() : null,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add to Wishlist'),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _save,
            child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.pink),
                SizedBox(height: 16),
                Text('Processing...'),
              ],
            ))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GestureDetector(
                        onTap: () => _showPickerSheet(context),
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.pink.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.pink.withOpacity(0.3)),
                          ),
                          child: _imageFile != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_imageFile!, fit: BoxFit.contain, filterQuality: FilterQuality.medium))
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.favorite_border, size: 48, color: Colors.pink),
                                    SizedBox(height: 8),
                                    Text('Tap to add photo', style: TextStyle(color: Colors.pink)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Item Name *'), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                          const SizedBox(height: 12),
                          TextFormField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'Brand')),
                          const SizedBox(height: 12),
                          TextFormField(controller: _priceCtrl, decoration: const InputDecoration(labelText: 'Price (₹)', prefixText: '₹ '), keyboardType: TextInputType.number),
                          const SizedBox(height: 12),
                          TextFormField(controller: _storeCtrl, decoration: const InputDecoration(labelText: 'Store / Note')),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Text('Color:', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  Color tmp = _selectedColor;
                                  showDialog(context: context, builder: (ctx) => AlertDialog(
                                    title: const Text('Pick Color'),
                                    content: SingleChildScrollView(child: ColorPicker(pickerColor: _selectedColor, onColorChanged: (c) => tmp = c, enableAlpha: false, labelTypes: const [])),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                      ElevatedButton(onPressed: () { setState(() => _selectedColor = tmp); Navigator.pop(ctx); }, child: const Text('Select')),
                                    ],
                                  ));
                                },
                                child: Container(width: 36, height: 36, decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle, border: Border.all(color: Colors.grey.withOpacity(0.3)))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('ADD TO WISHLIST ❤️', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),
    );
  }

  void _showPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.pink, child: Icon(Icons.camera_alt, color: Colors.white, size: 20)),
              title: const Text('Take Photo'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.pink.withOpacity(0.15), child: const Icon(Icons.photo_library, color: Colors.pink, size: 20)),
              title: const Text('Choose from Gallery'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
