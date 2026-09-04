/// FitAI Workout Plan Screen
///
/// Personalized workout and daily routine planner. Allows users to:
/// - View and edit their daily routine
/// - Get AI analysis of routine issues
/// - Generate next-day personalized workout plans
/// - View completed and upcoming plans
library;

import 'package:flutter/material.dart';

import '../app/app_localizations.dart' show L;
import '../core/food_data.dart';
import '../core/pose_analyzer.dart';
import '../core/user_profile_service.dart';
import '../core/workout_planner_engine.dart';
import '../exercise_library.dart';
import 'form_check_screen.dart';

class WorkoutPlanScreen extends StatefulWidget {
  const WorkoutPlanScreen({super.key});

  @override
  State<WorkoutPlanScreen> createState() => _WorkoutPlanScreenState();
}

class _WorkoutPlanScreenState extends State<WorkoutPlanScreen> {
  final WorkoutPlannerEngine _engine = WorkoutPlannerEngine.instance;
  final UserProfileService _profileService = UserProfileService.instance;

  UserProfile _profile = const UserProfile();
  UserRoutine _routine = const UserRoutine();
  List<DailyPlan> _plans = [];
  RoutineAnalysis? _analysis;

  bool _isLoading = true;
  bool _isAnalyzing = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _profile = await _profileService.load();
    _routine = await _engine.loadRoutine();
    _plans = await _engine.loadPlans();

    setState(() => _isLoading = false);
  }

  Future<void> _analyzeRoutine() async {
    setState(() => _isAnalyzing = true);

    _analysis = await _engine.analyzeRoutine(_routine, _profile);

    setState(() => _isAnalyzing = false);
  }

  Future<void> _generateNextDayPlan() async {
    if (!_profile.isComplete) {
      _showProfileIncompleteDialog();
      return;
    }

    setState(() => _isGenerating = true);

    final plan = await _engine.generateNextDayPlan(_profile, _routine);
    await _engine.addPlan(plan);
    _plans = await _engine.loadPlans();

    setState(() => _isGenerating = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.t('planGenerated')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showProfileIncompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.t('profileIncomplete')),
        content: Text(L.t('profileIncompleteMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L.t('ok')),
          ),
        ],
      ),
    );
  }

  void _editRoutine() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditRoutineScreen(
          routine: _routine,
          onSave: (routine) async {
            await _engine.saveRoutine(routine);
            await _loadData();
          },
        ),
      ),
    );
  }

  void _viewPlan(DailyPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlanDetailView(plan: plan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('myWorkoutPlan'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileSummary(),
          const SizedBox(height: 20),
          _buildRoutineSection(),
          const SizedBox(height: 20),
          _buildPlansSection(),
        ],
      ),
    );
  }

  Widget _buildProfileSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  L.t('yourProfile'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: _editProfile,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_profile.name.isNotEmpty)
            _profileRow(L.t('name'), _profile.name),
          if (_profile.age.isNotEmpty)
            _profileRow(L.t('age'), '${_profile.age} ${L.t("years")}'),
          if (_profile.height.isNotEmpty)
            _profileRow(L.t('height'), '${_profile.height} cm'),
          if (_profile.weight.isNotEmpty)
            _profileRow(L.t('weight'), '${_profile.weight} kg'),
          _profileRow(L.t('goal'), _profile.goal),
          _profileRow(L.t('gender'), _profile.gender.name),
          if (_profile.healthConditionNames.isNotEmpty)
            _profileRow(
              L.t('healthConditions'),
              _profile.healthConditionNames
                  .map((n) => L.t('health_$n'))
                  .join(', '),
            ),
          _profileRow(L.t('workoutLocation'), _profile.workoutLocation),
          _profileRow(L.t('experience'), _profile.experience),
          _profileRow(L.t('equipment'), _profile.equipment),
          _profileRow('Activity Level', _profile.activity.label),
          _profileRow('Diet', _profile.dietaryPreference),
          _profileRow(
            L.t('availability'),
            '${_profile.daysPerWeek} ${L.t("daysPerWeek")}, ${_profile.minutesPerSession} ${L.t("minutes")}',
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile() async {
    final goalCtrl = TextEditingController(text: _profile.goal);
    final daysCtrl = TextEditingController(text: _profile.daysPerWeek);
    final minutesCtrl = TextEditingController(text: _profile.minutesPerSession);
    String selectedExperience = _profile.experience;
    String selectedEquipment = _profile.equipment;
    String selectedActivityLevel = _profile.activityLevelName;
    String selectedDietaryPreference = _profile.dietaryPreference;
    String selectedGender = _profile.genderName;
    String selectedLocation = _profile.workoutLocation;
    List<String> selectedHealthConditions =
        List<String>.from(_profile.healthConditionNames);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(L.t('editProfile')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: goalCtrl,
                  decoration: InputDecoration(
                    labelText: L.t('goal'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedGender,
                  decoration: InputDecoration(
                    labelText: L.t('gender'),
                    border: const OutlineInputBorder(),
                  ),
                  items: ['male', 'female', 'other']
                      .map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(g == 'male'
                                ? L.t('male')
                                : g == 'female'
                                    ? L.t('female')
                                    : L.t('preferNotToSay')),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedGender = v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedLocation,
                  decoration: InputDecoration(
                    labelText: L.t('workoutLocation'),
                    border: const OutlineInputBorder(),
                  ),
                  items: ['Home', 'Gym', 'Outdoor']
                      .map((loc) => DropdownMenuItem(
                            value: loc,
                            child: Text(loc == 'Home'
                                ? L.t('home')
                                : loc == 'Gym'
                                    ? L.t('gym')
                                    : L.t('outdoor')),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedLocation = v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final allConditions = HealthCondition.values
                        .where((c) => c != HealthCondition.none)
                        .toList();
                    final result = await showDialog<List<String>>(
                      context: context,
                      builder: (hCtx) {
                        return StatefulBuilder(
                          builder: (hCtx, setHState) {
                            return AlertDialog(
                              title: Text(L.t('selectHealthConditions')),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: allConditions.map((c) {
                                    return CheckboxListTile(
                                      title: Text(L.t('health_${c.name}')),
                                      value: selectedHealthConditions
                                          .contains(c.name),
                                      onChanged: (checked) {
                                        setHState(() {
                                          if (checked == true) {
                                            selectedHealthConditions
                                                .add(c.name);
                                          } else {
                                            selectedHealthConditions
                                                .remove(c.name);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(hCtx, <String>[]),
                                  child: Text(L.t('cancel')),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(
                                    hCtx,
                                    List<String>.from(selectedHealthConditions),
                                  ),
                                  child: Text(L.t('save')),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                    if (result != null) {
                      setDialogState(
                        () => selectedHealthConditions = result,
                      );
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: L.t('healthConditions'),
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(
                      selectedHealthConditions.isEmpty
                          ? L.t('health_none')
                          : selectedHealthConditions
                              .map((n) => L.t('health_$n'))
                              .join(', '),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedExperience,
                  decoration: InputDecoration(
                    labelText: L.t('experience'),
                    border: const OutlineInputBorder(),
                  ),
                  items: ['Beginner', 'Intermediate', 'Advanced']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedExperience = v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedEquipment,
                  decoration: InputDecoration(
                    labelText: L.t('equipment'),
                    border: const OutlineInputBorder(),
                  ),
                  items: ['None', 'Home', 'Gym', 'Outdoor']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedEquipment = v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedActivityLevel,
                  decoration: const InputDecoration(
                    labelText: 'Activity Level',
                    border: OutlineInputBorder(),
                  ),
                  items: ['sedentary', 'light', 'moderate', 'active', 'athlete']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedActivityLevel = v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedDietaryPreference,
                  decoration: const InputDecoration(
                    labelText: 'Dietary Preference',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'No preference',
                    'Vegetarian',
                    'Vegan',
                    'Keto',
                    'Paleo',
                    'Halal',
                  ]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedDietaryPreference = v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: daysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: L.t('daysPerWeek'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: minutesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: L.t('minutes'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L.t('save')),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      // Capture controller values before they might be disposed
      final goalText = goalCtrl.text.trim();
      final daysText = daysCtrl.text.trim();
      final minutesText = minutesCtrl.text.trim();
      
      debugPrint('Profile save: goal=$goalText, days=$daysText, minutes=$minutesText');
      debugPrint('Profile save: experience=$selectedExperience, equipment=$selectedEquipment');
      debugPrint('Profile save: activity=$selectedActivityLevel, diet=$selectedDietaryPreference');
      
      final updated = UserProfile(
        name: _profile.name,
        age: _profile.age,
        height: _profile.height,
        weight: _profile.weight,
        goal: goalText.isNotEmpty ? goalText : _profile.goal,
        activityLevelName: selectedActivityLevel,
        experience: selectedExperience,
        equipment: selectedEquipment,
        daysPerWeek: daysText.isNotEmpty ? daysText : _profile.daysPerWeek,
        minutesPerSession:
            minutesText.isNotEmpty ? minutesText : _profile.minutesPerSession,
        dietaryPreference: selectedDietaryPreference,
        language: _profile.language,
        genderName: selectedGender,
        healthConditionNames: selectedHealthConditions,
        workoutLocation: selectedLocation,
        preferredDays: _profile.preferredDays,
      );
      
      debugPrint('Profile save: calling _profileService.save()');
      await _profileService.save(updated);
      debugPrint('Profile save: save completed, calling _loadData()');
      await _loadData();
      debugPrint('Profile save: loadData completed, new profile goal=${_profile.goal}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      debugPrint('Profile save: dialog returned $saved (not true)');
    }

    goalCtrl.dispose();
    daysCtrl.dispose();
    minutesCtrl.dispose();
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                L.t('dailyRoutine'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editRoutine,
                tooltip: L.t('editRoutine'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_routine.isEmpty)
            Text(
              L.t('noRoutineSet'),
              style: TextStyle(color: Colors.grey.shade600),
            )
          else ...[
            if (_routine.wakeTime.isNotEmpty)
              _routineRow(L.t('wakeTime'), _routine.wakeTime),
            if (_routine.sleepTime.isNotEmpty)
              _routineRow(L.t('sleepTime'), _routine.sleepTime),
            if (_routine.workSchedule.isNotEmpty)
              _routineRow(L.t('workSchedule'), _routine.workSchedule),
            if (_routine.mealTimes.isNotEmpty)
              _routineRow(L.t('mealTimes'), _routine.mealTimes),
            if (_routine.freeTime.isNotEmpty)
              _routineRow(L.t('freeTime'), _routine.freeTime),
            if (_routine.workoutTimePreference.isNotEmpty)
              _routineRow(L.t('workoutTime'), _routine.workoutTimePreference),
            if (_routine.notes.isNotEmpty)
              _routineRow(L.t('notes'), _routine.notes),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.analytics),
                  label: Text(L.t('analyzeRoutine')),
                  onPressed: _isAnalyzing ? null : _analyzeRoutine,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(L.t('createNextDayPlan')),
                  onPressed: _isGenerating ? null : _generateNextDayPlan,
                ),
              ),
            ],
          ),
          if (_analysis != null) ...[
            const SizedBox(height: 16),
            _buildAnalysisCard(),
          ],
        ],
      ),
    );
  }

  Widget _routineRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  L.t('routineAnalysis'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (_analysis!.isAiGenerated)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    L.t('appGenerated'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_analysis!.issues.isNotEmpty) ...[
            Text(
              L.t('issuesFound'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ..._analysis!.issues.asMap().entries.map((entry) {
              final index = entry.key;
              final issue = entry.value;
              return _buildIssueCard(issue, index + 1, colorScheme);
            }),
            const SizedBox(height: 12),
          ],
          if (_analysis!.suggestions.isNotEmpty) ...[
            Text(
              L.t('suggestions'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ..._analysis!.suggestions.map(
              (suggestion) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: colorScheme.primary)),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIssueCard(
    RoutineIssue issue,
    int number,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#$number',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${L.t("problem")}: ${issue.problem}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 16,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${L.t("correction")}: ${issue.correction}',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${L.t("reason")}: ${issue.reason}',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlansSection() {
    final today = DateTime.now();
    final upcomingPlans = _plans
        .where((p) => p.date.isAfter(today.subtract(const Duration(days: 1))))
        .toList();
    final pastPlans = _plans
        .where((p) => p.date.isBefore(today.subtract(const Duration(days: 1))))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L.t('upcomingPlans'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (upcomingPlans.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              L.t('noUpcomingPlans'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          ...upcomingPlans.map((plan) => _buildPlanCard(plan)),
        const SizedBox(height: 20),
        if (pastPlans.isNotEmpty) ...[
          Text(
            L.t('pastWorkouts'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...pastPlans.take(5).map((plan) => _buildPlanCard(plan)),
        ],
      ],
    );
  }

  Widget _buildPlanCard(DailyPlan plan) {
    final isToday =
        plan.date.year == DateTime.now().year &&
        plan.date.month == DateTime.now().month &&
        plan.date.day == DateTime.now().day;

    final isTomorrow =
        plan.date.year == DateTime.now().add(const Duration(days: 1)).year &&
        plan.date.month == DateTime.now().add(const Duration(days: 1)).month &&
        plan.date.day == DateTime.now().add(const Duration(days: 1)).day;

    String dateLabel;
    if (isToday) {
      dateLabel = L.t('today');
    } else if (isTomorrow) {
      dateLabel = L.t('tomorrow');
    } else {
      dateLabel = '${plan.date.day}/${plan.date.month}/${plan.date.year}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: plan.completed ? Colors.green : Colors.deepPurple,
          child: Icon(
            plan.completed ? Icons.check : Icons.fitness_center,
            color: Colors.white,
          ),
        ),
        title: Text(dateLabel),
        subtitle: Text('${plan.exercises.length} ${L.t("exercises")}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _viewPlan(plan),
      ),
    );
  }
}

// -------------------------------------------------------------------
// EDIT ROUTINE SCREEN
// -------------------------------------------------------------------

class EditRoutineScreen extends StatefulWidget {
  final UserRoutine routine;
  final Future<void> Function(UserRoutine) onSave;

  const EditRoutineScreen({
    super.key,
    required this.routine,
    required this.onSave,
  });

  @override
  State<EditRoutineScreen> createState() => _EditRoutineScreenState();
}

class _EditRoutineScreenState extends State<EditRoutineScreen> {
  late TextEditingController _wakeTimeController;
  late TextEditingController _sleepTimeController;
  late TextEditingController _workScheduleController;
  late TextEditingController _mealTimesController;
  late TextEditingController _freeTimeController;
  late TextEditingController _workoutTimeController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _wakeTimeController = TextEditingController(text: widget.routine.wakeTime);
    _sleepTimeController = TextEditingController(
      text: widget.routine.sleepTime,
    );
    _workScheduleController = TextEditingController(
      text: widget.routine.workSchedule,
    );
    _mealTimesController = TextEditingController(
      text: widget.routine.mealTimes,
    );
    _freeTimeController = TextEditingController(text: widget.routine.freeTime);
    _workoutTimeController = TextEditingController(
      text: widget.routine.workoutTimePreference,
    );
    _notesController = TextEditingController(text: widget.routine.notes);
  }

  @override
  void dispose() {
    _wakeTimeController.dispose();
    _sleepTimeController.dispose();
    _workScheduleController.dispose();
    _mealTimesController.dispose();
    _freeTimeController.dispose();
    _workoutTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final routine = UserRoutine(
      wakeTime: _wakeTimeController.text,
      sleepTime: _sleepTimeController.text,
      workSchedule: _workScheduleController.text,
      mealTimes: _mealTimesController.text,
      freeTime: _freeTimeController.text,
      workoutTimePreference: _workoutTimeController.text,
      notes: _notesController.text,
    );

    await widget.onSave(routine);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('editRoutine')),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L.t('editRoutineDescription'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _wakeTimeController,
              label: L.t('wakeTime'),
              hint: L.t('wakeTimeHint'),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _sleepTimeController,
              label: L.t('sleepTime'),
              hint: L.t('sleepTimeHint'),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _workScheduleController,
              label: L.t('workSchedule'),
              hint: L.t('workScheduleHint'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _mealTimesController,
              label: L.t('mealTimes'),
              hint: L.t('mealTimesHint'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _freeTimeController,
              label: L.t('freeTime'),
              hint: L.t('freeTimeHint'),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _workoutTimeController,
              label: L.t('workoutTime'),
              hint: L.t('workoutTimeHint'),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _notesController,
              label: L.t('notes'),
              hint: L.t('notesHint'),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(L.t('saveRoutine')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// -------------------------------------------------------------------
// PLAN DETAIL VIEW
// -------------------------------------------------------------------

class PlanDetailView extends StatefulWidget {
  final DailyPlan plan;

  const PlanDetailView({super.key, required this.plan});

  @override
  State<PlanDetailView> createState() => _PlanDetailViewState();
}

class _PlanDetailViewState extends State<PlanDetailView> {
  DailyPlan get plan => widget.plan;

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${plan.date.day}/${plan.date.month}/${plan.date.year}';

    return Scaffold(
      appBar: AppBar(title: Text(dateLabel)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.completed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      L.t('workoutCompleted'),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _buildSection(
              L.t('warmup'),
              plan.warmup,
              Icons.wb_sunny,
              Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              L.t('exercises'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...plan.exercises.map((exercise) => _buildExerciseCard(exercise)),
            if (plan.meals.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                L.t('mealSuggestions'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...plan.meals.map((meal) => _buildMealCard(meal)),
            ],
            const SizedBox(height: 16),
            _buildSection(
              L.t('cooldown'),
              plan.cooldown,
              Icons.bedtime,
              Colors.blue,
            ),
            if (plan.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection(L.t('notes'), plan.notes, Icons.note, Colors.grey),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(PlannedExercise exercise) {
    final libExercise = ExerciseLibrary.findCameraExercise(exercise.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.blue, size: 22),
                  tooltip: L.t('formCheck'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final type = libExercise?.poseExerciseType;
                    ExerciseType? exerciseType;
                    if (type != null) {
                      for (final t in ExerciseType.values) {
                        if (t.name == type) {
                          exerciseType = t;
                          break;
                        }
                      }
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FormCheckScreen(
                          initialExercise: exerciseType ?? ExerciseType.generic,
                          exerciseName: exercise.name,
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    exercise.muscleGroup,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStat(
                  Icons.format_list_numbered,
                  '${exercise.sets} ${L.t("sets")}',
                ),
                const SizedBox(width: 16),
                _buildStat(Icons.repeat, '${exercise.reps} ${L.t("reps")}'),
                const SizedBox(width: 16),
                _buildStat(
                  Icons.timer,
                  '${exercise.restSeconds}s ${L.t("rest")}',
                ),
              ],
            ),
            if (exercise.instructions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                exercise.instructions,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  ExerciseType? _parseExerciseType(String? name) {
    if (name == null) return null;
    for (final type in ExerciseType.values) {
      if (type.name == name) return type;
    }
    return null;
  }

  Widget _buildMealCard(PlannedMeal meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    meal.foodName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    meal.mealType,
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStat(
                  Icons.local_fire_department,
                  '${meal.calories} kcal',
                ),
                const SizedBox(width: 16),
                _buildStat(
                  Icons.fitness_center,
                  '${meal.protein.toStringAsFixed(1)}g protein',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${L.t("serving")}: ${meal.serving}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(L.t('findAlternative')),
                onPressed: () => _showFoodAlternative(meal),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFoodAlternative(PlannedMeal currentMeal) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.t('findAlternative')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${L.t("currentFood")}: ${currentMeal.foodName}'),
            const SizedBox(height: 16),
            Text(L.t('whyAlternative')),
            const SizedBox(height: 8),
            _buildReasonOption(L.t('dontLikeIt')),
            _buildReasonOption(L.t('notAvailable')),
            _buildReasonOption(L.t('vegetarian')),
            _buildReasonOption(L.t('allergy')),
            _buildReasonOption(L.t('other')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L.t('cancel')),
          ),
        ],
      ),
    );

    if (reason == null || !mounted) return;

    // Find alternative from food database
    final alternative = await _findFoodAlternative(currentMeal, reason);

    if (!mounted) return;

    if (alternative != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(L.t('alternativeFound')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${L.t("original")}: ${currentMeal.foodName}'),
              const SizedBox(height: 8),
              Text('${L.t("alternative")}: ${alternative.name}'),
              const SizedBox(height: 8),
              Text('${L.t("serving")}: ${alternative.serving}'),
              const SizedBox(height: 8),
              Text(
                '${alternative.calories} kcal | ${alternative.protein.toStringAsFixed(1)}g protein',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(L.t('ok')),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(L.t('noAlternativeFound')),
          content: Text(L.t('noSuitableAlternative')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(L.t('ok')),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildReasonOption(String reason) {
    return InkWell(
      onTap: () => Navigator.pop(context, reason),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(reason),
      ),
    );
  }

  Future<FoodItem?> _findFoodAlternative(
    PlannedMeal currentMeal,
    String reason,
  ) async {
    // Search in FoodDatabase for similar items
    final allFoods = FoodDatabase.items;

    // Filter based on reason
    List<FoodItem> candidates = [];

    if (reason == L.t('vegetarian')) {
      // Filter for vegetarian options
      candidates = allFoods.where((food) {
        final name = food.name.toLowerCase();
        return !name.contains('chicken') &&
            !name.contains('fish') &&
            !name.contains('meat') &&
            !name.contains('egg');
      }).toList();
    } else if (reason == L.t('allergy')) {
      // For allergies, we can't safely recommend without knowing the specific allergy
      // Return null to indicate we can't safely recommend
      return null;
    } else {
      // For other reasons, find similar foods by calories and macros
      candidates = allFoods.where((food) {
        final calorieDiff = (food.calories - currentMeal.calories).abs();
        return calorieDiff < 100; // Within 100 calories
      }).toList();
    }

    if (candidates.isEmpty) return null;

    // Find the closest match by calories
    candidates.sort((a, b) {
      final diffA = (a.calories - currentMeal.calories).abs();
      final diffB = (b.calories - currentMeal.calories).abs();
      return diffA.compareTo(diffB);
    });

    // Return the closest match that's not the same food
    for (final candidate in candidates) {
      if (candidate.name.toLowerCase() != currentMeal.foodName.toLowerCase()) {
        return candidate;
      }
    }

    return candidates.first;
  }
}
