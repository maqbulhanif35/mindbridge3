import '../models/user_model.dart';
import '../providers/mood_provider.dart';
import '../router/app_router.dart';

// ─────────────────────────────────────────────────────────
// GoalPlanEngine
// Central intelligence layer that translates every user's
// onboarding selections into concrete, contextual help
// across every screen of the app.
// ─────────────────────────────────────────────────────────

class GoalPlanEngine {
  GoalPlanEngine._();

  // ═══════════════════════════════════════════════════════
  // JOURNAL PROMPTS ─ per goal and per stressor
  // ═══════════════════════════════════════════════════════

  static const Map<String, List<(String, String)>> _goalPrompts = {
    'anxiety': [
      ('What is worrying me most right now, and is it within my control?',
          'Separate what you can act on from what you cannot. Control is a powerful antidote to anxiety.'),
      ('Describe the last time I felt calm. What was different?',
          'Identifying your calm conditions helps you recreate them intentionally.'),
      ('What is the worst realistic outcome I am afraid of — and could I survive it?',
          'Naming the fear at full size often shrinks it. You have survived hard things before.'),
      ('Write a letter to my anxious self from three months in the future.',
          'Your future self already got through this. What would they tell you today?'),
      ('What are 3 things I know to be true right now, in this moment?',
          'Grounding in facts anchors an anxious mind back to the present.'),
    ],
    'depression': [
      ('What was one moment today that felt even slightly less heavy?',
          'Even a flicker of lightness counts. Train your mind to notice it.'),
      ('What would "taking care of myself today" look like — even in a tiny way?',
          'Self-care during depression is not luxury. It is medicine.'),
      ('Write about a person who believes in you. What would they say right now?',
          'Sometimes we need to borrow someone else\'s belief in us.'),
      ('What am I carrying that I have not let myself grieve?',
          'Unexpressed grief often sits at the root of low mood. Naming it is healing.'),
      ('If my mood were a weather pattern, what would it be today — and what caused it?',
          'Externalising mood as weather makes it feel less personal and more temporary.'),
    ],
    'stress': [
      ('What are all the things on my mind right now? Write them all out.',
          'A brain dump clears mental RAM. Once it\'s on paper, you can prioritise.'),
      ('What is the most important task this week — and what would happen if I skipped everything else?',
          'Stress often comes from treating everything as equally urgent. It rarely is.'),
      ('When was the last time I truly rested — not scrolled, not studied, but rested?',
          'Rest is not wasted time. It is how your brain consolidates and resets.'),
      ('What would I tell a fellow student dealing with exactly my workload right now?',
          'We are usually kinder to others than to ourselves. Apply that kindness inward.'),
      ('Where is my stress coming from — the task itself, or what I fear it means about me?',
          'Much stress is tied to identity. Separating performance from self-worth is liberating.'),
    ],
    'sleep': [
      ('What thoughts keep visiting me when I try to sleep? Write them out now.',
          'Getting racing thoughts out of your head and onto paper can silence them at night.'),
      ('What does my bedtime routine look like — and what am I doing right up until sleep?',
          'The last 30 minutes before bed shape sleep quality more than almost anything else.'),
      ('What worries am I carrying into bed with me? Can any wait until tomorrow?',
          'Many concerns are best left for tomorrow. Write them here so your brain lets go.'),
      ('How did I feel on days when I slept well? What was different the day before?',
          'Your best sleep nights hold clues. Pattern recognition is powerful.'),
      ('What would my ideal morning feel like if I slept properly tonight?',
          'Visualising a great morning can motivate healthier evening choices.'),
    ],
    'social': [
      ('Describe a moment when I felt genuinely connected to someone. What made it feel safe?',
          'Understanding what safety feels like helps you seek it and create it again.'),
      ('What am I afraid will happen if I put myself out there socially?',
          'Name the fear specifically. Most social fears are survivable.'),
      ('Who in my life makes me feel seen without me having to perform?',
          'Identify your anchor relationships. These are worth nurturing deeply.'),
      ('What would I say to a new person if I had zero fear of rejection?',
          'The version of you without fear usually knows what the real you wants to say.'),
      ('How has loneliness shaped who I am — and what has it taught me?',
          'Loneliness, while painful, often deepens our capacity for empathy and self-knowledge.'),
    ],
    'motivation': [
      ('What would I be working toward if I knew I could not fail?',
          'Fear of failure is often the only thing standing between you and your real goals.'),
      ('What did I do last week that I am quietly proud of?',
          'Motivation grows from recognising progress. Look for it — even the small kind.'),
      ('What drains my motivation most, and what is one thing I can remove or reduce?',
          'Protecting your energy is as important as generating it.'),
      ('What is my "why" behind the thing I am trying to stay motivated for?',
          'Surface-level motivation fades. Connecting to a deeper purpose sustains action.'),
      ('Write about a version of myself 1 year from now who stayed consistent. What does their life look like?',
          'Your future self is built by the choices your present self makes today.'),
    ],
    'mindfulness': [
      ('Describe the last 5 minutes in sensory detail — what did I see, hear, feel?',
          'Sensory recounting trains the brain to dwell in the present, not in past or future.'),
      ('What thoughts came and went in the last hour that I barely noticed?',
          'Mindfulness begins with noticing. You cannot change what you cannot observe.'),
      ('When today did I feel most "in the flow" — completely absorbed?',
          'Flow states are naturally mindful. Understanding what triggers yours is valuable.'),
      ('What am I resisting right now — and what would happen if I simply allowed it?',
          'Mindfulness teaches acceptance before action. Resistance consumes energy.'),
      ('Write a gratitude for something so ordinary I usually overlook it.',
          'Attention to the small things is a mindfulness muscle. It gets stronger with practice.'),
    ],
    'selfesteem': [
      ('Write 5 things I genuinely like about myself that have nothing to do with achievement.',
          'Self-worth built on performance is fragile. Build it on who you are, not what you do.'),
      ('What would I never say to a friend — but say to myself regularly?',
          'Naming your inner critic\'s script is the first step to rewriting it.'),
      ('When did I last stand up for myself? How did it feel?',
          'Self-advocacy is a form of self-respect. Reflect on how it felt — even if it was hard.'),
      ('What am I more capable of than I give myself credit for?',
          'We routinely underestimate ourselves. This prompt lets you correct the record.'),
      ('Who taught me to see myself the way I currently do — and was that accurate?',
          'Our self-image is often inherited. Examine its origins critically.'),
    ],
    'grief': [
      ('Write freely about who or what I am grieving. No structure — just let it out.',
          'Grief does not need to be eloquent or organised. It just needs to be expressed.'),
      ('What do I miss most, and what does that missing tell me about what I value?',
          'Grief reveals our deepest values. What we mourn most shows what matters most.'),
      ('What would I want to say to who or what I have lost, if I could?',
          'Unsaid words carry weight. Writing them here — even to no one — can release that weight.'),
      ('Describe a memory that still brings both joy and sadness at the same time.',
          'Grief and love coexist. Honoring both is not contradiction — it is wholeness.'),
      ('What parts of myself am I also grieving — old versions of who I used to be?',
          'Sometimes the hardest grief is for who we thought we would become.'),
    ],
    'relationships': [
      ('Which relationship in my life feels most draining right now, and why?',
          'Naming what drains you is the first step to addressing or releasing it.'),
      ('What do I need most from my relationships that I have not asked for yet?',
          'Unvoiced needs create silent resentment. Naming them here prepares you to voice them.'),
      ('How do I typically respond when someone disappoints me? Is that serving me?',
          'Our relationship patterns are often automatic. Examining them creates choice.'),
      ('Describe a relationship dynamic I keep repeating. What is my part in it?',
          'Patterns persist until we see our own role. This is empowering, not blaming.'),
      ('What does a healthy relationship feel like in my body — and how can I recognise it?',
          'Our nervous system knows the difference between safe and unsafe. Learn its signals.'),
    ],
  };

  static const Map<String, List<(String, String)>> _stressorPrompts = {
    'exams': [
      ('Write out everything I need to do before my next exam — then circle the top 3.',
          'Externalising overwhelm and prioritising brings immediate relief.'),
      ('What does "doing my best" actually look like given my current circumstances?',
          'Redefining success contextually removes the tyranny of perfectionism.'),
      ('When I imagine the exam being over, how do I want to feel about how I prepared?',
          'Working backward from your ideal outcome clarifies today\'s priorities.'),
    ],
    'finances': [
      ('Write about my relationship with money — where did those feelings come from?',
          'Financial anxiety is often emotional before it is practical. Understand its root.'),
      ('What is one practical thing I can do this week to ease financial pressure?',
          'Small, concrete actions counter the paralysis that financial stress causes.'),
      ('What would financial security look like for me — and what is one step toward it?',
          'Defining your destination makes the path visible. Even one step forward is progress.'),
    ],
    'loneliness': [
      ('Describe what connection means to me — what does it look, feel, sound like?',
          'Knowing your own definition of connection helps you seek the right kind.'),
      ('Who is one person I could reach out to this week — and what has stopped me?',
          'Loneliness often has a quiet solution we avoid because vulnerability feels risky.'),
      ('What do I bring to friendships that others benefit from?',
          'Loneliness can distort our sense of our own value. This prompt corrects that.'),
    ],
    'family': [
      ('Write about a family dynamic that has shaped how I see myself.',
          'Our families are our first context. Understanding their influence is self-understanding.'),
      ('What boundary do I wish I had in my family relationships — and why has it been hard to set?',
          'Naming an unset boundary is the first step toward setting it.'),
      ('What do I love about my family — separate from what frustrates me?',
          'Holding complexity about family is healthy. Grief and love can coexist.'),
    ],
    'relationships_stress': [
      ('Write exactly what I wish the other person understood about how I feel.',
          'Clarity about your own position often precedes better communication.'),
      ('What is my part in this conflict — not to blame myself, but to understand it?',
          'Taking responsibility for our part (not others\') is an act of power, not weakness.'),
      ('What would this relationship look like if I stopped trying to control the outcome?',
          'We expend enormous energy trying to control what is not ours to control.'),
    ],
    'career': [
      ('What does success mean to me — not to my family or peers, but to me?',
          'Borrowed definitions of success lead to empty wins. Find your own.'),
      ('What is one skill I am building right now that my future career will thank me for?',
          'Career anxiety shrinks when you focus on growth over destination.'),
      ('What am I most afraid people will think if I choose the path I actually want?',
          'Career decisions are often derailed by social fear. Naming it loosens its grip.'),
    ],
    'identity': [
      ('Who am I outside of my roles — student, child, friend? What remains?',
          'Identity beyond roles is the most stable identity. Find the constant underneath.'),
      ('What parts of myself am I hiding, and from whom — and why?',
          'Concealment is exhausting. This prompt explores what you might let be seen.'),
      ('Write about a belief I have about myself that I am not sure is actually true.',
          'Many of our self-beliefs are inherited or constructed. Not all are accurate.'),
    ],
    'health': [
      ('How is my physical health affecting my mental state right now?',
          'The body and mind are not separate. Acknowledging the link is useful.'),
      ('What is one thing I can do today that my body would thank me for?',
          'Small acts of physical care compound into meaningful wellbeing.'),
      ('Write about the relationship between my energy levels and my emotions this week.',
          'Tracking energy alongside mood reveals patterns that explain a lot.'),
    ],
    'performance': [
      ('What does failure actually mean to me — what am I really afraid of?',
          'Performance anxiety is almost always about meaning, not the task itself.'),
      ('Write about a time I performed well when I did not expect to. What was different?',
          'Evidence of past competence is a direct antidote to performance anxiety.'),
      ('What would I do if no one was watching or judging the outcome?',
          'Removing the audience reveals what we actually enjoy and value.'),
    ],
    'time': [
      ('Map out my ideal week — when do I work, rest, connect, and do nothing?',
          'Designing your week intentionally prevents reactive, exhausting time use.'),
      ('What am I saying yes to that I actually want to say no to?',
          'Time pressure often comes from over-commitment. This prompt helps you see it.'),
      ('What one habit, if I protected time for it daily, would make everything else easier?',
          'Keystone habits create cascades of positive change. Identify yours.'),
    ],
  };

  /// Universal fallback prompts (used when no goal match found)
  static const _universalPrompts = [
    ('What am I most proud of this week?', 'Reflect on achievements, big or small.'),
    ('Where do I feel most stuck right now?', 'Identify the obstacle clearly to begin moving past it.'),
    ('What would I tell a friend in my exact situation?', 'Often the advice we give others is what we need most.'),
    ('What drains my energy vs. what restores it?', 'Map out your energy patterns to make better choices.'),
    ('What am I avoiding thinking about?', 'Avoidance is often a signal worth exploring.'),
    ('What does my ideal day look like?', 'Clarity on your vision helps you move toward it.'),
    ('How am I different from who I was 6 months ago?', 'Growth is often invisible until you look back.'),
  ];

  /// Returns a ranked list of journal prompts for the user.
  /// Goal-specific prompts appear first, then stressor-specific, then universal.
  static List<(String, String)> getJournalPrompts(
    UserModel? user, {
    int max = 8,
  }) {
    final prompts = <(String, String)>[];
    final seen = <String>{};

    void add((String, String) p) {
      if (!seen.contains(p.$1)) {
        prompts.add(p);
        seen.add(p.$1);
      }
    }

    // 1. Top 2 prompts from primary goal
    if (user != null && user.goals.isNotEmpty) {
      final goalList = _goalPrompts[user.goals.first] ?? [];
      for (final p in goalList.take(2)) add(p);
    }

    // 2. Top 1 prompt from primary stressor
    if (user != null && user.stressors.isNotEmpty) {
      final stressorList = _stressorPrompts[user.stressors.first] ?? [];
      for (final p in stressorList.take(1)) add(p);
    }

    // 3. One prompt from each remaining goal (up to 3 goals)
    if (user != null) {
      for (final g in user.goals.skip(1).take(3)) {
        final list = _goalPrompts[g] ?? [];
        if (list.isNotEmpty) add(list.first);
      }
    }

    // 4. One prompt from each remaining stressor
    if (user != null) {
      for (final s in user.stressors.skip(1).take(2)) {
        final list = _stressorPrompts[s] ?? [];
        if (list.isNotEmpty) add(list.first);
      }
    }

    // 5. Fill remainder with universal prompts
    for (final p in _universalPrompts) {
      if (prompts.length >= max) break;
      add(p);
    }

    return prompts.take(max).toList();
  }

  // ═══════════════════════════════════════════════════════
  // MINDFULNESS RECOMMENDATIONS ─ per goal + stressor
  // ═══════════════════════════════════════════════════════

  static const Map<String, ({String exercise, String reason})> _goalMindfulness = {
    'anxiety': (exercise: '4-7-8 Breathing', reason: 'Proven to activate the parasympathetic system — your anti-anxiety circuit'),
    'stress': (exercise: 'Box Breathing', reason: 'Used by Navy SEALs to regulate stress response in high-pressure moments'),
    'sleep': (exercise: '4-7-8 Breathing', reason: 'The 4-7-8 technique slows the nervous system — ideal pre-sleep'),
    'depression': (exercise: 'Body Scan', reason: 'Reconnects mind and body — reduces the disconnection depression creates'),
    'mindfulness': (exercise: 'Physiological Sigh', reason: 'The fastest reset — one double-inhale drops stress faster than any other technique'),
    'selfesteem': (exercise: 'Body Scan', reason: 'Reconnecting with your physical self builds a kinder relationship with your body'),
    'grief': (exercise: '4-7-8 Breathing', reason: 'Creates space between waves of emotion — breathing room for heavy feelings'),
    'social': (exercise: 'Box Breathing', reason: 'Perfect before social situations — regulates the stress response quickly'),
    'motivation': (exercise: 'Physiological Sigh', reason: 'A quick physiological reset to break inertia and restore energy'),
    'relationships': (exercise: 'Box Breathing', reason: 'Regulates your nervous system before or during difficult conversations'),
  };

  static const Map<String, ({String exercise, String reason})> _stressorMindfulness = {
    'exams': (exercise: 'Box Breathing', reason: 'Proven to reduce cortisol before high-stakes performance situations'),
    'performance': (exercise: '4-7-8 Breathing', reason: 'Reduces performance anxiety by activating your calm system rapidly'),
    'loneliness': (exercise: 'Body Scan', reason: 'Compassionate body attention counters the disconnection of loneliness'),
    'family': (exercise: 'Physiological Sigh', reason: 'One double-breath resets reactivity before or after difficult family interactions'),
    'finances': (exercise: 'Box Breathing', reason: 'Financial anxiety is physical — breathwork grounds you when worries spiral'),
    'time': (exercise: 'Physiological Sigh', reason: 'The fastest possible reset — 5 seconds to reduce stress when time is short'),
  };

  /// Returns the best mindfulness recommendation for the user's goals/stressors.
  /// Falls back to time-of-day logic if no match found.
  static ({String exercise, String reason}) getMindfulnessRecommendation(
    UserModel? user,
    int? moodScore,
  ) {
    // Low mood always overrides
    if (moodScore != null && moodScore <= 3) {
      return (
        exercise: '4-7-8 Breathing',
        reason: 'Based on your low mood today — this technique activates your calm circuit quickly',
      );
    }

    // Check goals first
    if (user != null) {
      for (final g in user.goals) {
        final rec = _goalMindfulness[g];
        if (rec != null) return rec;
      }
      // Then stressors
      for (final s in user.stressors) {
        final rec = _stressorMindfulness[s];
        if (rec != null) return rec;
      }
    }

    // Time-of-day fallback
    final h = DateTime.now().hour;
    if (moodScore != null && moodScore <= 5) {
      return (exercise: 'Box Breathing', reason: 'For moderate stress relief');
    }
    if (h < 9) return (exercise: 'Box Breathing', reason: 'Perfect morning focus starter');
    if (h < 13) return (exercise: '4-7-8 Breathing', reason: 'Mid-morning nervous system reset');
    if (h < 18) return (exercise: 'Physiological Sigh', reason: 'Afternoon stress relief');
    return (exercise: '4-7-8 Breathing', reason: 'Wind-down for the evening');
  }

  // ═══════════════════════════════════════════════════════
  // WELLNESS CHALLENGES ─ per goal/stressor priority order
  // ═══════════════════════════════════════════════════════

  // Challenge indices (matching wellness_screen.dart _challenges):
  // 0: Breathe, 1: Journal, 2: Gratitude, 3: Move, 4: Connect (Maya), 5: Wind Down

  static const Map<String, List<int>> _goalChallengeOrder = {
    'anxiety':    [0, 1, 2, 4, 3, 5], // breathe first
    'depression': [1, 2, 4, 3, 0, 5], // journal + gratitude first
    'stress':     [0, 1, 2, 3, 4, 5], // breathe + journal first
    'sleep':      [5, 0, 2, 1, 4, 3], // wind down first
    'social':     [4, 2, 1, 0, 3, 5], // connect (maya) first
    'motivation': [3, 2, 1, 4, 0, 5], // move + gratitude first
    'mindfulness':[0, 3, 2, 1, 4, 5], // breathe + move first
    'selfesteem': [2, 1, 4, 0, 3, 5], // gratitude + journal first
    'grief':      [1, 4, 2, 0, 3, 5], // journal + connect first
    'relationships':[4, 1, 2, 0, 3, 5], // connect + journal first
  };

  static const Map<String, List<int>> _stressorChallengeOrder = {
    'exams':       [0, 1, 2, 3, 4, 5],
    'performance': [0, 2, 1, 3, 4, 5],
    'loneliness':  [4, 2, 1, 0, 3, 5],
    'finances':    [4, 1, 2, 0, 3, 5],
    'time':        [0, 2, 3, 1, 4, 5],
    'identity':    [1, 2, 4, 0, 3, 5],
  };

  /// Returns challenge indices in the order most relevant for this user.
  static List<int> getChallengeOrder(UserModel? user) {
    if (user == null) return [0, 1, 2, 3, 4, 5];
    for (final g in user.goals) {
      final order = _goalChallengeOrder[g];
      if (order != null) return order;
    }
    for (final s in user.stressors) {
      final order = _stressorChallengeOrder[s];
      if (order != null) return order;
    }
    return [0, 1, 2, 3, 4, 5];
  }

  /// Returns a goal-aware description for each challenge index.
  static String getChallengeDescription(int index, UserModel? user) {
    final goals = user?.goals ?? [];
    final stressors = user?.stressors ?? [];

    switch (index) {
      case 0: // Breathe
        if (goals.contains('anxiety')) return 'Activate your calm system — anxiety responds to breath';
        if (goals.contains('stress') || stressors.contains('exams')) return 'Reset your stress response between study sessions';
        if (goals.contains('sleep')) return 'Wind-down breathing to prepare your body for rest';
        return '5-minute breathing exercise';
      case 1: // Journal
        if (goals.contains('depression')) return 'Write one thing that felt okay today — find the light';
        if (goals.contains('grief')) return 'Let your grief find words — writing it moves it through';
        if (goals.contains('anxiety')) return 'Get racing thoughts out of your head and onto the page';
        if (stressors.contains('exams')) return 'Brain-dump your worries — then close the notebook';
        return 'Write about one good thing today';
      case 2: // Gratitude
        if (goals.contains('depression')) return 'Name 3 things — even tiny — that still hold some good';
        if (goals.contains('selfesteem')) return 'Include something about yourself in your three today';
        if (goals.contains('stress')) return 'Zoom out — what is still working, even now?';
        return 'Name 3 things you\'re grateful for';
      case 3: // Move
        if (goals.contains('anxiety')) return 'Physical movement releases anxiety from the body — not just the mind';
        if (goals.contains('motivation')) return 'Motion creates emotion. A 10-min walk changes your state';
        if (goals.contains('depression')) return 'Gentle movement counters the physical weight of low mood';
        return '10-minute mindful walk';
      case 4: // Connect (Maya)
        if (goals.contains('social')) return 'Practice opening up — Maya is a safe space to start';
        if (goals.contains('grief')) return 'Grief is lighter when shared. Talk to Maya today';
        if (goals.contains('depression')) return 'Don\'t carry today alone — check in with Maya';
        return 'Check in with Maya about your day';
      case 5: // Wind Down
        if (goals.contains('sleep')) return 'Tonight\'s sleep starts now — set your sleep intention';
        if (goals.contains('stress') || stressors.contains('exams')) return 'Protect your rest tonight — log your sleep intention';
        if (goals.contains('anxiety')) return 'Let tonight be a pause — log your intention for rest';
        return 'Log your sleep intention tonight';
      default:
        return '5-minute wellness activity';
    }
  }

  // ═══════════════════════════════════════════════════════
  // NOTIFICATION COPY ─ goal + stressor aware
  // ═══════════════════════════════════════════════════════

  /// Maps checkInTime preference to notification hour.
  static int checkInHour(String? checkInTime) => switch (checkInTime) {
        'morning' => 8,
        'afternoon' => 14,
        'evening' => 20,
        _ => 20, // 'any' or null → default 8pm
      };

  static int checkInMinute(String? checkInTime) => switch (checkInTime) {
        'morning' => 0,
        'afternoon' => 0,
        'evening' => 0,
        _ => 0,
      };

  /// Returns a goal-aware check-in notification title.
  static String getCheckInTitle(UserModel? user) {
    if (user == null) {
      final h = DateTime.now().hour;
      if (h < 12) return 'Good morning! How are you feeling? ☀️';
      if (h < 17) return 'Afternoon check-in time 🌤';
      return 'How was your day? 🌙';
    }

    final time = user.checkInTime;
    return switch (time) {
      'morning' => 'Good morning, ${user.displayName}! Ready to start strong? ☀️',
      'afternoon' => 'Midday check-in, ${user.displayName} — how is your day going? 🌤',
      'evening' => 'Evening wind-down, ${user.displayName} — how was your day? 🌙',
      _ => 'Maya is here for you, ${user.displayName} 💙',
    };
  }

  /// Returns a goal-aware check-in notification body.
  static String getCheckInBody(UserModel? user) {
    if (user == null || user.goals.isEmpty) {
      const fallback = [
        'Take a moment to log how you\'re feeling today.',
        'Your mental health matters. Quick mood check?',
        'Maya is here if you want to talk. Start with a check-in.',
      ];
      return fallback[DateTime.now().minute % fallback.length];
    }

    final goal = user.goals.first;
    final stressor = user.stressors.isNotEmpty ? user.stressors.first : '';

    // Stressor-specific (more urgent, more contextual)
    if (stressor == 'exams' && _isExamSeason()) {
      return 'CAT season is hard. A 30-second check-in helps you stay grounded. 📝';
    }
    if (stressor == 'finances') {
      return 'Financial pressure is real. How are you holding up today? Maya is here. 💙';
    }

    return switch (goal) {
      'anxiety' =>
        'Anxiety check: on a scale of 1–10, how calm does your body feel right now? Log it.',
      'depression' =>
        'Even a small check-in builds momentum. How are you feeling, honestly? 💙',
      'stress' =>
        'Quick stress check-in — logging how you feel now helps Maya support you better.',
      'sleep' =>
        'How did you sleep last night? Tracking sleep is your first step to sleeping better.',
      'social' =>
        'How connected are you feeling today? Maya is always here to talk.',
      'motivation' =>
        'Motivation starts with one small step. Log your mood — that counts as step one.',
      'mindfulness' =>
        'Take a mindful breath, then log how you\'re feeling. 30 seconds. That\'s all.',
      'selfesteem' =>
        'Check in with yourself — your mood matters, and so do you. 💪',
      'grief' =>
        'Grief is not linear. Wherever you are today is okay. How are you feeling?',
      'relationships' =>
        'How are you feeling in your connections today? A quick check-in helps Maya understand.',
      _ => 'Maya is here for you. Take a moment to log how you\'re feeling. 💙',
    };
  }

  // ═══════════════════════════════════════════════════════
  // STREAK PROTECTION ─ goal-aware messaging
  // ═══════════════════════════════════════════════════════

  static String getStreakProtectionBody(UserModel? user) {
    if (user == null || user.goals.isEmpty) {
      return 'You haven\'t logged today yet. Quick check-in to keep your streak alive.';
    }
    final goal = user.goals.first;
    return switch (goal) {
      'anxiety' =>
        'Your anxiety management streak is on the line. 30-second check-in — you\'ve got this.',
      'depression' =>
        'Today\'s check-in matters more than you know. Keep showing up for yourself. 💙',
      'sleep' =>
        'Log your mood before bed — it only takes a moment and protects your sleep streak.',
      'motivation' =>
        'Don\'t break your streak today. Consistency is exactly what builds motivation.',
      _ => 'You haven\'t logged today yet. Quick check-in to keep your streak alive.',
    };
  }

  // ═══════════════════════════════════════════════════════
  // TODAY'S PRIMARY FOCUS ─ the single most important action
  // ═══════════════════════════════════════════════════════

  static ({
    String title,
    String subtitle,
    String emoji,
    String ctaLabel,
    String route,
    String goalId,
  }) getTodaysFocus(UserModel? user, MoodState? moodState) {
    final goals = user?.goals ?? [];
    final stressors = user?.stressors ?? [];
    final today = moodState?.todayEntry;
    final moodScore = today?.moodScore;

    // Crisis override
    if (moodScore != null && moodScore <= 2) {
      return (
        title: 'You\'re struggling today — Maya is here',
        subtitle: 'A low mood day is still a day worth showing up for. Talk to Maya.',
        emoji: '💙',
        ctaLabel: 'Talk to Maya',
        route: AppRoutes.chat,
        goalId: '',
      );
    }

    // No check-in yet — priority is always to check in
    if (today == null) {
      final g = goals.isNotEmpty ? goals.first : '';
      final checkInPrompt = switch (g) {
        'anxiety' => 'Naming how your body feels right now reduces anxiety\'s grip.',
        'sleep' => 'Track how you slept — it\'s the first step to sleeping better.',
        'depression' => 'Showing up for a check-in, even on hard days, matters.',
        'stress' => 'A quick check-in resets your stress response.',
        _ => 'A 30-second check-in helps Maya support you better today.',
      };
      return (
        title: 'Start with a check-in',
        subtitle: checkInPrompt,
        emoji: '✅',
        ctaLabel: 'Log mood',
        route: AppRoutes.moodTracker,
        goalId: g,
      );
    }

    // Exam season + exam stressor → study break
    if (_isExamSeason() && stressors.contains('exams')) {
      return (
        title: 'CAT season: protect your focus',
        subtitle: 'A 5-min breathing break between study sessions improves retention by up to 20%.',
        emoji: '📝',
        ctaLabel: 'Breathe now',
        route: AppRoutes.breathing,
        goalId: 'stress',
      );
    }

    // Per-goal primary focus
    if (goals.isNotEmpty) {
      return switch (goals.first) {
        'anxiety' => (
            title: 'Work on your anxiety today',
            subtitle: 'A 5-min breathing session measurably lowers cortisol. Do it now.',
            emoji: '😌',
            ctaLabel: 'Breathe now',
            route: AppRoutes.breathing,
            goalId: 'anxiety',
          ),
        'depression' => (
            title: 'Write something today',
            subtitle: 'Journaling even 3 sentences has measurable positive effects on low mood.',
            emoji: '💙',
            ctaLabel: 'Open journal',
            route: AppRoutes.journalEntry,
            goalId: 'depression',
          ),
        'sleep' => (
            title: 'Protect tonight\'s sleep',
            subtitle: 'Your sleep goal needs a wind-down routine. Start it 30 minutes before bed.',
            emoji: '😴',
            ctaLabel: 'Wind-down',
            route: AppRoutes.mindfulness,
            goalId: 'sleep',
          ),
        'stress' => (
            title: 'Take a breath break today',
            subtitle: 'Stress compounds without release. One 5-min breathing session resets everything.',
            emoji: '📚',
            ctaLabel: 'Breathe now',
            route: AppRoutes.breathing,
            goalId: 'stress',
          ),
        'social' => (
            title: 'Make one connection today',
            subtitle: 'Social confidence grows through small, repeated actions. Talk to Maya first.',
            emoji: '🤝',
            ctaLabel: 'Talk to Maya',
            route: AppRoutes.chat,
            goalId: 'social',
          ),
        'motivation' => (
            title: 'Build your momentum today',
            subtitle: 'Complete one challenge today. Consistency is what motivation is built from.',
            emoji: '🚀',
            ctaLabel: 'View challenges',
            route: AppRoutes.wellness,
            goalId: 'motivation',
          ),
        'mindfulness' => (
            title: 'Your mindful moment awaits',
            subtitle: 'Five minutes of presence today builds a lifelong mindfulness habit.',
            emoji: '🧘',
            ctaLabel: 'Be present',
            route: AppRoutes.mindfulness,
            goalId: 'mindfulness',
          ),
        'selfesteem' => (
            title: 'Build your self-regard today',
            subtitle: 'Write three things you genuinely like about yourself. Not what you do — who you are.',
            emoji: '💪',
            ctaLabel: 'Write now',
            route: AppRoutes.journalEntry,
            goalId: 'selfesteem',
          ),
        'grief' => (
            title: 'Give yourself space today',
            subtitle: 'Grief needs expression, not management. Write, talk to Maya, or simply breathe.',
            emoji: '🌹',
            ctaLabel: 'Talk to Maya',
            route: AppRoutes.chat,
            goalId: 'grief',
          ),
        'relationships' => (
            title: 'Reflect on your connections',
            subtitle: 'Healthy relationships start with understanding your own needs. Journal it today.',
            emoji: '❤️',
            ctaLabel: 'Open journal',
            route: AppRoutes.journalEntry,
            goalId: 'relationships',
          ),
        _ => (
            title: 'Your wellness check-in',
            subtitle: 'Log your mood and check in with Maya for personalized support.',
            emoji: '💙',
            ctaLabel: 'Check in',
            route: AppRoutes.moodTracker,
            goalId: '',
          ),
      };
    }

    return (
      title: 'Today\'s wellness moment',
      subtitle: 'Even one small action compounds into lasting change.',
      emoji: '✨',
      ctaLabel: 'Log mood',
      route: AppRoutes.moodTracker,
      goalId: '',
    );
  }

  // ═══════════════════════════════════════════════════════
  // RESOURCE MATCHING ─ goal-aware category ranking
  // ═══════════════════════════════════════════════════════

  static const Map<String, List<String>> _goalResourceCategories = {
    'anxiety': ['Anxiety', 'Mindfulness', 'Stress', 'Sleep'],
    'depression': ['Depression', 'Mindfulness', 'Self-Esteem', 'Relationships'],
    'stress': ['Stress', 'Anxiety', 'Academic', 'Campus Life'],
    'sleep': ['Sleep', 'Mindfulness', 'Stress'],
    'social': ['Relationships', 'Self-Esteem', 'Campus Life'],
    'motivation': ['Academic', 'Self-Esteem', 'Stress'],
    'mindfulness': ['Mindfulness', 'Anxiety', 'Stress'],
    'selfesteem': ['Self-Esteem', 'Relationships', 'Mindfulness'],
    'grief': ['Depression', 'Relationships', 'Mindfulness'],
    'relationships': ['Relationships', 'Self-Esteem', 'Campus Life'],
  };

  static const Map<String, List<String>> _stressorResourceCategories = {
    'exams': ['Stress', 'Academic', 'Anxiety'],
    'finances': ['Finance', 'Campus Life', 'Stress'],
    'loneliness': ['Relationships', 'Self-Esteem', 'Campus Life'],
    'family': ['Relationships', 'Stress', 'Mindfulness'],
    'health': ['Sleep', 'Mindfulness', 'Stress'],
    'career': ['Academic', 'Campus Life', 'Self-Esteem'],
    'identity': ['Self-Esteem', 'Mindfulness', 'Relationships'],
  };

  /// Returns resource categories in priority order for this user.
  static List<String> getResourceCategoryPriority(UserModel? user) {
    final result = <String>[];
    final seen = <String>{};

    void add(String cat) {
      if (seen.add(cat)) result.add(cat);
    }

    if (user != null) {
      for (final g in user.goals) {
        for (final cat in _goalResourceCategories[g] ?? []) add(cat);
      }
      for (final s in user.stressors) {
        for (final cat in _stressorResourceCategories[s] ?? []) add(cat);
      }
    }

    // Always include these
    for (final cat in ['Anxiety', 'Stress', 'Campus Life', 'Crisis']) add(cat);
    return result;
  }

  /// Returns a "why this is for you" string for a resource given the user.
  static String? getResourceReason(
    Map<String, dynamic> resource,
    UserModel? user,
  ) {
    if (user == null) return null;
    final category = resource['category'] as String? ?? '';
    final title = resource['title'] as String? ?? '';

    final goals = user.goals;
    final stressors = user.stressors;

    if (category == 'Anxiety' && goals.contains('anxiety')) {
      return 'Matches your anxiety management goal';
    }
    if (category == 'Sleep' && goals.contains('sleep')) {
      return 'Directly supports your better sleep goal';
    }
    if (category == 'Stress' && (goals.contains('stress') || stressors.contains('exams'))) {
      return stressors.contains('exams')
          ? 'Tailored for exam season stress'
          : 'Supports your academic stress goal';
    }
    if (category == 'Depression' && goals.contains('depression')) {
      return 'Chosen to support coping with low mood';
    }
    if (category == 'Relationships' && (goals.contains('relationships') || goals.contains('social'))) {
      return 'Relevant to your relationship goals';
    }
    if (category == 'Self-Esteem' && goals.contains('selfesteem')) {
      return 'Supports your self-esteem journey';
    }
    if (category == 'Finance' && stressors.contains('finances')) {
      return 'Relevant to your financial stress';
    }
    if (category == 'Mindfulness' && goals.contains('mindfulness')) {
      return 'Matched to your mindfulness practice goal';
    }
    if (category == 'Campus Life') {
      return 'Relevant to your campus experience';
    }
    if (category == 'Crisis') {
      return 'Always available when you need urgent support';
    }

    return null;
  }
}

// ─── Internal season helpers ──────────────────────────────

bool _isExamSeason() {
  final now = DateTime.now();
  final m = now.month;
  final d = now.day;
  return (m == 10 && d >= 15) || (m == 11 && d <= 15) ||
      (m == 12 && d <= 20) ||
      (m == 3 && d >= 15) || (m == 4 && d <= 15) ||
      m == 5;
}
