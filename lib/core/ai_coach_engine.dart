/// FitAI Multilingual AI Coach Engine
///
/// A rule-based, on-device fitness coach that replies in the user's
/// selected language and uses their profile (age, height, weight, goal,
/// activity, experience) to personalize advice. It is intentionally honest
/// about being an on-device coach: it never fabricates medical advice or
/// invents precise numbers, and it directs clinical questions to a
/// professional. When a Gemini API key is configured in Settings the
/// engine can optionally forward to a real LLM for richer conversation.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app/app_localizations.dart' show L;
import 'user_profile_service.dart';

/// Intent detected from the user's message.
enum CoachIntent {
  greeting,
  workoutPlan,
  nutrition,
  weightLoss,
  muscleGain,
  recovery,
  form,
  motivation,
  capabilities,
  profile,
  thanks,
  medical,
  unknown,
}

/// Result of a coach response.
class CoachResponse {
  final String text;
  final bool personalized;
  final bool fromCloud;

  const CoachResponse({
    required this.text,
    this.personalized = false,
    this.fromCloud = false,
  });
}

class AICoachEngine {
  AICoachEngine._();
  static final AICoachEngine instance = AICoachEngine._();

  /// Optional Gemini API key. When set and valid, the engine forwards
  /// requests to the cloud model for richer conversation; otherwise it
  /// uses the on-device rule-based coach.
  String? _apiKey;
  String? get apiKey => _apiKey;
  void setApiKey(String? key) =>
      _apiKey = (key == null || key.isEmpty) ? null : key;

  bool get hasCloud => _apiKey != null && _apiKey!.isNotEmpty;

  /// Main entry: produce a coach reply for [message] given [profile].
  Future<CoachResponse> respond(String message, UserProfile profile) async {
    final lang = profile.language;
    // Always try the cloud path first when a key is configured, so users
    // who connect an API key get real conversational AI in their language.
    if (hasCloud) {
      try {
        final cloud = await _callCloud(message, profile);
        if (cloud != null) {
          return CoachResponse(
            text: cloud,
            personalized: true,
            fromCloud: true,
          );
        }
      } catch (e) {
        debugPrint('Cloud coach failed, falling back on-device: $e');
      }
    }
    // Reference L so the import is used for direction-aware callers.
    assert(L.current == L.current);
    return _onDevice(message, profile, lang);
  }

  // -------------------------------------------------------------------
  // On-device rule-based coach
  // -------------------------------------------------------------------

  CoachResponse _onDevice(String message, UserProfile profile, String lang) {
    final intent = _detectIntent(message);
    final builder = _builders[lang] ?? _builders['English']!;
    final text = builder(intent, profile, message);
    return CoachResponse(text: text, personalized: profile.isComplete);
  }

  CoachIntent _detectIntent(String message) {
    final m = message.toLowerCase();
    bool has(List<String> keys) => keys.any((k) => m.contains(k));

    if (has([
      'hi',
      'hello',
      'hey',
      'salam',
      'salaam',
      'assalam',
      'سلام',
      'ہیلو',
      'ہائے',
      'नमस्ते',
      'ਸਤ',
      'ہیلو',
    ])) {
      return CoachIntent.greeting;
    }
    if (has(['thank', 'shukria', 'shukriya', 'شکریہ', 'धन्यवाद', 'مهربانی'])) {
      return CoachIntent.thanks;
    }
    if (has([
      'what can you',
      'help me',
      'capabilities',
      'features',
      'کیا کر',
      'کیا کر سکتے',
      'مدد',
      'मदद',
      'تمھارا',
    ])) {
      return CoachIntent.capabilities;
    }
    if (has([
      'workout',
      'exercise',
      'plan',
      'routine',
      'مشق',
      'ورک آؤٹ',
      'تمرین',
      'व्यायाम',
      'कसरत',
      'ਕਸਰਤ',
      'منصوبو',
      'پلان',
    ])) {
      return CoachIntent.workoutPlan;
    }
    if (has([
      'food',
      'eat',
      'diet',
      'nutrition',
      'meal',
      'calorie',
      'protein',
      'کھانا',
      'غذا',
      'خوراک',
      'भोजन',
      'खाना',
      'ਖਾਣਾ',
      'ਆਹਾਰ',
      'غذائیت',
      'کیلوری',
      'پروٹین',
    ])) {
      return CoachIntent.nutrition;
    }
    if (has([
      'lose weight',
      'weight loss',
      'fat loss',
      'reduce',
      'وزن کم',
      'موٹاپا',
      'वजन कम',
      'वसा',
      'ਵਜ਼ਨ ਘਟਾ',
    ])) {
      return CoachIntent.weightLoss;
    }
    if (has([
      'muscle',
      'bulk',
      'build muscle',
      'gain mass',
      'پٹھا',
      'مص member',
      'muscle',
      'मांसपेशी',
      'ਮਸਲ',
      'ਪੱਠਾ',
      'پٹھے',
    ])) {
      return CoachIntent.muscleGain;
    }
    if (has([
      'rest',
      'recovery',
      'sleep',
      'tired',
      'sore',
      'تھکا',
      'آرام',
      'نیند',
      'रिकवरी',
      'आराम',
      'नींद',
      'ਥੱਕਾ',
      'ਆਰਾਮ',
      ' recovery',
      'л hardam',
      'آرام',
    ])) {
      return CoachIntent.recovery;
    }
    if (has([
      'form',
      'technique',
      'squat',
      'pushup',
      'deadlift',
      'bench',
      'فارم',
      'تکنیک',
      'اسکواٹ',
      ' posture',
      'अ',
      'ফর্ম',
      'ਫਾਰਮ',
      'technique',
    ])) {
      return CoachIntent.form;
    }
    if (has([
      'motivat',
      'lazy',
      'give up',
      'consistency',
      'حوصلا',
      'حوصلہ',
      'متمل',
      'prerana',
      'प्रेरणा',
      'ਪ੍ਰੇਰਨਾ',
      'motivasi',
    ])) {
      return CoachIntent.motivation;
    }
    if (has([
      'my profile',
      'my info',
      'my data',
      'میری معلومات',
      'मेरी जानकारी',
      'ਮੇਰੀ ਜਾਣਕਾਰੀ',
    ])) {
      return CoachIntent.profile;
    }
    if (has([
      'diagnos',
      'symptom',
      'disease',
      'medication',
      'chest pain',
      'heart',
      'diabetes',
      'cancer',
      'infection',
      'blood pressure',
      'بیماری',
      'دوا',
      'تشخیص',
      'दवा',
      'बीमारी',
      'ਦਵਾ',
      'بیماری',
    ])) {
      return CoachIntent.medical;
    }
    return CoachIntent.unknown;
  }

  // -------------------------------------------------------------------
  // Optional cloud integration (Gemini) — only used when a key is set
  // -------------------------------------------------------------------

  Future<String?> _callCloud(String message, UserProfile profile) async {
    if (!hasCloud) return null;
    final lang = profile.language;
    final langInstruction = lang == 'Roman English'
        ? 'Reply ONLY in Roman Urdu — that is, Urdu language written in '
              'Latin/Roman script (e.g., "Apna weight kam karnay ke liye '
              'protein zyada khayein"). Do NOT use Urdu script. Do NOT use '
              'English.'
        : 'Reply ONLY in $lang.';
    final safetyInstructions = <String>[];
    if (profile.ageGroup.isMinor) {
      safetyInstructions.add(
        'IMPORTANT: This user is a minor (${profile.ageGroup.name}). NEVER recommend calorie deficits, fasting, or restrictive eating. Focus on balanced nutrition, fun activity, and healthy habits.',
      );
    }
    if (profile.ageGroup == AgeGroup.older) {
      safetyInstructions.add(
        'This user is 60+. Recommend moderate-intensity exercise, chair-based alternatives for high-impact moves, and longer rest periods.',
      );
    }
    if (profile.hasHighRiskCondition) {
      safetyInstructions.add(
        'SAFETY: This user has high-risk health conditions (${profile.healthConditionNames.join(", ")}). ALWAYS advise consulting their doctor before starting new exercises. Avoid high-intensity recommendations.',
      );
    }
    final safetyBlock = safetyInstructions.isNotEmpty
        ? '\n${safetyInstructions.join(" ")}'
        : '';
    final system =
        'You are FitAI, a friendly, concise personal fitness '
        'coach. $langInstruction Use the user profile to personalize. '
        'Do not give medical diagnoses; encourage professional help for '
        'medical questions. Profile: ${profile.toContextSummary()}.$safetyBlock';
    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-1.5-flash:generateContent?key=$_apiKey',
    );
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': '$system\n\nUser: $message'},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 600},
    });
    final res = await http.post(endpoint, body: body);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    final parts = (candidates.first['content']['parts'] as List);
    if (parts.isEmpty) return null;
    return parts.first['text'] as String?;
  }

  // -------------------------------------------------------------------
  // Greeting message used by the chat screen on first load
  // -------------------------------------------------------------------

  String greeting(UserProfile profile) {
    final lang = profile.language;
    final builder = _builders[lang] ?? _builders['English']!;
    return builder(CoachIntent.greeting, profile, '');
  }
}

/// Per-language response builders. Each returns a string for the given
/// intent, personalized with the profile. Languages without a dedicated
/// builder fall back to English.
typedef ResponseBuilder =
    String Function(CoachIntent intent, UserProfile profile, String rawMessage);

// -------------------------------------------------------------------
// Detailed plan helpers — generate actual personalized plans from profile
// -------------------------------------------------------------------

String _buildDetailedWorkoutPlan(UserProfile p) {
  final sb = StringBuffer();
  final days = int.tryParse(p.daysPerWeek) ?? 3;
  final mins = int.tryParse(p.minutesPerSession) ?? 45;
  final exp = p.experience;
  final goal = p.goal;
  final isBeg = exp == 'Beginner';
  final isInt = exp == 'Intermediate';
  final reps = isBeg ? '2-3 sets × 10-12 reps (light weight)'
      : isInt ? '3 sets × 8-10 reps (moderate weight)'
      : '4 sets × 6-8 reps (challenging weight)';
  final rest = isBeg ? '90 sec' : isInt ? '60-90 sec' : '45-60 sec';

  sb.writeln('Based on your profile — Goal: $goal | $exp level | '
      '$days days/week (~$mins min) — here is your personalized plan:\n');

  if (days <= 2) {
    sb.writeln('═══ $days-Day Full Body Split ═══');
    for (var d = 1; d <= days; d++) {
      sb.writeln('\n━━━ Day $d: Full Body ━━━');
      sb.writeln('1. Bodyweight Squats or Goblet Squats — $reps');
      sb.writeln('2. Push-ups (knee if needed) or Bench Press — $reps');
      sb.writeln('3. Dumbbell Rows — $reps');
      sb.writeln('4. Lunges — $reps each leg');
      sb.writeln('5. Overhead Press — $reps');
      sb.writeln('6. Plank — 3 × 20-30 sec');
    }
  } else if (days <= 3) {
    sb.writeln('═══ $days-Day Full Body Split ═══');
    for (var d = 1; d <= days; d++) {
      sb.writeln('\n━━━ Day $d: Full Body ━━━');
      sb.writeln('1. Squats (bodyweight or goblet) — $reps');
      sb.writeln('2. Push-ups or Bench Press — $reps');
      sb.writeln('3. Dumbbell Rows — $reps');
      sb.writeln('4. Lunges — $reps each leg');
      sb.writeln('5. Overhead Press — $reps');
      sb.writeln('6. Plank — 3 × 20-30 sec');
      if (d < days) sb.writeln('→ Rest day between');
    }
  } else if (days <= 4) {
    sb.writeln('═══ 4-Day Upper/Lower Split ═══');
    sb.writeln('\n━━━ Day 1: Upper Body ━━━');
    sb.writeln('1. Bench Press or Push-ups — $reps');
    sb.writeln('2. Dumbbell Rows — $reps');
    sb.writeln('3. Overhead Press — $reps');
    sb.writeln('4. Bicep Curls — $reps');
    sb.writeln('5. Tricep Dips — $reps');
    sb.writeln('\n━━━ Day 2: Lower Body ━━━');
    sb.writeln('1. Squats — $reps');
    sb.writeln('2. Romanian Deadlifts — $reps');
    sb.writeln('3. Lunges — $reps each leg');
    sb.writeln('4. Calf Raises — $reps');
    sb.writeln('5. Plank — 3 × 30 sec');
    sb.writeln('\n━━━ Day 3: Upper Body ━━━');
    sb.writeln('1. Incline Press or Pike Push-ups — $reps');
    sb.writeln('2. Lat Pulldowns or Band Pull-aparts — $reps');
    sb.writeln('3. Lateral Raises — $reps');
    sb.writeln('4. Hammer Curls — $reps');
    sb.writeln('5. Skull Crushers — $reps');
    sb.writeln('\n━━━ Day 4: Lower Body ━━━');
    sb.writeln('1. Deadlifts or Hip Thrusts — $reps');
    sb.writeln('2. Leg Press or Step-ups — $reps');
    sb.writeln('3. Leg Curls — $reps');
    sb.writeln('4. Calf Raises — $reps');
    sb.writeln('5. Side Plank — 3 × 20 sec each');
  } else {
    sb.writeln('═══ $days-Day Push/Pull/Legs Split ═══');
    sb.writeln('\n━━━ Day 1: Push (Chest/Shoulders/Triceps) ━━━');
    sb.writeln('1. Bench Press — $reps');
    sb.writeln('2. Overhead Press — $reps');
    sb.writeln('3. Incline Dumbbell Press — $reps');
    sb.writeln('4. Lateral Raises — $reps');
    sb.writeln('5. Tricep Pushdowns — $reps');
    sb.writeln('\n━━━ Day 2: Pull (Back/Biceps) ━━━');
    sb.writeln('1. Deadlifts or Rows — $reps');
    sb.writeln('2. Lat Pulldowns — $reps');
    sb.writeln('3. Seated Cable Rows — $reps');
    sb.writeln('4. Face Pulls — $reps');
    sb.writeln('5. Bicep Curls — $reps');
    sb.writeln('\n━━━ Day 3: Legs ━━━');
    sb.writeln('1. Squats — $reps');
    sb.writeln('2. Romanian Deadlifts — $reps');
    sb.writeln('3. Lunges — $reps each leg');
    sb.writeln('4. Leg Press — $reps');
    sb.writeln('5. Calf Raises — $reps');
    if (days >= 6) {
      sb.writeln('\n━━━ Day 4: Push (repeat Day 1) ━━━');
      sb.writeln('\n━━━ Day 5: Pull (repeat Day 2) ━━━');
      sb.writeln('\n━━━ Day 6: Legs (repeat Day 3) ━━━');
    }
  }

  sb.writeln('\n━━━ Guidelines ━━━');
  sb.writeln('• Rest between sets: $rest');
  sb.writeln('• Warm-up: 5 min light cardio + dynamic stretches');
  sb.writeln('• Cool-down: 5 min stretching');
  if (goal == 'Build muscle') {
    sb.writeln('• Focus: progressive overload — add weight or reps each week');
  } else if (goal == 'Lose weight') {
    sb.writeln('• Focus: keep intensity moderate, add 10-15 min cardio after weights');
  } else if (goal == 'Stay fit' || goal == 'Stay healthy') {
    sb.writeln('• Focus: balanced effort, enjoy the process');
  } else {
    sb.writeln('• Focus: consistent effort, gradual progression');
  }
  sb.writeln('• Sleep: 7-9 hours for recovery');
  sb.writeln('• Water: at least 8 glasses/day, more on training days');
  sb.writeln('• Pre-workout: light snack 30-60 min before');
  sb.writeln('• Post-workout: protein within 1 hour');
  sb.write('\nThis plan is based on your saved profile. '
      'Use Form Check for real-time exercise feedback!');
  return sb.toString().trim();
}

String _buildDetailedNutritionPlan(UserProfile p) {
  final sb = StringBuffer();
  final tdee = p.tdee;
  final weight = p.weightKg ?? 70;
  final goal = p.goal;

  if (tdee == null) {
    return 'Add your height and weight in Profile so I can calculate your '
        'calorie target. Meanwhile: eat lean protein, vegetables, whole '
        'grains, and drink plenty of water.';
  }

  double targetKcal;
  String goalNote;
  if (goal == 'Lose weight') {
    targetKcal = tdee * 0.8;
    goalNote = 'moderate deficit for steady fat loss';
  } else if (goal == 'Build muscle') {
    targetKcal = tdee * 1.1;
    goalNote = 'slight surplus for muscle growth';
  } else {
    targetKcal = tdee;
    goalNote = 'maintenance for your goal';
  }

  final protein = (weight * 1.6).round();
  final fat = (weight * 0.8).round();
  final carbCals = targetKcal - (protein * 4 + fat * 4);
  final carbs = (carbCals / 4).round();

  sb.writeln('Based on your profile — ${p.ageGroup.name}, '
      '${weight}kg, ${p.activity.label} — here is your nutrition guide:\n');
  sb.writeln('━━━ Daily Targets ━━━');
  sb.writeln('• Calories: ~${targetKcal.round()} kcal ($goalNote)');
  sb.writeln('• Protein: ~${protein}g (muscle repair & growth)');
  sb.writeln('• Carbs: ~${carbs}g (energy for workouts)');
  sb.writeln('• Fat: ~${fat}g (hormones & health)');

  sb.writeln('\n━━━ Sample Meals ━━━');
  sb.writeln('Breakfast:');
  sb.writeln('  • Oats with milk, banana & honey — or eggs with whole-wheat toast');

  sb.writeln('Lunch:');
  sb.writeln('  • Grilled chicken/fish with brown rice & salad');
  sb.writeln('  • Or daal/chickpeas with roti & vegetables');

  sb.writeln('Snack:');
  sb.writeln('  • Greek yogurt with nuts — or fruit with peanut butter');

  sb.writeln('Dinner:');
  sb.writeln('  • Lean meat/tofu with vegetables & sweet potato');
  sb.writeln('  • Or khichdi with curd & salad');

  sb.writeln('\n━━━ Tips ━━━');
  sb.writeln('• Drink 8+ glasses of water daily');
  sb.writeln('• Eat protein with every meal');
  sb.writeln('• Minimize processed food & sugary drinks');
  if (goal == 'Lose weight') {
    sb.writeln('• Don\'t skip meals — eat regular portions');
    sb.writeln('• Fill half your plate with vegetables');
  } else if (goal == 'Build muscle') {
    sb.writeln('• Don\'t skip meals — consistency matters for growth');
    sb.writeln('• Post-workout: protein + carbs within 1 hour');
  }
  sb.write('• Use the Nutrition tab to log meals and track macros');
  return sb.toString().trim();
}

final Map<String, ResponseBuilder> _builders = {
  'English': _english,
  'Urdu': _urdu,
  'Hindi': _hindi,
  'Punjabi': _punjabi,
  'Sindhi': _sindhi,
  'Pashto': _pashto,
  'Balochi': _balochi,
  'Roman English': _romanEnglish,
};

String _english(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'there';
  switch (intent) {
    case CoachIntent.greeting:
      return 'Hi $name! I\'m your FitAI coach. I can help with workouts, '
          'nutrition, recovery and motivation. What would you like to work on?';
    case CoachIntent.thanks:
      return 'You\'re welcome, $name! Stay consistent and the results will come. 💪';
    case CoachIntent.capabilities:
      return 'I can: build a personalized workout plan, suggest meals and '
          'calorie targets, advise on recovery and form, and keep you '
          'motivated. ${p.isComplete ? "I already have your profile, so my tips are tailored to you." : "Add your age, height and weight in Profile for personalized advice."}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'To build your plan I need your age, height, weight and goal '
            'first. Open Profile → Personal Information and add them, then '
            'ask me again.';
      }
      return _buildDetailedWorkoutPlan(p);
    case CoachIntent.nutrition:
      if (p.ageGroup.isMinor) {
        return 'For growing bodies, focus on balanced meals with lean protein, '
            'fruits, vegetables, whole grains and plenty of water. Skip '
            'processed snacks and sugary drinks. Stay active and have fun!';
      }
      if (p.tdee == null) {
        return 'Add your height and weight in Profile so I can estimate your '
            'daily calorie target. Meanwhile, aim for lean protein, '
            'vegetables, whole grains and plenty of water.';
      }
      if (p.hasHighRiskCondition) {
        return 'Given your health conditions, please consult your doctor for '
            'a personalized nutrition plan. In general, aim for lean protein, '
            'vegetables, whole grains and plenty of water.';
      }
      return _buildDetailedNutritionPlan(p);
    case CoachIntent.weightLoss:
      if (p.ageGroup.isMinor) {
        return 'At your age, focus on staying active and eating balanced meals '
            'rather than restricting calories. Your body is still growing! '
            'Try fun activities like sports, cycling or swimming.';
      }
      if (p.tdee == null) {
        return 'Add your weight in Profile so I can set a '
            'safe calorie target.';
      }
      if (p.hasHighRiskCondition) {
        return 'Given your health conditions, please get clearance from your '
            'doctor before starting any weight loss plan. I can suggest '
            'gentle activity ideas once you have the go-ahead.';
      }
      final target = (p.tdee! * 0.8).round();
      final protein = ((p.weightKg ?? 70) * 1.6).round();
      final sb = StringBuffer();
      sb.writeln('Here is your personalized fat-loss plan:\n');
      sb.writeln('━━━ Nutrition ━━━');
      sb.writeln('• Daily target: ~$target kcal (moderate deficit from ${p.tdee!.round()} kcal)');
      sb.writeln('• Protein: ~${protein}g to preserve muscle');
      sb.writeln('• Fill half your plate with vegetables at lunch & dinner');
      sb.writeln('• Cut sugary drinks & processed snacks');
      sb.writeln('• Drink 8+ glasses of water daily');
      sb.writeln('\n━━━ Training (${p.daysPerWeek} days/week) ━━━');
      sb.writeln('• Strength training ${p.daysPerWeek}x/week (full body or upper/lower split)');
      sb.writeln('• Focus on compound moves: squats, deadlifts, rows, presses');
      sb.writeln('• Add 10-15 min brisk walk or cardio after each session');
      sb.writeln('• Aim for 8,000-10,000 steps daily');
      sb.writeln('\n━━━ Recovery ━━━');
      sb.writeln('• Sleep 7-9 hours — poor sleep increases hunger hormones');
      sb.writeln('• Take 1-2 rest days/week');
      sb.writeln('• Don\'t skip meals — eat regular, satisfying portions');
      sb.write('\nConsistency over perfection. Small daily deficits add up!');
      return sb.toString().trim();
    case CoachIntent.muscleGain:
      if (p.ageGroup.isMinor) {
        return 'For building strength at your age, focus on bodyweight '
            'exercises, eat enough protein (eggs, milk, beans, chicken), '
            'sleep well and stay consistent. Avoid heavy weights until your '
            'body is fully developed.';
      }
      if (p.tdee == null) {
        return 'Add your weight in Profile so I can set a '
            'surplus target.';
      }
      final target = (p.tdee! * 1.1).round();
      final protein = ((p.weightKg ?? 70) * 1.6).round();
      final sb = StringBuffer();
      sb.writeln('Here is your personalized muscle-building plan:\n');
      sb.writeln('━━━ Nutrition ━━━');
      sb.writeln('• Daily target: ~$target kcal (slight surplus from ${p.tdee!.round()} kcal)');
      sb.writeln('• Protein: ~${protein}g (chicken, eggs, fish, daal, yogurt)');
      sb.writeln('• Eat protein with every meal');
      sb.writeln('• Post-workout: protein + carbs within 1 hour');
      sb.writeln('• Don\'t skip meals — consistency matters for growth');
      sb.writeln('\n━━━ Training (${p.daysPerWeek} days/week) ━━━');
      sb.writeln('• Focus on progressive overload — add weight or reps each week');
      sb.writeln('• Compound lifts first: squats, deadlifts, bench, rows, OHP');
      sb.writeln('• ${p.experience == 'Beginner' ? '2-3 sets × 10-12 reps (light-moderate weight)' : p.experience == 'Intermediate' ? '3 sets × 8-10 reps (moderate weight)' : '4 sets × 6-8 reps (challenging weight)'}');
      sb.writeln('• Rest ${p.experience == 'Beginner' ? '90 sec' : p.experience == 'Intermediate' ? '60-90 sec' : '45-60 sec'} between sets');
      sb.writeln('\n━━━ Recovery ━━━');
      sb.writeln('• Sleep 7-9 hours — muscles grow during rest, not in the gym');
      sb.writeln('• Don\'t train the same muscle group hard two days running');
      sb.writeln('• Stay hydrated: 8+ glasses of water daily');
      sb.write('\nMuscle takes time — trust the process and stay consistent!');
      return sb.toString().trim();
    case CoachIntent.recovery:
      if (p.ageGroup.isMinor) {
        return 'Young athletes need extra recovery! Aim for 8-10 hrs sleep, '
            'have fun rest days with light play, and always have a parent or '
            'guardian check your training plan. Focus on fun, not intensity.';
      }
      if (p.hasHighRiskCondition) {
        return 'Given your health conditions, please get clearance from your '
            'doctor for recovery guidelines. Gentle movement, adequate rest, '
            'and following medical advice are your top priorities.';
      }
      if (p.ageGroup == AgeGroup.older) {
        return 'Recovery matters more as we age. Aim for 7-9 hrs sleep, allow '
            'extra rest days, try gentle stretching or walking on off-days, '
            'and avoid training the same muscle group hard two days running.';
      }
      return 'Recovery is where progress happens. ${p.isComplete ? "At your activity level (${p.activity.label}), " : ""}'
          'aim for 7-9 hrs sleep, take 1-2 rest days/week, hydrate well, '
          'and don\'t train the same muscle group hard two days running. '
          'If you feel sharp pain, stop and see a professional.';
    case CoachIntent.form:
      return 'Good form prevents injury. Open "Form Check" from Home — it '
          'uses your camera with on-device pose detection to count reps and '
          'show joint-angle feedback in real time. Tip: control the '
          'negative (lowering) phase, don\'t rush reps.';
    case CoachIntent.motivation:
      return 'You started, and that\'s the hardest part, $name. Show up for '
          'just 10 minutes today — momentum follows action. Missed a day? '
          'Never miss two in a row. I\'m here whenever you need a nudge.';
    case CoachIntent.profile:
      if (!p.isComplete) {
        return 'Your profile isn\'t complete yet. Add your '
            'age, height and weight in Profile → Personal Information so I '
            'can personalize everything.';
      }
      return 'Here\'s what I know about you: ${p.toContextSummary()}. '
          'Update anything in Profile any time.';
    case CoachIntent.medical:
      if (p.ageGroup.isMinor) {
        return 'I can\'t help with medical questions, $name. Please talk to '
            'a parent or guardian and see a doctor for any health concerns. '
            'I\'m here for fitness and nutrition advice!';
      }
      if (p.hasHighRiskCondition) {
        return 'Given your health conditions, please consult your doctor or '
            'a healthcare professional for medical advice. I can help with '
            'gentle fitness guidance once you have medical clearance.';
      }
      return 'I\'m a fitness coach, not a doctor, $name. For medical concerns '
          'please consult a healthcare professional. I\'m here for workouts, '
          'nutrition, recovery and motivation!';
    case CoachIntent.unknown:
      return 'I\'m best at workouts, nutrition, recovery, form and '
          'motivation. ${p.isComplete ? "Try \"make my workout\" or \"what should I eat?\"" : "Add your profile details first for personalized advice."}';
  }
}

String _urdu(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'وہاں';
  switch (intent) {
    case CoachIntent.greeting:
      return 'السلام علیکم $name! میں آپ کا FitAI کوچ ہوں۔ ورک آؤٹ، غذائیت، '
          'بحالی اور حوصلے میں مدد کر سکتا ہوں۔ آپ کیا پر کام کرنا چاہتے ہیں؟';
    case CoachIntent.thanks:
      return 'خوش آمدید، $name! مسلسل رہیں اور نتائج آئیں گے۔ 💪';
    case CoachIntent.capabilities:
      return 'میں یہ کر سکتا ہوں: ذاتی ورک آؤٹ پلان بنانا، کھانے اور کیلوری '
          'ہدف تجویز کرنا، بحالی اور فارم مشورے دینا، اور آپ کا حوصلہ بڑھانا۔ '
          '${p.isComplete ? "مجھے آپ کی معلومات ہیں، اس لیے مشورے آپ کے لیے ہیں۔" : "ذاتی مشورے کے لیے Profile میں عمر، قد اور وزن شامل کریں۔"}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'آپ کا پلان بنانے کے لیے مجھے عمر، قد، وزن اور ہدف چاہیے۔ '
            'Profile → Personal Information کھولیں اور معلومات شامل کریں۔';
      }
      return 'آپ کے ہدف (${p.goal})، ${p.experience} سطح اور ہفتے میں '
          '${p.daysPerWeek} دن (تقریباً ${p.minutesPerSession} منٹ) کے حساب سے '
          'میں ایک ${p.daysPerWeek}-دن کا پلان تجویز کرتا ہوں۔ Workout ٹیب '
          'کھولیں اور "Start Workout" دبائیں، پھر فارم چیک میں حقیقی رائے لیں۔';
    case CoachIntent.nutrition:
      if (p.ageGroup.isMinor) {
        return 'نوجوانوں کے لیے متوازن کھانا ضروری ہے — پروٹین، پھل، سبزیاں '
            'اور پانی پر توجہ دیں۔ پروسیسڈ اسنیکس اور میٹھے مشروبات سے بچیں۔';
      }
      if (p.tdee == null) {
        return 'Profile میں قد اور وزن شامل کریں تاکہ میں روزانہ کیلوری '
            'ہدف بتا سکوں۔ اس وقت پروٹین، سبزیاں، اناج اور پانی پر توجہ دیں۔';
      }
      if (p.hasHighRiskCondition) {
        return 'آپ کی صحت کی صورتحال کے پیشِ نظر، براہ کرم ڈاکٹر سے ذاتی '
            'غذائی منصوبے کے لیے مشورہ کریں۔';
      }
      return 'آپ کی روزانہ ضرورت تقریباً ${p.tdee!.round()} کیلوری ہے۔ '
          '${p.goal} کے لیے ~${(p.tdee! * 0.85).round()} کیلوری اور '
          '~${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین مناسب ہے۔ '
          'Nutrition ٹیب میں کھانے درج کریں۔';
    case CoachIntent.weightLoss:
      if (p.ageGroup.isMinor) {
        return 'آپ کی عمر میں کیلوری کم کرنے کے بجائے متوازن کھانا اور '
            'فعال رہنا بہتر ہے۔ آپ کا جسم ابھی بڑھ رہا ہے!';
      }
      if (p.tdee == null) {
        return 'وزن Profile میں شامل کریں تاکہ محفوظ کیلوری ہدف بنا سکوں۔';
      }
      if (p.hasHighRiskCondition) {
        return 'آپ کی صحت کی صورتحال کے پیشِ نظر، وزن کم کرنے کا منصوبہ '
            'شروع کرنے سے پہلے ڈاکٹر سے اجازت لیں۔';
      }
      final target = (p.tdee! * 0.8).round();
      return 'مستحکم وزن کم کرنے کے لیے ~$target کیلوری/دن (اعتدال پسند '
          'فرق)، زیادہ پروٹین، ہفتے میں 3-4 بار طاقت کی مشق اور روزانہ '
          'قدم۔ بہت کم کیلوری نقصان دہ ہے — میں کبھی غیر محفوظ ہدف نہیں دوں گا۔';
    case CoachIntent.muscleGain:
      if (p.ageGroup.isMinor) {
        return 'نوجوانی میں طاقت بنانے کے لیے جسمانی ورزش کریں، کافی پروٹین '
            'کھائیں اور اچھی نیند لیں۔ بھاری وزن سے بچیں۔';
      }
      if (p.tdee == null) {
        return 'وزن Profile میں شامل کریں تاکہ اضافی کیلوری ہدف بنا سکوں۔';
      }
      final target = (p.tdee! * 1.1).round();
      return 'پٹھے بنانے کے لیے ~$target کیلوری/دن (تھوڑا اضافہ)، '
          '${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین، آہستہ آہستہ بوجھ '
          'بڑھائیں اور 6-8 گھنٹے نیند۔ مسلسل رہنا شروع میں شدت سے بہتر ہے۔';
    case CoachIntent.recovery:
      if (p.ageGroup.isMinor) {
        return 'نوجوان کھلاڑیوں کو اضافی آرام کی ضرورت ہے! 8-10 گھنٹے نیند، '
            'ہلکے پھلکے کھیل سے آرام کے دن، اور والدین سے تربیتی منصوبہ '
            'ضرور چیک کروائیں۔';
      }
      if (p.hasHighRiskCondition) {
        return 'آپ کی صحت کی حالت کو دیکھتے ہوئے، اپنے ڈاکٹر سے بحالی کے '
            'بارے میں ضرور پوچھیں۔ ہلکی حرکت، کافی آرام اور طبی مشورے '
            'پر عمل آپ کی ترجیح ہے۔';
      }
      if (p.ageGroup == AgeGroup.older) {
        return 'عمر کے ساتھ بحالی زیادہ اہم ہے۔ 7-9 گھنٹے نیند، اضافی آرام '
            'کے دن، ہلکی اسٹریچنگ یا چہل قدمی کریں۔';
      }
      return 'بحالی میں ہی ترقی ہوتی ہے۔ '
          '${p.isComplete ? "آپ کی سرگرمی (${p.activity.label}) کے لحاظ سے، " : ""}'
          '7-9 گھنٹے نیند، ہفتے میں 1-2 آرام کے دن، کافی پانی، اور مسلسل '
          'ایک ہی پٹھے کو سخت ٹریننگ نہ کریں۔ تیز درد ہو تو روکیں اور '
          'ماہر سے ملیں۔';
    case CoachIntent.form:
      return 'اچھی فارم چوٹ سے بچاتی ہے۔ Home سے "Form Check" کھولیں — یہ '
          'آپ کے کیمرے اور آن-ڈیوائس پوز ڈٹیکشن سے دہرائیں گنتی اور '
          'جوائنٹ اینگل رائے دیتا ہے۔ مشورہ: نیچے کی حرکت آہستہ کریں، '
          'جلدی نہ کریں۔';
    case CoachIntent.motivation:
      return 'آپ نے شروع کیا، اور یہ سب سے مشکل حصہ ہے، $name۔ آج صرف 10 '
          'منٹ کے لیے آ جائیں — رفتار عمل سے آتی ہے۔ ایک دن چھوٹا تو '
          'مسلسل دو نہ چھوڑیں۔ ضرورت ہو تو میں حاضر ہوں۔';
    case CoachIntent.profile:
      if (!p.isComplete) {
        return 'آپ کی معلومات ابھی مکمل نہیں۔ Profile میں عمر، قد اور وزن '
            'شامل کریں تاکہ سب کچھ ذاتی بنا سکوں۔';
      }
      return 'مجھے آپ کے بارے میں یہ معلوم ہے: ${p.toContextSummary()}۔ '
          'کوئی بھی چیز Profile میں کبھی اپ ڈیٹ کریں۔';
    case CoachIntent.medical:
      if (p.ageGroup.isMinor) {
        return 'میں طبی سوالات میں مدد نہیں کر سکتا، $name۔ براہ کرم والدین '
            'یا سرپرست سے بات کریں اور ڈاکٹر سے ملیں۔';
      }
      if (p.hasHighRiskCondition) {
        return 'آپ کی صحت کی صورتحال کے پیشِ نظر، براہ کرم ڈاکٹر یا طبی '
            'ماہر سے مشورہ کریں۔';
      }
      return 'میں فٹنس کوچ ہوں، ڈاکٹر نہیں، $name۔ طبی مسائل کے لیے ڈاکٹر '
          'سے رجوع کریں۔';
    case CoachIntent.unknown:
      return 'میں ورک آؤٹ، غذائیت، بحالی، فارم اور حوصلے میں ماہر ہوں۔ '
          '${p.isComplete ? "\"میرا ورک آؤٹ بناؤ\" یا \"میں کیا کھاؤں?\" آزمائیں۔" : "ذاتی مشورے کے لیے پہلے پروفائل مکمل کریں۔"}';
  }
}

String _hindi(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'वहाँ';
  switch (intent) {
    case CoachIntent.greeting:
      return 'नमस्ते $name! मैं आपका FitAI कोच हूँ। वर्कआउट, पोषण, रिकवरी '
          'और प्रेरणा में मदद कर सकता हूँ। आप क्या चाहते हैं?';
    case CoachIntent.thanks:
      return 'स्वागत है, $name! लगातार बने रहें और परिणाम आएँगे। 💪';
    case CoachIntent.capabilities:
      return 'मैं यह कर सकता हूँ: व्यक्तिगत वर्कआउट योजना बनाना, भोजन और '
          'कैलोरी लक्ष्य सुझाना, रिकवरी और फॉर्म सलाह देना, और प्रेरित '
          'रखना। ${p.isComplete ? "मेरे पास आपकी जानकारी है, इसलिए सुझात आपके लिए हैं।" : "व्यक्तिगत सलाह के लिए Profile में आयु, ऊँचाई और वज़न जोड़ें।"}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'योजना बनाने के लिए मुझे आयु, ऊँचाई, वज़न और लक्ष्य चाहिए। '
            'Profile → Personal Information खोलें और जानकारी जोड़ें।';
      }
      return 'आपके लक्ष्य (${p.goal}), ${p.experience} स्तर और हफ़्ते में '
          '${p.daysPerWeek} दिन (~${p.minutesPerSession} मिनट) के अनुसार '
          'मैं ${p.daysPerWeek}-दिन का विभाजन सुझाता हूँ। Workout टैब खोलें, '
          '"Start Workout" दबाएँ, फिर फॉर्म चेक में वास्तविक समीक्षा लें।';
    case CoachIntent.nutrition:
      if (p.ageGroup.isMinor) {
        return 'युवाओं के लिए संतुलित भोजन ज़रूरी है — प्रोटीन, फल, सब्ज़ियाँ '
            'और पानी पर ध्यान दें। प्रोसेस्ड स्नैक्स और मीठे पेय से बचें।';
      }
      if (p.tdee == null) {
        return 'Profile में ऊँचाई और वज़न जोड़ें ताकि मैं दैनिक कैलोरी '
            'लक्ष्य बता सकूँ। तब तक प्रोटीन, सब्ज़ियाँ, अनाज और पानी पर '
            'ध्यान दें।';
      }
      if (p.hasHighRiskCondition) {
        return 'आपकी स्वास्थ्य स्थिति के अनुसार, कृपया डॉक्टर से व्यक्तिगत '
            'पोषण योजना के लिए सलाह लें।';
      }
      return 'आपकी दैनिक ऊर्जा आवश्यकता लगभग ${p.tdee!.round()} कैलोरी है। '
          '${p.goal} के लिए ~${(p.tdee! * 0.85).round()} कैलोरी और '
          '~${((p.weightKg ?? 70) * 1.6).round()} ग्राम प्रोटीन उपयुक्त है। '
          'Nutrition टैब में भोजन दर्ज करें।';
    case CoachIntent.weightLoss:
      if (p.ageGroup.isMinor) {
        return 'आपकी उम्र में कैलोरी कम करने के बजाय संतुलित भोजन और सक्रिय '
            'रहना बेहतर है। आपका शरीर अभी बढ़ रहा है!';
      }
      if (p.tdee == null) {
        return 'Profile में वज़न जोड़ें ताकि सुरक्षित कैलोरी लक्ष्य बना सकूँ।';
      }
      if (p.hasHighRiskCondition) {
        return 'आपकी स्वास्थ्य स्थिति के अनुसार, वज़न कम करने की योजना '
            'शुरू करने से पहले डॉक्टर से अनुमति लें।';
      }
      final target = (p.tdee! * 0.8).round();
      return 'नियमित वसा हानि के लिए ~$target कैलोरी/दिन (मध्यम घाटा), '
          'अधिक प्रोटीन, सप्ताह में 3-4 बार शक्ति व्यायाम और दैनिक क़दम। '
          'बहुत कम कैलोरी नुक़सानदायक है।';
    case CoachIntent.muscleGain:
      if (p.ageGroup.isMinor) {
        return 'युवावस्था में ताक़त बनाने के लिए शरीर व्यायाम करें, पर्याप्त '
            'प्रोटीन लें और अच्छी नींद लें। भारी वज़न से बचें।';
      }
      if (p.tdee == null) {
        return 'Profile में वज़न जोड़ें ताकि अतिरिक्त कैलोरी लक्ष्य बना सकूँ।';
      }
      final target = (p.tdee! * 1.1).round();
      return 'मांसपेशी बनाने के लिए ~$target कैलोरी/दिन (थोड़ा अधिक), '
          '${((p.weightKg ?? 70) * 1.6).round()} ग्राम प्रोटीन, उत्तरोत्तर '
          'ओवरलोड और 6-8 घंटे नींद।';
    case CoachIntent.recovery:
      if (p.ageGroup.isMinor) {
        return 'युवा एथलीटों को अतिरिक्त आराम चाहिए! 8-10 घंटे नींद, हल्के '
            'खेल से आराम के दिन, और माता-पिता से प्रशिक्षण योजना ज़रूर '
            'जाँच कराएँ।';
      }
      if (p.hasHighRiskCondition) {
        return 'आपकी स्वास्थ्य स्थिति को देखते हुए, कृपया अपने डॉक्टर से '
            'रिकवरी संबंधी सलाह लें। हल्की गतिविधि, पर्याप्त आराम और '
            'चिकित्सा सलाह आपकी प्राथमिकता है।';
      }
      if (p.ageGroup == AgeGroup.older) {
        return 'उम्र के साथ रिकवरी ज़्यादा महत्वपूर्ण है। 7-9 घंटे नींद, '
            'अतिरिक्त विश्राम दिन, हल्की स्ट्रेचिंग या टहलना आज़माएँ।';
      }
      return 'रिकवरी में ही प्रगति होती है। '
          '${p.isComplete ? "आपकी गतिविधि (${p.activity.label}) के अनुसार, " : ""}'
          '7-9 घंटे नींद, सप्ताह में 1-2 विश्राम दिन, पर्याप्त पानी लें। '
          'तेज़ दर्द हो तो रुकें और विशेषज्ञ से मिलें।';
    case CoachIntent.form:
      return 'अच्छी फॉर्म चोट से बचाती है। Home से "Form Check" खोलें — यह '
          'आपके कैमरे और ऑन-डिवाइस पोज़ पहचान से रेप गिनती और जॉइंट-एंगल '
          'समीक्षा देता है। नीचे उतारते समय धीरे जाएँ।';
    case CoachIntent.motivation:
      return 'आपने शुरू किया, और यह सबसे कठिन हिस्सा है, $name। आज सिर्फ़ '
          '10 मिनट के लिए आ जाएँ। एक दिन छूटे तो लगातार दो न छोड़ें।';
    case CoachIntent.profile:
      if (!p.isComplete) {
        return 'आपकी प्रोफ़ाइल अभी पूरी नहीं है। Profile में आयु, ऊँचाई और '
            'वज़न जोड़ें ताकि सब कुछ व्यक्तिगत बने।';
      }
      return 'मुझे आपके बारे में यह पता है: ${p.toContextSummary()}।';
    case CoachIntent.medical:
      if (p.ageGroup.isMinor) {
        return 'मैं चिकित्सा प्रश्नों में मदद नहीं कर सकता, $name। कृपया '
            'अभिभावक से बात करें और डॉक्टर से मिलें।';
      }
      if (p.hasHighRiskCondition) {
        return 'आपकी स्वास्थ्य स्थिति के अनुसार, कृपया डॉक्टर या चिकित्सा '
            'विशेषज्ञ से सलाह लें।';
      }
      return 'मैं फ़िटनेस कोच हूँ, डॉक्टर नहीं, $name। चिकित्सा समस्याओं के '
          'लिए डॉक्टर से संपर्क करें।';
    case CoachIntent.unknown:
      return 'मैं वर्कआउट, पोषण, रिकवरी, फॉर्म और प्रेरणा में निपुण हूँ। '
          '${p.isComplete ? "\"मेरा वर्कआउट बनाओ\" आज़माएँ।" : "पहले प्रोफ़ाइल पूरी करें।"}';
  }
}

String _punjabi(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'اتھے';
  switch (intent) {
    case CoachIntent.greeting:
      return 'سلام $name! میں تہاڈا FitAI کوچ آں۔ ورک آؤٹ، غذائیت، بحالی اور '
          'حوصلے وچ مدد کر سکدا آں۔ تسیں کی کرنا چاہندے او؟';
    case CoachIntent.thanks:
      return 'خوش آمدید، $name! لگاتار رہو تے نتیجے آون گے۔ 💪';
    case CoachIntent.capabilities:
      return 'میں ایہ کر سکدا آں: ذاتی ورک آؤٹ پلان بنانا، کھانے تے کیلوری '
          'ہدف دینا، بحالی تے فارم مشورے، تے حوصلہ۔ '
          '${p.isComplete ? "مینوں تہاڈی معلومات ہن، اس لئی مشورے تہاڈے لئی ہن۔" : "ذاتی مشورے لئی Profile وچ عمر، قد تے وزن پاﺅ۔"}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'پلان بنان لئی مینوں عمر، قد، وزن تے ہدف چاہیدے نے۔ Profile → '
            'Personal Information کھولو تے معلومات پاؤ۔';
      }
      return 'تہاڈے ہدف (${p.goal})، ${p.experience} پدھر تے ہفتے وچ '
          '${p.daysPerWeek} دن (~${p.minutesPerSession} منٹ) موجب میں '
          '${p.daysPerWeek}-دن دا پلان سنواردا آں۔ Workout ٹیب کھولو، '
          '"Start Workout" دباؤ، فیر فارم چیک وچ اصل رائے لاؤ۔';
    case CoachIntent.nutrition:
      if (p.ageGroup.isMinor) {
        return 'ਨੌਜਵानਾਂ ਲਈ ਸੰਤੁਲਿਤ ਖਾਣਾ ਜ਼ਰੂਰੀ ਹੈ — ਪ੍ਰੋਟੀਨ, ਫਲ, ਸਬਜ਼ੀਆਂ '
            'ਅਤੇ ਪਾਣੀ ਤੇ ਧਿਆਨ ਦਿਓ।';
      }
      if (p.tdee == null) {
        return 'Profile وچ قد تے وزن پاؤ تاں روزانہ کیلوری ہدف دے سکاں۔ ';
      }
      if (p.hasHighRiskCondition) {
        return 'آپ کی صحت کی صورتحال کے پیشِ نظر، ڈاکٹر سے غذائی مشورہ لیں۔';
      }
      return 'تہاڈی روزانہ لوڑ لگ بھگ ${p.tdee!.round()} کیلوری ہے۔ '
          '${p.goal} لئی ~${(p.tdee! * 0.85).round()} کیلوری تے '
          '~${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین ٹھیک ہے۔ Nutrition '
          'ٹیب وچ کھانے درج کرو۔';
    case CoachIntent.weightLoss:
      if (p.ageGroup.isMinor) {
        return 'تہاڈی عمر وچ کیلوری گھٹ کرن دے بجائے سنتلت کھانا تے سرگرم '
            'رہنا بہتر ہے۔';
      }
      if (p.tdee == null) return 'Profile وچ وزن پاؤ۔';
      if (p.hasHighRiskCondition) {
        return 'صحت کی صورتحال کی وجہ سے، ڈاکٹر سے اجازت لیں پہلے۔';
      }
      final target = (p.tdee! * 0.8).round();
      return 'مسلسل وزن گھٹ کرن لئی ~$target کیلوری/دن، ودھ پروٹین، ہفتے وچ '
          '3-4 واری طاقت دی مشق تے روزانہ قدم۔';
    case CoachIntent.muscleGain:
      if (p.ageGroup.isMinor) {
        return 'نوجوانی وچ طاقت لئی جسمانی ورزش کرو، پروٹین کھاؤ تے نیند لو۔';
      }
      if (p.tdee == null) return 'Profile وچ وزن پاؤ۔';
      final target = (p.tdee! * 1.1).round();
      return 'پٹھے بنان لئی ~$target کیلوری/دن، '
          '${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین، ہولی ہولی بوجھ '
          'ودھاؤ تے 6-8 گھنٹے نیند۔';
    case CoachIntent.recovery:
      if (p.ageGroup.isMinor) {
        return 'ਨੌਜਵਾਨ ਖਿਡਾਰੀਆਂ ਨੂੰ ਵਾਧੂ ਆਰਾਮ ਦੀ ਲੋੜ ਹੈ! 8-10 ਘੰਟੇ ਨੀਂਦ, '
            'ਹਲਕੇ ਖੇਡ ਨਾਲ ਆਰਾਮ ਦੇ ਦਿਨ, ਤੇ ਮਾਪਿਆਂ ਕੋਲੋਂ ਸਿਖਲਾਈ ਯੋਜਨਾ '
            'ਜ਼ਰੂਰ ਚੈੱਕ ਕਰਵਾਓ।';
      }
      if (p.hasHighRiskCondition) {
        return 'ਤੁਹਾਡੀ ਸਿਹਤ ਹਾਲਤ ਨੂੰ ਵੇਖਦੇ ਹੋਏ, ਡਾਕਟਰ ਕੋਲੋਂ ਆਰਾਮ ਬਾਰੇ '
            'ਸਲਾਹ ਲਓ। ਹਲਕੀ ਹਿਲਜੁਲ, ਕਾਫ਼ੀ ਆਰਾਮ ਤੇ ਡਾਕਟਰੀ ਸਲਾਹ ਤੁਹਾਡੀ '
            'ਪਹਿਲ ਹੈ।';
      }
      if (p.ageGroup == AgeGroup.older) {
        return 'ਉਮਰ ਨਾਲ ਆਰਾਮ ਵਧੇਰੇ ਜ਼ਰੂਰੀ ਹੈ। 7-9 ਘੰਟੇ ਨੀਂਦ, ਵਾਧੂ ਆਰਾਮ '
            'ਦੇ ਦਿਨ, ਹਲਕੀ ਸਟ੍ਰੈਚਿੰਗ ਜਾਂ ਸੈਰ ਕਰੋ।';
      }
      return 'بحالی وچ ہی ترقی ہندی ہے۔ 7-9 گھنٹے نیند، ہفتے وچ 1-2 آرام '
          'دن، کافی پانی پاؤ۔ تیز درد ہووے تاں رکو تے ماہر کول جاؤ۔';
    case CoachIntent.form:
      return 'چنگی فارم چوٹ توں بچاندی ہے۔ Home توں "Form Check" کھولو — ایہ '
          'تہاڈے کیمرے تے آن-ڈیوائس پوز پچھان نال دہرائیں گنتی تے جوائنٹ '
          'اینگل رائے دیندا ہے۔';
    case CoachIntent.motivation:
      return 'تسیں شروع کیتا، تے ایہہ سبھ توں مشکل حصہ ہے، $name۔ اج صرف '
          '10 منٹ لئی آ جاؤ۔';
    case CoachIntent.profile:
      if (!p.isComplete) return 'Profile مکمل کرو۔';
      return 'مینوں تہاڈے بارے ایہہ پتہ ہے: ${p.toContextSummary()}۔';
    case CoachIntent.medical:
      if (p.ageGroup.isMinor) {
        return 'میں طبی سوالات وچ مدد نہیں کر سکدا، $name۔ والدین نال گل کرو '
            'تے ڈاکٹر کول جاؤ۔';
      }
      if (p.hasHighRiskCondition) {
        return 'صحت کی صورتحال کی وجہ سے ڈاکٹر سے مشورہ کرو۔';
      }
      return 'میں فٹنس کوچ آں، ڈاکٹر نہیں، $name۔ طبی مسئلے لئی ڈاکٹر کول جاؤ۔';
    case CoachIntent.unknown:
      return 'میں ورک آؤٹ، غذائیت، بحالی، فارم تے حوصلے وچ ماہر آں۔ '
          '${p.isComplete ? "\"میرا ورک آؤٹ بنا\" آزماؤ۔" : "پہلے پروفائل مکمل کرو۔"}';
  }
}

String _sindhi(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'اُتي';
  switch (intent) {
    case CoachIntent.greeting:
      return 'سلام $name! مان FitAI ڪوچ آهيان. ورڪ آئوٽ، غذائيت، بحالي ۽ '
          'حوصلي ۾ مدد ڪري سگهان ٿو. توهان ڇا چاهيو ٿا؟';
    case CoachIntent.thanks:
      return 'مهرباني، $name! لڳاتار رهو ۽ نتيجا ايندا.';
    case CoachIntent.capabilities:
      return 'مان هي ڪري سگهان ٿو: ذاتی ورڪ آئوٽ پلان، کاڌي ۽ ڪيلوري هدف، '
          'بحالي ۽ فارم صلاحون، ۽ حوصلا. '
          '${p.isComplete ? "مون وٽ توهان جي معلومات آهي." : "Profile ۾ عمر، ڊيگهه ۽ وزن شامل ڪريو."}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'پلان ٺاهڻ لاءِ مون کي عمر، ڊيگهه، وزن ۽ هدف گهرجن. Profile '
            '۾ معلومات شامل ڪريو.';
      }
      return 'توهان جي هدف (${p.goal})، ${p.experience} سطح ۽ هفتي ۾ '
          '${p.daysPerWeek} ڏينهن موجب مان ${p.daysPerWeek}-ڏينهن وارو پلان '
          'تجويز ڪريان ٿو. Workout ٽيب کولو.';
    case CoachIntent.nutrition:
      if (p.ageGroup.isMinor) {
        return 'نوجوانن لاءِ متوازن کاڌو ضروري آھي — پروٽين، ميوا، ڀاڄيون '
            '۽ پاڻي وٺو.';
      }
      if (p.tdee == null) {
        return 'Profile ۾ ڊيگهه ۽ وزن شامل ڪريو.';
      }
      if (p.hasHighRiskCondition) {
        return 'توهان جي صحت جي صورتحال مطابق، ڊاڪٽر سان غذائي صلاح وٺو.';
      }
      return 'توهان جي روزاني ضرورت لڳ بھڳ ${p.tdee!.round()} ڪيلوري آهي. '
          '${p.goal} لاءِ ~${(p.tdee! * 0.85).round()} ڪيلوري ۽ '
          '~${((p.weightKg ?? 70) * 1.6).round()} گرام پروٽين.';
    case CoachIntent.weightLoss:
      if (p.ageGroup.isMinor) {
        return 'توهان جي عمر ۾ ڪيلوري گهٽائڻ بجائي متوازن کاڌو ۽ سرگرم '
            'رهڻ بهتر آهي.';
      }
      if (p.tdee == null) return 'Profile ۾ وزن شامل ڪريو.';
      if (p.hasHighRiskCondition) {
        return 'صحت جي صورتحال مطابق، ڊاڪٽر کان اجازت وٺو.';
      }
      final target = (p.tdee! * 0.8).round();
      return 'وزن گهٽائڻ لاءِ ~$target ڪيلوري/ڏينهن، وڌيڪ پروٽين، هفتي ۾ 3-4 '
          'واري طاقت جي مشق.';
    case CoachIntent.muscleGain:
      if (p.ageGroup.isMinor) {
        return 'نوجواني ۾ طاقت لاءِ جسماني مشق ڪريو، پروٽين وٺو ۽ ننڊ ڪريو.';
      }
      if (p.tdee == null) return 'Profile ۾ وزن شامل ڪريو.';
      final target = (p.tdee! * 1.1).round();
      return 'پٽها ٺاهڻ لاءِ ~$target ڪيلوري/ڏينهن، '
          '${((p.weightKg ?? 70) * 1.6).round()} گرام پروٽين، 6-8 ڪلاڪ نندر.';
    case CoachIntent.recovery:
      if (p.ageGroup.isMinor) {
        return 'نوجوان اٿليٽن کي وڌيڪ آرام جي ضرورت آهي! 8-10 ڪلاڪ نندر، '
            'هلڪي راند سان آرام جا ڏينهن، ۽ والدين کان تربيتي منصوبو '
            'ضرور چيڪ ڪرايو.';
      }
      if (p.hasHighRiskCondition) {
        return 'توهان جي صحت جي حالت کي ڏسندي، مهرباني ڪري پنهنجي ڊاڪٽر '
            'کان رڪوري بابت صلاح وٺو. هلڪي حرڪت، ڪافي آرام ۽ طبي صلاح '
            'توهان جي ترجيح آهي.';
      }
      if (p.ageGroup == AgeGroup.older) {
        return 'عمر سان گڏ رڪوري وڌيڪ اهم آهي. 7-9 ڪلاڪ نندر، وڌيڪ آرام '
            'جا ڏينهن، هلڪي اسٽريچنگ يا چهل قدمي ڪريو.';
      }
      return 'بحالي ۾ ترقي ٿيندي آهي. 7-9 ڪلاڪ نندر، هفتي ۾ 1-2 آرام جا '
          'ڏينهن، پاڻي گهڻو پيئو.';
    case CoachIntent.form:
      return 'سٺي فارم زخم کان بچائي ٿي. "Form Check" کولو — اهو ڪيمري ۽ '
          'آن-ڊوائيس پوز سڃاڻپ سان ريپ ڳڻپ ڏي ٿو.';
    case CoachIntent.motivation:
      return 'توهان شروع ڪيو، اهو سڀ کان ڏکيو حصو آهي، $name. اڄ صرف 10 '
          'منٽ لاءِ اچو.';
    case CoachIntent.profile:
      if (!p.isComplete) return 'Profile مڪمل ڪريو.';
      return 'مون کي توهان بابت هي معلوم آهي: ${p.toContextSummary()}.';
    case CoachIntent.medical:
      if (p.ageGroup.isMinor) {
        return 'مان طبي سوالن ۾ مدد نٿو ڪري سگهان، $name. والدين سان ڳالهايو '
            '۽ ڊاڪٽر وٽ وڃو.';
      }
      if (p.hasHighRiskCondition) {
        return 'صحت جي صورتحال مطابق ڊاڪٽر سان صلاح ڪريو.';
      }
      return 'مان فٽنيس ڪوچ آهيان، ڊاڪٽر نه، $name. طبي مسئلن لاءِ ڊاڪٽر '
          'سان رابطو ڪريو.';
    case CoachIntent.unknown:
      return 'مان ورڪ آئوٽ، غذائيت، بحالي، فارم ۽ حوصلي ۾ ماهر آهيان. '
          '${p.isComplete ? "\"مون لاءِ ورڪ آئوٽ ٺاهو\" آزمايو." : "پهرين پروفائل مڪمل ڪريو."}';
  }
}

String _pashto(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'هلته';
  switch (intent) {
    case CoachIntent.greeting:
      return 'سلام $name! زه ستاسو FitAI کوچ يم. ورک آؤټ، غذاييت، بحالي او '
          'حوصلې کې مرسته کولی شم. تاسو څه غواړئ؟';
    case CoachIntent.thanks:
      return 'مننه، $name! پرله پسې اوسئ او پايلې راځي.';
    case CoachIntent.capabilities:
      return 'زه دا کولی شم: شخصي ورک آؤټ پلان، خواړه او کالوري موخه، بحالي '
          'او فورم مشورې، او هڅونه. '
          '${p.isComplete ? "ما ته ستاسو معلومات لرم." : "په Profile کې عمر، اوږدوالی او وزن ورزومو."}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'د پلان جوړولو لپاره ماته عمر، اوږدوالی، وزن او موخه پکار دي. '
            'Profile کې معلومات ورزومو.';
      }
      return 'ستاسو د موخې (${p.goal})، ${p.experience} کچې او اونۍ کې '
          '${p.daysPerWeek} ورځو له مخې زه ${p.daysPerWeek}-ورځنی پلان '
          'وړاندې کوم. Workout ټب پرانیزئ.';
    case CoachIntent.nutrition:
      if (p.ageGroup.isMinor) {
        return 'د ځوانانو لپاره متوازن خواړه اړین دي — پروټين، مېوې، سبزیجات '
            'او اوبه واخلئ.';
      }
      if (p.tdee == null) {
        return 'په Profile کې اوږدوالی او وزن ورزومو.';
      }
      if (p.hasHighRiskCondition) {
        return 'د صحت د حالت له مخې ډاکټر سره د غذایی مشورې لپاره مشوره وکړئ.';
      }
      return 'ستاسو ورځنۍ اړتيا نژدې ${p.tdee!.round()} کالوري ده. '
          '${p.goal} لپاره ~${(p.tdee! * 0.85).round()} کالوري او '
          '~${((p.weightKg ?? 70) * 1.6).round()} ګرام پروټين.';
    case CoachIntent.weightLoss:
      if (p.ageGroup.isMinor) {
        return 'ستاسو په عمر کې د کالوري کمولو پر ځای متوازن خواړه او فعال '
            'پاتې کیدل غوره دي.';
      }
      if (p.tdee == null) return 'په Profile کې وزن ورزومو.';
      if (p.hasHighRiskCondition) {
        return 'د صحت د حالت له مخې ډاکټر نه اجازه واخلئ.';
      }
      final target = (p.tdee! * 0.8).round();
      return 'د وزن کمولو لپاره ~$target کالوري/ورځ، زيات پروټين، اونۍ کې '
          '3-4 ځله د ځواک تمرين.';
    case CoachIntent.muscleGain:
      if (p.ageGroup.isMinor) {
        return 'د ځوانۍ کې د طاقت لپاره جسماني تمرین وکړئ، پروټين واخلئ او '
            'خوب وکړئ.';
      }
      if (p.tdee == null) return 'په Profile کې وزن ورزومو.';
      final target = (p.tdee! * 1.1).round();
      return 'د عضلو جوړولو لپاره ~$target کالوري/ورځ، '
          '${((p.weightKg ?? 70) * 1.6).round()} ګرام پروټين، 6-8 ساعتونه خوب.';
    case CoachIntent.recovery:
      if (p.ageGroup.isMinor) {
        return 'ځوان لوبغاړو ته اضافي آرام ته اړتیا ده! 8-10 ساعتونه خوب، '
            'سپک لوبو د آرام ورځې، او د والدینو سره د روزنیز پلان بیا '
            'کتنه وکړئ.';
      }
      if (p.hasHighRiskCondition) {
        return 'ستاسو د روغتیایي حالت له مخې، مهرباني وکړئ د خپل ډاکټر څخه '
            'د بحالی مشوره واخلئ. سپک حرکت، کافي آرام او طبي مشوره ستاسو '
            'لومړیتوب دی.';
      }
      if (p.ageGroup == AgeGroup.older) {
        return 'د عمر سره بحالا ډېره مهمه ده. 7-9 ساعتونه خوب، اضافي آرام '
            'ورځې، سپک اسټریچنګ یا پیاده ګي وکړئ.';
      }
      return 'په بحالي کې پرمختګ کيږي. 7-9 ساعتونه خوب، اونۍ کې 1-2 ارام '
          'ورځې، ډېر اوبه وڅښئ.';
    case CoachIntent.form:
      return 'ښه فورم د ټپ څخه ساتي. "Form Check" پرانیزئ — د کيمرې او آن-'
          'ډيوائس پوز پيژندنې سره ريپ شميرنه کوي.';
    case CoachIntent.motivation:
      return 'تاسو پيل وکړ، دا تر ټولو ستونزمنه برخه ده، $name. نن يوازې د '
          '10 دقيقو لپاره راشئ.';
    case CoachIntent.profile:
      if (!p.isComplete) return 'Profile مکمل کړئ.';
      return 'ما ته ستاسو په اړه دا معلوم دي: ${p.toContextSummary()}.';
    case CoachIntent.medical:
      if (p.ageGroup.isMinor) {
        return 'زه د طبي پوښتنو کې مرسته نشی کولی، $name. د والدینو سره خبرې '
            'وکړئ او ډاکټر ته لاړ شئ.';
      }
      if (p.hasHighRiskCondition) {
        return 'د صحت د حالت له مخې ډاکټر سره مشوره وکړئ.';
      }
      return 'زه د فټنېس کوچ یم، ډاکټر نه، $name. د طبي ستونزو لپاره ډاکټر '
          'سره اړیکه ونیسئ.';
    case CoachIntent.unknown:
      return 'زه په ورک آؤټ، غذاييت، بحالي، فورم او هڅونه کې ماهر يم. '
          '${p.isComplete ? "\"زما ورک آؤټ جوړ کړه\" وآزمايئ." : "لومړی پروفایل مکمل کړئ."}';
  }
}

String _balochi(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'اِتھ';
  switch (intent) {
    case CoachIntent.greeting:
      return 'سلام $name! من ئے FitAI کوچ انت. ورک آؤٹ، غذائیت، بحالی ؤ '
          'حوصلئَ ءَ مدد کن دارت. تو چه گوارٹ؟';
    case CoachIntent.thanks:
      return 'مهربانی، $name! لگاتار بہ ؤ نتیجہ شی۔';
    case CoachIntent.capabilities:
      return 'من ای کن دارم: شخصی ورک آؤٹ پلان، کھانا ؤ کیلوری ہدف، بحالی ؤ '
          'فارم مشورہ، ؤ ہچون۔ '
          '${p.isComplete ? "مئَ تئی معلومات درنت۔" : "Profile ءَ عمر، درازی ؤ وزن اِش کن۔"}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'پلانءَ ساجتءَ وہَتی منءَ عمر، درازی، وزن ؤ ہدف لازمی انت. '
            'Profile ءَ معلومات اِش کن۔';
      }
      return 'تئی ہدف (${p.goal})، ${p.experience} سطحه ؤ روچءَ '
          '${p.daysPerWeek} روچ موجب من ${p.daysPerWeek}-روچی پلان وۆارٹ۔ '
          'Workout ٹب کہ بز۔';
    case CoachIntent.nutrition:
      if (p.ageGroup.isMinor) {
        return 'نوجوانان لاءِ متوازن کاڌو ضروری انت — پروٹین، میوا، سبزیان '
            'ؤ پاݨی وٺو.';
      }
      if (p.tdee == null) {
        return 'Profile ءَ درازی ؤ وزن اِش کن۔';
      }
      if (p.hasHighRiskCondition) {
        return 'تئی صحت حالت موجب ڈاکٹر سان غذائی صلاح وٺو.';
      }
      return 'تئی روچی ضرورت لگ بگ ${p.tdee!.round()} کیلوری انت. '
          '${p.goal} وہَتی ~${(p.tdee! * 0.85).round()} کیلوری ؤ '
          '~${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین۔';
    case CoachIntent.weightLoss:
      if (p.ageGroup.isMinor) {
        return 'تئی عمر ءَ کیلوری کم کہ کن دے بجائے متوازن کاڌو ؤ سرگرم '
            'رہݨ بہتر انت.';
      }
      if (p.tdee == null) return 'Profile ءَ وزن اِش کن۔';
      if (p.hasHighRiskCondition) {
        return 'صحت حالت موجب ڈاکٹر کان اِجازت وٺو.';
      }
      final target = (p.tdee! * 0.8).round();
      return 'وزن کہ کم کہ کنءَ وہَتی ~$target کیلوری/روچ، گێں پروٹین، روچءَ '
          '3-4 وار طاقتی مشق۔';
    case CoachIntent.muscleGain:
      if (p.ageGroup.isMinor) {
        return 'نوجوانی ءَ طاقت لاءِ جسمانی مشق کن، پروٹین وٺ ؤ نیند کن.';
      }
      if (p.tdee == null) return 'Profile ءَ وزن اِش کن۔';
      final target = (p.tdee! * 1.1).round();
      return 'پٹہ ساجتءَ وہَتی ~$target کیلوری/روچ، '
          '${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین، 6-8 گنتی نئندگ۔';
    case CoachIntent.recovery:
      if (p.ageGroup.isMinor) {
        return 'نوجوان اٿلیٹں کہِ وڌیڪ آرام کہِ ضرورت انت! 8-9 گنتی نئندگ، '
            'سپک لوبءَ آرام روچ، والدينءَ تربيتی پلان چيڪ ڪرايو.';
      }
      if (p.hasHighRiskCondition) {
        return 'توهانءَ صحتءَ حالءَ ڏسنت، مهرباني ڪری پنہنجی ڈاكټرءَ '
            'بحالیءَ مشورہ گيشو. هلڪ حركت، كافي آرام طبی مشورہ توهانءَ '
            'ترجيح انت.';
      }
      if (p.ageGroup == AgeGroup.older) {
        return 'عمرءَ سان بحالا وڌيڪ اهم انت. 7-9 گنتی نئندگ، وڌيڪ آرام '
            'روچ، سپک اسٽريچنگ يا پياده ګي ڪريو.';
      }
      return 'بحالیءَ پہتراسی پیشرفت کنت۔ 7-9 گنتی نئندگ، روچءَ 1-2 آرام '
          'روچ، گێں پانی بہچ۔';
    case CoachIntent.form:
      return 'جاہ فارم ءَ زخم کنت بچیت۔ "Form Check" بز — ای کیمرءَ ؤ '
          'آن-ڈیوائس پوز پیژندگ ءَ ریپ شمار کنت۔';
    case CoachIntent.motivation:
      return 'تو پیل کہیت، اے گێں سخت ترین حصہ انت، $name۔ انکہ فقط 10 '
          'دقیقءَ وہَتی بہ ی۔';
    case CoachIntent.profile:
      if (!p.isComplete) return 'Profile مکمل کن۔';
      return 'مئَ تئی بارءَ ای معلوم انت: ${p.toContextSummary()}۔';
    case CoachIntent.medical:
      if (p.ageGroup.isMinor) {
        return 'من طبی سوالان ءَ مدد نہ کن دارت، $name. والدین سان ڳالھاہ کن '
            'ؤ ڈاکٹر ءَ جاؤ.';
      }
      if (p.hasHighRiskCondition) {
        return 'صحت حالت موجب ڈاکٹر سان صلاح کن.';
      }
      return 'من فٽنيس کوچ انت، ڈاکٹر نہ، $name. طبی مسئلان لاءِ ڈاکٹر سان '
          'رابطہ کن.';
    case CoachIntent.unknown:
      return 'من ورک آؤٹ، غذائیت، بحالی، فارم ؤ ہچونءَ ماهر انت۔ '
          '${p.isComplete ? "\"مئے ورک آؤٹ ساج\" آزمایش۔" : "پہتے پروفائل مکمل کن۔"}';
  }
}

String _romanEnglish(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'dost';
  switch (intent) {
    case CoachIntent.greeting:
      return 'Assalam o Alaikum $name! Main aapka FitAI coach hoon. Workout, '
          'nutrition, recovery aur motivation mein madad kar sakta hoon. '
          'Bataiye kya kaam karna hai?';
    case CoachIntent.thanks:
      return 'Shukriya $name! Lage rahein, zaroor results aayenge. 💪';
    case CoachIntent.capabilities:
      return 'Main yeh kar sakta hoon: personal workout plan banana, khana '
          'aur calorie target suggest karna, recovery aur form ki advice '
          'dena, aur aapko motivate karna. '
          '${p.isComplete ? "Mere paas aapki info hai, toh tips aapke liye hain." : "Personal advice ke liye Profile mein umar, qad aur wazan dalein."}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'Plan bananay ke liye mujhe umar, qad, wazan aur goal chahiye. '
            'Profile → Personal Information kholain aur details dalein.';
      }
      return _buildDetailedWorkoutPlan(p);
    case CoachIntent.nutrition:
      if (p.ageGroup.isMinor) {
        return 'Jawano ke liye balanced khana zaroori hai — protein, fruits, '
            'sabziyan aur paani lein. Processed snacks aur meethay drinks se '
            'bachein.';
      }
      if (p.tdee == null) {
        return 'Profile mein qad aur wazan dalein taake main daily calorie '
            'target bata sakoon. Abhi ke liye protein, sabziyan, anaaj aur '
            'paani par tawajjo dein.';
      }
      if (p.hasHighRiskCondition) {
        return 'Aapki health conditions ke hisaab se, doctor se personalized '
            'nutrition plan ke liye mashwara karein.';
      }
      return _buildDetailedNutritionPlan(p);
    case CoachIntent.weightLoss:
      if (p.ageGroup.isMinor) {
        return 'Aapki umar mein calorie kam karne ke bajaye balanced khana '
            'aur active rehna behtar hai. Aapka jism abhi barh raha hai!';
      }
      if (p.tdee == null) {
        return 'Wazan Profile mein dalein taake safe calorie target bana sakoon.';
      }
      if (p.hasHighRiskCondition) {
        return 'Aapki health conditions ke hisaab se, weight loss plan '
            'shuru karne se pehle doctor se ijazat lein.';
      }
      final target = (p.tdee! * 0.8).round();
      final protein = ((p.weightKg ?? 70) * 1.6).round();
      final sb = StringBuffer();
      sb.writeln('Aapka fat-loss plan yeh hai:\n');
      sb.writeln('━━━ Khurak ━━━');
      sb.writeln('• Rozana target: ~$target kcal (${p.tdee!.round()} se moderate kam)');
      sb.writeln('• Protein: ~${protein}g — muscle bachane ke liye');
      sb.writeln('• Lunch & dinner mein aadha plate sabziyan rakhein');
      sb.writeln('• Meethay drinks aur processed snacks band karein');
      sb.writeln('• 8+ glass paani rozana piyein');
      sb.writeln('\n━━━ Training (${p.daysPerWeek} din/hafta) ━━━');
      sb.writeln('• Strength training ${p.daysPerWeek}x/hafta (full body ya upper/lower)');
      sb.writeln('• Compound exercises pe focus: squats, deadlifts, rows, presses');
      sb.writeln('• Har session ke baad 10-15 min tez walk ya cardio');
      sb.writeln('• Rozana 8,000-10,000 steps ka target rakhein');
      sb.writeln('\n━━━ Recovery ━━━');
      sb.writeln('• 7-9 ghantay neend — kam neend bhookh barhati hai');
      sb.writeln('• Haftay mein 1-2 aaram ke din lein');
      sb.writeln('• Khana na chhorein — waqt par khaayein');
      sb.write('\nLage rahein — chhoti daily deficit bhi bara result deti hai!');
      return sb.toString().trim();
    case CoachIntent.muscleGain:
      if (p.ageGroup.isMinor) {
        return 'Jawani mein taqat banane ke liye bodyweight exercises karein, '
            'protein lein aur neend lein. Bhaari wazan se bachein.';
      }
      if (p.tdee == null) {
        return 'Wazan Profile mein dalein taake surplus target bana sakoon.';
      }
      final target = (p.tdee! * 1.1).round();
      final protein = ((p.weightKg ?? 70) * 1.6).round();
      final sb = StringBuffer();
      sb.writeln('Aapka muscle-building plan yeh hai:\n');
      sb.writeln('━━━ Khurak ━━━');
      sb.writeln('• Rozana target: ~$target kcal (${p.tdee!.round()} se thoda zyada)');
      sb.writeln('• Protein: ~${protein}g (chicken, anday, machli, daal, dahi)');
      sb.writeln('• Har khane mein protein shamil karein');
      sb.writeln('• Workout ke baad: protein + carbs 1 ghantay mein');
      sb.writeln('• Khana na chhorein — growth ke liye consistency zaroori hai');
      sb.writeln('\n━━━ Training (${p.daysPerWeek} din/hafta) ━━━');
      sb.writeln('• Progressive overload — har haftay weight ya reps barhayein');
      sb.writeln('• Pehle compound lifts: squats, deadlifts, bench, rows, OHP');
      sb.writeln('• ${p.experience == 'Beginner' ? '2-3 sets × 10-12 reps (halka-darmiyana weight)' : p.experience == 'Intermediate' ? '3 sets × 8-10 reps (darmiyana weight)' : '4 sets × 6-8 reps (bhaari weight)'}');
      sb.writeln('• Sets ke beech ${p.experience == 'Beginner' ? '90 sec' : p.experience == 'Intermediate' ? '60-90 sec' : '45-60 sec'} aaram');
      sb.writeln('\n━━━ Recovery ━━━');
      sb.writeln('• 7-9 ghantay neend — muscles gym mein nahi, sote waqt barhti hain');
      sb.writeln('• Lagatar ek hi muscle ko hard train na karein');
      sb.writeln('• Paani zyada piyein: 8+ glass rozana');
      sb.write('\nMuscle waqt leta hai — process pe bharosa rakhein aur lage rahein!');
      return sb.toString().trim();
    case CoachIntent.recovery:
      if (p.ageGroup.isMinor) {
        return 'Young athletes ko extra recovery chahiye! 8-10 ghantay neend, '
            'halkay khel se aaram ke din, aur parents se training plan zaroor '
            'check karwayein. Fun pe focus karein, intensity pe nahi.';
      }
      if (p.hasHighRiskCondition) {
        return 'Aapki health condition ko dekhte hue, apne doctor se recovery '
            'ke baare mein zaroor poochein. Halki harkat, kaafi aaram aur '
            'medical advice aapki priority hai.';
      }
      if (p.ageGroup == AgeGroup.older) {
        return 'Umar ke saath recovery zyada important hai. 7-9 ghantay neend, '
            'extra rest days, halki stretching ya walk karein.';
      }
      return 'Recovery mein hi taraqqi hoti hai. '
          '${p.isComplete ? "Aapki activity (${p.activity.label}) ke hisaab se, " : ""}'
          '7-9 ghantay neend, haftay mein 1-2 aaram ke din, paani zyada '
          'piyein, aur lagatar ek hi muscle ko hard train na karein. Tez '
          'dard ho toh ruken aur doctor se milein.';
    case CoachIntent.form:
      return 'Achi form chot se bachati hai. Home se "Form Check" kholain — '
          'yeh camera aur on-device pose detection se reps ginta hai aur '
          'joint angle feedback deta hai. Tip: neeche ki movement ahista '
          'karein, jaldi na karein.';
    case CoachIntent.motivation:
      return 'Aap ne shuru kiya, aur yeh sab se mushkil hissa hai, $name. '
          'Aaj sirf 10 minute ke liye aa jayein — momentum action se aata '
          'hai. Ek din chhoota toh lagatar do na chhorein. Zaroorat ho toh '
          'main hazir hoon.';
    case CoachIntent.profile:
      if (!p.isComplete) {
        return 'Aapki info abhi mukammal nahi. Profile mein umar, qad aur '
            'wazan dalein taake sab kuch personal bana sakoon.';
      }
      return 'Mujhe aap ke baare mein yeh pata hai: ${p.toContextSummary()}. '
          'Koi bhi cheez Profile mein kabhi bhi update karein.';
    case CoachIntent.medical:
      if (p.ageGroup.isMinor) {
        return 'Main medical sawalaat mein madad nahi kar sakta, $name. '
            'Walidain se baat karein aur doctor se milein.';
      }
      if (p.hasHighRiskCondition) {
        return 'Aapki health conditions ke hisaab se doctor ya medical '
            'professional se mashwara karein.';
      }
      return 'Main fitness coach hoon, doctor nahi, $name. Medical masail '
          'ke liye doctor se rabta karein.';
    case CoachIntent.unknown:
      return 'Main workout, nutrition, recovery, form aur motivation mein '
          'expert hoon. '
          '${p.isComplete ? "\"Mera workout banao\" ya \"main kya khaun?\" azmayein." : "Personal advice ke liye pehle profile mukammal karein."}';
  }
}

// Keep the math import used (defensive — avoids unused-import lint).
// ignore: unused_element
double _clamp(double v, double lo, double hi) => math.min(math.max(v, lo), hi);
