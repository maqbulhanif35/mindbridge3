import 'package:flutter/material.dart';
import '../models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoalTechniqueEngine
//
// Evidence-based technique library and structured wellness plans per goal
// and per stressor. Each goal maps to a real clinical framework (CBT, ACT,
// CBT-I, BA, MBSR, etc.) with specific techniques, a 4-week progression,
// and a Maya conversation protocol.
// ─────────────────────────────────────────────────────────────────────────────

class GoalTechniqueEngine {
  GoalTechniqueEngine._();

  // ── Public API ──────────────────────────────────────────────────────────────

  static GoalPlan? getGoalPlan(String goalId) => _goalPlans[goalId];

  static StressorPlan? getStressorPlan(String stressorId) =>
      _stressorPlans[stressorId];

  /// Returns goal plans for all of the user's selected goals, in order.
  static List<GoalPlan> getUserGoalPlans(UserModel? user) {
    if (user == null || user.goals.isEmpty) return [];
    return user.goals
        .map((g) => _goalPlans[g])
        .whereType<GoalPlan>()
        .toList();
  }

  /// Returns stressor plans for all selected stressors, in order.
  static List<StressorPlan> getUserStressorPlans(UserModel? user) {
    if (user == null || user.stressors.isEmpty) return [];
    return user.stressors
        .map((s) => _stressorPlans[s])
        .whereType<StressorPlan>()
        .toList();
  }

  /// Builds a clinical protocol addendum for Maya's system prompt.
  /// This tells Maya exactly which evidence-based approach to apply.
  static String buildClinicalProtocolBlock(UserModel? user) {
    if (user == null || user.goals.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln(
        '\n[Clinical framework — apply these protocols naturally, never mechanically]');

    for (final goalId in user.goals.take(3)) {
      final plan = _goalPlans[goalId];
      if (plan == null) continue;
      buffer.writeln('• ${plan.title}: ${plan.mayaProtocol}');
    }

    for (final stressorId in user.stressors.take(2)) {
      final plan = _stressorPlans[stressorId];
      if (plan == null) continue;
      buffer.writeln('• ${plan.title} (stressor): ${plan.mayaProtocol}');
    }

    return buffer.toString();
  }

  // ── Goal Plans ──────────────────────────────────────────────────────────────

  static final Map<String, GoalPlan> _goalPlans = {
    // ── ANXIETY ──────────────────────────────────────────────────────────────
    'anxiety': GoalPlan(
      id: 'anxiety',
      title: 'Managing Anxiety',
      emoji: '😌',
      color: const Color(0xFF00BEB4),
      clinicalApproach: 'CBT + Acceptance & Commitment Therapy (ACT)',
      approachNote:
          'Cognitive Behavioral Therapy helps you identify and reframe anxious thoughts. ACT teaches you to hold thoughts without being controlled by them. Together they\'re the most evidence-backed approach for anxiety.',
      techniques: [
        WellnessTechnique(
          name: '4-7-8 Breathing',
          emoji: '🌬️',
          duration: '5 min',
          description:
              'Inhale for 4, hold for 7, exhale for 8 seconds. Activates your parasympathetic system — the physiological off-switch for anxiety.',
          whenToUse: 'Any time anxiety spikes. Before exams, presentations, or difficult conversations.',
          evidenceNote: 'Activates the vagus nerve, reducing cortisol within 2–4 cycles.',
          category: TechniqueCategory.breathing,
        ),
        WellnessTechnique(
          name: '5-4-3-2-1 Grounding',
          emoji: '🌍',
          duration: '3 min',
          description:
              'Name 5 things you see, 4 you can touch, 3 you hear, 2 you smell, 1 you taste. Anchors your mind to the present, breaking the anxiety cycle.',
          whenToUse: 'During panic or spiralling thoughts. Anywhere, discreetly.',
          evidenceNote: 'Sensory grounding interrupts the amygdala\'s threat response loop.',
          category: TechniqueCategory.mindfulness,
        ),
        WellnessTechnique(
          name: 'Cognitive Restructuring',
          emoji: '🧠',
          duration: '10 min',
          description:
              'Write the anxious thought → identify the cognitive distortion (catastrophising? mind-reading?) → generate a balanced, evidence-based alternative.',
          whenToUse: 'When a specific worry keeps returning. Use your journal.',
          evidenceNote: 'Core CBT technique — changes neural pathways over 4–8 weeks.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Worry Time Scheduling',
          emoji: '⏰',
          duration: '15 min/day',
          description:
              'Dedicate 15 minutes daily to all your worries. When anxiety appears outside that window, note it and defer it. This contains worry rather than suppressing it.',
          whenToUse: 'Daily — pick a fixed time (e.g., 5pm). Not before bed.',
          evidenceNote: 'Reduces intrusive thoughts by 40% in controlled studies.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Thought Defusion (ACT)',
          emoji: '🌱',
          duration: '2 min',
          description:
              'Instead of "I\'m anxious", say "I notice I\'m having the thought that I\'m anxious." Creates psychological distance between you and your thoughts.',
          whenToUse: 'When thoughts feel overwhelming or all-consuming.',
          evidenceNote:
              'ACT defusion reduces anxiety\'s power without requiring you to change the thought.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Progressive Muscle Relaxation',
          emoji: '💆',
          duration: '10 min',
          description:
              'Tense each muscle group for 5 seconds, then release for 30. Start from your feet, work upward. Releases physically stored anxiety.',
          whenToUse: 'Before bed or after a stressful day. Lying down is best.',
          evidenceNote: 'Reduces somatic anxiety symptoms by releasing held muscle tension.',
          category: TechniqueCategory.body,
        ),
      ],
      weeklyPlan: [
        WeeklyFocus(
          week: 1,
          theme: 'Build Body Awareness',
          focus: 'Learn to notice anxiety in your body before your mind spirals.',
          actions: [
            'Practice 4-7-8 breathing once daily',
            'Journal: where does anxiety live in your body?',
            'Use 5-4-3-2-1 grounding when worried',
          ],
        ),
        WeeklyFocus(
          week: 2,
          theme: 'Catch the Thoughts',
          focus: 'Start identifying the thoughts that trigger anxiety.',
          actions: [
            'Log one anxious thought per day in your journal',
            'Schedule your daily worry time (15 min)',
            'Add PMR to your evening routine',
          ],
        ),
        WeeklyFocus(
          week: 3,
          theme: 'Challenge & Reframe',
          focus: 'Apply cognitive restructuring to your most frequent anxious thoughts.',
          actions: [
            'Restructure 1 thought per day (journal)',
            'Practice thought defusion during worry time',
            'Reduce breathing to 3 cycles before stressors',
          ],
        ),
        WeeklyFocus(
          week: 4,
          theme: 'Sustain & Integrate',
          focus: 'Make anxiety tools automatic — use them without thinking.',
          actions: [
            'Identify your 2 most effective techniques',
            'Create a personal anxiety protocol card',
            'Reflect on what has changed in your body and thoughts',
          ],
        ),
      ],
      mayaProtocol:
          'Use CBT principles — help identify automatic negative thoughts, label cognitive distortions (catastrophising, mind-reading, etc.), and guide gentle cognitive restructuring. Apply ACT defusion language: "I notice I\'m having the thought that...". Never dismiss the anxiety — acknowledge it physiologically first.',
    ),

    // ── DEPRESSION / LOW MOOD ─────────────────────────────────────────────────
    'depression': GoalPlan(
      id: 'depression',
      title: 'Coping with Low Mood',
      emoji: '💙',
      color: const Color(0xFF6C63FF),
      clinicalApproach: 'Behavioural Activation (BA) + Self-Compassion',
      approachNote:
          'Behavioural Activation is as effective as antidepressants for mild-moderate depression. It breaks the cycle of inactivity → low mood → more inactivity. Self-compassion work counters the harsh inner critic depression amplifies.',
      techniques: [
        WellnessTechnique(
          name: 'Behavioural Activation',
          emoji: '🚶',
          duration: '5–30 min',
          description:
              'Schedule one small, meaningful activity before you feel like doing it — not after. Depression lies and says motivation comes before action. It\'s the other way around.',
          whenToUse: 'Every day. Start with 5 minutes of something you once enjoyed.',
          evidenceNote: 'BA is as effective as CBT and medication for mild-moderate depression.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Opposite Action (DBT)',
          emoji: '🔄',
          duration: '5 min',
          description:
              'Identify what depression tells you to do (stay in bed, isolate, avoid) — then do the opposite. Not with full force, but with one small step in the other direction.',
          whenToUse: 'When the urge to withdraw or shut down is strongest.',
          evidenceNote:
              'DBT Opposite Action reduces the intensity and duration of depressive episodes.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Gratitude & Savoring',
          emoji: '🌸',
          duration: '5 min',
          description:
              'Write 3 specific things that went okay today — even tiny ones. Then spend 30 seconds actually feeling each one. Savoring rewires the brain\'s negativity bias.',
          whenToUse: 'Morning or before bed. Consistency over intensity.',
          evidenceNote:
              'Sustained gratitude practice increases positive affect over 6–8 weeks.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Self-Compassion Break',
          emoji: '🤗',
          duration: '3 min',
          description:
              '1. Acknowledge the suffering: "This is really hard." 2. Remind yourself it\'s human: "Everyone struggles." 3. Offer kindness: "May I be gentle with myself right now." Based on Kristin Neff\'s research.',
          whenToUse: 'When self-criticism is loud. When you feel like a failure.',
          evidenceNote:
              'Self-compassion reduces depression symptoms independently of self-esteem levels.',
          category: TechniqueCategory.mindfulness,
        ),
        WellnessTechnique(
          name: 'Connection Scheduling',
          emoji: '👥',
          duration: '15–30 min',
          description:
              'Schedule one human interaction today — a message, a phone call, showing up somewhere. Depression thrives in isolation. Connection is medicine.',
          whenToUse: 'Daily. Even a short text counts. Lower the bar to near zero.',
          evidenceNote: 'Social connection is the single strongest predictor of mood recovery.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Values Activation',
          emoji: '🎯',
          duration: '10 min',
          description:
              'Identify one of your core values (family, creativity, learning) → do one small action aligned with it today. Purpose-driven action is the most powerful antidepressant.',
          whenToUse: 'Weekly planning. Ask: "What matters to me, and did I touch it today?"',
          evidenceNote: 'Values-based action is the primary mechanism in ACT for depression.',
          category: TechniqueCategory.cognitive,
        ),
      ],
      weeklyPlan: [
        WeeklyFocus(
          week: 1,
          theme: 'Lower the Bar',
          focus: 'Any action is a win. Start absurdly small.',
          actions: [
            'Pick ONE activity per day — 5 minutes only',
            'Write one thing that was okay (not "good") each evening',
            'Tell Maya how you\'re actually feeling each day',
          ],
        ),
        WeeklyFocus(
          week: 2,
          theme: 'Build Momentum',
          focus: 'Small actions are starting to compound.',
          actions: [
            'Add a second micro-activity to your day',
            'Begin a daily gratitude + savoring practice',
            'Schedule one human connection this week',
          ],
        ),
        WeeklyFocus(
          week: 3,
          theme: 'Counter the Inner Critic',
          focus: 'Address the self-critical thoughts that fuel low mood.',
          actions: [
            'Practice self-compassion breaks when self-criticism appears',
            'Journal: what would I say to a friend feeling this?',
            'Apply Opposite Action to one avoidance pattern',
          ],
        ),
        WeeklyFocus(
          week: 4,
          theme: 'Connect to Values',
          focus: 'Ground your actions in what truly matters to you.',
          actions: [
            'Identify your top 3 values',
            'Do one values-aligned activity',
            'Review: what worked? What helped most?',
          ],
        ),
      ],
      mayaProtocol:
          'Use Behavioural Activation language — focus on action before feeling, not waiting to feel motivated. Validate the weight of low mood without reinforcing hopelessness. Offer micro-commitments ("just one thing"). Apply self-compassion language (Kristin Neff) when self-criticism appears. Avoid toxic positivity — "it makes sense you feel this way" before any reframe.',
    ),

    // ── ACADEMIC STRESS ────────────────────────────────────────────────────────
    'stress': GoalPlan(
      id: 'stress',
      title: 'Managing Academic Stress',
      emoji: '📚',
      color: const Color(0xFFF59E0B),
      clinicalApproach: 'Stress Inoculation Training + Problem-Solving Therapy',
      approachNote:
          'SIT teaches you to prepare for and work through stressors in graduated steps. Problem-Solving Therapy breaks overwhelming situations into solvable chunks. Both are highly effective for academic environments.',
      techniques: [
        WellnessTechnique(
          name: 'Brain Dump + Priority Matrix',
          emoji: '🗂️',
          duration: '10 min',
          description:
              'Write every task on your mind — no filter. Then categorise: Urgent+Important (do now), Important+Not Urgent (schedule), Urgent+Not Important (delegate or minimize), Neither (drop).',
          whenToUse: 'Every Sunday evening or when overwhelmed by your to-do list.',
          evidenceNote: 'Externalising cognitive load reduces perceived stress by up to 30%.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Pomodoro Technique',
          emoji: '🍅',
          duration: '25/5 min cycles',
          description:
              'Work with full focus for 25 minutes → 5-minute break. After 4 cycles, take a 30-minute break. Trains focus, prevents burnout, and makes large tasks feel manageable.',
          whenToUse: 'Any study session. Especially effective before CATs.',
          evidenceNote:
              'Regular breaks restore cognitive resources and prevent decision fatigue.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Box Breathing',
          emoji: '🌬️',
          duration: '4 min',
          description:
              'Inhale for 4, hold for 4, exhale for 4, hold for 4. Navy SEAL protocol for regulating stress in high-pressure performance situations.',
          whenToUse: 'Before exams, CATs, presentations, or when overwhelm hits mid-study.',
          evidenceNote: 'Box breathing reduces cortisol and increases pre-frontal cortex activity.',
          category: TechniqueCategory.breathing,
        ),
        WellnessTechnique(
          name: 'Study-Rest Cycles',
          emoji: '⚡',
          duration: 'Ongoing',
          description:
              'Plan study in blocks with deliberate rest. Cognitive performance peaks at 90-minute ultradian cycles. Work with your biology, not against it.',
          whenToUse: 'Design your study schedule around 90-minute deep work blocks.',
          evidenceNote:
              'Ultradian rhythms mean rest is not laziness — it\'s required for consolidation.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Cognitive Decoupling',
          emoji: '🧠',
          duration: '5 min',
          description:
              'Separate task performance from self-worth. Your exam result is not a verdict on your value as a person. Write: "The worst realistic outcome is X. I could handle X because..."',
          whenToUse: 'When stress is really about what failure would mean about you.',
          evidenceNote: 'Decoupling identity from performance reduces test anxiety significantly.',
          category: TechniqueCategory.cognitive,
        ),
      ],
      weeklyPlan: [
        WeeklyFocus(
          week: 1,
          theme: 'Get Clear',
          focus: 'Name everything that is stressing you — then organise it.',
          actions: [
            'Do a brain dump — every task and worry on paper',
            'Build a simple priority matrix for the week',
            'Use box breathing before each study session',
          ],
        ),
        WeeklyFocus(
          week: 2,
          theme: 'Work Smarter',
          focus: 'Structure study to match how your brain actually works.',
          actions: [
            'Start Pomodoro for all study sessions',
            'Build in deliberate rest after 90-minute blocks',
            'Identify your peak focus hours and protect them',
          ],
        ),
        WeeklyFocus(
          week: 3,
          theme: 'Mental Stress Fitness',
          focus: 'Build stress resilience, not just stress management.',
          actions: [
            'Cognitive decoupling: separate performance from identity',
            'Stress inoculation: mentally rehearse challenging scenarios',
            'Add movement to your day — it processes cortisol physically',
          ],
        ),
        WeeklyFocus(
          week: 4,
          theme: 'Protect Your Recovery',
          focus: 'Sustainable study requires deliberate recovery.',
          actions: [
            'Protect sleep — it consolidates everything you studied',
            'Design a post-CAT/exam recovery ritual',
            'Identify your stress early-warning signs for next semester',
          ],
        ),
      ],
      mayaProtocol:
          'Use Problem-Solving Therapy framing: break overwhelming situations into small, solvable steps. Acknowledge Kenyan academic pressures specifically (CATs, HELB, attachment). Validate the objective difficulty before offering strategy. Use Stress Inoculation — help them mentally prepare for difficult scenarios rather than avoid thinking about them.',
    ),

    // ── SLEEP ─────────────────────────────────────────────────────────────────
    'sleep': GoalPlan(
      id: 'sleep',
      title: 'Better Sleep',
      emoji: '😴',
      color: const Color(0xFF4C6EF5),
      clinicalApproach: 'CBT-I (Cognitive Behavioural Therapy for Insomnia)',
      approachNote:
          'CBT-I is the gold-standard treatment for insomnia — more effective than sleep medication with no side effects. It addresses the thoughts and behaviours that perpetuate poor sleep, rather than just the symptom.',
      techniques: [
        WellnessTechnique(
          name: 'Sleep Hygiene Protocol',
          emoji: '🌙',
          duration: 'Ongoing',
          description:
              'Keep a consistent wake time every day (including weekends). Make your bed only for sleep. Keep your room cool (18-20°C), dark, and quiet. No screens 45 minutes before bed.',
          whenToUse: 'Every day. Consistency is the foundation of good sleep.',
          evidenceNote:
              'A consistent wake time is the single most powerful regulator of your circadian rhythm.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Stimulus Control',
          emoji: '🛏️',
          duration: 'Ongoing',
          description:
              'Use your bed ONLY for sleep (and intimacy). If you can\'t sleep after 20 minutes, get up and do something quiet in dim light until you\'re sleepy. Return to bed only when drowsy.',
          whenToUse: 'Every night — especially when you notice yourself lying awake thinking.',
          evidenceNote: 'Stimulus control retrains the bed-sleep association within 2–3 weeks.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: '4-7-8 Pre-Sleep Breathing',
          emoji: '🌬️',
          duration: '5 min',
          description:
              'Inhale for 4, hold for 7, exhale for 8. Do 4 cycles lying down, lights off. Slows heart rate and signals the nervous system that sleep is safe.',
          whenToUse: 'In bed, as your final pre-sleep activity.',
          evidenceNote: 'Activates the parasympathetic system — physiologically prepares the body for sleep.',
          category: TechniqueCategory.breathing,
        ),
        WellnessTechnique(
          name: 'Wind-Down Ritual',
          emoji: '🕯️',
          duration: '30 min',
          description:
              'Create a consistent 30-minute pre-sleep sequence: dim lights, stop screens, do something calm (reading, stretching, journaling worries). Your brain learns that this sequence ends in sleep.',
          whenToUse: '30–45 minutes before your target sleep time. Every night.',
          evidenceNote: 'Conditioned sleep rituals reduce sleep onset latency by signalling the brain.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Worry Dump Pre-Bed',
          emoji: '📝',
          duration: '10 min',
          description:
              'At 9pm (not in bed), write all your worries and tomorrow\'s tasks. Tell your brain: "It\'s written down. You don\'t need to keep hold of it." Then close the notebook.',
          whenToUse: 'Before starting your wind-down ritual. Keep the notebook outside the bedroom.',
          evidenceNote: 'Pre-sleep worry journaling reduces cognitive arousal — the primary cause of insomnia.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Sleep Restriction Therapy',
          emoji: '⏱️',
          duration: '2–4 weeks',
          description:
              'Temporarily restrict your time in bed to your actual sleep time (e.g., if you sleep 5hrs, only spend 5hrs in bed). Builds sleep pressure that drives deeper, more efficient sleep. Gradually extend as efficiency improves.',
          whenToUse: 'Under guidance — for chronic insomnia. Discuss with Maya first.',
          evidenceNote: 'Most powerful CBT-I technique — 80%+ efficacy for chronic insomnia.',
          category: TechniqueCategory.behavioural,
        ),
      ],
      weeklyPlan: [
        WeeklyFocus(
          week: 1,
          theme: 'Establish Your Anchors',
          focus: 'Set a fixed wake time and build your wind-down ritual.',
          actions: [
            'Set the same wake time every day for 7 days',
            'Create a 30-minute wind-down sequence',
            'Stop screens 45 minutes before bed',
          ],
        ),
        WeeklyFocus(
          week: 2,
          theme: 'Control Your Sleep Environment',
          focus: 'Make your bedroom a sleep sanctuary.',
          actions: [
            'Implement stimulus control — bed only for sleep',
            'Start the pre-bed worry dump nightly',
            'Add 4-7-8 breathing as your sleep trigger',
          ],
        ),
        WeeklyFocus(
          week: 3,
          theme: 'Address Sleep Thoughts',
          focus: 'Challenge beliefs that keep you awake.',
          actions: [
            'Journal: what beliefs do you have about sleep?',
            'Challenge catastrophic sleep thoughts (CBT)',
            'Track sleep quality alongside mood in MindBridge',
          ],
        ),
        WeeklyFocus(
          week: 4,
          theme: 'Protect Your Progress',
          focus: 'Sleep health is ongoing — identify your personal sleep threats.',
          actions: [
            'Identify your top 3 sleep disruptors',
            'Build a weekend sleep strategy (don\'t oversleep)',
            'Reflect: how has your mood changed with better sleep?',
          ],
        ),
      ],
      mayaProtocol:
          'Apply CBT-I principles. Avoid reinforcing sleep effort — striving to sleep makes it harder. Use paradoxical intention language: "try to stay awake with your eyes closed". Emphasise the stimulus control and consistent wake time as the two highest-leverage changes. Validate how profoundly sleep deprivation affects mood, concentration, and stress.',
    ),

    // ── SOCIAL CONFIDENCE ─────────────────────────────────────────────────────
    'social': GoalPlan(
      id: 'social',
      title: 'Social Confidence',
      emoji: '🤝',
      color: const Color(0xFFFF6B9D),
      clinicalApproach: 'Social Skills Training + Graduated Exposure',
      approachNote:
          'Social anxiety responds best to graduated exposure — approaching feared situations in increasing order of difficulty. Combined with social skills practice, this builds genuine confidence from the ground up.',
      techniques: [
        WellnessTechnique(
          name: 'Exposure Hierarchy',
          emoji: '🪜',
          duration: 'Ongoing',
          description:
              'List social situations from least to most anxiety-provoking. Start at the bottom — stay in each until your anxiety drops by 50%. Move up only when ready. Avoidance maintains social anxiety; exposure reduces it.',
          whenToUse: 'As your weekly practice — one rung per week minimum.',
          evidenceNote:
              'Graduated exposure is the most effective treatment for social anxiety disorder.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'DEAR MAN (DBT)',
          emoji: '🗣️',
          duration: '5 min to learn',
          description:
              'Describe the situation → Express feelings → Assert what you want → Reinforce the other person → stay Mindful → Appear confident → Negotiate. A structured framework for effective communication.',
          whenToUse: 'Before any conversation where you want to express a need or set a limit.',
          evidenceNote: 'DBT interpersonal effectiveness — proven in clinical trials for social functioning.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Post-Event Processing Correction',
          emoji: '🔍',
          duration: '5 min',
          description:
              'After a social interaction, our bias is to replay only what went wrong. Force yourself to list 3 things that went okay — regardless of how small. Correct the negative post-event filter.',
          whenToUse: 'Within 30 minutes after any social interaction you feel anxious about.',
          evidenceNote:
              'Negative post-event processing maintains social anxiety — correcting it disrupts the cycle.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Box Breathing Before Social',
          emoji: '🌬️',
          duration: '3 min',
          description:
              'Do 4 cycles of box breathing (4-4-4-4) immediately before any social situation. Reduces visible anxiety symptoms and increases confidence.',
          whenToUse: '5 minutes before entering social situations, making calls, or speaking up.',
          evidenceNote: 'Physiological regulation reduces the anxiety signals others misread as disinterest.',
          category: TechniqueCategory.breathing,
        ),
        WellnessTechnique(
          name: 'Connection Micro-Challenges',
          emoji: '✨',
          duration: '1–5 min',
          description:
              'Small daily connection challenges: smile at someone, ask a classmate one question, send one message you\'ve been drafting. Frequency of small connections builds social fluency.',
          whenToUse: 'Daily. Pick one micro-challenge each morning.',
          evidenceNote: 'Frequent, low-stakes social practice is more effective than occasional high-stakes attempts.',
          category: TechniqueCategory.behavioural,
        ),
      ],
      weeklyPlan: [
        WeeklyFocus(
          week: 1,
          theme: 'Map Your Exposure Ladder',
          focus: 'Build your personal social hierarchy from easiest to hardest.',
          actions: [
            'List 10 social situations ranked by anxiety (0–10)',
            'Start with rungs 1–3 this week',
            'Practice post-event processing after each',
          ],
        ),
        WeeklyFocus(
          week: 2,
          theme: 'Daily Micro-Connections',
          focus: 'Build social muscle through frequent low-stakes practice.',
          actions: [
            'One micro-challenge per day (smile, ask, text)',
            'Learn DEAR MAN — role play it with Maya',
            'Box breathing before any social situation this week',
          ],
        ),
        WeeklyFocus(
          week: 3,
          theme: 'Climb the Ladder',
          focus: 'Approach situations that felt too scary in week 1.',
          actions: [
            'Move to rungs 4–6 on your exposure ladder',
            'Apply DEAR MAN in one real situation',
            'Journal: what surprised you positively this week?',
          ],
        ),
        WeeklyFocus(
          week: 4,
          theme: 'Consolidate & Push',
          focus: 'Social confidence is built through repetition, not breakthroughs.',
          actions: [
            'Reflect on your progress on the exposure ladder',
            'Challenge yourself to one conversation you\'ve avoided',
            'Rewrite your social narrative: who are you becoming?',
          ],
        ),
      ],
      mayaProtocol:
          'Use graduated exposure language — never push too fast, but gently challenge avoidance. Celebrate any social action, no matter how small. Apply post-event processing correction explicitly. Normalise social anxiety as the brain\'s threat system doing its job, not a personality flaw. Use DEAR MAN framing when the user needs to have a difficult conversation.',
    ),

    // ── MOTIVATION ────────────────────────────────────────────────────────────
    'motivation': GoalPlan(
      id: 'motivation',
      title: 'Boosting Motivation',
      emoji: '🚀',
      color: const Color(0xFFFF8C42),
      clinicalApproach: 'Motivational Interviewing + Habit Formation (BJ Fogg)',
      approachNote:
          'Motivational Interviewing helps you clarify your own "why" — sustainable motivation must come from within. BJ Fogg\'s Tiny Habits model shows that behaviour change succeeds through small wins, not willpower.',
      techniques: [
        WellnessTechnique(
          name: 'Values Clarification',
          emoji: '🎯',
          duration: '15 min',
          description:
              'List your top 5 values (family, growth, creativity, freedom, etc.) → rank them → ask: is what I\'m working toward aligned with what I actually value? Motivation flows naturally from values alignment.',
          whenToUse: 'Monthly or whenever motivation feels hollow.',
          evidenceNote: 'Intrinsic motivation (values-driven) outlasts extrinsic motivation by 3–5x.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Implementation Intentions',
          emoji: '📅',
          duration: '5 min',
          description:
              '"When [situation], I will [behaviour] for [duration]." E.g., "When my 8am alarm rings, I will open my notes for 10 minutes." Specificity triples follow-through rates.',
          whenToUse: 'Every Sunday — plan your week\'s key intentions.',
          evidenceNote: 'Increased goal follow-through by 2–3x in meta-analyses.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Tiny Habits (2-Minute Rule)',
          emoji: '⚡',
          duration: '2 min start',
          description:
              'Scale any habit down to 2 minutes. "Read for 30 minutes" → "open the book." "Exercise for an hour" → "put on my shoes." Starting is the hardest part. Two minutes always wins over nothing.',
          whenToUse: 'For any habit you keep failing to start.',
          evidenceNote: 'Identity-based habits succeed when the barrier to entry is removed.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Temptation Bundling',
          emoji: '🎵',
          duration: 'Ongoing',
          description:
              'Pair something you want to do (music, podcast, coffee) with something you need to do (study, exercise, admin). Only have the "want" when doing the "need".',
          whenToUse: 'For recurring tasks you procrastinate on.',
          evidenceNote: 'Increases engagement with aversive tasks by making them conditionally rewarding.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Momentum Tracking',
          emoji: '🔥',
          duration: '1 min/day',
          description:
              'Track streaks visually — your MindBridge streak IS this technique. "Don\'t break the chain" is a powerful motivational heuristic. One day at a time.',
          whenToUse: 'Daily. Check your streak. Let it motivate the next check-in.',
          evidenceNote: 'Visual progress tracking increases intrinsic motivation and task completion.',
          category: TechniqueCategory.behavioural,
        ),
      ],
      weeklyPlan: [
        WeeklyFocus(
          week: 1,
          theme: 'Find Your Why',
          focus: 'Sustainable motivation starts with clarity about what you actually want.',
          actions: [
            'Complete a values clarification exercise',
            'Write your "motivation statement" — one honest sentence',
            'Identify the one habit that would change everything',
          ],
        ),
        WeeklyFocus(
          week: 2,
          theme: 'Make It Tiny',
          focus: 'Shrink your most important habit to its 2-minute version.',
          actions: [
            'Identify your most important habit this week',
            'Scale it to 2 minutes — commit to JUST that',
            'Create your implementation intention for it',
          ],
        ),
        WeeklyFocus(
          week: 3,
          theme: 'Stack and Bundle',
          focus: 'Attach your habits to things you already do.',
          actions: [
            'Habit stack: after [existing routine], I will [new habit]',
            'Bundle one temptation with one important task',
            'Track your consecutive days — protect your streak',
          ],
        ),
        WeeklyFocus(
          week: 4,
          theme: 'Become the Identity',
          focus: '"I am someone who..." is more powerful than "I want to..."',
          actions: [
            'Reframe: from goal to identity ("I am a person who studies consistently")',
            'Journal: what evidence do I have for this identity this month?',
            'Plan next month with your motivation insight',
          ],
        ),
      ],
      mayaProtocol:
          'Use Motivational Interviewing — explore ambivalence without pushing. Evoke motivation from the user\'s own values and goals. Use reflective listening and importance/confidence rulers. Apply BJ Fogg language: celebrate tiny wins enthusiastically. Never shame lack of motivation — normalise it and redirect to structure.',
    ),

    // ── MINDFULNESS ───────────────────────────────────────────────────────────
    'mindfulness': GoalPlan(
      id: 'mindfulness',
      title: 'Mindfulness Practice',
      emoji: '🧘',
      color: const Color(0xFF06D6A0),
      clinicalApproach: 'MBSR (Mindfulness-Based Stress Reduction — Kabat-Zinn)',
      approachNote:
          'MBSR is one of the most researched wellness interventions. 8 weeks of practice produces measurable changes in brain structure — more grey matter in the prefrontal cortex, smaller amygdala reactivity.',
      techniques: [
        WellnessTechnique(
          name: 'STOP Practice',
          emoji: '🛑',
          duration: '1 min',
          description:
              'Stop → Take a breath → Observe (thoughts, feelings, body) → Proceed mindfully. The most practical mindfulness tool for a busy student life.',
          whenToUse: 'Any transition point: between classes, before meals, when stress spikes.',
          evidenceNote: 'Brief mindful pauses reduce cortisol and restore attentional focus.',
          category: TechniqueCategory.mindfulness,
        ),
        WellnessTechnique(
          name: 'Physiological Sigh',
          emoji: '😮‍💨',
          duration: '15 seconds',
          description:
              'Double-inhale through the nose (short + extend), then long exhale through mouth. This deflates the alveoli and is the fastest physiological way to reduce stress.',
          whenToUse: 'Any moment. It works in 15 seconds — no one needs to know you\'re doing it.',
          evidenceNote: 'Faster stress reduction than any other breathing technique (Huberman Lab, Stanford).',
          category: TechniqueCategory.breathing,
        ),
        WellnessTechnique(
          name: 'Formal Sitting Meditation',
          emoji: '🧘',
          duration: '10–20 min',
          description:
              'Sit comfortably, close eyes, focus on breath. When attention wanders (it will), notice it and return gently. The noticing and returning IS the practice — not staying focused.',
          whenToUse: 'Same time every day — morning is best for most people.',
          evidenceNote: 'Daily practice for 8 weeks measurably alters brain structure.',
          category: TechniqueCategory.mindfulness,
        ),
        WellnessTechnique(
          name: 'Body Scan',
          emoji: '🔍',
          duration: '15 min',
          description:
              'Slowly move attention from toes to crown, noticing sensations without judgement. Reconnects mind and body — particularly powerful for those who dissociate under stress.',
          whenToUse: 'Before sleep, or when feeling disconnected from your body.',
          evidenceNote: 'Body scan is one of the most effective MBSR techniques for reducing rumination.',
          category: TechniqueCategory.mindfulness,
        ),
        WellnessTechnique(
          name: 'Mindful Walking',
          emoji: '🚶',
          duration: '10 min',
          description:
              'Walk slowly, feeling each step — heel to toe. Notice sights, sounds, air. Leave your phone in your pocket. Campus walks become meditation sessions.',
          whenToUse: 'Between classes, during lunch, or whenever you have a few minutes outside.',
          evidenceNote: 'Mindful walking reduces ruminative thinking and restores directed attention.',
          category: TechniqueCategory.mindfulness,
        ),
      ],
      weeklyPlan: [
        WeeklyFocus(
          week: 1,
          theme: 'Begin with Breath',
          focus: 'Awareness starts with the one thing always with you — your breath.',
          actions: [
            'Practice the STOP technique 3× daily',
            'One 5-minute sitting session per day',
            'Try physiological sigh when stress hits',
          ],
        ),
        WeeklyFocus(
          week: 2,
          theme: 'Expand Awareness',
          focus: 'Move beyond breath to body and senses.',
          actions: [
            'Add a body scan before sleep',
            'One mindful walk per day (no phone)',
            'Extend sitting sessions to 10 minutes',
          ],
        ),
        WeeklyFocus(
          week: 3,
          theme: 'Mindfulness in Daily Life',
          focus: 'Bring mindfulness into ordinary activities.',
          actions: [
            'Eat one meal per day without screens or reading',
            'Practice STOP at every transition (class to class)',
            'Extend to 15-minute daily sitting practice',
          ],
        ),
        WeeklyFocus(
          week: 4,
          theme: 'Sustain the Practice',
          focus: 'Build a personal practice that fits your life.',
          actions: [
            'Identify your 2 core techniques',
            'Create a daily mindfulness anchor (same time, same space)',
            'Reflect: what has changed in how you relate to stress?',
          ],
        ),
      ],
      mayaProtocol:
          'Use MBSR-informed language — never teach mindfulness, just demonstrate it. Respond mindfully (pause, reflect, present). Invite the user into present-moment awareness during conversations. Validate that a wandering mind is not failure — the noticing is the practice. Use sensory language to anchor.',
    ),

    // ── SELF-ESTEEM ───────────────────────────────────────────────────────────
    'selfesteem': GoalPlan(
      id: 'selfesteem',
      title: 'Building Self-Esteem',
      emoji: '💪',
      color: const Color(0xFFFF6B9D),
      clinicalApproach: 'Schema Therapy + Self-Compassion (Kristin Neff)',
      approachNote:
          'Schema Therapy addresses the deep core beliefs (schemas) that drive low self-esteem — often formed in childhood or difficult life experiences. Self-compassion work offers an evidence-based, sustainable alternative to fragile self-esteem.',
      techniques: [
        WellnessTechnique(
          name: 'Inner Critic Journaling',
          emoji: '📝',
          duration: '10 min',
          description:
              'Write what your inner critic says → Identify the schema behind it (failure, defectiveness, abandonment) → Write what a compassionate, wise friend would say in response. Over time, the compassionate voice gets louder.',
          whenToUse: 'When self-critical thoughts are loud. After perceived failures.',
          evidenceNote: 'Externalising the inner critic reduces its emotional impact and makes it disputable.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Self-Compassion Break',
          emoji: '🤗',
          duration: '3 min',
          description:
              '1. "This is suffering." 2. "Suffering is part of being human." 3. "May I be kind to myself." Repeat with your hand on your heart. Not self-pity — it\'s what you\'d offer a dear friend.',
          whenToUse: 'Any time you\'re being harsh with yourself.',
          evidenceNote:
              'Self-compassion is a stronger predictor of wellbeing than self-esteem (Neff, 2011).',
          category: TechniqueCategory.mindfulness,
        ),
        WellnessTechnique(
          name: 'Strength Journaling',
          emoji: '⭐',
          duration: '5 min',
          description:
              'Write 3 qualities you showed today that had nothing to do with performance — kindness, curiosity, patience, loyalty. Building an evidence base for unconditional self-worth.',
          whenToUse: 'Every evening. Consistency is what rewires self-perception.',
          evidenceNote: 'Daily strength reflection increases self-efficacy and reduces negative self-regard.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Schema Identification',
          emoji: '🔑',
          duration: '15 min',
          description:
              'Identify your core negative belief (e.g., "I\'m not good enough"). Ask: when did I first feel this? What evidence exists for AND against it? Who taught me to see myself this way?',
          whenToUse: 'When a recurring pattern of self-doubt appears. With Maya.',
          evidenceNote: 'Schema awareness is the first stage of schema modification.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Values-Based Identity',
          emoji: '🎯',
          duration: '10 min',
          description:
              'Self-esteem built on achievements is fragile — it rises and falls with results. Build it instead on your values: "I am someone who shows up, cares, and keeps trying." That can\'t be taken away.',
          whenToUse: 'When defining yourself through outcomes (grades, appearance, opinions).',
          evidenceNote: 'Values-based self-regard is more stable than achievement-based self-esteem.',
          category: TechniqueCategory.cognitive,
        ),
      ],
      weeklyPlan: [
        WeeklyFocus(
          week: 1,
          theme: 'Name the Critic',
          focus: 'You cannot change what you cannot name.',
          actions: [
            'Journal: what does your inner critic say most often?',
            'Identify the theme — is it "not good enough", "unlovable", other?',
            'Practice one self-compassion break daily',
          ],
        ),
        WeeklyFocus(
          week: 2,
          theme: 'Build the Evidence',
          focus: 'Gather real evidence of your worth that doesn\'t depend on achievement.',
          actions: [
            'Daily strength journaling — 3 non-performance qualities',
            'Write to your inner critic as if it\'s a separate voice',
            'Identify one area where your inner critic is clearly wrong',
          ],
        ),
        WeeklyFocus(
          week: 3,
          theme: 'Rebuild the Narrative',
          focus: 'Write a new, accurate story about who you are.',
          actions: [
            'Complete schema identification exercise with Maya',
            'Write the compassionate reframe for your core belief',
            'Begin values-based identity journaling',
          ],
        ),
        WeeklyFocus(
          week: 4,
          theme: 'Live From Worth',
          focus: 'Act from self-worth — not to earn it.',
          actions: [
            'Identify one area where you acted against your worth this month',
            'Set one boundary that honours your self-regard',
            'Reflect: how has your inner voice changed?',
          ],
        ),
      ],
      mayaProtocol:
          'Use self-compassion language consistently. Never validate harsh self-criticism — gently challenge it. Use schema language when patterns emerge: "it sounds like part of you believes...". Celebrate non-achievement qualities. Mirror back strengths the user doesn\'t see in themselves. Ask: "what would you say to a friend who said that about themselves?"',
    ),

    // ── GRIEF ────────────────────────────────────────────────────────────────
    'grief': GoalPlan(
      id: 'grief',
      title: 'Processing Grief',
      emoji: '🌹',
      color: const Color(0xFF9C4FF5),
      clinicalApproach: 'Worden\'s Tasks of Mourning + Meaning-Making (Neimeyer)',
      approachNote:
          'Grief is not a problem to be solved or stages to be "completed." It\'s a process of adapting to loss. Worden\'s Tasks and Neimeyer\'s meaning-reconstruction model honour the complexity of grief without trying to rush it.',
      techniques: [
        WellnessTechnique(
          name: 'Grief Journaling',
          emoji: '📖',
          duration: 'No limit',
          description:
              'Write freely about who or what you\'ve lost. No structure — just expression. Grief needs a container, and the journal is that container. Some days will pour out; others, a sentence is enough.',
          whenToUse: 'Whenever the weight feels heavy. Not to process — just to express.',
          evidenceNote:
              'Expressive writing for grief reduces physical and psychological symptoms.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Memory Honoring',
          emoji: '🕯️',
          duration: 'Ongoing',
          description:
              'Create a small ritual to honor what you\'ve lost — a photo, a playlist, a walk to a meaningful place, a letter you don\'t send. Continuing bonds theory shows maintaining connection is healthy, not avoidance.',
          whenToUse: 'When you feel the need to honour, not just process.',
          evidenceNote: 'Continuing bonds — healthy connection to the lost person or thing — supports adaptation.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Meaning Reconstruction',
          emoji: '🌱',
          duration: '15 min',
          description:
              'Ask: "What does this loss mean about life, about me, about what matters?" Grief often shatters our assumptive world. Meaning-making rebuilds it — not to make the loss okay, but to find what it teaches.',
          whenToUse: 'When the loss feels senseless or when "why" questions arise.',
          evidenceNote: 'Meaning-making mediates grief\'s impact on long-term wellbeing.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: '4-7-8 During Grief Waves',
          emoji: '🌬️',
          duration: '5 min',
          description:
              'When a grief wave hits — body heavy, tears rising — use 4-7-8 breathing. Not to stop the grief, but to ride it. Creates space between you and the wave so you are not consumed.',
          whenToUse: 'When acute grief waves arise unexpectedly.',
          evidenceNote: 'Physiological regulation prevents grief from becoming traumatic flooding.',
          category: TechniqueCategory.breathing,
        ),
        WellnessTechnique(
          name: 'Post-Traumatic Growth Reflection',
          emoji: '✨',
          duration: '10 min',
          description:
              'When ready (not forced), reflect: "What has this loss, unexpectedly, taught me or opened in me?" PTG is not denying pain — it\'s recognising that loss and growth can coexist.',
          whenToUse: 'Weeks or months in — not in the acute phase.',
          evidenceNote: 'Post-traumatic growth is a real, research-validated outcome of processed grief.',
          category: TechniqueCategory.cognitive,
        ),
      ],
      weeklyPlan: [
        WeeklyFocus(
          week: 1,
          theme: 'Create a Container',
          focus: 'Grief needs a space — give it one without letting it flood everything.',
          actions: [
            'Start a grief journal — write anything, even one sentence',
            'Allow yourself to feel without judgment for 10 minutes daily',
            'Tell Maya how you\'re doing — even a few words',
          ],
        ),
        WeeklyFocus(
          week: 2,
          theme: 'Hold What You\'ve Lost',
          focus: 'Connection to what was lost is healthy — not a sign you haven\'t moved on.',
          actions: [
            'Create one small memory-honoring ritual',
            'Write a letter to who or what you\'ve lost',
            'Use 4-7-8 when grief waves arrive',
          ],
        ),
        WeeklyFocus(
          week: 3,
          theme: 'Tend to Yourself',
          focus: 'Grief is exhausting. Self-care during grief is not selfish.',
          actions: [
            'Identify one person you can lean on this week',
            'Do one thing your pre-loss self would have enjoyed',
            'Practice self-compassion — this is objectively hard',
          ],
        ),
        WeeklyFocus(
          week: 4,
          theme: 'Begin Meaning-Making',
          focus: 'Not to justify the loss — to integrate it into your story.',
          actions: [
            'Journal: what has this loss changed about what matters to you?',
            'Reflect: what do you want to carry forward from what you\'ve lost?',
            'Notice any unexpected growth without forcing it',
          ],
        ),
      ],
      mayaProtocol:
          'Never rush grief. Never say "you need to move on" or "at least." Validate the full weight of loss. Use Worden\'s framework — grief is tasks (accept loss, process pain, adjust, find enduring connection) not stages. Offer space and reflection without problem-solving. Grief shared is grief halved.',
    ),

    // ── RELATIONSHIPS ─────────────────────────────────────────────────────────
    'relationships': GoalPlan(
      id: 'relationships',
      title: 'Healthier Relationships',
      emoji: '❤️',
      color: const Color(0xFFFF4757),
      clinicalApproach: 'EFT Principles + Attachment Theory + NVC',
      approachNote:
          'Emotionally Focused Therapy identifies the underlying attachment needs driving relationship patterns. Non-Violent Communication gives practical language for expressing those needs. Together they transform relationship dynamics.',
      techniques: [
        WellnessTechnique(
          name: 'Needs Identification',
          emoji: '🔑',
          duration: '10 min',
          description:
              'Behind every conflict or relationship pain is an unmet need — connection, respect, safety, autonomy. Identify the need under the surface emotion. This transforms arguments from blame to understanding.',
          whenToUse: 'After any relationship conflict or recurring frustration.',
          evidenceNote: 'EFT shows that most relationship conflict is disconnection anxiety in disguise.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Non-Violent Communication (NVC)',
          emoji: '🗣️',
          duration: '5 min',
          description:
              'Observe (no evaluation) → Feel (no blame) → Need (own it) → Request (specific, doable). "When [observation], I feel [feeling] because I need [need]. Would you be willing to [request]?"',
          whenToUse: 'Before any difficult conversation. Practice with Maya first.',
          evidenceNote:
              'NVC reduces defensiveness and increases cooperative problem-solving in relationships.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Attachment Style Awareness',
          emoji: '🔗',
          duration: '15 min',
          description:
              'Understand your attachment style (secure, anxious, avoidant, disorganised). Once you know your pattern, you can distinguish between your attachment system reacting and the actual situation.',
          whenToUse: 'As a one-time but profound reflection. Talk it through with Maya.',
          evidenceNote: 'Attachment awareness is the first step toward earned security.',
          category: TechniqueCategory.cognitive,
        ),
        WellnessTechnique(
          name: 'Boundary Setting Framework',
          emoji: '🛡️',
          duration: '10 min',
          description:
              'A boundary is not a wall — it\'s a statement of what you need to stay safe or present in a relationship. Identify one boundary → Express it clearly → Follow through. Boundaries protect relationships, not end them.',
          whenToUse: 'When you feel repeatedly depleted, disrespected, or resentful.',
          evidenceNote: 'Clear boundaries increase relationship quality and reduce resentment.',
          category: TechniqueCategory.behavioural,
        ),
        WellnessTechnique(
          name: 'Repair Attempts',
          emoji: '🩹',
          duration: '5 min',
          description:
              'After a conflict, repair matters more than who was right. A repair attempt: "I think we got disconnected — can we try again?" Gottman research: repair attempts predict relationship longevity more than conflict frequency.',
          whenToUse: 'After any argument or disconnect — regardless of who initiated.',
          evidenceNote: 'Successful repair attempts are the strongest predictor of relationship longevity.',
          category: TechniqueCategory.behavioural,
        ),
      ],
      weeklyPlan: [
        WeeklyFocus(
          week: 1,
          theme: 'Know Your Patterns',
          focus: 'Understanding your attachment style and recurring patterns.',
          actions: [
            'Explore your attachment style with Maya',
            'Journal: what relationship pattern keeps repeating?',
            'Identify one unmet need driving a current conflict',
          ],
        ),
        WeeklyFocus(
          week: 2,
          theme: 'Learn the Language',
          focus: 'NVC gives you a new way to express needs without triggering defenses.',
          actions: [
            'Learn the NVC formula — practice with Maya',
            'Identify one conversation you\'ve been avoiding',
            'Practice the conversation using NVC language',
          ],
        ),
        WeeklyFocus(
          week: 3,
          theme: 'Set One Boundary',
          focus: 'A healthy boundary is an act of self-respect and relationship protection.',
          actions: [
            'Identify one boundary you\'ve been hesitant to set',
            'Draft the boundary statement (clear, kind, specific)',
            'Set the boundary — journal how it went',
          ],
        ),
        WeeklyFocus(
          week: 4,
          theme: 'Build Repair Capacity',
          focus: 'Healthy relationships are not conflict-free — they repair well.',
          actions: [
            'Practice one repair attempt after a disconnect',
            'Reflect: what relationship feels most nourishing? Why?',
            'Plan one act of genuine connection this week',
          ],
        ),
      ],
      mayaProtocol:
          'Apply EFT lens — look for the attachment need under every relationship complaint. Use NVC language as a framework. Never take sides. Help the user see their own patterns without shame. Validate relationship difficulty — it is genuinely hard. Ask "what do you need from this relationship right now?" before any advice.',
    ),
  };

  // ── Stressor Plans ──────────────────────────────────────────────────────────

  static final Map<String, StressorPlan> _stressorPlans = {
    'exams': StressorPlan(
      id: 'exams',
      title: 'Exams & CAT Season',
      emoji: '📝',
      color: const Color(0xFFF59E0B),
      copingTools: [
        CopingTool(
          name: 'Pre-Exam Ritual',
          emoji: '🧘',
          description: '10 min before any exam: box breathing (4 cycles), read your self-compassion statement, remind yourself that you\'ve prepared what you\'ve prepared.',
          whenToUse: 'The morning of and 10 minutes before every exam.',
        ),
        CopingTool(
          name: 'Spaced Repetition',
          emoji: '📚',
          description: 'Review material at increasing intervals: 1 day → 3 days → 7 days → 14 days. This is how memory works — not cramming.',
          whenToUse: 'From week 1 of semester, not the week before CATs.',
        ),
        CopingTool(
          name: 'The "Good Enough" Reframe',
          emoji: '✅',
          description: 'Perfectionism during exams costs performance. Define what "good enough" looks like given your preparation — then aim for that, not perfection.',
          whenToUse: 'When exam anxiety is rooted in perfectionism.',
        ),
        CopingTool(
          name: 'Post-Exam Decompression',
          emoji: '🌿',
          description: 'After each exam: 30 minutes no study, no talking about it. Walk, eat, call someone you love. Processing before the next paper.',
          whenToUse: 'Immediately after every exam or CAT.',
        ),
      ],
      mayaProtocol:
          'Normalise CAT stress explicitly — this is one of the hardest university experiences in Kenya. Validate without catastrophising. Use Problem-Solving Therapy to break the study challenge into concrete, manageable steps. Celebrate preparation progress, not just results.',
    ),

    'finances': StressorPlan(
      id: 'finances',
      title: 'Financial Pressure',
      emoji: '💰',
      color: const Color(0xFF4CAF50),
      copingTools: [
        CopingTool(
          name: 'Worry vs Problem Separation',
          emoji: '🔍',
          description: 'Separate financial worries you can act on from those you cannot. Action items go on a to-do list. Unactionable worries go in your worry journal, not your mind.',
          whenToUse: 'When financial anxiety is spinning without direction.',
        ),
        CopingTool(
          name: 'Needs vs Wants Audit',
          emoji: '📊',
          description: 'List this week\'s expenses. Categorise honestly: need (food, transport, rent) vs want. Not to restrict — to gain clarity and reduce the anxiety that comes from not knowing.',
          whenToUse: 'Weekly, especially when money anxiety is high.',
        ),
        CopingTool(
          name: 'Financial Compassion',
          emoji: '🤗',
          description: 'HELB delays and financial precarity are systemic, not personal failures. Apply self-compassion: "This is genuinely hard. Many students face this. I\'m doing my best."',
          whenToUse: 'When financial stress is becoming shame.',
        ),
        CopingTool(
          name: 'Resource Mapping',
          emoji: '🗺️',
          description: 'Map every support resource available to you: campus emergency fund, student services, HELB bursary, family network, side hustle potential. Knowing your resources reduces helplessness.',
          whenToUse: 'When financial situation feels completely without options.',
        ),
      ],
      mayaProtocol:
          'Acknowledge HELB specifically — it is a uniquely Kenyan university financial stressor. Validate the real material difficulty without false reassurance. Help separate actionable financial problems from anxiety spirals. Apply financial self-compassion — this is often shame-adjacent.',
    ),

    'loneliness': StressorPlan(
      id: 'loneliness',
      title: 'Loneliness',
      emoji: '🌧️',
      color: const Color(0xFF5C6BC0),
      copingTools: [
        CopingTool(
          name: 'Connection Micro-Steps',
          emoji: '👋',
          description: 'One message, one smile, one hello per day. Loneliness is often maintained by raising the bar for connection so high that nothing counts. Lower the bar to near zero.',
          whenToUse: 'Daily — pick one micro-connection in advance each morning.',
        ),
        CopingTool(
          name: 'Activity-Based Connection',
          emoji: '🎨',
          description: 'Join one campus activity — club, sport, volunteering, study group. Shared activities create natural connection without the pressure of "making friends".',
          whenToUse: 'This week — choose one thing and commit to just showing up.',
        ),
        CopingTool(
          name: 'Solitude vs Loneliness',
          emoji: '🌿',
          description: 'Loneliness is painful disconnection. Solitude is chosen aloneness. Learn to distinguish and even enjoy solitude — it becomes loneliness only when we resist it.',
          whenToUse: 'When alone time feels uncomfortable — explore what it means.',
        ),
        CopingTool(
          name: 'Talk to Maya',
          emoji: '💙',
          description: 'When human connection isn\'t available, Maya is. Not a replacement for human connection — but a bridge that holds you until human connection is possible.',
          whenToUse: 'Any time. Especially late at night or during long weekends.',
        ),
      ],
      mayaProtocol:
          'Treat loneliness as a real physiological pain signal — the brain processes social rejection similarly to physical pain. Validate without offering quick fixes. Gently challenge isolation behaviours. Offer connection via conversation. Ask what kind of connection would feel most meaningful.',
    ),

    'family': StressorPlan(
      id: 'family',
      title: 'Family Stress',
      emoji: '🏠',
      color: const Color(0xFF8BC34A),
      copingTools: [
        CopingTool(
          name: 'Detachment with Love',
          emoji: '🌊',
          description: 'You can love your family AND detach from their chaos, expectations, or pressure. Detachment is not abandonment — it\'s staying close while not being swept away.',
          whenToUse: 'When family dynamics are consuming your mental energy.',
        ),
        CopingTool(
          name: 'Influence vs Control',
          emoji: '🎛️',
          description: 'Map what you can influence in your family situation and what you cannot control. Focus only on the influenceable. Attempting to control the uncontrollable creates exhaustion.',
          whenToUse: 'When feeling responsible for fixing family problems.',
        ),
        CopingTool(
          name: 'Limit Communication Windows',
          emoji: '⏱️',
          description: 'If family calls are draining, set a window: "I\'m available 7–8pm on weekdays." This protects your study time and mental space without cutting off family.',
          whenToUse: 'When family contact is unpredictable and disruptive.',
        ),
        CopingTool(
          name: 'Separate Identity Work',
          emoji: '🔮',
          description: 'Your family\'s story does not have to be your story. Write: "Who am I, separate from my family role?" University is a chance to construct your own identity.',
          whenToUse: 'When family expectations feel identity-consuming.',
        ),
      ],
      mayaProtocol:
          'Family stress in Kenyan universities often involves financial obligation, cultural expectations, and family conflict at a distance. Validate the complexity — loving family and finding them difficult are not contradictions. Never advise cutting off family — help establish healthy boundaries and distance when needed.',
    ),

    'relationships_stress': StressorPlan(
      id: 'relationships_stress',
      title: 'Relationship Stress',
      emoji: '💔',
      color: const Color(0xFFFF4757),
      copingTools: [
        CopingTool(
          name: 'Clarify Before Communicating',
          emoji: '🔍',
          description: 'Before the conversation: write what you want to say, what you actually need, and what outcome you\'re hoping for. Clarity before conversation prevents reactive exchanges.',
          whenToUse: 'Before any difficult relationship conversation.',
        ),
        CopingTool(
          name: 'Regulate First',
          emoji: '🌬️',
          description: 'Box breathing (4-4-4-4) before difficult conversations. You cannot access your rational brain when your nervous system is flooded. Regulate, then relate.',
          whenToUse: 'Immediately before or during a heated conversation.',
        ),
        CopingTool(
          name: '24-Hour Rule',
          emoji: '⏰',
          description: 'For non-urgent relationship issues, wait 24 hours before responding. Many messages that feel urgent in the moment look different after sleep and distance.',
          whenToUse: 'When something provokes a strong reactive feeling.',
        ),
        CopingTool(
          name: 'Your Part, Their Part',
          emoji: '⚖️',
          description: 'In any conflict, separate what is yours to own from what is theirs. Not to diminish their impact, but to understand your own role and focus where you have actual power.',
          whenToUse: 'When relationship conflicts keep repeating.',
        ),
      ],
      mayaProtocol:
          'Never take sides in relationship conflicts. Help the user see their own patterns without shame. Use NVC language for expressing needs. Validate hurt without reinforcing victim narratives. If there are signs of unhealthy or unsafe relationships, gently name it and offer appropriate resources.',
    ),

    'career': StressorPlan(
      id: 'career',
      title: 'Career & Future Anxiety',
      emoji: '🎯',
      color: const Color(0xFF00BEB4),
      copingTools: [
        CopingTool(
          name: 'Values-Based Career Compass',
          emoji: '🧭',
          description: 'Most career anxiety comes from chasing the "right" path by others\' standards. Write: what do I want my daily life to feel like? What values must my work express? Start there.',
          whenToUse: 'When career decisions feel overwhelming or externally driven.',
        ),
        CopingTool(
          name: 'Skills Inventory',
          emoji: '📊',
          description: 'List every skill you\'ve built — academic, practical, interpersonal, from part-time jobs, campus involvement, life experience. This counter-acts the scarcity narrative.',
          whenToUse: 'When feeling like you have nothing to offer or are behind.',
        ),
        CopingTool(
          name: 'One-Step Focus',
          emoji: '👣',
          description: 'Career is not a destination — it\'s a series of next steps. Ask only: what is the ONE most useful thing I can do this week for my career? Then do only that.',
          whenToUse: 'When career overwhelm leads to paralysis.',
        ),
        CopingTool(
          name: 'Social Comparison Audit',
          emoji: '🔍',
          description: 'Note who you compare yourself to and why. Comparison is almost always upward and selective. Ask: am I comparing my beginning to someone else\'s middle?',
          whenToUse: 'When social media or peer comparisons are driving career anxiety.',
        ),
      ],
      mayaProtocol:
          'Career and attachment (internship) anxiety is acutely felt by Kenyan students. Validate the real uncertainty of the job market. Help identify intrinsic values over external markers of success. Break career planning into manageable immediate actions. Normalise a non-linear path.',
    ),

    'identity': StressorPlan(
      id: 'identity',
      title: 'Identity & Purpose',
      emoji: '🔍',
      color: const Color(0xFF9C4FF5),
      copingTools: [
        CopingTool(
          name: 'Values Archaeology',
          emoji: '🏺',
          description: 'Dig beneath social roles to find your own values. Ask: what would I do if no one was watching? What makes me angry? (anger reveals values). What do I admire in others?',
          whenToUse: 'When "who am I really?" questions are most active.',
        ),
        CopingTool(
          name: 'Identity Journaling',
          emoji: '📝',
          description: 'Write about: who am I outside of my student role? Outside of my family role? What constants exist across all contexts? The intersection of those is your core identity.',
          whenToUse: 'Weekly. Identity work is slow and iterative — be patient with it.',
        ),
        CopingTool(
          name: 'Narrative Therapy Exercise',
          emoji: '📖',
          description: 'Write your life story in the third person as if it were a novel. Then rewrite it — same facts, different interpretation. What does the protagonist actually want? What are their strengths?',
          whenToUse: 'When you feel like your story is one-dimensional or "stuck".',
        ),
        CopingTool(
          name: 'Tolerance of Not-Knowing',
          emoji: '🌙',
          description: 'Not knowing who you are at 20 is not a crisis — it is the developmentally appropriate task. Practice tolerating uncertainty: "I don\'t know yet, and that\'s okay."',
          whenToUse: 'When identity uncertainty is causing acute distress.',
        ),
      ],
      mayaProtocol:
          'Identity questions are developmentally appropriate at university age. Normalise without minimising the distress. Use ACT values work and narrative therapy language. Help the user separate their genuine values from inherited or imposed ones. Support individuation without encouraging reckless rebellion.',
    ),

    'health': StressorPlan(
      id: 'health',
      title: 'Physical Health Stress',
      emoji: '🏥',
      color: const Color(0xFF4CAF50),
      copingTools: [
        CopingTool(
          name: 'Mind-Body Check-In',
          emoji: '🔍',
          description: 'Daily: scan your body for 2 minutes. Where is tension? Where is ease? Physical symptoms often carry emotional information — learning the language of your body is self-care.',
          whenToUse: 'Daily, especially when physical and mental health are both struggling.',
        ),
        CopingTool(
          name: 'Pacing, Not Pushing',
          emoji: '⚡',
          description: 'When dealing with health challenges, your nervous system needs regulation, not demands. Map your energy envelope and work within it — rest is not laziness, it\'s treatment.',
          whenToUse: 'When health issues make normal functioning hard.',
        ),
        CopingTool(
          name: 'Health Anxiety Grounding',
          emoji: '🌍',
          description: 'If health anxiety is leading to catastrophic thinking about symptoms: 5-4-3-2-1 grounding. Then ask: what do I actually know, vs what am I predicting?',
          whenToUse: 'When health worries are spiralling.',
        ),
      ],
      mayaProtocol:
          'Validate the real difficulty of managing health while maintaining academic performance. Distinguish health anxiety from legitimate concern — both deserve compassionate attention. Encourage professional medical care where appropriate. Support without catastrophising or minimising.',
    ),

    'performance': StressorPlan(
      id: 'performance',
      title: 'Performance Anxiety',
      emoji: '😰',
      color: const Color(0xFFFF8C42),
      copingTools: [
        CopingTool(
          name: 'Pre-Performance Protocol',
          emoji: '🎯',
          description: '1. Box breathing (4 cycles). 2. Power posture for 2 minutes. 3. Read your preparation evidence ("I have practiced X, studied Y"). 4. Process focus: "I will focus on X, not outcomes."',
          whenToUse: '10 minutes before any performance situation.',
        ),
        CopingTool(
          name: 'Process vs Outcome Focus',
          emoji: '🔄',
          description: 'Performance anxiety focuses on outcomes (will I pass?). Process focus asks: what is the next right action? Outcome is not in your control in the moment — process is.',
          whenToUse: 'During performance anxiety — redirect attention to process.',
        ),
        CopingTool(
          name: 'Evidence Review',
          emoji: '📊',
          description: 'List the specific preparation you\'ve done. Performance anxiety tells you you\'re unprepared even when you\'re not. Evidence corrects the lie.',
          whenToUse: 'In the hours before a performance event.',
        ),
        CopingTool(
          name: 'Stakes Reality Check',
          emoji: '⚖️',
          description: 'Ask: what is the actual worst realistic outcome? And could I survive it? Performance anxiety inflates stakes. Realistic assessment deflates them.',
          whenToUse: 'When anxiety about performance is disproportionate to actual stakes.',
        ),
      ],
      mayaProtocol:
          'Performance anxiety is both cognitive (catastrophic thoughts) and physiological (arousal). Address both. Use box breathing and cognitive restructuring. Help distinguish performance anxiety from avoidance. Normalise some arousal — it improves performance. The goal is optimal activation, not zero anxiety.',
    ),

    'time': StressorPlan(
      id: 'time',
      title: 'Time Management',
      emoji: '⏰',
      color: const Color(0xFF00BEB4),
      copingTools: [
        CopingTool(
          name: 'Weekly Time Blocking',
          emoji: '📅',
          description: 'Every Sunday: block study time, rest time, and social time. Treat these blocks like appointments. Reactive time management creates constant low-grade stress.',
          whenToUse: 'Sunday evenings. Non-negotiable weekly ritual.',
        ),
        CopingTool(
          name: 'No-List',
          emoji: '🚫',
          description: 'Time pressure comes from too many yeses. Create your "No List" — commitments you\'re currently saying yes to but shouldn\'t be. Practice the polite but firm no.',
          whenToUse: 'When reviewing how your time actually gets spent.',
        ),
        CopingTool(
          name: 'Energy Management over Time Management',
          emoji: '⚡',
          description: 'Match high-energy work (studying complex topics) to peak energy windows. Match low-energy work (admin, replying messages) to low-energy windows. Same hours — dramatically different output.',
          whenToUse: 'When you have time to study but can\'t focus.',
        ),
        CopingTool(
          name: 'Physiological Sigh for Time Pressure',
          emoji: '😮‍💨',
          description: 'When the overwhelm of too much to do hits physically — double-inhale through nose, long exhale through mouth. 15 seconds. Then prioritise the next ONE thing.',
          whenToUse: 'When time pressure becomes acute and you freeze.',
        ),
      ],
      mayaProtocol:
          'Time stress is often about cognitive overload and competing demands, not genuine scarcity of time. Help the user map reality vs perception. Use Problem-Solving Therapy to break down time challenges. Validate the real difficulty of managing academic + family + financial demands simultaneously as a student.',
    ),
  };
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class GoalPlan {
  final String id;
  final String title;
  final String emoji;
  final Color color;
  final String clinicalApproach;
  final String approachNote;
  final List<WellnessTechnique> techniques;
  final List<WeeklyFocus> weeklyPlan;
  final String mayaProtocol;

  const GoalPlan({
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
    required this.clinicalApproach,
    required this.approachNote,
    required this.techniques,
    required this.weeklyPlan,
    required this.mayaProtocol,
  });
}

class StressorPlan {
  final String id;
  final String title;
  final String emoji;
  final Color color;
  final List<CopingTool> copingTools;
  final String mayaProtocol;

  const StressorPlan({
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
    required this.copingTools,
    required this.mayaProtocol,
  });
}

class WellnessTechnique {
  final String name;
  final String emoji;
  final String duration;
  final String description;
  final String whenToUse;
  final String evidenceNote;
  final TechniqueCategory category;

  const WellnessTechnique({
    required this.name,
    required this.emoji,
    required this.duration,
    required this.description,
    required this.whenToUse,
    required this.evidenceNote,
    required this.category,
  });
}

class WeeklyFocus {
  final int week;
  final String theme;
  final String focus;
  final List<String> actions;

  const WeeklyFocus({
    required this.week,
    required this.theme,
    required this.focus,
    required this.actions,
  });
}

class CopingTool {
  final String name;
  final String emoji;
  final String description;
  final String whenToUse;

  const CopingTool({
    required this.name,
    required this.emoji,
    required this.description,
    required this.whenToUse,
  });
}

enum TechniqueCategory {
  breathing,
  mindfulness,
  cognitive,
  behavioural,
  body;

  String get label => switch (this) {
        TechniqueCategory.breathing => 'Breathing',
        TechniqueCategory.mindfulness => 'Mindfulness',
        TechniqueCategory.cognitive => 'Cognitive',
        TechniqueCategory.behavioural => 'Behavioural',
        TechniqueCategory.body => 'Body',
      };

  Color get color => switch (this) {
        TechniqueCategory.breathing => const Color(0xFF00BEB4),
        TechniqueCategory.mindfulness => const Color(0xFF06D6A0),
        TechniqueCategory.cognitive => const Color(0xFF6C63FF),
        TechniqueCategory.behavioural => const Color(0xFFFF8C42),
        TechniqueCategory.body => const Color(0xFFFF6B9D),
      };
}
