/// FitAI User Profile Service
///
/// Single source of truth for the personalization data every AI module
/// reads from. Reuses the SharedPreferences keys already used by the
/// existing Personal Information / Settings screens so existing data is
/// preserved, and adds the richer profile fields described in the FitAI
/// product documents (activity level, equipment, experience, etc.).
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Activity level, used by calorie/target calculations and the AI coach.
enum ActivityLevel {
  sedentary('Sedentary', 1.2),
  light('Lightly active', 1.375),
  moderate('Moderately active', 1.55),
  active('Very active', 1.725),
  athlete('Athlete', 1.9);

  final String label;
  final double factor;
  const ActivityLevel(this.label, this.factor);

  static ActivityLevel fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return ActivityLevel.sedentary;
  }
}

/// Gender, used by BMR calculation.
enum Gender { male, female, other }

/// Health conditions a user can optionally select.
enum HealthCondition {
  none,
  diabetes,
  cardiovascular,
  highBP,
  jointMobility,
  respiratory,
  cancer,
  recentSurgery,
  pregnancyPostpartum,
  other;

  bool get isHighRisk =>
      this == cardiovascular ||
      this == highBP ||
      this == recentSurgery ||
      this == cancer;

  static HealthCondition fromName(String? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return HealthCondition.none;
  }
}

/// Age group for age-aware personalization.
enum AgeGroup {
  child,
  teen,
  adult,
  older;

  static AgeGroup fromAge(int? age) {
    if (age == null) return AgeGroup.adult;
    if (age < 13) return AgeGroup.child;
    if (age < 18) return AgeGroup.teen;
    if (age >= 60) return AgeGroup.older;
    return AgeGroup.adult;
  }

  bool get isMinor => this == child || this == teen;
}

/// A snapshot of the user's profile used to personalize AI output.
class UserProfile {
  final String name;
  final String age;
  final String height; // cm
  final String weight; // kg
  final String goal;
  final String activityLevelName;
  final String experience; // Beginner / Intermediate / Advanced
  final String equipment; // Home / Gym / Outdoor / None
  final String daysPerWeek;
  final String minutesPerSession;
  final String dietaryPreference;
  final String language;
  final String genderName;
  final List<String> healthConditionNames;
  final String workoutLocation;
  final List<String> preferredDays;

  const UserProfile({
    this.name = '',
    this.age = '',
    this.height = '',
    this.weight = '',
    this.goal = 'Build strength',
    this.activityLevelName = 'sedentary',
    this.experience = 'Beginner',
    this.equipment = 'None',
    this.daysPerWeek = '3',
    this.minutesPerSession = '45',
    this.dietaryPreference = 'No preference',
    this.language = 'English',
    this.genderName = 'male',
    this.healthConditionNames = const <String>[],
    this.workoutLocation = 'Home',
    this.preferredDays = const <String>[],
  });

  bool get isComplete =>
      name.isNotEmpty &&
      age.isNotEmpty &&
      height.isNotEmpty &&
      weight.isNotEmpty;

  int? get ageInt => int.tryParse(age);
  double? get heightCm => double.tryParse(height);
  double? get weightKg => double.tryParse(weight);
  ActivityLevel get activity => ActivityLevel.fromName(activityLevelName);
  Gender get gender {
    for (final v in Gender.values) {
      if (v.name == genderName) return v;
    }
    return Gender.male;
  }

  List<HealthCondition> get healthConditions =>
      healthConditionNames.map(HealthCondition.fromName).toList();

  bool get hasHighRiskCondition => healthConditions.any((c) => c.isHighRisk);
  AgeGroup get ageGroup => AgeGroup.fromAge(ageInt);

  /// Body Mass Index, or null when height/weight are missing.
  double? get bmi {
    final h = heightCm;
    final w = weightKg;
    if (h == null || w == null || h <= 0) return null;
    final m = h / 100;
    return w / (m * m);
  }

  /// Basal Metabolic Rate (Mifflin–St Jeor), gender-aware.
  double? get bmr {
    final a = ageInt;
    final h = heightCm;
    final w = weightKg;
    if (a == null || h == null || w == null) return null;
    final g = gender;
    final constant = g == Gender.female
        ? -161.0
        : g == Gender.other
            ? -78.0
            : 5.0;
    return 10 * w + 6.25 * h - 5 * a + constant;
  }

  /// Total daily energy expenditure, used as the calorie target baseline.
  double? get tdee {
    final base = bmr;
    if (base == null) return null;
    return base * activity.factor;
  }

  /// A short, human-readable summary the AI coach prepends to its context.
  String toContextSummary() {
    final parts = <String>[];
    if (name.isNotEmpty) parts.add('Name: $name');
    if (ageInt != null) parts.add('Age: $age');
    parts.add('Age group: ${ageGroup.name}');
    parts.add('Gender: ${gender.name}');
    if (heightCm != null) parts.add('Height: $height cm');
    if (weightKg != null) parts.add('Weight: $weight kg');
    parts.add('Goal: $goal');
    parts.add('Activity: ${activity.label}');
    parts.add('Experience: $experience');
    parts.add('Equipment: $equipment');
    parts.add('Location: $workoutLocation');
    parts.add('Availability: $daysPerWeek days/week, $minutesPerSession min');
    if (preferredDays.isNotEmpty) {
      parts.add('Preferred days: ${preferredDays.join(', ')}');
    }
    parts.add('Diet: $dietaryPreference');
    if (healthConditionNames.isNotEmpty) {
      parts.add('Health: ${healthConditionNames.join(', ')}');
    }
    if (bmi != null) {
      parts.add('BMI: ${bmi!.toStringAsFixed(1)}');
    }
    if (tdee != null) {
      parts.add('Est. daily calories: ${tdee!.round()} kcal');
    }
    return parts.join('; ');
  }
}

/// Loads and persists the user profile via SharedPreferences.
class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  static const _kName = 'user_name';
  static const _kAge = 'user_age';
  static const _kHeight = 'user_height';
  static const _kWeight = 'user_weight';
  static const _kGoal = 'user_goal';
  static const _kActivity = 'user_activity_level';
  static const _kExperience = 'user_experience';
  static const _kEquipment = 'user_equipment';
  static const _kDays = 'user_days_per_week';
  static const _kMinutes = 'user_minutes_per_session';
  static const _kDiet = 'user_dietary_preference';
  static const _kLanguage = 'language';
  static const _kGender = 'user_gender';
  static const _kHealth = 'user_health_conditions';
  static const _kLocation = 'user_workout_location';
  static const _kPrefDays = 'user_preferred_days';

  Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final healthJson = prefs.getString(_kHealth) ?? '[]';
    final daysJson = prefs.getString(_kPrefDays) ?? '[]';
    return UserProfile(
      name: prefs.getString(_kName) ?? '',
      age: prefs.getString(_kAge) ?? '',
      height: prefs.getString(_kHeight) ?? '',
      weight: prefs.getString(_kWeight) ?? '',
      goal: prefs.getString(_kGoal) ?? 'Build strength',
      activityLevelName: prefs.getString(_kActivity) ?? 'sedentary',
      experience: prefs.getString(_kExperience) ?? 'Beginner',
      equipment: prefs.getString(_kEquipment) ?? 'None',
      daysPerWeek: prefs.getString(_kDays) ?? '3',
      minutesPerSession: prefs.getString(_kMinutes) ?? '45',
      dietaryPreference: prefs.getString(_kDiet) ?? 'No preference',
      language: prefs.getString(_kLanguage) ?? 'English',
      genderName: prefs.getString(_kGender) ?? 'male',
      healthConditionNames: _decodeStringList(healthJson),
      workoutLocation: prefs.getString(_kLocation) ?? 'Home',
      preferredDays: _decodeStringList(daysJson),
    );
  }

  static List<String> _decodeStringList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (_) {}
    return <String>[];
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, profile.name);
    await prefs.setString(_kAge, profile.age);
    await prefs.setString(_kHeight, profile.height);
    await prefs.setString(_kWeight, profile.weight);
    await prefs.setString(_kGoal, profile.goal);
    await prefs.setString(_kActivity, profile.activityLevelName);
    await prefs.setString(_kExperience, profile.experience);
    await prefs.setString(_kEquipment, profile.equipment);
    await prefs.setString(_kDays, profile.daysPerWeek);
    await prefs.setString(_kMinutes, profile.minutesPerSession);
    await prefs.setString(_kDiet, profile.dietaryPreference);
    await prefs.setString(_kLanguage, profile.language);
    await prefs.setString(_kGender, profile.genderName);
    await prefs.setString(_kHealth, jsonEncode(profile.healthConditionNames));
    await prefs.setString(_kLocation, profile.workoutLocation);
    await prefs.setString(_kPrefDays, jsonEncode(profile.preferredDays));
  }

  /// Update a single field without touching the others.
  Future<void> setField(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
