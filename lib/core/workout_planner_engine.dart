/// FitAI Workout Planner Engine
///
/// Generates personalized workout plans based on user profile, routine,
/// and progress. Uses Gemini AI when available, falls back to rule-based
/// on-device generation.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile_service.dart';

/// A single exercise in a workout plan.
class PlannedExercise {
  final String name;
  final String muscleGroup;
  final int sets;
  final int reps;
  final int restSeconds;
  final String instructions;

  const PlannedExercise({
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.instructions,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'muscleGroup': muscleGroup,
    'sets': sets,
    'reps': reps,
    'restSeconds': restSeconds,
    'instructions': instructions,
  };

  factory PlannedExercise.fromJson(Map<String, dynamic> j) => PlannedExercise(
    name: j['name'] as String? ?? '',
    muscleGroup: j['muscleGroup'] as String? ?? '',
    sets: (j['sets'] as num?)?.toInt() ?? 3,
    reps: (j['reps'] as num?)?.toInt() ?? 10,
    restSeconds: (j['restSeconds'] as num?)?.toInt() ?? 60,
    instructions: j['instructions'] as String? ?? '',
  );
}

/// A meal suggestion in a daily plan.
class PlannedMeal {
  final String mealType; // Breakfast, Lunch, Dinner, Snack
  final String foodName;
  final String serving;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  const PlannedMeal({
    required this.mealType,
    required this.foodName,
    required this.serving,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toJson() => {
    'mealType': mealType,
    'foodName': foodName,
    'serving': serving,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  factory PlannedMeal.fromJson(Map<String, dynamic> j) => PlannedMeal(
    mealType: j['mealType'] as String? ?? 'Snack',
    foodName: j['foodName'] as String? ?? '',
    serving: j['serving'] as String? ?? '',
    calories: (j['calories'] as num?)?.toInt() ?? 0,
    protein: (j['protein'] as num?)?.toDouble() ?? 0,
    carbs: (j['carbs'] as num?)?.toDouble() ?? 0,
    fat: (j['fat'] as num?)?.toDouble() ?? 0,
  );
}

/// A complete daily workout plan.
class DailyPlan {
  final DateTime date;
  final List<PlannedExercise> exercises;
  final List<PlannedMeal> meals;
  final String warmup;
  final String cooldown;
  final String notes;
  final bool completed;

  const DailyPlan({
    required this.date,
    required this.exercises,
    required this.meals,
    required this.warmup,
    required this.cooldown,
    required this.notes,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'meals': meals.map((m) => m.toJson()).toList(),
    'warmup': warmup,
    'cooldown': cooldown,
    'notes': notes,
    'completed': completed,
  };

  factory DailyPlan.fromJson(Map<String, dynamic> j) => DailyPlan(
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    exercises:
        (j['exercises'] as List<dynamic>?)
            ?.map((e) => PlannedExercise.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    meals:
        (j['meals'] as List<dynamic>?)
            ?.map((m) => PlannedMeal.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [],
    warmup: j['warmup'] as String? ?? '',
    cooldown: j['cooldown'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    completed: j['completed'] as bool? ?? false,
  );
}

/// User's daily routine information.
class UserRoutine {
  final String wakeTime;
  final String sleepTime;
  final String workSchedule;
  final String mealTimes;
  final String freeTime;
  final String workoutTimePreference;
  final String notes;

  const UserRoutine({
    this.wakeTime = '',
    this.sleepTime = '',
    this.workSchedule = '',
    this.mealTimes = '',
    this.freeTime = '',
    this.workoutTimePreference = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'wakeTime': wakeTime,
    'sleepTime': sleepTime,
    'workSchedule': workSchedule,
    'mealTimes': mealTimes,
    'freeTime': freeTime,
    'workoutTimePreference': workoutTimePreference,
    'notes': notes,
  };

  factory UserRoutine.fromJson(Map<String, dynamic> j) => UserRoutine(
    wakeTime: j['wakeTime'] as String? ?? '',
    sleepTime: j['sleepTime'] as String? ?? '',
    workSchedule: j['workSchedule'] as String? ?? '',
    mealTimes: j['mealTimes'] as String? ?? '',
    freeTime: j['freeTime'] as String? ?? '',
    workoutTimePreference: j['workoutTimePreference'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
  );

  bool get isEmpty =>
      wakeTime.isEmpty &&
      sleepTime.isEmpty &&
      workSchedule.isEmpty &&
      mealTimes.isEmpty &&
      freeTime.isEmpty &&
      workoutTimePreference.isEmpty &&
      notes.isEmpty;
}

/// Routine analysis result from AI.
/// A single routine issue with structured problem/correction/reason.
class RoutineIssue {
  final String problem;
  final String correction;
  final String reason;

  const RoutineIssue({
    required this.problem,
    required this.correction,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'problem': problem,
    'correction': correction,
    'reason': reason,
  };

  factory RoutineIssue.fromJson(Map<String, dynamic> j) => RoutineIssue(
    problem: j['problem'] as String? ?? '',
    correction: j['correction'] as String? ?? '',
    reason: j['reason'] as String? ?? '',
  );
}

class RoutineAnalysis {
  final List<RoutineIssue> issues;
  final List<String> suggestions;
  final bool isValid;
  final bool isAiGenerated;

  const RoutineAnalysis({
    required this.issues,
    required this.suggestions,
    this.isValid = true,
    this.isAiGenerated = false,
  });
}

class WorkoutPlannerEngine {
  WorkoutPlannerEngine._();
  static final WorkoutPlannerEngine instance = WorkoutPlannerEngine._();

  static const _kRoutineKey = 'workout_routine';
  static const _kPlansKey = 'workout_plans';

  String? _apiKey;

  void setApiKey(String? key) {
    _apiKey = (key == null || key.isEmpty) ? null : key;
  }

  bool get hasCloud => _apiKey != null && _apiKey!.isNotEmpty;

  // -------------------------------------------------------------------
  // ROUTINE STORAGE
  // -------------------------------------------------------------------

  Future<UserRoutine> loadRoutine() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kRoutineKey);
    if (json == null) return const UserRoutine();
    try {
      return UserRoutine.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to load routine: $e');
      return const UserRoutine();
    }
  }

  Future<void> saveRoutine(UserRoutine routine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRoutineKey, jsonEncode(routine.toJson()));
  }

  // -------------------------------------------------------------------
  // PLAN STORAGE
  // -------------------------------------------------------------------

  Future<List<DailyPlan>> loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kPlansKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      final allPlans = list
          .map((e) => DailyPlan.fromJson(e as Map<String, dynamic>))
          .toList();

      // Deduplicate by calendar date (year/month/day).
      // Keep the LAST plan for each date (most recently added).
      final Map<String, DailyPlan> deduped = {};
      for (final plan in allPlans) {
        final key =
            '${plan.date.year}-${plan.date.month.toString().padLeft(2, '0')}-${plan.date.day.toString().padLeft(2, '0')}';
        deduped[key] = plan; // later entries overwrite earlier ones
      }
      final plans = deduped.values.toList();
      plans.sort((a, b) => a.date.compareTo(b.date));

      // If duplicates were found and removed, persist the cleaned list.
      if (plans.length < allPlans.length) {
        await savePlans(plans);
      }

      return plans;
    } catch (e) {
      debugPrint('Failed to load plans: $e');
      return [];
    }
  }

  Future<void> savePlans(List<DailyPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(plans.map((p) => p.toJson()).toList());
    await prefs.setString(_kPlansKey, json);
  }

  Future<void> addPlan(DailyPlan plan) async {
    final plans = await loadPlans();
    // Remove any existing plan for the same calendar date
    // (compare year/month/day only, not time)
    plans.removeWhere(
      (p) =>
          p.date.year == plan.date.year &&
          p.date.month == plan.date.month &&
          p.date.day == plan.date.day,
    );
    plans.add(plan);
    plans.sort((a, b) => a.date.compareTo(b.date));
    await savePlans(plans);
  }

  Future<void> markPlanCompleted(DateTime date) async {
    final plans = await loadPlans();
    final index = plans.indexWhere(
      (p) =>
          p.date.year == date.year &&
          p.date.month == date.month &&
          p.date.day == date.day,
    );
    if (index >= 0) {
      final old = plans[index];
      plans[index] = DailyPlan(
        date: old.date,
        exercises: old.exercises,
        meals: old.meals,
        warmup: old.warmup,
        cooldown: old.cooldown,
        notes: old.notes,
        completed: true,
      );
      await savePlans(plans);
    }
  }

  Future<DailyPlan?> getPlanForDate(DateTime date) async {
    final plans = await loadPlans();
    for (final plan in plans) {
      if (plan.date.year == date.year &&
          plan.date.month == date.month &&
          plan.date.day == date.day) {
        return plan;
      }
    }
    return null;
  }

  // -------------------------------------------------------------------
  // ROUTINE ANALYSIS
  // -------------------------------------------------------------------

  Future<RoutineAnalysis> analyzeRoutine(
    UserRoutine routine,
    UserProfile profile,
  ) async {
    if (hasCloud) {
      try {
        return await _analyzeRoutineWithAI(routine, profile);
      } catch (e) {
        debugPrint('AI routine analysis failed: $e');
      }
    }
    return _analyzeRoutineOnDevice(routine, profile);
  }

  Future<RoutineAnalysis> _analyzeRoutineWithAI(
    UserRoutine routine,
    UserProfile profile,
  ) async {
    final prompt =
        '''
You are a fitness coach analyzing a user's daily routine.

User Profile:
${profile.toContextSummary()}

User's Daily Routine:
- Wake time: ${routine.wakeTime.isEmpty ? 'Not specified' : routine.wakeTime}
- Sleep time: ${routine.sleepTime.isEmpty ? 'Not specified' : routine.sleepTime}
- Work/School schedule: ${routine.workSchedule.isEmpty ? 'Not specified' : routine.workSchedule}
- Meal times: ${routine.mealTimes.isEmpty ? 'Not specified' : routine.mealTimes}
- Free time: ${routine.freeTime.isEmpty ? 'Not specified' : routine.freeTime}
- Preferred workout time: ${routine.workoutTimePreference.isEmpty ? 'Not specified' : routine.workoutTimePreference}
- Additional notes: ${routine.notes.isEmpty ? 'None' : routine.notes}

Analyze this routine and identify potential issues with workout timing, recovery, meal timing, consistency, or feasibility.

For each issue, provide:
- problem: What appears to be wrong or potentially inefficient
- correction: What the user can change
- reason: Why that correction may help

Also provide general suggestions.

Respond in JSON format:
{
  "issues": [
    {"problem": "...", "correction": "...", "reason": "..."}
  ],
  "suggestions": ["suggestion 1", "suggestion 2"]
}

Be practical and encouraging. Do not diagnose medical conditions.
Do not invent calories, nutrients, or portion sizes.
''';

    final response = await _callGemini(prompt);
    if (response == null) {
      return _analyzeRoutineOnDevice(routine, profile);
    }

    try {
      final json = jsonDecode(response) as Map<String, dynamic>;
      final issuesList =
          (json['issues'] as List<dynamic>?)
              ?.map((e) => RoutineIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return RoutineAnalysis(
        issues: issuesList,
        suggestions:
            (json['suggestions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        isAiGenerated: true,
      );
    } catch (e) {
      debugPrint('Failed to parse AI response: $e');
      return _analyzeRoutineOnDevice(routine, profile);
    }
  }

  RoutineAnalysis _analyzeRoutineOnDevice(
    UserRoutine routine,
    UserProfile profile,
  ) {
    final issues = <RoutineIssue>[];
    final suggestions = <String>[];

    if (routine.wakeTime.isEmpty) {
      issues.add(
        const RoutineIssue(
          problem: 'Wake time not specified.',
          correction:
              'Set a consistent wake time that aligns with your schedule.',
          reason:
              'A consistent wake time helps regulate your body clock and makes it easier to plan workouts and meals.',
        ),
      );
    }

    if (routine.sleepTime.isEmpty) {
      issues.add(
        const RoutineIssue(
          problem: 'Sleep time not specified.',
          correction:
              'Aim for 7-9 hours of sleep by setting a consistent bedtime.',
          reason:
              'Adequate sleep is essential for muscle recovery and overall fitness progress.',
        ),
      );
    }

    if (routine.workoutTimePreference.isEmpty) {
      issues.add(
        const RoutineIssue(
          problem: 'Workout time not specified.',
          correction:
              'Choose a consistent workout time based on your energy levels and daily schedule.',
          reason: 'A consistent workout time helps build a sustainable habit.',
        ),
      );
    }

    if (routine.mealTimes.isEmpty) {
      issues.add(
        const RoutineIssue(
          problem: 'Meal times not specified.',
          correction:
              'Plan regular meal times throughout the day based on your routine.',
          reason:
              'Consistent meal timing helps maintain energy levels and supports workout performance.',
        ),
      );
    }

    if (routine.workSchedule.isEmpty && routine.freeTime.isEmpty) {
      issues.add(
        const RoutineIssue(
          problem: 'Work/school schedule and free time are not specified.',
          correction:
              'Add your work or school schedule and available free time.',
          reason:
              'Knowing your daily commitments helps create a realistic workout and meal plan.',
        ),
      );
    }

    if (profile.daysPerWeek.isEmpty) {
      issues.add(
        const RoutineIssue(
          problem: 'Workout frequency not set in profile.',
          correction:
              'Set how many days per week you can realistically workout.',
          reason:
              'This helps generate an appropriate workout plan that fits your schedule.',
        ),
      );
    }

    if (issues.isEmpty) {
      suggestions.add('Your routine looks well-structured!');
      suggestions.add('Continue maintaining consistency.');
    }

    return RoutineAnalysis(
      issues: issues,
      suggestions: suggestions,
      isAiGenerated: false,
    );
  }

  // -------------------------------------------------------------------
  // PLAN GENERATION
  // -------------------------------------------------------------------

  Future<DailyPlan> generateNextDayPlan(
    UserProfile profile,
    UserRoutine routine,
  ) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    if (hasCloud) {
      try {
        return await _generatePlanWithAI(profile, routine, tomorrow);
      } catch (e) {
        debugPrint('AI plan generation failed: $e');
      }
    }

    return _generatePlanOnDevice(profile, routine, tomorrow);
  }

  Future<DailyPlan> _generatePlanWithAI(
    UserProfile profile,
    UserRoutine routine,
    DateTime date,
  ) async {
    final previousPlan = await getPlanForDate(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    final prompt =
        '''
You are a fitness coach creating a personalized workout plan.

User Profile:
${profile.toContextSummary()}

User's Routine:
- Workout time preference: ${routine.workoutTimePreference.isEmpty ? 'Not specified' : routine.workoutTimePreference}
- Available time per session: ${profile.minutesPerSession} minutes
- Equipment: ${profile.equipment}
- Experience: ${profile.experience}
- Goal: ${profile.goal}
- Age group: ${profile.ageGroup.name}
- Health conditions: ${profile.healthConditionNames.isEmpty ? 'None' : profile.healthConditionNames.join(', ')}
- Workout location: ${profile.workoutLocation}

${previousPlan != null ? '''
Previous workout (${previousPlan.date.toString().substring(0, 10)}):
- Completed: ${previousPlan.completed ? 'Yes' : 'No'}
- Exercises: ${previousPlan.exercises.map((e) => e.name).join(', ')}
''' : 'No previous workout data available.'}

Generate a workout plan for ${date.toString().substring(0, 10)}.

Requirements:
- Match the user's experience level (${profile.experience})
- Use available equipment (${profile.equipment})
- Fit within ${profile.minutesPerSession} minutes
- Align with their goal: ${profile.goal}
- Include 5-8 exercises appropriate for their level
- Specify sets, reps, and rest periods
- Include warmup and cooldown suggestions
${profile.ageGroup.isMinor ? '- IMPORTANT: This is a minor. Focus on proper form, fun, and balanced activity. Never recommend calorie deficits or extreme intensity.' : ''}
${profile.ageGroup == AgeGroup.older ? '- IMPORTANT: This is an older adult. Use lower-impact exercises, longer rest periods (90s+), and avoid high-intensity movements like burpees.' : ''}
${profile.hasHighRiskCondition ? '- IMPORTANT: User has health conditions (${profile.healthConditionNames.join(', ')}). Be conservative with intensity, include a medical disclaimer, and avoid high-impact exercises.' : ''}

Respond in JSON format:
{
  "warmup": "5-10 minute warmup description",
  "cooldown": "5-10 minute cooldown description",
  "notes": "Any special instructions or encouragement",
  "exercises": [
    {
      "name": "Exercise name",
      "muscleGroup": "Target muscle",
      "sets": 3,
      "reps": 10,
      "restSeconds": 60,
      "instructions": "Brief form cue"
    }
  ]
}
''';

    final response = await _callGemini(prompt);
    if (response == null) {
      return _generatePlanOnDevice(profile, routine, date);
    }

    try {
      final json = jsonDecode(response) as Map<String, dynamic>;
      final exercises =
          (json['exercises'] as List<dynamic>?)
              ?.map((e) => PlannedExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final meals =
          (json['meals'] as List<dynamic>?)
              ?.map((m) => PlannedMeal.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [];

      return DailyPlan(
        date: date,
        exercises: exercises,
        meals: meals,
        warmup: json['warmup'] as String? ?? '5 minutes light cardio',
        cooldown: json['cooldown'] as String? ?? '5 minutes stretching',
        notes: json['notes'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('Failed to parse AI plan: $e');
      return _generatePlanOnDevice(profile, routine, date);
    }
  }

  DailyPlan _generatePlanOnDevice(
    UserProfile profile,
    UserRoutine routine,
    DateTime date,
  ) {
    final exercises = <PlannedExercise>[];
    final isIntermediate = profile.experience == 'Intermediate';
    final isAdvanced = profile.experience == 'Advanced';
    final ageGroup = profile.ageGroup;
    final hasHighRisk = profile.hasHighRiskCondition;

    final squatName = ageGroup == AgeGroup.older ? 'Chair Squats' : 'Bodyweight Squats';
    final squatSets = (ageGroup == AgeGroup.child || ageGroup == AgeGroup.older) ? 2 : 3;
    final squatRest = (ageGroup == AgeGroup.child || ageGroup == AgeGroup.older) ? 90 : 60;

    exercises.add(
      PlannedExercise(
        name: squatName,
        muscleGroup: 'Legs',
        sets: squatSets,
        reps: 12,
        restSeconds: squatRest,
        instructions: 'Keep chest up, knees tracking over toes',
      ),
    );

    exercises.add(
      const PlannedExercise(
        name: 'Push-ups',
        muscleGroup: 'Chest',
        sets: 3,
        reps: 10,
        restSeconds: 60,
        instructions: 'Keep body straight, lower chest to floor',
      ),
    );

    exercises.add(
      const PlannedExercise(
        name: 'Bent-over Rows',
        muscleGroup: 'Back',
        sets: 3,
        reps: 12,
        restSeconds: 60,
        instructions: 'Keep back flat, pull elbows to ceiling',
      ),
    );

    exercises.add(
      const PlannedExercise(
        name: 'Plank',
        muscleGroup: 'Core',
        sets: 3,
        reps: 30,
        restSeconds: 45,
        instructions: 'Hold for 30 seconds, keep body straight',
      ),
    );

    if (isIntermediate || isAdvanced) {
      exercises.add(
        const PlannedExercise(
          name: 'Lunges',
          muscleGroup: 'Legs',
          sets: 3,
          reps: 10,
          restSeconds: 60,
          instructions: 'Step forward, lower back knee toward floor',
        ),
      );
    }

    if (isAdvanced && !hasHighRisk && ageGroup != AgeGroup.older) {
      exercises.add(
        const PlannedExercise(
          name: 'Burpees',
          muscleGroup: 'Full Body',
          sets: 3,
          reps: 8,
          restSeconds: 90,
          instructions: 'Explosive movement, maintain form',
        ),
      );
    }

    if (ageGroup == AgeGroup.older && hasHighRisk) {
      exercises.add(
        const PlannedExercise(
          name: 'Step-ups',
          muscleGroup: 'Legs',
          sets: 2,
          reps: 8,
          restSeconds: 90,
          instructions: 'Use a low step, hold railing for balance',
        ),
      );
    }

    if (ageGroup == AgeGroup.child && isAdvanced) {
      exercises.add(
        const PlannedExercise(
          name: 'Fun Runs',
          muscleGroup: 'Full Body',
          sets: 2,
          reps: 1,
          restSeconds: 90,
          instructions: 'Run in place for 1 minute, keep it fun!',
        ),
      );
    }

    final meals = _generateMealSuggestions(profile);

    return DailyPlan(
      date: date,
      exercises: exercises,
      meals: meals,
      warmup: '5 minutes light cardio (jogging in place, jumping jacks)',
      cooldown: '5 minutes stretching (focus on worked muscles)',
      notes: _getMotivationalNote(profile),
    );
  }

  List<PlannedMeal> _generateMealSuggestions(UserProfile profile) {
    final meals = <PlannedMeal>[];

    // Generate meals based on user's dietary preference and goals
    final isVegetarian =
        profile.dietaryPreference.toLowerCase().contains('vegetarian') ||
        profile.dietaryPreference.toLowerCase().contains('vegan');

    // Breakfast suggestion
    meals.add(
      PlannedMeal(
        mealType: 'Breakfast',
        foodName: isVegetarian
            ? 'Oatmeal with fruits'
            : 'Scrambled eggs with toast',
        serving: '1 bowl',
        calories: isVegetarian ? 350 : 400,
        protein: isVegetarian ? 12.0 : 20.0,
        carbs: isVegetarian ? 55.0 : 35.0,
        fat: isVegetarian ? 8.0 : 18.0,
      ),
    );

    // Lunch suggestion
    meals.add(
      PlannedMeal(
        mealType: 'Lunch',
        foodName: isVegetarian
            ? 'Daal with rice and vegetables'
            : 'Grilled chicken with rice',
        serving: '1 plate',
        calories: isVegetarian ? 500 : 550,
        protein: isVegetarian ? 18.0 : 35.0,
        carbs: isVegetarian ? 70.0 : 45.0,
        fat: isVegetarian ? 12.0 : 15.0,
      ),
    );

    // Snack suggestion
    meals.add(
      PlannedMeal(
        mealType: 'Snack',
        foodName: isVegetarian ? 'Greek yogurt with nuts' : 'Protein shake',
        serving: '1 serving',
        calories: isVegetarian ? 250 : 200,
        protein: isVegetarian ? 15.0 : 25.0,
        carbs: isVegetarian ? 20.0 : 10.0,
        fat: isVegetarian ? 12.0 : 5.0,
      ),
    );

    // Dinner suggestion
    meals.add(
      PlannedMeal(
        mealType: 'Dinner',
        foodName: isVegetarian
            ? 'Roti with vegetable curry'
            : 'Fish with vegetables',
        serving: '1 plate',
        calories: isVegetarian ? 450 : 480,
        protein: isVegetarian ? 16.0 : 30.0,
        carbs: isVegetarian ? 60.0 : 25.0,
        fat: isVegetarian ? 14.0 : 18.0,
      ),
    );

    return meals;
  }

  String _getMotivationalNote(UserProfile profile) {
    final goal = profile.goal;
    final ageGroup = profile.ageGroup;

    if (ageGroup == AgeGroup.child) {
      return 'Focus on fun and movement — great job being active today!';
    }
    if (ageGroup == AgeGroup.teen) {
      return 'Focus on proper form and consistency — you are building habits for life!';
    }
    if (ageGroup == AgeGroup.older) {
      return 'Move at your own pace and listen to your body. Consistency matters more than intensity!';
    }
    if (profile.hasHighRiskCondition) {
      return 'Please consult your doctor before starting any new exercise program. Start slow and listen to your body.';
    }
    if (goal.toLowerCase().contains('strength')) {
      return 'Focus on progressive overload - try to increase weight or reps each week!';
    } else if (goal.toLowerCase().contains('loss') ||
        goal.toLowerCase().contains('fat')) {
      return 'Keep your heart rate up and minimize rest between sets!';
    } else if (goal.toLowerCase().contains('muscle') ||
        goal.toLowerCase().contains('gain')) {
      return 'Focus on mind-muscle connection and controlled movements!';
    }
    return 'Stay consistent and listen to your body!';
  }

  // -------------------------------------------------------------------
  // GEMINI API
  // -------------------------------------------------------------------

  Future<String?> _callGemini(String prompt) async {
    if (_apiKey == null) return null;

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey',
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = json['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String?;
          }
        }
      } else {
        debugPrint('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Gemini API call failed: $e');
    }

    return null;
  }
}
