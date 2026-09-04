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

enum FormQuality { good, warning, poor, none }

class PoseAnalysis {
  final int reps;
  final double primaryAngle;
  final FormQuality formQuality;
  final String feedback;
  final bool bodyDetected;
  final bool personDetected;
  final ExerciseType exercise;
  final String formIssueKey;

  const PoseAnalysis({
    this.reps = 0,
    this.primaryAngle = 0,
    this.formQuality = FormQuality.none,
    this.feedback = '',
    this.bodyDetected = false,
    this.personDetected = false,
    this.exercise = ExerciseType.generic,
    this.formIssueKey = '',
  });
}

double angleAt(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
  final radians =
      math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);

  var degrees = (radians * 180 / math.pi).abs();

  if (degrees > 180) {
    degrees = 360 - degrees;
  }

  return degrees;
}

enum _RepPhase { up, down }

enum _SquatState { waitingForStanding, ready, descending, bottom, rising }

class PoseAnalyzer {
  ExerciseType _exercise = ExerciseType.squat;

  int _reps = 0;
  _RepPhase _phase = _RepPhase.up;

  _SquatState _squatState = _SquatState.waitingForStanding;

  // ------------------------------------------------------------
  // Squat standing confirmation
  // ------------------------------------------------------------
  //
  // A single standing frame is not enough to start the rep cycle.
  // We require several consecutive standing frames.
  //
  static const int _requiredStandingFrames = 8;
  int _standingFrames = 0;

  // ------------------------------------------------------------
  // Squat transition stability
  // ------------------------------------------------------------
  // Require multiple consecutive frames before changing state.
  // This prevents one noisy ML Kit frame from creating a fake rep.
  static const int _requiredTransitionFrames = 3;

  int _descendingFrames = 0;
  int _bottomFrames = 0;
  int _risingFrames = 0;
  int _completionStandingFrames = 0;

  // ------------------------------------------------------------
  // Generic initial-position arming
  // ------------------------------------------------------------
  // Before any non-squat exercise can begin a rep cycle, the user
  // must hold the starting ("up") position for several consecutive
  // frames. This prevents noisy ML Kit frames at camera startup
  // from producing a false rep.
  static const int _requiredGenericArmedFrames = 5;

  bool _genericArmed = false;
  int _genericArmedFrames = 0;

  // ------------------------------------------------------------
  // Generic transition stability (non-squat exercises)
  // ------------------------------------------------------------
  // Require multiple consecutive frames before changing phase.
  static const int _requiredGenericTransitionFrames = 3;

  int _genericDownFrames = 0;
  int _genericUpFrames = 0;

  // ------------------------------------------------------------
  // Set tracking
  // ------------------------------------------------------------

  int _currentSet = 1;
  int _completedSets = 0;
  int _targetSets = 0;
  int _targetRepsPerSet = 0;
  bool _exerciseCompleted = false;

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

    _currentSet = 0;
    _completedSets = 0;
    _exerciseCompleted = false;

    // Do not allow a previous pose cycle to leak into a new set.
    _squatState = _SquatState.waitingForStanding;
    _standingFrames = 0;
    _descendingFrames = 0;
    _bottomFrames = 0;
    _risingFrames = 0;
    _completionStandingFrames = 0;
    _phase = _RepPhase.up;
    _genericDownFrames = 0;
    _genericUpFrames = 0;
    _genericArmed = false;
    _genericArmedFrames = 0;
  }

  void setExercise(ExerciseType type) {
    _exercise = type;
    reset();
  }

  void reset() {
    _reps = 0;
    _phase = _RepPhase.up;

    // IMPORTANT:
    // Every reset starts by waiting for a real standing position.
    // This prevents the initial camera pose from being interpreted
    // as the end of a repetition.
    _squatState = _SquatState.waitingForStanding;
    _standingFrames = 0;
    _descendingFrames = 0;
    _bottomFrames = 0;
    _risingFrames = 0;
    _completionStandingFrames = 0;

    _genericDownFrames = 0;
    _genericUpFrames = 0;
    _genericArmed = false;
    _genericArmedFrames = 0;

    _currentSet = 0;
    _completedSets = 0;
    _exerciseCompleted = false;
  }

  /// Returns true when the current set has just been completed.
  bool _checkSetCompletion() {
    if (_targetRepsPerSet <= 0) {
      return false;
    }

    if (_reps < _targetRepsPerSet) {
      return false;
    }

    _completedSets++;

    if (_completedSets >= _targetSets) {
      _exerciseCompleted = true;

      // Final set is complete.
      // Keep the completed state; no next set exists.
      _phase = _RepPhase.up;
      _squatState = _SquatState.ready;
      _standingFrames = 0;

      return true;
    }

    // Move to the next set.
    _currentSet = _completedSets + 1;

    // Start the next set with zero reps.
    _reps = 0;

    // The user has just completed a rep by reaching full standing.
    // They are already in a valid standing position, so do NOT
    // require another 8 standing frames before allowing the
    // next descent.
    _phase = _RepPhase.up;
    _squatState = _SquatState.ready;
    _standingFrames = 0;

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
        feedback: 'No body detected - step into frame.',
        bodyDetected: false,
        personDetected: false,
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
        personDetected: true,
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

  PoseAnalysis _analyzeSquat(Map<PoseLandmarkType, PoseLandmark> landmarks) {
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
        feedback: 'Legs not visible - show your lower body.',
        bodyDetected: true,
        personDetected: true,
      );
    }

    final kneeAngle = angleAt(joint.a, joint.b, joint.c);

    final isStanding = kneeAngle >= 155;
    final isDescending = kneeAngle <= 140;
    final isBottom = kneeAngle <= 125;

    // ------------------------------------------------------------
    // ------------------------------------------------------------
    // STABLE SQUAT STATE MACHINE
    // ------------------------------------------------------------
    //
    // Important transitions require consecutive frames.
    // This prevents a single noisy ML Kit frame from:
    // - starting a squat
    // - reaching the bottom
    // - completing a rep
    //
    // Required sequence:
    // standing -> descent -> bottom -> rising -> standing -> rep
    // ------------------------------------------------------------

    final transitionFrames = _requiredTransitionFrames;

    switch (_squatState) {
      case _SquatState.waitingForStanding:
        _phase = _RepPhase.up;

        if (isStanding) {
          _standingFrames++;

          if (_standingFrames >= _requiredStandingFrames) {
            _squatState = _SquatState.ready;

            _standingFrames = 0;
            _descendingFrames = 0;
            _bottomFrames = 0;
            _risingFrames = 0;
            _completionStandingFrames = 0;
          }
        } else {
          _standingFrames = 0;
        }
        break;

      case _SquatState.ready:
        _phase = _RepPhase.up;

        // Descent must remain stable for several frames.
        if (isDescending) {
          _descendingFrames++;

          if (_descendingFrames >= transitionFrames) {
            _squatState = _SquatState.descending;
            _phase = _RepPhase.down;

            _descendingFrames = 0;
            _bottomFrames = 0;
            _risingFrames = 0;
          }
        } else {
          _descendingFrames = 0;
        }
        break;

      case _SquatState.descending:
        _phase = _RepPhase.down;

        // Bottom position must remain stable.
        if (isBottom) {
          _bottomFrames++;

          if (_bottomFrames >= transitionFrames) {
            _squatState = _SquatState.bottom;

            _bottomFrames = 0;
            _risingFrames = 0;
          }
        } else {
          _bottomFrames = 0;

          // Returned upward without reaching valid depth.
          // This does NOT count as a rep.
          if (isStanding) {
            _squatState = _SquatState.ready;
            _phase = _RepPhase.up;
            _descendingFrames = 0;
          }
        }
        break;

      case _SquatState.bottom:
        _phase = _RepPhase.down;

        // Must clearly leave the bottom before rising.
        if (kneeAngle >= 135) {
          _risingFrames++;

          if (_risingFrames >= transitionFrames) {
            _squatState = _SquatState.rising;
            _phase = _RepPhase.up;

            _risingFrames = 0;
            _bottomFrames = 0;
          }
        } else {
          _risingFrames = 0;
        }
        break;

      case _SquatState.rising:
        _phase = _RepPhase.up;

        // Full standing must be stable before counting.
        if (isStanding) {
          _completionStandingFrames++;

          if (_completionStandingFrames >= transitionFrames) {
            _reps++;

            final setCompleted = _checkSetCompletion();

            _completionStandingFrames = 0;
            _descendingFrames = 0;
            _bottomFrames = 0;
            _risingFrames = 0;

            if (!setCompleted) {
              // Already standing after the rep.
              // Ready for the next genuine descent immediately.
              _squatState = _SquatState.ready;
              _phase = _RepPhase.up;
              _standingFrames = 0;
            }
          }
        } else {
          _completionStandingFrames = 0;

          // If the user drops back down, return to bottom.
          // Never count the rep yet.
          if (isBottom) {
            _squatState = _SquatState.bottom;
            _phase = _RepPhase.down;
            _risingFrames = 0;
          }
        }
        break;
    }

    // ------------------------------------------------------------
    // FORM CHECKING
    // ------------------------------------------------------------

    var quality = FormQuality.good;
    String issueKey = '';

    if ((_squatState == _SquatState.bottom ||
            _squatState == _SquatState.rising) &&
        kneeAngle > 125) {
      issueKey = 'formDepthLow';
      quality = FormQuality.warning;
    }

    final kneeX = joint.b.x;
    final ankleX = joint.c.x;

    if (issueKey.isEmpty && (kneeX - ankleX).abs() > 0.15) {
      issueKey = 'formKneeAlign';
      quality = FormQuality.warning;
    }

    final hip =
        _get(landmarks, PoseLandmarkType.leftHip) ??
        _get(landmarks, PoseLandmarkType.rightHip);

    final shoulder =
        _get(landmarks, PoseLandmarkType.leftShoulder) ??
        _get(landmarks, PoseLandmarkType.rightShoulder);

    if (issueKey.isEmpty &&
        hip != null &&
        shoulder != null &&
        kneeAngle < 135) {
      final horizontal = (shoulder.x - hip.x).abs();

      final vertical = (shoulder.y - hip.y).abs();

      if (vertical > 0.01 && horizontal / vertical > 1.2) {
        issueKey = 'formTorsoLean';
        quality = FormQuality.warning;
      }
    }

    // ------------------------------------------------------------
    // FEEDBACK
    // ------------------------------------------------------------

    String feedback;

    if (issueKey.isNotEmpty) {
      feedback = _issueKeyToEnglish(issueKey);
    } else {
      switch (_squatState) {
        case _SquatState.waitingForStanding:
          feedback = _reps == 0
              ? 'Stand tall to begin.'
              : 'Stand tall to get ready.';
          break;

        case _SquatState.ready:
          feedback = 'Ready - squat down.';
          break;

        case _SquatState.descending:
          feedback = 'Keep going down.';
          break;

        case _SquatState.bottom:
          feedback = 'Good depth - stand up.';
          break;

        case _SquatState.rising:
          feedback = 'Stand up fully.';
          break;
      }
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: kneeAngle,
      formQuality: quality,
      feedback: feedback,
      bodyDetected: true,
      personDetected: true,
      formIssueKey: issueKey,
    );
  }

  // ================================================================
  // PUSH-UP
  // ================================================================

  PoseAnalysis _analyzePushup(Map<PoseLandmarkType, PoseLandmark> landmarks) {
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
        feedback: 'Arms not visible - adjust the camera.',
        bodyDetected: true,
        personDetected: true,
      );
    }

    final elbowAngle = angleAt(joint.a, joint.b, joint.c);

    String issueKey = '';
    var quality = FormQuality.good;

    final hip = _get(landmarks, PoseLandmarkType.leftHip);

    final shoulder = _get(landmarks, PoseLandmarkType.leftShoulder);

    final ankle = _get(landmarks, PoseLandmarkType.leftAnkle);

    if (hip != null && shoulder != null && ankle != null) {
      final bodyAngle = angleAt(shoulder, hip, ankle);

      if ((bodyAngle - 180).abs() > 30) {
        issueKey = 'formBodyStraight';
        quality = FormQuality.warning;
      }
    }

    final stableFrames = _requiredGenericTransitionFrames;

    if (!_genericArmed) {
      if (elbowAngle > 160) {
        _genericArmedFrames++;
        if (_genericArmedFrames >= _requiredGenericArmedFrames) {
          _genericArmed = true;
        }
      } else {
        _genericArmedFrames = 0;
      }
    }

    if (elbowAngle < 90) {
      _genericDownFrames++;
      _genericUpFrames = 0;

      if (_genericDownFrames >= stableFrames && _genericArmed) {
        _phase = _RepPhase.down;
      }
    } else if (elbowAngle > 160) {
      _genericUpFrames++;
      _genericDownFrames = 0;

      if (_genericUpFrames >= stableFrames && _phase == _RepPhase.down) {
        _phase = _RepPhase.up;
        _reps++;
        _genericUpFrames = 0;
        _checkSetCompletion();
      }
    } else {
      _genericDownFrames = 0;
      _genericUpFrames = 0;
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: elbowAngle,
      formQuality: quality,
      feedback: issueKey.isEmpty
          ? (elbowAngle < 90 ? 'Good depth!' : 'Lower for full range.')
          : _issueKeyToEnglish(issueKey),
      bodyDetected: true,
      personDetected: true,
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
        feedback: 'Arm not visible - face the camera.',
        bodyDetected: true,
        personDetected: true,
      );
    }

    final elbowAngle = angleAt(joint.a, joint.b, joint.c);

    var quality = FormQuality.good;
    String issueKey = '';

    final dy = (joint.a.y - joint.b.y).abs();
    final dx = (joint.a.x - joint.b.x).abs();

    if (dy > 0.01 && dx / dy > 0.6) {
      issueKey = 'formElbowStill';
      quality = FormQuality.warning;
    }

    final stableFrames = _requiredGenericTransitionFrames;

    if (!_genericArmed) {
      if (elbowAngle > 160) {
        _genericArmedFrames++;
        if (_genericArmedFrames >= _requiredGenericArmedFrames) {
          _genericArmed = true;
        }
      } else {
        _genericArmedFrames = 0;
      }
    }

    if (elbowAngle < 50) {
      _genericDownFrames++;
      _genericUpFrames = 0;

      if (_genericDownFrames >= stableFrames && _genericArmed) {
        _phase = _RepPhase.down;
      }
    } else if (elbowAngle > 160) {
      _genericUpFrames++;
      _genericDownFrames = 0;

      if (_genericUpFrames >= stableFrames && _phase == _RepPhase.down) {
        _phase = _RepPhase.up;
        _reps++;
        _genericUpFrames = 0;
        _checkSetCompletion();
      }
    } else {
      _genericDownFrames = 0;
      _genericUpFrames = 0;
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: elbowAngle,
      formQuality: quality,
      feedback: issueKey.isEmpty
          ? (elbowAngle < 50 ? 'Full curl!' : 'Curl higher.')
          : _issueKeyToEnglish(issueKey),
      bodyDetected: true,
      personDetected: true,
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
        feedback: 'Arms not visible - face the camera.',
        bodyDetected: true,
        personDetected: true,
      );
    }

    final elbowAngle = angleAt(joint.a, joint.b, joint.c);

    var quality = FormQuality.good;
    String issueKey = '';

    if (elbowAngle > 160 && joint.c.y > joint.a.y) {
      issueKey = 'formPressHigher';
      quality = FormQuality.warning;
    }

    final stableFrames = _requiredGenericTransitionFrames;

    if (!_genericArmed) {
      if (elbowAngle < 90) {
        _genericArmedFrames++;
        if (_genericArmedFrames >= _requiredGenericArmedFrames) {
          _genericArmed = true;
        }
      } else {
        _genericArmedFrames = 0;
      }
    }

    if (elbowAngle < 90) {
      _genericDownFrames++;
      _genericUpFrames = 0;

      if (_genericDownFrames >= stableFrames && _genericArmed) {
        _phase = _RepPhase.down;
      }
    } else if (elbowAngle > 160) {
      _genericUpFrames++;
      _genericDownFrames = 0;

      if (_genericUpFrames >= stableFrames && _phase == _RepPhase.down) {
        _phase = _RepPhase.up;
        _reps++;
        _genericUpFrames = 0;
        _checkSetCompletion();
      }
    } else {
      _genericDownFrames = 0;
      _genericUpFrames = 0;
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: elbowAngle,
      formQuality: quality,
      feedback: issueKey.isEmpty
          ? (elbowAngle > 160 ? 'Full press!' : 'Press higher.')
          : _issueKeyToEnglish(issueKey),
      bodyDetected: true,
      personDetected: true,
      formIssueKey: issueKey,
    );
  }

  // ================================================================
  // LUNGE
  // ================================================================

  PoseAnalysis _analyzeLunge(Map<PoseLandmarkType, PoseLandmark> landmarks) {
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
        feedback: 'Legs not visible - stand sideways.',
        bodyDetected: true,
        personDetected: true,
      );
    }

    final kneeAngle = angleAt(joint.a, joint.b, joint.c);

    var quality = FormQuality.good;
    String issueKey = '';

    if ((joint.b.x - joint.c.x).abs() > 0.15) {
      issueKey = 'formKneeAlign';
      quality = FormQuality.warning;
    }

    final stableFrames = _requiredGenericTransitionFrames;

    if (!_genericArmed) {
      if (kneeAngle > 160) {
        _genericArmedFrames++;
        if (_genericArmedFrames >= _requiredGenericArmedFrames) {
          _genericArmed = true;
        }
      } else {
        _genericArmedFrames = 0;
      }
    }

    if (kneeAngle < 100) {
      _genericDownFrames++;
      _genericUpFrames = 0;

      if (_genericDownFrames >= stableFrames && _genericArmed) {
        _phase = _RepPhase.down;
      }
    } else if (kneeAngle > 160) {
      _genericUpFrames++;
      _genericDownFrames = 0;

      if (_genericUpFrames >= stableFrames && _phase == _RepPhase.down) {
        _phase = _RepPhase.up;
        _reps++;
        _genericUpFrames = 0;
        _checkSetCompletion();
      }
    } else {
      _genericDownFrames = 0;
      _genericUpFrames = 0;
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: kneeAngle,
      formQuality: quality,
      feedback: issueKey.isEmpty
          ? (kneeAngle < 100 ? 'Good depth!' : 'Lower for full depth.')
          : _issueKeyToEnglish(issueKey),
      bodyDetected: true,
      personDetected: true,
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
        _get(landmarks, PoseLandmarkType.rightShoulder);

    final wrist =
        _get(landmarks, PoseLandmarkType.leftWrist) ??
        _get(landmarks, PoseLandmarkType.rightWrist);

    if (shoulder == null || wrist == null) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        feedback: 'Full body not visible - step back.',
        bodyDetected: true,
        personDetected: true,
      );
    }

    final armsUp = wrist.y < shoulder.y;

    final stableFrames = _requiredGenericTransitionFrames;

    if (!_genericArmed) {
      if (!armsUp) {
        _genericArmedFrames++;
        if (_genericArmedFrames >= _requiredGenericArmedFrames) {
          _genericArmed = true;
        }
      } else {
        _genericArmedFrames = 0;
      }
    }

    if (armsUp) {
      _genericDownFrames++;
      _genericUpFrames = 0;

      if (_genericDownFrames >= stableFrames && _genericArmed) {
        _phase = _RepPhase.down;
      }
    } else {
      _genericUpFrames++;
      _genericDownFrames = 0;

      if (_genericUpFrames >= stableFrames && _phase == _RepPhase.down) {
        _phase = _RepPhase.up;
        _reps++;
        _genericUpFrames = 0;
        _checkSetCompletion();
      }
    }

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: (shoulder.y - wrist.y) * 100,
      formQuality: FormQuality.good,
      feedback: armsUp ? 'Arms up - good!' : 'Raise your arms higher.',
      bodyDetected: true,
      personDetected: true,
    );
  }

  // ================================================================
  // PLANK
  // ================================================================

  PoseAnalysis _analyzePlank(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final hip = _get(landmarks, PoseLandmarkType.leftHip);

    final shoulder = _get(landmarks, PoseLandmarkType.leftShoulder);

    final ankle = _get(landmarks, PoseLandmarkType.leftAnkle);

    if (hip == null || shoulder == null || ankle == null) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        feedback: 'Body not fully visible - use side view.',
        bodyDetected: true,
        personDetected: true,
      );
    }

    final bodyAngle = angleAt(shoulder, hip, ankle);

    final deviation = (bodyAngle - 180).abs();

    if (deviation < 15) {
      return PoseAnalysis(
        exercise: _exercise,
        reps: _reps,
        primaryAngle: bodyAngle,
        formQuality: FormQuality.good,
        feedback: 'Great plank - body is straight!',
        bodyDetected: true,
        personDetected: true,
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
        personDetected: true,
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
      personDetected: true,
    );
  }

  // ================================================================
  // GENERIC
  // ================================================================

  PoseAnalysis _analyzeGeneric(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final joint = _bestJoint(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );

    final angle = joint == null ? 0.0 : angleAt(joint.a, joint.b, joint.c);

    return PoseAnalysis(
      exercise: _exercise,
      reps: _reps,
      primaryAngle: angle,
      formQuality: FormQuality.none,
      feedback: joint != null
          ? 'Elbow angle: ${angle.round()}°'
          : 'Body detected - move freely.',
      bodyDetected: true,
      personDetected: true,
    );
  }

  // ================================================================
  // FORM FEEDBACK
  // ================================================================

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

// ================================================================
// SKELETON CONNECTIONS
// ================================================================

const List<List<PoseLandmarkType>> skeletonConnections = [
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftEar],
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightEar],
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
  [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
  [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
  [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
  [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
  [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
  [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
  [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],
  [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
  [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
  [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
];
