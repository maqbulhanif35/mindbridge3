import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/mood_model.dart';
import '../../../core/providers/mood_provider.dart';
import '../../../shared/widgets/custom_button.dart';

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

  final TextEditingController _tagCtrl = TextEditingController();
  String? _savedEntryId;

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
      // Get the new entry ID (first in list)
      final entries = ref.read(moodProvider).journalEntries;
      if (entries.isNotEmpty) {
        _savedEntryId = entries.first.id;
      }

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

  @override
  Widget build(BuildContext context) {
    final moodState = ref.watch(moodProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingEntry != null ? 'Edit Entry' : 'New Journal Entry',
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPrivate ? LucideIcons.lock : LucideIcons.lockOpen,
              size: 18,
              color: _isPrivate ? AppColors.primary : AppColors.textMuted,
            ),
            tooltip: _isPrivate ? 'Private' : 'Not Private',
            onPressed: () => setState(() => _isPrivate = !_isPrivate),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Date & Privacy Status ──────────────────
            Row(
              children: [
                const Icon(LucideIcons.calendarDays,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isPrivate
                        ? AppColors.primaryContainer
                        : AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPrivate
                            ? LucideIcons.lock
                            : LucideIcons.globe,
                        size: 12,
                        color: _isPrivate
                            ? AppColors.primary
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPrivate ? 'Private' : 'Public',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isPrivate
                              ? AppColors.primary
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(),

            const SizedBox(height: 16),

            // ─── Mood Selector ──────────────────────────
            const Text(
              'How are you feeling?',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                itemBuilder: (_, i) {
                  final score = i + 1;
                  final isSelected = _selectedMood == score;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMood = score),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.moodColors[i].withOpacity(0.15)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.moodColors[i]
                              : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppStrings.moodEmojis[score],
                            style: const TextStyle(fontSize: 20),
                          ),
                          Text(
                            '$score',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 10,
                              color: isSelected
                                  ? AppColors.moodColors[i]
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 20),

            // ─── Title ──────────────────────────────────
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Title (optional)',
                hintStyle: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ).animate().fadeIn(delay: 150.ms),

            // ─── Divider ────────────────────────────────
            const Divider(height: 24),

            // ─── Content ────────────────────────────────
            TextField(
              controller: _contentCtrl,
              maxLines: null,
              minLines: 10,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.7,
              ),
              decoration: const InputDecoration(
                hintText:
                    "What's on your mind? Write freely — this is your safe space.",
                hintStyle: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ).animate().fadeIn(delay: 200.ms),

            // ─── Word Count ─────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$_wordCount ${_wordCount == 1 ? 'word' : 'words'}',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ─── Tags ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addTag(),
                    decoration: InputDecoration(
                      hintText: 'Add tags...',
                      prefixIcon: const Icon(Icons.label_outline, size: 18),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_rounded,
                      color: AppColors.primary),
                  onPressed: _addTag,
                ),
              ],
            ),

            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                    backgroundColor: AppColors.primaryContainer,
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () =>
                        setState(() => _tags.remove(tag)),
                    side: const BorderSide(color: Colors.transparent),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),

            // ─── AI Insight ─────────────────────────────
            if (_aiInsight != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.calmGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('🤖', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text(
                          "Maya's Reflection",
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _aiInsight!,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(),

            const SizedBox(height: 24),

            // ─── Action Buttons ──────────────────────────
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: _loadingInsight ? 'Analyzing...' : '🤖 AI Insight',
                    onTap: _loadingInsight ? null : _getAIInsight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: _saved ? 'Saved ✓' : 'Save Entry',
                    onTap: _save,
                    isLoading: moodState.isLoading,
                    gradient: _saved
                        ? const LinearGradient(
                            colors: [AppColors.success, AppColors.secondary])
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
