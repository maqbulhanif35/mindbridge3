 import '../services/crisis_ml_service.dart';

 const _tier1Keywords = {
    'stressed', 'overwhelmed', 'anxious', 'depressed', 'sad', 'lonely',
    'hopeless', 'worthless', 'exhausted', 'burned out', 'giving up',
    'can\'t cope', 'can\'t go on', 'don\'t care anymore', 'not okay',
    'struggling', 'falling apart',
  };

  // Tier 2: explicit crisis signals
const _tier2Keywords = {
    'suicide', 'suicidal', 'kill myself', 'end my life', 'don\'t want to live',
    'self-harm', 'self harm', 'hurt myself', 'cutting', 'overdose',
    'want to die', 'rather be dead', 'no reason to live', 'ending it all',
  };

  // Tier 3: immediate crisis (explicit statement of intent/action)
const _tier3Keywords = {
    'going to kill myself', 'about to hurt myself', 'i\'m going to end it',
    'taking pills now', 'already hurt myself', 'i\'ve done something',
    'it\'s too late', 'goodbye forever',
  };
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

Future<CrisisTier> analyzeText(String text) async {
    print("----RUNNING ML INFERENCE-----");
    print("INFERENCE ON: $text");
    final lower = text.toLowerCase();
    final now   = DateTime.now();

    // final isNewDay = state.lastDetectionAt == null ||
    //     state.lastDetectionAt!.day != now.day;
    final isNewDay = false;
    // int t1Count = isNewDay ? 0 : state.tier1DetectionsToday;
    // int t2Count = isNewDay ? 0 : state.tier2DetectionsToday;
    int t1Count = 0;
    int t2Count = 0;
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

    // await _escalateTo(
    //   finalTier,
    //   tier1Count:      t1Count,
    //   tier2Count:      t2Count,
    //   keywords:        keywords,
    //   now:             now,
    //   mlCrisisScore:   mlCrisisProb,
    //   detectionMethod: detectionMethod,
    // );
    return finalTier;
  }
void main()async{
  String te = "I will kill myself";
  await analyzeText(te);
}