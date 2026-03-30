import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/providers/mindfulness_provider.dart';
import '../../../core/providers/streak_provider.dart';

class BreathingScreen extends ConsumerStatefulWidget {
  final String? exerciseId;
  const BreathingScreen({super.key, this.exerciseId});

  @override
  ConsumerState<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends ConsumerState<BreathingScreen>
    with TickerProviderStateMixin {
  late Map<String, dynamic> _exercise;
  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;

  bool _isRunning = false;
  int _phase = 0; // 0=inhale, 1=holdIn, 2=exhale, 3=holdOut
  int _cyclesCompleted = 0;
  int _targetCycles = 5;
  String _phaseLabel = 'Ready';
  int _countdown = 0;
  DateTime? _sessionStart;
  bool _sessionRecorded = false;

  static const List<String> _phaseLabels = ['Inhale', 'Hold', 'Exhale', 'Hold'];

  @override
  void initState() {
    super.initState();
    _exercise = AppStrings.breathingExercises.firstWhere(
      (e) => e['id'] == widget.exerciseId,
      orElse: () => AppStrings.breathingExercises[0],
    );
    _breathCtrl = AnimationController(vsync: this);
    _breathAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  List<int> get _phaseDurations => [
        _exercise['inhale'] as int,
        _exercise['holdIn'] as int,
        _exercise['exhale'] as int,
        _exercise['holdOut'] as int,
      ];

  void _startBreathing() {
    setState(() {
      _isRunning = true;
      _phase = 0;
      _cyclesCompleted = 0;
      _sessionRecorded = false;
      _sessionStart = DateTime.now();
    });
    _runPhase();
  }

  Future<void> _stopBreathing({bool auto = false}) async {
    _breathCtrl.stop();
    _breathCtrl.value = 0.6;

    final cycles = _cyclesCompleted;
    final elapsed = _sessionStart != null
        ? DateTime.now().difference(_sessionStart!).inSeconds
        : 0;

    setState(() {
      _isRunning = false;
      _phaseLabel = 'Ready';
      _countdown = 0;
    });

    if (cycles >= 1 && !_sessionRecorded) {
      _sessionRecorded = true;
      // Record in providers
      ref.read(mindfulnessProvider.notifier).recordSession(
            exerciseId: _exercise['id'] as String,
            exerciseName: _exercise['name'] as String,
            cyclesCompleted: cycles,
            durationSeconds: elapsed,
          );
      await ref.read(streakProvider.notifier).recordActivity(StreakType.mindfulness);

      if (mounted) {
        _showCompletionSheet(cycles, elapsed);
      }
    }
  }

  Future<void> _runPhase() async {
    if (!_isRunning) return;

    final duration = _phaseDurations[_phase];
    if (duration == 0) {
      _nextPhase();
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _phaseLabel = _phaseLabels[_phase];
      _countdown = duration;
    });

    if (_phase == 0) {
      _breathCtrl.animateTo(1.0,
          duration: Duration(seconds: duration), curve: Curves.easeInOut);
    } else if (_phase == 2) {
      _breathCtrl.animateTo(0.6,
          duration: Duration(seconds: duration), curve: Curves.easeInOut);
    }

    for (int i = duration; i >= 0; i--) {
      if (!_isRunning) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (_isRunning) _nextPhase();
  }

  void _nextPhase() {
    if (!_isRunning) return;
    setState(() {
      _phase = (_phase + 1) % 4;
      if (_phase == 0) {
        _cyclesCompleted++;
        // Check target
        if (_cyclesCompleted >= _targetCycles) {
          _stopBreathing(auto: true);
          return;
        }
      }
    });
    _runPhase();
  }

  Color get _currentColor {
    final base = Color(_exercise['color'] as int);
    return switch (_phase) {
      0 => base,
      1 => base.withValues(alpha: 0.7),
      2 => base.withValues(alpha: 0.5),
      _ => base.withValues(alpha: 0.4),
    };
  }

  void _showCompletionSheet(int cycles, int seconds) {
    final minutes = (seconds / 60).floor();
    final secs = seconds % 60;
    final timeStr = minutes > 0 ? '${minutes}m ${secs}s' : '${secs}s';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _CompletionSheet(
        exerciseName: _exercise['name'] as String,
        cycles: cycles,
        timeStr: timeStr,
        onDone: () {
          Navigator.pop(context); // close sheet
          if (mounted) context.pop(); // go back to mindfulness
        },
        onRestart: () {
          Navigator.pop(context);
          setState(() {
            _sessionRecorded = false;
          });
          _startBreathing();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_exercise['color'] as int);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () async {
            if (_isRunning) await _stopBreathing();
            if (mounted) context.pop();
          },
        ),
        title: Text(
          _exercise['name'] as String,
          style: const TextStyle(
            fontFamily: 'Nunito',
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          // Target cycles picker
          if (!_isRunning)
            PopupMenuButton<int>(
              icon: const Icon(LucideIcons.target, color: Colors.white70),
              color: const Color(0xFF1A2030),
              onSelected: (v) => setState(() => _targetCycles = v),
              itemBuilder: (_) => [3, 5, 8, 10, 15].map((n) {
                return PopupMenuItem(
                  value: n,
                  child: Text(
                    '$n cycles${n == _targetCycles ? ' ✓' : ''}',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      color: n == _targetCycles ? color : Colors.white70,
                      fontWeight: n == _targetCycles
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                kToolbarHeight -
                MediaQuery.of(context).padding.top,
          ),
          child: IntrinsicHeight(
            child: Column(
              children: [
          const SizedBox(height: 24),

          // ─── Progress Row ────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoPill(
                label: 'Cycles',
                value: '$_cyclesCompleted / $_targetCycles',
                color: color,
              ),
              const SizedBox(width: 16),
              _InfoPill(
                label: 'Phase',
                value: _isRunning ? _phaseLabel : '—',
                color: color,
              ),
            ],
          ),

          const SizedBox(height: 40),

          // ─── Breathing Circle ────────────────────────
          AnimatedBuilder(
            animation: _breathAnim,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  width: 290 * _breathAnim.value,
                  height: 290 * _breathAnim.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _currentColor.withValues(alpha: 0.15),
                      width: 2,
                    ),
                  ),
                ),
                // Middle ring
                Container(
                  width: 240 * _breathAnim.value,
                  height: 240 * _breathAnim.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _currentColor.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                ),
                // Core circle
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _currentColor,
                        _currentColor.withValues(alpha: 0.55),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _currentColor.withValues(alpha: 0.45),
                        blurRadius: 50,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isRunning ? _phaseLabel : 'Tap to Start',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (_countdown > 0 && _isRunning) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$_countdown',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // ─── Phase Indicators ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                ['Inhale', 'Hold', 'Exhale', 'Hold'].asMap().entries.map((e) {
              final i = e.key;
              final dur = _phaseDurations[i];
              if (dur == 0) return const SizedBox.shrink();
              final isActive = _isRunning && _phase == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? color.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      e.value,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: isActive ? color : Colors.white38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${dur}s',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isActive ? Colors.white : Colors.white24,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // ─── Description ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _exercise['description'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── Target label ─────────────────────────────
          if (!_isRunning)
            Text(
              'Target: $_targetCycles cycles • tap ⊙ to change',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),

          const SizedBox(height: 16),

          // ─── Control Button ───────────────────────────
          GestureDetector(
            onTap: _isRunning ? () => _stopBreathing() : _startBreathing,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 2),
                boxShadow: _isRunning
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                _isRunning ? LucideIcons.square : LucideIcons.play,
                color: color,
                size: 36,
              ),
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
          ),
        ),
      ),
    );
  }
}

// ─── Info Pill ────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Completion Sheet ─────────────────────────────────────

class _CompletionSheet extends StatelessWidget {
  final String exerciseName;
  final int cycles;
  final String timeStr;
  final VoidCallback onDone;
  final VoidCallback onRestart;

  const _CompletionSheet({
    required this.exerciseName,
    required this.cycles,
    required this.timeStr,
    required this.onDone,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text('🎉', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text(
            'Session Complete!',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            exerciseName,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(label: 'Cycles', value: '$cycles'),
              const SizedBox(width: 16),
              _StatChip(label: 'Duration', value: timeStr),
              const SizedBox(width: 16),
              _StatChip(label: 'XP Earned', value: '+60'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.flame, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Mindfulness streak updated! Keep it up.',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onRestart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Center(
                      child: Text(
                        'Again',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onDone,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'Done  ✓',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}
