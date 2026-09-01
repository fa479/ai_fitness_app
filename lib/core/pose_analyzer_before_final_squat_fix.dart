import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum ExerciseType {
  squat,
  pushup,
  bicepCurl,
  shoulderPress,
  lunge,
  jumpingJack,
  plank,
  generic;

  String get displayName {
    switch (this) {
      case ExerciseType.squat:
        return 'Squat';
      case ExerciseType.pushup:
        return 'Push-up';
      case ExerciseType.bicepCurl:
        return 'Bicep Curl';
      case ExerciseType.shoulderPress:
        return 'Shoulder Press';
      case ExerciseType.lunge:
        return 'Lunge';
      case ExerciseType.jumpingJack:
        return 'Jumping Jack';
      case ExerciseType.plank:
        return 'Plank Hold';
      case ExerciseType.generic:
        return 'Free Form';
    }
  }

  String get instruction {
    switch (this) {
      case ExerciseType.squat:
        return 'Stand sideways to the camera. Squat down, then stand up fully.';
      case ExerciseType.pushup:
        return 'Place the camera at floor level. Lower your body, then push back up.';
      case ExerciseType.bicepCurl:
        return 'Face the camera. Curl your arm up, then extend it fully.';
      case ExerciseType.shoulderPress:
        return 'Face the camera. Press your arms overhead, then lower them.';
      case ExerciseType.lunge:
        return 'Stand sideways. Lower into a lunge, then return to standing.';
      case ExerciseType.jumpingJack:
        return 'Keep your full body in frame. Raise your arms and spread your legs.';
      case ExerciseType.plank:
        return 'Use a side view. Keep your shoulders, hips and ankles aligned.';
      case ExerciseType.generic:
        return 'Move freely while your body is tracked.';
    }
  }
}

enum FormQuality {
  good,
  warning,
  poor,
  none,
}

class PoseAnalysis {
  final int reps;
  final double primaryAngle;
  final FormQuality formQuality;
  final String feedback;
  final bool bodyDetected;
  final ExerciseType exercise;
  final String formIssueKey;

  const PoseAnalysis({
    this.reps = 0,
    this.primaryAngle = 0,
    this.formQuality = FormQuality.none,
    this.feedback = '',
    this.bodyDetected = false,
    this.exercise = ExerciseType.generic,
    this.formIssueKey = '',
  });
}

double angleAt(
  PoseLandmark a,
  PoseLandmark b,
  PoseLandmark c,
) {
  final radians =
      math.atan2(c.y - b.y, c.x - b.x) -
      math.atan2(a.y - b.y, a.x - b.x);

  var degrees = (radians * 180 / math.pi).abs();

  if (degrees > 180) {
    degrees = 360 - degrees;
  }

  return degrees;
}

enum _RepPhase {
  up,
  down,
}

enum _SquatState {
  waiting,
  descending,
  bottom,
  rising,
}

class PoseAnalyzer {
  ExerciseType _exercise = ExerciseType.squat;

  int _reps = 0;
  _RepPhase _phase = _RepPhase.up;

  _SquatState _squatState = _SquatState.waiting;

  bool _wasStanding = false;
  int _standingFrames = 0;
  int _descentFrames = 0;

  // ---- Set tracking ----
  int _currentSet = 1;
  int _completedSets = 0;
  int _targetSets = 0;
  int _targetRepsPerSet = 0;
  bool _exerciseCompleted = false;

  static const int _requiredFrames = 4;
  static const double _minConfidence = 0.5;

  ExerciseType get exercise => _exercise;

  int get reps => _reps;
  int get currentSet => _currentSet;
  int get completedSets => _completedSets;
  int get targetSets => _targetSets;
  int get targetRepsPerSet => _targetRepsPerSet;
  bool get exerciseCompleted => _exerciseCompleted;

  void configureSets({required int targetSets, required int targetRepsPerSet}) {
    _targetSets = targetSets;
    _targetRepsPerSet = targetRepsPerSet;
    _currentSet = 1;
    _completedSets = 0;
    _exerciseCompleted = false;
  }

  void setExercise(ExerciseType type) {
    _exercise = type;
    reset();
  }

  void reset() {
    _reps = 0;
    _phase = _RepPhase.up;

    _squatState = _SquatState.waiting;

    _wasStanding = false;
    _standingFrames = 0;
    _descentFrames = 0;

    _currentSet = 1;
    _completedSets = 0;
    _exerciseCompleted = false;
  }

  /// Returns true when the current set has just been completed.
  bool _checkSetCompletion() {
    if (_targetRepsPerSet <= 0) return false;
    if (_reps < _targetRepsPerSet) return false;

    _completedSets = _currentSet;

    if (_currentSet >= _targetSets) {
      _exerciseCompleted = true;
    } else {
      _currentSet++;
    }

    _reps = 0;
    _phase = _RepPhase.up;
    return true;
  }

  PoseLandmark? _get(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmarkType type,
  ) {
    final landmark = landmarks[type];

    if (landmark == null) {
      return null;
    }

    if (landmark.likelihood < _minConfidence) {
      return null;
    }

    return landmark;
  }

  ({PoseLandmark a, PoseLandmark b, PoseLandmark c})? _bestJoint(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmarkType aLeft,
    PoseLandmarkType bLeft,
    PoseLandmarkType cLeft,
  ) {
    final a = _get(landmarks, aLeft);
    final b = _get(landmarks, bLeft);
    final c = _get(landmarks, cLeft);

    if (a != null && b != null && c != null) {
      return (a: a, b: b, c: c);
    }

    final aRight = _get(landmarks, _mirror(aLeft));
    final bRight = _get(landmarks, _mirror(bLeft));
    final cRight = _get(landmarks, _mirror(cLeft));

    if (aRight != null && bRight != null && cRight != null) {
      return (a: aRight, b: bRight, c: cRight);
    }

    return null;
  }

  PoseLandmarkType _mirror(PoseLandmarkType type) {
    final name = type.name;

    if (name.startsWith('left')) {
      final target = 'right${name.substring(4)}';

      return PoseLandmarkType.values.firstWhere(
        (e) => e.name == target,
        orElse: () => type,
      );
    }

    if (name.startsWith('right')) {
      final target = 'left${name.substring(5)}';

      return PoseLandmarkType.values.firstWhere(
        (e) => e.name == target,
        orElse: () => type,
      );
    }

    return type;
  }

  PoseAnalysis analyze(Pose? pose) {
    if (pose == null || pose.landmarks.isEmpty) {
      return PoseAnalysis(
        exercise: _exercise,
        feedback: 'No body detected â€” step into frame.',
        bodyDetected: false,
      );
    }

    final landmarks = pose.landmarks;

    final hasShoulder =
        _get(landmarks, PoseLandmarkType.leftShoulder) != null ||
        _get(landmarks, PoseLandmarkType.rightShoulder) != null;

    final hasHip =
        _get(landmarks, PoseLandmarkType.leftHip) != null ||
        _get(landmarks, PoseLandmarkType.rightHip) != null;

    if (!hasShoulder && !hasHip) {
      return PoseAnalysis(
        exercise: _exercise,
        feedback: 'Step back so your body is visible.',
        bodyDetected: false,
      );
    }

    switch (_exercise) {
      case ExerciseType.squat:
        return _analyzeSquat(landmarks);

      case ExerciseType.pushup:
        return _analyzePushup(landmarks);

      case ExerciseType.bicepCurl:
        return _analyzeBicepCurl(landmarks);

      case ExerciseType.shoulderPress:
        return _analyzeShoulderPress(landmarks);

      case ExerciseType.lunge:
        return _analyzeLunge(landmarks);

      case ExerciseType.jumpingJack:
        return _analyzeJumpingJack(landmarks);

      case ExerciseType.plank:
        return _analyzePlank(landmarks);

      case ExerciseType.generic:
        return _analyzeGeneric(landmarks);
    }
  }

  // ================================================================
  // SQUAT
  // ================================================================

  PoseAnalysis _analyzeSquat(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final joint = _bestJoint(
      landmarks,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    );

    if (joint == null) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        feedback: 'Legs not visible â€” show your lower body.',
        bodyDetected: true,
      );
    }

    final kneeAngle = angleAt(
      joint.a,
      joint.b,
      joint.c,
    );

    // ------------------------------------------------------------
    // Standing detection
    //
    // We only need the knee angle here.
    // This is intentionally simpler than the old body-ratio check.
    // ------------------------------------------------------------

    if (_squatState == _SquatState.waiting) {
      if (kneeAngle > 155) {
        _standingFrames++;

        if (_standingFrames >= _requiredFrames) {
          _wasStanding = true;
        }
      } else {
        _standingFrames = 0;

        // If the person is clearly sitting/bent and was never
        // confirmed standing, keep the state neutral.
        if (kneeAngle < 140 && _reps == 0) {
          _wasStanding = false;
        }
      }

      // ----------------------------------------------------------
      // Descent starts only after confirmed standing.
      // ----------------------------------------------------------

      if (_wasStanding && kneeAngle < 135) {
        _descentFrames++;

        if (_descentFrames >= _requiredFrames) {
          _squatState = _SquatState.descending;
        }
      } else {
        _descentFrames = 0;
      }
    }

    // ------------------------------------------------------------
    // Descending
    // ------------------------------------------------------------

    if (_squatState == _SquatState.descending) {
      if (kneeAngle < 105) {
        _squatState = _SquatState.bottom;
        _phase = _RepPhase.down;
      } else if (kneeAngle > 155) {
        // Person stood back up without reaching squat depth.
        _squatState = _SquatState.waiting;
        _standingFrames = _requiredFrames;
        _descentFrames = 0;
      }
    }

    // ------------------------------------------------------------
    // Bottom
    // ------------------------------------------------------------

    if (_squatState == _SquatState.bottom) {
      if (kneeAngle > 135) {
        _squatState = _SquatState.rising;
      }
    }

    // ------------------------------------------------------------
    // Rising / rep completion
    // ------------------------------------------------------------

    if (_squatState == _SquatState.rising) {
      if (kneeAngle > 160) {
        _reps++;
        _checkSetCompletion();

        _squatState = _SquatState.waiting;

        // The user is now standing.
        _wasStanding = true;
        _standingFrames = _requiredFrames;
        _descentFrames = 0;

        _phase = _RepPhase.up;
      } else if (kneeAngle < 100) {
        _squatState = _SquatState.bottom;
      }
    }

    // ------------------------------------------------------------
    // Before a real squat begins, DON'T show form warnings.
    // ------------------------------------------------------------

    if (_squatState == _SquatState.waiting && !_wasStanding) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        primaryAngle: kneeAngle,
        formQuality: FormQuality.none,
        feedback: 'Stand tall to begin your squat.',
        bodyDetected: true,
        formIssueKey: 'squatReady',
      );
    }

    // ------------------------------------------------------------
    // User is standing and ready.
    // ------------------------------------------------------------

    if (_squatState == _SquatState.waiting && _wasStanding) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        primaryAngle: kneeAngle,
        formQuality: FormQuality.none,
        feedback: 'Ready â€” squat down.',
        bodyDetected: true,
        formIssueKey: 'squatReady',
      );
    }

    // ------------------------------------------------------------
    // During descent.
    // ------------------------------------------------------------

    if (_squatState == _SquatState.descending) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        primaryAngle: kneeAngle,
        formQuality: FormQuality.good,
        feedback: 'Keep going down.',
        bodyDetected: true,
        formIssueKey: 'squatLowerSlowly',
      );
    }

    // ------------------------------------------------------------
    // Active squat form checks.
    // ------------------------------------------------------------

    var quality = FormQuality.good;
    String issueKey = '';

    // Depth
    if (_squatState == _SquatState.bottom ||
        _squatState == _SquatState.rising) {
      if (kneeAngle > 120) {
        issueKey = 'formDepthLow';
        quality = FormQuality.warning;
      }
    }

    // Knee alignment
    final kneeX = joint.b.x;
    final ankleX = joint.c.x;

    if (issueKey.isEmpty && (kneeX - ankleX).abs() > 0.15) {
      issueKey = 'formKneeAlign';
      quality = FormQuality.warning;
    }

    // Torso lean
    final hip = _get(
          landmarks,
          PoseLandmarkType.leftHip,
        ) ??
        _get(
          landmarks,
          PoseLandmarkType.rightHip,
        );

    final shoulder = _get(
          landmarks,
          PoseLandmarkType.leftShoulder,
        ) ??
        _get(
          landmarks,
          PoseLandmarkType.rightShoulder,
        );

    if (issueKey.isEmpty &&
        hip != null &&
        shoulder != null &&
        kneeAngle < 130) {
      final horizontal = (shoulder.x - hip.x).abs();
      final vertical = (shoulder.y - hip.y).abs();

      if (vertical > 0.01 && horizontal / vertical > 1.2) {
        issueKey = 'formTorsoLean';
        quality = FormQuality.warning;
      }
    }

    final feedback = issueKey.isEmpty
        ? 'Good form!'
        : _issueKeyToEnglish(issueKey);

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: kneeAngle,
      formQuality: quality,
      feedback: feedback,
      bodyDetected: true,
      formIssueKey: issueKey,
    );
  }

  // ================================================================
  // PUSH-UP
  // ================================================================

  PoseAnalysis _analyzePushup(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final joint = _bestJoint(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );

    if (joint == null) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        feedback: 'Arms not visible â€” adjust the camera.',
        bodyDetected: true,
      );
    }

    final elbowAngle = angleAt(
      joint.a,
      joint.b,
      joint.c,
    );

    String issueKey = '';
    var quality = FormQuality.good;

    final hip = _get(
      landmarks,
      PoseLandmarkType.leftHip,
    );

    final shoulder = _get(
      landmarks,
      PoseLandmarkType.leftShoulder,
    );

    final ankle = _get(
      landmarks,
      PoseLandmarkType.leftAnkle,
    );

    if (hip != null && shoulder != null && ankle != null) {
      final bodyAngle = angleAt(
        shoulder,
        hip,
        ankle,
      );

      if ((bodyAngle - 180).abs() > 30) {
        issueKey = 'formBodyStraight';
        quality = FormQuality.warning;
      }
    }

    if (elbowAngle < 90) {
      _phase = _RepPhase.down;
    } else if (elbowAngle > 160 &&
        _phase == _RepPhase.down) {
      _phase = _RepPhase.up;
      _reps++;
      _checkSetCompletion();
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: elbowAngle,
      formQuality: quality,
      feedback: issueKey.isEmpty
          ? (elbowAngle < 90
              ? 'Good depth!'
              : 'Lower for full range.')
          : _issueKeyToEnglish(issueKey),
      bodyDetected: true,
      formIssueKey: issueKey,
    );
  }

  // ================================================================
  // BICEP CURL
  // ================================================================

  PoseAnalysis _analyzeBicepCurl(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final joint = _bestJoint(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );

    if (joint == null) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        feedback: 'Arm not visible â€” face the camera.',
        bodyDetected: true,
      );
    }

    final elbowAngle = angleAt(
      joint.a,
      joint.b,
      joint.c,
    );

    var quality = FormQuality.good;
    String issueKey = '';

    final dy = (joint.a.y - joint.b.y).abs();
    final dx = (joint.a.x - joint.b.x).abs();

    if (dy > 0.01 && dx / dy > 0.6) {
      issueKey = 'formElbowStill';
      quality = FormQuality.warning;
    }

    if (elbowAngle < 50) {
      _phase = _RepPhase.down;
    } else if (elbowAngle > 160 &&
        _phase == _RepPhase.down) {
      _phase = _RepPhase.up;
      _reps++;
      _checkSetCompletion();
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: elbowAngle,
      formQuality: quality,
      feedback: issueKey.isEmpty
          ? (elbowAngle < 50
              ? 'Full curl!'
              : 'Curl higher.')
          : _issueKeyToEnglish(issueKey),
      bodyDetected: true,
      formIssueKey: issueKey,
    );
  }

  // ================================================================
  // SHOULDER PRESS
  // ================================================================

  PoseAnalysis _analyzeShoulderPress(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final joint = _bestJoint(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );

    if (joint == null) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        feedback: 'Arms not visible â€” face the camera.',
        bodyDetected: true,
      );
    }

    final elbowAngle = angleAt(
      joint.a,
      joint.b,
      joint.c,
    );

    var quality = FormQuality.good;
    String issueKey = '';

    if (elbowAngle > 160 &&
        joint.c.y > joint.a.y) {
      issueKey = 'formPressHigher';
      quality = FormQuality.warning;
    }

    if (elbowAngle < 90) {
      _phase = _RepPhase.down;
    } else if (elbowAngle > 160 &&
        _phase == _RepPhase.down) {
      _phase = _RepPhase.up;
      _reps++;
      _checkSetCompletion();
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: elbowAngle,
      formQuality: quality,
      feedback: issueKey.isEmpty
          ? (elbowAngle > 160
              ? 'Full press!'
              : 'Press higher.')
          : _issueKeyToEnglish(issueKey),
      bodyDetected: true,
      formIssueKey: issueKey,
    );
  }

  // ================================================================
  // LUNGE
  // ================================================================

  PoseAnalysis _analyzeLunge(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final joint = _bestJoint(
      landmarks,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    );

    if (joint == null) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        feedback: 'Legs not visible â€” stand sideways.',
        bodyDetected: true,
      );
    }

    final kneeAngle = angleAt(
      joint.a,
      joint.b,
      joint.c,
    );

    var quality = FormQuality.good;
    String issueKey = '';

    if ((joint.b.x - joint.c.x).abs() > 0.15) {
      issueKey = 'formKneeAlign';
      quality = FormQuality.warning;
    }

    if (kneeAngle < 100) {
      _phase = _RepPhase.down;
    } else if (kneeAngle > 160 &&
        _phase == _RepPhase.down) {
      _phase = _RepPhase.up;
      _reps++;
      _checkSetCompletion();
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: kneeAngle,
      formQuality: quality,
      feedback: issueKey.isEmpty
          ? (kneeAngle < 100
              ? 'Good depth!'
              : 'Lower for full depth.')
          : _issueKeyToEnglish(issueKey),
      bodyDetected: true,
      formIssueKey: issueKey,
    );
  }

  // ================================================================
  // JUMPING JACK
  // ================================================================

  PoseAnalysis _analyzeJumpingJack(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final shoulder =
        _get(landmarks, PoseLandmarkType.leftShoulder) ??
            _get(
              landmarks,
              PoseLandmarkType.rightShoulder,
            );

    final wrist =
        _get(landmarks, PoseLandmarkType.leftWrist) ??
            _get(
              landmarks,
              PoseLandmarkType.rightWrist,
            );

    if (shoulder == null || wrist == null) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        feedback: 'Full body not visible â€” step back.',
        bodyDetected: true,
      );
    }

    final armsUp = wrist.y < shoulder.y;

    if (armsUp) {
      _phase = _RepPhase.down;
    } else if (_phase == _RepPhase.down) {
      _phase = _RepPhase.up;
      _reps++;
      _checkSetCompletion();
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: (shoulder.y - wrist.y) * 100,
      formQuality: FormQuality.good,
      feedback: armsUp
          ? 'Arms up â€” good!'
          : 'Raise your arms higher.',
      bodyDetected: true,
    );
  }

  // ================================================================
  // PLANK
  // ================================================================

  PoseAnalysis _analyzePlank(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final hip =
        _get(landmarks, PoseLandmarkType.leftHip);

    final shoulder =
        _get(landmarks, PoseLandmarkType.leftShoulder);

    final ankle =
        _get(landmarks, PoseLandmarkType.leftAnkle);

    if (hip == null ||
        shoulder == null ||
        ankle == null) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        feedback: 'Body not fully visible â€” use side view.',
        bodyDetected: true,
      );
    }

    final bodyAngle = angleAt(
      shoulder,
      hip,
      ankle,
    );

    final deviation = (bodyAngle - 180).abs();

    if (deviation < 15) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        primaryAngle: bodyAngle,
        formQuality: FormQuality.good,
        feedback: 'Great plank â€” body is straight!',
        bodyDetected: true,
      );
    }

    if (deviation < 30) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        primaryAngle: bodyAngle,
        formQuality: FormQuality.warning,
        feedback: hip.y > shoulder.y
            ? 'Keep your hips from sagging.'
            : 'Lower your hips slightly.',
        bodyDetected: true,
      );
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: bodyAngle,
      formQuality: FormQuality.poor,
      feedback: hip.y > shoulder.y
          ? 'Straighten your body line.'
          : 'Bring your hips down.',
      bodyDetected: true,
    );
  }

  // ================================================================
  // GENERIC
  // ================================================================

  PoseAnalysis _analyzeGeneric(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final joint = _bestJoint(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );

    final angle = joint == null
        ? 0.0
        : angleAt(
            joint.a,
            joint.b,
            joint.c,
          );

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: angle,
      formQuality: FormQuality.none,
      feedback: joint != null
          ? 'Elbow angle: ${angle.round()}Â°'
          : 'Body detected â€” move freely.',
      bodyDetected: true,
    );
  }

  String _issueKeyToEnglish(String key) {
    switch (key) {
      case 'formDepthLow':
        return 'Go a little lower for full depth.';

      case 'formKneeAlign':
        return 'Keep your knees aligned with your toes.';

      case 'formTorsoLean':
        return 'Keep your chest more upright.';

      case 'formNotStanding':
        return 'Stand fully upright to complete the repetition.';

      case 'formBodyStraight':
        return 'Keep your body straighter.';

      case 'formElbowStill':
        return 'Keep your elbow more still.';

      case 'formPressHigher':
        return 'Press your arms higher overhead.';

      case 'formHipDrop':
        return 'Keep your hips level.';

      default:
        return '';
    }
  }
}

const List<List<PoseLandmarkType>> skeletonConnections = [
  [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
  ],

  [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.leftEar,
  ],

  [
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.rightEar,
  ],

  [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.leftElbow,
  ],

  [
    PoseLandmarkType.leftElbow,
    PoseLandmarkType.leftWrist,
  ],

  [
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.rightElbow,
  ],

  [
    PoseLandmarkType.rightElbow,
    PoseLandmarkType.rightWrist,
  ],

  [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.leftHip,
  ],

  [
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.rightHip,
  ],

  [
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
  ],

  [
    PoseLandmarkType.leftHip,
    PoseLandmarkType.leftKnee,
  ],

  [
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.leftAnkle,
  ],

  [
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.leftHeel,
  ],

  [
    PoseLandmarkType.leftHeel,
    PoseLandmarkType.leftFootIndex,
  ],

  [
    PoseLandmarkType.rightHip,
    PoseLandmarkType.rightKnee,
  ],

  [
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.rightAnkle,
  ],

  [
    PoseLandmarkType.rightAnkle,
    PoseLandmarkType.rightHeel,
  ],

  [
    PoseLandmarkType.rightHeel,
    PoseLandmarkType.rightFootIndex,
  ],
];
