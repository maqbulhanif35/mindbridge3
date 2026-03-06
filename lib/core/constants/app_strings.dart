abstract class AppStrings {
  // ─── App Identity ─────────────────────────────────────
  static const String appName = 'MindBridge';
  static const String appTagline = 'Your Bridge to Better Mental Health';
  static const String aiName = 'Maya';

  // ─── Onboarding ───────────────────────────────────────
  static const List<Map<String, String>> onboardingData = [
    {
      'title': "You're Not Alone",
      'subtitle':
          '69% of students struggle with mental health. MindBridge is here to change that — for you.',
      'illustration': 'assets/animations/not_alone.json',
    },
    {
      'title': 'Meet Maya, Your AI Companion',
      'subtitle':
          'Chat 24/7 with Maya — an empathetic AI trained in evidence-based therapy techniques.',
      'illustration': 'assets/animations/ai_chat.json',
    },
    {
      'title': 'Track Your Wellness Journey',
      'subtitle':
          'Log moods, journal thoughts, practice mindfulness, and watch yourself grow day by day.',
      'illustration': 'assets/animations/tracking.json',
    },
  ];

  // ─── Auth ─────────────────────────────────────────────
  static const String loginTitle = 'Welcome back';
  static const String loginSubtitle = "We're glad you're here.";
  static const String registerTitle = 'Create your account';
  static const String registerSubtitle = "Let's begin your wellness journey.";

  // ─── Home ─────────────────────────────────────────────
  static const String homeGreetingMorning = 'Good morning';
  static const String homeGreetingAfternoon = 'Good afternoon';
  static const String homeGreetingEvening = 'Good evening';
  static const String homeGreetingNight = 'Good night';
  static const String homeSubtitle = "How are you feeling today?";

  // ─── Chat ─────────────────────────────────────────────
  static const String chatTitle = 'Chat with Maya';
  static const String chatPlaceholder = 'Share what\'s on your mind...';
  static const String chatTypingIndicator = 'Maya is thinking...';
  static const String chatNewSession = 'New Conversation';

  static const List<String> chatSuggestions = [
    "I'm feeling stressed about exams",
    "I've been feeling lonely lately",
    "Help me calm down right now",
    "I can't sleep because of anxiety",
    "I feel like I'm falling behind",
    "I had a conflict with a friend",
    "I'm feeling overwhelmed",
    "Help me practice gratitude",
  ];

  // ─── Maya System Prompt ───────────────────────────────
  static const String mayaSystemPrompt = """
You are Maya, an empathetic AI mental wellness companion designed specifically for university
and college students. You are built into MindBridge, a student mental health support platform.

## Your Core Identity
- Name: Maya
- Role: Supportive AI companion (NOT a therapist or doctor)
- Approach: Warm, non-judgmental, evidence-based

## Your Therapeutic Approach
You are trained in and use these evidence-based techniques:
1. **Cognitive Behavioral Therapy (CBT)** — Help identify and reframe negative thought patterns
2. **Dialectical Behavior Therapy (DBT)** — Distress tolerance, emotion regulation, mindfulness
3. **Acceptance & Commitment Therapy (ACT)** — Values-based living, psychological flexibility
4. **Mindfulness-Based Interventions** — Present-moment awareness techniques
5. **Problem-Solving Therapy** — Structured approach to academic and personal challenges
6. **Behavioral Activation** — Scheduling meaningful activities to combat depression

## Communication Style
- Use a warm, conversational tone — not clinical or formal
- Use open-ended questions to explore feelings
- Validate emotions before offering solutions ("It makes complete sense that you feel...")
- Avoid toxic positivity — acknowledge the difficulty before reframing
- Use "I" statements and reflective listening
- Keep responses focused and not overwhelming (2-4 paragraphs max)
- Use emojis sparingly but naturally when appropriate

## Student-Specific Knowledge
Understand and address:
- Exam anxiety and academic pressure
- Imposter syndrome in competitive academic environments
- Financial stress and student debt anxiety
- Social isolation, loneliness on campus
- Sleep disruption from study schedules
- Relationship issues and peer pressure
- Career uncertainty and post-graduation anxiety
- International student cultural adjustment
- Substance use patterns common in students

## Safety Protocol (MANDATORY)
If a student expresses:
- Active suicidal ideation or self-harm intent → ALWAYS provide crisis resources immediately
- Mention of specific plans to harm themselves → Escalate, do not continue normal conversation
- Passive suicidal ideation ("I wish I wasn't here") → Gently assess safety, provide resources

Crisis Resources to always mention in crisis:
- 988 Suicide & Crisis Lifeline: Call or text 988 (US)
- Crisis Text Line: Text HOME to 741741
- International Association for Suicide Prevention: https://www.iasp.info/resources/Crisis_Centres/

## Important Boundaries
- Always clarify you are an AI, not a licensed therapist
- For serious clinical concerns, recommend professional help
- Never diagnose conditions
- Never prescribe or recommend medications
- Never discuss methods of self-harm
- If unsure, err on the side of caution and suggest professional support

Remember: You are often talking to someone who needs to feel heard. Prioritize empathy over advice.
""";

  // ─── Mood ─────────────────────────────────────────────
  static const List<String> moodLabels = [
    '',
    'Terrible',
    'Very Bad',
    'Bad',
    'Poor',
    'Neutral',
    'Okay',
    'Good',
    'Great',
    'Excellent',
    'Amazing',
  ];

  static const List<String> moodEmojis = [
    '',
    '😭',
    '😢',
    '😞',
    '😟',
    '😐',
    '🙂',
    '😊',
    '😄',
    '😁',
    '🤩',
  ];

  static const List<String> emotionTags = [
    'Happy',
    'Sad',
    'Anxious',
    'Calm',
    'Angry',
    'Excited',
    'Tired',
    'Grateful',
    'Lonely',
    'Hopeful',
    'Overwhelmed',
    'Proud',
    'Frustrated',
    'Content',
    'Nervous',
    'Motivated',
    'Confused',
    'Relieved',
    'Stressed',
    'Peaceful',
    'Scared',
    'Confident',
    'Embarrassed',
    'Loved',
    'Bored',
    'Curious',
    'Disappointed',
    'Energetic',
    'Melancholy',
    'Optimistic',
    'Irritable',
    'Focused',
  ];

  static const List<String> activityTags = [
    'Studying',
    'Exercise',
    'Socializing',
    'Gaming',
    'Reading',
    'Music',
    'Nature',
    'Cooking',
    'Sleep',
    'Work',
    'Family',
    'Dating',
    'Meditation',
    'Art',
    'Sports',
  ];

  // ─── Journal Prompts ──────────────────────────────────
  static const List<String> journalPrompts = [
    'What is one thing I am grateful for today?',
    'What challenged me today, and how did I handle it?',
    'What emotion has been most present for me this week?',
    'If I could talk to my future self, what would I want to hear?',
    'What is one small thing I can do tomorrow to take care of myself?',
    'What thought pattern keeps repeating in my mind lately?',
    'Describe a moment today when you felt connected to someone.',
    'What are three things that are going well in my life right now?',
    'What am I most worried about, and what would help?',
    'Write about someone who has positively influenced your life.',
    'What does my ideal week look like? What is stopping me from having it?',
    'What are my core values and how am I living them?',
  ];

  // ─── Crisis ───────────────────────────────────────────
  static const String crisisTitle = 'You Are Not Alone';
  static const String crisisSubtitle =
      'If you are in crisis or having thoughts of self-harm, please reach out immediately.';

  static const List<Map<String, String>> crisisContacts = [
    {
      'name': '988 Suicide & Crisis Lifeline',
      'number': '988',
      'description': 'Call or text 988 — Available 24/7 (US)',
      'type': 'hotline',
    },
    {
      'name': 'Crisis Text Line',
      'number': '741741',
      'description': "Text HOME to 741741 — Available 24/7",
      'type': 'text',
    },
    {
      'name': 'Emergency Services',
      'number': '911',
      'description': 'Call 911 if there is immediate danger',
      'type': 'emergency',
    },
    {
      'name': 'SAMHSA Helpline',
      'number': '1-800-662-4357',
      'description': 'Substance & mental health — Free, confidential',
      'type': 'hotline',
    },
  ];

  // ─── Mindfulness ──────────────────────────────────────
  static const List<Map<String, dynamic>> breathingExercises = [
    {
      'id': 'box_breathing',
      'name': 'Box Breathing',
      'description': 'Used by Navy SEALs to reduce stress and regain focus',
      'inhale': 4,
      'holdIn': 4,
      'exhale': 4,
      'holdOut': 4,
      'color': 0xFF00BEB4,
      'icon': 'box',
    },
    {
      'id': '4_7_8',
      'name': '4-7-8 Breathing',
      'description': 'Activates the parasympathetic nervous system for calm',
      'inhale': 4,
      'holdIn': 7,
      'exhale': 8,
      'holdOut': 0,
      'color': 0xFF4ECDC4,
      'icon': 'wave',
    },
    {
      'id': 'deep_breathing',
      'name': 'Deep Belly Breathing',
      'description': 'Simple diaphragmatic breathing for immediate relief',
      'inhale': 5,
      'holdIn': 2,
      'exhale': 6,
      'holdOut': 0,
      'color': 0xFFFF6B9D,
      'icon': 'circle',
    },
  ];

  // ─── Wellness Challenges ──────────────────────────────
  static const List<Map<String, dynamic>> dailyChallenges = [
    {
      'title': '3-Minute Breathing',
      'description': 'Complete one breathing exercise session',
      'points': 10,
      'icon': '🫁',
      'type': 'mindfulness',
    },
    {
      'title': 'Gratitude Entry',
      'description': 'Write 3 things you are grateful for in your journal',
      'points': 15,
      'icon': '📝',
      'type': 'journal',
    },
    {
      'title': 'Mood Log',
      'description': 'Record your mood and emotions for today',
      'points': 5,
      'icon': '😊',
      'type': 'mood',
    },
    {
      'title': 'Mindful Walk',
      'description': 'Take a 10-minute walk without your phone',
      'points': 20,
      'icon': '🚶',
      'type': 'physical',
    },
    {
      'title': 'Connect',
      'description': 'Reach out to one person you care about',
      'points': 25,
      'icon': '💬',
      'type': 'social',
    },
    {
      'title': 'Sleep Hygiene',
      'description': 'Be in bed before midnight and log your sleep',
      'points': 15,
      'icon': '😴',
      'type': 'sleep',
    },
  ];
}
