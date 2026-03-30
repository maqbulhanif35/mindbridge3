// ─── Resource Data Models & Static Content ─────────────────

class ContentSection {
  final String? heading;
  final String body;
  const ContentSection({this.heading, required this.body});
}

class ExerciseStep {
  final String title;
  final String instruction;
  final int? durationSeconds; // null = tap to advance
  const ExerciseStep({required this.title, required this.instruction, this.durationSeconds});
}

class Hotline {
  final String name;
  final String number;
  final String hours;
  final String? note;
  const Hotline({required this.name, required this.number, required this.hours, this.note});
}

class ResourceItem {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String category;
  final String type; // 'article' | 'guide' | 'exercise' | 'crisis'
  final String emoji;
  final String readTime;
  final bool isHot;
  final bool isFeatured;
  final int colorValue;
  final List<ContentSection> sections;
  final List<ExerciseStep>? steps;
  final List<Hotline>? hotlines;
  final int xp;

  const ResourceItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.type,
    required this.emoji,
    required this.readTime,
    this.isHot = false,
    this.isFeatured = false,
    required this.colorValue,
    required this.sections,
    this.steps,
    this.hotlines,
    this.xp = 10,
  });
}

// ─── Curated Resource Library ──────────────────────────────

const kResources = <ResourceItem>[
  // ── Articles ──────────────────────────────────────────────

  ResourceItem(
    id: 'cat_season',
    title: 'Surviving CAT Season Without Burning Out',
    subtitle: 'Protect your mental health during assessment season',
    description: 'Proven strategies for managing the intense pressure of CATs while protecting your mental health.',
    category: 'Stress',
    type: 'article',
    emoji: '📝',
    readTime: '7 min',
    isHot: true,
    isFeatured: true,
    colorValue: 0xFF00BEB4,
    xp: 15,
    sections: [
      ContentSection(
        body: 'CATs arrive every 6–8 weeks at most Kenyan universities, and the compressed timelines can make even the most prepared student feel overwhelmed. The good news: with the right strategy, you can perform well without sacrificing your mental health.',
      ),
      ContentSection(
        heading: 'Start Two Weeks Before',
        body: 'List every unit being tested and the marks allocated. Prioritise by weight — a 20-mark section deserves more time than a 5-mark one. Break each topic into 30-minute study blocks spread across the two weeks. Consistency beats cramming every time.',
      ),
      ContentSection(
        heading: 'Sleep Is Non-Negotiable',
        body: 'Sleep-deprived students perform significantly worse on memory and problem-solving tasks. Aim for at least 7 hours. Pulling an all-nighter might feel productive, but you\'ll retain almost nothing studied after midnight — your brain needs sleep to consolidate memories.',
      ),
      ContentSection(
        heading: 'Use the Pomodoro Technique',
        body: 'Study for 25 minutes, break for 5. After 4 cycles, take a longer 20-minute break. This prevents mental fatigue and keeps concentration sharp. Use Forest or a simple phone timer — keeping your phone face-down during study blocks.',
      ),
      ContentSection(
        heading: 'Know When to Ask for Help',
        body: 'If the pressure feels crushing, your university\'s Student Counseling Unit offers free, confidential sessions. Many students find even one conversation dramatically changes how they relate to academic pressure. You are not weak for asking for support — you are strategic.',
      ),
    ],
  ),

  ResourceItem(
    id: 'helb_stress',
    title: 'HELB Stress is Real — Here\'s How to Cope',
    subtitle: 'Managing financial anxiety as a Kenyan student',
    description: 'When your loan delays and fees are due, the anxiety is real. Practical steps for managing financial stress.',
    category: 'Finance',
    type: 'article',
    emoji: '💸',
    readTime: '6 min',
    isHot: true,
    isFeatured: true,
    colorValue: 0xFFF59E0B,
    xp: 15,
    sections: [
      ContentSection(
        body: 'The HELB loan process is one of the most stressful experiences unique to Kenyan university students. Delays, portal errors, guarantor complications — and meanwhile fees deadlines loom. If financial anxiety is affecting your studies or sleep, you\'re not alone.',
      ),
      ContentSection(
        heading: 'Communicate Early with Finance Office',
        body: 'Most universities will not deregister a student who proactively communicates. Visit the finance office before the deadline, explain your situation, and request a deferment. Put it in writing. Institutions have more flexibility than their public messaging suggests.',
      ),
      ContentSection(
        heading: 'Know the Emergency Bursary Process',
        body: 'Most public universities have emergency bursary funds administered through the Dean of Students\' office. These are rarely publicised but are specifically for students in your situation. Ask directly: "Do you have emergency financial assistance for students?"',
      ),
      ContentSection(
        heading: 'Separate the Financial Problem from Your Mental State',
        body: 'The financial problem is real and needs solving — but the anxiety catastrophizing ("I\'ll be kicked out", "my parents will be disappointed") is a thought pattern that can be challenged. Write down your actual worst-case scenario versus what is likely to actually happen.',
      ),
      ContentSection(
        heading: 'Practical Short-Term Steps',
        body: 'Look into on-campus part-time work (library desk, department assistant). Join peer tutoring programs which usually pay small stipends. The Dean of Students office can also refer you to NGOs and foundations that offer emergency academic support.',
      ),
    ],
  ),

  ResourceItem(
    id: 'imposter_syndrome',
    title: 'Imposter Syndrome: You Belong Here',
    subtitle: 'Overcoming the feeling that you don\'t deserve your place',
    description: 'Overcoming the feeling that you don\'t deserve your spot — especially when coming from a humble background.',
    category: 'Self-Esteem',
    type: 'article',
    emoji: '💪',
    readTime: '10 min',
    isHot: true,
    isFeatured: true,
    colorValue: 0xFF8B5CF6,
    xp: 20,
    sections: [
      ContentSection(
        body: 'Imposter syndrome — the persistent belief that you\'re a fraud who doesn\'t deserve your achievements — is especially common among first-generation university students and those who grew up in environments very different from their current institution.',
      ),
      ContentSection(
        heading: 'You Were Admitted Because You Earned It',
        body: 'Universities don\'t admit students by mistake. Your KCSE grade, your application, your interview — they all reflect real ability. The discomfort you feel in new academic environments is not evidence of inadequacy; it\'s evidence that you\'re growing.',
      ),
      ContentSection(
        heading: 'Everyone Else Feels This Too',
        body: 'Studies show that imposter syndrome affects the majority of high-achieving individuals, including professors and CEOs. The students who look most confident in the front row are often performing confidence while feeling just as uncertain inside.',
      ),
      ContentSection(
        heading: 'Track Your Evidence',
        body: 'Keep a "wins journal" — a note on your phone where you record things you did well. A question you answered in class, an assignment you completed, a concept you finally understood. Evidence is the antidote to imposter thinking.',
      ),
      ContentSection(
        heading: 'Your Background Is a Strength',
        body: 'Coming from a challenging background means you\'ve already demonstrated resilience, resourcefulness, and determination. These are qualities many of your peers have never had to develop. Your story is not a liability — it\'s part of what makes you exceptional.',
      ),
    ],
  ),

  ResourceItem(
    id: 'depression_toolkit',
    title: 'The Depression Toolkit',
    subtitle: '10 evidence-based strategies for lifting your mood',
    description: '10 evidence-based strategies adapted for the Kenyan campus environment.',
    category: 'Depression',
    type: 'article',
    emoji: '💙',
    readTime: '12 min',
    isFeatured: true,
    colorValue: 0xFF3B82F6,
    xp: 25,
    sections: [
      ContentSection(
        body: 'Depression is more than sadness — it\'s a persistent low mood, loss of interest, difficulty concentrating, and sometimes physical symptoms like fatigue and changed appetite. It\'s also treatable. These strategies are drawn from Cognitive Behavioural Therapy and behavioural activation research.',
      ),
      ContentSection(
        heading: '1. Behavioural Activation',
        body: 'Depression tells you to withdraw. Do the opposite: schedule one small, manageable activity each day — a 10-minute walk, calling a friend, cooking a simple meal. Action precedes motivation, not the other way around. Start tiny.',
      ),
      ContentSection(
        heading: '2. Sunlight and Movement',
        body: 'Natural light and exercise are among the most evidence-backed interventions for low mood. A 20-minute walk outside — ideally in the morning — affects serotonin levels more significantly than many people expect. It\'s free and available every day.',
      ),
      ContentSection(
        heading: '3. Challenge Negative Thoughts',
        body: 'Depression distorts thinking. When you notice thoughts like "I\'m worthless" or "nothing will improve", pause and ask: What is the actual evidence for this? What would I tell a friend who said this about themselves? Write it down.',
      ),
      ContentSection(
        heading: '4. Maintain Structure',
        body: 'Depression thrives in unstructured time. Even a loose daily routine — wake time, meals, study blocks — gives your brain predictability and a sense of control. You don\'t need a rigid schedule, just a gentle rhythm.',
      ),
      ContentSection(
        heading: 'When to Seek Professional Help',
        body: 'If low mood persists for more than two weeks, is affecting your studies or relationships, or includes thoughts of self-harm, please speak to a counsellor. Your university\'s Student Counseling Unit is free and confidential. You do not need to manage this alone.',
      ),
    ],
  ),

  ResourceItem(
    id: 'campus_anxiety',
    title: 'Understanding Anxiety in Campus Life',
    subtitle: 'Recognise and manage anxiety before it controls you',
    description: 'A guide to recognizing and managing anxiety that builds during lectures, group work, and hostel life.',
    category: 'Anxiety',
    type: 'article',
    emoji: '😰',
    readTime: '8 min',
    colorValue: 0xFF0EA5E9,
    xp: 15,
    sections: [
      ContentSection(
        body: 'Anxiety is your brain\'s alarm system. In small doses it\'s useful — it keeps you alert before a presentation. But when the alarm stays on too long, it becomes exhausting and disruptive. Campus life has specific triggers: social judgment, academic performance, financial uncertainty, and being far from home.',
      ),
      ContentSection(
        heading: 'Recognise Your Anxiety Signals',
        body: 'Physical: racing heart, shallow breathing, tight chest, stomach knots. Cognitive: "what if" spirals, catastrophising, mind-reading ("they think I\'m stupid"). Behavioural: avoiding situations, procrastinating, reassurance-seeking. Knowing your pattern is the first step to managing it.',
      ),
      ContentSection(
        heading: 'The STOP Technique',
        body: 'S — Stop what you\'re doing. T — Take three slow, deep breaths. O — Observe your thoughts without judgment ("I\'m noticing I\'m anxious"). P — Proceed with awareness. This 60-second practice interrupts the anxiety spiral before it escalates.',
      ),
      ContentSection(
        heading: 'Reduce Avoidance',
        body: 'The most powerful way to reduce anxiety long-term is gradual exposure — facing what you fear in small steps. If group presentations terrify you, start by answering one question in class. If social settings overwhelm you, go to one event for 15 minutes. Each small win rewires your brain\'s threat response.',
      ),
    ],
  ),

  ResourceItem(
    id: 'sleep_assignments',
    title: 'Sleep When You Have Assignments Due',
    subtitle: 'Build a sleep routine that works around your workload',
    description: 'Build a sleep routine that works when you\'re juggling CATs, assignments, and part-time work.',
    category: 'Sleep',
    type: 'article',
    emoji: '😴',
    readTime: '6 min',
    colorValue: 0xFF6366F1,
    xp: 10,
    sections: [
      ContentSection(
        body: 'Sleep deprivation is so normalised in university culture that students wear it as a badge of honour. The reality: chronic sleep deprivation impairs memory consolidation, emotional regulation, immune function, and academic performance. You cannot hustle your way around biology.',
      ),
      ContentSection(
        heading: 'The 2am Rule',
        body: 'Commit to being in bed by 2am at the absolute latest, even during heavy workloads. Studies show the hours between 2am and 6am are the least productive for most people — you\'re essentially delaying sleep for diminishing returns. The work will still be there after proper rest.',
      ),
      ContentSection(
        heading: 'Wind-Down Ritual',
        body: 'The hour before bed should be low-stimulation: dim your screen brightness, avoid social media arguments, drink water. If your phone is your alarm, keep it across the room to avoid doom-scrolling. Even 20 minutes of this routine significantly improves sleep onset speed.',
      ),
      ContentSection(
        heading: 'Strategic Napping',
        body: 'If you\'re seriously sleep-deprived, a 20-minute nap (set an alarm — no longer, or you\'ll feel groggy) in the afternoon can restore alertness without disrupting nighttime sleep. Research shows short naps improve memory consolidation and focus for 2–3 hours after.',
      ),
    ],
  ),

  ResourceItem(
    id: 'burnout_guide',
    title: 'The Kenyan Student Burnout Guide',
    subtitle: 'Recognise it early and recover before it breaks you',
    description: 'Burnout hits differently when you\'re also supporting family and managing fees. Recognize it and recover.',
    category: 'Stress',
    type: 'article',
    emoji: '🔥',
    readTime: '9 min',
    colorValue: 0xFFEF4444,
    xp: 15,
    sections: [
      ContentSection(
        body: 'Burnout is not laziness. It\'s a state of physical and emotional exhaustion caused by sustained, overwhelming demands. For many Kenyan students, the pressure is compounded: academic performance, family expectations, financial stress, and sometimes part-time work — all at once.',
      ),
      ContentSection(
        heading: 'The Three Dimensions of Burnout',
        body: 'Exhaustion (physically and emotionally drained), Cynicism (feeling detached from your studies, "what\'s the point"), and Reduced Efficacy (feeling incompetent, like you\'re not achieving anything despite effort). Recognising these early is critical.',
      ),
      ContentSection(
        heading: 'Recovery Is Not a Holiday',
        body: 'True recovery from burnout requires reducing the actual demands on you — not just resting on a Saturday. This means having an honest conversation about your workload, saying no to some commitments, and getting proper sleep for consecutive nights.',
      ),
      ContentSection(
        heading: 'Talk to Your Lecturer or Academic Advisor',
        body: 'Many students are surprised to discover how accommodating lecturers can be when approached early and honestly. "I\'m struggling and need some support" is a sentence that can open doors — to deadline extensions, reduced workloads, or referrals to the counselling unit.',
      ),
    ],
  ),

  ResourceItem(
    id: 'relationships',
    title: 'Navigating Difficult Relationships',
    subtitle: 'Boundaries, communication, and emotional safety',
    description: 'Setting boundaries and communicating effectively with friends, partners, lecturers, and family.',
    category: 'Relationships',
    type: 'article',
    emoji: '❤️',
    readTime: '11 min',
    colorValue: 0xFFEC4899,
    xp: 15,
    sections: [
      ContentSection(
        body: 'University relationships — romantic partnerships, friendships, family dynamics, and lecturer relationships — all have the potential to be major sources of both support and stress. Learning to navigate them consciously is one of the most important life skills you\'ll develop.',
      ),
      ContentSection(
        heading: 'What Boundaries Actually Mean',
        body: 'A boundary is not a wall — it\'s a clear statement of what you will and won\'t accept. "I can\'t receive calls after 10pm during exam week" is a boundary. Boundaries protect your energy. You cannot pour from an empty cup, and people who respect you will respect your limits.',
      ),
      ContentSection(
        heading: 'The Non-Violent Communication Formula',
        body: 'When addressing conflict: "When [specific behaviour] happens, I feel [emotion] because I need [underlying need]. Would you be willing to [specific request]?" This replaces blame with observation and transforms arguments into problem-solving conversations.',
      ),
      ContentSection(
        heading: 'When to Step Away',
        body: 'If a relationship consistently leaves you feeling worse about yourself, drained, unsafe, or anxious — that is data. Not every relationship deserves infinite investment. Stepping back from a harmful relationship is self-respect, not selfishness.',
      ),
    ],
  ),

  // ── Guides ────────────────────────────────────────────────

  ResourceItem(
    id: 'campus_counselor',
    title: 'Finding Your Campus Counselor',
    subtitle: 'Access free mental health support without stigma',
    description: 'Every Kenyan university has a free, confidential Student Counseling Unit. Here\'s how to access it.',
    category: 'Campus Life',
    type: 'guide',
    emoji: '🏥',
    readTime: '4 min',
    colorValue: 0xFF10B981,
    xp: 10,
    sections: [
      ContentSection(
        body: 'Every accredited Kenyan university has a Student Counseling Unit (SCU), often housed in the Dean of Students\' office or student affairs building. Sessions are free, confidential, and available to all registered students. You don\'t need a referral — you can walk in.',
      ),
      ContentSection(
        heading: 'What to Expect in Your First Session',
        body: 'The first session is an intake conversation — the counsellor will ask about what brought you in, your background, and what you\'re hoping to get from counselling. There\'s no right or wrong answer. You don\'t need to have a "serious problem" to attend.',
      ),
      ContentSection(
        heading: 'What Happens to Your Information',
        body: 'Everything shared in a counselling session is confidential. The counsellor cannot share your information with lecturers, parents, or the university administration — unless you are in immediate danger of harming yourself or others. Your privacy is protected by professional ethics.',
      ),
      ContentSection(
        heading: 'How to Book',
        body: 'Visit the Dean of Students\' office in person and ask for the counselling unit, or check your university\'s website for the SCU contact number. Some universities also have online booking through the student portal. If the first counsellor isn\'t a good fit, you can request another.',
      ),
    ],
  ),

  ResourceItem(
    id: 'attachment_pressure',
    title: 'Navigating Attachment & Internship Pressure',
    subtitle: 'Thrive in industrial attachment without breaking down',
    description: 'Industrial attachment can be overwhelming — unpaid work, new environments, and professional expectations.',
    category: 'Campus Life',
    type: 'guide',
    emoji: '🏢',
    readTime: '8 min',
    colorValue: 0xFF10B981,
    xp: 15,
    sections: [
      ContentSection(
        body: 'Industrial attachment is often the first time Kenyan university students encounter a professional environment — without the academic support structures they\'re used to. The combination of new social dynamics, often unpaid work, and performance pressure can be genuinely overwhelming.',
      ),
      ContentSection(
        heading: 'Set Realistic Expectations',
        body: 'The purpose of attachment is learning, not perfection. You\'re not expected to operate like a full employee. Ask questions — it\'s a sign of engagement, not weakness. No supervisor expects an intern to know everything on day one.',
      ),
      ContentSection(
        heading: 'Manage the Financial Reality',
        body: 'Many attachments are unpaid or minimally stipended, which adds financial stress. Before attachment starts, map out your expenses and discuss with family or university if any emergency support is available. HELB and your Dean of Students may have specific attachment support.',
      ),
      ContentSection(
        heading: 'Build Your Network Deliberately',
        body: 'Attachment is less about the work and more about the people you meet. Identify two or three professionals whose careers interest you and ask for a 20-minute conversation about their journey. Most people are happy to mentor a curious intern.',
      ),
    ],
  ),

  // ── Exercises ────────────────────────────────────────────

  ResourceItem(
    id: 'box_breathing',
    title: 'Box Breathing',
    subtitle: 'A 4-minute technique used by Navy SEALs to stay calm',
    description: 'Regulate your nervous system in under 5 minutes. Works anywhere — before exams, in conflicts, when overwhelmed.',
    category: 'Anxiety',
    type: 'exercise',
    emoji: '🫁',
    readTime: '4 min',
    isHot: true,
    isFeatured: true,
    colorValue: 0xFF00BEB4,
    xp: 10,
    sections: [
      ContentSection(
        body: 'Box breathing activates the parasympathetic nervous system — the rest-and-digest state — directly counteracting the fight-or-flight response. Used by Navy SEALs, surgeons, and athletes before high-pressure moments.',
      ),
    ],
    steps: [
      ExerciseStep(
        title: 'Get Comfortable',
        instruction: 'Sit upright or lie down. Place one hand on your chest. Close your eyes or soften your gaze downward. We\'ll do 4 rounds — about 4 minutes total.',
      ),
      ExerciseStep(
        title: 'Inhale',
        instruction: 'Breathe in slowly through your nose. Count 1... 2... 3... 4. Feel your chest and belly expand. Keep your shoulders relaxed.',
        durationSeconds: 4,
      ),
      ExerciseStep(
        title: 'Hold',
        instruction: 'Hold your breath gently. Count 1... 2... 3... 4. Don\'t tense — just pause. Your mind may wander; gently bring it back to the count.',
        durationSeconds: 4,
      ),
      ExerciseStep(
        title: 'Exhale',
        instruction: 'Breathe out slowly through your mouth. Count 1... 2... 3... 4. Let your body soften with each exhale. Release any tension in your jaw and shoulders.',
        durationSeconds: 4,
      ),
      ExerciseStep(
        title: 'Hold Empty',
        instruction: 'Hold with empty lungs. Count 1... 2... 3... 4. Stay relaxed. Notice the stillness. This completes one round.',
        durationSeconds: 4,
      ),
      ExerciseStep(
        title: 'Complete 4 Rounds',
        instruction: 'Repeat the cycle 3 more times. Inhale 4 → Hold 4 → Exhale 4 → Hold 4. Your heart rate should feel steadier by the third round.',
      ),
      ExerciseStep(
        title: 'Come Back',
        instruction: 'Take a natural breath. Open your eyes slowly. Notice how you feel — calmer, more grounded. You can return to this technique anytime, anywhere.',
      ),
    ],
  ),

  ResourceItem(
    id: 'grounding_54321',
    title: '5-4-3-2-1 Grounding Exercise',
    subtitle: 'Bring yourself back to the present moment in minutes',
    description: 'An evidence-based grounding technique for anxiety, panic, and dissociation — anchors you to the present.',
    category: 'Anxiety',
    type: 'exercise',
    emoji: '🌿',
    readTime: '5 min',
    colorValue: 0xFF10B981,
    xp: 10,
    sections: [
      ContentSection(
        body: 'This technique works by engaging your senses to interrupt an anxiety spiral and bring your attention back to the present moment. It\'s especially effective during panic attacks, intrusive thoughts, and moments of overwhelm.',
      ),
    ],
    steps: [
      ExerciseStep(
        title: 'Take a breath',
        instruction: 'Before we begin, take one slow breath in and out. Let your eyes softly scan your surroundings. This exercise will engage your five senses to ground you firmly in the present.',
      ),
      ExerciseStep(
        title: '5 Things You Can SEE',
        instruction: 'Look around and name 5 things you can see right now. A wall, a phone, a tree outside, your hands, the colour of the floor. Say them aloud or in your mind. Take your time — really look.',
      ),
      ExerciseStep(
        title: '4 Things You Can TOUCH',
        instruction: 'Notice 4 things you can physically feel. The texture of your clothes, the temperature of the air, your feet on the ground, the weight of your body in the chair. Touch each one intentionally.',
      ),
      ExerciseStep(
        title: '3 Things You Can HEAR',
        instruction: 'Close your eyes and listen. Name 3 sounds — distant traffic, your own breathing, birds, AC hum, voices. Don\'t judge the sounds, just observe them with curiosity.',
      ),
      ExerciseStep(
        title: '2 Things You Can SMELL',
        instruction: 'Identify 2 smells — or breathe in and notice whatever subtle scent is there. Fresh air, fabric, food, your skin. If you can\'t smell anything, that\'s fine too — just notice.',
      ),
      ExerciseStep(
        title: '1 Thing You Can TASTE',
        instruction: 'Notice 1 thing you can taste — even if it\'s just the faint taste of water or nothing at all. This final sense brings you fully back to your body, right here, right now.',
      ),
      ExerciseStep(
        title: 'Return',
        instruction: 'Take three slow breaths. Notice your feet on the ground. You are here. You are safe. The anxiety wave has passed. You can repeat this exercise anytime you feel pulled out of the present.',
      ),
    ],
  ),

  ResourceItem(
    id: 'cbt_thought_record',
    title: 'CBT Thought Record',
    subtitle: 'Identify and reframe negative thought patterns',
    description: 'An interactive CBT exercise to challenge automatic negative thoughts — great for exam anxiety and self-doubt.',
    category: 'Anxiety',
    type: 'exercise',
    emoji: '🧠',
    readTime: '15 min',
    colorValue: 0xFF8B5CF6,
    xp: 25,
    sections: [
      ContentSection(
        body: 'Cognitive Behavioural Therapy (CBT) is one of the most well-researched mental health interventions. The thought record helps you identify automatic negative thoughts, examine the evidence, and develop more balanced thinking.',
      ),
    ],
    steps: [
      ExerciseStep(
        title: 'The Situation',
        instruction: 'Describe the situation that triggered your distress. Be specific and factual — just the facts, no interpretation yet. Example: "I got my CAT results back and scored 11/20."',
      ),
      ExerciseStep(
        title: 'Automatic Thought',
        instruction: 'What was the first thought that went through your mind? Don\'t filter — write the raw thought. Example: "I\'m going to fail this unit. I\'m not smart enough for this course."',
      ),
      ExerciseStep(
        title: 'Emotions & Intensity',
        instruction: 'What emotions did that thought trigger? Rate the intensity from 0–10. Example: Shame (8/10), Anxiety (7/10), Hopelessness (6/10). Naming emotions precisely reduces their power over you.',
      ),
      ExerciseStep(
        title: 'Evidence FOR the Thought',
        instruction: 'What real evidence supports the automatic thought? Be honest but specific. Example: "I did score below average. I didn\'t study the last two topics thoroughly."',
      ),
      ExerciseStep(
        title: 'Evidence AGAINST the Thought',
        instruction: 'What evidence contradicts the thought? Example: "I passed all previous CATs. I understand most of the material. One result doesn\'t define my capability. Others also found this CAT hard."',
      ),
      ExerciseStep(
        title: 'Balanced Thought',
        instruction: 'Write a more balanced, realistic thought that takes all the evidence into account. Example: "This result was disappointing, but it reflects one difficult test, not my overall intelligence. I can review this material and do better next time."',
      ),
      ExerciseStep(
        title: 'Re-rate Your Emotions',
        instruction: 'How do you feel now, after examining the evidence? Re-rate those same emotions. Most people find the intensity drops by 2–4 points just from going through this process. That\'s the power of challenging your thoughts.',
      ),
    ],
  ),

  ResourceItem(
    id: 'body_scan',
    title: 'Body Scan for Sleep',
    subtitle: 'Release tension and ease into restful sleep',
    description: 'A progressive muscle relaxation guide to release physical tension and prepare your body for deep sleep.',
    category: 'Sleep',
    type: 'exercise',
    emoji: '🌙',
    readTime: '10 min',
    colorValue: 0xFF6366F1,
    xp: 15,
    sections: [
      ContentSection(
        body: 'Progressive muscle relaxation and body scan meditation reduce physiological arousal — the muscle tension, racing thoughts, and heightened alertness that prevent sleep. This exercise works best lying in bed with your eyes closed.',
      ),
    ],
    steps: [
      ExerciseStep(
        title: 'Settle In',
        instruction: 'Lie down in bed. Let your arms rest at your sides, palms facing up. Close your eyes. Take 3 slow breaths — in through the nose, out through the mouth. Release any effort to control what happens next.',
        durationSeconds: 30,
      ),
      ExerciseStep(
        title: 'Feet & Toes',
        instruction: 'Bring your attention to your feet. Curl your toes tightly for 5 seconds, then release. Feel the warmth and relaxation spread through your feet. Let them sink heavy into the mattress.',
        durationSeconds: 20,
      ),
      ExerciseStep(
        title: 'Calves & Shins',
        instruction: 'Move your awareness up to your calves. Flex them gently, hold 5 seconds, then release. Notice the contrast between tension and release. Your legs are getting heavier.',
        durationSeconds: 20,
      ),
      ExerciseStep(
        title: 'Thighs & Hips',
        instruction: 'Squeeze the muscles in your thighs. Hold for 5 seconds, then let go completely. Your lower body is now soft and heavy. You don\'t need to hold yourself up — the bed supports you fully.',
        durationSeconds: 20,
      ),
      ExerciseStep(
        title: 'Stomach & Back',
        instruction: 'Take a breath into your belly. Hold it, tightening your core gently. Then release, letting your stomach soften completely. Your back sinks into the mattress. Nowhere to go. Nothing to do.',
        durationSeconds: 20,
      ),
      ExerciseStep(
        title: 'Shoulders & Arms',
        instruction: 'Lift your shoulders toward your ears, tense them for 5 seconds — then let them drop. Feel the release. Let your arms become so heavy they feel like they\'re sinking through the bed.',
        durationSeconds: 20,
      ),
      ExerciseStep(
        title: 'Face & Jaw',
        instruction: 'Clench your jaw lightly, scrunch your face. Hold 5 seconds, then soften. Let your jaw drop slightly. Unclench your teeth. Relax the muscles around your eyes. Let your whole face go slack.',
        durationSeconds: 20,
      ),
      ExerciseStep(
        title: 'Whole Body',
        instruction: 'Now notice your whole body — heavy, warm, and completely supported. Your mind may still move. That\'s okay. Each thought, just let it pass like a cloud. You are safe. You can sleep now.',
      ),
    ],
  ),

  // ── Crisis Resource ───────────────────────────────────────

  ResourceItem(
    id: 'crisis_now',
    title: 'Crisis: What to Do Right Now',
    subtitle: 'Kenyan helplines, campus resources, and immediate steps',
    description: 'Step-by-step guidance for a mental health crisis — Kenyan crisis lines, campus resources, and immediate coping steps.',
    category: 'Crisis',
    type: 'crisis',
    emoji: '🆘',
    readTime: '5 min',
    colorValue: 0xFFEF4444,
    xp: 0,
    sections: [
      ContentSection(
        heading: 'You Are Not Alone',
        body: 'If you are in crisis right now — feeling suicidal, overwhelmed to the point of not being able to function, or unsafe — please reach out immediately. Crisis is a temporary state, even when it doesn\'t feel like it. You do not have to manage this alone.',
      ),
      ContentSection(
        heading: 'Immediate Safety Steps',
        body: '1. If you are in immediate danger, call 999 or go to the nearest hospital A&E. 2. Put distance between yourself and any means of self-harm. 3. Call someone — a friend, family member, or the helplines below. 4. Stay on the phone with them until you feel safer.',
      ),
      ContentSection(
        heading: 'Your Campus Counseling Unit',
        body: 'Most campus counseling units have a crisis walk-in facility. You do not need an appointment. Tell the receptionist it\'s urgent. The counsellor will see you. If the office is closed, go to the campus clinic or health center.',
      ),
    ],
    hotlines: [
      Hotline(
        name: 'Befrienders Kenya',
        number: '0800 723 253',
        hours: '24/7, Free',
        note: 'Emotional support and crisis intervention',
      ),
      Hotline(
        name: 'Niskize Helpline',
        number: '0900 620 800',
        hours: 'Mon–Fri, 8am–8pm',
        note: 'Mental health support in English and Swahili',
      ),
      Hotline(
        name: 'Kenya Red Cross',
        number: '1199',
        hours: '24/7',
        note: 'Psychosocial support and emergency referrals',
      ),
      Hotline(
        name: 'Amani Counselling Centre',
        number: '+254 722 178 177',
        hours: 'Mon–Fri, 9am–5pm',
        note: 'Professional counselling and crisis support',
      ),
    ],
  ),
];

// ─── Category metadata ────────────────────────────────────

class CategoryMeta {
  final String name;
  final int colorValue;
  final String emoji;
  const CategoryMeta({required this.name, required this.colorValue, required this.emoji});
}

const kCategoryMeta = <String, CategoryMeta>{
  'All':         CategoryMeta(name: 'All',          colorValue: 0xFF00BEB4, emoji: '🌟'),
  'Anxiety':     CategoryMeta(name: 'Anxiety',      colorValue: 0xFF8B5CF6, emoji: '😰'),
  'Stress':      CategoryMeta(name: 'Stress',       colorValue: 0xFFF59E0B, emoji: '😤'),
  'Depression':  CategoryMeta(name: 'Depression',   colorValue: 0xFF3B82F6, emoji: '💙'),
  'Sleep':       CategoryMeta(name: 'Sleep',        colorValue: 0xFF6366F1, emoji: '😴'),
  'Relationships': CategoryMeta(name: 'Relationships', colorValue: 0xFFEC4899, emoji: '❤️'),
  'Self-Esteem': CategoryMeta(name: 'Self-Esteem',  colorValue: 0xFF8B5CF6, emoji: '💪'),
  'Finance':     CategoryMeta(name: 'Finance',      colorValue: 0xFFF59E0B, emoji: '💸'),
  'Campus Life': CategoryMeta(name: 'Campus Life',  colorValue: 0xFF10B981, emoji: '🏫'),
  'Crisis':      CategoryMeta(name: 'Crisis',       colorValue: 0xFFEF4444, emoji: '🆘'),
};

const kCategories = [
  'All', 'Anxiety', 'Stress', 'Depression', 'Sleep',
  'Relationships', 'Self-Esteem', 'Finance', 'Campus Life', 'Crisis',
];
