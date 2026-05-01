import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../models/streak_model.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';
import 'streak_provider.dart';

// ─── State ──────────────────────────────────────────────────

class MindfulnessSession {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final int cyclesCompleted;
  final int durationSeconds;
  final DateTime completedAt;

  const MindfulnessSession({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.cyclesCompleted,
    required this.durationSeconds,
    required this.completedAt,
  });

  factory MindfulnessSession.fromMap(Map<String, dynamic> m) =>
      MindfulnessSession(
        id: m['id'] as String,
        exerciseId: m['exercise_id'] as String? ?? '',
        exerciseName: m['exercise_name'] as String? ?? '',
        cyclesCompleted: (m['cycles_completed'] as int?) ?? 0,
        durationSeconds: (m['duration_seconds'] as int?) ?? 0,
        completedAt: DateTime.parse(m['completed_at'] as String),
      );

  Map<String, dynamic> toMap(String userId) => {
        'id': id,
        'user_id': userId,
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'cycles_completed': cyclesCompleted,
        'duration_seconds': durationSeconds,
        'completed_at': completedAt.toIso8601String(),
      };
}

class MindfulnessState {
  final List<MindfulnessSession> todaySessions;
  final String? activeSound;
  final bool soundPlaying;
  final bool isLoaded;

  const MindfulnessState({
    this.todaySessions = const [],
    this.activeSound,
    this.soundPlaying = false,
    this.isLoaded = false,
  });

  MindfulnessState copyWith({
    List<MindfulnessSession>? todaySessions,
    String? activeSound,
    bool? soundPlaying,
    bool clearSound = false,
    bool? isLoaded,
  }) {
    return MindfulnessState(
      todaySessions: todaySessions ?? this.todaySessions,
      activeSound: clearSound ? null : (activeSound ?? this.activeSound),
      soundPlaying: soundPlaying ?? this.soundPlaying,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  int get totalSecondsToday =>
      todaySessions.fold(0, (sum, s) => sum + s.durationSeconds);
  int get totalMinutesToday => (totalSecondsToday / 60).floor();
  int get totalSessionsToday => todaySessions.length;
  bool get hasSessionToday => todaySessions.isNotEmpty;

  Set<String> get completedExerciseIds =>
      todaySessions.map((s) => s.exerciseId).toSet();

  bool isCompletedToday(String exerciseId) =>
      completedExerciseIds.contains(exerciseId);
}

// ─── Notifier ───────────────────────────────────────────────

class MindfulnessNotifier extends Notifier<MindfulnessState> {
  static final _client = Supabase.instance.client;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  MindfulnessState build() {
    _loadToday();

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
        _loadToday();
      }
    });

    ref.onDispose(() {
      _audioPlayer.dispose();
    });

    return const MindfulnessState();
  }

  // ── Load today's sessions ────────────────────────────────

  Future<void> _loadToday() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      final now = DateTime.now();
      final startOfDay =
          DateTime(now.year, now.month, now.day).toIso8601String();

      final rows = await _client
          .from('mindfulness_sessions')
          .select()
          .eq('user_id', userId)
          .gte('completed_at', startOfDay)
          .order('completed_at');

      final sessions = (rows as List)
          .map((r) => MindfulnessSession.fromMap(r as Map<String, dynamic>))
          .toList();

      state = state.copyWith(todaySessions: sessions, isLoaded: true);
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  // ── Record a completed session ───────────────────────────

  Future<void> recordSession({
    required String exerciseId,
    required String exerciseName,
    required int cyclesCompleted,
    required int durationSeconds,
  }) async {
    if (cyclesCompleted < 1) return;

    final userId = SupabaseService.currentUser?.id;
    final now = DateTime.now();
    final id = '${userId}_${now.millisecondsSinceEpoch}';

    final session = MindfulnessSession(
      id: id,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      cyclesCompleted: cyclesCompleted,
      durationSeconds: durationSeconds,
      completedAt: now,
    );

    state = state.copyWith(
      todaySessions: [...state.todaySessions, session],
    );

    if (userId != null) {
      try {
        await _client
            .from('mindfulness_sessions')
            .upsert(session.toMap(userId));
      } catch (_) {}
    }

    ref.read(streakProvider.notifier).recordActivity(StreakType.mindfulness);
  }

  // ── Audio controls (audioplayers) ─────────────────────────

  Future<void> setActiveSound(String label) async {
    if (state.activeSound == label && state.soundPlaying) {
      await _audioPlayer.stop();
      state = state.copyWith(clearSound: true, soundPlaying: false);
      return;
    }

    await _audioPlayer.stop();

    try {
      final path =
          'audio/${label.toLowerCase().replaceAll(' ', '_')}.mp3';

      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(path));

      state = state.copyWith(activeSound: label, soundPlaying: true);
    } catch (_) {
      state = state.copyWith(clearSound: true, soundPlaying: false);
    }
  }

  Future<void> stopSound() async {
    await _audioPlayer.stop();
    state = state.copyWith(clearSound: true, soundPlaying: false);
  }

  Future<void> refresh() => _loadToday();
}

// ─── Provider ───────────────────────────────────────────────

final mindfulnessProvider =
    NotifierProvider<MindfulnessNotifier, MindfulnessState>(
        MindfulnessNotifier.new);