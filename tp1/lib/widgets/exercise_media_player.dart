import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../app_theme.dart';
import '../models/exercise.dart';
import 'exercise_3d_viewer.dart';

/// Universal media player for exercise demonstrations.
/// Supports 3D GLB Biomechanics, HTML5 / Video playback with play/pause and looping,
/// and smooth biomechanical anatomy fallback with zero broken asset paths.
class ExerciseMediaPlayer extends StatefulWidget {
  final Exercise exercise;
  final double height;
  final bool autoPlay;
  final VoidCallback? onToggleExpand;

  const ExerciseMediaPlayer({
    super.key,
    required this.exercise,
    this.height = 340,
    this.autoPlay = true,
    this.onToggleExpand,
  });

  @override
  State<ExerciseMediaPlayer> createState() => _ExerciseMediaPlayerState();
}

class _ExerciseMediaPlayerState extends State<ExerciseMediaPlayer> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  @override
  void didUpdateWidget(ExerciseMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id) {
      _disposeVideo();
      _initMedia();
    }
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _hasVideoError = false;
  }

  void _initMedia() {
    // If exercise has 3D asset, 3D viewer handles it
    if (widget.exercise.has3dAnimation && widget.exercise.glbAssetPath != null) {
      return;
    }

    final mediaUrl = widget.exercise.mediaUrl;
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      // Determine URI: if relative, attempt local Vite server on web or localhost
      Uri? uri;
      if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) {
        uri = Uri.tryParse(mediaUrl);
      } else {
        // Try local dev server or relative host
        final host = kIsWeb ? Uri.base.origin : 'http://127.0.0.1:5173';
        uri = Uri.tryParse('$host/$mediaUrl');
      }

      if (uri != null) {
        try {
          final controller = VideoPlayerController.networkUrl(uri);
          _videoController = controller;
          controller.initialize().then((_) {
            if (mounted && _videoController == controller) {
              setState(() {
                _isVideoInitialized = true;
                _hasVideoError = false;
              });
              controller.setLooping(true);
              controller.setVolume(0.0);
              if (widget.autoPlay) {
                controller.play();
                _isPlaying = true;
              }
            }
          }).catchError((err) {
            if (mounted && _videoController == controller) {
              setState(() {
                _hasVideoError = true;
                _isVideoInitialized = false;
              });
            }
          });
        } catch (_) {
          _hasVideoError = true;
        }
      } else {
        _hasVideoError = true;
      }
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;

    // 1. If 3D model is available, use interactive 3D Anatomy viewer
    if (ex.has3dAnimation && ex.glbAssetPath != null) {
      return AnatomyExerciseViewer(
        exercise: ex,
        exerciseId: ex.id,
        animationPath: ex.glbAssetPath,
        primaryMuscles: ex.primaryMuscles,
        secondaryMuscles: ex.secondaryMuscles,
        cameraView: 'Front',
        playbackSpeed: 1.0,
        showMuscleLabels: true,
        height: widget.height,
      );
    }

    // 2. Video demonstration (OpenGym clip or custom video)
    if (_videoController != null && _isVideoInitialized && !_hasVideoError) {
      return Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: _togglePlayPause,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio > 0
                      ? _videoController!.value.aspectRatio
                      : 1.0,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),
            // Play / Pause pulse overlay
            if (!_isPlaying)
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: AppTheme.primaryColor,
                    size: 34,
                  ),
                ),
              ),
            // Bottom controls bar
            Positioned(
              left: 12,
              bottom: 10,
              right: 12,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: AppTheme.primaryColor,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isPlaying ? 'Tap to Pause' : 'Tap to Play',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.loop, color: AppTheme.primaryColor, size: 13),
                        SizedBox(width: 4),
                        Text(
                          'Loop',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 3. High-definition Biomechanical Vector Fallback
    return _BiomechanicalDiagramFallback(
      exercise: ex,
      height: widget.height,
      isLoading: _videoController != null && !_isVideoInitialized && !_hasVideoError,
    );
  }
}

/// Dynamic, responsive biomechanical schematic fallback.
/// Highlights target muscle groups in vibrant neon colors with zero external asset dependencies.
class _BiomechanicalDiagramFallback extends StatelessWidget {
  final Exercise exercise;
  final double height;
  final bool isLoading;

  const _BiomechanicalDiagramFallback({
    required this.exercise,
    required this.height,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.primaryColor;
    final primaryMuscle = exercise.primaryMuscles.isNotEmpty
        ? exercise.primaryMuscles.first
        : exercise.category;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardColor,
            AppTheme.surfaceColor.withValues(alpha: 0.95),
            AppTheme.primaryColor.withValues(alpha: 0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Tech Grid Lines
          Positioned.fill(
            child: CustomPaint(
              painter: _TechGridPainter(),
            ),
          ),

          // Central Anatomical Kinetic Illustration
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Loading Demonstration Clip...',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  // Dynamic Biomechanical Icon
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: catColor.withValues(alpha: 0.14),
                      border: Border.all(
                        color: catColor.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: catColor.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _iconForCategory(exercise.category),
                      color: catColor,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Target Muscle Focus Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: catColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.radar,
                          color: AppTheme.primaryColor,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'TARGET: ${primaryMuscle.toUpperCase()}',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    exercise.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${exercise.category} • ${exercise.equipment} • ${exercise.difficulty}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Top Badges
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fitness_center, size: 12, color: AppTheme.powerliftingAmber),
                  const SizedBox(width: 5),
                  Text(
                    exercise.equipment,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'FORM GUIDE',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'chest':
        return Icons.fitness_center;
      case 'back':
        return Icons.swap_vert;
      case 'shoulders':
        return Icons.airline_seat_recline_extra;
      case 'biceps':
      case 'triceps':
      case 'forearms':
        return Icons.sports_kabaddi;
      case 'quadriceps':
      case 'hamstrings':
      case 'glutes':
      case 'calves':
        return Icons.directions_walk;
      case 'core':
        return Icons.shield_outlined;
      case 'cardio':
        return Icons.directions_run;
      default:
        return Icons.accessibility_new;
    }
  }
}

class _TechGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1.0;

    const double step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

