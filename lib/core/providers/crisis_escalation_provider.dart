import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/crisis_ml_service.dart';

/// Three-tier crisis escalation system.
enum CrisisTier {
  none, // No crisis detected
  tier1, // Keywords detected → in-app banner + breathing prompt
  tier2, // Repeated keywords OR mood ≤3 → full crisis screen
  tier3, // Explicit crisis statement → lock UI to crisis resources
}

extension CrisisTierExt on CrisisTier {
  bool get requiresAction => this != CrisisTier.none;
  bool get isHigh => this == CrisisTier.tier2 || this == CrisisTier.tier3;
  bool get isCritical => this == CrisisTier.tier3;

  String get displayMessage => switch (this) {
        CrisisTier.tier1 =>
          'It sounds like things are hard right now. I\'m here with you.',
        CrisisTier.tier2 =>
          'I\'m genuinely concerned about you. Please reach out for support.',
        CrisisTier.tier3 =>
          'You\'re not alone. Crisis support is available right now.',
        CrisisTier.none => '',
      };
}

class CrisisEscalationState {
  final CrisisTier currentTier;
  final int tier1DetectionsToday;
  final int tier2DetectionsToday;
  final DateTime? lastDetectionAt;
  final bool isSafeConfirmed;
  final List<String> triggeredKeywords;
  /// Raw crisis probability from the ML model (0.0–1.0).
  /// Null when the ML model is unavailable.
  final double? mlCrisisScore;
  /// How the last detection was triggered: 'keyword', 'ml', 'both', or 'none'.
  final String detectionMethod;

  const CrisisEscalationState({
    this.currentTier = CrisisTier.none,
    this.tier1DetectionsToday = 0,
    this.tier2DetectionsToday = 0,
    this.lastDetectionAt,
    this.isSafeConfirmed = false,
    this.triggeredKeywords = const [],
    this.mlCrisisScore,
    this.detectionMethod = 'none',
  });

  CrisisEscalationState copyWith({
    CrisisTier? currentTier,
    int? tier1DetectionsToday,
    int? tier2DetectionsToday,
    DateTime? lastDetectionAt,
    bool? isSafeConfirmed,
    List<String>? triggeredKeywords,
    double? mlCrisisScore,
    String? detectionMethod,
  }) =>
      CrisisEscalationState(
        currentTier: currentTier ?? this.currentTier,
        tier1DetectionsToday:
            tier1DetectionsToday ?? this.tier1DetectionsToday,
        tier2DetectionsToday:
            tier2DetectionsToday ?? this.tier2DetectionsToday,
        lastDetectionAt: lastDetectionAt ?? this.lastDetectionAt,
        isSafeConfirmed: isSafeConfirmed ?? this.isSafeConfirmed,
        triggeredKeywords: triggeredKeywords ?? this.triggeredKeywords,
        mlCrisisScore: mlCrisisScore ?? this.mlCrisisScore,
        detectionMethod: detectionMethod ?? this.detectionMethod,
      );
}

class CrisisEscalationNotifier
    extends StateNotifier<CrisisEscalationState> {
  CrisisEscalationNotifier() : super(const CrisisEscalationState()) {
    _loadPersistedState();
  }

  // ─── Keyword Tiers ────────────────────────────────────

  // Tier 1: general distress (suggest breathing / Maya chat)
  static const _tier1Keywords = {
    'stressed', 'overwhelmed', 'anxious', 'depressed', 'sad', 'lonely',
    'hopeless', 'worthless', 'exhausted', 'burned out', 'giving up',
    'can\'t cope', 'can\'t go on', 'don\'t care anymore', 'not okay',
    'struggling', 'falling apart',
  };

  // Tier 2: explicit crisis signals
  static const _tier2Keywords = {
    'suicide', 'suicidal', 'kill myself', 'end my life', 'don\'t want to live',
    'self-harm', 'self harm', 'hurt myself', 'cutting', 'overdose',
    'want to die', 'rather be dead', 'no reason to live', 'ending it all',
  };

  // Tier 3: immediate crisis (explicit statement of intent/action)
  static const _tier3Keywords = {
    'going to kill myself', 'about to hurt myself', 'i\'m going to end it',
    'taking pills now', 'already hurt myself', 'i\'ve done something',
    'it\'s too late', 'goodbye forever',
  };

  /// Analyse text for crisis signals using both keyword matching and the
  /// on-device ML model.  The keyword scan runs synchronously; ML inference
  /// runs in a background isolate (see [CrisisMlService]) and never blocks
  /// the UI or the chat message stream.
  ///
  /// The final tier is always the *more severe* of the two signals — neither
  /// can downgrade the other.
  Future<CrisisTier> analyzeText(String text) async {
    print("----RUNNING ML INFERENCE-----");
    print("INFERENCE ON: $text");
    final lower = text.toLowerCase();
    final now   = DateTime.now();

    final isNewDay = state.lastDetectionAt == null ||
        state.lastDetectionAt!.day != now.day;
    int t1Count = isNewDay ? 0 : state.tier1DetectionsToday;
    int t2Count = isNewDay ? 0 : state.tier2DetectionsToday;

    // ── 1. Keyword scan (synchronous, always runs) ─────────────────────────
    CrisisTier    keywordTier = CrisisTier.none;
    List<String>  keywords    = [];

    final t3 = _tier3Keywords.where((kw) => lower.contains(kw)).toList();
    if (t3.isNotEmpty) {
      keywordTier = CrisisTier.tier3;
      keywords    = t3;
      t2Count++;
    } else {
      final t2 = _tier2Keywords.where((kw) => lower.contains(kw)).toList();
      if (t2.isNotEmpty) {
        t2Count++;
        keywordTier = CrisisTier.tier2;
        keywords    = t2;
      } else {
        final t1 = _tier1Keywords.where((kw) => lower.contains(kw)).toList();
        if (t1.isNotEmpty) {
          t1Count++;
          keywordTier = t1Count >= 2 ? CrisisTier.tier2 : CrisisTier.tier1;
          keywords    = t1;
          if (keywordTier == CrisisTier.tier2) t2Count++;
        }
      }
    }

    // ── 2. ML scoring (async, background isolate — non-blocking) ──────────
    double     mlCrisisProb = 0.0;
    CrisisTier mlTier       = CrisisTier.none;
    print("ML-RUNNING!");
    final mlScore = await CrisisMlService.score(text);
    if (mlScore.available) {
      mlCrisisProb = mlScore.crisis;
      if (mlScore.crisis >= CrisisMlService.tier3Min) {
        mlTier = CrisisTier.tier3;
      } else if (mlScore.crisis >= CrisisMlService.crisisMin) {
        mlTier = CrisisTier.tier2;
      } else if (mlScore.distress >= CrisisMlService.distressMin) {
        mlTier = CrisisTier.tier1;
      }
    }

    // ── 3. Take the more severe tier (invariant: never downgrade) ──────────
    final finalTier =
        mlTier.index > keywordTier.index ? mlTier : keywordTier;

    final String detectionMethod;
    if (keywordTier != CrisisTier.none && mlTier != CrisisTier.none) {
      detectionMethod = 'both';
    } else if (mlTier != CrisisTier.none) {
      detectionMethod = 'ml';
    } else if (keywordTier != CrisisTier.none) {
      detectionMethod = 'keyword';
    } else {
      detectionMethod = 'none';
    }
    print("FINAL-TIER: $finalTier");
    if (finalTier == CrisisTier.none) return CrisisTier.none;

    await _escalateTo(
      finalTier,
      tier1Count:      t1Count,
      tier2Count:      t2Count,
      keywords:        keywords,
      now:             now,
      mlCrisisScore:   mlCrisisProb,
      detectionMethod: detectionMethod,
    );
    return finalTier;
  }

  /// Escalate based on low mood entry (mood ≤ 3 = tier2, mood ≤ 2 = tier3).
  Future<CrisisTier> analyzeMoodScore(int moodScore) async {
    if (moodScore <= 2) {
      await _escalateTo(
        CrisisTier.tier2,
        tier1Count: state.tier1DetectionsToday,
        tier2Count: state.tier2DetectionsToday + 1,
        keywords: ['low_mood_score_$moodScore'],
        now: DateTime.now(),
      );
      return CrisisTier.tier2;
    }
    if (moodScore <= 3) {
      await _escalateTo(
        CrisisTier.tier1,
        tier1Count: state.tier1DetectionsToday + 1,
        tier2Count: state.tier2DetectionsToday,
        keywords: ['low_mood_score_$moodScore'],
        now: DateTime.now(),
      );
      return CrisisTier.tier1;
    }
    return CrisisTier.none;
  }

  /// User confirmed they are safe — downgrade tier3 to tier1 / clear.
  Future<void> confirmSafe() async {
    state = state.copyWith(
      currentTier: CrisisTier.tier1,
      isSafeConfirmed: true,
    );
    await _persistState();
  }

  /// Dismiss current crisis alert (move to none).
  Future<void> dismiss() async {
    state = state.copyWith(
      currentTier: CrisisTier.none,
      isSafeConfirmed: false,
      triggeredKeywords: [],
    );
    await _persistState();
  }

  /// Reset all crisis state (e.g., end of day / new session).
  Future<void> reset() async {
    state = const CrisisEscalationState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('crisis_state');
  }

  // ─── Internal ─────────────────────────────────────────

  Future<void> _escalateTo(
    CrisisTier tier, {
    required int tier1Count,
    required int tier2Count,
    required List<String> keywords,
    required DateTime now,
    double mlCrisisScore    = 0.0,
    String detectionMethod  = 'keyword',
  }) async {
    // Never downgrade tier automatically (only confirmSafe/dismiss can lower it)
    final newTier =
        tier.index > state.currentTier.index ? tier : state.currentTier;

    state = state.copyWith(
      currentTier:          newTier,
      tier1DetectionsToday: tier1Count,
      tier2DetectionsToday: tier2Count,
      lastDetectionAt:      now,
      isSafeConfirmed:      false,
      triggeredKeywords:    [...state.triggeredKeywords, ...keywords],
      mlCrisisScore:        mlCrisisScore > 0 ? mlCrisisScore : null,
      detectionMethod:      detectionMethod,
    );
    await _persistState();
  }

  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('crisis_tier', state.currentTier.index);
      await prefs.setInt('crisis_t1_count', state.tier1DetectionsToday);
      await prefs.setInt('crisis_t2_count', state.tier2DetectionsToday);
      if (state.lastDetectionAt != null) {
        await prefs.setString(
          'crisis_last_detection',
          state.lastDetectionAt!.toIso8601String(),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tierIndex = prefs.getInt('crisis_tier') ?? 0;
      final t1Count = prefs.getInt('crisis_t1_count') ?? 0;
      final t2Count = prefs.getInt('crisis_t2_count') ?? 0;
      final lastDetectionStr = prefs.getString('crisis_last_detection');

      DateTime? lastDetection;
      if (lastDetectionStr != null) {
        lastDetection = DateTime.tryParse(lastDetectionStr);
      }

      // Reset if it's a new day
      final now = DateTime.now();
      final isNewDay = lastDetection == null ||
          lastDetection.day != now.day ||
          lastDetection.month != now.month;

      if (isNewDay) {
        state = const CrisisEscalationState();
        return;
      }

      state = CrisisEscalationState(
        currentTier: CrisisTier.values[tierIndex.clamp(0, CrisisTier.values.length - 1)],
        tier1DetectionsToday: t1Count,
        tier2DetectionsToday: t2Count,
        lastDetectionAt: lastDetection,
      );
    } catch (_) {}
  }
}

final crisisEscalationProvider = StateNotifierProvider<
    CrisisEscalationNotifier, CrisisEscalationState>(
  (ref) => CrisisEscalationNotifier(),
);
