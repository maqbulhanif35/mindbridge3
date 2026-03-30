import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/peer_chat_model.dart';
import '../../../core/providers/peer_chat_provider.dart';

// ─── Crisis Severity ──────────────────────────────────────

enum CrisisSeverity { none, mild, moderate, severe }

const _kMildKeywords = [
  'stressed', 'overwhelmed', "can't cope", 'struggling', 'hopeless',
  'worthless', 'failing', 'alone', 'empty', 'numb',
];
const _kModerateKeywords = [
  'give up', "can't go on", 'no reason to live', 'hurt myself',
  'self harm', 'disappear', 'not worth it', 'checked out',
];
const _kSevereKeywords = [
  'suicide', 'kill myself', 'end it all', 'end my life',
  'want to die', 'overdose', 'no reason to be here',
];

CrisisSeverity _getCrisisSeverity(String text) {
  final lower = text.toLowerCase();
  if (_kSevereKeywords.any((k) => lower.contains(k))) return CrisisSeverity.severe;
  if (_kModerateKeywords.any((k) => lower.contains(k))) return CrisisSeverity.moderate;
  if (_kMildKeywords.any((k) => lower.contains(k))) return CrisisSeverity.mild;
  return CrisisSeverity.none;
}

// ─── Emoji Reactions ─────────────────────────────────────

const _kReactionEmojis = ['❤️', '😂', '😮', '😢', '🙏', '👍'];

// ─── Waiting Room Tips ────────────────────────────────────

const _kWaitingTips = [
  'Take 3 slow, deep breaths 🌬️',
  'You took a brave step by reaching out 💪',
  'Peer support can be incredibly powerful 🤝',
  'Everything shared here stays private 🔒',
  "You are not alone in what you're feeling 💙",
  'A peer is on their way — hold on ⏳',
];

// ─── Peer Chat Page ───────────────────────────────────────

class PeerChatPage extends ConsumerStatefulWidget {
  final PeerConversation conversation;
  const PeerChatPage({super.key, required this.conversation});

  @override
  ConsumerState<PeerChatPage> createState() => _PeerChatPageState();
}

class _PeerChatPageState extends ConsumerState<PeerChatPage> {
  late PeerConversation _conv;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<PeerMessage> _messages = [];
  bool _isLoading = true;
  bool _isSendingImage = false;
  CrisisSeverity _crisisSeverity = CrisisSeverity.none;
  int _crisisMessageCount = 0;
  bool _peerIsTyping = false;
  bool _peerJoinAnnounced = false;
  RealtimeChannel? _msgChannel;
  RealtimeChannel? _convChannel;
  Timer? _typingClearTimer;
  Timer? _typingDebounce;
  Timer? _pollTimer;
  Timer? _inactivityTimer;
  String? _myUid;
  late DateTime _sessionStart;
  int _charCount = 0;
  PeerMessage? _replyingTo;

  static const _kMaxChars = 800;
  static const _kCharWarnThreshold = 600;
  static const _kInactivityDuration = Duration(minutes: 20);

  @override
  void initState() {
    super.initState();
    _conv = widget.conversation;
    _sessionStart = DateTime.now();
    _myUid = Supabase.instance.client.auth.currentUser?.id;
    _ctrl.addListener(_onCtrlChanged);
    _load();
    _setupSubscriptions();
  }

  @override
  void dispose() {
    _msgChannel?.unsubscribe();
    _convChannel?.unsubscribe();
    _typingClearTimer?.cancel();
    _typingDebounce?.cancel();
    _pollTimer?.cancel();
    _inactivityTimer?.cancel();
    _ctrl.removeListener(_onCtrlChanged);
    _ctrl.dispose();
    _scroll.dispose();
    ref.read(peerChatProvider.notifier).disposeBroadcastChannel(_conv.id);
    super.dispose();
  }

  void _onCtrlChanged() {
    final len = _ctrl.text.length;
    if (len != _charCount) setState(() => _charCount = len);
  }

  // ── Inactivity Timer ──────────────────────────────────────

  void _resetInactivityTimer() {
    if (!_conv.isConnected) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_kInactivityDuration, _onInactivityExpired);
  }

  void _onInactivityExpired() {
    if (!mounted || !_conv.isConnected) return;
    setState(() {
      _messages.add(PeerMessage.system(
        conversationId: _conv.id,
        content: "It's been quiet — still there? 💬",
      ));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _resetInactivityTimer();
  }

  // ── Data Loading ──────────────────────────────────────────

  Future<void> _load() async {
    final msgs = await ref.read(peerChatProvider.notifier).loadMessages(_conv.id);
    if (mounted) setState(() { _messages = msgs; _isLoading = false; });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    if (_conv.isWaiting && _myUid == _conv.user1Id) {
      _checkIfAlreadyJoined();
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_conv.isWaiting) { _pollTimer?.cancel(); return; }
        _checkIfAlreadyJoined();
      });
    }
    if (_conv.isConnected) _resetInactivityTimer();
  }

  Future<void> _checkIfAlreadyJoined() async {
    try {
      final resp = await Supabase.instance.client
          .from('peer_conversations').select().eq('id', _conv.id).single();
      final updated = PeerConversation.fromJson(resp as Map<String, dynamic>);
      if (updated.user2Id != null && mounted) {
        _pollTimer?.cancel();
        _onConvUpdate(updated);
      }
    } catch (_) {}
  }

  // ── Subscriptions ─────────────────────────────────────────

  void _setupSubscriptions() {
    _msgChannel = ref.read(peerChatProvider.notifier)
        .subscribeToMessages(_conv.id, _onNewMessage);
    _convChannel = ref.read(peerChatProvider.notifier)
        .subscribeToConversation(_conv.id, _onConvUpdate);
    ref.read(peerChatProvider.notifier).listenTyping(_conv.id, (uid, isTyping) {
      if (!mounted || uid == _myUid) return;
      setState(() => _peerIsTyping = isTyping);
      _typingClearTimer?.cancel();
      if (isTyping) {
        _typingClearTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _peerIsTyping = false);
        });
      }
    });
  }

  void _onConvUpdate(PeerConversation updated) {
    if (!mounted) return;
    if (updated.user2Id != null && _conv.user2Id == null && !_peerJoinAnnounced) {
      _peerJoinAnnounced = true;
      setState(() {
        _conv = updated;
        _messages.add(PeerMessage.system(
          conversationId: _conv.id,
          content: '${_conv.peerHandle(_myUid!)} joined the chat 👋',
        ));
      });
      _resetInactivityTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      setState(() => _conv = updated);
    }
    if (updated.isEnded && !_conv.isEnded) {
      _inactivityTimer?.cancel();
      setState(() {
        _messages.add(PeerMessage.system(
          conversationId: _conv.id,
          content: 'This conversation has ended',
        ));
      });
    }
  }

  void _onNewMessage(PeerMessage msg) {
    if (!mounted) return;
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages.add(msg));
    _resetInactivityTimer();
    final severity = _getCrisisSeverity(msg.content);
    if (severity != CrisisSeverity.none) {
      _crisisMessageCount++;
      if (severity.index > _crisisSeverity.index) setState(() => _crisisSeverity = severity);
      _handleCrisisEscalation(severity);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _handleCrisisEscalation(CrisisSeverity severity) {
    if (severity == CrisisSeverity.severe) {
      _showCrisisSheet(context);
    } else if (severity == CrisisSeverity.moderate && _crisisMessageCount >= 3) {
      setState(() {
        _messages.add(PeerMessage.system(
          conversationId: _conv.id,
          content: 'Crisis support is available right now — you don\'t have to face this alone.',
        ));
      });
      _showCrisisSheet(context);
    }
  }

  // ── Scroll ────────────────────────────────────────────────

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  // ── Typing ────────────────────────────────────────────────

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      ref.read(peerChatProvider.notifier).sendTyping(_conv.id, true);
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 3), () {
        ref.read(peerChatProvider.notifier).sendTyping(_conv.id, false);
      });
    } else {
      _typingDebounce?.cancel();
      ref.read(peerChatProvider.notifier).sendTyping(_conv.id, false);
    }
  }

  // ── Send Message ──────────────────────────────────────────

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || text.length > _kMaxChars) return;
    _ctrl.clear();
    _typingDebounce?.cancel();
    ref.read(peerChatProvider.notifier).sendTyping(_conv.id, false);

    final severity = _getCrisisSeverity(text);
    if (severity != CrisisSeverity.none) {
      _crisisMessageCount++;
      if (severity.index > _crisisSeverity.index) setState(() => _crisisSeverity = severity);
      _handleCrisisEscalation(severity);
    }
    _resetInactivityTimer();

    final reply = _replyingTo;
    if (mounted) setState(() => _replyingTo = null);

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final temp = PeerMessage(
      id: tempId, conversationId: _conv.id, senderId: _myUid ?? '',
      content: text, createdAt: DateTime.now(), isTemp: true,
      replyToId: reply?.id,
      replyToContent: reply?.isImage == true ? '📷 Photo' : reply?.content,
      replyToSender: reply?.senderId,
    );
    setState(() => _messages.add(temp));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final confirmed = await ref.read(peerChatProvider.notifier).sendMessage(
      _conv.id, text,
      replyToId: reply?.id,
      replyToContent: reply?.isImage == true ? '📷 Photo' : reply?.content,
      replyToSender: reply?.senderId,
    );

    if (mounted) {
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
        if (confirmed != null) _messages.add(confirmed);
      });
    }
  }

  // ── Image Sharing ─────────────────────────────────────────

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _isSendingImage = true);
    final url = await ref.read(peerChatProvider.notifier)
        .uploadImage(_conv.id, File(picked.path));

    if (!mounted) return;
    if (url == null) {
      setState(() => _isSendingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to upload image. Try again.'),
        behavior: SnackBarBehavior.floating));
      return;
    }

    final tempId = 'temp_img_${DateTime.now().millisecondsSinceEpoch}';
    final temp = PeerMessage(
      id: tempId, conversationId: _conv.id, senderId: _myUid ?? '',
      content: '', createdAt: DateTime.now(), isTemp: true,
      type: 'image', mediaUrl: url,
    );
    setState(() { _messages.add(temp); _isSendingImage = false; });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final confirmed = await ref.read(peerChatProvider.notifier)
        .sendMessage(_conv.id, '', mediaUrl: url, mediaType: 'image');

    if (mounted) {
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
        if (confirmed != null) _messages.add(confirmed);
      });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Share a photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ImageSourceTile(
                    icon: LucideIcons.camera, label: 'Camera',
                    color: AppColors.primary,
                    onTap: () { Navigator.pop(context); _pickAndSendImage(ImageSource.camera); },
                  ),
                  _ImageSourceTile(
                    icon: LucideIcons.image, label: 'Gallery',
                    color: const Color(0xFF6366F1),
                    onTap: () { Navigator.pop(context); _pickAndSendImage(ImageSource.gallery); },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reactions ─────────────────────────────────────────────

  void _showReactionPicker(PeerMessage msg) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(15),
              blurRadius: 20, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(msg.isImage ? '📷 Photo' : msg.content,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _kReactionEmojis.map((emoji) {
                final alreadyReacted = msg.reactions[emoji]?.contains(_myUid ?? '') ?? false;
                return GestureDetector(
                  onTap: () { Navigator.pop(context); _toggleReaction(msg, emoji); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: alreadyReacted ? AppColors.primary.withAlpha(20) : const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(color: alreadyReacted ? AppColors.primary : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  void _toggleReaction(PeerMessage msg, String emoji) {
    final uid = _myUid;
    if (uid == null) return;
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == msg.id);
      if (idx != -1) _messages[idx] = _messages[idx].copyWithReaction(emoji, uid);
    });
    ref.read(peerChatProvider.notifier).toggleReaction(msg.id, emoji);
  }

  // ── Reply ─────────────────────────────────────────────────

  void _startReply(PeerMessage msg) {
    HapticFeedback.lightImpact();
    setState(() => _replyingTo = msg);
  }

  // ── End Chat ──────────────────────────────────────────────

  Future<void> _endChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End this chat?',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
        content: const Text('The conversation will be archived.',
          style: TextStyle(color: Color(0xFF64748B))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End chat',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      _inactivityTimer?.cancel();
      await ref.read(peerChatProvider.notifier).endConversation(_conv.id);
      if (mounted) _showSessionSummary();
    }
  }

  void _showSessionSummary() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _SessionSummarySheet(
        sessionStart: _sessionStart,
        messageCount: _messages.where((m) => !m.isSystem).length,
        onDone: () { Navigator.pop(context); Navigator.pop(context); },
      ),
    );
  }

  void _showChatInfo() {
    final tc = _topicColor(_conv.topic);
    final dMin = DateTime.now().difference(_sessionStart).inMinutes;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Chat Info', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            if (_conv.isConnected) ...[
              Row(
                children: [
                  _PeerAvatar(
                    name: _conv.peerHandle(_myUid ?? ''),
                    avatarUrl: _conv.isAnonymous ? null : _conv.peerAvatar(_myUid ?? ''),
                    color: tc, size: 44,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_conv.peerHandle(_myUid ?? ''),
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                      if (_conv.isAnonymous)
                        const Text('Anonymous mode',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                _TopicChip(topic: _conv.topic, color: tc),
                if (_conv.isAnonymous) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFE0F8F7),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.eyeOff, size: 12, color: AppColors.primary),
                        SizedBox(width: 5),
                        Text('Anonymous', style: TextStyle(fontSize: 12,
                            color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.clock, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text('${_sessionStart.hour.toString().padLeft(2,'0')}:${_sessionStart.minute.toString().padLeft(2,'0')} start  ·  ${dMin < 1 ? 'just started' : '$dMin min'}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Community Guidelines',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B))),
                const SizedBox(height: 10),
                _GuidelineTile(LucideIcons.heart, 'Be kind — support, don\'t judge'),
                const SizedBox(height: 6),
                _GuidelineTile(LucideIcons.smile, 'Be real — share your authentic experience'),
                const SizedBox(height: 6),
                _GuidelineTile(LucideIcons.shieldOff, 'No personal info — keep it safe'),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.flag, size: 16),
                label: const Text('Report this conversation',
                  style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Report submitted. Thank you.'),
                    behavior: SnackBarBehavior.floating));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImage(String url) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => _FullImageViewer(url: url)));

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_conv.isWaiting && _myUid == _conv.user1Id) {
      return _WaitingRoom(
        conversation: _conv,
        onCancel: () async {
          final s = ref.read(peerChatProvider).value;
          final entry = s?.openRequests
              .where((e) => e.conversationId == _conv.id && e.userId == _myUid)
              .firstOrNull;
          if (entry != null) await ref.read(peerChatProvider.notifier).cancelRequest(entry.id);
          if (mounted) Navigator.pop(context);
        },
      );
    }

    final tc = _topicColor(_conv.topic);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(tc),
      body: Column(
        children: [
          if (_crisisSeverity != CrisisSeverity.none)
            _CrisisBanner(
              severity: _crisisSeverity,
              onDismiss: _crisisSeverity == CrisisSeverity.severe
                  ? null : () => setState(() => _crisisSeverity = CrisisSeverity.none),
              onGetHelp: () => _showCrisisSheet(context),
            ),
          if (_conv.isEnded)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFFF1F5F9),
              child: const Center(child: Text('This conversation has ended',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic))),
            ),
          Expanded(child: _buildMessages()),
          if (_replyingTo != null)
            _ReplyPreview(
              message: _replyingTo!,
              isMe: _replyingTo!.senderId == _myUid,
              myHandle: _conv.myHandle(_myUid ?? ''),
              peerHandle: _conv.peerHandle(_myUid ?? ''),
              accentColor: tc,
              onDismiss: () => setState(() => _replyingTo = null),
            ),
          if (!_conv.isEnded)
            _ChatInput(
              ctrl: _ctrl, onSend: _send, onChanged: _onTextChanged,
              onAttach: _showImageSourceSheet, accentColor: tc,
              charCount: _charCount, maxChars: _kMaxChars,
              warnThreshold: _kCharWarnThreshold, isSendingImage: _isSendingImage,
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Color tc) {
    final isConnected = _conv.isConnected;
    final peerName = isConnected ? _conv.peerHandle(_myUid ?? '') : _conv.topic;
    final peerAvatar = isConnected ? _conv.peerAvatar(_myUid ?? '') : null;
    return AppBar(
      backgroundColor: tc, elevation: 0,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        onPressed: () => Navigator.pop(context)),
      title: Row(
        children: [
          _PeerAvatar(
            name: peerName, avatarUrl: _conv.isAnonymous ? null : peerAvatar,
            color: Colors.white.withAlpha(50), size: 36, textColor: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(peerName, style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 15)),
                Row(children: [
                  _PulseDot(color: isConnected
                      ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24)),
                  const SizedBox(width: 5),
                  Text(isConnected ? 'Connected' : 'Connecting…',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(LucideIcons.info, color: Colors.white, size: 20),
          tooltip: 'Chat Info', onPressed: _showChatInfo),
        if (!_conv.isEnded) ...[
          IconButton(icon: const Icon(LucideIcons.phoneCall, color: Colors.white, size: 20),
            tooltip: 'Crisis Line', onPressed: () => _showCrisisSheet(context)),
          IconButton(icon: const Icon(LucideIcons.doorOpen, color: Colors.white, size: 20),
            tooltip: 'End Chat', onPressed: _endChat),
        ],
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMessages() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty && !_conv.isConnected) {
      return _EmptyChatState(
        icon: LucideIcons.messageCircle,
        title: _conv.isWaiting ? 'Waiting for a peer…' : 'Start the conversation',
        subtitle: _conv.isAnonymous
            ? 'Your identity is hidden — share safely' : 'Be kind, be real, be supportive',
        color: _topicColor(_conv.topic),
      );
    }

    final items = <_ChatDisplayItem>[];
    DateTime? lastDate;
    String? lastSenderId;
    for (final msg in _messages) {
      if (!msg.isSystem) {
        final d = DateTime(msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
        if (lastDate == null || d != lastDate) {
          items.add(_ChatDisplayItem.separator(d));
          lastDate = d; lastSenderId = null;
        }
      }
      final isFirstInRun = msg.isSystem || msg.senderId != lastSenderId;
      if (!msg.isSystem) lastSenderId = msg.senderId;
      items.add(_ChatDisplayItem.message(msg, isFirstInRun: isFirstInRun));
    }

    final totalCount = items.length + (_peerIsTyping ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: totalCount,
      itemBuilder: (ctx, i) {
        if (i == items.length && _peerIsTyping) {
          return _TypingBubble(
            handle: _conv.peerHandle(_myUid ?? ''),
            avatarUrl: _conv.isAnonymous ? null : _conv.peerAvatar(_myUid ?? ''),
            accentColor: _topicColor(_conv.topic),
          );
        }
        final item = items[i];
        if (item.isSeparator) return _DateSeparator(date: item.date!);
        final msg = item.message!;
        if (msg.isSystem) return _SystemMessageBubble(content: msg.content);
        final isMe = msg.senderId == _myUid;
        final isLast = i == items.length - 1;
        final showTime = isLast ||
            (items[i + 1].message != null &&
                items[i + 1].message!.createdAt.difference(msg.createdAt).inMinutes > 5);
        return _MessageBubble(
          message: msg, isMe: isMe, showTime: showTime,
          isFirstInRun: item.isFirstInRun,
          accentColor: _topicColor(_conv.topic),
          senderHandle: !isMe && item.isFirstInRun ? _conv.peerHandle(_myUid ?? '') : null,
          senderAvatarUrl: !isMe && item.isFirstInRun && !_conv.isAnonymous
              ? _conv.peerAvatar(_myUid ?? '') : null,
          onLongPress: () => _showReactionPicker(msg),
          onReply: () => _startReply(msg),
          onImageTap: msg.isImage && msg.mediaUrl != null
              ? () => _openImage(msg.mediaUrl!) : null,
        );
      },
    );
  }
}

// ─── Chat Display Item ────────────────────────────────────

class _ChatDisplayItem {
  final PeerMessage? message;
  final DateTime? date;
  final bool isFirstInRun;
  const _ChatDisplayItem._({this.message, this.date, this.isFirstInRun = false});
  factory _ChatDisplayItem.message(PeerMessage m, {bool isFirstInRun = false}) =>
      _ChatDisplayItem._(message: m, isFirstInRun: isFirstInRun);
  factory _ChatDisplayItem.separator(DateTime d) => _ChatDisplayItem._(date: d);
  bool get isSeparator => date != null;
}

// ─── Peer Avatar ──────────────────────────────────────────

class _PeerAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final Color color;
  final double size;
  final Color textColor;
  const _PeerAvatar({
    required this.name, required this.color,
    this.avatarUrl, this.size = 36,
    this.textColor = const Color(0xFF1E293B),
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!, width: size, height: size, fit: BoxFit.cover,
          placeholder: (_, __) => _Initials(name: name, color: color, size: size, textColor: textColor),
          errorWidget: (_, __, ___) => _Initials(name: name, color: color, size: size, textColor: textColor),
        ),
      );
    }
    return _Initials(name: name, color: color, size: size, textColor: textColor);
  }
}

class _Initials extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  final Color textColor;
  const _Initials({required this.name, required this.color,
      required this.size, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: Text(initial,
        style: TextStyle(fontSize: size * 0.4,
            fontWeight: FontWeight.w800, color: textColor))),
    );
  }
}

// ─── Image Source Tile ────────────────────────────────────

class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ImageSourceTile({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: color.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(60))),
          child: Icon(icon, color: color, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      ],
    ),
  );
}

// ─── Topic Chip ───────────────────────────────────────────

class _TopicChip extends StatelessWidget {
  final String topic;
  final Color color;
  const _TopicChip({required this.topic, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withAlpha(20), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withAlpha(60))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.tag, size: 12, color: color),
      const SizedBox(width: 5),
      Text(topic, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ─── Pulse Dot ────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(width: 6, height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)));
}

// ─── Reply Preview ────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final PeerMessage message;
  final bool isMe;
  final String myHandle;
  final String peerHandle;
  final Color accentColor;
  final VoidCallback onDismiss;
  const _ReplyPreview({
    required this.message, required this.isMe, required this.myHandle,
    required this.peerHandle, required this.accentColor, required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(
        left: BorderSide(color: accentColor, width: 3),
        top: const BorderSide(color: Color(0xFFE2E8F0)))),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Replying to ${isMe ? myHandle : peerHandle}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor)),
          const SizedBox(height: 2),
          Text(message.isImage ? '📷 Photo' : message.content,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      )),
      GestureDetector(onTap: onDismiss,
        child: const Padding(padding: EdgeInsets.all(4),
          child: Icon(LucideIcons.x, size: 16, color: Color(0xFF94A3B8)))),
    ]),
  );
}

// ─── Guideline Tile ───────────────────────────────────────

class _GuidelineTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GuidelineTile(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 13, color: AppColors.primary),
    const SizedBox(width: 8),
    Expanded(child: Text(text,
      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4))),
  ]);
}

// ─── Session Summary Sheet ────────────────────────────────

class _SessionSummarySheet extends StatefulWidget {
  final DateTime sessionStart;
  final int messageCount;
  final VoidCallback onDone;
  const _SessionSummarySheet({
    required this.sessionStart, required this.messageCount, required this.onDone});

  @override
  State<_SessionSummarySheet> createState() => _SessionSummarySheetState();
}

class _SessionSummarySheetState extends State<_SessionSummarySheet> {
  int? _feelingIndex;
  bool? _gotSupport;
  static const _emojis = ['😰', '😟', '😐', '🙂', '😊'];

  @override
  Widget build(BuildContext context) {
    final dMin = DateTime.now().difference(widget.sessionStart).inMinutes;
    final dStr = dMin < 1 ? 'Less than a minute' : '$dMin min${dMin == 1 ? '' : 's'}';
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 44, height: 44,
              decoration: const BoxDecoration(color: Color(0xFFE0F8F7), shape: BoxShape.circle),
              child: const Icon(LucideIcons.checkCheck, color: AppColors.primary, size: 22)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Session Complete', style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              Text('$dStr · ${widget.messageCount} messages',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ]),
          ]),
          const SizedBox(height: 24),
          const Text('How did this conversation feel?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_emojis.length, (i) {
              final selected = _feelingIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _feelingIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withAlpha(20) : const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
                        width: selected ? 2 : 1)),
                  child: Center(child: Text(_emojis[i],
                    style: TextStyle(fontSize: selected ? 26 : 22)))),
              );
            }),
          ),
          const SizedBox(height: 24),
          const Text('Did you get the support you needed?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _SupportButton(label: 'Yes', icon: LucideIcons.thumbsUp,
              selected: _gotSupport == true, color: AppColors.primary,
              onTap: () => setState(() => _gotSupport = true))),
            const SizedBox(width: 12),
            Expanded(child: _SupportButton(label: 'No', icon: LucideIcons.thumbsDown,
              selected: _gotSupport == false, color: const Color(0xFFEF4444),
              onTap: () => setState(() => _gotSupport = false))),
          ]),
          if (_gotSupport == false) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withAlpha(60))),
              child: const Row(children: [
                Icon(LucideIcons.lightbulb, size: 14, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Expanded(child: Text('Consider reaching out to a campus counselor →',
                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E),
                      fontWeight: FontWeight.w600, height: 1.4))),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0),
              child: const Text('Done',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
          ),
        ],
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _SupportButton({required this.label, required this.icon,
      required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? color.withAlpha(20) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: selected ? color : const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: selected ? color : const Color(0xFF94A3B8))),
      ]),
    ),
  );
}

// ─── Waiting Room ─────────────────────────────────────────

class _WaitingRoom extends StatefulWidget {
  final PeerConversation conversation;
  final VoidCallback onCancel;
  const _WaitingRoom({required this.conversation, required this.onCancel});

  @override
  State<_WaitingRoom> createState() => _WaitingRoomState();
}

class _WaitingRoomState extends State<_WaitingRoom>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  Timer? _timer;
  int _seconds = 0;
  late PageController _tipsCtrl;
  Timer? _tipsTimer;
  int _currentTip = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    _tipsCtrl = PageController();
    _tipsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _currentTip = (_currentTip + 1) % _kWaitingTips.length;
      _tipsCtrl.animateToPage(_currentTip,
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _pulse.dispose(); _timer?.cancel(); _tipsTimer?.cancel(); _tipsCtrl.dispose();
    super.dispose();
  }

  String get _elapsed => _seconds < 60 ? '$_seconds s' : '${_seconds ~/ 60}m ${_seconds % 60}s';

  @override
  Widget build(BuildContext context) {
    final tc = _topicColor(widget.conversation.topic);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: tc, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Text(widget.conversation.topic,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: tc.withAlpha(20),
                      border: Border.all(color: tc.withAlpha(80), width: 3)),
                  child: Icon(LucideIcons.users, color: tc, size: 44)),
              ),
              const SizedBox(height: 28),
              const Text('Looking for a peer…',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: PageView.builder(
                  controller: _tipsCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _kWaitingTips.length,
                  itemBuilder: (_, i) => Center(child: Text(_kWaitingTips[i],
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                    textAlign: TextAlign.center)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_kWaitingTips.length, (i) =>
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: _currentTip == i ? 16 : 5, height: 5,
                    decoration: BoxDecoration(
                      color: _currentTip == i ? tc : tc.withAlpha(60),
                      borderRadius: BorderRadius.circular(3)),
                  )),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: tc.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tc.withAlpha(60))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.tag, size: 13, color: tc),
                  const SizedBox(width: 6),
                  Text(widget.conversation.topic,
                    style: TextStyle(fontSize: 13, color: tc, fontWeight: FontWeight.w700)),
                  if (widget.conversation.isAnonymous) ...[
                    const SizedBox(width: 8),
                    Icon(LucideIcons.eyeOff, size: 12, color: tc.withAlpha(160)),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.clock, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text('Waiting: $_elapsed',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 40),
              OutlinedButton.icon(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                icon: const Icon(LucideIcons.x, size: 16),
                label: const Text('Cancel Request',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Self Reflect Page ────────────────────────────────────

class SelfReflectPage extends ConsumerStatefulWidget {
  final String conversationId;
  const SelfReflectPage({super.key, required this.conversationId});

  @override
  ConsumerState<SelfReflectPage> createState() => _SelfReflectPageState();
}

class _SelfReflectPageState extends ConsumerState<SelfReflectPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<PeerMessage> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;
  String? _myUid;
  static const _purple = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _myUid = Supabase.instance.client.auth.currentUser?.id;
    _load();
    _channel = ref.read(peerChatProvider.notifier)
        .subscribeToMessages(widget.conversationId, _onNew);
  }

  @override
  void dispose() {
    _channel?.unsubscribe(); _ctrl.dispose(); _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final msgs = await ref.read(peerChatProvider.notifier).loadMessages(widget.conversationId);
    if (mounted) setState(() { _messages = msgs; _isLoading = false; });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onNew(PeerMessage msg) {
    if (!mounted) return;
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final temp = PeerMessage(id: tempId, conversationId: widget.conversationId,
      senderId: _myUid ?? '', content: text, createdAt: DateTime.now(), isTemp: true);
    setState(() => _messages.add(temp));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    final confirmed = await ref.read(peerChatProvider.notifier)
        .sendMessage(widget.conversationId, text);
    if (mounted) {
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
        if (confirmed != null) _messages.add(confirmed);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: _purple, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.white.withAlpha(40), shape: BoxShape.circle),
            child: const Icon(LucideIcons.lock, size: 16, color: Colors.white)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('My Reflections', style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 15)),
            Text('${_messages.length} private thought${_messages.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.info, color: Colors.white, size: 20),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Your private space',
                  style: TextStyle(fontWeight: FontWeight.w800)),
                content: const Text(
                  'Everything here is completely private — only you can see these reflections.',
                  style: TextStyle(color: Color(0xFF64748B), height: 1.5)),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _purple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it', style: TextStyle(color: Colors.white))),
                ],
              )),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFEDE9FE),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(children: [
              Text('✨', style: TextStyle(fontSize: 14)),
              SizedBox(width: 8),
              Expanded(child: Text('This is your safe space — no judgement, just you.',
                style: TextStyle(fontSize: 12, color: _purple, fontWeight: FontWeight.w600))),
            ]),
          ),
          Expanded(child: _buildMessages()),
          _ChatInput(ctrl: _ctrl, onSend: _send,
            hintText: 'Write a thought...', accentColor: _purple),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) {
      return _EmptyChatState(icon: LucideIcons.penLine,
        title: 'Your reflections start here',
        subtitle: 'Write freely — thoughts, feelings,\nwhatever is on your mind',
        color: _purple);
    }
    DateTime? lastDate;
    final items = <_ChatDisplayItem>[];
    for (final msg in _messages) {
      final d = DateTime(msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      if (lastDate == null || d != lastDate) { items.add(_ChatDisplayItem.separator(d)); lastDate = d; }
      items.add(_ChatDisplayItem.message(msg));
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item.isSeparator) return _DateSeparator(date: item.date!);
        final msg = item.message!;
        final showTime = i == items.length - 1 ||
            (items[i + 1].message != null &&
                items[i + 1].message!.createdAt.difference(msg.createdAt).inMinutes > 5);
        return _SelfBubble(message: msg, showTime: showTime);
      },
    );
  }
}

// ─── Date Separator ───────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${m[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFEFF3F7),
            borderRadius: BorderRadius.circular(12)),
        child: Text(_label, style: const TextStyle(fontSize: 11,
            color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))),
      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
    ]),
  );
}

// ─── System Message ───────────────────────────────────────

class _SystemMessageBubble extends StatelessWidget {
  final String content;
  const _SystemMessageBubble({required this.content});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withAlpha(40))),
      child: Text(content,
        style: TextStyle(fontSize: 12, color: AppColors.primary.withAlpha(220),
            fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center))),
  );
}

// ─── Typing Bubble ────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  final String handle;
  final String? avatarUrl;
  final Color accentColor;
  const _TypingBubble({required this.handle, required this.accentColor, this.avatarUrl});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _d1, _d2, _d3;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _d1 = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeInOut)));
    _d2 = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 0.6, curve: Curves.easeInOut)));
    _d3 = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 0.8, curve: Curves.easeInOut)));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _PeerAvatar(name: widget.handle, avatarUrl: widget.avatarUrl,
            color: widget.accentColor.withAlpha(30), size: 28),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18), topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(10),
                blurRadius: 6, offset: const Offset(0, 2))]),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
              _Dot(offset: _d1.value, color: widget.accentColor),
              const SizedBox(width: 4),
              _Dot(offset: _d2.value, color: widget.accentColor),
              const SizedBox(width: 4),
              _Dot(offset: _d3.value, color: widget.accentColor),
            ]),
          ),
        ),
      ],
    ),
  );
}

class _Dot extends StatelessWidget {
  final double offset;
  final Color color;
  const _Dot({required this.offset, required this.color});

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(0, offset),
    child: Container(width: 7, height: 7,
        decoration: BoxDecoration(color: color.withAlpha(180), shape: BoxShape.circle)));
}

// ─── Message Bubble ───────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final PeerMessage message;
  final bool isMe;
  final bool showTime;
  final bool isFirstInRun;
  final Color accentColor;
  final String? senderHandle;
  final String? senderAvatarUrl;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onImageTap;

  const _MessageBubble({
    required this.message, required this.isMe, required this.showTime,
    required this.isFirstInRun, required this.accentColor,
    this.senderHandle, this.senderAvatarUrl,
    this.onLongPress, this.onReply, this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: isFirstInRun ? 6 : 1, bottom: 2),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && senderHandle != null)
            Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 3),
              child: Text(senderHandle!,
                style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w700))),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                if (isFirstInRun)
                  _PeerAvatar(name: senderHandle ?? '?', avatarUrl: senderAvatarUrl,
                      color: accentColor.withAlpha(30), size: 28)
                else
                  const SizedBox(width: 28),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: onLongPress,
                      onHorizontalDragEnd: (d) {
                        if ((d.primaryVelocity ?? 0) < -200) onReply?.call();
                      },
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (message.replyToContent != null)
                            _ReplyQuote(content: message.replyToContent!,
                                isMe: isMe, accentColor: accentColor),
                          Container(
                            constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.68),
                            decoration: isMe
                                ? BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.primary, Color(0xFF33CBC2)],
                                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(18), topRight: Radius.circular(18),
                                      bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
                                    boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(50),
                                        blurRadius: 8, offset: const Offset(0, 3))],
                                  )
                                : BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(18), topRight: Radius.circular(18),
                                      bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18)),
                                    border: Border(left: BorderSide(color: accentColor, width: 3)),
                                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(10),
                                        blurRadius: 6, offset: const Offset(0, 2))],
                                  ),
                            child: message.isImage
                                ? _ImageContent(url: message.mediaUrl!, isMe: isMe, onTap: onImageTap)
                                : Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Text(message.content,
                                      style: TextStyle(fontSize: 14, height: 1.45,
                                          color: isMe ? Colors.white : const Color(0xFF1E293B)))),
                          ),
                        ],
                      ),
                    ),
                    if (message.hasReactions)
                      _ReactionsRow(reactions: message.reactions, isMe: isMe),
                    if (showTime) ...[
                      const SizedBox(height: 3),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(message.timeAgo,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(message.isTemp ? LucideIcons.clock : LucideIcons.checkCheck,
                            size: 10,
                            color: message.isTemp ? const Color(0xFF94A3B8) : accentColor),
                        ],
                      ]),
                    ],
                  ],
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onReply,
                  child: Padding(padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(LucideIcons.reply, size: 14, color: Colors.grey.shade400))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Reply Quote (inside bubble) ─────────────────────────

class _ReplyQuote extends StatelessWidget {
  final String content;
  final bool isMe;
  final Color accentColor;
  const _ReplyQuote({required this.content, required this.isMe, required this.accentColor});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
    decoration: BoxDecoration(
      color: isMe ? Colors.white.withAlpha(30) : accentColor.withAlpha(12),
      borderRadius: BorderRadius.circular(10),
      border: Border(left: BorderSide(
        color: isMe ? Colors.white.withAlpha(120) : accentColor.withAlpha(120), width: 2))),
    child: Text(content, maxLines: 2, overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12,
        color: isMe ? Colors.white.withAlpha(200) : const Color(0xFF64748B), height: 1.4)),
  );
}

// ─── Image Content ────────────────────────────────────��───

class _ImageContent extends StatelessWidget {
  final String url;
  final bool isMe;
  final VoidCallback? onTap;
  const _ImageContent({required this.url, required this.isMe, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
        bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18)),
      child: CachedNetworkImage(
        imageUrl: url, width: 220, height: 200, fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: 220, height: 200,
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
        errorWidget: (_, __, ___) => Container(width: 220, height: 200,
          color: Colors.grey.shade100,
          child: const Center(child: Icon(LucideIcons.imageOff,
              color: Color(0xFF94A3B8), size: 32))),
      ),
    ),
  );
}

// ─── Reactions Row ────────────────────────────────────────

class _ReactionsRow extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final bool isMe;
  const _ReactionsRow({required this.reactions, required this.isMe});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Wrap(
      alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
      spacing: 4,
      children: reactions.entries.where((e) => e.value.isNotEmpty).map((e) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8),
                blurRadius: 4, offset: const Offset(0, 1))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(e.key, style: const TextStyle(fontSize: 13)),
            if (e.value.length > 1) ...[
              const SizedBox(width: 3),
              Text('${e.value.length}', style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            ],
          ]),
        )).toList(),
    ),
  );
}

// ─── Self Bubble ──────────────────────────────────────────

class _SelfBubble extends StatelessWidget {
  final PeerMessage message;
  final bool showTime;
  static const _purple = Color(0xFF7C3AED);
  const _SelfBubble({required this.message, required this.showTime});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 40),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18), topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
            border: Border.all(color: _purple.withAlpha(30))),
          child: Text(message.content,
            style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF4C1D95)))),
        if (showTime) ...[
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(message.timeAgo,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            if (message.isTemp) ...[
              const SizedBox(width: 4),
              const Icon(LucideIcons.clock, size: 10, color: Color(0xFF94A3B8)),
            ],
          ]),
        ],
      ],
    ),
  );
}

// ─── Chat Input ───────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final void Function(String)? onChanged;
  final VoidCallback? onAttach;
  final String hintText;
  final Color accentColor;
  final int charCount;
  final int maxChars;
  final int warnThreshold;
  final bool isSendingImage;

  const _ChatInput({
    required this.ctrl, required this.onSend,
    this.onChanged, this.onAttach,
    this.hintText = 'Type a message...',
    this.accentColor = AppColors.primary,
    this.charCount = 0, this.maxChars = 800, this.warnThreshold = 600,
    this.isSendingImage = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOver = charCount >= maxChars;
    return Container(
      padding: EdgeInsets.only(left: 14, right: 14, top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(15),
            blurRadius: 12, offset: const Offset(0, -3))]),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (charCount >= warnThreshold)
              Align(alignment: Alignment.centerRight,
                child: Padding(padding: const EdgeInsets.only(bottom: 4, right: 4),
                  child: Text('$charCount/$maxChars',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: isOver ? const Color(0xFFEF4444) : const Color(0xFFF59E0B))))),
            Row(children: [
              if (onAttach != null)
                GestureDetector(
                  onTap: isSendingImage ? null : onAttach,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38, height: 38,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSendingImage
                          ? const Color(0xFFE2E8F0) : accentColor.withAlpha(15),
                      shape: BoxShape.circle),
                    child: isSendingImage
                        ? const Center(child: SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                        : Icon(LucideIcons.paperclip, size: 18, color: accentColor)),
                ),
              Expanded(
                child: TextField(
                  controller: ctrl, maxLines: null, maxLength: maxChars,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    filled: true, fillColor: const Color(0xFFF1F5F9),
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                  onSubmitted: (_) => isOver ? null : onSend()),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isOver ? null : onSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isOver ? const Color(0xFFCBD5E1) : accentColor,
                    shape: BoxShape.circle,
                    boxShadow: isOver ? null : [BoxShadow(color: accentColor.withAlpha(80),
                        blurRadius: 8, offset: const Offset(0, 3))]),
                  child: Icon(LucideIcons.sendHorizontal,
                    color: isOver ? const Color(0xFF94A3B8) : Colors.white, size: 18))),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Crisis Banner ────────────────────────────────────────

class _CrisisBanner extends StatelessWidget {
  final CrisisSeverity severity;
  final VoidCallback? onDismiss;
  final VoidCallback onGetHelp;
  const _CrisisBanner({required this.severity, required this.onGetHelp, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final (bg, border, icon, title, sub) = switch (severity) {
      CrisisSeverity.mild => (const Color(0xFFFFFBEB), const Color(0xFFF59E0B),
        const Color(0xFFD97706), "We noticed you might be struggling… 💛",
        "It's okay to not be okay. Support is here."),
      CrisisSeverity.moderate => (const Color(0xFFFFF7ED), const Color(0xFFF97316),
        const Color(0xFFEA580C), "You're not alone 🧡",
        "Crisis support is available right now."),
      CrisisSeverity.severe || CrisisSeverity.none => (const Color(0xFFFEF2F2),
        const Color(0xFFEF4444), const Color(0xFFDC2626), "You're not alone 💙",
        "Free support is available 24/7. You matter."),
    };
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: border, width: 4)),
        boxShadow: [BoxShadow(color: border.withAlpha(30),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Icon(LucideIcons.heartHandshake, color: icon, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: icon, fontSize: 13)),
          Text(sub, style: TextStyle(color: icon.withAlpha(180), fontSize: 12, height: 1.4)),
        ])),
        Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(onTap: onGetHelp,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(8)),
              child: const Text('Get Help', style: TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w800)))),
          if (onDismiss != null) ...[
            const SizedBox(height: 6),
            GestureDetector(onTap: onDismiss,
              child: const Text('Dismiss', style: TextStyle(fontSize: 10,
                  color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))),
          ],
        ]),
      ]),
    );
  }
}

// ─── Crisis Sheet ─────────────────────────────────────────

void _showCrisisSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 40, height: 40,
              decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
              child: const Icon(LucideIcons.heartHandshake, color: Color(0xFFEF4444), size: 20)),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("You're not alone", style: TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 17, color: Color(0xFF1E293B))),
              Text('Real support, right now',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 20),
          ...[
            ('Kenya Red Cross', '1199', '🆘'),
            ('Befrienders Kenya', '+254 722 178 177', '📞'),
            ('University Counsellor', 'Campus ext 100', '🏫'),
          ].map((h) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(children: [
              Text(h.$3, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.$1, style: const TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 14, color: Color(0xFF1E293B))),
                Text(h.$2, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ])),
              const Icon(LucideIcons.phone, size: 18, color: Color(0xFF00BEB4)),
            ]),
          )),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ─── Full Image Viewer ────────────────────────────────────

class _FullImageViewer extends StatelessWidget {
  final String url;
  const _FullImageViewer({required this.url});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      leading: IconButton(icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
    ),
    body: Center(
      child: InteractiveViewer(
        minScale: 0.5, maxScale: 4.0,
        child: CachedNetworkImage(
          imageUrl: url, fit: BoxFit.contain,
          placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
          errorWidget: (_, __, ___) => const Icon(LucideIcons.imageOff,
              color: Colors.white, size: 48)),
      ),
    ),
  );
}

// ─── Empty Chat State ─────────────────────────────────────

class _EmptyChatState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _EmptyChatState({required this.icon, required this.title,
      required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(60), width: 2)),
          child: Icon(icon, color: color, size: 30)),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800,
            fontSize: 17, color: Color(0xFF1E293B)), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8),
            fontSize: 13, height: 1.5), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ─── Topic Color ──────────────────────────────────────────

Color _topicColor(String topic) {
  const colors = {
    'Anxiety': Color(0xFFF59E0B), 'Anxiety & Stress': Color(0xFFF59E0B),
    'Depression': Color(0xFF6366F1), 'Loneliness': Color(0xFF6366F1),
    'Stress': Color(0xFFEF4444), 'Sleep': Color(0xFF8B5CF6),
    'Sleep Issues': Color(0xFF8B5CF6), 'Relationships': Color(0xFFEC4899),
    'Academic': Color(0xFF3B82F6), 'Academic Pressure': Color(0xFF3B82F6),
    'Self-Care': Color(0xFF10B981), 'General': Color(0xFF00BEB4),
    'General Support': Color(0xFF00BEB4),
  };
  return colors[topic] ?? AppColors.primary;
}
