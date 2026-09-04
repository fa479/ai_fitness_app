/// FitAI Form Check — Live Camera Mirror + Posture/Form Feedback
///
/// Uses Google ML Kit Pose Detection on the live camera stream to:
///   - act as a real mirror (live CameraPreview)
///   - detect body landmarks in real time
///   - draw a skeleton overlay
///   - give real form/posture feedback
///
/// NO rep counting, NO set counting, NO workout progression.
/// This is purely a mirror + posture check tool.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/pose_analyzer.dart';
import '../core/voice_service.dart';
import '../app/app_localizations.dart' show L;

class FormCheckScreen extends StatefulWidget {
  final ExerciseType? initialExercise;
  final String? exerciseName;

  const FormCheckScreen({
    super.key,
    this.initialExercise,
    this.exerciseName,
  });

  @override
  State<FormCheckScreen> createState() => _FormCheckScreenState();
}

class _FormCheckScreenState extends State<FormCheckScreen> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;

  final PoseAnalyzer _analyzer = PoseAnalyzer();

  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _hasPermission = false;

  String _statusMessage = 'Initializing...';

  Pose? _latestPose;

  int _imageWidth = 0;
  int _imageHeight = 0;

  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  PoseAnalysis _analysis = const PoseAnalysis();

  String _lastSpokenIssueKey = '';
  bool _lastBodyDetected = false;
  DateTime _lastVoiceTime = DateTime.now();

  static const Duration _voiceCooldown = Duration(seconds: 5);

  int _processedFrameCount = 0;
  static const int _warmUpFrames = 10;

  bool _isConfigured = false;
  late ExerciseType _selectedExercise;

  @override
  void initState() {
    super.initState();
    _selectedExercise = widget.initialExercise ?? ExerciseType.squat;
  }

  void _startExercise() {
    _analyzer.setExercise(_selectedExercise);
    setState(() => _isConfigured = true);
    _setupCamera();
  }

  // ================================================================
  // CAMERA SETUP
  // ================================================================

  Future<void> _setupCamera() async {
    final permission = await Permission.camera.request();

    if (!permission.isGranted) {
      if (!mounted) return;

      setState(() {
        _statusMessage =
            'Camera permission denied.\n'
            'Please allow camera access in Settings.';
      });

      return;
    }

    _hasPermission = true;

    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        if (!mounted) return;

        setState(() {
          _statusMessage = 'No camera found on this device.';
        });

        return;
      }

      // Prefer front camera for mirror-like experience.
      final frontIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      _currentCameraIndex = frontIndex >= 0 ? frontIndex : 0;

      await _initializeSelectedCamera();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Camera setup error: $e');
      }

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Camera initialization failed.\n$e';
      });
    }
  }

  Future<void> _initializeSelectedCamera() async {
    await _stopCamera();

    final camera = _cameras[_currentCameraIndex];

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();

    _poseDetector ??= PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );

    _rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;

    _latestPose = null;
    _analysis = const PoseAnalysis();
    _processedFrameCount = 0;

    await _cameraController!.startImageStream(_onCameraImage);

    if (!mounted) return;

    setState(() {
      _isCameraReady = true;
      _statusMessage = 'Position your full body inside the frame.';
    });
  }

  // ================================================================
  // SWITCH FRONT / BACK CAMERA
  // ================================================================

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only one camera is available on this device.'),
        ),
      );
      return;
    }

    if (_isProcessing) {
      return;
    }

    setState(() {
      _isCameraReady = false;
      _statusMessage = 'Switching camera...';
    });

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;

    try {
      await _initializeSelectedCamera();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Camera switch error: $e');
      }

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Could not switch camera.\n$e';
      });
    }
  }

  String get _cameraName {
    if (_cameras.isEmpty) return 'Camera';

    final direction = _cameras[_currentCameraIndex].lensDirection;

    if (direction == CameraLensDirection.front) {
      return 'Front Camera';
    }

    return 'Back Camera';
  }

  // ================================================================
  // CAMERA IMAGE PROCESSING
  // ================================================================

  void _onCameraImage(CameraImage image) {
    if (_isProcessing || _poseDetector == null) {
      return;
    }

    _isProcessing = true;

    _processFrame(image).whenComplete(() {
      _isProcessing = false;
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      _imageWidth = image.width;
      _imageHeight = image.height;

      final inputImage = _buildInputImage(image);

      if (inputImage == null) {
        return;
      }

      final poses = await _poseDetector!.processImage(inputImage);

      final pose = poses.isNotEmpty ? poses.first : null;

      _processedFrameCount++;
      final isWarmingUp = _processedFrameCount <= _warmUpFrames;

      final analysis = _analyzer.analyze(pose);

      if (!mounted) return;

      setState(() {
        _latestPose = pose;
        _analysis = isWarmingUp
            ? const PoseAnalysis(
                feedback: 'Detecting body position...',
                bodyDetected: true,
                personDetected: true,
              )
            : analysis;
      });

      if (!isWarmingUp) {
        _maybeSpeakFeedback(analysis);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Pose detection error: $e');
      }
    }
  }

  // ================================================================
  // INPUT IMAGE
  // ================================================================

  InputImage? _buildInputImage(CameraImage image) {
    if (Platform.isAndroid) {
      return _buildInputImageAndroid(image);
    }

    if (Platform.isIOS) {
      return _buildInputImageIos(image);
    }

    return null;
  }

  InputImage? _buildInputImageAndroid(CameraImage image) {
    try {
      if (image.planes.length < 3) {
        return null;
      }

      final width = image.width;
      final height = image.height;

      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      final yRowStride = yPlane.bytesPerRow;
      final uRowStride = uPlane.bytesPerRow;
      final vRowStride = vPlane.bytesPerRow;

      final uPixelStride = uPlane.bytesPerPixel ?? 1;
      final vPixelStride = vPlane.bytesPerPixel ?? 1;

      final ySize = width * height;
      final nv21 = Uint8List(ySize + ySize ~/ 2);

      int index = 0;

      for (int row = 0; row < height; row++) {
        final rowStart = row * yRowStride;

        for (int col = 0; col < width; col++) {
          nv21[index++] = yPlane.bytes[rowStart + col];
        }
      }

      for (int row = 0; row < height ~/ 2; row++) {
        final uStart = row * uRowStride;
        final vStart = row * vRowStride;

        for (int col = 0; col < width ~/ 2; col++) {
          nv21[index++] = vPlane.bytes[vStart + col * vPixelStride];

          nv21[index++] = uPlane.bytes[uStart + col * uPixelStride];
        }
      }

      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: ui.Size(width.toDouble(), height.toDouble()),
          rotation: _rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: width,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Android input image error: $e');
      }

      return null;
    }
  }

  InputImage? _buildInputImageIos(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;

      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: Uint8List.fromList(plane.bytes),
        metadata: InputImageMetadata(
          size: ui.Size(width.toDouble(), height.toDouble()),
          rotation: _rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('iOS input image error: $e');
      }

      return null;
    }
  }

  // ================================================================
  // VOICE FEEDBACK — posture/form only, no rep announcements
  // ================================================================

  void _maybeSpeakFeedback(PoseAnalysis analysis) {
    final now = DateTime.now();

    final currentIssue = analysis.formIssueKey;
    final bodyDetected = analysis.bodyDetected;

    String? toSpeak;

    if (!bodyDetected && _lastBodyDetected) {
      toSpeak = L.t('formMoveIntoFrame');
    } else if (bodyDetected && !_lastBodyDetected) {
      if (currentIssue.isNotEmpty) {
        toSpeak = L.t(currentIssue);
      }
    } else if (currentIssue.isNotEmpty && currentIssue != _lastSpokenIssueKey) {
      toSpeak = L.t(currentIssue);
    } else if (currentIssue.isEmpty && _lastSpokenIssueKey.isNotEmpty) {
      toSpeak = L.t('formGoodForm');
    }

    if (toSpeak != null && now.difference(_lastVoiceTime) > _voiceCooldown) {
      _lastVoiceTime = now;
      VoiceService.instance.speak(toSpeak);
    }

    _lastSpokenIssueKey = currentIssue;
    _lastBodyDetected = bodyDetected;
  }

  // ================================================================
  // DISPOSE CAMERA
  // ================================================================

  Future<void> _stopCamera() async {
    final controller = _cameraController;

    if (controller == null) {
      return;
    }

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}

    await controller.dispose();

    _cameraController = null;
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector?.close();

    super.dispose();
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          L.t('formCheck'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isConfigured) ...[
            IconButton(
              onPressed: _isCameraReady ? _switchCamera : null,
              tooltip: 'Switch Camera',
              icon: const Icon(Icons.flip_camera_ios),
            ),
            PopupMenuButton<ExerciseType>(
              icon: const Icon(Icons.fitness_center),
              tooltip: 'Select Exercise',
              onSelected: (type) {
                _analyzer.setExercise(type);
                setState(() {
                  _selectedExercise = type;
                  _latestPose = null;
                  _analysis = const PoseAnalysis();
                });
              },
              itemBuilder: (_) {
                return ExerciseType.values
                    .map(
                      (exercise) => PopupMenuItem<ExerciseType>(
                        value: exercise,
                        child: Text(exercise.displayName),
                      ),
                    )
                    .toList();
              },
            ),
          ],
        ],
      ),
      body: _isConfigured
          ? (_isCameraReady &&
                    _cameraController != null &&
                    _cameraController!.value.isInitialized
                ? _buildCameraView()
                : _buildLoadingView())
          : _buildConfigView(),
    );
  }

  // ================================================================
  // CONFIGURATION VIEW — exercise selection only, no sets/reps
  // ================================================================

  Widget _buildConfigView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          const Icon(Icons.camera_alt, size: 56, color: Colors.blue),

          const SizedBox(height: 16),

          Text(
            L.t('formCheck'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            'Live mirror with real-time posture and form feedback.\nNo rep or set counting — just check your form.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 16),

          if (widget.exerciseName != null)
            Text(
              widget.exerciseName!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),

          if (widget.exerciseName != null)
            const SizedBox(height: 8),

          Text(
            _selectedExercise.instruction,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 32),

          Text(
            L.t('exercise'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 8),

          DropdownButtonFormField<ExerciseType>(
            initialValue: _selectedExercise,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: ExerciseType.values
                .map(
                  (e) => DropdownMenuItem<ExerciseType>(
                    value: e,
                    child: Text(e.displayName),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedExercise = value);
              }
            },
          ),

          const SizedBox(height: 32),

          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _startExercise,
              icon: const Icon(Icons.camera_alt),
              label: Text(L.t('start'), style: const TextStyle(fontSize: 18)),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ================================================================
  // LOADING
  // ================================================================

  Widget _buildLoadingView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_hasPermission)
              const Icon(
                Icons.camera_alt_outlined,
                size: 52,
                color: Colors.grey,
              )
            else
              const CircularProgressIndicator(),

            const SizedBox(height: 18),

            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // CAMERA VIEW — live mirror + posture overlay
  // ================================================================

  Widget _buildCameraView() {
    final controller = _cameraController!;

    return Column(
      children: [
        // Instruction banner.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  _analyzer.exercise.instruction,
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),

        // Camera.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Camera preview (live mirror).
                  CameraPreview(controller),

                  // Skeleton overlay.
                  if (_latestPose != null)
                    CustomPaint(
                      painter: SkeletonPainter(
                        pose: _latestPose!,
                        imageSize: _rotatedSize(),
                        previewSize: Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                        rotation: _rotation,
                        isFrontCamera:
                            _cameras[_currentCameraIndex].lensDirection ==
                            CameraLensDirection.front,
                      ),
                    ),

                  // Camera name badge.
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _cameraName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Form feedback banner.
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: _buildFormFeedbackBanner(),
                    ),
                  ),

                  // Bottom form status bar.
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _buildFormStatusBar(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ================================================================
  // IMAGE SIZE
  // ================================================================

  ui.Size _rotatedSize() {
    if (_rotation == InputImageRotation.rotation90deg ||
        _rotation == InputImageRotation.rotation270deg) {
      return ui.Size(_imageHeight.toDouble(), _imageWidth.toDouble());
    }

    return ui.Size(_imageWidth.toDouble(), _imageHeight.toDouble());
  }

  // ================================================================
  // FORM FEEDBACK BANNER (replaces old info banner)
  // ================================================================

  Widget _buildFormFeedbackBanner() {
    final String headline;
    final String detail;
    final Color color;

    if (!_analysis.personDetected) {
      headline = L.t('noBodyDetected');
      detail = '';
      color = Colors.grey;
    } else if (!_analysis.bodyDetected) {
      headline = L.t('noBodyDetected');
      detail = _analysis.feedback.isNotEmpty
          ? _analysis.feedback
          : 'Step back so your full body is visible.';
      color = Colors.orange;
    } else if (_analysis.formIssueKey.isNotEmpty) {
      headline = L.t('formNeedsAdjustment');
      detail = L.t(_analysis.formIssueKey);

      color = switch (_analysis.formQuality) {
        FormQuality.good => Colors.green,
        FormQuality.warning => Colors.orange,
        FormQuality.poor => Colors.red,
        FormQuality.none => Colors.grey,
      };
    } else {
      headline = L.t('formGoodForm');
      detail = L.t('formKeepGoing');
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center, color: color, size: 18),

              const SizedBox(width: 6),

              Flexible(
                child: Text(
                  _analyzer.exercise.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const Spacer(),

              if (_analysis.bodyDetected)
                Icon(Icons.check_circle, color: color, size: 18)
              else
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            headline,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (detail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // ================================================================
  // FORM STATUS BAR — posture only, no reps/sets
  // ================================================================

  Widget _buildFormStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _formStatItem(
              L.t('exercise'),
              _analyzer.exercise.displayName,
            ),
          ),
          Expanded(
            child: _formStatItem(
              'Posture',
              _analysis.bodyDetected
                  ? (_analysis.formQuality == FormQuality.good
                      ? 'Good'
                      : _analysis.formQuality == FormQuality.warning
                          ? 'Adjust'
                          : _analysis.formQuality == FormQuality.poor
                              ? 'Fix'
                              : 'Checking')
                  : 'No body',
            ),
          ),
          Expanded(
            child: _formStatItem(
              'Angle',
              _analysis.bodyDetected && _analysis.primaryAngle > 0
                  ? '${_analysis.primaryAngle.round()}\u00b0'
                  : '--',
            ),
          ),
        ],
      ),
    );
  }

  Widget _formStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),

        const SizedBox(height: 4),

        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// SKELETON PAINTER
// ====================================================================

class SkeletonPainter extends CustomPainter {
  final Pose pose;
  final ui.Size imageSize;
  final ui.Size previewSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;

  static const double _minConfidence = 0.3;

  SkeletonPainter({
    required this.pose,
    required this.imageSize,
    required this.previewSize,
    required this.rotation,
    required this.isFrontCamera,
  });

  ui.Size get _rotatedSize {
    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      return ui.Size(imageSize.height, imageSize.width);
    }

    return imageSize;
  }

  Offset? _toPreview(PoseLandmark landmark) {
    if (landmark.likelihood < _minConfidence) {
      return null;
    }

    final rotated = _rotatedSize;

    if (rotated.width <= 0 || rotated.height <= 0) {
      return null;
    }

    double nx = landmark.x / rotated.width;
    final ny = landmark.y / rotated.height;

    // Mirror skeleton for front camera so it follows
    // the mirrored camera preview naturally.
    if (isFrontCamera) {
      nx = 1.0 - nx;
    }

    return Offset(nx * previewSize.width, ny * previewSize.height);
  }

  @override
  void paint(Canvas canvas, ui.Size size) {
    final landmarks = pose.landmarks;

    if (landmarks.isEmpty) {
      return;
    }

    final linePaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final goodPaint = Paint()..color = Colors.green;

    final lowPaint = Paint()..color = Colors.orange;

    // Draw bones.
    for (final connection in skeletonConnections) {
      final first = landmarks[connection[0]];
      final second = landmarks[connection[1]];

      if (first == null || second == null) {
        continue;
      }

      final pointA = _toPreview(first);
      final pointB = _toPreview(second);

      if (pointA == null || pointB == null) {
        continue;
      }

      canvas.drawLine(pointA, pointB, linePaint);
    }

    // Draw joints.
    for (final landmark in landmarks.values) {
      final position = _toPreview(landmark);

      if (position == null) {
        continue;
      }

      final paint = landmark.likelihood >= 0.7 ? goodPaint : lowPaint;

      canvas.drawCircle(position, 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return pose != oldDelegate.pose ||
        isFrontCamera != oldDelegate.isFrontCamera ||
        imageSize != oldDelegate.imageSize ||
        previewSize != oldDelegate.previewSize ||
        rotation != oldDelegate.rotation;
  }
}

// ====================================================================
// SKELETON CONNECTIONS
// ====================================================================

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
