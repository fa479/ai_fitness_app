import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// FitAI feature modules
import 'app/app_localizations.dart';
import 'features/form_check_screen.dart';
import 'features/ai_coach_screen.dart';
import 'features/nutrition_screen.dart';
import 'core/voice_service.dart';

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
    final savedAppearance =
        prefs.getString('appearance') ?? 'Dark mode';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Fitness',

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
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
    const HomeContent(),
    const WorkoutScreen(),
    const ProgressScreen(),
    ProfileScreen(
      onThemeChanged: widget.onThemeChanged,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Fitness',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome Back ðŸ‘‹',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Your AI personal trainer is ready.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade400,
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _FeatureCard(
                  icon: Icons.auto_awesome,
                  title: 'AI Coach',
                  subtitle: 'Your personal AI trainer',
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
                  title: 'Form Check',
                  subtitle: 'Real-time pose detection',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const FormCheckScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _FeatureCard(
            icon: Icons.restaurant_menu,
            title: 'Nutrition',
            subtitle: 'Log meals & track macros',
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
            title: "Women's Wellness",
            subtitle: 'Cycle-aware fitness & wellness support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const WomensWellnessScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 28),

          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          _ActionTile(
            icon: Icons.calendar_month,
            title: 'My Workout Plan',
            subtitle: 'View your personalized weekly plan',
          ),

          _ActionTile(
            icon: Icons.menu_book_outlined,
            title: 'Exercise Library',
            subtitle: 'Explore exercises and instructions',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ExerciseLibraryScreen(),
                ),
              );
            },
          ),

          _ActionTile(
            icon: Icons.music_note,
            title: 'Gym Music',
            subtitle: 'Choose music for your workout',
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
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 30,
              color: Colors.deepPurpleAccent,
            ),

            const SizedBox(height: 14),

            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
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
          'Hi! ðŸ‘‹ Iâ€™m your AI Fitness Coach. How can I help you today?',
    },
  ];

  void _sendMessage() {
    final message = _messageController.text.trim();

    if (message.isEmpty) return;

    setState(() {
      _messages.add({
        'sender': 'You',
        'message': message,
      });

      _messages.add({
        'sender': 'AI',
        'message':
            'Great! ðŸ’ª I can help you with workouts, fitness goals, recovery and healthy habits.',
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
                  alignment:
                      isAI ? Alignment.centerLeft : Alignment.centerRight,
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
        title: const Text(
          'Women’s Wellness',
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
                  Icon(
                    Icons.favorite_outline,
                    size: 34,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your wellness, your way',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Personalized wellness guidance designed '
                    'around women’s fitness and wellbeing.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Women’s Wellness',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            _WellnessFeatureTile(
              icon: Icons.calendar_month_outlined,
              title: 'Cycle-Aware Fitness',
              subtitle:
                  'Get workout guidance that can adapt to your cycle.',
              onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CycleAwareFitnessScreen(),
                    ),
                  );
                },
            ),

            _WellnessFeatureTile(
              icon: Icons.restaurant_menu_outlined,
              title: 'Cycle-Aware Nutrition',
              subtitle:
                  'Explore nutrition guidance for different cycle phases.',
              onTap: () {},
            ),

            _WellnessFeatureTile(
              icon: Icons.favorite_border,
              title: 'PCOS Support',
              subtitle:
                  'Wellness and fitness guidance for users with PCOS.',
              onTap: () {},
            ),

            _WellnessFeatureTile(
              icon: Icons.self_improvement_outlined,
              title: 'Pregnancy & Postpartum',
              subtitle:
                  'Wellness guidance for pregnancy and recovery after birth.',
              onTap: () {},
            ),

            _WellnessFeatureTile(
              icon: Icons.wb_sunny_outlined,
              title: 'Hormonal Wellness',
              subtitle:
                  'Learn about fitness, recovery and healthy habits.',
              onTap: () {},
            ),

            _WellnessFeatureTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Women’s Safety Mode',
              subtitle:
                  'Extra safety-focused options for workouts and wellness.',
              onTap: () {},
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
                  child: Icon(
                    icon,
                    color: colorScheme.primary,
                  ),
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

class CycleAwareFitnessScreen extends StatefulWidget {
  const CycleAwareFitnessScreen({super.key});

  @override
  State<CycleAwareFitnessScreen> createState() =>
      _CycleAwareFitnessScreenState();
}

class _CycleAwareFitnessScreenState
    extends State<CycleAwareFitnessScreen> {
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
      'workouts': [
        'Strength Training',
        'Moderate Cardio',
        'Full-Body Workout',
      ],
    },
    'Ovulatory': {
      'intensity': 'Moderate to high',
      'focus': 'Strength, cardio and performance',
      'tip':
          'Prioritize good technique, controlled movement and recovery.',
      'workouts': [
        'Strength Workout',
        'Cardio Intervals',
        'Full-Body Training',
      ],
    },
    'Luteal': {
      'intensity': 'Moderate',
      'focus': 'Steady training, strength and recovery',
      'tip':
          'Adjust workout intensity based on your energy and comfort.',
      'workouts': [
        'Moderate Strength Workout',
        'Steady-State Cardio',
        'Mobility & Recovery',
      ],
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
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 34,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Fitness that adapts to you',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Select a cycle phase to see general workout '
                    'and recovery guidance.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Current cycle phase',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: selectedPhase,
              decoration: InputDecoration(
                labelText: 'Select phase',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(
                  Icons.calendar_today_outlined,
                ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    guidance['intensity'] as String,
                    style: const TextStyle(height: 1.4),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Fitness focus',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    guidance['focus'] as String,
                    style: const TextStyle(height: 1.4),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'FitAI tip',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
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
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Tap a workout to learn how to do it.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),

            const SizedBox(height: 14),

            ...workouts.asMap().entries.map((entry) {
              final index = entry.key;
              final workout = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      _openWorkout(workout);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  workout,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Tap to view how to do this workout',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
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
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                      ),
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
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
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
                    title: 'Duration',
                    value: duration,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WorkoutInfoCard(
                    icon: Icons.track_changes_outlined,
                    title: 'Focus',
                    value: focus,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            const Text(
              'How to do it',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
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

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          step,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                          ),
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
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                          ),
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
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
              ),
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
          Icon(
            icon,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
            ),
          ),
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
    { 
      'name': 'Bench Press', 
      'muscle': 'Chest', 
      'sets': 3, 
      'reps': 10, 
    }, 
    { 
      'name': 'Shoulder Press', 
      'muscle': 'Shoulders', 
      'sets': 3, 
      'reps': 10, 
    }, 
    { 
      'name': 'Lat Pulldown', 
      'muscle': 'Back', 
      'sets': 3, 
      'reps': 12, 
    }, 
    { 
      'name': 'Bicep Curls', 
      'muscle': 'Biceps', 
      'sets': 3, 
      'reps': 12, 
    }, 
    { 
      'name': 'Tricep Pushdown', 
      'muscle': 'Triceps', 
      'sets': 3, 
      'reps': 12, 
    }, 
  ]; 
 
  @override 
  void initState() { 
    super.initState(); 
    loadCustomExercises(); 
  } 
 
  Future<void> loadCustomExercises() async { 
    final prefs = await SharedPreferences.getInstance(); 
 
    final savedExercises = 
        prefs.getStringList('custom_exercises'); 
 
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
          const Text( 
            'Your Workout', 
            style: TextStyle( 
              fontSize: 28, 
              fontWeight: FontWeight.bold, 
            ), 
          ), 
 
          const SizedBox(height: 8), 
 
          Text( 
            'Your AI-powered training plan', 
            style: TextStyle( 
              fontSize: 15, 
              color: Colors.grey.shade400, 
            ), 
          ), 
 
          const SizedBox(height: 24), 
 
          Container( 
            width: double.infinity, 
            padding: const EdgeInsets.all(20), 
            decoration: BoxDecoration( 
              color: Theme.of(context) 
                  .colorScheme 
                  .surfaceContainerHighest, 
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
                        color: Colors.deepPurpleAccent 
                            .withValues(alpha: 0.15), 
                        borderRadius: BorderRadius.circular(14), 
                      ), 
                      child: const Icon( 
                        Icons.auto_awesome, 
                        color: Colors.deepPurpleAccent, 
                        size: 28, 
                      ), 
                    ), 
 
                    const SizedBox(width: 14), 
 
                    const Expanded( 
                      child: Column( 
                        crossAxisAlignment: 
                            CrossAxisAlignment.start, 
                        children: [ 
                          Text( 
                            'Today\'s Workout', 
                            style: TextStyle( 
                              fontSize: 19, 
                              fontWeight: FontWeight.bold, 
                            ), 
                          ), 
                          SizedBox(height: 4), 
                          Text( 
                            'Upper Body â€¢ 45 min', 
                            style: TextStyle( 
                              color: Colors.grey, 
                            ), 
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
                        label: 'Exercises', 
                      ), 
                    ), 
                    const Expanded( 
                      child: _WorkoutStat( 
                        value: '3', 
                        label: 'Sets', 
                      ), 
                    ), 
                    const Expanded( 
                      child: _WorkoutStat( 
                        value: '45', 
                        label: 'Minutes', 
                      ), 
                    ), 
                  ], 
                ), 
              ], 
            ), 
          ), 
 
          const SizedBox(height: 28), 
 
          const Text( 
            'Exercises', 
            style: TextStyle( 
              fontSize: 21, 
              fontWeight: FontWeight.bold, 
            ), 
          ), 
 
          const SizedBox(height: 15), 
 
          ...exercises.map( 
            (exercise) => _ExerciseTile( 
              icon: Icons.fitness_center, 
              name: exercise['name'], 
              details: 
                  '${exercise['sets']} sets Ã— ' 
                  '${exercise['reps']} reps', 
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
                    builder: (context) => 
                        const ActiveWorkoutScreen(), 
                  ), 
                ); 
              }, 
              icon: const Icon(Icons.play_arrow), 
              label: const Text( 
                'Start Workout', 
                style: TextStyle( 
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
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 6,
          ),
          leading: Icon(
            icon,
            color: Colors.deepPurpleAccent,
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _WorkoutStat extends StatelessWidget {
  final String value;
  final String label;

  const _WorkoutStat({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.deepPurpleAccent,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(details),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 15,
        ),
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

    final workouts = prefs.getInt(workoutsKey) ?? 0;
    final oldExercises = prefs.getInt(exercisesKey) ?? 0;
    final oldHours = prefs.getDouble(hoursKey) ?? 0.0;

    final now = DateTime.now();

    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final dates =
        prefs.getStringList(workoutDatesKey) ?? <String>[];

    if (!dates.contains(dateKey)) {
      dates.add(dateKey);
    }

    await prefs.setInt(
      workoutsKey,
      workouts + 1,
    );

    await prefs.setInt(
      exercisesKey,
      oldExercises + exercises,
    );

    await prefs.setDouble(
      hoursKey,
      oldHours + duration.inSeconds / 3600.0,
    );

    await prefs.setStringList(
      workoutDatesKey,
      dates,
    );
  }

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'workouts': prefs.getInt(workoutsKey) ?? 0,
      'exercises': prefs.getInt(exercisesKey) ?? 0,
      'hours': prefs.getDouble(hoursKey) ?? 0.0,
      'dates':
          prefs.getStringList(workoutDatesKey) ?? <String>[],
    };
  }
}
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

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
    ).subtract(
      Duration(days: today.weekday - 1),
    );

    final target = monday.add(
      Duration(days: weekday - 1),
    );

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
    ).subtract(
      Duration(days: today.weekday - 1),
    );

    final target = monday.add(
      Duration(days: weekday - 1),
    );

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
    DateTime day = DateTime(
      today.year,
      today.month,
      today.day,
    );

    while (dates.contains(
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}',
    )) {
      streak++;
      day = day.subtract(
        const Duration(days: 1),
      );
    }

    return streak;
  }
  int steps = 0;
  int _initialSteps = 0;

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

  Stream<StepCount>? _stepCountStream;
  StreamSubscription<StepCount>? _stepSubscription;
  Stream<PedestrianStatus>? _pedestrianStatusStream;
  StreamSubscription<PedestrianStatus>? _statusSubscription;

  String pedestrianStatus = 'Unknown';

  @override
  void initState() {
    super.initState();
    initStepCounter();
    loadProgressData();
  }

  void initStepCounter() {
    try {
      _stepCountStream = Pedometer.stepCountStream;
      _pedestrianStatusStream = Pedometer.pedestrianStatusStream;

      _stepSubscription = _stepCountStream!.listen(
        onStepCount,
        onError: onStepCountError,
        cancelOnError: false,
      );

      _statusSubscription = _pedestrianStatusStream!.listen(
        onPedestrianStatusChanged,
        onError: onPedestrianStatusError,
        cancelOnError: false,
      );
    } catch (e) {
      // Emulator or device without step sensor
      if (kDebugMode) debugPrint('Step sensor not available: $e');
      setState(() {
        pedestrianStatus = 'Step sensor not available on this device';
      });
    }
  }

  void onStepCount(StepCount event) {
    if (!mounted) return;

    if (_initialSteps == 0) {
      _initialSteps = event.steps;
    }

    setState(() {
      steps = event.steps - _initialSteps;
    });
  }

  void onStepCountError(dynamic error) {
    if (!mounted) return;

    setState(() {
      pedestrianStatus = 'Step sensor unavailable';
    });
  }

  void onPedestrianStatusChanged(PedestrianStatus event) {
    if (!mounted) return;

    setState(() {
      pedestrianStatus = event.status;
    });
  }

  void onPedestrianStatusError(dynamic error) {
    if (!mounted) return;

    setState(() {
      pedestrianStatus = 'Unavailable';
    });
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Progress',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Track your fitness journey',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade400,
            ),
          ),

          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.directions_walk,
                    color: Colors.deepPurpleAccent,
                    size: 32,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today\'s Steps',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        '$steps steps',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        pedestrianStatus == 'walking'
                            ? 'Walking'
                            : pedestrianStatus == 'stopped'
                                ? 'Not walking'
                                : pedestrianStatus,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _ProgressCard(
                  value: totalWorkouts.toString(),
                  label: 'Workouts',
                  icon: Icons.fitness_center,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _ProgressCard(
                  value: totalHours.toStringAsFixed(1),
                  label: 'Hours',
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
                  label: 'Exercises',
                  icon: Icons.directions_run,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _ProgressCard(
                  value: calculateDayStreak().toString(),
                  label: 'Day Streak',
                  icon: Icons.local_fire_department,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          const Text(
            'Weekly Activity',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                                _ActivityRow(
                  day: 'Monday',
                  date: weeklyDateLabel(1),
                  completed: isWorkoutDay(DateTime.monday),
                  isToday: isTodayInWeek(1),
                ),
                _ActivityRow(
                  day: 'Tuesday',
                  date: weeklyDateLabel(2),
                  completed: isWorkoutDay(DateTime.tuesday),
                  isToday: isTodayInWeek(2),
                ),
                _ActivityRow(
                  day: 'Wednesday',
                  date: weeklyDateLabel(3),
                  completed: isWorkoutDay(DateTime.wednesday),
                  isToday: isTodayInWeek(3),
                ),
                _ActivityRow(
                  day: 'Thursday',
                  date: weeklyDateLabel(4),
                  completed: isWorkoutDay(DateTime.thursday),
                  isToday: isTodayInWeek(4),
                ),
                _ActivityRow(
                  day: 'Friday',
                  date: weeklyDateLabel(5),
                  completed: isWorkoutDay(DateTime.friday),
                  isToday: isTodayInWeek(5),
                ),
                _ActivityRow(
                  day: 'Saturday',
                  date: weeklyDateLabel(6),
                  completed: isWorkoutDay(DateTime.saturday),
                  isToday: isTodayInWeek(6),
                ),
                _ActivityRow(
                  day: 'Sunday',
                  date: weeklyDateLabel(7),
                  completed: isWorkoutDay(DateTime.sunday),
                  isToday: isTodayInWeek(7),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Fitness Summary',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep going! ðŸ’ª',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You are building a consistent workout routine. '
                  'Complete your weekly workouts to keep improving.',
                  style: TextStyle(
                    color: Colors.grey,
                    height: 1.5,
                  ),
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
          Icon(
            icon,
            color: Colors.deepPurpleAccent,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
            ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isToday
            ? colorScheme.primary.withValues(alpha: 0.10)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: isToday
            ? Border.all(
                color: colorScheme.primary.withValues(alpha: 0.35),
              )
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
              completed
                  ? Icons.check_circle_outline
                  : Icons.hotel_outlined,
              color: completed
                  ? Colors.green
                  : Colors.grey,
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
                          'TODAY',
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
                  completed
                      ? 'Workout completed'
                      : 'Rest / No workout',
                  style: TextStyle(
                    fontSize: 12,
                    color: completed
                        ? Colors.green
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          Icon(
            completed
                ? Icons.fitness_center
                : Icons.self_improvement,
            color: completed
                ? Colors.green
                : Colors.grey.shade500,
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
  State<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  List<Map<String, dynamic>> exercises = [
    {
      'name': 'Bench Press',
      'muscle': 'Chest',
      'sets': 3,
      'reps': 10,
    },
    {
      'name': 'Shoulder Press',
      'muscle': 'Shoulders',
      'sets': 3,
      'reps': 10,
    },
    {
      'name': 'Lat Pulldown',
      'muscle': 'Back',
      'sets': 3,
      'reps': 12,
    },
    {
      'name': 'Bicep Curls',
      'muscle': 'Biceps',
      'sets': 3,
      'reps': 12,
    },
    {
      'name': 'Tricep Pushdown',
      'muscle': 'Triceps',
      'sets': 3,
      'reps': 12,
    },
  ];

  int completedExercises = 0;
  late DateTime workoutStartTime;

  @override
  void initState() {
    super.initState();
    workoutStartTime = DateTime.now();
    loadCustomExercises();
  }

  Future<void> loadCustomExercises() async {
    final prefs = await SharedPreferences.getInstance();

    final savedExercises =
        prefs.getStringList('custom_exercises');

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
    final int currentIndex = completedExercises
        .clamp(0, exercises.length - 1)
        .toInt();

    final currentExercise = exercises[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Workout'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upper Body Workout',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Follow your AI training plan',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 25),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Current Exercise',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
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
                    '${currentExercise['sets']} sets Ã— '
                    '${currentExercise['reps']} reps',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    currentExercise['muscle'],
                    style: TextStyle(
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Workout Progress',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),

              child: LinearProgressIndicator(
                value:
                    completedExercises / exercises.length,
                minHeight: 10,

                backgroundColor:
                    const Color(0xFF292933),

                valueColor:
                    const AlwaysStoppedAnimation<Color>(
                  Colors.deepPurpleAccent,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              '$completedExercises of '
              '${exercises.length} exercises completed',

              style: const TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,

              child: ElevatedButton.icon(
                onPressed:
                    completedExercises == exercises.length
                        ? null
                        : () async {
                            setState(() {
                              completedExercises++;
                            });

                            if (completedExercises ==
                                exercises.length) {
                              final duration =
                                  DateTime.now().difference(
                                workoutStartTime,
                              );
                              final messenger = ScaffoldMessenger.of(context);

                              await ProgressData.recordWorkout(
                                exercises: completedExercises,
                                duration: duration,
                              );

                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'ðŸŽ‰ Workout Completed! Great job!',
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Exercise completed! ðŸ’ª',
                                  ),
                                ),
                              );
                            }
                          },

                icon: const Icon(Icons.check),

                label: Text(
                  completedExercises == exercises.length
                      ? 'Workout Completed'
                      : 'Complete Exercise',

                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.deepPurpleAccent,

                  foregroundColor: Colors.white,

                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
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

  const ProfileScreen({
    super.key,
    required this.onThemeChanged,
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
      selectedGoal =
          prefs.getString('user_goal') ?? 'Build strength';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Profile',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Manage your fitness profile',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade400,
            ),
          ),

          const SizedBox(height: 25),

          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor:
                      Colors.deepPurpleAccent.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.deepPurpleAccent,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Fitness User',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'AI Fitness Member',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            'Fitness Information',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          _ProfileTile(
            icon: Icons.person_outline,
            title: 'Personal Information',
            subtitle: 'Name, age, height and weight',
            screen: const PersonalInformationScreen(),
          ),

          _ProfileTile(
            icon: Icons.flag_outlined,
            title: 'Fitness Goal',
            subtitle: selectedGoal,
            screen: const FitnessGoalScreen(),
          ),

          _ProfileTile(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Manage workout reminders',
            screen: const NotificationsScreen(),
          ),

          _ProfileTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'App preferences and options',
            screen: SettingsScreen(
  onThemeChanged: widget.onThemeChanged,
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
          leading: Icon(
            icon,
            color: Colors.deepPurpleAccent,
            size: 27,
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 15,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => screen,
              ),
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

class _PersonalInformationScreenState
    extends State<PersonalInformationScreen> {
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
      userName =
          prefs.getString('user_name') ?? 'Fitness User';
      userAge =
          prefs.getString('user_age') ?? 'Not added';
      userHeight =
          prefs.getString('user_height') ?? 'Not added';
      userWeight =
          prefs.getString('user_weight') ?? 'Not added';
      userGoal =
          prefs.getString('user_goal') ?? 'Build strength';
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
      text: currentValue == 'Not added' ||
              currentValue == 'Fitness User' ||
              currentValue == 'Build strength'
          ? ''
          : currentValue,
    );

    final newValue = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Enter Your $title'),
          content: TextField(
            controller: controller,
            autofocus: false,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: 'Your $title',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(dialogContext, value);
                }
              },
              child: const Text('Save'),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title saved: $newValue'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Information'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Information',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Add your basic fitness information',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade400,
              ),
            ),

            const SizedBox(height: 25),

            _InformationCard(
              icon: Icons.person_outline,
              title: 'Name',
              value: userName,
              onTap: () {
                editInformation(
                  title: 'Name',
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
              title: 'Age',
              value: userAge,
              onTap: () {
                editInformation(
                  title: 'Age',
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
              title: 'Height',
              value: userHeight,
              onTap: () {
                editInformation(
                  title: 'Height',
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
              title: 'Weight',
              value: userWeight,
              onTap: () {
                editInformation(
                  title: 'Weight',
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
              title: 'Fitness Goal',
              value: userGoal,
              onTap: () {
                editInformation(
                  title: 'Fitness Goal',
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
          leading: Icon(
            icon,
            color: Colors.deepPurpleAccent,
            size: 27,
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(value),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 15,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class FitnessGoalScreen extends StatefulWidget {
  const FitnessGoalScreen({super.key});

  @override
  State<FitnessGoalScreen> createState() =>
      _FitnessGoalScreenState();
}

class _FitnessGoalScreenState
    extends State<FitnessGoalScreen> {
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
      selectedGoal =
          prefs.getString('user_goal') ?? 'Build strength';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Goal'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose Your Goal',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Select the goal that best matches your fitness journey.',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 15,
            ),
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          margin: const EdgeInsets.only(bottom: 12),
          child: RadioListTile<String>(
            value: goal,
            activeColor: Colors.deepPurpleAccent,
            title: Text(
              goal,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
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
                final prefs =
                    await SharedPreferences.getInstance();

                await prefs.setString(
                  'user_goal',
                  selectedGoal,
                );
              
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Fitness goal saved: $selectedGoal',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Save Goal',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
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
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  bool workoutReminders = true;
  bool progressUpdates = true;
  bool aiCoachTips = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Notification Settings',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Choose which notifications you want to receive.',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 25),

          _NotificationTile(
            title: 'Workout Reminders',
            subtitle: 'Get reminders for your workouts',
            value: workoutReminders,
            onChanged: (value) {
              setState(() {
                workoutReminders = value;
              });
            },
          ),

          _NotificationTile(
            title: 'Progress Updates',
            subtitle: 'Receive updates about your progress',
            value: progressUpdates,
            onChanged: (value) {
              setState(() {
                progressUpdates = value;
              });
            },
          ),

          _NotificationTile(
            title: 'AI Coach Tips',
            subtitle: 'Get helpful tips from your AI coach',
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
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        onChanged: onChanged,
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
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
          title: const Text('Choose Appearance'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, 'System default');
              },
              child: const Text('System default'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, 'Light mode');
              },
              child: const Text('Light mode'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, 'Dark mode');
              },
              child: const Text('Dark mode'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appearance saved: $selected'),
      ),
    );
  }

  Future<void> chooseLanguage() async {
  final selected = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return SimpleDialog(
        title: const Text('Choose Language'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'English');
            },
            child: const Text('English'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Urdu');
            },
            child: const Text('Urdu'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Sindhi');
            },
            child: const Text('Sindhi'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Punjabi');
            },
            child: const Text('Punjabi'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Pashto');
            },
            child: const Text('Pashto'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Balochi');
            },
            child: const Text('Balochi'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Saraiki');
            },
            child: const Text('Saraiki'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Hindko');
            },
            child: const Text('Hindko'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Kashmiri');
            },
            child: const Text('Kashmiri'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Shina');
            },
            child: const Text('Shina'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Balti');
            },
            child: const Text('Balti'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Brahui');
            },
            child: const Text('Brahui'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Wakhi');
            },
            child: const Text('Wakhi'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Khowar');
            },
            child: const Text('Khowar'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext, 'Burushaski');
            },
            child: const Text('Burushaski'),
          ),
        ],
      );
    },
  );

  if (selected == null) return;

  final prefs = await SharedPreferences.getInstance();

  await prefs.setString('language', selected);
  L.set(selected);

  if (!mounted) return;

  setState(() {
    language = selected;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Language saved: $selected'),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'App Settings',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Manage your AI Fitness app preferences.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade400,
            ),
          ),

          const SizedBox(height: 25),

          _SettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: language,
            onTap: chooseLanguage,
          ),

          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Appearance',
            subtitle: appearance,
            onTap: chooseAppearance,
          ),

          _SettingsTile(
            icon: Icons.security_outlined,
            title: 'Privacy',
            subtitle: 'Manage your privacy preferences',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyScreen(),
                ),
              );
            },
          ),

          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About AI Fitness',
            subtitle: 'App information',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutAIScreen(),
                ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 7,
        ),
        leading: Icon(
          icon,
          color: Colors.deepPurpleAccent,
          size: 27,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 15,
        ),
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
      appBar: AppBar(
        title: const Text('Privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Privacy & Data',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Manage your privacy and personal data.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade400,
            ),
          ),

          const SizedBox(height: 25),

          // Privacy Information
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Privacy',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'AI Fitness currently stores profile information '
                  'and app preferences locally on your device. '
                  'Cloud storage is not currently connected.',
                  style: TextStyle(
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Data Information',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          _PrivacyTile(
            icon: Icons.storage_outlined,
            title: 'Manage Your Data',
            subtitle: 'View and control your stored app data',
            onTap: () {
              _showDataInformation();
            },
          ),

          const SizedBox(height: 20),

          const Text(
            'Manage Your Data',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          // Export Data
          _PrivacyTile(
            icon: Icons.file_download_outlined,
            title: 'Export My Data',
            subtitle: 'Save a copy of your available FitAI data',
            onTap: _exportData,
          ),

          // Delete Account
          _PrivacyTile(
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            subtitle: 'Delete your local FitAI data',
            iconColor: Colors.redAccent,
            onTap: _confirmDeleteAccount,
          ),

          // Cloud Data
          _PrivacyTile(
            icon: Icons.cloud_outlined,
            title: 'Delete Cloud Data',
            subtitle: 'No cloud data is currently stored',
            onTap: _showCloudDataInfo,
          ),

          // Permissions
          _PrivacyTile(
            icon: Icons.security_outlined,
            title: 'Permissions',
            subtitle: 'View app permission information',
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
          title: const Text('Your Stored Data'),
          content: const Text(
            'FitAI may store the following information locally '
            'on this device:\n\n'
            'â€¢ Name\n'
            'â€¢ Age\n'
            'â€¢ Height\n'
            'â€¢ Weight\n'
            'â€¢ Fitness goal\n'
            'â€¢ Appearance preference\n'
            'â€¢ Language preference\n'
            'â€¢ Custom exercises\n'
            'â€¢ Hidden exercise preferences\n\n'
            'This version of FitAI does not currently use '
            'cloud storage for this information.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
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
    'customExercises':
        prefs.getStringList('custom_exercises') ?? [],
    'hiddenDefaultExercises':
        prefs.getStringList('hidden_default_exercises') ?? [],
  };

  final jsonData = const JsonEncoder.withIndent('  ').convert(data);

  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/fitai_data.json');

  await file.writeAsString(jsonData);

  if (!mounted) return;

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      text: 'My FitAI data',
    ),
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
          title: const Text('Delete Account?'),
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
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
      const SnackBar(
        content: Text(
          'Your local FitAI data has been deleted.',
        ),
      ),
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
          title: const Text('Cloud Data'),
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
              child: const Text('OK'),
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
  final activityStatus =
      await Permission.activityRecognition.status;
  final cameraStatus =
      await Permission.camera.status;
  final notificationStatus =
      await Permission.notification.status;

  if (!mounted) return;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Permissions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PermissionRow(
              icon: Icons.directions_walk,
              title: 'Physical Activity',
              subtitle: 'Used for step tracking',
              status: activityStatus.isGranted
                  ? 'Allowed âœ“'
                  : 'Allow >',
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
              title: 'Camera',
              subtitle: 'Used for workout form checking',
              status: cameraStatus.isGranted
                  ? 'Allowed âœ“'
                  : 'Allow >',
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
              title: 'Notifications',
              subtitle: 'Used for workout reminders',
              status: notificationStatus.isGranted
                  ? 'Allowed âœ“'
                  : 'Allow >',
              allowed: notificationStatus.isGranted,
              onTap: () async {
                await Permission.notification.request();

                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext);
                _showPermissions();
              },
            ),

            const _PermissionRow(
              icon: Icons.location_on_outlined,
              title: 'Location',
              subtitle: 'Not currently required',
              status: 'Not required',
              allowed: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Close'),
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
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 7,
        ),
        leading: Icon(
          icon,
          color: iconColor ?? Colors.deepPurpleAccent,
          size: 27,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 15,
        ),
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
            Icon(
              icon,
              color: Colors.deepPurpleAccent,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Text(
              status,
              style: TextStyle(
                color: allowed
                    ? Colors.green
                    : Colors.deepPurpleAccent,
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
      appBar: AppBar(
        title: const Text('About AI Fitness'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor:
                      Colors.deepPurpleAccent.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.fitness_center,
                    size: 50,
                    color: Colors.deepPurpleAccent,
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'AI Fitness',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'AI-powered fitness and wellness platform',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                  ),
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '1.0.0',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                SizedBox(height: 20),

                Text(
                  'About',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'AI Fitness helps users manage workouts, '
                  'fitness goals, progress and personalized training.',
                  style: TextStyle(
                    color: Colors.grey,
                    height: 1.5,
                  ),
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
  State<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState
    extends State<ExerciseLibraryScreen> {
  final List<Map<String, dynamic>> defaultExercises = [
    {
      'name': 'Bench Press',
      'muscle': 'Chest',
      'sets': 3,
      'reps': 10,
    },
    {
      'name': 'Shoulder Press',
      'muscle': 'Shoulders',
      'sets': 3,
      'reps': 10,
    },
    {
      'name': 'Lat Pulldown',
      'muscle': 'Back',
      'sets': 3,
      'reps': 12,
    },
    {
      'name': 'Bicep Curls',
      'muscle': 'Biceps',
      'sets': 3,
      'reps': 12,
    },
    {
      'name': 'Tricep Pushdown',
      'muscle': 'Triceps',
      'sets': 3,
      'reps': 12,
    },
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

    final savedExercises =
        prefs.getStringList('custom_exercises') ?? [];

    final hidden =
        prefs.getStringList('hidden_default_exercises') ?? [];

    if (!mounted) return;

    setState(() {
      customExercises = savedExercises.map((item) {
        final parts = item.split('|');

        return {
          'name': parts.isNotEmpty ? parts[0] : 'Exercise',
          'muscle': parts.length > 1 ? parts[1] : 'Custom',
          'sets': parts.length > 2
              ? int.tryParse(parts[2]) ?? 3
              : 3,
          'reps': parts.length > 3
              ? int.tryParse(parts[3]) ?? 10
              : 10,
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

    await prefs.setStringList(
      'custom_exercises',
      data,
    );
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
          title: const Text('Add Custom Exercise'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Exercise name',
                  ),
                ),
                TextField(
                  controller: muscleController,
                  decoration: const InputDecoration(
                    labelText: 'Muscle group',
                  ),
                ),
                TextField(
                  controller: setsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sets',
                  ),
                ),
                TextField(
                  controller: repsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Repetitions',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();

                if (name.isEmpty) return;

                final muscle =
                    muscleController.text.trim().isEmpty
                        ? 'Custom'
                        : muscleController.text.trim();

                final sets =
                    int.tryParse(setsController.text) ?? 3;

                final reps =
                    int.tryParse(repsController.text) ?? 10;

                Navigator.pop(
                  dialogContext,
                  {
                    'name': name,
                    'muscle': muscle,
                    'sets': sets,
                    'reps': reps,
                  },
                );
              },
              child: const Text('Add Exercise'),
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
      const SnackBar(
        content: Text('Exercise added successfully! ðŸ’ª'),
      ),
    );
  }

  Future<void> deleteCustomExercise(int index) async {
    final exercise = customExercises[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Exercise?'),
          content: Text(
            'Are you sure you want to delete '
            '"${exercise['name']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exercise deleted.'),
      ),
    );
  }

  Future<void> editCustomExercise(int index) async {
    final exercise = customExercises[index];

    final nameController =
        TextEditingController(text: exercise['name']);

    final muscleController =
        TextEditingController(text: exercise['muscle']);

    final setsController =
        TextEditingController(
      text: exercise['sets'].toString(),
    );

    final repsController =
        TextEditingController(
      text: exercise['reps'].toString(),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Exercise'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Exercise name',
                  ),
                ),
                TextField(
                  controller: muscleController,
                  decoration: const InputDecoration(
                    labelText: 'Muscle group',
                  ),
                ),
                TextField(
                  controller: setsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sets',
                  ),
                ),
                TextField(
                  controller: repsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Repetitions',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();

                if (name.isEmpty) return;

                Navigator.pop(
                  dialogContext,
                  {
                    'name': name,
                    'muscle':
                        muscleController.text.trim().isEmpty
                            ? 'Custom'
                            : muscleController.text.trim(),
                    'sets':
                        int.tryParse(setsController.text) ?? 3,
                    'reps':
                        int.tryParse(repsController.text) ?? 10,
                  },
                );
              },
              child: const Text('Save Changes'),
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
      const SnackBar(
        content: Text('Exercise updated successfully!'),
      ),
    );
  }

  Future<void> hideDefaultExercise(
      Map<String, dynamic> exercise) async {
    final name = exercise['name'] as String;

    setState(() {
      hiddenDefaultExercises.add(name);
    });

    await saveHiddenDefaults();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name hidden from Exercise Library.'),
      ),
    );
  }

  Future<void> showDefaultExercise(
      Map<String, dynamic> exercise) async {
    final name = exercise['name'] as String;

    setState(() {
      hiddenDefaultExercises.remove(name);
    });

    await saveHiddenDefaults();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name restored.'),
      ),
    );
  }

  Widget buildExerciseTile(
    Map<String, dynamic> exercise, {
    required bool isCustom,
    int? customIndex,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 8,
        ),
        leading: const Icon(
          Icons.fitness_center,
          color: Colors.deepPurpleAccent,
          size: 28,
        ),
        title: Text(
          exercise['name'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${exercise['muscle']} â€¢ '
          '${exercise['sets']} sets Ã— '
          '${exercise['reps']} reps',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit' &&
                customIndex != null) {
              editCustomExercise(customIndex);
            }

            if (value == 'delete' &&
                customIndex != null) {
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
              return const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ];
            }

            final isHidden =
                hiddenDefaultExercises
                    .contains(exercise['name']);

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
                    Text(
                      isHidden
                          ? 'Restore'
                          : 'Hide',
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleDefaults = defaultExercises
        .where(
          (exercise) => !hiddenDefaultExercises
              .contains(exercise['name']),
        )
        .toList();
final hiddenDefaults = defaultExercises
    .where(
      (exercise) => hiddenDefaultExercises
          .contains(exercise['name']),
    )
    .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (visibleDefaults.isNotEmpty) ...[
            const Text(
              'Default Exercises',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            ...visibleDefaults.map(
              (exercise) => buildExerciseTile(
                exercise,
                isCustom: false,
              ),
            ),
          ],
if (hiddenDefaults.isNotEmpty) ...[
  const SizedBox(height: 15),

  const Text(
    'Hidden Exercises',
    style: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.bold,
    ),
  ),

  const SizedBox(height: 15),

  ...hiddenDefaults.map(
    (exercise) => buildExerciseTile(
      exercise,
      isCustom: false,
    ),
  ),
],
          if (customExercises.isNotEmpty) ...[
            const SizedBox(height: 15),

            const Text(
              'My Exercises',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
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
            const Padding(
              padding: EdgeInsets.only(top: 50),
              child: Center(
                child: Text(
                  'No exercises available.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 90),
        ],
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: addCustomExercise,
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
      ),
    );
  }
}
class AIFormCheckScreen extends StatefulWidget {
  const AIFormCheckScreen({super.key});

  @override
  State<AIFormCheckScreen> createState() => _AIFormCheckScreenState();
}

class _AIFormCheckScreenState extends State<AIFormCheckScreen> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;

  bool _isCameraReady = false;
  bool _isProcessing = false;

  String exerciseName = 'Squat';
  int reps = 0;
  String formStatus = 'Get ready...';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          formStatus = 'No camera found';
        });
        return;
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          model: PoseDetectionModel.base,
          mode: PoseDetectionMode.stream,
        ),
      );

      await _cameraController!.startImageStream(_processCameraImage);

      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
        formStatus = 'Position yourself in front of the camera';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        formStatus = 'Camera initialization failed';
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      // Pose detection processing will be connected here.
      //
      // Camera stream is active and ready for ML Kit pose analysis.
      // Rep counting and form correction can be added here.
    } catch (_) {
      // Ignore individual frame errors.
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Form Check',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isCameraReady && _cameraController != null
          ? Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_cameraController!),

                      Positioned(
                        top: 20,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                exerciseName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                formStatus,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: 25,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text(
                                    'Reps',
                                    style: TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$reps',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text(
                                    'Exercise',
                                    style: TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    exerciseName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    formStatus,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}






























