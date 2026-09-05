
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../models/bulk_item_data.dart';
import '../../models/category_model.dart';
import '../../theme/app_theme.dart';

class BulkItemCard extends StatelessWidget {
  final BulkItemData item;
  final List<CategoryModel> categories;
  final int index;
  final VoidCallback onRemove;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onBrandChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onRetryAi;

  const BulkItemCard({
    super.key,
    required this.item,
    required this.categories,
    required this.index,
    required this.onRemove,
    required this.onNameChanged,
    required this.onBrandChanged,
    required this.onCategoryChanged,
    required this.onColorChanged,
    required this.onRetryAi,
  });

  void _showColorPicker(BuildContext context, Color currentColor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Color tempColor = currentColor;
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                tempColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                onColorChanged(tempColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiLoadingSuffix = item.isAnalyzingAi
        ? const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : null;

    return Card(
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview area
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      item.displayImage,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                    if (item.isProcessingBg)
                      Container(
                        color: Colors.black45,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              'Removing background...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    if (item.isRemoved)
                      Container(
                        color: Colors.black45,
                        child: Center(
                          child: Text(
                            'Removed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Form fields section
            IgnorePointer(
              ignoring: item.isRemoved,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: item.isRemoved ? 0.4 : 1.0,
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: item.name,
                      decoration: InputDecoration(
                        labelText: 'Item Name',
                        suffixIcon: aiLoadingSuffix,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: onNameChanged,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: item.brand,
                      decoration: InputDecoration(
                        labelText: 'Brand',
                        suffixIcon: aiLoadingSuffix,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: onBrandChanged,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: item.categoryId,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: const OutlineInputBorder(),
                        suffixIcon: item.isAnalyzingAi
                            ? const Padding(
                                padding: EdgeInsets.only(right: 12.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      items: categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: onCategoryChanged,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Color:', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: item.selectedColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => _showColorPicker(context, item.selectedColor),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons row
            if (!item.isRemoved)
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: item.isAnalyzingAi ? null : onRetryAi,
                    icon: const Icon(Icons.auto_awesome, color: Colors.black87),
                    label: const Text('Auto-Fill AI', style: TextStyle(color: Colors.black87)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentYellow,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Remove', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.undo),
                  label: const Text('Restore'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
