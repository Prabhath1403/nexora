import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with SingleTickerProviderStateMixin {
  int targetMinutes = 25;
  int remainingSeconds = 25 * 60;
  bool isRunning = false;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  void _startTimer() {
    setState(() => isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds > 0) {
        if (mounted) setState(() => remainingSeconds--);
      } else {
        _timer?.cancel();
        if (mounted) setState(() => isRunning = false);
        ApiService.recordFocusSession(targetMinutes, "pomodoro");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Focus session complete! 🎉"),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => isRunning = false);
  }

  void _resetTimer(int minutes) {
    _timer?.cancel();
    setState(() { targetMinutes = minutes; remainingSeconds = minutes * 60; isRunning = false; });
  }

  String _formatTime() {
    final m = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (remainingSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() { _timer?.cancel(); _pulseController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (remainingSeconds / (targetMinutes * 60));

    return CustomScrollView(
      slivers: [
        // Large Title
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Focus", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  const Text("Deep work sessions", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),

        // Timer Ring
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(
              child: SizedBox(
                width: 260, height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background ring
                    SizedBox(
                      width: 240, height: 240,
                      child: CustomPaint(painter: _RingPainter(progress: progress, isRunning: isRunning)),
                    ),
                    // Time display
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formatTime(), style: const TextStyle(
                          fontSize: 54, fontWeight: FontWeight.w200, letterSpacing: 2, fontFamily: '.SF UI Display')),
                        const SizedBox(height: 4),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) => Opacity(
                            opacity: isRunning ? (0.5 + 0.5 * _pulseController.value) : 1.0,
                            child: Text(
                              isRunning ? "FOCUSING" : "READY",
                              style: TextStyle(
                                color: isRunning ? AppTheme.accentGreen : AppTheme.secondaryLabel,
                                fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Duration Selector
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: targetMinutes,
              thumbColor: AppTheme.tertiaryBg,
              backgroundColor: AppTheme.secondaryBg,
              children: const {
                5: Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: Text("5m", style: TextStyle(fontSize: 14))),
                10: Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: Text("10m", style: TextStyle(fontSize: 14))),
                25: Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: Text("25m", style: TextStyle(fontSize: 14))),
                50: Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: Text("50m", style: TextStyle(fontSize: 14))),
              },
              onValueChanged: (int? val) {
                if (!isRunning && val != null) _resetTimer(val);
              },
            ),
          ),
        ),

        // Play / Pause + Reset
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 36),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Main control
                GestureDetector(
                  onTap: isRunning ? _pauseTimer : _startTimer,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunning ? AppTheme.accentRed : AppTheme.accent,
                      boxShadow: [
                        BoxShadow(
                          color: (isRunning ? AppTheme.accentRed : AppTheme.accent).withValues(alpha: 0.4),
                          blurRadius: 24, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => _resetTimer(targetMinutes),
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.secondaryBg,
                    ),
                    child: const Icon(Icons.refresh_rounded, color: AppTheme.secondaryLabel, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Session Counter
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondaryBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_fire_department, color: AppTheme.accentOrange, size: 18),
                  const SizedBox(width: 8),
                  const Text("4 sessions today", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text("100 min", style: TextStyle(fontSize: 12, color: AppTheme.accentOrange, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// Custom ring painter (Apple Watch-style)
class _RingPainter extends CustomPainter {
  final double progress;
  final bool isRunning;

  _RingPainter({required this.progress, required this.isRunning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 8.0;

    // Background ring
    final bgPaint = Paint()
      ..color = AppTheme.tertiaryBg
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -pi / 2,
          endAngle: 3 * pi / 2,
          colors: isRunning
              ? [AppTheme.accentGreen, AppTheme.accentTeal]
              : [AppTheme.accent, AppTheme.accentPurple],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, 2 * pi * progress, false, progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.isRunning != isRunning;
}
