/// FitAI Food Database & Nutrition Service
///
/// Provides a local catalogue of common foods (including South-Asian /
/// Pakistani staples) with calorie and macro values, plus a service that
/// logs meals to SharedPreferences and computes daily totals against the
/// user's calorie target.
///
/// The photo-based food analyzer described in the product document needs
/// a cloud vision model (Gemini vision). When no API key is configured
/// the app is honest about that: photos are saved with the meal as a
/// reference and the user enters the items manually. When a key is set,
/// the analyzer calls the vision model for an estimate and clearly marks
/// it as an estimate, never as exact values.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile_service.dart';

/// A single food with its macro values per [serving] (e.g. 1 piece, 100g).
class FoodItem {
  final String name;
  final String serving;
  final int calories;
  final double protein; // grams
  final double carbs; // grams
  final double fat; // grams

  const FoodItem({
    required this.name,
    required this.serving,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'serving': serving,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        name: j['name'] as String? ?? '',
        serving: j['serving'] as String? ?? '',
        calories: (j['calories'] as num?)?.toInt() ?? 0,
        protein: (j['protein'] as num?)?.toDouble() ?? 0,
        carbs: (j['carbs'] as num?)?.toDouble() ?? 0,
        fat: (j['fat'] as num?)?.toDouble() ?? 0,
      );
}

/// A logged meal entry for a given day.
class MealEntry {
  final String id;
  final DateTime date;
  final String mealType; // Breakfast / Lunch / Dinner / Snack
  final FoodItem food;
  final double servings;
  final String? photoPath;
  final bool? aiEstimated;

  MealEntry({
    required this.id,
    required this.date,
    required this.mealType,
    required this.food,
    this.servings = 1,
    this.photoPath,
    this.aiEstimated,
  });

  int get totalCalories => (food.calories * servings).round();
  double get totalProtein => food.protein * servings;
  double get totalCarbs => food.carbs * servings;
  double get totalFat => food.fat * servings;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'mealType': mealType,
        'food': food.toJson(),
        'servings': servings,
        'photoPath': photoPath,
        'aiEstimated': aiEstimated,
      };

  factory MealEntry.fromJson(Map<String, dynamic> j) {
    return MealEntry(
      id: j['id'] as String? ?? '',
      date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      mealType: j['mealType'] as String? ?? 'Snack',
      food: FoodItem.fromJson(
          j['food'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      servings: (j['servings'] as num?)?.toDouble() ?? 1,
      photoPath: j['photoPath'] as String?,
      aiEstimated: j['aiEstimated'] as bool?,
    );
  }
}

/// Static catalogue of common foods, including Pakistani staples.
class FoodDatabase {
  const FoodDatabase._();

  static const items = <FoodItem>[
    // ---- South-Asian staples ----
    FoodItem(
        name: 'Roti (chapatti)',
        serving: '1 piece',
        calories: 120,
        protein: 3,
        carbs: 18,
        fat: 3.5),
    FoodItem(
        name: 'Naan',
        serving: '1 piece',
        calories: 260,
        protein: 9,
        carbs: 45,
        fat: 5),
    FoodItem(
        name: 'Plain rice (cooked)',
        serving: '1 cup',
        calories: 205,
        protein: 4.2,
        carbs: 45,
        fat: 0.4),
    FoodItem(
        name: 'Daal (lentils)',
        serving: '1 cup',
        calories: 180,
        protein: 9,
        carbs: 30,
        fat: 1),
    FoodItem(
        name: 'Chicken curry',
        serving: '1 cup',
        calories: 290,
        protein: 28,
        carbs: 8,
        fat: 16),
    FoodItem(
        name: 'Biryani (chicken)',
        serving: '1 plate',
        calories: 500,
        protein: 22,
        carbs: 60,
        fat: 18),
    FoodItem(
        name: 'Haleem',
        serving: '1 cup',
        calories: 230,
        protein: 10,
        carbs: 30,
        fat: 7),
    FoodItem(
        name: 'Paratha',
        serving: '1 piece',
        calories: 300,
        protein: 5,
        carbs: 38,
        fat: 13),
    FoodItem(
        name: 'Halwa (sooji)',
        serving: '1/2 cup',
        calories: 320,
        protein: 4,
        carbs: 50,
        fat: 12),
    FoodItem(
        name: 'Lassi (sweet)',
        serving: '1 glass',
        calories: 180,
        protein: 5,
        carbs: 28,
        fat: 4),
    // ---- Proteins ----
    FoodItem(
        name: 'Egg (whole)',
        serving: '1 large',
        calories: 74,
        protein: 6.3,
        carbs: 0.4,
        fat: 5),
    FoodItem(
        name: 'Chicken breast (grilled)',
        serving: '100 g',
        calories: 165,
        protein: 31,
        carbs: 0,
        fat: 3.6),
    FoodItem(
        name: 'Beef (lean)',
        serving: '100 g',
        calories: 217,
        protein: 26,
        carbs: 0,
        fat: 13),
    FoodItem(
        name: 'Fish (tilapia)',
        serving: '100 g',
        calories: 96,
        protein: 20,
        carbs: 0,
        fat: 1.4),
    FoodItem(
        name: 'Chickpeas',
        serving: '1 cup',
        calories: 269,
        protein: 14.5,
        carbs: 45,
        fat: 4),
    FoodItem(
        name: 'Tofu',
        serving: '100 g',
        calories: 76,
        protein: 8,
        carbs: 1.9,
        fat: 4.8),
    // ---- Dairy ----
    FoodItem(
        name: 'Milk (whole)',
        serving: '1 cup',
        calories: 149,
        protein: 8,
        carbs: 12,
        fat: 8),
    FoodItem(
        name: 'Yogurt (plain)',
        serving: '1 cup',
        calories: 100,
        protein: 17,
        carbs: 6,
        fat: 0.7),
    FoodItem(
        name: 'Paneer',
        serving: '100 g',
        calories: 296,
        protein: 18,
        carbs: 6,
        fat: 22),
    // ---- Carbs / fruit / veg ----
    FoodItem(
        name: 'Banana',
        serving: '1 medium',
        calories: 105,
        protein: 1.3,
        carbs: 27,
        fat: 0.4),
    FoodItem(
        name: 'Apple',
        serving: '1 medium',
        calories: 95,
        protein: 0.5,
        carbs: 25,
        fat: 0.3),
    FoodItem(
        name: 'Oats (dry)',
        serving: '1/2 cup',
        calories: 150,
        protein: 5,
        carbs: 27,
        fat: 3),
    FoodItem(
        name: 'Potato (boiled)',
        serving: '1 medium',
        calories: 130,
        protein: 3,
        carbs: 30,
        fat: 0.2),
    FoodItem(
        name: 'Mixed vegetables',
        serving: '1 cup',
        calories: 80,
        protein: 3,
        carbs: 16,
        fat: 0.5),
    FoodItem(
        name: 'Salad (green)',
        serving: '1 bowl',
        calories: 50,
        protein: 2,
        carbs: 9,
        fat: 0.3),
    FoodItem(
        name: 'Water',
        serving: '1 glass',
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0),
  ];

  static List<FoodItem> search(String query) {
    if (query.trim().isEmpty) return items;
    final q = query.toLowerCase();
    return items.where((f) => f.name.toLowerCase().contains(q)).toList();
  }
}

/// Result of an AI food-photo analysis.
class FoodAnalysis {
  final String summary;
  final List<FoodItem> detectedItems;
  final bool isEstimate;
  final bool fromCloud;

  const FoodAnalysis({
    required this.summary,
    required this.detectedItems,
    this.isEstimate = false,
    this.fromCloud = false,
  });
}

/// Loads/saves meals and computes daily totals.
class NutritionService {
  NutritionService._();
  static final NutritionService instance = NutritionService._();

  static const _kMeals = 'meal_log';
  static const _kCustomCalorieTarget = 'custom_calorie_target';
  static const _kCustomMacroTargets = 'custom_macro_targets';

  /// Optional Gemini API key for food-photo analysis.
  String? _apiKey;
  void setApiKey(String? key) =>
      _apiKey = (key == null || key.isEmpty) ? null : key;
  bool get hasCloud => _apiKey != null;

  /// Custom calorie target override (set by user).
  int? _customCalorieTarget;

  /// Custom macro targets: {protein, carbs, fat} in grams.
  Map<String, int>? _customMacroTargets;

  int? get customCalorieTarget => _customCalorieTarget;
  Map<String, int>? get customMacroTargets => _customMacroTargets;

  Future<void> loadCustomTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final calTarget = prefs.getInt(_kCustomCalorieTarget);
    if (calTarget != null) {
      _customCalorieTarget = calTarget;
    }
    final macroRaw = prefs.getString(_kCustomMacroTargets);
    if (macroRaw != null) {
      try {
        final decoded = jsonDecode(macroRaw) as Map<String, dynamic>;
        _customMacroTargets = {
          'protein': (decoded['protein'] as num?)?.toInt() ?? 0,
          'carbs': (decoded['carbs'] as num?)?.toInt() ?? 0,
          'fat': (decoded['fat'] as num?)?.toInt() ?? 0,
        };
      } catch (_) {
        _customMacroTargets = null;
      }
    }
  }

  Future<void> setCustomTargets({
    int? calorieTarget,
    int? protein,
    int? carbs,
    int? fat,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (calorieTarget != null) {
      _customCalorieTarget = calorieTarget;
      await prefs.setInt(_kCustomCalorieTarget, calorieTarget);
    } else {
      _customCalorieTarget = null;
      await prefs.remove(_kCustomCalorieTarget);
    }
    if (protein != null && carbs != null && fat != null) {
      _customMacroTargets = {'protein': protein, 'carbs': carbs, 'fat': fat};
      await prefs.setString(
          _kCustomMacroTargets, jsonEncode(_customMacroTargets));
    } else {
      _customMacroTargets = null;
      await prefs.remove(_kCustomMacroTargets);
    }
  }

  /// Load all meal entries.
  Future<List<MealEntry>> loadMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMeals);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => MealEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to load meals: $e');
      return [];
    }
  }

  /// Save the full meal list.
  Future<void> _saveMeals(List<MealEntry> meals) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(meals.map((m) => m.toJson()).toList());
    await prefs.setString(_kMeals, raw);
  }

  /// Add a meal entry.
  Future<void> addMeal(MealEntry entry) async {
    final meals = await loadMeals();
    meals.add(entry);
    await _saveMeals(meals);
  }

  /// Remove a meal entry by id.
  Future<void> removeMeal(String id) async {
    final meals = await loadMeals();
    meals.removeWhere((m) => m.id == id);
    await _saveMeals(meals);
  }

  /// Clear all meals (used by delete-account flow).
  Future<void> clearMeals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMeals);
  }

  /// Meals for a specific day.
  Future<List<MealEntry>> mealsForDay(DateTime day) async {
    final meals = await loadMeals();
    return meals.where((m) {
      return m.date.year == day.year &&
          m.date.month == day.month &&
          m.date.day == day.day;
    }).toList();
  }

  /// Daily totals for a given day.
  Future<Map<String, double>> totalsForDay(DateTime day) async {
    final meals = await mealsForDay(day);
    double cal = 0, p = 0, c = 0, f = 0;
    for (final m in meals) {
      cal += m.totalCalories;
      p += m.totalProtein;
      c += m.totalCarbs;
      f += m.totalFat;
    }
    return {
      'calories': cal,
      'protein': p,
      'carbs': c,
      'fat': f,
    };
  }

  /// Recommended daily calorie target from a profile.
  /// Returns custom target if set, otherwise computes from profile.
  int? targetCalories(UserProfile profile) {
    if (_customCalorieTarget != null) return _customCalorieTarget;
    final tdee = profile.tdee;
    if (tdee == null) return null;
    // Goal-aware adjustment, kept within safe bounds.
    switch (profile.goal.toLowerCase()) {
      case 'weight management':
      case 'stay active':
        return tdee.round();
      case 'build strength':
      case 'muscle gain':
        return (tdee * 1.1).round();
      case 'improve fitness':
        return tdee.round();
      default:
        return (tdee * 0.9).round();
    }
  }

  /// Macro targets (grams) from profile.
  /// Returns custom macros if set, otherwise computes from profile + calorie target.
  Map<String, int>? targetMacros(UserProfile profile) {
    if (_customMacroTargets != null) return _customMacroTargets;
    final cal = targetCalories(profile);
    if (cal == null) return null;
    final w = profile.weightKg ?? 70;
    final isStrength =
        profile.goal.toLowerCase() == 'build strength' ||
        profile.goal.toLowerCase() == 'muscle gain';
    final proteinGrams = (w * (isStrength ? 2.0 : 1.6)).round();
    final fatCalories = cal * 0.25;
    final fatGrams = (fatCalories / 9).round();
    final carbCalories = cal - (proteinGrams * 4) - fatCalories;
    final carbGrams = (carbCalories / 4).round();
    return {
      'protein': proteinGrams,
      'carbs': carbGrams > 0 ? carbGrams : 0,
      'fat': fatGrams,
    };
  }

  /// Analyze a food photo. When no API key is configured, returns an honest
  /// message telling the user to log items manually. When a key is set,
  /// asks the vision model and marks results as estimates.
  Future<FoodAnalysis> analyzePhoto(File image) async {
    if (!hasCloud) {
      return const FoodAnalysis(
        summary:
            'AI food photo analysis is not connected. Add a Gemini API key '
            'in Settings to enable photo recognition. For now, please pick '
            'the food items from the list and enter the serving size.',
        detectedItems: [],
        isEstimate: false,
        fromCloud: false,
      );
    }
    try {
      final bytes = await image.readAsBytes();
      final b64 = base64Encode(bytes);
      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-1.5-flash:generateContent?key=$_apiKey',
      );
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': 'Identify the food items in this image. Reply ONLY '
                    'with a JSON array of objects with keys name, serving, '
                    'calories, protein, carbs, fat (numbers). These are '
                    'estimates.'
              },
              {
                'inlineData': {'mimeType': 'image/jpeg', 'data': b64}
              }
            ],
          },
        ],
      });
      final res = await http.post(endpoint, body: body);
      if (res.statusCode != 200) {
        return const FoodAnalysis(
          summary: 'Could not analyze the photo right now. Please log the '
              'items manually.',
          detectedItems: [],
          isEstimate: false,
        );
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return const FoodAnalysis(
          summary: 'No food recognized. Please log items manually.',
          detectedItems: [],
        );
      }
      final text = (candidates.first['content']['parts'] as List).first['text']
          as String;
      // Extract the JSON array from the response.
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start == -1 || end == -1) {
        return FoodAnalysis(
          summary: text.trim(),
          detectedItems: [],
          isEstimate: true,
          fromCloud: true,
        );
      }
      final jsonText = text.substring(start, end + 1);
      final arr = jsonDecode(jsonText) as List;
      final detected = arr
          .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return FoodAnalysis(
        summary: 'Estimated items (AI vision — values are approximate):',
        detectedItems: detected,
        isEstimate: true,
        fromCloud: true,
      );
    } catch (e) {
      debugPrint('Food analysis failed: $e');
      return const FoodAnalysis(
        summary: 'Photo analysis failed. Please log items manually.',
        detectedItems: [],
      );
    }
  }
}
