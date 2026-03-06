import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  const CrisisEscalationState({
    this.currentTier = CrisisTier.none,
    this.tier1DetectionsToday = 0,
    this.tier2DetectionsToday = 0,
    this.lastDetectionAt,
    this.isSafeConfirmed = false,
    this.triggeredKeywords = const [],
  });

  CrisisEscalationState copyWith({
    CrisisTier? currentTier,
    int? tier1DetectionsToday,
    int? tier2DetectionsToday,
    DateTime? lastDetectionAt,
    bool? isSafeConfirmed,
    List<String>? triggeredKeywords,
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

  /// Analyze text for crisis keywords and escalate tier accordingly.
  Future<CrisisTier> analyzeText(String text) async {
    final lower = text.toLowerCase();
    final now = DateTime.now();

    // Reset daily counts at midnight
    final lastDetection = state.lastDetectionAt;
    final isNewDay = lastDetection == null ||
        lastDetection.day != now.day;

    int t1Count = isNewDay ? 0 : state.tier1DetectionsToday;
    int t2Count = isNewDay ? 0 : state.tier2DetectionsToday;

    // Check tier 3 first (highest priority)
    final triggeredT3 =
        _tier3Keywords.where((kw) => lower.contains(kw)).toList();
    if (triggeredT3.isNotEmpty) {
      await _escalateTo(
        CrisisTier.tier3,
        tier1Count: t1Count,
        tier2Count: t2Count + 1,
        keywords: triggeredT3,
        now: now,
      );
      return CrisisTier.tier3;
    }

    // Check tier 2
    final triggeredT2 =
        _tier2Keywords.where((kw) => lower.contains(kw)).toList();
    if (triggeredT2.isNotEmpty) {
      t2Count++;
      await _escalateTo(
        CrisisTier.tier2,
        tier1Count: t1Count,
        tier2Count: t2Count,
        keywords: triggeredT2,
        now: now,
      );
      return CrisisTier.tier2;
    }

    // Check tier 1
    final triggeredT1 =
        _tier1Keywords.where((kw) => lower.contains(kw)).toList();
    if (triggeredT1.isNotEmpty) {
      t1Count++;

      // Escalate to tier 2 if tier 1 detected 2+ times today
      final newTier = t1Count >= 2 ? CrisisTier.tier2 : CrisisTier.tier1;
      await _escalateTo(
        newTier,
        tier1Count: t1Count,
        tier2Count: t2Count,
        keywords: triggeredT1,
        now: now,
      );
      return newTier;
    }

    return CrisisTier.none;
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
  }) async {
    // Never downgrade tier automatically (only confirmSafe/dismiss can lower it)
    final newTier = tier.index > state.currentTier.index ? tier : state.currentTier;

    state = state.copyWith(
      currentTier: newTier,
      tier1DetectionsToday: tier1Count,
      tier2DetectionsToday: tier2Count,
      lastDetectionAt: now,
      isSafeConfirmed: false,
      triggeredKeywords: [
        ...state.triggeredKeywords,
        ...keywords,
      ],
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
