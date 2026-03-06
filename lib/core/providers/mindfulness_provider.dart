import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── State ──────────────────────────────────────────────────

class MindfulnessSession {
  final String exerciseId;
  final String exerciseName;
  final int cyclesCompleted;
  final int durationSeconds;
  final DateTime completedAt;

  const MindfulnessSession({
    required this.exerciseId,
    required this.exerciseName,
    required this.cyclesCompleted,
    required this.durationSeconds,
    required this.completedAt,
  });
}

class MindfulnessState {
  final List<MindfulnessSession> todaySessions;
  final String? activeSound;
  final bool soundPlaying;

  const MindfulnessState({
    this.todaySessions = const [],
    this.activeSound,
    this.soundPlaying = false,
  });

  MindfulnessState copyWith({
    List<MindfulnessSession>? todaySessions,
    String? activeSound,
    bool? soundPlaying,
    bool clearSound = false,
  }) {
    return MindfulnessState(
      todaySessions: todaySessions ?? this.todaySessions,
      activeSound: clearSound ? null : (activeSound ?? this.activeSound),
      soundPlaying: soundPlaying ?? this.soundPlaying,
    );
  }

  // Total seconds practiced today
  int get totalSecondsToday =>
      todaySessions.fold(0, (sum, s) => sum + s.durationSeconds);

  int get totalMinutesToday => (totalSecondsToday / 60).floor();

  int get totalSessionsToday => todaySessions.length;

  // IDs of exercises completed at least once today
  Set<String> get completedExerciseIds =>
      todaySessions.map((s) => s.exerciseId).toSet();

  bool isCompletedToday(String exerciseId) =>
      completedExerciseIds.contains(exerciseId);
}

// ─── Notifier ───────────────────────────────────────────────

class MindfulnessNotifier extends Notifier<MindfulnessState> {
  @override
  MindfulnessState build() => const MindfulnessState();

  void recordSession({
    required String exerciseId,
    required String exerciseName,
    required int cyclesCompleted,
    required int durationSeconds,
  }) {
    if (cyclesCompleted < 1) return;
    final session = MindfulnessSession(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      cyclesCompleted: cyclesCompleted,
      durationSeconds: durationSeconds,
      completedAt: DateTime.now(),
    );
    state = state.copyWith(
      todaySessions: [...state.todaySessions, session],
    );
  }

  void setActiveSound(String label) {
    if (state.activeSound == label && state.soundPlaying) {
      // Toggle off
      state = state.copyWith(clearSound: true, soundPlaying: false);
    } else {
      state = state.copyWith(activeSound: label, soundPlaying: true);
    }
  }

  void stopSound() {
    state = state.copyWith(clearSound: true, soundPlaying: false);
  }
}

// ─── Provider ───────────────────────────────────────────────

final mindfulnessProvider =
    NotifierProvider<MindfulnessNotifier, MindfulnessState>(
        MindfulnessNotifier.new);
