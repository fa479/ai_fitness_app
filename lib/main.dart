import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// FitAI feature modules
import 'app/app_localizations.dart';
import 'features/form_check_screen.dart';
import 'features/ai_coach_screen.dart';
import 'features/nutrition_screen.dart';
import 'features/workout_plan_screen.dart';
import 'features/gym_music_screen.dart';
import 'core/voice_service.dart';
import 'core/user_profile_service.dart';
import 'core/food_data.dart';
import 'core/workout_planner_engine.dart';
import 'core/pose_analyzer.dart';
import 'exercise_library.dart';

void main() {
  runApp(const AIFitnessApp());
}

class AIFitnessApp extends StatefulWidget {
  const AIFitnessApp({super.key});

  @override
  State<AIFitnessApp> createState() => _AIFitnessAppState();
}

class _AIFitnessAppState extends State<AIFitnessApp> {
  ThemeMode themeMode = ThemeMode.dark;
  int _languageVersion = 0;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await L.load();
    await VoiceService.instance.initStt();
    await VoiceService.instance.initTts();
    loadThemeMode();
  }

  Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAppearance = prefs.getString('appearance') ?? 'Dark mode';

    if (!mounted) return;

    setState(() {
      if (savedAppearance == 'Light mode') {
        themeMode = ThemeMode.light;
      } else if (savedAppearance == 'System default') {
        themeMode = ThemeMode.system;
      } else {
        themeMode = ThemeMode.dark;
      }
    });
  }

  void changeThemeMode(ThemeMode mode) {
    setState(() {
      themeMode = mode;
    });
  }

  Future<void> changeLanguage(String language) async {
    await L.set(language);
    setState(() {
      _languageVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable — used to trigger rebuild on language change
    final lang = _languageVersion;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Fitness',
      locale: Locale(L.current),
      builder: (context, child) {
        return Directionality(
          textDirection: L.textDirection,
          child: child!,
        );
      },

      themeMode: themeMode,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101014),
      ),

      home: HomeScreen(
        onThemeChanged: changeThemeMode,
        onLanguageChanged: changeLanguage,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final Future<void> Function(String) onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final int _progressRefreshTrigger = 0;

  void _openFormCheck() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormCheckScreen(
          targetSets: 3,
          targetRepsPerSet: 10,
          // FormCheck exercise completion is NOT a full workout.
          // Only ActiveWorkoutScreen records full workout progress.
          onExerciseCompleted: (completedSets, totalReps) {
            // Exercise-only completion — no progress recorded.
            // This callback is kept for potential future exercise tracking
            // but does NOT count as a full workout.
          },
        ),
      ),
    );
  }

  List<Widget> get _screens => [
    HomeContent(onFormCheckTap: _openFormCheck),
    const WorkoutScreen(),
    ProgressScreen(refreshTrigger: _progressRefreshTrigger),
    ProfileScreen(
      onThemeChanged: widget.onThemeChanged,
      onLanguageChanged: widget.onLanguageChanged,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          L.t('appName'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: L.t('tabHome'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon: const Icon(Icons.fitness_center),
            label: L.t('tabWorkout'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: L.t('tabProgress'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: L.t('tabProfile'),
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final VoidCallback? onFormCheckTap;
  const HomeContent({super.key, this.onFormCheckTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${L.t("welcome")} \u{1F44B}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            L.t('aiCoachReady'),
            style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _FeatureCard(
                  icon: Icons.auto_awesome,
                  title: L.t('aiCoach'),
                  subtitle: L.t('aiCoachSubtitle'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AICoachChatScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _FeatureCard(
                  icon: Icons.camera_alt_outlined,
                  title: L.t('formCheck'),
                  subtitle: L.t('formCheckSubtitle'),
                  onTap: onFormCheckTap,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _FeatureCard(
            icon: Icons.restaurant_menu,
            title: L.t('tabNutrition'),
            subtitle: L.t('nutritionSubtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NutritionScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _FeatureCard(
            icon: Icons.favorite_outline,
            title: L.t('womensWellness'),
            subtitle: L.t('womensWellnessSubtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WomensWellnessScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 28),

          Text(
            L.t('quickActions'),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          _ActionTile(
            icon: Icons.calendar_month,
            title: L.t('myWorkoutPlan'),
            subtitle: L.t('myWorkoutPlanSubtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WorkoutPlanScreen(),
                ),
              );
            },
          ),

          _ActionTile(
            icon: Icons.menu_book_outlined,
            title: L.t('exerciseLibrary'),
            subtitle: L.t('exerciseLibrarySubtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExerciseLibraryScreen(),
                ),
              );
            },
          ),

          _ActionTile(
            icon: Icons.music_note,
            title: L.t('gymMusic'),
            subtitle: L.t('gymMusicSubtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GymMusicScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: Colors.deepPurpleAccent),

            const SizedBox(height: 14),

            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

class AICoachScreen extends StatefulWidget {
  const AICoachScreen({super.key});

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> {
  final TextEditingController _messageController = TextEditingController();

  final List<Map<String, String>> _messages = [
    {
      'sender': 'AI',
      'message':
          'Hi! 👋 I\'m your AI Fitness Coach. How can I help you today?',
    },
  ];

  void _sendMessage() {
    final message = _messageController.text.trim();

    if (message.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'You', 'message': message});

      _messages.add({
        'sender': 'AI',
        'message':
            'Great! 💪 I can help you with workouts, fitness goals, recovery and healthy habits.',
      });
    });

    _messageController.clear();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Coach',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isAI = message['sender'] == 'AI';

                return Align(
                  alignment: isAI
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: isAI
                          ? Colors.deepPurple.withValues(alpha: 0.25)
                          : Colors.deepPurple,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      message['message']!,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask your AI Coach...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WomensWellnessScreen extends StatelessWidget {
  const WomensWellnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          L.t('womensWellness'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite_outline, size: 34),
                  const SizedBox(height: 12),
                  Text(
                    L.t('yourWellnessYourWay'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    L.t('wellnessDetail'),
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text(
              L.t('womensWellness'),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            _WellnessFeatureTile(
              icon: Icons.calendar_month_outlined,
              title: L.t('cycleAwareFitness'),
              subtitle: L.t('cycleAwareFitnessSubtitle'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CycleAwareFitnessScreen(),
                  ),
                );
              },
            ),

            _WellnessFeatureTile(
              icon: Icons.restaurant_menu_outlined,
              title: L.t('cycleAwareNutrition'),
              subtitle: L.t('cycleAwareNutritionSubtitle'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CycleAwareNutritionScreen(),
                  ),
                );
              },
            ),

            _WellnessFeatureTile(
              icon: Icons.favorite_border,
              title: L.t('pcosSupport'),
              subtitle: L.t('pcosSubtitle'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PcosSupportScreen(),
                  ),
                );
              },
            ),

            _WellnessFeatureTile(
              icon: Icons.pregnant_woman_outlined,
              title: L.t('pregnancy'),
              subtitle: L.t('pregnancySubtitle'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PregnancyScreen(),
                  ),
                );
              },
            ),

            _WellnessFeatureTile(
              icon: Icons.healing_outlined,
              title: L.t('postpartum'),
              subtitle: L.t('postpartumSubtitle'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PostpartumScreen(),
                  ),
                );
              },
            ),

            _WellnessFeatureTile(
              icon: Icons.wb_sunny_outlined,
              title: L.t('hormonalWellness'),
              subtitle: L.t('hormonalWellnessSubtitle'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HormonalWellnessScreen(),
                  ),
                );
              },
            ),

            _WellnessFeatureTile(
              icon: Icons.health_and_safety_outlined,
              title: L.t('safetyMode'),
              subtitle: L.t('safetyModeSubtitle'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WomensSafetyModeScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WellnessFeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WellnessFeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WellnessProfile {
  final String age;
  final String height;
  final String weight;
  final String goal;

  const _WellnessProfile({
    required this.age,
    required this.height,
    required this.weight,
    required this.goal,
  });

  static Future<_WellnessProfile> load() async {
    final prefs = await SharedPreferences.getInstance();

    return _WellnessProfile(
      age: prefs.getString('user_age') ?? '',
      height: prefs.getString('user_height') ?? '',
      weight: prefs.getString('user_weight') ?? '',
      goal: prefs.getString('user_goal') ?? '',
    );
  }

  bool get hasProfile =>
      age.isNotEmpty ||
      height.isNotEmpty ||
      weight.isNotEmpty ||
      goal.isNotEmpty;

  String get profileSummary {
    final parts = <String>[];

    if (age.isNotEmpty) {
      parts.add('Age: $age');
    }

    if (height.isNotEmpty) {
      parts.add('Height: $height');
    }

    if (weight.isNotEmpty) {
      parts.add('Weight: $weight');
    }

    if (goal.isNotEmpty) {
      parts.add('Goal: $goal');
    }

    if (parts.isEmpty) {
      return 'Complete your fitness profile for better personalization.';
    }

    return parts.join(' • ');
  }

  String get goalGuidance {
    final normalized = goal.toLowerCase();

    if (normalized.contains('strength')) {
      return 'Focus on regular balanced meals, protein-containing foods, carbohydrates for activity, vegetables/fruits and adequate fluids.';
    }

    if (normalized.contains('fitness') ||
        normalized.contains('fitness level')) {
      return 'Focus on balanced meals and enough food to support your normal activity and recovery.';
    }

    if (normalized.contains('weight')) {
      return 'Focus on balanced eating, regular meals and healthy activity rather than restrictive portions.';
    }

    return 'Focus on regular balanced meals and a variety of nutritious foods.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Personalized meal data generated from user profile
// ─────────────────────────────────────────────────────────────────────────────
class _PersonalizedMeal {
  final String mealName;
  final String timing;
  final String portion;
  final List<String> foodOptions;
  final String benefit;

  const _PersonalizedMeal({
    required this.mealName,
    required this.timing,
    required this.portion,
    required this.foodOptions,
    required this.benefit,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Generates personalized meal recommendations from UserProfile.
//
// Uses the existing NutritionService.targetCalories() (which derives from
// BMR via Mifflin-St Jeor + activity factor + goal adjustment) to produce
// per-meal calorie-aware portion guidance.  Timing is derived from the
// user's activity level and experience.  No hard-coded universal values.
// ─────────────────────────────────────────────────────────────────────────────
class _MealPersonalizer {
  final UserProfile profile;

  _MealPersonalizer(this.profile);

  /// Daily calorie target from the existing FitAI nutrition engine,
  /// or null when the profile is incomplete.
  int? get _dailyCalories {
    final tdee = profile.tdee;
    if (tdee == null) return null;
    return NutritionService.instance.targetCalories(profile);
  }

  /// Whether the user is a minor (age < 18).
  bool get _isMinor {
    final age = profile.ageInt;
    return age != null && age < 18;
  }

  /// Calorie distribution per meal type (fraction of daily target).
  double _mealFraction(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return 0.25;
      case 'Lunch':
        return 0.35;
      case 'Snack':
        return 0.10;
      case 'Dinner':
        return 0.30;
      default:
        return 0.25;
    }
  }

  /// Per-meal calorie estimate, or null when unavailable.
  int? _mealCalories(String mealType) {
    final daily = _dailyCalories;
    if (daily == null) return null;
    return (daily * _mealFraction(mealType)).round();
  }

  /// Generates a personalized timing recommendation using relative
  /// descriptions based on the user's profile.
  ///
  /// The app does NOT store wake-up time, workout start time, or daily
  /// schedule. Rather than estimating clock times from age or activity
  /// (which would pretend to know the user's real schedule), this method
  /// provides actionable relative timing derived from the user's actual
  /// profile data: activity level, workout frequency, session duration,
  /// and experience.
  String _personalizedTiming(String mealType, {String? workoutContext}) {
    final activity = profile.activity;
    final daysPerWeek = int.tryParse(profile.daysPerWeek) ?? 3;
    final minutesPerSession = int.tryParse(profile.minutesPerSession) ?? 45;
    final experience = profile.experience.toLowerCase();

    switch (mealType) {
      case 'Breakfast':
        if (workoutContext != null && daysPerWeek >= 3) {
          return 'Morning, ideally 30\u201360 minutes before or after your $workoutContext session';
        }
        if (activity.factor >= 1.55 && daysPerWeek >= 4) {
          return 'Morning, ideally 1\u20132 hours before your typical training window';
        }
        if (daysPerWeek >= 3) {
          return 'Morning, ideally on your regular activity days and rest days alike';
        }
        if (activity.factor >= 1.375) {
          return 'Morning, about 1 hour after starting your day';
        }
        return 'Morning, within the first hours after waking';

      case 'Lunch':
        if (daysPerWeek >= 4 && minutesPerSession >= 45) {
          return 'Midday, allowing 2\u20133 hours after breakfast for sustained energy';
        }
        if (activity.factor >= 1.55) {
          return 'Midday, roughly 4\u20135 hours after breakfast';
        }
        if (daysPerWeek >= 3) {
          return 'Midday, roughly 3\u20134 hours after breakfast to maintain energy';
        }
        return 'Midday, roughly 3\u20134 hours after breakfast';

      case 'Snack':
        if (workoutContext != null) {
          return 'Around your $workoutContext session \u2014 before or after depending on hunger';
        }
        if (daysPerWeek >= 3) {
          return 'Between meals, timed around your activity days or when energy dips';
        }
        if (activity.factor >= 1.55) {
          return 'Between meals, timed around your activity or when energy dips';
        }
        return 'Between meals, based on hunger and daily activity';

      case 'Dinner':
        if (experience.contains('beginner')) {
          return 'Evening, at least 2 hours before your usual sleep time';
        }
        if (activity.factor >= 1.55) {
          return 'Evening, allowing 3\u20134 hours after lunch for balanced digestion';
        }
        return 'Evening, allowing 2\u20133 hours after your last main meal';

      default:
        return 'Around your normal routine';
    }
  }

  /// Generates a personalized portion description with practical serving
  /// guidance derived from the user's profile and existing nutrition
  /// calculations.
  ///
  /// Uses the full BMR→TDEE→calorie-target chain (which includes height,
  /// age, weight, activity and goal) to compute per-meal protein and
  /// carbohydrate gram targets, then converts those into practical
  /// food-amount descriptions (e.g. "About 120g protein-rich food").
  ///
  /// Safety constraints:
  /// - No restrictive portions for minors
  /// - No calorie numbers shown for pregnancy context
  /// - General guidance when profile is incomplete
  String _personalizedPortion(
    String mealType, {
    bool restrictCalorieDisplay = false,
  }) {
    final cal = _mealCalories(mealType);

    // When profile is incomplete or user is a minor, avoid calorie numbers
    if (cal == null || _isMinor || restrictCalorieDisplay) {
      return _generalPortionGuidance(mealType);
    }

    // Compute protein and carb gram targets from the full BMR chain.
    // height → BMR → TDEE → calorieTarget → perMealCal → proteinG/carbG
    final proteinG = _proteinGramTarget(mealType);
    final carbG = _carbGramTarget(cal, proteinG);

    // Convert gram targets into practical food-amount descriptions.
    final proteinStr = _practicalProteinAmount(proteinG);
    final carbStr = _practicalCarbAmount(carbG, mealType);

    return '$proteinStr + $carbStr + vegetables to fill the plate. '
        'Adjust to comfort and hunger.';
  }

  /// Protein gram target for a single meal, derived from both the calorie
  /// target and the weight-based requirement.  Uses the higher of:
  /// - Calorie-based: protein calories as a share of the meal target
  /// - Weight-based: body weight × goal-specific factor × meal fraction
  ///
  /// This ensures height (via BMR→calories) and weight both contribute.
  double _proteinGramTarget(String mealType) {
    final cal = _mealCalories(mealType);
    if (cal == null) return 15;

    final goalLower = profile.goal.toLowerCase();
    final isStrengthGoal =
        goalLower.contains('strength') || goalLower.contains('muscle');
    final isWeightMgmt = goalLower.contains('weight') ||
        goalLower.contains('management');

    // Protein calorie share from goal
    final double proteinCalShare;
    if (isStrengthGoal) {
      proteinCalShare = 0.30;
    } else if (isWeightMgmt) {
      proteinCalShare = 0.25;
    } else {
      proteinCalShare = 0.20;
    }

    final calBasedProtein = (cal * proteinCalShare) / 4.0;

    // Weight-based protein
    double weightBased = 0;
    final weightKg = profile.weightKg;
    if (weightKg != null && weightKg > 0) {
      final double proteinFactor;
      if (isStrengthGoal) {
        proteinFactor = 1.6;
      } else if (isWeightMgmt) {
        proteinFactor = 1.2;
      } else {
        proteinFactor = 1.0;
      }
      weightBased = weightKg * proteinFactor * _mealFraction(mealType);
    }

    // Use the higher of calorie-based and weight-based
    return calBasedProtein > weightBased ? calBasedProtein : weightBased;
  }

  /// Carbohydrate gram target for a single meal, derived from the
  /// remaining calories after protein allocation.
  double _carbGramTarget(int perMealCal, double proteinG) {
    final proteinCal = proteinG * 4;
    final remainingCal = (perMealCal - proteinCal).clamp(0, perMealCal);
    // Carbs receive ~45% of remaining calories
    return (remainingCal * 0.45) / 4.0;
  }

  /// Converts protein grams into a practical food-amount description.
  /// Uses approximate real-world food weights so the output is actionable
  /// rather than a vague adjective.
  String _practicalProteinAmount(double proteinG) {
    // Approximate grams of common protein-rich food to supply proteinG:
    // lean meat/fish ~20g protein per 100g, eggs/paneer ~15g per 100g
    final foodG = (proteinG * 5).round(); // ~5x protein grams in food weight
    if (foodG <= 50) return 'About ${foodG}g protein-rich food (such as eggs, paneer or daal)';
    if (foodG <= 100) return 'About ${foodG}g protein-rich food (such as chicken, fish, eggs or paneer)';
    return 'About ${foodG}g protein-rich food (such as chicken, fish, eggs, paneer or lean meat)';
  }

  /// Converts carbohydrate grams into a practical food-amount description.
  /// Uses approximate cooked-food weights so the output is actionable.
  String _practicalCarbAmount(double carbG, String mealType) {
    if (mealType == 'Snack') {
      // Snack carbs → fruit + small starch
      final fruitG = (carbG * 3).round();
      if (fruitG <= 50) return 'a small piece of fruit';
      if (fruitG <= 120) return 'a piece of fruit';
      return 'a piece of fruit with a small portion of nuts or grains';
    }
    // Cooked grains/rice ~25g carbs per 100g
    final cookedG = (carbG * 4).round();
    if (cookedG <= 75) return 'a modest portion of cooked grains or starches (such as roti, rice or oats)';
    if (cookedG <= 150) return 'a moderate portion of cooked grains or starches (such as roti, rice or oats)';
    if (cookedG <= 250) return 'a substantial portion of cooked grains or starches (such as roti, rice or oats)';
    return 'a large portion of cooked grains or starches (such as roti, rice or oats)';
  }

  /// General portion guidance when calorie data is unavailable (minors,
  /// pregnancy, incomplete profile).  Uses relative descriptions scaled
  /// by activity level, goal, age, experience and dietary preference
  /// rather than hard-coded food amounts.
  ///
  /// For minors, the guidance is age-appropriate and never restrictive.
  String _generalPortionGuidance(String mealType) {
    final activity = profile.activity;
    final goalLower = profile.goal.toLowerCase();
    final isStrengthGoal =
        goalLower.contains('strength') || goalLower.contains('muscle');
    final isFatLose = goalLower.contains('fat') || goalLower.contains('lose');
    final age = profile.ageInt;
    final experience = profile.experience.toLowerCase();
    final daysPerWeek = int.tryParse(profile.daysPerWeek) ?? 3;
    final diet = profile.dietaryPreference.toLowerCase();
    final isVeg = diet.contains('vegetarian') || diet.contains('vegan');

    // Size modifier from activity level and goal
    String sizeModifier;
    if (activity.factor >= 1.55 || isStrengthGoal) {
      sizeModifier = 'generous';
    } else if (activity.factor >= 1.375) {
      sizeModifier = 'moderate';
    } else {
      sizeModifier = 'modest';
    }

    // Age adjustment: older users may prefer slightly smaller portions
    if (age != null && age >= 60 && sizeModifier == 'generous') {
      sizeModifier = 'moderate';
    }

    // Goal-aware emphasis (safe for minors — never restrictive)
    final String goalNote;
    if (isStrengthGoal) {
      goalNote = 'Supporting your strength and fitness goals.';
    } else if (isFatLose) {
      goalNote = 'Regular balanced meals support your overall goals.';
    } else {
      goalNote = '';
    }

    // Dietary-aware food suggestions
    final String proteinExamples = isVeg
        ? 'protein-rich plant foods like daal, paneer, tofu or nuts'
        : 'protein-containing foods like eggs, daal, chicken or paneer';

    // Experience-aware encouragement
    final String experienceNote = experience.contains('beginner')
        ? 'Start with comfortable portions and adjust gradually.'
        : '';

    // Activity frequency note
    final String activityNote = daysPerWeek >= 4
        ? 'Your regular activity supports balanced nutrition.'
        : '';

    switch (mealType) {
      case 'Breakfast':
        return 'A $sizeModifier breakfast with $proteinExamples, '
            'plus grains and fruit. '
            'Eat until comfortably satisfied.'
            '${goalNote.isNotEmpty ? ' $goalNote' : ''}'
            '${experienceNote.isNotEmpty ? ' $experienceNote' : ''}';
      case 'Lunch':
        return 'A $sizeModifier plate with $proteinExamples, '
            'grains and vegetables. '
            'A satisfying portion.'
            '${activityNote.isNotEmpty ? ' $activityNote' : ''}';
      case 'Snack':
        return 'A small snack with protein or fruit. '
            'Enough to bridge hunger until the next meal.';
      case 'Dinner':
        return 'A $sizeModifier plate with $proteinExamples, '
            'grains and vegetables. '
            'A satisfying but comfortable evening portion.'
            '${goalNote.isNotEmpty ? ' $goalNote' : ''}';
      default:
        return 'A balanced portion adjusted to your hunger and routine.';
    }
  }

  /// Generates a personalized wellness benefit.
  String _personalizedBenefit(String mealType, String context) {
    final goalLower = profile.goal.toLowerCase();
    final activity = profile.activity;

    if (goalLower.contains('strength') || goalLower.contains('muscle')) {
      switch (mealType) {
        case 'Breakfast':
          return 'Supports muscle recovery and morning energy for your $context routine';
        case 'Lunch':
          return 'Sustained protein and energy for afternoon activity and strength development';
        case 'Snack':
          return 'Protein boost to support muscle repair between meals';
        case 'Dinner':
          return 'Overnight recovery nourishment for muscle repair and growth';
        default:
          return 'Supports your strength and fitness goals';
      }
    }

    if (goalLower.contains('fitness') || goalLower.contains('active')) {
      switch (mealType) {
        case 'Breakfast':
          return 'Provides steady energy for your daily activity and $context routine';
        case 'Lunch':
          return 'Sustained energy to support your active lifestyle';
        case 'Snack':
          return 'Light energy boost to maintain activity levels';
        case 'Dinner':
          return 'Recovery nourishment to support your active routine';
        default:
          return 'Supports your overall fitness and wellbeing';
      }
    }

    if (activity.factor >= 1.55) {
      switch (mealType) {
        case 'Breakfast':
          return 'Fuel for your active lifestyle and $context routine';
        case 'Lunch':
          return 'Sustained energy for your active daily schedule';
        case 'Snack':
          return 'Energy bridge between meals for your active routine';
        case 'Dinner':
          return 'Recovery and nourishment for your active lifestyle';
        default:
          return 'Supports your active and balanced lifestyle';
      }
    }

    switch (mealType) {
      case 'Breakfast':
        return 'Provides balanced energy to start your $context routine';
      case 'Lunch':
        return 'Sustained energy and balanced nourishment through the afternoon';
      case 'Snack':
        return 'Light energy boost between meals';
      case 'Dinner':
        return 'Recovery and balanced nourishment for the evening';
      default:
        return 'Supports balanced daily nutrition';
    }
  }

  /// Generates food options personalized to dietary preference and goal.
  List<String> _personalizedFoodOptions(
    String mealType,
    List<String> baseOptions,
  ) {
    final diet = profile.dietaryPreference.toLowerCase();

    // Filter out meat options for vegetarian/vegan preferences
    if (diet.contains('vegetarian') || diet.contains('vegan')) {
      return baseOptions.map((option) {
        // Keep plant-based options, note alternatives for meat items
        if (option.toLowerCase().contains('chicken') ||
            option.toLowerCase().contains('fish')) {
          return _plantBasedAlternative(option);
        }
        return option;
      }).toList();
    }

    return baseOptions;
  }

  String _plantBasedAlternative(String original) {
    final lower = original.toLowerCase();
    if (lower.contains('chicken')) {
      return original.replaceAll(RegExp(r'[Cc]hicken'), 'Paneer/tofu');
    }
    if (lower.contains('fish')) {
      return original.replaceAll(RegExp(r'[Ff]ish'), 'Paneer/tofu/extra daal');
    }
    return original;
  }

  /// Main entry point: generates a complete personalized meal.
  _PersonalizedMeal generate({
    required String mealName,
    required List<String> baseFoodOptions,
    required String context,
    bool restrictCalorieDisplay = false,
    String? workoutContext,
  }) {
    return _PersonalizedMeal(
      mealName: mealName,
      timing: _personalizedTiming(mealName, workoutContext: workoutContext),
      portion: _personalizedPortion(
        mealName,
        restrictCalorieDisplay: restrictCalorieDisplay,
      ),
      foodOptions: _personalizedFoodOptions(mealName, baseFoodOptions),
      benefit: _personalizedBenefit(mealName, context),
    );
  }

  /// Generates a set of meals for a full day.
  List<_PersonalizedMeal> generateDayMeals({
    required List<String> mealNames,
    required Map<String, List<String>> baseFoodOptions,
    required String context,
    bool restrictCalorieDisplay = false,
    String? workoutContext,
  }) {
    return mealNames
        .map(
          (name) => generate(
            mealName: name,
            baseFoodOptions: baseFoodOptions[name] ?? [],
            context: context,
            restrictCalorieDisplay: restrictCalorieDisplay,
            workoutContext: workoutContext,
          ),
        )
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Exercise personalization — reusable across all Women's Wellness screens
  // ─────────────────────────────────────────────────────────────────────

  /// Personalized walking duration range string derived from activity,
  /// experience, workout frequency, age and session duration.
  String personalizedWalkingDuration() {
    final activity = profile.activity;
    final experience = profile.experience.toLowerCase();
    final daysPerWeek = int.tryParse(profile.daysPerWeek) ?? 3;
    final minutesPerSession = int.tryParse(profile.minutesPerSession) ?? 45;
    final age = profile.ageInt;

    final baseMin = activity.factor >= 1.55 ? 15 : 10;
    final addActivity = activity.factor >= 1.725 ? 10 : 0;
    final addFreq = daysPerWeek >= 5 ? 5 : 0;
    final addExp = experience.contains('advanced') ? 5 : 0;
    final addSession = minutesPerSession >= 60 ? 5 : 0;
    final maxMin = baseMin + 10 + addActivity + addFreq + addExp + addSession;

    // Age adjustment: older users get a gentler upper range
    final ageAdj = (age != null && age >= 60) ? 5 : 0;

    return '$baseMin\u2013${maxMin - ageAdj} minutes';
  }

  /// Personalized strength exercise repetition range string derived
  /// from experience, workout frequency, age and goal.
  String personalizedRepRange() {
    final experience = profile.experience.toLowerCase();
    final daysPerWeek = int.tryParse(profile.daysPerWeek) ?? 3;
    final age = profile.ageInt;
    final goalLower = profile.goal.toLowerCase();
    final isStrengthGoal =
        goalLower.contains('strength') || goalLower.contains('muscle');

    String reps;
    if (experience.contains('beginner')) {
      reps = daysPerWeek >= 4 ? '8\u201312' : '6\u201310';
    } else if (experience.contains('intermediate')) {
      reps = '8\u201315';
    } else {
      reps = '10\u201315';
    }

    // Age adjustment: older users get a slightly lower range
    if (age != null && age >= 60) {
      if (experience.contains('beginner')) {
        reps = '5\u20138';
      } else if (experience.contains('intermediate')) {
        reps = '8\u201312';
      } else {
        reps = '8\u201312';
      }
    }

    // Goal emphasis: strength goals favour the upper rep descriptor
    if (isStrengthGoal && !experience.contains('beginner')) {
      reps = '$reps (focus on controlled form)';
    }

    return '$reps repetitions';
  }

  /// Personalized mobility session duration range string derived from
  /// activity level, experience, age and session duration.
  String personalizedMobilityDuration() {
    final activity = profile.activity;
    final experience = profile.experience.toLowerCase();
    final age = profile.ageInt;
    final minutesPerSession = int.tryParse(profile.minutesPerSession) ?? 45;

    final base = activity.factor >= 1.55 ? 8 : 5;
    final add = (activity.factor >= 1.725 ||
            experience.contains('advanced'))
        ? 5
        : 0;
    // Longer sessions suggest more mobility warm-up time
    final addSession = minutesPerSession >= 60 ? 3 : 0;
    final max = base + 5 + add + addSession;

    // Age adjustment: older users benefit from slightly longer mobility
    final ageAdj = (age != null && age >= 55) ? 3 : 0;

    return '${base + ageAdj}\u2013${max + ageAdj} minutes';
  }

  /// Personalized recovery guidance string derived from workout frequency,
  /// experience and age.
  String personalizedRecoveryGuidance() {
    final daysPerWeek = int.tryParse(profile.daysPerWeek) ?? 3;
    final experience = profile.experience.toLowerCase();
    final age = profile.ageInt;

    if (daysPerWeek >= 5) {
      return 'Include at least 1\u20132 lighter days per week for recovery.';
    } else if (daysPerWeek >= 3) {
      if (age != null && age >= 55) {
        return 'Balance activity days with rest or gentle movement days. '
            'Allow extra recovery time as needed.';
      }
      if (experience.contains('beginner')) {
        return 'Balance activity days with rest or gentle movement days. '
            'Progress gradually and allow recovery between sessions.';
      }
      return 'Balance activity days with rest or gentle movement days.';
    }
    return 'Add rest days as needed and respond to your energy levels.';
  }

  /// Equipment-aware exercise suggestion suffix derived from the user's
  /// saved equipment availability.
  String personalizedEquipmentNote() {
    final equip = profile.equipment.toLowerCase();
    if (equip.contains('gym')) {
      return 'Your gym equipment can be incorporated into these activities.';
    }
    if (equip.contains('home')) {
      return 'These activities suit a home setting with basic equipment.';
    }
    if (equip.contains('outdoor')) {
      return 'These activities can be done outdoors where comfortable.';
    }
    return 'No equipment is needed for these activities.';
  }
}

class _WellnessSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _WellnessSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _WellnessProfileCard extends StatelessWidget {
  final _WellnessProfile profile;

  const _WellnessProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  L.t('personalizedForProfile'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            profile.profileSummary,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            profile.goalGuidance,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable meal detail card for Women's Wellness nutrition sections
// ─────────────────────────────────────────────────────────────────────────────
class _MealDetailCard extends StatelessWidget {
  final _PersonalizedMeal meal;

  const _MealDetailCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Meal name ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.restaurant_outlined, size: 20,
                    color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    meal.mealName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Timing ──
                _buildLabeledSection(
                  icon: Icons.schedule_outlined,
                  label: L.t('timing'),
                  child: Text(
                    meal.timing,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  colorScheme: colorScheme,
                ),
                const Divider(height: 24),

                // ── Portion / Quantity ──
                _buildLabeledSection(
                  icon: Icons.portrait_outlined,
                  label: L.t('portionQuantity'),
                  child: Text(
                    meal.portion,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  colorScheme: colorScheme,
                ),
                const Divider(height: 24),

                // ── Food Options ──
                _buildLabeledSection(
                  icon: Icons.restaurant_menu_outlined,
                  label: L.t('foodOptions'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: meal.foodOptions.map((food) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline, size: 15,
                                color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                food,
                                style: const TextStyle(
                                    fontSize: 14, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  colorScheme: colorScheme,
                ),
                const Divider(height: 24),

                // ── Why It Helps ──
                _buildLabeledSection(
                  icon: Icons.favorite_outline,
                  label: L.t('whyItHelps'),
                  child: Text(
                    meal.benefit,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renders a clearly visible labeled section: [icon] [LABEL] on top, value below.
  Widget _buildLabeledSection({
    required IconData icon,
    required String label,
    required Widget child,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: child,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable exercise video card for Women's Wellness activity sections
// ─────────────────────────────────────────────────────────────────────────────
class _ExerciseVideoCard extends StatelessWidget {
  final String exerciseName;
  final String durationOrReps;
  final String instructions;
  final String? benefit;

  const _ExerciseVideoCard({
    required this.exerciseName,
    required this.durationOrReps,
    required this.instructions,
    this.benefit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fitness_center_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exerciseName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        durationOrReps,
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Watch exercise video',
                  icon: Icon(
                    Icons.play_circle_outline,
                    size: 28,
                    color: colorScheme.primary,
                  ),
                  onPressed: () async {
                    final query = Uri.encodeComponent(
                      '$exerciseName exercise tutorial',
                    );
                    final uri = Uri.parse(
                      'https://www.youtube.com/results?search_query=$query',
                    );
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              instructions,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            if (benefit != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.favorite_outline,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        benefit!,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CycleAwareNutritionScreen extends StatefulWidget {
  const CycleAwareNutritionScreen({super.key});

  @override
  State<CycleAwareNutritionScreen> createState() =>
      _CycleAwareNutritionScreenState();
}

class _CycleAwareNutritionScreenState extends State<CycleAwareNutritionScreen> {
  _WellnessProfile? profile;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final loaded = await _WellnessProfile.load();
    final userLoaded = await UserProfileService.instance.load();

    if (!mounted) return;

    setState(() {
      profile = loaded;
      _userProfile = userLoaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = profile;
    final userProfile = _userProfile;

    if (currentProfile == null || userProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final personalizer = _MealPersonalizer(userProfile);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          L.t('cycleAwareNutrition'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Nutrition by Cycle Phase',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'FitAI adapts meal guidance to the selected cycle phase while keeping nutrition flexible and balanced.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 18),

          _WellnessProfileCard(profile: currentProfile),

          const _WellnessSection(
            title: '🌧️ Menstrual Phase',
            icon: Icons.water_drop_outlined,
            items: [
              'Breakfast — Eggs with whole-grain toast and fruit, OR oats prepared with milk/yogurt, banana and nuts.',
              'Lunch — Daal with roti and cooked vegetables, OR chicken with rice and vegetables.',
              'Snack — Yogurt with fruit, OR roasted chana with fruit.',
              'Dinner — Daal/chickpeas with roti and vegetables, OR chicken/fish with rice and vegetables.',
              'Preparation — Prefer home-cooked meals, moderate oil and normal seasoning according to preference.',
              'Timing — Eat at regular times that fit your routine. A snack can be added when genuinely hungry.',
              'Focus — Iron-containing foods, protein-containing foods, fruits, vegetables and regular fluids.',
            ],
          ),

          const Text(
            'Menstrual Phase Meal Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Breakfast',
              baseFoodOptions: [
                'Eggs with whole-grain toast and fruit',
                'Oats prepared with milk/yogurt, banana and nuts',
              ],
              context: 'menstrual phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Lunch',
              baseFoodOptions: [
                'Daal with roti and cooked vegetables',
                'Chicken with rice and vegetables',
              ],
              context: 'menstrual phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Snack',
              baseFoodOptions: [
                'Yogurt with fruit',
                'Roasted chana with fruit',
              ],
              context: 'menstrual phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Dinner',
              baseFoodOptions: [
                'Daal/chickpeas with roti and vegetables',
                'Chicken/fish with rice and vegetables',
              ],
              context: 'menstrual phase',
            ),
          ),

          const _WellnessSection(
            title: '🌱 Follicular Phase',
            icon: Icons.spa_outlined,
            items: [
              'Breakfast — Oats with milk/yogurt, fruit and nuts, OR eggs with whole-grain toast and fruit.',
              'Lunch — Chicken/fish with rice and vegetables, OR chickpeas/daal with roti and salad.',
              'Snack — Yogurt and fruit, OR roasted chana.',
              'Dinner — Protein-containing food with roti/rice and vegetables.',
              'Preparation — Use grilling, baking, steaming or normal home cooking according to preference.',
              'Focus — Variety and regular balanced meals.',
            ],
          ),

          const Text(
            'Follicular Phase Meal Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Breakfast',
              baseFoodOptions: [
                'Oats with milk/yogurt, fruit and nuts',
                'Eggs with whole-grain toast and fruit',
              ],
              context: 'follicular phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Lunch',
              baseFoodOptions: [
                'Chicken/fish with rice and vegetables',
                'Chickpeas/daal with roti and salad',
              ],
              context: 'follicular phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Snack',
              baseFoodOptions: [
                'Yogurt and fruit',
                'Roasted chana',
              ],
              context: 'follicular phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Dinner',
              baseFoodOptions: [
                'Protein-containing food with roti/rice and vegetables',
              ],
              context: 'follicular phase',
            ),
          ),

          const _WellnessSection(
            title: '💗 Ovulatory Phase',
            icon: Icons.favorite_outline,
            items: [
              'Breakfast — Eggs, whole-grain toast, yogurt and fruit.',
              'Lunch — Chicken/fish with rice and vegetables, OR daal/chickpeas with roti and vegetables.',
              'Snack — Fruit with nuts, OR yogurt.',
              'Dinner — Daal/chickpeas with roti and vegetables, OR another protein-containing meal.',
              'Focus — Variety, vegetables, fruit, protein-containing foods and regular fluids.',
              'Do not skip meals simply because of the cycle phase.',
            ],
          ),

          const Text(
            'Ovulatory Phase Meal Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Breakfast',
              baseFoodOptions: [
                'Eggs, whole-grain toast, yogurt and fruit',
              ],
              context: 'ovulatory phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Lunch',
              baseFoodOptions: [
                'Chicken/fish with rice and vegetables',
                'Daal/chickpeas with roti and vegetables',
              ],
              context: 'ovulatory phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Snack',
              baseFoodOptions: [
                'Fruit with nuts',
                'Yogurt',
              ],
              context: 'ovulatory phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Dinner',
              baseFoodOptions: [
                'Daal/chickpeas with roti and vegetables',
                'Another protein-containing meal',
              ],
              context: 'ovulatory phase',
            ),
          ),

          const _WellnessSection(
            title: '🌙 Luteal Phase',
            icon: Icons.nightlight_outlined,
            items: [
              'Breakfast — Oats with milk/yogurt, banana and nuts, OR eggs with toast and fruit.',
              'Lunch — Chicken with roti and vegetables, OR daal/chickpeas with rice and vegetables.',
              'Snack — Yogurt and fruit, OR roasted chana.',
              'Dinner — Daal with roti and vegetables, OR chicken/fish with rice and vegetables.',
              'Preparation — Choose satisfying balanced meals rather than restrictive eating.',
              'Focus — Regular meals and foods containing protein, complex carbohydrates, vegetables and fruit.',
            ],
          ),

          const Text(
            'Luteal Phase Meal Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Breakfast',
              baseFoodOptions: [
                'Oats with milk/yogurt, banana and nuts',
                'Eggs with toast and fruit',
              ],
              context: 'luteal phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Lunch',
              baseFoodOptions: [
                'Chicken with roti and vegetables',
                'Daal/chickpeas with rice and vegetables',
              ],
              context: 'luteal phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Snack',
              baseFoodOptions: [
                'Yogurt and fruit',
                'Roasted chana',
              ],
              context: 'luteal phase',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Dinner',
              baseFoodOptions: [
                'Daal with roti and vegetables',
                'Chicken/fish with rice and vegetables',
              ],
              context: 'luteal phase',
            ),
          ),

          const _WellnessSection(
            title: '💧 Hydration',
            icon: Icons.local_drink_outlined,
            items: [
              'Drink water regularly throughout the day.',
              'Drink more when exercising or sweating.',
              'Use thirst, activity and weather as practical guides.',
              'FitAI should provide reminders rather than forcing one fixed amount for everyone.',
            ],
          ),

          _WellnessSection(
            title: '🕐 Meal Timing',
            icon: Icons.schedule_outlined,
            items: [
              'Breakfast — ${personalizer.generate(mealName: 'Breakfast', baseFoodOptions: [], context: 'daily').timing}',
              'Lunch — ${personalizer.generate(mealName: 'Lunch', baseFoodOptions: [], context: 'daily').timing}',
              'Snack — ${personalizer.generate(mealName: 'Snack', baseFoodOptions: [], context: 'daily').timing}',
              'Dinner — ${personalizer.generate(mealName: 'Dinner', baseFoodOptions: [], context: 'daily').timing}',
              'Before exercise — A small familiar snack can be useful if hungry.',
              'After exercise — A normal balanced meal or snack can support recovery.',
            ],
          ),

          const _WellnessNote(
            text:
                'FitAI uses profile information to personalize general wellness guidance. It does not calculate restrictive diets, diagnose conditions or replace professional nutrition advice.',
          ),
        ],
      ),
    );
  }
}

class PcosSupportScreen extends StatefulWidget {
  const PcosSupportScreen({super.key});

  @override
  State<PcosSupportScreen> createState() => _PcosSupportScreenState();
}

class _PcosSupportScreenState extends State<PcosSupportScreen> {
  _WellnessProfile? profile;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final loaded = await _WellnessProfile.load();
    final userLoaded = await UserProfileService.instance.load();

    if (!mounted) return;

    setState(() {
      profile = loaded;
      _userProfile = userLoaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = profile;
    final userProfile = _userProfile;

    if (currentProfile == null || userProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final personalizer = _MealPersonalizer(userProfile);
    final walkDuration = personalizer.personalizedWalkingDuration();
    final repRange = personalizer.personalizedRepRange();
    final mobilityDuration = personalizer.personalizedMobilityDuration();
    final recoveryGuidance = personalizer.personalizedRecoveryGuidance();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          L.t('pcosSupport'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'PCOS Wellness Support',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Movement, balanced nutrition, recovery and personalization guidance.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 18),

          _WellnessProfileCard(profile: currentProfile),

          _WellnessSection(
            title: '🚶 Easy Walking',
            icon: Icons.directions_walk_outlined,
            items: [
              'Start with a comfortable short walk.',
              'Suggested session — $walkDuration based on your profile.',
              'Walk at a comfortable pace where you can still talk.',
              'Increase duration gradually when comfortable.',
              'Take breaks whenever needed.',
            ],
          ),

          const Text(
            'Walking Activities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _ExerciseVideoCard(
            exerciseName: 'Comfortable Walking',
            durationOrReps: walkDuration,
            instructions:
                'Walk at a comfortable pace where you can still hold a conversation. Start with a shorter duration and increase gradually.',
            benefit: 'Supports cardiovascular health and mood balance',
          ),

          _ExerciseVideoCard(
            exerciseName: 'Brisk Walking',
            durationOrReps: walkDuration,
            instructions:
                'Walk at a slightly faster pace while maintaining good posture. Keep arms relaxed at your sides.',
            benefit: 'Helps manage energy levels and supports metabolic health',
          ),

          _WellnessSection(
            title: '🏋️ Beginner Strength',
            icon: Icons.fitness_center_outlined,
            items: [
              'Supported squat — Sit toward a chair and stand back up with controlled movement.',
              'Wall push-up — Place hands on a wall, bend elbows gently and push back.',
              'Glute bridge — Lie comfortably, bend knees and gently lift hips.',
              'Suggested reps — $repRange based on your experience level.',
              'Technique — Prioritize controlled movement rather than maximum repetitions or resistance.',
              'Progress — Increase gradually based on comfort and experience.',
            ],
          ),

          const Text(
            'Strength Activities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _ExerciseVideoCard(
            exerciseName: 'Supported Squat',
            durationOrReps: repRange,
            instructions:
                'Stand with feet shoulder-width apart. Slowly bend knees and hips, keeping chest upright. Push through feet to return to standing.',
            benefit: 'Builds lower-body strength and supports metabolic health',
          ),

          _ExerciseVideoCard(
            exerciseName: 'Wall Push-Up',
            durationOrReps: repRange,
            instructions:
                'Stand facing a wall. Place hands on wall at shoulder height. Bend elbows and move toward wall, then push back to start.',
            benefit: 'Develops upper-body strength with controlled movement',
          ),

          _ExerciseVideoCard(
            exerciseName: 'Glute Bridge',
            durationOrReps: repRange,
            instructions:
                'Lie on your back with knees bent and feet flat. Lift hips slowly while keeping movement controlled. Lower gently and repeat.',
            benefit: 'Strengthens glutes and lower-body muscles',
          ),

          _WellnessSection(
            title: '🧘 Mobility',
            icon: Icons.self_improvement_outlined,
            items: [
              'Shoulder rolls — Slow controlled circles.',
              'Hip mobility — Small comfortable movements.',
              'Ankle circles — Gentle circles on each side.',
              'Gentle stretching — Move only within a comfortable range.',
              'Suggested session — $mobilityDuration based on your profile.',
              'Never force painful movement.',
            ],
          ),

          const Text(
            'Mobility Activities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _ExerciseVideoCard(
            exerciseName: 'Shoulder Rolls',
            durationOrReps: repRange,
            instructions:
                'Roll shoulders forward and backward in slow controlled circles. Keep movements comfortable and relaxed.',
            benefit: 'Releases upper-body tension and improves posture',
          ),

          _ExerciseVideoCard(
            exerciseName: 'Hip Circles',
            durationOrReps: repRange,
            instructions:
                'Stand with hands on hips. Make small comfortable circles with your hips. Reverse direction after completing repetitions.',
            benefit: 'Improves hip mobility and lower-body flexibility',
          ),

          _ExerciseVideoCard(
            exerciseName: 'Gentle Stretching',
            durationOrReps: mobilityDuration,
            instructions:
                'Move through gentle full-body stretches. Hold each stretch comfortably without forcing. Breathe normally throughout.',
            benefit: 'Supports flexibility and recovery',
          ),

          const _WellnessSection(
            title: '🍽️ Balanced Meals',
            icon: Icons.restaurant_outlined,
            items: [
              'Breakfast — Eggs + whole-grain toast + fruit, OR oats + milk/yogurt + fruit + nuts.',
              'Lunch — Daal/chickpeas + roti + vegetables, OR chicken/fish + rice + vegetables.',
              'Snack — Yogurt + fruit, OR roasted chana + fruit.',
              'Dinner — Protein-containing food + roti/rice + vegetables.',
              'Preparation — Prefer balanced home-cooked meals and avoid unnecessary restriction.',
              'FitAI should adapt food choices to allergies, preferences and available foods.',
            ],
          ),

          const Text(
            'Meal Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Breakfast',
              baseFoodOptions: [
                'Eggs + whole-grain toast + fruit',
                'Oats + milk/yogurt + fruit + nuts',
              ],
              context: 'PCOS support',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Lunch',
              baseFoodOptions: [
                'Daal/chickpeas + roti + vegetables',
                'Chicken/fish + rice + vegetables',
              ],
              context: 'PCOS support',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Snack',
              baseFoodOptions: [
                'Yogurt + fruit',
                'Roasted chana + fruit',
              ],
              context: 'PCOS support',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Dinner',
              baseFoodOptions: [
                'Protein-containing food + roti/rice + vegetables',
              ],
              context: 'PCOS support',
            ),
          ),

          _WellnessSection(
            title: '😴 Recovery',
            icon: Icons.bedtime_outlined,
            items: [
              'Keep a consistent sleep/wake routine when possible.',
              'Use easier activity days when energy is lower.',
              recoveryGuidance,
              'Drink fluids regularly.',
              'Track general energy and recovery rather than forcing a fixed training target.',
            ],
          ),

          const _WellnessSection(
            title: '🎯 Personalization',
            icon: Icons.tune_outlined,
            items: [
              'Profile — FitAI reads the saved age, height, weight and fitness goal.',
              'Activity — Select beginner, intermediate or experienced level.',
              'Time — Select a realistic available workout duration.',
              'Location — Home or gym.',
              'Equipment — None, basic equipment or gym equipment.',
              'Energy — Low, medium or good.',
              'Preference — Walking, strength, mobility or mixed activity.',
              'FitAI can use these choices to select suitable general routines.',
            ],
          ),

          const _WellnessNote(
            text:
                'PCOS is a medical condition. FitAI provides general wellness information and does not diagnose or treat PCOS.',
          ),
        ],
      ),
    );
  }
}

class PregnancyScreen extends StatefulWidget {
  const PregnancyScreen({super.key});

  @override
  State<PregnancyScreen> createState() => _PregnancyScreenState();
}

class _PregnancyScreenState extends State<PregnancyScreen> {
  _WellnessProfile? profile;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final loaded = await _WellnessProfile.load();
    final userLoaded = await UserProfileService.instance.load();

    if (!mounted) return;

    setState(() {
      profile = loaded;
      _userProfile = userLoaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = profile;
    final userProfile = _userProfile;

    if (currentProfile == null || userProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final personalizer = _MealPersonalizer(userProfile);
    final walkDuration = personalizer.personalizedWalkingDuration();
    final mobilityDuration = personalizer.personalizedMobilityDuration();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          L.t('pregnancy'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Pregnancy Wellness',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stage-aware wellness guidance with safety as the first priority.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 18),

          _WellnessProfileCard(profile: currentProfile),

          const _WellnessSection(
            title: '🤰 Pregnancy',
            icon: Icons.pregnant_woman_outlined,
            items: [
              'FitAI should first ask for pregnancy stage and whether activity has been cleared as appropriate.',
              'Exercise selection should be individualized.',
              'Comfortable movement may be appropriate for some people, but pregnancy circumstances vary.',
              'Do not use FitAI as a replacement for prenatal care.',
              'Do not use calorie restriction or weight-loss targets during pregnancy.',
            ],
          ),

          _WellnessSection(
            title: '🚶 Gentle Movement',
            icon: Icons.directions_walk_outlined,
            items: [
              'Comfortable walking can be considered when activity is appropriate.',
              'Suggested walking — $walkDuration based on your profile.',
              'Take breaks whenever needed.',
              'Gentle mobility — $mobilityDuration when appropriate.',
              'Avoid movements that cause pain or concerning symptoms.',
            ],
          ),

          const Text(
            'Gentle Movement Activities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _ExerciseVideoCard(
            exerciseName: 'Prenatal Walking',
            durationOrReps: walkDuration,
            instructions:
                'Walk at a comfortable pace on flat ground. Maintain good posture and take breaks as needed. Stay hydrated.',
            benefit: 'Supports cardiovascular health and mood during pregnancy',
          ),

          _ExerciseVideoCard(
            exerciseName: 'Prenatal Mobility',
            durationOrReps: mobilityDuration,
            instructions:
                'Perform gentle shoulder rolls, ankle circles, and comfortable stretches. Avoid movements that cause discomfort.',
            benefit: 'Maintains flexibility and reduces tension',
          ),

          const _WellnessSection(
            title: '🍽️ Balanced Nutrition',
            icon: Icons.restaurant_outlined,
            items: [
              'Protein foods — Eggs, yogurt, lentils, beans, chicken or fish as suitable.',
              'Carbohydrates — Roti, rice, oats or other grains.',
              'Vegetables — Include a variety of vegetables.',
              'Fruit — Include fruit as part of normal meals/snacks.',
              'Dairy/alternative — Use suitable options according to preference and tolerance.',
              'Fluids — Drink regularly.',
              'FitAI should not prescribe calorie restriction during pregnancy.',
            ],
          ),

          const Text(
            'Nutrition Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Breakfast',
              baseFoodOptions: [
                'Eggs + whole-grain toast + fruit',
                'Oats + milk/yogurt + fruit + nuts',
              ],
              context: 'pregnancy',
              restrictCalorieDisplay: true,
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Lunch',
              baseFoodOptions: [
                'Daal/chickpeas + roti + vegetables',
                'Chicken/fish + rice + vegetables',
              ],
              context: 'pregnancy',
              restrictCalorieDisplay: true,
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Snack',
              baseFoodOptions: [
                'Yogurt + fruit',
                'Roasted chana + fruit',
              ],
              context: 'pregnancy',
              restrictCalorieDisplay: true,
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Dinner',
              baseFoodOptions: [
                'Protein-containing food + roti/rice + vegetables',
              ],
              context: 'pregnancy',
              restrictCalorieDisplay: true,
            ),
          ),

          const _WellnessNote(
            text:
                'Pregnancy activity and nutrition should be individualized with appropriate professional guidance.',
          ),
        ],
      ),
    );
  }
}

class PostpartumScreen extends StatefulWidget {
  const PostpartumScreen({super.key});

  @override
  State<PostpartumScreen> createState() => _PostpartumScreenState();
}

class _PostpartumScreenState extends State<PostpartumScreen> {
  _WellnessProfile? profile;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final loaded = await _WellnessProfile.load();
    final userLoaded = await UserProfileService.instance.load();

    if (!mounted) return;

    setState(() {
      profile = loaded;
      _userProfile = userLoaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = profile;
    final userProfile = _userProfile;

    if (currentProfile == null || userProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final personalizer = _MealPersonalizer(userProfile);
    final walkDuration = personalizer.personalizedWalkingDuration();
    final mobilityDuration = personalizer.personalizedMobilityDuration();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          L.t('postpartum'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Postpartum Recovery',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recovery-focused guidance for your postpartum journey.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 18),

          _WellnessProfileCard(profile: currentProfile),

          const _WellnessSection(
            title: '🌷 Postpartum Recovery',
            icon: Icons.healing_outlined,
            items: [
              'Recovery comes first.',
              'Return to activity gradually and according to professional guidance.',
              'Walking — Start with comfortable short periods when appropriate.',
              'Mobility — Gentle movement can be considered when appropriate.',
              'Strength — Progress gradually rather than immediately returning to previous training.',
              'Rest — Include recovery periods and respond to energy and comfort.',
            ],
          ),

          const Text(
            'Postpartum Recovery Activities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _ExerciseVideoCard(
            exerciseName: 'Postpartum Walking',
            durationOrReps: walkDuration,
            instructions:
                'Start with comfortable short walks. Increase duration gradually as recovery progresses. Listen to your body.',
            benefit: 'Supports gentle return to activity and mood balance',
          ),

          _ExerciseVideoCard(
            exerciseName: 'Postpartum Mobility',
            durationOrReps: mobilityDuration,
            instructions:
                'Perform gentle stretches and mobility exercises. Focus on comfortable range of motion. Avoid forcing movements.',
            benefit: 'Helps restore flexibility and reduce tension',
          ),

          const _WellnessSection(
            title: '💗 Body Signals',
            icon: Icons.favorite_outline,
            items: [
              'Do not force painful movements.',
              'Stop an activity if something feels unsafe or concerning.',
              'For complications, surgery, symptoms or individual medical decisions, seek professional advice.',
            ],
          ),

          const _WellnessNote(
            text:
                'Postpartum activity and nutrition should be individualized with appropriate professional guidance.',
          ),
        ],
      ),
    );
  }
}

class HormonalWellnessScreen extends StatefulWidget {
  const HormonalWellnessScreen({super.key});

  @override
  State<HormonalWellnessScreen> createState() => _HormonalWellnessScreenState();
}

class _HormonalWellnessScreenState extends State<HormonalWellnessScreen> {
  _WellnessProfile? profile;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final loaded = await _WellnessProfile.load();
    final userLoaded = await UserProfileService.instance.load();

    if (!mounted) return;

    setState(() {
      profile = loaded;
      _userProfile = userLoaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = profile;
    final userProfile = _userProfile;

    if (currentProfile == null || userProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final personalizer = _MealPersonalizer(userProfile);
    final walkDuration = personalizer.personalizedWalkingDuration();
    final repRange = personalizer.personalizedRepRange();
    final mobilityDuration = personalizer.personalizedMobilityDuration();
    final recoveryGuidance = personalizer.personalizedRecoveryGuidance();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          L.t('hormonalWellness'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Everyday Hormonal Wellness',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'A personalized wellness layer for movement, meals, recovery and daily tracking.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 18),

          _WellnessProfileCard(profile: currentProfile),

          _WellnessSection(
            title: '🏃 Movement',
            icon: Icons.fitness_center_outlined,
            items: [
              'Walking — $walkDuration based on your profile.',
              'Mobility — $mobilityDuration of gentle movement.',
              'Supported squat — $repRange.',
              'Wall push-up — $repRange.',
              'Glute bridge — $repRange.',
              'Choose intensity according to your experience and energy.',
            ],
          ),

          const Text(
            'Movement Activities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _ExerciseVideoCard(
            exerciseName: 'Comfortable Walking',
            durationOrReps: walkDuration,
            instructions:
                'Walk at a comfortable pace. Maintain relaxed posture and breathe naturally. Adjust intensity based on energy levels.',
            benefit: 'Supports cardiovascular health and daily energy',
          ),

          _ExerciseVideoCard(
            exerciseName: 'Gentle Mobility',
            durationOrReps: mobilityDuration,
            instructions:
                'Perform comfortable shoulder rolls, hip circles, and ankle circles. Move within a comfortable range without forcing.',
            benefit: 'Maintains flexibility and reduces stiffness',
          ),

          _ExerciseVideoCard(
            exerciseName: 'Supported Squat',
            durationOrReps: repRange,
            instructions:
                'Stand with feet shoulder-width apart. Slowly bend knees and hips while keeping chest upright. Return to standing with control.',
            benefit: 'Builds lower-body strength and stability',
          ),

          _ExerciseVideoCard(
            exerciseName: 'Wall Push-Up',
            durationOrReps: repRange,
            instructions:
                'Stand facing a wall. Place hands on wall and bend elbows toward it. Push back to starting position with control.',
            benefit: 'Develops upper-body strength',
          ),

          _ExerciseVideoCard(
            exerciseName: 'Glute Bridge',
            durationOrReps: repRange,
            instructions:
                'Lie on your back with knees bent. Lift hips slowly while keeping movement controlled. Lower gently and repeat.',
            benefit: 'Strengthens glutes and core muscles',
          ),

          const _WellnessSection(
            title: '🍽️ Balanced Eating',
            icon: Icons.restaurant_outlined,
            items: [
              'Breakfast — Eggs + toast + fruit, OR oats + milk/yogurt + fruit + nuts.',
              'Lunch — Daal/chickpeas + roti + vegetables, OR chicken/fish + rice + vegetables.',
              'Snack — Yogurt + fruit, OR roasted chana.',
              'Dinner — Protein-containing food + roti/rice + vegetables.',
              'Hydration — Drink regularly throughout the day.',
              'FitAI should avoid restrictive meal prescriptions based only on body measurements.',
            ],
          ),

          const Text(
            'Meal Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Breakfast',
              baseFoodOptions: [
                'Eggs + toast + fruit',
                'Oats + milk/yogurt + fruit + nuts',
              ],
              context: 'hormonal wellness',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Lunch',
              baseFoodOptions: [
                'Daal/chickpeas + roti + vegetables',
                'Chicken/fish + rice + vegetables',
              ],
              context: 'hormonal wellness',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Snack',
              baseFoodOptions: [
                'Yogurt + fruit',
                'Roasted chana',
              ],
              context: 'hormonal wellness',
            ),
          ),

          _MealDetailCard(
            meal: personalizer.generate(
              mealName: 'Dinner',
              baseFoodOptions: [
                'Protein-containing food + roti/rice + vegetables',
              ],
              context: 'hormonal wellness',
            ),
          ),

          _WellnessSection(
            title: '😴 Sleep & Recovery',
            icon: Icons.bedtime_outlined,
            items: [
              'Keep a consistent sleep/wake routine when possible.',
              'Create a calm wind-down period before sleep.',
              recoveryGuidance,
              'Gentle walking or mobility can be used for recovery when comfortable.',
              'Track recovery trends instead of chasing perfect numbers.',
            ],
          ),

          const _WellnessSection(
            title: '😊 Daily Wellbeing',
            icon: Icons.mood_outlined,
            items: [
              'Energy — Low, medium or good.',
              'Sleep quality — Record how rested you feel.',
              'Mood — Record general mood.',
              'Movement — Track activity completed.',
              'Hydration — Track general fluid habits.',
              'Use patterns as wellness information, not as a diagnosis.',
            ],
          ),

          const _WellnessSection(
            title: '🎯 Personalization',
            icon: Icons.tune_outlined,
            items: [
              'Profile — Age, height, weight and goal are read from the saved profile.',
              'Time — Choose the time available for activity.',
              'Experience — Beginner, intermediate or experienced.',
              'Location — Home or gym.',
              'Equipment — None, basic or gym equipment.',
              'Energy — Low, medium or good.',
              'Activity preference — Walking, strength, mobility or mixed.',
            ],
          ),

          const _WellnessNote(
            text:
                'Hormonal health is individual. FitAI provides general wellness information and does not diagnose hormonal disorders.',
          ),
        ],
      ),
    );
  }
}

class WomensSafetyModeScreen extends StatefulWidget {
  const WomensSafetyModeScreen({super.key});

  @override
  State<WomensSafetyModeScreen> createState() => _WomensSafetyModeScreenState();
}

class _WomensSafetyModeScreenState extends State<WomensSafetyModeScreen> {
  bool workoutCheckIn = false;
  bool awarenessReminder = true;
  bool lowDistraction = false;

  Future<void> _toggleCheckIn(bool value) async {
    setState(() {
      workoutCheckIn = value;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? L.t('checkInEnabled') : L.t('checkInDisabled'),
        ),
      ),
    );
  }

  void _quickExit() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _showSafetyInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.t('safetyMode')),
        content: Text(L.t('safetyModeDetail')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          L.t('safetyMode'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _showSafetyInfo,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.health_and_safety_outlined, size: 38),
                SizedBox(height: 12),
                Text(
                  'Safety First',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Safety-focused controls and reminders for workouts at home, in a gym or outdoors.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const _WellnessSection(
            title: '📍 Safe Workout Location',
            icon: Icons.location_on_outlined,
            items: [
              'Prefer familiar and well-lit places.',
              'Choose environments where help is available if needed.',
              'For outdoor activity, consider telling a trusted person your general plan.',
              'At home, keep the workout space clear.',
            ],
          ),

          const _WellnessSection(
            title: '👤 Trusted Contact',
            icon: Icons.person_outline,
            items: [
              'FitAI should allow the user to choose a trusted contact.',
              'Contact information must remain private.',
              'Any contact sharing should require explicit user permission.',
              'Do not automatically expose contact information.',
            ],
          ),

          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: SwitchListTile(
              secondary: const Icon(Icons.check_circle_outline),
              title: const Text(
                'Workout Check-In',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Mark the beginning and completion of a workout.',
              ),
              value: workoutCheckIn,
              onChanged: _toggleCheckIn,
            ),
          ),

          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: SwitchListTile(
              secondary: const Icon(Icons.visibility_outlined),
              title: const Text(
                'Awareness Reminder',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Keep awareness reminders available during outdoor activity.',
              ),
              value: awarenessReminder,
              onChanged: (value) {
                setState(() {
                  awarenessReminder = value;
                });
              },
            ),
          ),

          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: SwitchListTile(
              secondary: const Icon(Icons.do_not_disturb_on_outlined),
              title: const Text(
                'Low-Distraction Mode',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Reduce unnecessary app distractions during a workout.',
              ),
              value: lowDistraction,
              onChanged: (value) {
                setState(() {
                  lowDistraction = value;
                });
              },
            ),
          ),

          Container(
            margin: const EdgeInsets.only(bottom: 14),
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _quickExit,
              icon: const Icon(Icons.exit_to_app_outlined),
              label: const Text('Quick Exit Workout'),
            ),
          ),

          const _WellnessSection(
            title: '🔊 Awareness',
            icon: Icons.volume_up_outlined,
            items: [
              'Stay aware of your surroundings during outdoor activity.',
              'Avoid audio settings that prevent awareness of nearby surroundings.',
              'Keep important calls and emergency notifications available.',
            ],
          ),

          const _WellnessSection(
            title: '🆘 Emergency Help',
            icon: Icons.emergency_outlined,
            items: [
              'If you feel unsafe, stop the activity and move toward a safer place when possible.',
              'Contact a trusted person when appropriate.',
              'Use the appropriate local emergency service during an actual emergency.',
              'FitAI should never claim to replace emergency services.',
            ],
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Safety Mode provides supportive controls and reminders. '
              'It cannot guarantee personal safety or replace local emergency services.',
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WellnessNote extends StatelessWidget {
  final String text;

  const _WellnessNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, height: 1.5)),
    );
  }
}

class ExerciseHowToScreen extends StatelessWidget {
  final String exerciseName;
  final Map<String, dynamic> details;

  const ExerciseHowToScreen({
    super.key,
    required this.exerciseName,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final steps = List<String>.from(details['steps'] ?? const <String>[]);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          exerciseName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 38,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    exerciseName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How to do this exercise',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SizedBox(height: 28),

            const Text(
              'Steps',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            if (details['tip'] != null) ...[
              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        details['tip'].toString(),
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Use comfortable movement and focus on controlled '
                      'technique. Stop if an exercise causes pain or feels unsafe.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class CycleAwareFitnessScreen extends StatefulWidget {
  const CycleAwareFitnessScreen({super.key});

  @override
  State<CycleAwareFitnessScreen> createState() =>
      _CycleAwareFitnessScreenState();
}

class _CycleAwareFitnessScreenState extends State<CycleAwareFitnessScreen> {
  String selectedPhase = 'Menstrual';

  final Map<String, Map<String, dynamic>> phaseGuidance = {
    'Menstrual': {
      'intensity': 'Low to moderate',
      'focus': 'Recovery, mobility and comfortable movement',
      'tip':
          'Choose comfortable movement and adjust intensity according to how you feel.',
      'workouts': [
        'Gentle Walking',
        'Mobility & Stretching',
        'Light Bodyweight Workout',
      ],
    },
    'Follicular': {
      'intensity': 'Moderate to high',
      'focus': 'Strength, cardio and skill-building',
      'tip':
          'If your energy feels good, gradually increase training intensity.',
      'workouts': ['Strength Training', 'Moderate Cardio', 'Full-Body Workout'],
    },
    'Ovulatory': {
      'intensity': 'Moderate to high',
      'focus': 'Strength, cardio and performance',
      'tip': 'Prioritize good technique, controlled movement and recovery.',
      'workouts': [
        'Strength Workout',
        'Cardio Intervals',
        'Full-Body Training',
      ],
    },
    'Luteal': {
      'intensity': 'Moderate',
      'focus': 'Steady training, strength and recovery',
      'tip': 'Adjust workout intensity based on your energy and comfort.',
      'workouts': [
        'Moderate Strength Workout',
        'Steady-State Cardio',
        'Mobility & Recovery',
      ],
    },
  };

  final Map<String, List<String>> workoutExercises = {
    'Gentle Walking': [
      'Easy Walking',
      'Heel-to-Toe Walking',
      'Slow Walking Cooldown',
    ],
    'Mobility & Stretching': [
      'Neck Mobility',
      'Shoulder Rolls',
      'Hip Circles',
      'Ankle Circles',
      'Gentle Full-Body Stretch',
    ],
    'Light Bodyweight Workout': [
      'Supported Squat',
      'Wall Push-Up',
      'Glute Bridge',
      'Standing March',
    ],
    'Strength Training': [
      'Bodyweight Squat',
      'Wall Push-Up',
      'Glute Bridge',
      'Bird Dog',
    ],
    'Moderate Cardio': ['Brisk Walking', 'Marching in Place', 'Step Touch'],
    'Full-Body Workout': [
      'Bodyweight Squat',
      'Wall Push-Up',
      'Glute Bridge',
      'Bird Dog',
    ],
    'Strength Workout': [
      'Bodyweight Squat',
      'Wall Push-Up',
      'Glute Bridge',
      'Bird Dog',
    ],
    'Cardio Intervals': ['Marching in Place', 'Step Touch', 'Brisk Walking'],
    'Full-Body Training': [
      'Bodyweight Squat',
      'Wall Push-Up',
      'Glute Bridge',
      'Bird Dog',
    ],
    'Moderate Strength Workout': [
      'Bodyweight Squat',
      'Wall Push-Up',
      'Glute Bridge',
      'Bird Dog',
    ],
    'Steady-State Cardio': ['Brisk Walking', 'Marching in Place', 'Step Touch'],
    'Mobility & Recovery': [
      'Shoulder Rolls',
      'Hip Circles',
      'Ankle Circles',
      'Gentle Full-Body Stretch',
    ],
  };
  final Map<String, Map<String, dynamic>> exerciseDetails = {
    'Supported Squat': {
      'howTo': [
        'Stand with your feet about shoulder-width apart.',
        'Keep your chest comfortable and your back neutral.',
        'Bend your knees and hips slowly while staying balanced.',
        'Push through your feet to return to the starting position.',
      ],
      'focus': 'Lower-body strength and controlled movement',
    },
    'Wall Push-Up': {
      'howTo': [
        'Stand facing a wall and place your hands on it.',
        'Keep your body in a comfortable straight position.',
        'Bend your elbows and slowly move toward the wall.',
        'Push gently away from the wall to return to the start.',
      ],
      'focus': 'Upper-body strength and controlled movement',
    },
    'Glute Bridge': {
      'howTo': [
        'Lie comfortably on your back with your knees bent.',
        'Keep your feet supported on the floor.',
        'Lift your hips slowly while keeping the movement controlled.',
        'Lower your hips gently and repeat at a comfortable pace.',
      ],
      'focus': 'Glute and lower-body strength',
    },
    'Gentle Walking': {
      'howTo': [
        'Start at an easy, comfortable walking pace.',
        'Keep your posture relaxed while walking.',
        'Maintain a pace that feels manageable.',
        'Slow down gradually before finishing.',
      ],
      'focus': 'Light movement and recovery',
    },
    'Mobility & Stretching': {
      'howTo': [
        'Begin with gentle shoulder and neck movements.',
        'Move through comfortable hip and ankle mobility.',
        'Add gentle full-body stretches.',
        'Never force a stretch or movement.',
      ],
      'focus': 'Mobility and comfortable movement',
    },
  };
  final Map<String, Map<String, dynamic>> workoutDetails = {
    'Gentle Walking': {
      'duration': '10–20 min',
      'focus': 'Light movement and recovery',
      'steps': [
        'Start with a comfortable walking pace.',
        'Keep your posture relaxed and shoulders comfortable.',
        'Walk at an easy pace that feels manageable.',
        'Slow down gradually before finishing.',
      ],
      'tip':
          'Keep the pace comfortable. Stop or reduce intensity if you feel unwell or uncomfortable.',
    },
    'Mobility & Stretching': {
      'duration': '10–15 min',
      'focus': 'Mobility and comfortable movement',
      'steps': [
        'Begin with gentle shoulder and neck movements.',
        'Move through comfortable hip and ankle mobility.',
        'Add gentle full-body stretches without forcing the range.',
        'Breathe normally and finish with a short relaxation period.',
      ],
      'tip':
          'Movements should feel comfortable. Do not force a stretch or movement.',
    },
    'Light Bodyweight Workout': {
      'duration': '10–15 min',
      'focus': 'Light full-body movement',
      'steps': [
        'Start with a gentle warm-up.',
        'Perform comfortable bodyweight movements such as supported squats.',
        'Add simple upper-body movements at an easy pace.',
        'Take breaks whenever needed.',
      ],
      'tip':
          'Choose easy variations and focus on comfortable movement rather than intensity.',
    },
    'Strength Training': {
      'duration': '25–35 min',
      'focus': 'Basic strength development',
      'steps': [
        'Begin with a short warm-up.',
        'Choose manageable resistance and focus on technique.',
        'Perform controlled repetitions with comfortable range of motion.',
        'Rest between exercises and finish with light recovery movement.',
      ],
      'tip':
          'Use manageable resistance and prioritize safe technique over heavier loads.',
    },
    'Moderate Cardio': {
      'duration': '20–30 min',
      'focus': 'Steady cardiovascular activity',
      'steps': [
        'Warm up gradually for a few minutes.',
        'Choose a comfortable cardio activity such as walking or cycling.',
        'Maintain a steady, manageable pace.',
        'Gradually reduce the pace before stopping.',
      ],
      'tip':
          'Keep the intensity manageable and adjust the pace whenever needed.',
    },
    'Full-Body Workout': {
      'duration': '25–35 min',
      'focus': 'Balanced full-body training',
      'steps': [
        'Start with a gentle warm-up.',
        'Choose simple lower-body, upper-body and core movements.',
        'Perform each movement with controlled technique.',
        'Rest between exercises and finish with recovery movement.',
      ],
      'tip':
          'Use exercise variations that match your experience level and focus on technique.',
    },
    'Strength Workout': {
      'duration': '25–35 min',
      'focus': 'Strength and controlled performance',
      'steps': [
        'Warm up before beginning resistance exercises.',
        'Choose manageable resistance for each exercise.',
        'Perform controlled repetitions with good technique.',
        'Rest between sets and cool down gradually.',
      ],
      'tip':
          'Do not sacrifice technique to increase resistance or repetitions.',
    },
    'Cardio Intervals': {
      'duration': '15–25 min',
      'focus': 'Cardiovascular fitness',
      'steps': [
        'Begin with a gradual warm-up.',
        'Alternate a comfortable faster period with an easier recovery period.',
        'Keep the harder periods manageable rather than maximal.',
        'Finish with several minutes of easy movement.',
      ],
      'tip':
          'Intervals should remain manageable. Reduce intensity if you feel uncomfortable.',
    },
    'Full-Body Training': {
      'duration': '25–35 min',
      'focus': 'Balanced strength and movement',
      'steps': [
        'Warm up the major muscle groups.',
        'Perform simple full-body exercises with controlled movement.',
        'Rest as needed between exercises.',
        'Finish with gentle cooldown movements.',
      ],
      'tip':
          'Prioritize controlled technique and comfortable movement throughout the session.',
    },
    'Moderate Strength Workout': {
      'duration': '20–30 min',
      'focus': 'Steady strength training',
      'steps': [
        'Start with a gentle warm-up.',
        'Choose manageable resistance.',
        'Perform controlled repetitions and take regular rests.',
        'Finish with gentle mobility or cooldown movement.',
      ],
      'tip':
          'Adjust resistance and rest periods according to your energy and comfort.',
    },
    'Steady-State Cardio': {
      'duration': '20–30 min',
      'focus': 'Steady cardiovascular activity',
      'steps': [
        'Warm up gradually.',
        'Choose a comfortable activity such as walking or cycling.',
        'Maintain a steady pace that you can comfortably sustain.',
        'Slow down gradually at the end.',
      ],
      'tip':
          'Keep the pace comfortable and adjust it whenever your energy changes.',
    },
    'Mobility & Recovery': {
      'duration': '10–20 min',
      'focus': 'Mobility and recovery',
      'steps': [
        'Begin with slow, comfortable movements.',
        'Move through gentle shoulder, hip and ankle mobility.',
        'Add relaxed stretching without forcing the range.',
        'Finish with slow breathing and easy movement.',
      ],
      'tip':
          'Recovery sessions should feel comfortable and should not be painful.',
    },
  };

  void _openExercise(String exerciseName) {
    final details = exerciseDetails[exerciseName];

    if (details == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ExerciseHowToScreen(exerciseName: exerciseName, details: details),
      ),
    );
  }

  void _openWorkout(String workoutName) {
    final details = workoutDetails[workoutName];

    if (details == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutDetailsScreen(
          workoutName: workoutName,
          duration: details['duration'] as String,
          focus: details['focus'] as String,
          steps: List<String>.from(details['steps'] as List),
          tip: details['tip'] as String,
          phase: selectedPhase,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final guidance = phaseGuidance[selectedPhase]!;
    final workouts = guidance['workouts'] as List<String>;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cycle-Aware Fitness',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.20),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.calendar_month_outlined, size: 34),
                  SizedBox(height: 12),
                  Text(
                    'Fitness that adapts to you',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Select a cycle phase to see general workout '
                    'and recovery guidance.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Current cycle phase',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: selectedPhase,
              decoration: InputDecoration(
                labelText: 'Select phase',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              items: phaseGuidance.keys.map((phase) {
                return DropdownMenuItem<String>(
                  value: phase,
                  child: Text(phase),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedPhase = value;
                });
              },
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedPhase,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Suggested intensity',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    guidance['intensity'] as String,
                    style: const TextStyle(height: 1.4),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Fitness focus',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    guidance['focus'] as String,
                    style: const TextStyle(height: 1.4),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'FitAI tip',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    guidance['tip'] as String,
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Suggested workouts',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Tap a workout to learn how to do it.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),

            const SizedBox(height: 14),

            ...workouts.asMap().entries.map((entry) {
              final index = entry.key;
              final workout = entry.value;

              final exerciseMap = <String, List<String>>{
                'Gentle Walking': [
                  'Comfortable Walking',
                  'Heel-to-Toe Walk',
                  'Easy March',
                ],
                'Mobility & Stretching': [
                  'Neck Mobility',
                  'Shoulder Rolls',
                  'Hip Mobility',
                  'Ankle Circles',
                ],
                'Light Bodyweight Workout': [
                  'Supported Squat',
                  'Wall Push-Up',
                  'Glute Bridge',
                ],
                'Strength Training': [
                  'Bodyweight Squat',
                  'Wall Push-Up',
                  'Glute Bridge',
                ],
                'Moderate Cardio': [
                  'Brisk Walking',
                  'March in Place',
                  'Low-Impact Step',
                ],
                'Full-Body Workout': [
                  'Bodyweight Squat',
                  'Wall Push-Up',
                  'Glute Bridge',
                ],
                'Strength Workout': [
                  'Bodyweight Squat',
                  'Wall Push-Up',
                  'Glute Bridge',
                ],
                'Cardio Intervals': [
                  'March in Place',
                  'Step Touch',
                  'Easy Recovery Walk',
                ],
                'Full-Body Training': [
                  'Bodyweight Squat',
                  'Wall Push-Up',
                  'Glute Bridge',
                ],
                'Moderate Strength Workout': [
                  'Bodyweight Squat',
                  'Wall Push-Up',
                  'Glute Bridge',
                ],
                'Steady-State Cardio': [
                  'Comfortable Walking',
                  'March in Place',
                  'Easy Cycling',
                ],
                'Mobility & Recovery': [
                  'Shoulder Rolls',
                  'Hip Mobility',
                  'Ankle Circles',
                  'Gentle Stretching',
                ],
              };

              final exercises =
                  exerciseMap[workout] ??
                  ['Bodyweight Squat', 'Wall Push-Up', 'Glute Bridge'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            _openWorkout(workout);
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  workout,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 17,
                                color: colorScheme.primary,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Recommended exercises',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        ...exercises.map(
                          (exercise) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                _openExercise(exercise);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.fitness_center,
                                      size: 18,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        exercise,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Watch exercise video',
                                      icon: Icon(
                                        Icons.play_circle_outline,
                                        size: 20,
                                        color: colorScheme.primary,
                                      ),
                                      onPressed: () async {
                                        final query = Uri.encodeComponent(
                                          "$exercise exercise tutorial",
                                        );

                                        final uri = Uri.parse(
                                          "https://www.youtube.com/results?search_query=$query",
                                        );

                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cycle experiences vary from person to person. '
                      'Use these suggestions as general wellness guidance '
                      'and adjust activity according to your comfort.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class WorkoutDetailsScreen extends StatelessWidget {
  final String workoutName;
  final String duration;
  final String focus;
  final List<String> steps;
  final String tip;
  final String phase;

  const WorkoutDetailsScreen({
    super.key,
    required this.workoutName,
    required this.duration,
    required this.focus,
    required this.steps,
    required this.tip,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'How to Do Workout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workoutName,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Suggested for your $phase phase',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _WorkoutInfoCard(
                    icon: Icons.timer_outlined,
                    title: L.t('duration'),
                    value: duration,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WorkoutInfoCard(
                    icon: Icons.track_changes_outlined,
                    title: L.t('focus'),
                    value: focus,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            Text(
              L.t('howToDoIt'),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          step,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.health_and_safety_outlined,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FitAI Safety Tip',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tip,
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'This feature provides general wellness guidance, '
              'not medical advice.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _WorkoutInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _WorkoutInfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final List<Map<String, dynamic>> exercises = [
    {'name': 'Bench Press', 'muscle': 'Chest', 'sets': 3, 'reps': 10},
    {'name': 'Shoulder Press', 'muscle': 'Shoulders', 'sets': 3, 'reps': 10},
    {'name': 'Lat Pulldown', 'muscle': 'Back', 'sets': 3, 'reps': 12},
    {'name': 'Bicep Curls', 'muscle': 'Biceps', 'sets': 3, 'reps': 12},
    {'name': 'Tricep Pushdown', 'muscle': 'Triceps', 'sets': 3, 'reps': 12},
  ];

  @override
  void initState() {
    super.initState();
    loadCustomExercises();
  }

  Future<void> loadCustomExercises() async {
    final prefs = await SharedPreferences.getInstance();

    final savedExercises = prefs.getStringList('custom_exercises');

    if (savedExercises == null) return;

    if (!mounted) return;

    setState(() {
      for (final item in savedExercises) {
        final parts = item.split('|');

        if (parts.length == 4) {
          exercises.add({
            'name': parts[0],
            'muscle': parts[1],
            'sets': int.tryParse(parts[2]) ?? 3,
            'reps': int.tryParse(parts[3]) ?? 10,
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.t('yourWorkout'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            L.t('workoutSubtitle'),
            style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
          ),

          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.deepPurpleAccent,
                        size: 28,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L.t('todaysWorkout'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Upper Body • 45 min',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _WorkoutStat(
                        value: '${exercises.length}',
                        label: L.t('exercises'),
                      ),
                    ),
                    Expanded(
                      child: _WorkoutStat(value: '3', label: L.t('sets')),
                    ),
                    Expanded(
                      child: _WorkoutStat(value: '45', label: L.t('minutes')),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            L.t('exercises'),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          ...exercises.map(
            (exercise) => _ExerciseTile(
              icon: Icons.fitness_center,
              name: exercise['name'],
              details:
                  '${exercise['sets']} ${L.t("sets")} \u00d7 '
                  '${exercise['reps']} ${L.t("reps")}',
            ),
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActiveWorkoutScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(
                L.t('startWorkout'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 6,
          ),
          leading: Icon(icon, color: Colors.deepPurpleAccent),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _WorkoutStat extends StatelessWidget {
  final String value;
  final String label;

  const _WorkoutStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String details;

  const _ExerciseTile({
    required this.icon,
    required this.name,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.deepPurpleAccent),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(details),
        trailing: const Icon(Icons.arrow_forward_ios, size: 15),
      ),
    );
  }
}

class ProgressData {
  static const String workoutsKey = 'progress_workouts';
  static const String exercisesKey = 'progress_exercises';
  static const String hoursKey = 'progress_hours';
  static const String workoutDatesKey = 'progress_workout_dates';

  static Future<void> recordWorkout({
    required int exercises,
    required Duration duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();

    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final dates = prefs.getStringList(workoutDatesKey) ?? <String>[];

    // Prevent duplicate recording for the same date.
    // If a workout has already been recorded today, do not record again.
    if (dates.contains(dateKey)) {
      return;
    }

    final workouts = prefs.getInt(workoutsKey) ?? 0;
    final oldExercises = prefs.getInt(exercisesKey) ?? 0;
    final oldHours = prefs.getDouble(hoursKey) ?? 0.0;

    dates.add(dateKey);

    await prefs.setInt(workoutsKey, workouts + 1);

    await prefs.setInt(exercisesKey, oldExercises + exercises);

    await prefs.setDouble(hoursKey, oldHours + duration.inSeconds / 3600.0);

    await prefs.setStringList(workoutDatesKey, dates);
  }

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'workouts': prefs.getInt(workoutsKey) ?? 0,
      'exercises': prefs.getInt(exercisesKey) ?? 0,
      'hours': prefs.getDouble(hoursKey) ?? 0.0,
      'dates': prefs.getStringList(workoutDatesKey) ?? <String>[],
    };
  }
}

class ProgressScreen extends StatefulWidget {
  final int refreshTrigger;
  const ProgressScreen({super.key, this.refreshTrigger = 0});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String weeklyDateLabel(int weekday) {
    final today = DateTime.now();

    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));

    final target = monday.add(Duration(days: weekday - 1));

    return '${target.day}/${target.month}';
  }

  bool isTodayInWeek(int weekday) {
    return DateTime.now().weekday == weekday;
  }

  bool isWorkoutDay(int weekday) {
    final today = DateTime.now();

    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));

    final target = monday.add(Duration(days: weekday - 1));

    final dateKey =
        '${target.year}-${target.month.toString().padLeft(2, '0')}-'
        '${target.day.toString().padLeft(2, '0')}';

    return workoutDates.contains(dateKey);
  }

  int calculateDayStreak() {
    if (workoutDates.isEmpty) return 0;

    final dates = workoutDates.toSet();
    final today = DateTime.now();

    int streak = 0;
    DateTime day = DateTime(today.year, today.month, today.day);

    while (dates.contains(
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}',
    )) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }

    return streak;
  }

  int totalWorkouts = 0;
  int totalExercises = 0;
  double totalHours = 0.0;
  List<String> workoutDates = <String>[];

  Future<void> loadProgressData() async {
    final data = await ProgressData.load();

    if (!mounted) return;

    setState(() {
      totalWorkouts = data['workouts'] as int;
      totalExercises = data['exercises'] as int;
      totalHours = data['hours'] as double;
      workoutDates = List<String>.from(data['dates'] as List);
    });
  }

  @override
  void initState() {
    super.initState();
    loadProgressData();
  }

  @override
  void didUpdateWidget(covariant ProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      loadProgressData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.t('yourProgress'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            L.t('trackFitnessJourney'),
            style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _ProgressCard(
                  value: totalWorkouts.toString(),
                  label: L.t('workouts'),
                  icon: Icons.fitness_center,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _ProgressCard(
                  value: totalHours.toStringAsFixed(1),
                  label: L.t('hours'),
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _ProgressCard(
                  value: totalExercises.toString(),
                  label: L.t('exercises'),
                  icon: Icons.directions_run,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _ProgressCard(
                  value: calculateDayStreak().toString(),
                  label: L.t('dayStreak'),
                  icon: Icons.local_fire_department,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Text(
            L.t('weeklyActivity'),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _ActivityRow(
                  day: L.t('monday'),
                  date: weeklyDateLabel(1),
                  completed: isWorkoutDay(DateTime.monday),
                  isToday: isTodayInWeek(1),
                ),
                _ActivityRow(
                  day: L.t('tuesday'),
                  date: weeklyDateLabel(2),
                  completed: isWorkoutDay(DateTime.tuesday),
                  isToday: isTodayInWeek(2),
                ),
                _ActivityRow(
                  day: L.t('wednesday'),
                  date: weeklyDateLabel(3),
                  completed: isWorkoutDay(DateTime.wednesday),
                  isToday: isTodayInWeek(3),
                ),
                _ActivityRow(
                  day: L.t('thursday'),
                  date: weeklyDateLabel(4),
                  completed: isWorkoutDay(DateTime.thursday),
                  isToday: isTodayInWeek(4),
                ),
                _ActivityRow(
                  day: L.t('friday'),
                  date: weeklyDateLabel(5),
                  completed: isWorkoutDay(DateTime.friday),
                  isToday: isTodayInWeek(5),
                ),
                _ActivityRow(
                  day: L.t('saturday'),
                  date: weeklyDateLabel(6),
                  completed: isWorkoutDay(DateTime.saturday),
                  isToday: isTodayInWeek(6),
                ),
                _ActivityRow(
                  day: L.t('sunday'),
                  date: weeklyDateLabel(7),
                  completed: isWorkoutDay(DateTime.sunday),
                  isToday: isTodayInWeek(7),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            L.t('fitnessSummary'),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${L.t("keepGoing")} \u{1F4AA}',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  L.t('fitnessSummaryDetail'),
                  style: const TextStyle(color: Colors.grey, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _ProgressCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepPurpleAccent, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String day;
  final String date;
  final bool completed;
  final bool isToday;

  const _ActivityRow({
    required this.day,
    required this.date,
    required this.completed,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isToday
            ? colorScheme.primary.withValues(alpha: 0.10)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: isToday
            ? Border.all(color: colorScheme.primary.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: completed
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              completed ? Icons.check_circle_outline : Icons.hotel_outlined,
              color: completed ? Colors.green : Colors.grey,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      day,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          L.t('today'),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 3),

                Text(
                  completed ? L.t('workoutCompletedLabel') : L.t('restNoWorkout'),
                  style: TextStyle(
                    fontSize: 12,
                    color: completed ? Colors.green : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          Icon(
            completed ? Icons.fitness_center : Icons.self_improvement,
            color: completed ? Colors.green : Colors.grey.shade500,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  List<Map<String, dynamic>> exercises = [];
  bool _isPersonalizedPlan = false;
  int completedExercises = 0;
  bool _workoutRecorded = false;
  late DateTime workoutStartTime;

  /// Hardcoded fallback exercises when no personalized plan exists.
  static const List<Map<String, dynamic>> _fallbackExercises = [
    {'name': 'Bench Press', 'muscle': 'Chest', 'sets': 3, 'reps': 10},
    {'name': 'Shoulder Press', 'muscle': 'Shoulders', 'sets': 3, 'reps': 10},
    {'name': 'Lat Pulldown', 'muscle': 'Back', 'sets': 3, 'reps': 12},
    {'name': 'Bicep Curls', 'muscle': 'Biceps', 'sets': 3, 'reps': 12},
    {'name': 'Tricep Pushdown', 'muscle': 'Triceps', 'sets': 3, 'reps': 12},
  ];

  @override
  void initState() {
    super.initState();
    workoutStartTime = DateTime.now();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    // 1. Try to load today's personalized plan
    final engine = WorkoutPlannerEngine.instance;
    final plans = await engine.loadPlans();
    final now = DateTime.now();

    DailyPlan? todayPlan;
    for (final plan in plans) {
      if (plan.date.year == now.year &&
          plan.date.month == now.month &&
          plan.date.day == now.day) {
        todayPlan = plan;
        break;
      }
    }

    if (todayPlan != null && todayPlan.exercises.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _isPersonalizedPlan = true;
        exercises = todayPlan!.exercises.map((e) => {
          'name': e.name,
          'muscle': e.muscleGroup,
          'sets': e.sets,
          'reps': e.reps,
          'instructions': e.instructions,
          'restSeconds': e.restSeconds,
        }).toList();
      });
      return;
    }

    // 2. Fall back to custom exercises from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedExercises = prefs.getStringList('custom_exercises');
    if (savedExercises != null && savedExercises.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _isPersonalizedPlan = false;
        exercises = List<Map<String, dynamic>>.from(_fallbackExercises);
        for (final item in savedExercises) {
          final parts = item.split('|');
          if (parts.length == 4) {
            exercises.add({
              'name': parts[0],
              'muscle': parts[1],
              'sets': int.tryParse(parts[2]) ?? 3,
              'reps': int.tryParse(parts[3]) ?? 10,
            });
          }
        }
      });
      return;
    }

    // 3. Use hardcoded fallback
    if (!mounted) return;
    setState(() {
      _isPersonalizedPlan = false;
      exercises = List<Map<String, dynamic>>.from(_fallbackExercises);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Handle loading state
    if (exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(L.t('activeWorkout')),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final int currentIndex = completedExercises
        .clamp(0, exercises.length - 1)
        .toInt();

    final currentExercise = exercises[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('activeWorkout')),
        actions: [
          IconButton(
            icon: const Icon(Icons.music_note),
            tooltip: L.t('gymMusic'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GymMusicScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L.t('todaysWorkout'),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            // Show plan source indicator
            Row(
              children: [
                Icon(
                  _isPersonalizedPlan ? Icons.auto_awesome : Icons.fitness_center,
                  size: 16,
                  color: _isPersonalizedPlan ? Colors.amber : Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isPersonalizedPlan
                        ? L.t('followAiPlan')
                        : L.t('defaultWorkout'),
                    style: TextStyle(
                      color: _isPersonalizedPlan
                          ? Colors.amber.shade200
                          : Colors.grey.shade400,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    L.t('currentExercise'),
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    currentExercise['name'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '${currentExercise['sets']} ${L.t("sets")} \u00d7 '
                    '${currentExercise['reps']} ${L.t("reps")}',
                    style: const TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    currentExercise['muscle'],
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            Text(
              L.t('workoutProgress'),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),

              child: LinearProgressIndicator(
                value: completedExercises / exercises.length,
                minHeight: 10,

                backgroundColor: const Color(0xFF292933),

                valueColor: const AlwaysStoppedAnimation<Color>(
                  Colors.deepPurpleAccent,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              '$completedExercises ${L.t("of")} '
              '${exercises.length} ${L.t("ofExercisesCompleted")}',

              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,

              child: ElevatedButton.icon(
                onPressed: (completedExercises == exercises.length ||
                        _workoutRecorded)
                    ? null
                    : () async {
                        setState(() {
                          completedExercises++;
                        });

                        if (completedExercises == exercises.length &&
                            !_workoutRecorded) {
                          _workoutRecorded = true;
                          final duration = DateTime.now().difference(
                            workoutStartTime,
                          );
                          final messenger = ScaffoldMessenger.of(context);

                          await ProgressData.recordWorkout(
                            exercises: completedExercises,
                            duration: duration,
                          );

                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '\u{1F3C6} ${L.t("workoutCompletedMsg")}',
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${L.t("exerciseCompletedMsg")} \u{1F4AA}',
                              ),
                            ),
                          );
                        }
                      },

                icon: const Icon(Icons.check),

                label: Text(
                  (completedExercises == exercises.length || _workoutRecorded)
                      ? L.t('workoutComplete')
                      : L.t('completeExercise'),

                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,

                  foregroundColor: Colors.white,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final Future<void> Function(String) onLanguageChanged;

  const ProfileScreen({
    super.key,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String selectedGoal = 'Build strength';

  @override
  void initState() {
    super.initState();
    loadGoal();
  }

  Future<void> loadGoal() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      selectedGoal = prefs.getString('user_goal') ?? 'Build strength';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.t('myProfile'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            L.t('manageFitnessProfile'),
            style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
          ),

          const SizedBox(height: 25),

          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.deepPurpleAccent.withValues(
                    alpha: 0.15,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.deepPurpleAccent,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  L.t('fitnessUser'),
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(
                  L.t('aiFitnessMember'),
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          Text(
            L.t('fitnessInformation'),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          _ProfileTile(
            icon: Icons.person_outline,
            title: L.t('personalInformation'),
            subtitle: L.t('personalInfoSubtitle'),
            screen: const PersonalInformationScreen(),
          ),

          _ProfileTile(
            icon: Icons.flag_outlined,
            title: L.t('fitnessGoal'),
            subtitle: selectedGoal,
            screen: const FitnessGoalScreen(),
          ),

          _ProfileTile(
            icon: Icons.notifications_none,
            title: L.t('notifications'),
            subtitle: L.t('notificationsSubtitle'),
            screen: const NotificationsScreen(),
          ),

          _ProfileTile(
            icon: Icons.settings_outlined,
            title: L.t('settings'),
            subtitle: L.t('settingsSubtitle'),
            screen: SettingsScreen(
              onThemeChanged: widget.onThemeChanged,
              onLanguageChanged: widget.onLanguageChanged,
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget screen;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 7,
          ),
          leading: Icon(icon, color: Colors.deepPurpleAccent, size: 27),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.arrow_forward_ios, size: 15),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => screen),
            );
          },
        ),
      ),
    );
  }
}

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  String userName = 'Fitness User';
  String userAge = 'Not added';
  String userHeight = 'Not added';
  String userWeight = 'Not added';
  String userGoal = 'Build strength';

  @override
  void initState() {
    super.initState();
    loadInformation();
  }

  Future<void> loadInformation() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      userName = prefs.getString('user_name') ?? 'Fitness User';
      userAge = prefs.getString('user_age') ?? 'Not added';
      userHeight = prefs.getString('user_height') ?? 'Not added';
      userWeight = prefs.getString('user_weight') ?? 'Not added';
      userGoal = prefs.getString('user_goal') ?? 'Build strength';
    });
  }

  Future<void> editInformation({
    required String title,
    required String key,
    required String currentValue,
    required Function(String) onSaved,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController(
      text:
          currentValue == 'Not added' ||
              currentValue == 'Fitness User' ||
              currentValue == 'Build strength'
          ? ''
          : currentValue,
    );

    final newValue = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${L.t("enterYour")} $title'),
          content: TextField(
            controller: controller,
            autofocus: false,
            keyboardType: keyboardType,
            decoration: InputDecoration(hintText: '${L.t("your")} $title'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(L.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(dialogContext, value);
                }
              },
              child: Text(L.t('save')),
            ),
          ],
        );
      },
    );

    if (newValue == null || newValue.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, newValue);

    if (!mounted) return;

    setState(() {
      onSaved(newValue);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title ${L.t("savedMsg")}: $newValue')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('personalInformation'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L.t('yourInformation'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              L.t('addBasicInfo'),
              style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
            ),

            const SizedBox(height: 25),

            _InformationCard(
              icon: Icons.person_outline,
              title: L.t('name'),
              value: userName,
              onTap: () {
                editInformation(
                  title: L.t('name'),
                  key: 'user_name',
                  currentValue: userName,
                  onSaved: (value) {
                    userName = value;
                  },
                );
              },
            ),

            _InformationCard(
              icon: Icons.cake_outlined,
              title: L.t('age'),
              value: userAge,
              onTap: () {
                editInformation(
                  title: L.t('age'),
                  key: 'user_age',
                  currentValue: userAge,
                  keyboardType: TextInputType.number,
                  onSaved: (value) {
                    userAge = value;
                  },
                );
              },
            ),

            _InformationCard(
              icon: Icons.height,
              title: L.t('height'),
              value: userHeight,
              onTap: () {
                editInformation(
                  title: L.t('height'),
                  key: 'user_height',
                  currentValue: userHeight,
                  keyboardType: TextInputType.number,
                  onSaved: (value) {
                    userHeight = value;
                  },
                );
              },
            ),

            _InformationCard(
              icon: Icons.monitor_weight_outlined,
              title: L.t('weight'),
              value: userWeight,
              onTap: () {
                editInformation(
                  title: L.t('weight'),
                  key: 'user_weight',
                  currentValue: userWeight,
                  keyboardType: TextInputType.number,
                  onSaved: (value) {
                    userWeight = value;
                  },
                );
              },
            ),

            _InformationCard(
              icon: Icons.flag_outlined,
              title: L.t('fitnessGoal'),
              value: userGoal,
              onTap: () {
                editInformation(
                  title: L.t('fitnessGoal'),
                  key: 'user_goal',
                  currentValue: userGoal,
                  onSaved: (value) {
                    userGoal = value;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const _InformationCard({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 8,
          ),
          leading: Icon(icon, color: Colors.deepPurpleAccent, size: 27),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(value),
          trailing: const Icon(Icons.arrow_forward_ios, size: 15),
          onTap: onTap,
        ),
      ),
    );
  }
}

class FitnessGoalScreen extends StatefulWidget {
  const FitnessGoalScreen({super.key});

  @override
  State<FitnessGoalScreen> createState() => _FitnessGoalScreenState();
}

class _FitnessGoalScreenState extends State<FitnessGoalScreen> {
  String selectedGoal = 'Build strength';

  final List<String> goals = [
    'Build strength',
    'Muscle gain',
    'Weight management',
    'Improve fitness',
    'Stay active',
  ];

  @override
  void initState() {
    super.initState();
    loadGoal();
  }

  Future<void> loadGoal() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      selectedGoal = prefs.getString('user_goal') ?? 'Build strength';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('fitnessGoal'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            L.t('chooseYourGoal'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            L.t('chooseGoalDetail'),
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),

          const SizedBox(height: 25),

          RadioGroup<String>(
            groupValue: selectedGoal,
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                selectedGoal = value;
              });
            },
            child: Column(
              children: [
                ...goals.map(
                  (goal) => Card(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: RadioListTile<String>(
                      value: goal,
                      activeColor: Colors.deepPurpleAccent,
                      title: Text(
                        goal,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();

                await prefs.setString('user_goal', selectedGoal);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${L.t("goalSavedMsg")}: $selectedGoal')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                L.t('saveGoal'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool workoutReminders = true;
  bool progressUpdates = true;
  bool aiCoachTips = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('notifications'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            L.t('notificationSettings'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            L.t('chooseNotifications'),
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),

          const SizedBox(height: 25),

          _NotificationTile(
            title: L.t('workoutRemindersTitle'),
            subtitle: L.t('workoutRemindersSubtitle'),
            value: workoutReminders,
            onChanged: (value) {
              setState(() {
                workoutReminders = value;
              });
            },
          ),

          _NotificationTile(
            title: L.t('progressUpdates'),
            subtitle: L.t('progressUpdatesSubtitle'),
            value: progressUpdates,
            onChanged: (value) {
              setState(() {
                progressUpdates = value;
              });
            },
          ),

          _NotificationTile(
            title: L.t('aiCoachTips'),
            subtitle: L.t('aiCoachTipsSubtitle'),
            value: aiCoachTips,
            onChanged: (value) {
              setState(() {
                aiCoachTips = value;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SwitchListTile(
        value: value,
        activeThumbColor: Colors.deepPurpleAccent,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onChanged: onChanged,
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final Future<void> Function(String) onLanguageChanged;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String appearance = 'Dark mode';
  String language = 'English';

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      appearance = prefs.getString('appearance') ?? 'Dark mode';
      language = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> chooseAppearance() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(L.t('chooseAppearance')),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, 'System default');
              },
              child: Text(L.t('systemDefault')),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, 'Light mode');
              },
              child: Text(L.t('lightMode')),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, 'Dark mode');
              },
              child: Text(L.t('darkMode')),
            ),
          ],
        );
      },
    );

    if (selected == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appearance', selected);

    if (!mounted) return;

    setState(() {
      appearance = selected;
    });
    widget.onThemeChanged(
      selected == 'Light mode'
          ? ThemeMode.light
          : selected == 'System default'
          ? ThemeMode.system
          : ThemeMode.dark,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${L.t("appearanceSavedMsg")}: $selected')));
  }

  Future<void> chooseLanguage() async {
    final isEnglish = language == 'English' || language == 'Roman English';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(L.t('chooseLanguage')),
          children: AppLanguages.all.map((lang) {
            final displayName = isEnglish
                ? lang.name
                : (AppLanguages.urduNames[lang.name] ?? lang.name);
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, lang.name);
              },
              child: Text(displayName),
            );
          }).toList(),
        );
      },
    );

    if (selected == null) return;

    await widget.onLanguageChanged(selected);

    if (!mounted) return;

    setState(() {
      language = selected;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${L.t("languageSavedMsg")}: $selected')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            L.t('appSettings'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            L.t('managePreferences'),
            style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
          ),

          const SizedBox(height: 25),

          _SettingsTile(
            icon: Icons.language,
            title: L.t('language'),
            subtitle: language,
            onTap: chooseLanguage,
          ),

          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: L.t('appearance'),
            subtitle: appearance,
            onTap: chooseAppearance,
          ),

          _SettingsTile(
            icon: Icons.security_outlined,
            title: L.t('privacy'),
            subtitle: L.t('privacySubtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyScreen()),
              );
            },
          ),

          _SettingsTile(
            icon: Icons.info_outline,
            title: L.t('aboutAiFitness'),
            subtitle: L.t('appInformation'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutAIScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        leading: Icon(icon, color: Colors.deepPurpleAccent, size: 27),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 15),
        onTap: onTap,
      ),
    );
  }
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool activityPermission = true;
  bool cameraPermission = false;
  bool notificationPermission = false;
  bool locationPermission = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('privacy'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            L.t('privacyData'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            L.t('managePrivacy'),
            style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
          ),

          const SizedBox(height: 25),

          // Privacy Information
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.t('yourPrivacy'),
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  L.t('privacyInfoText'),
                  style: TextStyle(color: Colors.grey, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            L.t('dataInformation'),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          _PrivacyTile(
            icon: Icons.storage_outlined,
            title: L.t('manageYourData'),
            subtitle: L.t('manageDataSubtitle'),
            onTap: () {
              _showDataInformation();
            },
          ),

          const SizedBox(height: 20),

          Text(
            L.t('manageYourData'),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          // Export Data
          _PrivacyTile(
            icon: Icons.file_download_outlined,
            title: L.t('exportMyData'),
            subtitle: L.t('exportDataSubtitle'),
            onTap: _exportData,
          ),

          // Delete Account
          _PrivacyTile(
            icon: Icons.delete_forever_outlined,
            title: L.t('deleteAccount'),
            subtitle: L.t('deleteAccountSubtitle'),
            iconColor: Colors.redAccent,
            onTap: _confirmDeleteAccount,
          ),

          // Cloud Data
          _PrivacyTile(
            icon: Icons.cloud_outlined,
            title: L.t('deleteCloudData'),
            subtitle: L.t('noCloudData'),
            onTap: _showCloudDataInfo,
          ),

          // Permissions
          _PrivacyTile(
            icon: Icons.security_outlined,
            title: L.t('permissions'),
            subtitle: L.t('permissionsSubtitle'),
            onTap: _showPermissions,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // DATA INFORMATION
  // --------------------------------------------------

  void _showDataInformation() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(L.t('yourStoredData')),
          content: const Text(
            'FitAI may store the following information locally '
            'on this device:\n\n'
            '• Name\n'
            '• Age\n'
            '• Height\n'
            '• Weight\n'
            '• Fitness goal\n'
            '• Appearance preference\n'
            '• Language preference\n'
            '• Custom exercises\n'
            '• Hidden exercise preferences\n\n'
            'This version of FitAI does not currently use '
            'cloud storage for this information.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(L.t('close')),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------
  // EXPORT DATA
  // --------------------------------------------------

  Future<void> _exportData() async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'name': prefs.getString('user_name') ?? '',
      'age': prefs.getString('user_age') ?? '',
      'height': prefs.getString('user_height') ?? '',
      'weight': prefs.getString('user_weight') ?? '',
      'fitnessGoal': prefs.getString('user_goal') ?? '',
      'appearance': prefs.getString('appearance') ?? 'Dark mode',
      'language': prefs.getString('language') ?? 'English',
      'customExercises': prefs.getStringList('custom_exercises') ?? [],
      'hiddenDefaultExercises':
          prefs.getStringList('hidden_default_exercises') ?? [],
    };

    final jsonData = const JsonEncoder.withIndent('  ').convert(data);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/fitai_data.json');

    await file.writeAsString(jsonData);

    if (!mounted) return;

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'My FitAI data'),
    );
  }

  // --------------------------------------------------
  // DELETE ACCOUNT
  // --------------------------------------------------

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(L.t('deleteAccountQuestion')),
          content: const Text(
            'This will permanently remove your locally '
            'stored FitAI profile, preferences and custom '
            'exercise data from this device.\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(L.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: Text(L.t('delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('user_name');
    await prefs.remove('user_age');
    await prefs.remove('user_height');
    await prefs.remove('user_weight');
    await prefs.remove('user_goal');
    await prefs.remove('appearance');
    await prefs.remove('language');
    await prefs.remove('custom_exercises');
    await prefs.remove('hidden_default_exercises');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.t('dataDeletedMsg'))),
    );
  }

  // --------------------------------------------------
  // CLOUD DATA
  // --------------------------------------------------

  void _showCloudDataInfo() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(L.t('cloudData')),
          content: const Text(
            'No cloud database is currently connected '
            'to this version of FitAI.\n\n'
            'Your profile and preferences are currently '
            'stored locally on this device.\n\n'
            'Cloud deletion can be connected when a '
            'backend such as Firebase is added.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(L.t('ok')),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------
  // PERMISSIONS
  // --------------------------------------------------

  Future<void> _showPermissions() async {
    final activityStatus = await Permission.activityRecognition.status;
    final cameraStatus = await Permission.camera.status;
    final notificationStatus = await Permission.notification.status;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(L.t('permissions')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PermissionRow(
                icon: Icons.directions_walk,
                title: L.t('physicalActivity'),
                subtitle: L.t('stepTracking'),
                status: activityStatus.isGranted
                    ? '${L.t("allowed")} \u2713'
                    : '${L.t("allow")} >',
                allowed: activityStatus.isGranted,
                onTap: () async {
                  await Permission.activityRecognition.request();

                  if (!dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _showPermissions();
                },
              ),

              _PermissionRow(
                icon: Icons.camera_alt_outlined,
                title: L.t('camera'),
                subtitle: L.t('formChecking'),
                status: cameraStatus.isGranted
                    ? '${L.t("allowed")} \u2713'
                    : '${L.t("allow")} >',
                allowed: cameraStatus.isGranted,
                onTap: () async {
                  await Permission.camera.request();

                  if (!dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _showPermissions();
                },
              ),

              _PermissionRow(
                icon: Icons.notifications_outlined,
                title: L.t('notifications'),
                subtitle: L.t('workoutReminders'),
                status: notificationStatus.isGranted
                    ? '${L.t("allowed")} \u2713'
                    : '${L.t("allow")} >',
                allowed: notificationStatus.isGranted,
                onTap: () async {
                  await Permission.notification.request();

                  if (!dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _showPermissions();
                },
              ),

              _PermissionRow(
                icon: Icons.location_on_outlined,
                title: L.t('location'),
                subtitle: L.t('notRequired'),
                status: L.t('notRequired'),
                allowed: false,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(L.t('close')),
            ),
          ],
        );
      },
    );
  }
}
// --------------------------------------------------
// PRIVACY TILE
// --------------------------------------------------

class _PrivacyTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const _PrivacyTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        leading: Icon(
          icon,
          color: iconColor ?? Colors.deepPurpleAccent,
          size: 27,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 15),
        onTap: onTap,
      ),
    );
  }
}

// --------------------------------------------------
// PERMISSION ROW
// --------------------------------------------------

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final bool allowed;
  final VoidCallback? onTap;

  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.allowed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.deepPurpleAccent),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Text(
              status,
              style: TextStyle(
                color: allowed ? Colors.green : Colors.deepPurpleAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutAIScreen extends StatelessWidget {
  const AboutAIScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('aboutAiFitness'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.deepPurpleAccent.withValues(
                    alpha: 0.15,
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    size: 50,
                    color: Colors.deepPurpleAccent,
                  ),
                ),

                const SizedBox(height: 15),

                Text(
                  L.t('appName'),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  L.t('aiPlatform'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.t('version'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text('1.0.0', style: TextStyle(color: Colors.grey)),

                const SizedBox(height: 20),

                Text(
                  L.t('about'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  L.t('aboutDetail'),
                  style: const TextStyle(color: Colors.grey, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final List<Map<String, dynamic>> defaultExercises = [
    {'name': 'Squat', 'muscle': 'Legs & Glutes', 'sets': 3, 'reps': 10},
    {'name': 'Push-up', 'muscle': 'Chest & Triceps', 'sets': 3, 'reps': 10},
    {'name': 'Bicep Curl', 'muscle': 'Biceps', 'sets': 3, 'reps': 10},
    {'name': 'Shoulder Press', 'muscle': 'Shoulders', 'sets': 3, 'reps': 10},
    {'name': 'Lunge', 'muscle': 'Legs & Glutes', 'sets': 3, 'reps': 10},
    {'name': 'Jumping Jack', 'muscle': 'Full Body', 'sets': 3, 'reps': 20},
    {'name': 'Plank', 'muscle': 'Core', 'sets': 3, 'reps': 30},
    {'name': 'Bench Press', 'muscle': 'Chest', 'sets': 3, 'reps': 10},
    {'name': 'Lat Pulldown', 'muscle': 'Back', 'sets': 3, 'reps': 12},
    {'name': 'Tricep Pushdown', 'muscle': 'Triceps', 'sets': 3, 'reps': 12},
  ];

  List<Map<String, dynamic>> customExercises = [];

  Set<String> hiddenDefaultExercises = {};

  @override
  void initState() {
    super.initState();
    loadExercises();
  }

  Future<void> loadExercises() async {
    final prefs = await SharedPreferences.getInstance();

    final savedExercises = prefs.getStringList('custom_exercises') ?? [];

    final hidden = prefs.getStringList('hidden_default_exercises') ?? [];

    if (!mounted) return;

    setState(() {
      customExercises = savedExercises.map((item) {
        final parts = item.split('|');

        return {
          'name': parts.isNotEmpty ? parts[0] : 'Exercise',
          'muscle': parts.length > 1 ? parts[1] : 'Custom',
          'sets': parts.length > 2 ? int.tryParse(parts[2]) ?? 3 : 3,
          'reps': parts.length > 3 ? int.tryParse(parts[3]) ?? 10 : 10,
        };
      }).toList();

      hiddenDefaultExercises = hidden.toSet();
    });
  }

  Future<void> saveCustomExercises() async {
    final prefs = await SharedPreferences.getInstance();

    final data = customExercises.map((exercise) {
      return '${exercise['name']}|'
          '${exercise['muscle']}|'
          '${exercise['sets']}|'
          '${exercise['reps']}';
    }).toList();

    await prefs.setStringList('custom_exercises', data);
  }

  Future<void> saveHiddenDefaults() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'hidden_default_exercises',
      hiddenDefaultExercises.toList(),
    );
  }

  Future<void> addCustomExercise() async {
    final nameController = TextEditingController();
    final muscleController = TextEditingController();
    final setsController = TextEditingController(text: '3');
    final repsController = TextEditingController(text: '10');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(L.t('addCustomExercise')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: L.t('exerciseName')),
                ),
                TextField(
                  controller: muscleController,
                  decoration: InputDecoration(labelText: L.t('muscleGroup')),
                ),
                TextField(
                  controller: setsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: L.t('sets')),
                ),
                TextField(
                  controller: repsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: L.t('repetitions')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(L.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();

                if (name.isEmpty) return;

                final muscle = muscleController.text.trim().isEmpty
                    ? 'Custom'
                    : muscleController.text.trim();

                final sets = int.tryParse(setsController.text) ?? 3;

                final reps = int.tryParse(repsController.text) ?? 10;

                Navigator.pop(dialogContext, {
                  'name': name,
                  'muscle': muscle,
                  'sets': sets,
                  'reps': reps,
                });
              },
              child: Text(L.t('addExercise')),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    setState(() {
      customExercises.add(result);
    });

    await saveCustomExercises();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${L.t("exerciseAddedMsg")} \u{1F4AA}'),
      ),
    );
  }

  Future<void> deleteCustomExercise(int index) async {
    final exercise = customExercises[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(L.t('deleteExerciseQuestion')),
          content: Text(
            'Are you sure you want to delete '
            '"${exercise['name']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(L.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(L.t('delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      customExercises.removeAt(index);
    });

    await saveCustomExercises();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(L.t('exerciseDeletedMsg'))));
  }

  Future<void> editCustomExercise(int index) async {
    final exercise = customExercises[index];

    final nameController = TextEditingController(text: exercise['name']);

    final muscleController = TextEditingController(text: exercise['muscle']);

    final setsController = TextEditingController(
      text: exercise['sets'].toString(),
    );

    final repsController = TextEditingController(
      text: exercise['reps'].toString(),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(L.t('editExercise')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: L.t('exerciseName')),
                ),
                TextField(
                  controller: muscleController,
                  decoration: InputDecoration(labelText: L.t('muscleGroup')),
                ),
                TextField(
                  controller: setsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: L.t('sets')),
                ),
                TextField(
                  controller: repsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: L.t('repetitions')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(L.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();

                if (name.isEmpty) return;

                Navigator.pop(dialogContext, {
                  'name': name,
                  'muscle': muscleController.text.trim().isEmpty
                      ? 'Custom'
                      : muscleController.text.trim(),
                  'sets': int.tryParse(setsController.text) ?? 3,
                  'reps': int.tryParse(repsController.text) ?? 10,
                });
              },
              child: Text(L.t('saveChanges')),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    setState(() {
      customExercises[index] = result;
    });

    await saveCustomExercises();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.t('exerciseUpdatedMsg'))),
    );
  }

  Future<void> hideDefaultExercise(Map<String, dynamic> exercise) async {
    final name = exercise['name'] as String;

    setState(() {
      hiddenDefaultExercises.add(name);
    });

    await saveHiddenDefaults();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name ${L.t("hiddenMsg")}')),
    );
  }

  Future<void> showDefaultExercise(Map<String, dynamic> exercise) async {
    final name = exercise['name'] as String;

    setState(() {
      hiddenDefaultExercises.remove(name);
    });

    await saveHiddenDefaults();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name ${L.t("restoredMsg")}')));
  }

  LibraryExercise? _cameraExerciseFor(String name) {
    final normalized = name.trim().toLowerCase();
    for (final exercise in ExerciseLibrary.instance.allExercises) {
      if (!exercise.cameraSupported) continue;
      if (exercise.name.toLowerCase() == normalized) return exercise;
    }
    for (final exercise in ExerciseLibrary.instance.allExercises) {
      if (!exercise.cameraSupported) continue;
      if (exercise.name.toLowerCase().contains(normalized) ||
          normalized.contains(exercise.name.toLowerCase())) {
        return exercise;
      }
    }
    return null;
  }

  ExerciseType? _parseExerciseType(String? name) {
    if (name == null) return null;
    for (final type in ExerciseType.values) {
      if (type.name == name) return type;
    }
    return null;
  }

  Widget buildExerciseTile(
    Map<String, dynamic> exercise, {
    required bool isCustom,
    int? customIndex,
  }) {
    final cameraExercise = _cameraExerciseFor(exercise['name'] as String);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: const Icon(
          Icons.fitness_center,
          color: Colors.deepPurpleAccent,
          size: 28,
        ),
        title: Text(
          exercise['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${exercise['muscle']} • '
          '${exercise['sets']} sets × '
          '${exercise['reps']} reps',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cameraExercise != null)
              IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.blue),
                tooltip: L.t('formCheck'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormCheckScreen(
                        initialExercise:
                            _parseExerciseType(cameraExercise.poseExerciseType),
                        targetSets: cameraExercise.defaultSets,
                        targetRepsPerSet: cameraExercise.defaultReps,
                      ),
                    ),
                  );
                },
              ),
            PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit' && customIndex != null) {
              editCustomExercise(customIndex);
            }

            if (value == 'delete' && customIndex != null) {
              deleteCustomExercise(customIndex);
            }

            if (value == 'hide') {
              hideDefaultExercise(exercise);
            }

            if (value == 'restore') {
              showDefaultExercise(exercise);
            }
          },
          itemBuilder: (context) {
            if (isCustom) {
              return [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined),
                      const SizedBox(width: 10),
                      Text(L.t('edit')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline),
                      const SizedBox(width: 10),
                      Text(L.t('delete')),
                    ],
                  ),
                ),
              ];
            }

            final isHidden = hiddenDefaultExercises.contains(exercise['name']);

            return [
              PopupMenuItem(
                value: isHidden ? 'restore' : 'hide',
                child: Row(
                  children: [
                    Icon(
                      isHidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    const SizedBox(width: 10),
                    Text(isHidden ? L.t('restore') : L.t('hide')),
                  ],
                ),
              ),
            ];
          },
        ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleDefaults = defaultExercises
        .where((exercise) => !hiddenDefaultExercises.contains(exercise['name']))
        .toList();
    final hiddenDefaults = defaultExercises
        .where((exercise) => hiddenDefaultExercises.contains(exercise['name']))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(L.t('exerciseLibrary'))),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (visibleDefaults.isNotEmpty) ...[
            Text(
              L.t('defaultExercises'),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            ...visibleDefaults.map(
              (exercise) => buildExerciseTile(exercise, isCustom: false),
            ),
          ],
          if (hiddenDefaults.isNotEmpty) ...[
            const SizedBox(height: 15),

            Text(
              L.t('hiddenExercises'),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            ...hiddenDefaults.map(
              (exercise) => buildExerciseTile(exercise, isCustom: false),
            ),
          ],
          if (customExercises.isNotEmpty) ...[
            const SizedBox(height: 15),

            Text(
              L.t('myExercises'),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            ...customExercises.asMap().entries.map(
              (entry) => buildExerciseTile(
                entry.value,
                isCustom: true,
                customIndex: entry.key,
              ),
            ),
          ],

          if (visibleDefaults.isEmpty &&
              hiddenDefaults.isEmpty &&
              customExercises.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Center(
                child: Text(
                  L.t('noExercises'),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),

          const SizedBox(height: 90),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: addCustomExercise,
        icon: const Icon(Icons.add),
        label: Text(L.t('addExercise')),
      ),
    );
  }
}


