/// FitAI Nutrition Screen — Food Logging & Photo Analysis
///
/// Implements the food/nutrition feature described in the product
/// documents. Users can:
///   - log meals from a built-in food database (including Pakistani staples)
///   - see daily calorie and macro totals vs their personalized target
///   - capture a food photo for optional AI vision analysis
///
/// When no Gemini API key is configured, photo analysis is honest about
/// being unavailable and directs the user to log manually. When a key
/// is set, results are clearly marked as estimates, not exact values.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/app_localizations.dart' show L;
import '../core/food_data.dart';
import '../core/user_profile_service.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final NutritionService _nutrition = NutritionService.instance;
  List<MealEntry> _todayMeals = [];
  UserProfile? _profile;
  int? _targetCalories;
  Map<String, int>? _targetMacros;
  bool _isLoading = true;

  // Daily totals
  double _consumedCalories = 0;
  double _consumedProtein = 0;
  double _consumedCarbs = 0;
  double _consumedFat = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _profile = await UserProfileService.instance.load();
    await _nutrition.loadCustomTargets();
    _targetCalories = _nutrition.targetCalories(_profile!);
    _targetMacros = _nutrition.targetMacros(_profile!);
    _todayMeals = await _nutrition.mealsForDay(DateTime.now());

    final totals = await _nutrition.totalsForDay(DateTime.now());
    setState(() {
      _consumedCalories = totals['calories'] ?? 0;
      _consumedProtein = totals['protein'] ?? 0;
      _consumedCarbs = totals['carbs'] ?? 0;
      _consumedFat = totals['fat'] ?? 0;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _loadData();
  }

  // -------------------------------------------------------------------
  // Add meal via food search
  // -------------------------------------------------------------------

  Future<void> _showAddMealSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddMealSheet(
        onAdded: (food, servings, mealType) async {
          final entry = MealEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            date: DateTime.now(),
            mealType: mealType,
            food: food,
            servings: servings,
          );
          await _nutrition.addMeal(entry);
          if (ctx.mounted) Navigator.pop(ctx);
          _refresh();
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // Photo analysis
  // -------------------------------------------------------------------

  Future<void> _captureAndAnalyze() async {
    // Request camera permission.
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is needed to analyze food photos.')),
      );
      return;
    }

    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (photo == null) return;

    final file = File(photo.path);
    _showAnalysisDialog(file);
  }

  Future<void> _pickFromGallery() async {
    final status = await Permission.photos.request();
    if (!status.isGranted && !status.isLimited) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo library permission is needed to pick food images.')),
      );
      return;
    }

    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (photo == null) return;

    final file = File(photo.path);
    _showAnalysisDialog(file);
  }

  Future<void> _showAnalysisDialog(File image) async {
    setState(() => _isLoading = true);

    final analysis = await _nutrition.analyzePhoto(image);

    if (!mounted) return;
    setState(() => _isLoading = false);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Food Photo Analysis'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(image, height: 150, width: double.maxFinite,
                    fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Text(analysis.summary, style: const TextStyle(fontSize: 13)),
              if (analysis.fromCloud && analysis.isEstimate)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'These are AI estimates, not exact values. '
                          'Adjust serving sizes as needed.',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              if (analysis.detectedItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Detected items:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                ...analysis.detectedItems.map((item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${item.calories} kcal • P${item.protein.toStringAsFixed(1)} '
                        'C${item.carbs.toStringAsFixed(1)} F${item.fat.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(item.serving, style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        // Add this detected item to the log.
                        final entry = MealEntry(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          date: DateTime.now(),
                          mealType: _currentMealType(),
                          food: item,
                          servings: 1,
                          photoPath: image.path,
                          aiEstimated: true,
                        );
                        _nutrition.addMeal(entry);
                        Navigator.pop(ctx);
                        _refresh();
                      },
                    )),
              ],
            ],
          ),
        ),
        actions: [
          if (analysis.detectedItems.isEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showAddMealSheet();
              },
              child: const Text('Log Manually'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L.t('close')),
          ),
        ],
      ),
    );
  }

  String _currentMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Breakfast';
    if (hour < 15) return 'Lunch';
    if (hour < 21) return 'Dinner';
    return 'Snack';
  }

  // -------------------------------------------------------------------
  // Target settings
  // -------------------------------------------------------------------

  Future<void> _showTargetSettingsSheet() async {
    final calCtrl = TextEditingController(
        text: _targetCalories?.toString() ?? '');
    final proteinCtrl = TextEditingController(
        text: _targetMacros?['protein']?.toString() ?? '');
    final carbsCtrl = TextEditingController(
        text: _targetMacros?['carbs']?.toString() ?? '');
    final fatCtrl = TextEditingController(
        text: _targetMacros?['fat']?.toString() ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set Daily Targets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: calCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Calories (kcal)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: proteinCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Protein (g)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: carbsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Carbs (g)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: fatCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Fat (g)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final cal = int.tryParse(calCtrl.text);
                  final p = int.tryParse(proteinCtrl.text);
                  final c = int.tryParse(carbsCtrl.text);
                  final f = int.tryParse(fatCtrl.text);
                  await _nutrition.setCustomTargets(
                    calorieTarget: cal,
                    protein: p,
                    carbs: c,
                    fat: f,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _refresh();
                },
                icon: const Icon(Icons.check),
                label: Text(L.t('save')),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    calCtrl.dispose();
    proteinCtrl.dispose();
    carbsCtrl.dispose();
    fatCtrl.dispose();
  }

  // -------------------------------------------------------------------
  // Remove meal
  // -------------------------------------------------------------------

  Future<void> _removeMeal(String id) async {
    await _nutrition.removeMeal(id);
    _refresh();
  }

  // -------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final target = _targetCalories;
    final isRtl = L.isRtl;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(L.t('nutritionLog'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Set Targets',
              onPressed: _showTargetSettingsSheet,
            ),
            IconButton(
              icon: const Icon(Icons.photo_camera),
              tooltip: 'Analyze Food Photo',
              onPressed: _captureAndAnalyze,
            ),
            IconButton(
              icon: const Icon(Icons.photo_library),
              tooltip: 'Pick from Gallery',
              onPressed: _pickFromGallery,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryCard(target),
              const SizedBox(height: 16),
              _buildMacroBreakdown(),
              const SizedBox(height: 20),
              _buildMealList(),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddMealSheet,
          icon: const Icon(Icons.add),
          label: Text(L.t('addMeal')),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int? target) {
    final consumed = _consumedCalories.round();
    final remaining = (target ?? 0) - consumed;
    final progress = target != null && target > 0
        ? (consumed / target).clamp(0.0, 1.5)
        : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              L.t('dailyTarget'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$consumed',
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.bold),
                ),
                Text(
                  target != null ? ' / $target ${L.t('calories')}' : ' ${L.t('calories')}',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: progress > 1.0
                    ? Colors.red
                    : (progress > 0.85 ? Colors.orange : Colors.green),
              ),
            ),
            const SizedBox(height: 8),
            if (target != null)
              Text(
                remaining >= 0
                    ? '$remaining ${L.t('calories')} ${L.t('remaining')}'
                    : '${remaining.abs()} ${L.t('calories')} ${L.t('overTarget')}',
                style: TextStyle(
                  fontSize: 12,
                  color: remaining >= 0 ? Colors.green.shade700 : Colors.red,
                ),
              )
            else
              Text(
                L.t('setWeightHeight'),
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBreakdown() {
    final macros = _targetMacros;
    return Row(
      children: [
        _macroChip(L.t('protein'), _consumedProtein, Colors.blue,
            target: macros?['protein']),
        const SizedBox(width: 8),
        _macroChip(L.t('carbs'), _consumedCarbs, Colors.amber,
            target: macros?['carbs']),
        const SizedBox(width: 8),
        _macroChip(L.t('fat'), _consumedFat, Colors.purple,
            target: macros?['fat']),
      ],
    );
  }

  Widget _macroChip(String label, double grams, Color color, {int? target}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              target != null ? '${grams.round()}g / ${target}g' : '${grams.round()}g',
              style: TextStyle(fontSize: target != null ? 13 : 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealList() {
    if (_todayMeals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                '${L.t('noMealsLogged')}\n${L.t('tapToAdd')}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    // Group by meal type.
    final groups = <String, List<MealEntry>>{};
    for (final m in _todayMeals) {
      groups.putIfAbsent(m.mealType, () => []).add(m);
    }
    final orderedTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final type in orderedTypes)
          if (groups[type] != null && groups[type]!.isNotEmpty) ...[
            _buildMealTypeHeader(type, groups[type]!),
            ...groups[type]!.map((m) => _buildMealTile(m)),
          ],
        // Any other meal types not in the standard list.
        for (final type in groups.keys)
          if (!orderedTypes.contains(type)) ...[
            _buildMealTypeHeader(type, groups[type]!),
            ...groups[type]!.map((m) => _buildMealTile(m)),
          ],
      ],
    );
  }

  Widget _buildMealTypeHeader(String type, List<MealEntry> meals) {
    final typeCalories = meals.fold<int>(0, (sum, m) => sum + m.totalCalories);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 8),
          Text('$typeCalories kcal', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildMealTile(MealEntry meal) {
    return Dismissible(
      key: ValueKey(meal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeMeal(meal.id),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: meal.photoPath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(File(meal.photoPath!),
                      width: 40, height: 40, fit: BoxFit.cover),
                )
              : CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.restaurant, size: 18, color: Colors.blue.shade700),
                ),
          title: Row(
            children: [
              Flexible(
                child: Text(meal.food.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              if (meal.aiEstimated == true)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.auto_awesome, size: 12, color: Colors.orange.shade400),
                ),
            ],
          ),
          subtitle: Text(
            '${meal.servings}× ${meal.food.serving} • ${meal.totalCalories} kcal • '
            'P${meal.totalProtein.toStringAsFixed(0)} C${meal.totalCarbs.toStringAsFixed(0)} '
            'F${meal.totalFat.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Text('${meal.totalCalories} kcal',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Add Meal Bottom Sheet — searchable food list + serving selector
// ---------------------------------------------------------------------

class _AddMealSheet extends StatefulWidget {
  final void Function(FoodItem food, double servings, String mealType) onAdded;

  const _AddMealSheet({required this.onAdded});

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  final _searchController = TextEditingController();
  final _servingsController = TextEditingController(text: '1');
  List<FoodItem> _results = FoodDatabase.items;
  FoodItem? _selected;
  String _mealType = 'Breakfast';

  @override
  void initState() {
    super.initState();
    final hour = DateTime.now().hour;
    if (hour < 11) {
      _mealType = 'Breakfast';
    } else if (hour < 15) {
      _mealType = 'Lunch';
    } else if (hour < 21) {
      _mealType = 'Dinner';
    } else {
      _mealType = 'Snack';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _servingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(L.t('logFood'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search food (e.g. roti, chicken, rice...)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (q) {
                setState(() {
                  _results = FoodDatabase.search(q);
                  _selected = null;
                });
              },
            ),
            const SizedBox(height: 12),
            if (_selected == null)
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final food = _results[i];
                    return ListTile(
                      title: Text(food.name, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${food.serving} • ${food.calories} kcal • '
                        'P${food.protein.toStringAsFixed(1)} '
                        'C${food.carbs.toStringAsFixed(1)} '
                        'F${food.fat.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => setState(() => _selected = food),
                    );
                  },
                ),
              )
            else
              _buildSelectedFood(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFood() {
    final food = _selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${food.serving} • ${food.calories} kcal',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selected = null),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Meal type selector
        const Text('Meal:', style: TextStyle(fontSize: 13)),
        Wrap(
          spacing: 8,
          children: ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((type) {
            return ChoiceChip(
              label: Text(type),
              selected: _mealType == type,
              onSelected: (_) => setState(() => _mealType = type),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Servings
        TextField(
          controller: _servingsController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Servings',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        // Save button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              final servings = double.tryParse(_servingsController.text) ?? 1;
              widget.onAdded(food, servings, _mealType);
            },
            icon: const Icon(Icons.check),
            label: Text(L.t('save')),
          ),
        ),
      ],
    );
  }
}
