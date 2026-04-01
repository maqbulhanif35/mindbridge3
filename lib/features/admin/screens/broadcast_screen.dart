import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../providers/admin_provider.dart';

class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen>
    with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabs;

  String _target = 'all';
  String? _targetUni;
  String _channel = 'inapp';
  String _priority = 'normal';
  bool _sending = false;
  bool _showPreview = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminProvider.notifier).loadBroadcasts();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    String targetValue = _target;
    if (_target == 'university' && _targetUni != null && _targetUni!.isNotEmpty) {
      targetValue = 'uni:$_targetUni';
    } else if (_target == 'students') {
      targetValue = 'role:user';
    } else if (_target == 'admins') {
      targetValue = 'role:admin';
    }

    final ok = await ref.read(adminProvider.notifier).sendBroadcast(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          target: targetValue,
          channel: _channel,
        );

    setState(() => _sending = false);
    if (ok && mounted) {
      _titleCtrl.clear();
      _bodyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.circleCheck, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Broadcast sent successfully'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return Column(
      children: [
        // ── Stats Bar ───────────────────────────────────────
        _BroadcastStatsBar(
          totalSent: state.broadcasts.length,
          totalRecipients: state.broadcasts.fold(0, (s, b) => s + b.recipientCount),
          totalUsers: state.stats.totalUsers,
        ),

        // ── Tabs ────────────────────────────────────────────
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              const Tab(icon: Icon(LucideIcons.send, size: 15), text: 'Compose'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.history, size: 15),
                    const SizedBox(width: 6),
                    const Text('History'),
                    if (state.broadcasts.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: Text(
                          state.broadcasts.length.toString(),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              // ── Compose Tab ────────────────────────────────
              RefreshIndicator(
                onRefresh: () => ref.read(adminProvider.notifier).loadBroadcasts(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(isMobile ? 12 : 24),
                  child: isMobile
                      ? Column(
                          children: [
                            _ComposerCard(
                              formKey: _formKey,
                              titleCtrl: _titleCtrl,
                              bodyCtrl: _bodyCtrl,
                              target: _target,
                              targetUni: _targetUni,
                              channel: _channel,
                              priority: _priority,
                              sending: _sending,
                              showPreview: _showPreview,
                              onTargetChange: (v) => setState(() => _target = v),
                              onUniChange: (v) => setState(() => _targetUni = v),
                              onChannelChange: (v) => setState(() => _channel = v),
                              onPriorityChange: (v) => setState(() => _priority = v),
                              onPreviewToggle: () => setState(() => _showPreview = !_showPreview),
                              onSend: _send,
                              totalUsers: state.stats.totalUsers,
                            ),
                            const SizedBox(height: 20),
                            _QuickTemplates(
                              onSelect: (title, body) {
                                _titleCtrl.text = title;
                                _bodyCtrl.text = body;
                              },
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _ComposerCard(
                                formKey: _formKey,
                                titleCtrl: _titleCtrl,
                                bodyCtrl: _bodyCtrl,
                                target: _target,
                                targetUni: _targetUni,
                                channel: _channel,
                                priority: _priority,
                                sending: _sending,
                                showPreview: _showPreview,
                                onTargetChange: (v) => setState(() => _target = v),
                                onUniChange: (v) => setState(() => _targetUni = v),
                                onChannelChange: (v) => setState(() => _channel = v),
                                onPriorityChange: (v) => setState(() => _priority = v),
                                onPreviewToggle: () =>
                                    setState(() => _showPreview = !_showPreview),
                                onSend: _send,
                                totalUsers: state.stats.totalUsers,
                              ),
                            ),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: 280,
                              child: _QuickTemplates(
                                onSelect: (title, body) {
                                  _titleCtrl.text = title;
                                  _bodyCtrl.text = body;
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // ── History Tab ────────────────────────────────
              _HistoryTab(broadcasts: state.broadcasts),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Stats Bar ────────────────────────────────────────────

class _BroadcastStatsBar extends StatelessWidget {
  final int totalSent;
  final int totalRecipients;
  final int totalUsers;

  const _BroadcastStatsBar({
    required this.totalSent,
    required this.totalRecipients,
    required this.totalUsers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _Stat(
              icon: LucideIcons.send,
              label: 'Total Sent',
              value: totalSent.toString(),
              color: AppColors.primary),
          const SizedBox(width: 16),
          _Stat(
              icon: LucideIcons.users,
              label: 'Total Reached',
              value: NumberFormat.compact().format(totalRecipients),
              color: AppColors.info),
          const SizedBox(width: 16),
          _Stat(
              icon: LucideIcons.target,
              label: 'Platform Size',
              value: totalUsers.toString(),
              color: AppColors.success),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.xsAll,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ],
      );
}

// ─── Composer Card ────────────────────────────────────────

class _ComposerCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final String target;
  final String? targetUni;
  final String channel;
  final String priority;
  final bool sending;
  final bool showPreview;
  final ValueChanged<String> onTargetChange;
  final ValueChanged<String?> onUniChange;
  final ValueChanged<String> onChannelChange;
  final ValueChanged<String> onPriorityChange;
  final VoidCallback onPreviewToggle;
  final VoidCallback onSend;
  final int totalUsers;

  const _ComposerCard({
    required this.formKey,
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.target,
    required this.targetUni,
    required this.channel,
    required this.priority,
    required this.sending,
    required this.showPreview,
    required this.onTargetChange,
    required this.onUniChange,
    required this.onChannelChange,
    required this.onPriorityChange,
    required this.onPreviewToggle,
    required this.onSend,
    required this.totalUsers,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Icon(LucideIcons.megaphone,
                      size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Broadcast',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.white)),
                      Text('Compose and send to your users',
                          style: TextStyle(fontSize: 12, color: Colors.white60)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    '$totalUsers users',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Target
                _ComposeSectionLabel('Recipients'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TargetChip(
                        label: 'All Users',
                        icon: LucideIcons.users,
                        value: 'all',
                        selected: target == 'all',
                        onTap: onTargetChange),
                    _TargetChip(
                        label: 'Students',
                        icon: LucideIcons.graduationCap,
                        value: 'students',
                        selected: target == 'students',
                        onTap: onTargetChange),
                    _TargetChip(
                        label: 'Admins Only',
                        icon: LucideIcons.shield,
                        value: 'admins',
                        selected: target == 'admins',
                        onTap: onTargetChange),
                    _TargetChip(
                        label: 'By University',
                        icon: LucideIcons.building2,
                        value: 'university',
                        selected: target == 'university',
                        onTap: onTargetChange),
                  ],
                ),

                if (target == 'university') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    onChanged: onUniChange,
                    decoration: InputDecoration(
                      hintText: 'Enter university name…',
                      prefixIcon: const Icon(LucideIcons.search,
                          size: 15, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                          borderRadius: AppRadius.smAll,
                          borderSide: BorderSide.none),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    validator: (v) => target == 'university' && (v == null || v.isEmpty)
                        ? 'Enter a university name'
                        : null,
                  ),
                ],

                const SizedBox(height: 20),

                // Channel
                _ComposeSectionLabel('Channel'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ChannelOption(
                        icon: LucideIcons.bell,
                        label: 'In-App',
                        subtitle: 'Push notification',
                        value: 'inapp',
                        selected: channel == 'inapp',
                        color: AppColors.primary,
                        onTap: () => onChannelChange('inapp'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChannelOption(
                        icon: LucideIcons.mail,
                        label: 'Email',
                        subtitle: 'To inbox',
                        value: 'email',
                        selected: channel == 'email',
                        color: AppColors.info,
                        onTap: () => onChannelChange('email'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChannelOption(
                        icon: LucideIcons.zap,
                        label: 'Both',
                        subtitle: 'App + Email',
                        value: 'both',
                        selected: channel == 'both',
                        color: AppColors.warning,
                        onTap: () => onChannelChange('both'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Priority
                _ComposeSectionLabel('Priority'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _PriorityChip(
                        label: 'Normal',
                        color: AppColors.textMuted,
                        selected: priority == 'normal',
                        onTap: () => onPriorityChange('normal')),
                    const SizedBox(width: 8),
                    _PriorityChip(
                        label: 'Important',
                        color: AppColors.warning,
                        selected: priority == 'important',
                        onTap: () => onPriorityChange('important')),
                    const SizedBox(width: 8),
                    _PriorityChip(
                        label: 'Urgent',
                        color: AppColors.error,
                        selected: priority == 'urgent',
                        onTap: () => onPriorityChange('urgent')),
                  ],
                ),

                const SizedBox(height: 20),

                // Title
                _ComposeSectionLabel('Notification Title'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: titleCtrl,
                  maxLength: 80,
                  decoration: InputDecoration(
                    hintText: 'e.g. New wellness challenge available',
                    hintStyle:
                        const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                        borderRadius: AppRadius.smAll,
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.smAll,
                        borderSide: const BorderSide(color: AppColors.primary)),
                    isDense: true,
                    counterText: '',
                  ),
                  style: const TextStyle(fontSize: 13),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Title required' : null,
                ),

                const SizedBox(height: 16),

                // Message
                Row(
                  children: [
                    const Expanded(child: _ComposeSectionLabel('Message')),
                    TextButton.icon(
                      onPressed: onPreviewToggle,
                      icon: Icon(
                          showPreview ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 13),
                      label: Text(showPreview ? 'Hide Preview' : 'Show Preview',
                          style: const TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Write your message here…',
                    hintStyle:
                        const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                        borderRadius: AppRadius.smAll,
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.smAll,
                        borderSide: const BorderSide(color: AppColors.primary)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 13),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Message required' : null,
                ),

                // Preview
                if (showPreview) ...[
                  const SizedBox(height: 16),
                  _MessagePreview(titleCtrl: titleCtrl, bodyCtrl: bodyCtrl, channel: channel),
                ],

                const SizedBox(height: 20),

                // Send Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: sending ? null : onSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
                      elevation: 0,
                    ),
                    icon: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(LucideIcons.send, size: 16),
                    label: Text(
                        sending ? 'Sending…' : 'Send Broadcast',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }
}

// ─── Message Preview ──────────────────────────────────────

class _MessagePreview extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final String channel;

  const _MessagePreview({
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.channel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([titleCtrl, bodyCtrl]),
      builder: (context, _) {
        final hasContent = titleCtrl.text.isNotEmpty || bodyCtrl.text.isNotEmpty;
        if (!hasContent) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ComposeSectionLabel('Preview'),
            const SizedBox(height: 8),
            // Phone notification mockup
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: AppRadius.mdAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.xsAll,
                        ),
                        child: const Icon(LucideIcons.brain,
                            size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text('MindBridge',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      const Text('now',
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Notification Title',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bodyCtrl.text.isNotEmpty ? bodyCtrl.text : 'Your message here…',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (channel == 'email' || channel == 'both') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.infoContainer,
                  borderRadius: AppRadius.smAll,
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.mail, size: 12, color: AppColors.info),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Email will also be sent to user inboxes',
                        style: TextStyle(fontSize: 11, color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─── Quick Templates ──────────────────────────────────────

class _QuickTemplates extends StatelessWidget {
  final void Function(String title, String body) onSelect;
  const _QuickTemplates({required this.onSelect});

  static const _templates = [
    (
      '🧘 Weekly Mindfulness Reminder',
      'Hi! Take 5 minutes today for your mental wellbeing. Open MindBridge and try a quick breathing exercise or log your mood. Your mental health matters! 💙',
      LucideIcons.wind,
      AppColors.primary,
    ),
    (
      '🎯 New Challenge Unlocked',
      'You have a new wellness challenge waiting for you! Complete it to earn XP and keep your streak going. Open the app to check it out.',
      LucideIcons.target,
      AppColors.success,
    ),
    (
      '📊 Weekly Wellness Report Ready',
      'Your weekly mental wellness report is ready. See your mood trends, streaks, and insights from the past 7 days. Keep up the great work!',
      LucideIcons.chartBar,
      AppColors.info,
    ),
    (
      '⚠️ Platform Maintenance Notice',
      'MindBridge will undergo scheduled maintenance on [DATE] from [TIME]. The app will be temporarily unavailable. Thank you for your patience.',
      LucideIcons.wrench,
      AppColors.warning,
    ),
    (
      '🎉 Feature Announcement',
      'We just launched something new on MindBridge! Open the app to explore our latest feature designed to support your mental health journey.',
      LucideIcons.sparkles,
      AppColors.secondary,
    ),
    (
      '💚 Crisis Support Reminder',
      'Remember, you\'re never alone. If you\'re struggling, reach out to Maya in the chat, or contact emergency services. We\'re here for you. 💙',
      LucideIcons.heart,
      AppColors.error,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.layoutTemplate, size: 15, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Quick Templates',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap to use a template',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          ...(_templates.map((t) => _TemplateTile(
                title: t.$1,
                body: t.$2,
                icon: t.$3,
                color: t.$4,
                onTap: () => onSelect(t.$1, t.$2),
              ))),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 300.ms);
  }
}

class _TemplateTile extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TemplateTile({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          borderRadius: AppRadius.smAll,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: AppRadius.smAll,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title.replaceAll(RegExp(r'^[^\w]+'), ''),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 12, color: color),
              ],
            ),
          ),
        ),
      );
}

// ─── History Tab ──────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final List<BroadcastRecord> broadcasts;
  const _HistoryTab({required this.broadcasts});

  @override
  Widget build(BuildContext context) {
    if (broadcasts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: AppRadius.pillAll,
              ),
              child: const Icon(LucideIcons.megaphone,
                  size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No broadcasts yet',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            const Text('Send your first broadcast to users',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    // Group by month
    final groups = <String, List<BroadcastRecord>>{};
    for (final b in broadcasts) {
      final key = DateFormat('MMMM yyyy').format(b.sentAt);
      groups.putIfAbsent(key, () => []).add(b);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              entry.key,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.sm,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entry.value.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.border, height: 1),
              itemBuilder: (context, i) => _BroadcastTile(
                record: entry.value[i],
                delay: Duration(milliseconds: i * 30),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BroadcastTile extends StatelessWidget {
  final BroadcastRecord record;
  final Duration delay;

  const _BroadcastTile({required this.record, required this.delay});

  String get _targetLabel {
    if (record.target == 'all') return 'All Users';
    if (record.target == 'role:user') return 'Students';
    if (record.target == 'role:admin') return 'Admins';
    if (record.target.startsWith('uni:')) return record.target.substring(4);
    if (record.target.startsWith('user:')) return record.target.substring(5);
    return record.target;
  }

  Color get _channelColor {
    switch (record.channel) {
      case 'email': return AppColors.info;
      case 'both': return AppColors.warning;
      default: return AppColors.primary;
    }
  }

  IconData get _channelIcon {
    switch (record.channel) {
      case 'email': return LucideIcons.mail;
      case 'both': return LucideIcons.zap;
      default: return LucideIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _channelColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(_channelIcon, size: 16, color: _channelColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  record.body,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Badge(
                        label: _targetLabel,
                        color: AppColors.primary,
                        icon: LucideIcons.users),
                    _Badge(
                        label: '${record.recipientCount} recipients',
                        color: AppColors.success,
                        icon: LucideIcons.circleCheck),
                    _Badge(
                        label: record.channel.toUpperCase(),
                        color: _channelColor,
                        icon: _channelIcon),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('d MMM').format(record.sentAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('HH:mm').format(record.sentAt),
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: delay).fadeIn(duration: 200.ms);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.xsAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

// ─── Helper Widgets ───────────────────────────────────────

class _ComposeSectionLabel extends StatelessWidget {
  final String label;
  const _ComposeSectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3),
      );
}

class _TargetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;

  const _TargetChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: AppRadius.smAll,
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13,
                  color: selected ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}

class _ChannelOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ChannelOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : AppColors.surfaceVariant,
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? color : AppColors.textMuted),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? color : AppColors.textSecondary)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: AppRadius.pillAll,
            border: Border.all(
                color: selected ? color : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : AppColors.textMuted),
          ),
        ),
      );
}
