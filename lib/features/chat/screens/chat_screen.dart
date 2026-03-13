import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/message_model.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  bool _justListenMode = false;
  bool _showQuickReplies = true;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  List<String> _getQuickReplies(List msgs) {
    if (msgs.isEmpty) {
      return [
        "I'm feeling anxious 😰",
        "I can't sleep 😴",
        "Just want to vent 💬",
        "Stressed about exams 📚",
        "Feeling lonely 💙",
      ];
    }
    // Get last message content for context
    final last = msgs.last;
    final isLastFromUser = last.isFromUser;
    if (isLastFromUser) {
      return [
        "What should I do?",
        "Is this normal?",
        "Let's try an exercise",
        "I need more support",
      ];
    }
    final content = last.content.toLowerCase();
    if (content.contains('breath') || content.contains('exercise') || content.contains('practice')) {
      return ["Try it now", "Not right now", "Tell me more", "That sounds helpful"];
    }
    if (content.contains('journal') || content.contains('write') || content.contains('reflect')) {
      return ["I'll try journaling", "Help me start", "Tell me more", "Not right now"];
    }
    return ["That helps, thanks 💚", "Tell me more", "I need more support", "Let's try something"];
  }

  void _showNavigationSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NavSheet(
        onNavigate: (route) {
          Navigator.pop(context);
          context.push(route);
        },
      ),
    );
  }

  Future<void> _send([String? prefilled]) async {
    final text = (prefilled ?? _ctrl.text).trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _showQuickReplies = false);
    _focus.requestFocus();
    // Prepend listen-mode context if active
    final finalText = _justListenMode
        ? '[Just listen mode - please only validate and reflect, do not give advice] $text'
        : text;
    await ref.read(chatProvider.notifier).sendMessage(finalText);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      if (mounted) setState(() => _showQuickReplies = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    ref.listen(chatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          next.streamingContent != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    final quickReplies = _getQuickReplies(chatState.messages);
    final hasMessages = chatState.messages.isNotEmpty || chatState.streamingContent != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.tokenBackground,
        body: Column(
          children: [
            _ChatHeader(
              streamState: chatState.streamState,
              justListenMode: _justListenMode,
              messageCount: chatState.messages.length,
              onNewChat: () {
                ref.read(chatProvider.notifier).startNewSession();
                setState(() => _showQuickReplies = true);
              },
              onCrisis: () => context.push(AppRoutes.crisis),
              onToggleListenMode: () =>
                  setState(() => _justListenMode = !_justListenMode),
              onNavigate: _showNavigationSheet,
            ),

            // Crisis banner
            if (chatState.crisisDetected)
              _CrisisBanner(
                onDismiss: () =>
                    ref.read(chatProvider.notifier).dismissCrisisAlert(),
                onGetHelp: () => context.push(AppRoutes.crisis),
              ).animate().slideY(begin: -1, end: 0, duration: 300.ms),

            // Messages
            Expanded(
              child: !hasMessages
                  ? _EmptyState(
                      onSuggestionTap: (s) => _send(s),
                    )
                  : _MessageList(
                      chatState: chatState,
                      scrollController: _scroll,
                      onExerciseTap: () =>
                          context.push(AppRoutes.breathing),
                    ),
            ),

            // Error banner
            if (chatState.errorMessage != null)
              _ErrorBanner(
                message: chatState.errorMessage!,
                onDismiss: () =>
                    ref.read(chatProvider.notifier).clearError(),
              ),

            // Just-listen mode banner
            if (_justListenMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: AppColors.primaryContainer,
                child: Row(
                  children: [
                    const Icon(LucideIcons.ear, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Just listening mode — Maya will only validate, not advise',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _justListenMode = false),
                      child: const Icon(LucideIcons.x, size: 14, color: AppColors.primary),
                    ),
                  ],
                ),
              ),

            // Quick reply chips (when not loading and has context)
            if (_showQuickReplies && !chatState.isMayaResponding)
              _QuickReplyChips(
                replies: quickReplies,
                onTap: (reply) => _send(reply),
              ).animate().fadeIn(duration: 200.ms),

            // Input
            _ChatInput(
              controller: _ctrl,
              focusNode: _focus,
              onSend: () => _send(),
              isLoading: chatState.isMayaResponding,
              justListenMode: _justListenMode,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chat Header ──────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final MayaStreamState streamState;
  final bool justListenMode;
  final int messageCount;
  final VoidCallback onNewChat;
  final VoidCallback onCrisis;
  final VoidCallback onToggleListenMode;
  final VoidCallback onNavigate;

  const _ChatHeader({
    required this.streamState,
    required this.justListenMode,
    required this.messageCount,
    required this.onNewChat,
    required this.onCrisis,
    required this.onToggleListenMode,
    required this.onNavigate,
  });

  String get _statusText => switch (streamState) {
        MayaStreamState.thinking => 'Thinking...',
        MayaStreamState.streaming => 'Responding...',
        MayaStreamState.idle => 'Here for you',
      };

  Color get _statusColor => switch (streamState) {
        MayaStreamState.thinking => const Color(0xFFFFD166),
        MayaStreamState.streaming => const Color(0xFF4ECDC4),
        MayaStreamState.idle => const Color(0xFF06D6A0),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF0EA5E9)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.md, Spacing.xs, Spacing.sm, Spacing.md),
          child: Row(
            children: [
              // Maya avatar
              Stack(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4ECDC4), AppColors.primary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(LucideIcons.bot,
                          size: 24, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: 300.ms,
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: Spacing.sm),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Maya',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: 300.ms,
                      child: Row(
                        key: ValueKey(streamState),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (streamState != MayaStreamState.idle)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor:
                                      AlwaysStoppedAnimation(_statusColor),
                                ),
                              ),
                            ),
                          Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: _statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              _HeaderBtn(
                icon: LucideIcons.layoutGrid,
                onTap: onNavigate,
                tooltip: 'Navigate',
              ),
              const SizedBox(width: Spacing.xs),
              _HeaderBtn(
                icon: justListenMode ? LucideIcons.ear : LucideIcons.earOff,
                onTap: onToggleListenMode,
                tooltip: justListenMode ? 'Exit listen mode' : 'Just listen mode',
                color: justListenMode ? const Color(0xFFFFD166) : Colors.white,
              ),
              const SizedBox(width: Spacing.xs),
              _HeaderBtn(
                icon: LucideIcons.squarePen,
                onTap: onNewChat,
                tooltip: 'New Chat',
              ),
              const SizedBox(width: Spacing.xs),
              _HeaderBtn(
                icon: LucideIcons.phoneCall,
                onTap: onCrisis,
                tooltip: 'Crisis Support',
                color: const Color(0xFFFF8A80),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;

  const _HeaderBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: AppRadius.smAll,
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

// ─── Message List ─────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final ChatState chatState;
  final ScrollController scrollController;
  final VoidCallback onExerciseTap;

  const _MessageList({
    required this.chatState,
    required this.scrollController,
    required this.onExerciseTap,
  });

  @override
  Widget build(BuildContext context) {
    final messages = chatState.messages;
    final streamingContent = chatState.streamingContent;
    final isThinking = chatState.streamState == MayaStreamState.thinking;

    // Total items: messages + (streaming bubble or thinking indicator)
    final showStreamingBubble = streamingContent != null;
    final showThinkingBubble =
        isThinking && !showStreamingBubble;

    final extraItems =
        (showStreamingBubble || showThinkingBubble) ? 1 : 0;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.md),
      itemCount: messages.length + extraItems,
      itemBuilder: (_, i) {
        if (i == messages.length) {
          if (showStreamingBubble) {
            return _StreamingBubble(content: streamingContent);
          }
          if (showThinkingBubble) {
            return const _ThinkingIndicator();
          }
        }
        final msg = messages[i];
        return _MessageBubble(
          message: msg,
          isFirstInGroup: i == 0 || messages[i - 1].role != msg.role,
          isLast: i == messages.length - 1,
          onExerciseTap: onExerciseTap,
        );
      },
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isFirstInGroup;
  final bool isLast;
  final VoidCallback onExerciseTap;

  const _MessageBubble({
    required this.message,
    required this.isFirstInGroup,
    this.isLast = false,
    required this.onExerciseTap,
  });

  bool get _suggestsExercise {
    final c = message.content.toLowerCase();
    return !message.isFromUser &&
        (c.contains('breath') || c.contains('box breathing') ||
            c.contains('4-7-8') || c.contains('mindful') ||
            c.contains('try this exercise') || c.contains('calming technique'));
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? Spacing.sm : 3,
        left: isUser ? 64 : 0,
        right: isUser ? 0 : 64,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isFirstInGroup && !isUser)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4ECDC4), AppColors.primary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.bot,
                        size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    'Maya',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.tokenTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              Clipboard.setData(ClipboardData(text: message.content));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Copied to clipboard'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      )
                    : null,
                color: isUser ? null : context.tokenSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                border: isUser
                    ? null
                    : Border.all(color: context.tokenBorder),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? AppColors.primary.withOpacity(0.2)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 15,
                  color: isUser ? Colors.white : context.tokenTextPrimary,
                  height: 1.5,
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 250.ms)
              .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),

          // Inline exercise card
          if (_suggestsExercise)
            _InlineExerciseCard(onTap: onExerciseTap)
                .animate()
                .fadeIn(delay: 300.ms)
                .slideY(begin: 0.2),
        ],
      ),
    );
  }
}

// ─── Inline Exercise Card ─────────────────────────────────

class _InlineExerciseCard extends StatelessWidget {
  final VoidCallback onTap;
  const _InlineExerciseCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8, right: 64),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF009E95), Color(0xFF00BEB4)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('🌬️', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Try a breathing exercise',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '4-7-8 breathing · 2 min',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Start →',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Streaming Bubble ─────────────────────────────────────

class _StreamingBubble extends StatelessWidget {
  final String content;
  const _StreamingBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          top: Spacing.sm, right: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4ECDC4), AppColors.primary],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.bot,
                      size: 14, color: Colors.white),
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  'Maya',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.tokenTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm),
            decoration: BoxDecoration(
              color: context.tokenSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: context.tokenBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.tokenTextPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Cursor blink
                Container(
                  width: 2,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .fadeIn(duration: 500.ms)
                    .then()
                    .fadeOut(duration: 500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Thinking Indicator ───────────────────────────────────

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm, right: 64),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4ECDC4), AppColors.primary],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.bot, size: 14, color: Colors.white),
          ),
          const SizedBox(width: Spacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm),
            decoration: BoxDecoration(
              color: context.tokenSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: context.tokenBorder),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i * 0.33;
                  final progress =
                      (_ctrl.value - delay).clamp(0.0, 1.0);
                  final opacity = (progress < 0.5
                          ? progress * 2
                          : (1 - progress) * 2)
                      .clamp(0.3, 1.0);
                  return Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(opacity),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ─── Empty State ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onSuggestionTap;
  const _EmptyState({required this.onSuggestionTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        children: [
          const SizedBox(height: Spacing.xl),

          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4ECDC4), AppColors.primary],
              ),
              shape: BoxShape.circle,
              boxShadow: AppShadow.coloredMd(AppColors.primary),
            ),
            child: const Icon(LucideIcons.bot,
                size: 50, color: Colors.white),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: Spacing.lg),

          Text(
            "Hi, I'm Maya 👋",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: context.tokenTextPrimary,
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: Spacing.xs),

          Text(
            "I'm your AI wellness companion. Share what's on your mind — I'll listen without judgment.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: context.tokenTextSecondary,
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: Spacing.xl),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Try asking...",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.tokenTextMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: Spacing.sm),

          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: AppStrings.chatSuggestions.map((s) {
              return GestureDetector(
                onTap: () => onSuggestionTap(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: AppRadius.pillAll,
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }
}

// ─── Quick Reply Chips ────────────────────────────────────

class _QuickReplyChips extends StatelessWidget {
  final List<String> replies;
  final ValueChanged<String> onTap;

  const _QuickReplyChips({required this.replies, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.tokenSurface,
        border: Border(top: BorderSide(color: context.tokenBorder)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: replies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap(replies[i]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              child: Text(
                replies[i],
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Chat Input ───────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isLoading;
  final bool justListenMode;

  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isLoading,
    this.justListenMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tokenSurface,
        border: Border(
          top: BorderSide(color: context.tokenBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.md, Spacing.sm, Spacing.md, Spacing.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: justListenMode
                        ? 'Share freely — Maya will just listen...'
                        : AppStrings.chatPlaceholder,
                    hintStyle: TextStyle(
                      color: context.tokenTextMuted,
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: context.tokenBackground,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.pillAll,
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.sm),
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    color: context.tokenTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              AnimatedContainer(
                duration: 200.ms,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: isLoading
                      ? null
                      : const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                  color: isLoading ? context.tokenBorder : null,
                  shape: BoxShape.circle,
                  boxShadow: isLoading
                      ? null
                      : AppShadow.coloredMd(AppColors.primary),
                ),
                child: IconButton(
                  icon: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                context.tokenTextMuted),
                          ),
                        )
                      : const Icon(LucideIcons.send,
                          color: Colors.white, size: 20),
                  onPressed: isLoading ? null : onSend,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          Spacing.md, 0, Spacing.md, Spacing.xs),
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.circleAlert,
              color: AppColors.error, size: 18),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 16),
            onPressed: onDismiss,
            color: AppColors.error,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─── Crisis Banner ────────────────────────────────────────

class _CrisisBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onGetHelp;

  const _CrisisBanner({
    required this.onDismiss,
    required this.onGetHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          Spacing.md, Spacing.sm, Spacing.md, 0),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.07),
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: AppColors.error.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.heart,
                  color: AppColors.error, size: 20),
              const SizedBox(width: Spacing.xs),
              const Text(
                'We care about you',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(LucideIcons.x,
                    size: 18, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            "If you're in crisis, please reach out to a professional. You don't have to face this alone.",
            style: TextStyle(
              fontSize: 13,
              color: context.tokenTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onGetHelp,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: Spacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: AppRadius.lgAll,
                    ),
                    child: const Center(
                      child: Text(
                        'Get Immediate Help',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                '📞 988',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Navigation Sheet ─────────────────────────────────────

class _NavSheet extends StatelessWidget {
  final ValueChanged<String> onNavigate;
  const _NavSheet({required this.onNavigate});

  static const _destinations = [
    _NavDest(icon: LucideIcons.house, label: 'Home', route: AppRoutes.home, color: AppColors.primary),
    _NavDest(icon: LucideIcons.heart, label: 'Mood Check-in', route: AppRoutes.moodTracker, color: Color(0xFFFF6B6B)),
    _NavDest(icon: LucideIcons.chartBar, label: 'Mood Analytics', route: AppRoutes.moodAnalytics, color: Color(0xFF0EA5E9)),
    _NavDest(icon: LucideIcons.bookOpen, label: 'Journal', route: AppRoutes.journal, color: Color(0xFFF59E0B)),
    _NavDest(icon: LucideIcons.wind, label: 'Mindfulness', route: AppRoutes.mindfulness, color: Color(0xFF10B981)),
    _NavDest(icon: LucideIcons.activity, label: 'Wellness Hub', route: AppRoutes.wellness, color: Color(0xFF06D6A0)),
    _NavDest(icon: LucideIcons.library, label: 'Resources', route: AppRoutes.resources, color: Color(0xFFF59E0B)),
    _NavDest(icon: LucideIcons.users, label: 'Community', route: AppRoutes.community, color: Color(0xFF0EA5E9)),
    _NavDest(icon: LucideIcons.userRound, label: 'Profile & Settings', route: AppRoutes.profile, color: AppColors.primary),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.layoutGrid, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Navigate',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Jump to any section of the app',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: AppColors.border),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
                children: _destinations.map((d) => _NavGridItem(
                  dest: d,
                  onTap: () => onNavigate(d.route),
                )).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: GestureDetector(
              onTap: () => onNavigate(AppRoutes.crisis),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    _CrisisIconBox(),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crisis Support',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                          Text(
                            'Immediate help & hotlines',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, color: AppColors.error, size: 18),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _CrisisIconBox extends StatelessWidget {
  const _CrisisIconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(LucideIcons.phoneCall, color: AppColors.error, size: 20),
    );
  }
}

class _NavDest {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _NavDest({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
}

class _NavGridItem extends StatelessWidget {
  final _NavDest dest;
  final VoidCallback onTap;
  const _NavGridItem({required this.dest, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: dest.color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dest.color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: dest.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(dest.icon, color: dest.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              dest.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
