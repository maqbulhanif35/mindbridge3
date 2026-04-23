import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/mood_model.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../core/providers/streak_provider.dart';

// ─── Writing Mode ─────────────────────────────────────────────────────────────
enum _WritingMode {
  freeWrite,
  gratitude,
  vent;

  String get label {
    switch (this) {
      case _WritingMode.freeWrite:
        return '✍️ Free Write';
      case _WritingMode.gratitude:
        return '🙏 Gratitude';
      case _WritingMode.vent:
        return '💭 Vent';
    }
  }

  String get hint {
    switch (this) {
      case _WritingMode.freeWrite:
        return 'Write freely — this is your safe space...';
      case _WritingMode.gratitude:
        return "What are 3 things you're grateful for today?";
      case _WritingMode.vent:
        return 'Let it out. This space is only for you.';
    }
  }
}

// ─── Mood Bucket (5 emoji groups mapping to 1-10) ────────────────────────────
class _MoodBucket {
  final String emoji;
  final String label;
  final int minScore;
  final int maxScore;
  final Color color;

  const _MoodBucket({
    required this.emoji,
    required this.label,
    required this.minScore,
    required this.maxScore,
    required this.color,
  });

  int get midScore => ((minScore + maxScore) / 2).round();
}

const List<_MoodBucket> _moodBuckets = [
  _MoodBucket(
    emoji: '😢',
    label: 'Awful',
    minScore: 1,
    maxScore: 2,
    color: Color(0xFFFF4757),
  ),
  _MoodBucket(
    emoji: '😔',
    label: 'Low',
    minScore: 3,
    maxScore: 4,
    color: Color(0xFFFF8C42),
  ),
  _MoodBucket(
    emoji: '😐',
    label: 'Okay',
    minScore: 5,
    maxScore: 6,
    color: Color(0xFFFFD166),
  ),
  _MoodBucket(
    emoji: '🙂',
    label: 'Good',
    minScore: 7,
    maxScore: 8,
    color: Color(0xFF56CC99),
  ),
  _MoodBucket(
    emoji: '😊',
    label: 'Great',
    minScore: 9,
    maxScore: 10,
    color: Color(0xFF00BEB4),
  ),
];

// ─── Emotion Keyword Detection ───────────────────────────────────────────────
const List<String> _joyKeywords = [
  'happy', 'joy', 'grateful', 'excited', 'love', 'wonderful', 'amazing',
];
const List<String> _anxietyKeywords = [
  'anxious', 'worried', 'stress', 'nervous', 'afraid', 'fear', 'panic',
];
const List<String> _sadnessKeywords = [
  'sad', 'lonely', 'empty', 'hopeless', 'cry', 'miss', 'loss', 'hurt',
];
const List<String> _angerKeywords = [
  'angry', 'frustrated', 'annoyed', 'upset', 'mad', 'hate',
];

class _DetectedEmotion {
  final String label;
  final Color color;
  const _DetectedEmotion(this.label, this.color);
}

List<_DetectedEmotion> _detectEmotions(String text) {
  final lower = text.toLowerCase();
  final result = <_DetectedEmotion>[];
  if (_joyKeywords.any((k) => lower.contains(k))) {
    result.add(const _DetectedEmotion('Joy', Color(0xFF10B981)));
  }
  if (_anxietyKeywords.any((k) => lower.contains(k))) {
    result.add(const _DetectedEmotion('Anxiety', Color(0xFFF59E0B)));
  }
  if (_sadnessKeywords.any((k) => lower.contains(k))) {
    result.add(const _DetectedEmotion('Sadness', Color(0xFF0EA5E9)));
  }
  if (_angerKeywords.any((k) => lower.contains(k))) {
    result.add(const _DetectedEmotion('Anger', Color(0xFFFF6B6B)));
  }
  return result;
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class JournalEntryScreen extends ConsumerStatefulWidget {
  final JournalEntry? existingEntry;
  const JournalEntryScreen({super.key, this.existingEntry});

  @override
  ConsumerState<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends ConsumerState<JournalEntryScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  int? _selectedMood;
  List<String> _tags = [];
  bool _isPrivate = true;
  String? _aiInsight;
  bool _loadingInsight = false;
  bool _saved = false;
  int _wordCount = 0;
  _WritingMode _writingMode = _WritingMode.freeWrite;

  final TextEditingController _tagCtrl = TextEditingController();
  String? _savedEntryId;

  static const List<String> _suggestedTags = [
    'anxiety',
    'relationships',
    'work',
    'sleep',
    'growth',
    'family',
    'goals',
    'stress',
    'grateful',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existingEntry;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _contentCtrl = TextEditingController(text: e?.content ?? '');
    _selectedMood = e?.moodScore;
    _tags = List.from(e?.tags ?? []);
    _isPrivate = e?.isPrivate ?? true;
    _aiInsight = e?.aiInsight;
    _savedEntryId = e?.id;
    _wordCount = _countWords(e?.content ?? '');
    _contentCtrl.addListener(() {
      setState(() => _wordCount = _countWords(_contentCtrl.text));
    });
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  // ─── Logic (unchanged) ───────────────────────────────────────────────────

  Future<void> _save() async {
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something first')),
      );
      return;
    }

    final success = await ref.read(moodProvider.notifier).createJournalEntry(
          title: _titleCtrl.text.isEmpty ? null : _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          moodScore: _selectedMood,
          tags: _tags,
        );

    if (success) {
      setState(() => _saved = true);
      final entries = ref.read(moodProvider).journalEntries;
      if (entries.isNotEmpty) {
        _savedEntryId = entries.first.id;
      }
      ref
          .read(streakProvider.notifier)
          .recordActivity(StreakType.journalWriting);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journal entry saved! ✓'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _getAIInsight() async {
    if (_savedEntryId == null) {
      await _save();
    }
    if (_savedEntryId == null) return;

    setState(() => _loadingInsight = true);
    final insight =
        await ref.read(moodProvider.notifier).getJournalInsight(_savedEntryId!);
    setState(() {
      _aiInsight = insight ?? 'Unable to generate insight at this time.';
      _loadingInsight = false;
    });
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 5) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  void _toggleSuggestedTag(String tag) {
    setState(() {
      if (_tags.contains(tag)) {
        _tags.remove(tag);
      } else if (_tags.length < 5) {
        _tags.add(tag);
      }
    });
  }

  // ─── Derived helpers ─────────────────────────────────────────────────────

  Color get _moodDividerColor {
    if (_selectedMood == null) return const Color(0xFFDDD5C8);
    final idx = (_selectedMood! - 1).clamp(0, 9);
    return AppColors.moodColors[idx];
  }

  int? get _selectedBucketIndex {
    if (_selectedMood == null) return null;
    for (int i = 0; i < _moodBuckets.length; i++) {
      if (_selectedMood! >= _moodBuckets[i].minScore &&
          _selectedMood! <= _moodBuckets[i].maxScore) {
        return i;
      }
    }
    return null;
  }

  Color get _progressBarColor {
    if (_wordCount >= 100) return const Color(0xFF10B981);
    if (_wordCount >= 70) return AppColors.primary;
    if (_wordCount >= 30) return const Color(0xFFF59E0B);
    return const Color(0xFFE2E8F0);
  }

  String get _progressLabel {
    if (_wordCount >= 100) return 'Deep reflection! ✓';
    if (_wordCount >= 70) return 'Almost there!';
    if (_wordCount >= 30) return 'Building momentum...';
    return 'Keep writing...';
  }

  double get _progressValue => (_wordCount / 100).clamp(0.0, 1.0);

  String get _insightBadge {
    if (_aiInsight == null) return '';
    final lower = _aiInsight!.toLowerCase();
    if (lower.contains('pattern')) return '🧠 Pattern';
    if (lower.contains('suggest') || lower.contains('try')) return '💡 Tip';
    return '❤️ Reflection';
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final moodState = ref.watch(moodProvider);
    final safeArea = MediaQuery.of(context).padding.bottom;
    final bucketIdx = _selectedBucketIndex;

    // suppress unused import warning — AppStrings.moodEmojis used indirectly
    // via _moodBuckets emoji literals; keep import for AppStrings elsewhere.
    assert(AppStrings.moodEmojis.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: _buildAppBar(),
      bottomNavigationBar: _buildBottomBar(moodState, safeArea),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Paper Container ─────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF5),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPaperHeader(),
                  _buildWritingModeSelector(),
                  const SizedBox(height: 16),

                  // Mood selector
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How are you feeling?',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B7355),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildMoodSelector(bucketIdx),
                        if (bucketIdx != null) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              _moodBuckets[bucketIdx].label,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _moodBuckets[bucketIdx].color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (_selectedMood != null) ...[
                    const SizedBox(height: 12),
                    _buildMoodPromptCard(),
                  ],

                  const SizedBox(height: 20),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D2D2D),
                      ),
                      decoration: const InputDecoration(
                        hintText: "What's on your mind?",
                        hintStyle: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFCCBFA8),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  // Mood-tinted divider
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 1.5,
                      decoration: BoxDecoration(
                        color: _moodDividerColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      minLines: 8,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        color: Color(0xFF3D3D3D),
                        height: 1.8,
                      ),
                      decoration: InputDecoration(
                        hintText: _writingMode.hint,
                        hintStyle: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          color: Color(0xFFCCBFA8),
                          height: 1.8,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildWritingGoal(),
                  ),

                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildEmotionDetector(),
                  ),

                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildTagsSection(),
                  ),

                  if (_aiInsight != null) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildAIInsightCard(),
                    ),
                  ],

                  const SizedBox(height: 28),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SizedBox(height: 100),
          ],

        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'My Journal',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: [
            if (_wordCount > 0)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🔥 ${_wordCount}w',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(
                _isPrivate ? LucideIcons.lock : LucideIcons.lockOpen,
                size: 18,
                color: Colors.white,
              ),
              tooltip: _isPrivate ? 'Private' : 'Not Private',
              onPressed: () => setState(() => _isPrivate = !_isPrivate),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Paper Header ─────────────────────────────────────────────────────────

  Widget _buildPaperHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          const Icon(LucideIcons.calendarDays,
              size: 14, color: Color(0xFFAA9977)),
          const SizedBox(width: 6),
          Text(
            DateFormat('EEEE, MMMM d').format(DateTime.now()),
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              color: Color(0xFFAA9977),
            ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isPrivate
                  ? const Color(0xFFE0F8F7)
                  : const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPrivate ? LucideIcons.lock : LucideIcons.globe,
                  size: 11,
                  color:
                      _isPrivate ? AppColors.primary : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  _isPrivate ? 'Private' : 'Public',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        _isPrivate ? AppColors.primary : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Writing Mode Selector ────────────────────────────────────────────────

  Widget _buildWritingModeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: _WritingMode.values.map((mode) {
          final selected = _writingMode == mode;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _writingMode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : const Color(0xFFF0EDE6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFDDD5C8),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  mode.label,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? Colors.white : const Color(0xFF8B7355),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Mood Selector ────────────────────────────────────────────────────────

  Widget _buildMoodSelector(int? bucketIdx) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_moodBuckets.length, (i) {
        final bucket = _moodBuckets[i];
        final isSelected = bucketIdx == i;
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedMood = null;
              } else {
                _selectedMood = bucket.midScore;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? bucket.color.withValues(alpha: 0.12)
                  : const Color(0xFFF5F0E8),
              border: Border.all(
                color:
                    isSelected ? bucket.color : const Color(0xFFDDD5C8),
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: bucket.color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : const [],
            ),
            child: Center(
              child: Text(
                bucket.emoji,
                style: TextStyle(fontSize: isSelected ? 26 : 22),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─── Mood Prompt Card ─────────────────────────────────────────────────────

  Widget _buildMoodPromptCard() {
    if (_selectedMood == null) return const SizedBox.shrink();
    final isLow = _selectedMood! <= 4;
    final isHigh = _selectedMood! >= 8;
    if (!isLow && !isHigh) return const SizedBox.shrink();

    final bg =
        isLow ? const Color(0xFFFFF0F0) : const Color(0xFFF0FFF4);
    final textColor =
        isLow ? const Color(0xFFCC4444) : const Color(0xFF10B981);
    final promptText = isLow
        ? "It's okay to not be okay. Writing it out can help. 💙"
        : 'Wonderful! What made today feel great? 🌟';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: textColor.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          children: [
            Icon(
              isLow
                  ? LucideIcons.heartHandshake
                  : LucideIcons.sparkles,
              size: 16,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                promptText,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Writing Goal ─────────────────────────────────────────────────────────

  Widget _buildWritingGoal() {
    final readTime = max(1, (_wordCount / 200).ceil());
    final barColor = _progressBarColor;
    final displayColor = barColor == const Color(0xFFE2E8F0)
        ? const Color(0xFFDDD5C8)
        : barColor;
    final labelColor = barColor == const Color(0xFFE2E8F0)
        ? const Color(0xFFAA9977)
        : barColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.penLine,
                size: 14, color: Color(0xFFAA9977)),
            const SizedBox(width: 6),
            Text(
              '$_wordCount / 100 words',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8B7355),
              ),
            ),
            const Spacer(),
            Text(
              '~${readTime}m read',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: Color(0xFFAA9977),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progressValue,
            minHeight: 5,
            backgroundColor: const Color(0xFFE8E0D0),
            valueColor: AlwaysStoppedAnimation<Color>(displayColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _progressLabel,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ─── Emotion Detector ─────────────────────────────────────────────────────

  Widget _buildEmotionDetector() {
    final emotions = _detectEmotions(_contentCtrl.text);
    final showNeutral = emotions.isEmpty && _wordCount >= 20;
    if (emotions.isEmpty && !showNeutral) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emotional Tone',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFAA9977),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: showNeutral
              ? [_emotionPill('Neutral', const Color(0xFF9CA3AF))]
              : emotions
                  .map((e) => _emotionPill(e.label, e.color))
                  .toList(),
        ),
      ],
    );
  }

  Widget _emotionPill(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ─── Tags Section ─────────────────────────────────────────────────────────

  Widget _buildTagsSection() {
    final customTags =
        _tags.where((t) => !_suggestedTags.contains(t)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFAA9977),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),

        // Predefined suggestions
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _suggestedTags.map((tag) {
            final isSelected = _tags.contains(tag);
            return GestureDetector(
              onTap: () => _toggleSuggestedTag(tag),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : const Color(0xFFF0EDE6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFDDD5C8),
                    width: 1,
                  ),
                ),
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFF8B7355),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 8),

        // Custom tag input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addTag(),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: Color(0xFF3D3D3D),
                ),
                decoration: InputDecoration(
                  hintText: 'Add custom tag...',
                  hintStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: Color(0xFFCCBFA8),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F0E8),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addTag,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.plus,
                    size: 18, color: AppColors.primary),
              ),
            ),
          ],
        ),

        // Custom tags (removable)
        if (customTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: customTags.map((tag) {
                return GestureDetector(
                  onTap: () => setState(() => _tags.remove(tag)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#$tag',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.x,
                            size: 11, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ─── AI Insight Card ──────────────────────────────────────────────────────

  Widget _buildAIInsightCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient strip header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.sparkles,
                    size: 16, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  "Maya's Reflection",
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _insightBadge,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _aiInsight!,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: Color(0xFF3D3D3D),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Save Bar ──────────────────────────────────────────────────────

  Widget _buildBottomBar(MoodState moodState, double safeArea) {
    return Container(
      height: 100,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 20 + safeArea),
      child: Row(
        children: [
          // AI Insight button (outlined)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _loadingInsight ? null : _getAIInsight,
              icon: _loadingInsight
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF6366F1),
                      ),
                    )
                  : const Icon(LucideIcons.sparkles, size: 15),
              label: Text(
                _loadingInsight ? 'Analyzing...' : 'Insight',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                side: const BorderSide(color: Color(0xFF6366F1)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Privacy toggle (circular icon button)
          Container(
            decoration: BoxDecoration(
              color: _isPrivate
                  ? AppColors.primaryContainer
                  : const Color(0xFFFFF8E7),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isPrivate ? LucideIcons.lock : LucideIcons.lockOpen,
                size: 18,
              ),
              color:
                  _isPrivate ? AppColors.primary : AppColors.warning,
              tooltip: _isPrivate ? 'Private' : 'Not Private',
              onPressed: () =>
                  setState(() => _isPrivate = !_isPrivate),
            ),
          ),

          const SizedBox(width: 8),

          // Save Entry button (primary gradient, flex 2)
          Flexible(
            flex: 1,
            child: GestureDetector(
              onTap: moodState.isLoading ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: _saved
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF10B981),
                            Color(0xFF00BEB4),
                          ],
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFF00BEB4),
                            Color(0xFF33CBC2),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: moodState.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _saved ? 'Saved ✓' : 'Save Entry',
                          style: const TextStyle(
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
        ],
      ),
    );
  }
}
