/// FitAI Exercise Library
///
/// Central exercise catalogue used by the workout planner and workout UI.
/// Includes general fitness exercises and a dedicated Women's Wellness
/// collection.
///
/// IMPORTANT:
/// Being present in this library does NOT automatically mean an exercise
/// supports live camera rep counting. Camera-supported exercises are marked
/// explicitly with [cameraSupported].

library;

import 'core/pose_analyzer.dart' show ExerciseType;

// ============================================================================
// MODELS
// ============================================================================

enum ExerciseCategory {
  strength,
  cardio,
  core,
  mobility,
  flexibility,
  balance,
  upperBody,
  lowerBody,
  fullBody,
  womensWellness,
}

enum ExerciseDifficulty { beginner, intermediate, advanced }

class LibraryExercise {
  final String id;
  final String name;
  final String description;
  final String muscleGroup;
  final ExerciseCategory category;
  final ExerciseDifficulty difficulty;

  /// Whether the current ML Kit pose analyzer can actually count this
  /// exercise using the live camera.
  final bool cameraSupported;

  /// The ExerciseType name used by pose_analyzer.dart when supported.
  /// Null means there is currently no live-camera implementation.
  final String? poseExerciseType;

  final int defaultSets;
  final int defaultReps;
  final int defaultRestSeconds;
  final String instructions;

  /// True for exercises specifically intended for the Women's Wellness
  /// section of the library.
  final bool womensWellness;

  const LibraryExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.muscleGroup,
    required this.category,
    required this.difficulty,
    required this.cameraSupported,
    required this.poseExerciseType,
    required this.defaultSets,
    required this.defaultReps,
    required this.defaultRestSeconds,
    required this.instructions,
    required this.womensWellness,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'muscleGroup': muscleGroup,
      'category': category.name,
      'difficulty': difficulty.name,
      'cameraSupported': cameraSupported,
      'poseExerciseType': poseExerciseType,
      'defaultSets': defaultSets,
      'defaultReps': defaultReps,
      'defaultRestSeconds': defaultRestSeconds,
      'instructions': instructions,
      'womensWellness': womensWellness,
    };
  }

  factory LibraryExercise.fromJson(Map<String, dynamic> json) {
    ExerciseCategory parseCategory(String? value) {
      return ExerciseCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ExerciseCategory.fullBody,
      );
    }

    ExerciseDifficulty parseDifficulty(String? value) {
      return ExerciseDifficulty.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ExerciseDifficulty.beginner,
      );
    }

    return LibraryExercise(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      muscleGroup: json['muscleGroup'] as String? ?? '',
      category: parseCategory(json['category'] as String?),
      difficulty: parseDifficulty(json['difficulty'] as String?),
      cameraSupported: json['cameraSupported'] as bool? ?? false,
      poseExerciseType: json['poseExerciseType'] as String?,
      defaultSets: (json['defaultSets'] as num?)?.toInt() ?? 3,
      defaultReps: (json['defaultReps'] as num?)?.toInt() ?? 10,
      defaultRestSeconds: (json['defaultRestSeconds'] as num?)?.toInt() ?? 60,
      instructions: json['instructions'] as String? ?? '',
      womensWellness: json['womensWellness'] as bool? ?? false,
    );
  }
}

// ============================================================================
// EXERCISE LIBRARY
// ============================================================================

class ExerciseLibrary {
  ExerciseLibrary._();

  static final ExerciseLibrary instance = ExerciseLibrary._();

  // --------------------------------------------------------------------------
  // GENERAL FITNESS EXERCISES
  // --------------------------------------------------------------------------

  static const List<LibraryExercise> generalExercises = [
    // =========================
    // CAMERA SUPPORTED
    // =========================
    LibraryExercise(
      id: 'squat',
      name: 'Squat',
      description: 'Bodyweight squat with controlled depth and standing phase.',
      muscleGroup: 'Legs & Glutes',
      category: ExerciseCategory.lowerBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: true,
      poseExerciseType: 'squat',
      defaultSets: 3,
      defaultReps: 10,
      defaultRestSeconds: 60,
      instructions:
          'Stand tall, lower with control, keep your chest up, then stand tall.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'pushup',
      name: 'Push-up',
      description: 'Upper-body pushing exercise using bodyweight.',
      muscleGroup: 'Chest, Shoulders & Triceps',
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: true,
      poseExerciseType: 'pushup',
      defaultSets: 3,
      defaultReps: 10,
      defaultRestSeconds: 60,
      instructions:
          'Keep your body aligned and lower and raise yourself with control.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'bicep_curl',
      name: 'Bicep Curl',
      description: 'Controlled arm curl targeting the biceps.',
      muscleGroup: 'Biceps',
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: true,
      poseExerciseType: 'bicepCurl',
      defaultSets: 3,
      defaultReps: 10,
      defaultRestSeconds: 60,
      instructions:
          'Keep elbows close to your body and curl with controlled movement.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'shoulder_press',
      name: 'Shoulder Press',
      description: 'Pressing movement for the shoulders and upper body.',
      muscleGroup: 'Shoulders',
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: true,
      poseExerciseType: 'shoulderPress',
      defaultSets: 3,
      defaultReps: 10,
      defaultRestSeconds: 60,
      instructions: 'Keep your core stable and press upward without rushing.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'lunge',
      name: 'Lunge',
      description: 'Single-leg lower-body movement.',
      muscleGroup: 'Legs & Glutes',
      category: ExerciseCategory.lowerBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: true,
      poseExerciseType: 'lunge',
      defaultSets: 3,
      defaultReps: 10,
      defaultRestSeconds: 60,
      instructions:
          'Step forward, lower with control, then return to the starting position.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'jumping_jack',
      name: 'Jumping Jack',
      description: 'Full-body cardio movement.',
      muscleGroup: 'Full Body',
      category: ExerciseCategory.cardio,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: true,
      poseExerciseType: 'jumpingJack',
      defaultSets: 3,
      defaultReps: 20,
      defaultRestSeconds: 45,
      instructions:
          'Move arms and legs rhythmically while maintaining controlled landings.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'plank',
      name: 'Plank',
      description: 'Isometric core exercise.',
      muscleGroup: 'Core',
      category: ExerciseCategory.core,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: true,
      poseExerciseType: 'plank',
      defaultSets: 3,
      defaultReps: 30,
      defaultRestSeconds: 45,
      instructions:
          'Keep your body aligned and brace your core while holding the position.',
      womensWellness: false,
    ),

    // =========================
    // LOWER BODY
    // =========================
    LibraryExercise(
      id: 'glute_bridge',
      name: 'Glute Bridge',
      description: 'Floor-based exercise targeting the glutes and hips.',
      muscleGroup: 'Glutes & Hips',
      category: ExerciseCategory.lowerBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 12,
      defaultRestSeconds: 45,
      instructions:
          'Lie on your back, bend your knees, lift your hips with control, then lower.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'calf_raise',
      name: 'Calf Raise',
      description: 'Standing exercise for the calf muscles.',
      muscleGroup: 'Calves',
      category: ExerciseCategory.lowerBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 15,
      defaultRestSeconds: 45,
      instructions: 'Rise onto the balls of your feet and lower slowly.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'wall_sit',
      name: 'Wall Sit',
      description: 'Isometric lower-body exercise.',
      muscleGroup: 'Quads & Glutes',
      category: ExerciseCategory.lowerBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 30,
      defaultRestSeconds: 60,
      instructions:
          'Lean against a wall and hold a comfortable seated position.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'step_up',
      name: 'Step-up',
      description: 'Alternating step movement targeting the legs.',
      muscleGroup: 'Legs & Glutes',
      category: ExerciseCategory.lowerBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 10,
      defaultRestSeconds: 60,
      instructions: 'Step onto a stable platform and return with control.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'sumo_squat',
      name: 'Sumo Squat',
      description: 'Wide-stance squat variation.',
      muscleGroup: 'Glutes, Quads & Inner Thighs',
      category: ExerciseCategory.lowerBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 12,
      defaultRestSeconds: 60,
      instructions:
          'Use a comfortable wide stance and lower while keeping your chest upright.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'reverse_lunge',
      name: 'Reverse Lunge',
      description: 'Controlled backward lunge variation.',
      muscleGroup: 'Legs & Glutes',
      category: ExerciseCategory.lowerBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 10,
      defaultRestSeconds: 60,
      instructions:
          'Step backward, lower under control, then return to standing.',
      womensWellness: false,
    ),

    // =========================
    // UPPER BODY
    // =========================
    LibraryExercise(
      id: 'tricep_dip',
      name: 'Tricep Dip',
      description: 'Bodyweight pushing movement for the back of the arms.',
      muscleGroup: 'Triceps',
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.intermediate,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 8,
      defaultRestSeconds: 60,
      instructions:
          'Use a stable surface and lower and raise yourself with control.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'incline_pushup',
      name: 'Incline Push-up',
      description:
          'Beginner-friendly push-up variation using an elevated surface.',
      muscleGroup: 'Chest & Triceps',
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 10,
      defaultRestSeconds: 60,
      instructions:
          'Keep your body straight and lower your chest toward the stable surface.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'chest_press',
      name: 'Chest Press',
      description: 'Resistance exercise for the chest.',
      muscleGroup: 'Chest & Triceps',
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 10,
      defaultRestSeconds: 60,
      instructions:
          'Press the resistance away from your body with controlled movement.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'lateral_raise',
      name: 'Lateral Raise',
      description: 'Shoulder isolation movement.',
      muscleGroup: 'Shoulders',
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 12,
      defaultRestSeconds: 45,
      instructions: 'Raise your arms to a comfortable height without swinging.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'front_raise',
      name: 'Front Raise',
      description: 'Controlled shoulder exercise.',
      muscleGroup: 'Front Shoulders',
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 12,
      defaultRestSeconds: 45,
      instructions:
          'Lift your arms forward smoothly and lower them under control.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'bent_over_row',
      name: 'Bent-over Row',
      description: 'Back-focused pulling movement.',
      muscleGroup: 'Back & Biceps',
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 12,
      defaultRestSeconds: 60,
      instructions: 'Keep your back comfortable and pull your elbows backward.',
      womensWellness: false,
    ),

    // =========================
    // CORE
    // =========================
    LibraryExercise(
      id: 'dead_bug',
      name: 'Dead Bug',
      description: 'Controlled core stability exercise.',
      muscleGroup: 'Core',
      category: ExerciseCategory.core,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 10,
      defaultRestSeconds: 45,
      instructions:
          'Move opposite arm and leg slowly while keeping your core controlled.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'bird_dog',
      name: 'Bird Dog',
      description: 'Core stability and balance exercise.',
      muscleGroup: 'Core & Back',
      category: ExerciseCategory.core,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 10,
      defaultRestSeconds: 45,
      instructions:
          'From a hands-and-knees position, extend opposite arm and leg with control.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'mountain_climber',
      name: 'Mountain Climber',
      description: 'Dynamic cardio and core exercise.',
      muscleGroup: 'Core & Full Body',
      category: ExerciseCategory.cardio,
      difficulty: ExerciseDifficulty.intermediate,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 20,
      defaultRestSeconds: 45,
      instructions: 'Maintain a stable upper body while alternating your legs.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'bicycle_crunch',
      name: 'Bicycle Crunch',
      description: 'Core exercise with alternating trunk movement.',
      muscleGroup: 'Core',
      category: ExerciseCategory.core,
      difficulty: ExerciseDifficulty.intermediate,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 12,
      defaultRestSeconds: 45,
      instructions: 'Move slowly and focus on controlled core engagement.',
      womensWellness: false,
    ),

    // =========================
    // CARDIO / FULL BODY
    // =========================
    LibraryExercise(
      id: 'high_knees',
      name: 'High Knees',
      description: 'Cardio movement performed in place.',
      muscleGroup: 'Full Body',
      category: ExerciseCategory.cardio,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 30,
      defaultRestSeconds: 45,
      instructions:
          'Alternate knees at a comfortable pace and land with control.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'butt_kicks',
      name: 'Butt Kicks',
      description: 'Light cardio movement performed in place.',
      muscleGroup: 'Legs',
      category: ExerciseCategory.cardio,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 30,
      defaultRestSeconds: 45,
      instructions:
          'Alternate your heels toward the back while maintaining balance.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'march_in_place',
      name: 'March in Place',
      description: 'Low-impact cardio and warm-up movement.',
      muscleGroup: 'Full Body',
      category: ExerciseCategory.cardio,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 60,
      defaultRestSeconds: 30,
      instructions:
          'March comfortably in place while moving your arms naturally.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'burpee',
      name: 'Burpee',
      description: 'Full-body conditioning exercise.',
      muscleGroup: 'Full Body',
      category: ExerciseCategory.fullBody,
      difficulty: ExerciseDifficulty.advanced,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 3,
      defaultReps: 8,
      defaultRestSeconds: 90,
      instructions:
          'Perform each phase under control and choose a suitable pace.',
      womensWellness: false,
    ),

    // =========================
    // MOBILITY / FLEXIBILITY
    // =========================
    LibraryExercise(
      id: 'cat_cow',
      name: 'Cat-Cow',
      description: 'Gentle spinal mobility movement.',
      muscleGroup: 'Back & Core',
      category: ExerciseCategory.mobility,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 10,
      defaultRestSeconds: 30,
      instructions: 'Move slowly between the two comfortable spinal positions.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'hip_circles',
      name: 'Hip Circles',
      description: 'Gentle hip mobility movement.',
      muscleGroup: 'Hips',
      category: ExerciseCategory.mobility,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 10,
      defaultRestSeconds: 30,
      instructions:
          'Make small controlled circles through a comfortable range of motion.',
      womensWellness: false,
    ),

    LibraryExercise(
      id: 'shoulder_circles',
      name: 'Shoulder Circles',
      description: 'Gentle shoulder mobility exercise.',
      muscleGroup: 'Shoulders',
      category: ExerciseCategory.mobility,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 10,
      defaultRestSeconds: 30,
      instructions: 'Move the shoulders slowly through a comfortable range.',
      womensWellness: false,
    ),
  ];

  // --------------------------------------------------------------------------
  // WOMEN'S WELLNESS EXERCISES
  // --------------------------------------------------------------------------

  static const List<LibraryExercise> womensWellnessExercises = [
    LibraryExercise(
      id: 'ww_glute_bridge',
      name: 'Glute Bridge',
      description:
          'Gentle hip and glute strengthening movement used in the Women’s Wellness collection.',
      muscleGroup: 'Glutes & Hips',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 10,
      defaultRestSeconds: 45,
      instructions:
          'Move slowly and comfortably. Stop if the movement causes pain or discomfort.',
      womensWellness: true,
    ),

    LibraryExercise(
      id: 'ww_bodyweight_squat',
      name: 'Women’s Wellness Squat',
      description:
          'Beginner-friendly squat included in the Women’s Wellness collection.',
      muscleGroup: 'Legs & Glutes',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: true,
      poseExerciseType: 'squat',
      defaultSets: 2,
      defaultReps: 10,
      defaultRestSeconds: 60,
      instructions:
          'Use a comfortable range of motion and keep the movement controlled.',
      womensWellness: true,
    ),

    LibraryExercise(
      id: 'ww_supported_lunge',
      name: 'Supported Lunge',
      description:
          'Controlled lunge variation with emphasis on balance and comfort.',
      muscleGroup: 'Legs & Glutes',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: true,
      poseExerciseType: 'lunge',
      defaultSets: 2,
      defaultReps: 8,
      defaultRestSeconds: 60,
      instructions:
          'Use support if needed and keep every repetition controlled.',
      womensWellness: true,
    ),

    LibraryExercise(
      id: 'ww_bird_dog',
      name: 'Women’s Wellness Bird Dog',
      description:
          'Core stability and balance movement for the Women’s Wellness section.',
      muscleGroup: 'Core & Back',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 8,
      defaultRestSeconds: 45,
      instructions:
          'Move slowly and maintain comfortable control throughout the exercise.',
      womensWellness: true,
    ),

    LibraryExercise(
      id: 'ww_dead_bug',
      name: 'Women’s Wellness Dead Bug',
      description: 'Gentle controlled core stability exercise.',
      muscleGroup: 'Core',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 8,
      defaultRestSeconds: 45,
      instructions:
          'Keep movements slow and controlled and work within a comfortable range.',
      womensWellness: true,
    ),

    LibraryExercise(
      id: 'ww_cat_cow',
      name: 'Women’s Wellness Cat-Cow',
      description: 'Gentle spinal mobility movement.',
      muscleGroup: 'Back & Core',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 8,
      defaultRestSeconds: 30,
      instructions:
          'Move gently between positions without forcing the range of motion.',
      womensWellness: true,
    ),

    LibraryExercise(
      id: 'ww_hip_mobility',
      name: 'Women’s Wellness Hip Mobility',
      description: 'Gentle hip mobility routine.',
      muscleGroup: 'Hips',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 8,
      defaultRestSeconds: 30,
      instructions:
          'Use slow, comfortable movements and avoid forcing the range.',
      womensWellness: true,
    ),

    LibraryExercise(
      id: 'ww_wall_sit',
      name: 'Women’s Wellness Wall Sit',
      description: 'Controlled lower-body isometric exercise.',
      muscleGroup: 'Quads & Glutes',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 20,
      defaultRestSeconds: 60,
      instructions:
          'Use a comfortable position and hold only as long as you can maintain good control.',
      womensWellness: true,
    ),

    LibraryExercise(
      id: 'ww_march',
      name: 'Women’s Wellness March',
      description: 'Low-impact movement suitable for gentle activity sessions.',
      muscleGroup: 'Full Body',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 30,
      defaultRestSeconds: 30,
      instructions:
          'March at a comfortable pace and adjust intensity to how you feel.',
      womensWellness: true,
    ),

    LibraryExercise(
      id: 'ww_shoulder_mobility',
      name: 'Women’s Wellness Shoulder Mobility',
      description: 'Gentle shoulder mobility movement.',
      muscleGroup: 'Shoulders',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 10,
      defaultRestSeconds: 30,
      instructions:
          'Move slowly through a comfortable range without forcing the joints.',
      womensWellness: true,
    ),

    LibraryExercise(
      id: 'ww_calf_raise',
      name: 'Women’s Wellness Calf Raise',
      description: 'Simple lower-leg strengthening movement.',
      muscleGroup: 'Calves',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 12,
      defaultRestSeconds: 45,
      instructions: 'Rise and lower slowly while maintaining balance.',
      womensWellness: true,
    ),

    LibraryExercise(
      id: 'ww_incline_pushup',
      name: 'Women’s Wellness Incline Push-up',
      description:
          'Beginner-friendly upper-body exercise using an elevated stable surface.',
      muscleGroup: 'Chest & Triceps',
      category: ExerciseCategory.womensWellness,
      difficulty: ExerciseDifficulty.beginner,
      cameraSupported: false,
      poseExerciseType: null,
      defaultSets: 2,
      defaultReps: 8,
      defaultRestSeconds: 60,
      instructions: 'Use a stable elevated surface and keep your body aligned.',
      womensWellness: true,
    ),
  ];

  // --------------------------------------------------------------------------
  // ALL EXERCISES
  // --------------------------------------------------------------------------

  List<LibraryExercise> get allExercises {
    return [...generalExercises, ...womensWellnessExercises];
  }

  List<LibraryExercise> get generalOnly {
    return generalExercises;
  }

  List<LibraryExercise> get womensWellnessOnly {
    return womensWellnessExercises;
  }

  // --------------------------------------------------------------------------
  // FIND / SEARCH
  // --------------------------------------------------------------------------

  LibraryExercise? findById(String id) {
    for (final exercise in allExercises) {
      if (exercise.id == id) {
        return exercise;
      }
    }
    return null;
  }

  LibraryExercise? findByName(String name) {
    final normalized = name.trim().toLowerCase();

    for (final exercise in allExercises) {
      if (exercise.name.toLowerCase() == normalized) {
        return exercise;
      }
    }

    return null;
  }

  List<LibraryExercise> search(String query) {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return allExercises;
    }

    return allExercises.where((exercise) {
      return exercise.name.toLowerCase().contains(q) ||
          exercise.description.toLowerCase().contains(q) ||
          exercise.muscleGroup.toLowerCase().contains(q) ||
          exercise.category.name.toLowerCase().contains(q);
    }).toList();
  }

  // --------------------------------------------------------------------------
  // FILTERS
  // --------------------------------------------------------------------------

  List<LibraryExercise> byCategory(ExerciseCategory category) {
    return allExercises
        .where((exercise) => exercise.category == category)
        .toList();
  }

  List<LibraryExercise> byDifficulty(ExerciseDifficulty difficulty) {
    return allExercises
        .where((exercise) => exercise.difficulty == difficulty)
        .toList();
  }

  List<LibraryExercise> cameraSupportedExercises() {
    return allExercises.where((exercise) => exercise.cameraSupported).toList();
  }

  // --------------------------------------------------------------------------
  // CAMERA SUPPORT
  // --------------------------------------------------------------------------

  bool supportsCamera(String exerciseName) {
    final exercise = findByName(exerciseName);

    return exercise?.cameraSupported ?? false;
  }

  String? poseTypeFor(String exerciseName) {
    final exercise = findByName(exerciseName);
    return exercise?.poseExerciseType;
  }

  // --------------------------------------------------------------------------
  // DEFAULT PLAN HELPERS
  // --------------------------------------------------------------------------

  List<LibraryExercise> beginnerExercises() {
    return allExercises
        .where((exercise) => exercise.difficulty == ExerciseDifficulty.beginner)
        .toList();
  }

  List<LibraryExercise> exercisesForWomenWellness() {
    return womensWellnessExercises;
  }

  List<LibraryExercise> exercisesForGoal(String goal) {
    final normalized = goal.toLowerCase();

    if (normalized.contains('strength') || normalized.contains('muscle')) {
      return allExercises.where((exercise) {
        return exercise.category == ExerciseCategory.strength ||
            exercise.category == ExerciseCategory.upperBody ||
            exercise.category == ExerciseCategory.lowerBody ||
            exercise.category == ExerciseCategory.fullBody;
      }).toList();
    }

    if (normalized.contains('cardio') ||
        normalized.contains('fitness') ||
        normalized.contains('endurance')) {
      return allExercises.where((exercise) {
        return exercise.category == ExerciseCategory.cardio ||
            exercise.category == ExerciseCategory.fullBody;
      }).toList();
    }

    if (normalized.contains('mobility') || normalized.contains('flexibility')) {
      return allExercises.where((exercise) {
        return exercise.category == ExerciseCategory.mobility ||
            exercise.category == ExerciseCategory.flexibility;
      }).toList();
    }

    return allExercises;
  }

  /// Centralized camera exercise registry.
  ///
  /// Given any exercise name (e.g. "Supported Squat", "Wall Push-Up"),
  /// returns the matching camera-supported [LibraryExercise], or null if
  /// no camera implementation exists for that exercise.
  static LibraryExercise? findCameraExercise(String name) {
    final normalized = name.trim().toLowerCase();
    final stripped = normalized
        .replaceAll(RegExp(r'^bodyweight\s+'), '')
        .replaceAll(RegExp(r'^dumbbell\s+'), '')
        .replaceAll(RegExp(r'^barbell\s+'), '')
        .replaceAll(RegExp(r'^kettlebell\s+'), '')
        .replaceAll(RegExp(r'^supported\s+'), '')
        .replaceAll(RegExp(r'^wall\s+'), '')
        .replaceAll(RegExp(r'^easy\s+'), '')
        .replaceAll(RegExp(r'^gentle\s+'), '')
        .replaceAll(RegExp(r'^light\s+'), '')
        .trim();

    for (final exercise in instance.allExercises) {
      if (!exercise.cameraSupported) continue;
      if (exercise.name.toLowerCase() == normalized) return exercise;
    }

    for (final exercise in instance.allExercises) {
      if (!exercise.cameraSupported) continue;
      if (exercise.name.toLowerCase() == stripped) return exercise;
    }

    for (final exercise in instance.allExercises) {
      if (!exercise.cameraSupported) continue;
      final libName = exercise.name.toLowerCase();
      final libSingular = libName.replaceAll(RegExp(r's$'), '');
      final strippedSingular = stripped.replaceAll(RegExp(r's$'), '');
      if (libSingular == strippedSingular) return exercise;
    }

    for (final exercise in instance.allExercises) {
      if (!exercise.cameraSupported) continue;
      final libName = exercise.name.toLowerCase();
      if (libName.contains(stripped) || stripped.contains(libName)) {
        return exercise;
      }
    }

    const keywords = <String, String>{
      'squat': 'squat',
      'squats': 'squat',
      'push': 'pushup',
      'pushup': 'pushup',
      'push-up': 'pushup',
      'push-ups': 'pushup',
      'curl': 'bicepCurl',
      'bicep': 'bicepCurl',
      'press': 'shoulderPress',
      'shoulder': 'shoulderPress',
      'lunge': 'lunge',
      'lunges': 'lunge',
      'jack': 'jumpingJack',
      'jumping': 'jumpingJack',
      'plank': 'plank',
    };

    for (final entry in keywords.entries) {
      if (stripped.contains(entry.key) || normalized.contains(entry.key)) {
        for (final exercise in instance.allExercises) {
          if (exercise.cameraSupported &&
              exercise.poseExerciseType == entry.value) {
            return exercise;
          }
        }
      }
    }

    return null;
  }

  /// Returns the [ExerciseType] for a camera-supported exercise name, or null.
  static ExerciseType? cameraExerciseType(String name) {
    return findCameraExercise(name)?.poseExerciseType != null
        ? ExerciseType.values.firstWhere(
            (t) => t.name == findCameraExercise(name)!.poseExerciseType,
            orElse: () => ExerciseType.generic,
          )
        : null;
  }
}

final exerciseLibrary = ExerciseLibrary.instance;
