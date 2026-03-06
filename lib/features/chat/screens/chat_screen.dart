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

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    _focus.requestFocus();
    await ref.read(chatProvider.notifier).sendMessage(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.tokenBackground,
        body: Column(
          children: [
            _ChatHeader(
              streamState: chatState.streamState,
              onNewChat: () =>
                  ref.read(chatProvider.notifier).startNewSession(),
              onCrisis: () => context.push(AppRoutes.crisis),
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
              child: chatState.messages.isEmpty &&
                      chatState.streamingContent == null
                  ? _EmptyState(
                      onSuggestionTap: (s) {
                        _ctrl.text = s;
                        _send();
                      },
                    )
                  : _MessageList(
                      chatState: chatState,
                      scrollController: _scroll,
                    ),
            ),

            // Error banner
            if (chatState.errorMessage != null)
              _ErrorBanner(
                message: chatState.errorMessage!,
                onDismiss: () =>
                    ref.read(chatProvider.notifier).clearError(),
              ),

            // Input
            _ChatInput(
              controller: _ctrl,
              focusNode: _focus,
              onSend: _send,
              isLoading: chatState.isMayaResponding,
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
  final VoidCallback onNewChat;
  final VoidCallback onCrisis;

  const _ChatHeader({
    required this.streamState,
    required this.onNewChat,
    required this.onCrisis,
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

  const _MessageList({
    required this.chatState,
    required this.scrollController,
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
          isFirstInGroup:
              i == 0 || messages[i - 1].role != msg.role,
        );
      },
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isFirstInGroup;

  const _MessageBubble({
    required this.message,
    required this.isFirstInGroup,
  });

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
              Clipboard.setData(ClipboardData(text: message.content));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
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
        ],
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

// ─── Chat Input ───────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isLoading;

  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isLoading,
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
                    hintText: AppStrings.chatPlaceholder,
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
