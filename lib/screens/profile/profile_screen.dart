import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final theme = Theme.of(context);
    final allItems = DatabaseService.getAllItems();
    final allOutfits = DatabaseService.getAllOutfits();
    final wardrobeCategories = DatabaseService.getCategories('wardrobe');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          Row(
            children: [
              Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 18),
              Switch(
                value: isDark,
                onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                activeColor: AppTheme.accentYellow,
                activeTrackColor: AppTheme.primaryBlue,
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _pickAvatar(context, ref),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primaryBlue.withOpacity(0.15),
                          backgroundImage: profile.avatarPath != null && File(profile.avatarPath!).existsSync()
                              ? FileImage(File(profile.avatarPath!))
                              : null,
                          child: profile.avatarPath == null
                              ? const Icon(Icons.person, size: 50, color: AppTheme.primaryBlue)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.cardTheme.color ?? Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _editName(context, ref, profile.name),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(profile.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit, size: 16, color: AppTheme.primaryBlue),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatChip(label: 'Items', value: allItems.length.toString(), icon: Icons.checkroom),
                      Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
                      _StatChip(label: 'Outfits', value: allOutfits.length.toString(), icon: Icons.style),
                      Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
                      _StatChip(label: 'Categories', value: wardrobeCategories.length.toString(), icon: Icons.category),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Pie chart
          if (allItems.isNotEmpty) ...[
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
                        Text('Wardrobe Breakdown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: _WardrobePieChart(allItems: allItems, allCategories: wardrobeCategories),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Color palette
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
                        Text('Color Palette', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ColorPaletteGrid(allItems: allItems),
                  ],
                ),
              ),
            ),
          ],

          if (allItems.isEmpty) ...[
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('Add items to see your stats', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // AI Settings card
          const _AiSettingsCard(),

          const SizedBox(height: 32),
        ],
      ),
    );

  }

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xFile != null) {
      ref.read(profileProvider.notifier).updateAvatar(xFile.path);
    }
  }

  void _editName(BuildContext context, WidgetRef ref, String current) {
    final c = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Your name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                ref.read(profileProvider.notifier).updateName(c.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }
}

class _WardrobePieChart extends StatefulWidget {
  final List allItems;
  final List allCategories;
  const _WardrobePieChart({required this.allItems, required this.allCategories});

  List get categories => allCategories;

  @override
  State<_WardrobePieChart> createState() => _WardrobePieChartState();
}

class _WardrobePieChartState extends State<_WardrobePieChart> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final countsByCategory = <String, int>{};
    for (final item in widget.allItems) {
      countsByCategory[item.categoryId] = (countsByCategory[item.categoryId] ?? 0) + 1;
    }
    final catMap = {for (final c in widget.categories) c.id: c};

    final sections = countsByCategory.entries.map((e) {
      final cat = catMap[e.key];
      final color = cat != null ? Color(cat.colorValue) : AppTheme.primaryBlue;
      final name = cat?.name ?? 'Other';
      final pct = (e.value / widget.allItems.length * 100).toStringAsFixed(0);
      final isTouched = _touched == countsByCategory.keys.toList().indexOf(e.key);
      return PieChartSectionData(
        color: color,
        value: e.value.toDouble(),
        title: '$name\n$pct%',
        radius: isTouched ? 80 : 65,
        titleStyle: TextStyle(fontSize: isTouched ? 12 : 10, fontWeight: FontWeight.w700, color: Colors.white),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            setState(() {
              if (!event.isInterestedForInteractions || response == null || response.touchedSection == null) {
                _touched = null;
              } else {
                _touched = response.touchedSection!.touchedSectionIndex;
              }
            });
          },
        ),
        centerSpaceRadius: 30,
        sectionsSpace: 2,
      ),
    );
  }
}

class _ColorPaletteGrid extends StatelessWidget {
  final List allItems;
  const _ColorPaletteGrid({required this.allItems});

  @override
  Widget build(BuildContext context) {
    final colors = allItems.map((i) => Color(i.colorValue)).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((c) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: c.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))],
        ),
      )).toList(),
    );
  }
}

class _AiSettingsCard extends StatefulWidget {
  const _AiSettingsCard();

  @override
  State<_AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends State<_AiSettingsCard> {
  bool _hasKey = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final has = await AiService.hasApiKey();
    if (mounted) {
      setState(() {
        _hasKey = has;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Settings (BYOK)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (!_isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _hasKey ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasKey ? Icons.check_circle : Icons.warning_amber,
                          size: 14,
                          color: _hasKey ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _hasKey ? 'Connected' : 'Not Configured',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _hasKey ? Colors.green[800] : Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Powers smart clothing photo auto-tagging using Google Gemini 3.8 Flash. Each user uses their own free key (1,500 free queries/day).',
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showEditKeyDialog(context),
                  icon: const Icon(Icons.key, size: 16),
                  label: Text(_hasKey ? 'Change Key' : 'Configure Key'),
                ),
                if (_hasKey) ...[
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: _confirmDeleteKey,
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditKeyDialog(BuildContext context) {
    final keyCtrl = TextEditingController();
    bool isVerifying = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Gemini API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Get your free key from Google AI Studio:\naistudio.google.com/app/apikey',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'AIzaSy...',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final text = keyCtrl.text.trim();
                      if (text.isEmpty) {
                        setDialogState(() => errorText = 'Key cannot be empty');
                        return;
                      }
                      setDialogState(() {
                        isVerifying = true;
                        errorText = null;
                      });

                      final isValid = await AiService.validateApiKey(text);
                      if (!isValid) {
                        setDialogState(() {
                          isVerifying = false;
                          errorText = 'Invalid key or network issue';
                        });
                        return;
                      }

                      await AiService.saveApiKey(text);
                      await _checkStatus();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: isVerifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verify & Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteKey() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove API Key?'),
        content: const Text('AI auto-tagging will be disabled until you enter a key again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await AiService.deleteApiKey();
              await _checkStatus();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );

  }
}

