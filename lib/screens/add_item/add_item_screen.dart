import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/image_service.dart';
import '../../services/database_service.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';



class AddItemScreen extends ConsumerStatefulWidget {
  final String? preselectedCategoryId;
  const AddItemScreen({super.key, this.preselectedCategoryId});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  Color _selectedColor = AppTheme.primaryBlue;
  String? _selectedCategoryId;
  File? _imageFile;
  bool _isProcessing = false;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.preselectedCategoryId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = source == ImageSource.camera
        ? await ImageService.pickFromCamera()
        : await ImageService.pickFromGallery();
    if (file == null) return;
    setState(() => _isProcessing = true);

    // Concurrently trigger AI analysis in the background while processing image
    AiService.hasApiKey().then((hasKey) {
      if (hasKey && mounted) {
        _triggerAiAnalysis(targetFile: file, silent: true);
      }
    });

    try {
      final processed = await ImageService.removeBackground(file);
      setState(() {
        _imageFile = processed;
        _isProcessing = false;
      });
    } catch (_) {
      final saved = await ImageService.saveImagePermanently(file);
      setState(() {
        _imageFile = saved;
        _isProcessing = false;
      });
    }
  }


  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final saved = await ImageService.saveImagePermanently(_imageFile!);
      await DatabaseService.addItem(
        name: _nameCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        colorValue: _selectedColor.value,
        categoryId: _selectedCategoryId!,
        imagePath: saved.path,
      );
      ref.read(categoryItemsProvider(_selectedCategoryId!).notifier).refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(wardrobeCategoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _saveItem,
            child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryBlue),
                  SizedBox(height: 16),
                  Text('Removing background...', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w500)),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Photo section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showImageSourceSheet(context),
                            child: Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _imageFile != null ? AppTheme.primaryBlue : Colors.grey.withOpacity(0.3),
                                  width: _imageFile != null ? 2 : 1,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: _imageFile != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Image.file(
                                          _imageFile!,
                                          fit: BoxFit.contain,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_outlined, size: 48, color: AppTheme.primaryBlue.withOpacity(0.6)),
                                        const SizedBox(height: 8),
                                        Text('Tap to add photo', style: TextStyle(color: AppTheme.primaryBlue.withOpacity(0.7), fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 4),
                                        Text('Background will be removed automatically', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                      ],
                                    ),
                            ),
                          ),
                          if (_imageFile != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isAnalyzing ? null : () => _showImageSourceSheet(context),
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Change'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: _isAnalyzing ? null : _triggerAiAnalysis,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentYellow,
                                      foregroundColor: Colors.black87,
                                      elevation: 0,
                                    ),
                                    icon: _isAnalyzing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                                            ),
                                          )
                                        : const Icon(Icons.auto_awesome, size: 16, color: Colors.black87),
                                    label: Text(
                                      _isAnalyzing ? 'Analyzing...' : 'Auto-Fill with AI',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                    ),
                  ),

                  const SizedBox(height: 12),

                  // Details card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 4, height: 18, decoration: BoxDecoration(color: AppTheme.primaryBlue, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 8),
                              Text('Item Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(labelText: 'Item Name *', hintText: 'e.g. White Linen Shirt'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _brandCtrl,
                            decoration: const InputDecoration(labelText: 'Brand', hintText: 'e.g. Zara, H&M'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                          // Category dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedCategoryId,
                            decoration: const InputDecoration(labelText: 'Category *'),
                            items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                            onChanged: (v) => setState(() => _selectedCategoryId = v),
                            validator: (v) => v == null ? 'Please select a category' : null,
                          ),
                          const SizedBox(height: 16),
                          // Color picker
                          Row(
                            children: [
                              Text('Color:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _openColorPicker(context),
                                child: Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: _selectedColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey.withOpacity(0.4), width: 2),
                                    boxShadow: [BoxShadow(color: _selectedColor.withOpacity(0.4), blurRadius: 6)],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(_colorName(_selectedColor), style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _openColorPicker(context),
                                icon: const Icon(Icons.palette, size: 16),
                                label: const Text('Change'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _saveItem,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                    child: const Text('ADD TO WARDROBE'),
                  ),
                ],
              ),
            ),
    );
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Add Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(backgroundColor: AppTheme.primaryBlue, child: Icon(Icons.camera_alt, color: Colors.white, size: 20)),
              title: const Text('Take Photo'),
              subtitle: const Text('Use camera'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: AppTheme.primaryBlue.withOpacity(0.15), child: const Icon(Icons.photo_library, color: AppTheme.primaryBlue, size: 20)),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Pick existing photo'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openColorPicker(BuildContext context) {
    Color tempColor = _selectedColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (c) => tempColor = c,
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _selectedColor = tempColor);
              Navigator.pop(ctx);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  String _colorName(Color color) {
    final argb = color.toARGB32();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    if (r > 200 && g > 200 && b > 200) return 'White';
    if (r < 50 && g < 50 && b < 50) return 'Black';
    if (r > 150 && g < 100 && b < 100) return 'Red';
    if (r < 100 && g < 100 && b > 150) return 'Blue';
    if (r < 100 && g > 150 && b < 100) return 'Green';
    if (r > 200 && g > 200 && b < 100) return 'Yellow';
    if (r > 200 && g > 100 && b < 80) return 'Orange';
    if (r > 150 && g < 100 && b > 150) return 'Purple';
    if (r > 150 && g > 100 && b > 100) return 'Pink';
    if (r > 100 && g > 80 && b < 60) return 'Brown';
    if (r > 150 && g > 150 && b > 150) return 'Grey';
    return 'Custom';
  }

  Future<void> _triggerAiAnalysis({File? targetFile, bool silent = false}) async {
    final fileToAnalyze = targetFile ?? _imageFile;
    if (fileToAnalyze == null) return;

    final hasKey = await AiService.hasApiKey();
    if (!hasKey) {
      if (silent) return;
      if (!mounted) return;
      final setupSuccess = await _showApiKeySetupSheet(context);
      if (setupSuccess != true) return;
    }

    setState(() => _isAnalyzing = true);
    try {
      final categories = ref.read(wardrobeCategoriesProvider);
      final categoryNames = categories.map((c) => c.name).toList();

      final result = await AiService.analyzeClothingImage(
        imageFile: fileToAnalyze,
        existingCategories: categoryNames,
      );

      if (result != null && mounted) {
        setState(() {
          if (result.name.isNotEmpty) {
            _nameCtrl.text = result.name;
          }
          if (result.brand != null && result.brand!.isNotEmpty) {
            _brandCtrl.text = result.brand!;
          }
          if (result.colorValue != null) {
            _selectedColor = Color(result.colorValue!);
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
            _selectedCategoryId = matched.id;
          }
        });

        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('AI auto-filled the clothing details!')),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Analysis failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }


  Future<bool?> _showApiKeySetupSheet(BuildContext context) {
    final keyCtrl = TextEditingController();
    bool isVerifying = false;
    String? errorText;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: bottomPadding + 20,
            ),
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
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppTheme.primaryBlue),
                    SizedBox(width: 8),
                    Text(
                      'Free Gemini API Key Setup',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'To use AI auto-tagging with your own free quota (1,500 requests/day), grab a free key from Google AI Studio. No credit card required.',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SelectableText(
                    '1. Visit aistudio.google.com/app/apikey\n2. Sign in with Google & click "Create API key"\n3. Paste your key below',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: keyCtrl,
                  decoration: InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'AIzaSy...',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: isVerifying
                          ? null
                          : () async {
                              final text = keyCtrl.text.trim();
                              if (text.isEmpty) {
                                setModalState(() => errorText = 'Please enter an API key');
                                return;
                              }
                              setModalState(() {
                                isVerifying = true;
                                errorText = null;
                              });

                              final isValid = await AiService.validateApiKey(text);
                              if (!isValid) {
                                setModalState(() {
                                  isVerifying = false;
                                  errorText = 'Invalid key or could not connect';
                                });
                                return;
                              }

                              await AiService.saveApiKey(text);
                              if (ctx.mounted) {
                                Navigator.pop(ctx, true);
                              }
                            },
                      child: isVerifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Verify & Save'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

