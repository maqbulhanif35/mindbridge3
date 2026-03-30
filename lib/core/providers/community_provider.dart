import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_model.dart';

// ─── Anonymous Handle Generator ────────────────────────────

const _adjectives = [
  'Starry', 'Cloudy', 'Brave', 'Gentle', 'Swift', 'Silent', 'Calm',
  'Bright', 'Misty', 'Cozy', 'Daring', 'Quiet', 'Bold', 'Tender', 'Keen',
];
const _animals = [
  'Panda', 'Otter', 'Owl', 'Fox', 'Wolf', 'Deer', 'Crane', 'Seal', 'Lynx',
  'Hare', 'Hawk', 'Bear', 'Finch', 'Moth', 'Wren',
];

String generateAnonHandle() {
  final rng = Random();
  final adj = _adjectives[rng.nextInt(_adjectives.length)];
  final animal = _animals[rng.nextInt(_animals.length)];
  final num = 1000 + rng.nextInt(9000);
  return '$adj$animal#$num';
}

// ─── State ─────────────────────────────────────────────────

class CommunityState {
  final List<CommunityPost> posts;
  final bool isLoading;
  final String? error;
  final int unseenCount;
  final String activeTag;
  final String sortMode; // 'recent' | 'popular' | 'unanswered'
  final String searchQuery;

  const CommunityState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.unseenCount = 0,
    this.activeTag = 'All',
    this.sortMode = 'recent',
    this.searchQuery = '',
  });

  CommunityState copyWith({
    List<CommunityPost>? posts,
    bool? isLoading,
    String? error,
    int? unseenCount,
    String? activeTag,
    String? sortMode,
    String? searchQuery,
  }) {
    return CommunityState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unseenCount: unseenCount ?? this.unseenCount,
      activeTag: activeTag ?? this.activeTag,
      sortMode: sortMode ?? this.sortMode,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<CommunityPost> get filteredPosts {
    var list = activeTag == 'All'
        ? List<CommunityPost>.from(posts)
        : posts.where((p) => p.tag == activeTag).toList();

    // Search filter
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((p) =>
        p.content.toLowerCase().contains(q) ||
        p.tag.toLowerCase().contains(q) ||
        (p.displayName.toLowerCase().contains(q))
      ).toList();
    }

    switch (sortMode) {
      case 'popular':
        list.sort((a, b) => b.totalReactions.compareTo(a.totalReactions));
      case 'unanswered':
        list = list.where((p) => p.commentCount == 0).toList();
      default:
        list.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
    }
    return list;
  }

  List<CommunityPost> get myPosts {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return posts.where((p) => p.userId == uid).toList();
  }

  List<CommunityPost> get savedPosts => posts.where((p) => p.isBookmarked).toList();

  List<CommunityPost> get trendingPosts {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final recent = posts.where((p) => p.createdAt.isAfter(cutoff)).toList();
    recent.sort((a, b) => b.totalReactions.compareTo(a.totalReactions));
    return recent.take(5).toList();
  }
}

// ─── Notifier ──────────────────────────────────────────────

class CommunityNotifier extends AsyncNotifier<CommunityState> {
  SupabaseClient get _sb => Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;

  /// Cached real name for the current user — fetched once on build,
  /// stored here so createPost/addComment can denormalize it into rows.
  String? _myName;

  @override
  Future<CommunityState> build() async {
    // Pre-fetch the current user's display name once
    final uid = _uid;
    if (uid != null) {
      try {
        final profile = await _sb
            .from('profiles')
            .select('name')
            .eq('id', uid)
            .maybeSingle();
        _myName = profile?['name'] as String?;
      } catch (_) {
        // Fallback to auth metadata
        _myName = _sb.auth.currentUser?.userMetadata?['full_name'] as String?;
      }
    }
    final s = await _loadPosts();
    final unseen = await _fetchUnseenCount();
    return s.copyWith(unseenCount: unseen);
  }

  Future<CommunityState> _loadPosts() async {
    try {
      final uid = _uid;

      // Fetch posts with aggregated reaction/comment counts
      final rawData = await _sb.rpc('get_community_posts');

      List<Map<String, dynamic>> rows;
      if (rawData is List) {
        rows = rawData.cast<Map<String, dynamic>>();
      } else {
        rows = [];
      }

      var posts = rows.map(CommunityPost.fromJson).toList();

      if (uid != null) {
        // Fetch user's own reactions
        final rxResp = await _sb
            .from('community_reactions')
            .select('post_id, reaction_type')
            .eq('user_id', uid);
        final reactions = <String, String>{};
        for (final r in (rxResp as List)) {
          reactions[r['post_id'] as String] = r['reaction_type'] as String;
        }

        // Fetch user's bookmarks
        final bkResp = await _sb
            .from('community_bookmarks')
            .select('post_id')
            .eq('user_id', uid);
        final bookmarks = <String>{};
        for (final b in (bkResp as List)) {
          bookmarks.add(b['post_id'] as String);
        }

        // Fetch user's poll votes
        final voteResp = await _sb
            .from('community_poll_votes')
            .select('post_id, option_index')
            .eq('user_id', uid);
        final votes = <String, int>{};
        for (final v in (voteResp as List)) {
          votes[v['post_id'] as String] = v['option_index'] as int;
        }

        posts = posts.map((p) => p.copyWith(
          userReaction: reactions[p.id],
          isBookmarked: bookmarks.contains(p.id),
          userVoteIndex: votes[p.id],
        )).toList();
      }

      return CommunityState(posts: posts, isLoading: false);
    } catch (e) {
      return CommunityState(error: e.toString());
    }
  }

  Future<int> _fetchUnseenCount() async {
    try {
      final uid = _uid;
      if (uid == null) return 0;

      final seenResp = await _sb
          .from('community_last_seen')
          .select('last_seen_at')
          .eq('user_id', uid)
          .maybeSingle();

      if (seenResp == null) return 5; // new user → show some badge

      final lastSeen = DateTime.parse(seenResp['last_seen_at'] as String);
      final countResp = await _sb
          .from('community_posts')
          .select('id')
          .gt('created_at', lastSeen.toIso8601String());

      return (countResp as List).length;
    } catch (_) {
      return 0;
    }
  }

  // ── Public actions ──────────────────────────────────────

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _loadPosts());
  }

  void setTag(String tag) {
    state = state.whenData((s) => s.copyWith(activeTag: tag));
  }

  void setSortMode(String mode) {
    state = state.whenData((s) => s.copyWith(sortMode: mode));
  }

  void setSearch(String query) {
    state = state.whenData((s) => s.copyWith(searchQuery: query));
  }

  Future<void> createPost({
    required String content,
    required String tag,
    required String postType,
    required bool isAnonymous,
    int? moodScore,
    List<PollOption>? pollOptions,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    await _sb.from('community_posts').insert({
      'user_id': uid,
      'content': content,
      'tag': tag,
      'post_type': postType,
      'is_anonymous': isAnonymous,
      'anon_handle': isAnonymous ? generateAnonHandle() : null,
      // Store real name denormalized — never null for non-anon posts
      'author_name': isAnonymous ? null : _myName,
      'mood_score': moodScore,
      'poll_options': pollOptions?.map((p) => p.toJson()).toList(),
    });

    await refresh();
  }

  Future<void> toggleReaction(String postId, String reactionType) async {
    final uid = _uid;
    if (uid == null) return;

    final current = state.value;
    if (current == null) return;

    final post = current.posts.firstWhere((p) => p.id == postId);
    final alreadyReacted = post.userReaction == reactionType;

    // Optimistic update
    final newReactions = Map<String, int>.from(post.reactions);
    if (alreadyReacted) {
      newReactions[reactionType] = (newReactions[reactionType] ?? 1) - 1;
    } else {
      // Remove old reaction count if switching
      if (post.userReaction != null) {
        newReactions[post.userReaction!] =
            (newReactions[post.userReaction!] ?? 1) - 1;
        await _sb
            .from('community_reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', uid);
      }
      newReactions[reactionType] = (newReactions[reactionType] ?? 0) + 1;
    }

    final updatedPost = post.copyWith(
      reactions: newReactions,
      userReaction: alreadyReacted ? null : reactionType,
      clearReaction: alreadyReacted,
    );

    final updatedPosts =
        current.posts.map((p) => p.id == postId ? updatedPost : p).toList();
    state = AsyncData(current.copyWith(posts: updatedPosts));

    // Persist to Supabase
    try {
      if (alreadyReacted) {
        await _sb
            .from('community_reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', uid)
            .eq('reaction_type', reactionType);
      } else {
        await _sb.from('community_reactions').upsert({
          'post_id': postId,
          'user_id': uid,
          'reaction_type': reactionType,
        });
      }
    } catch (_) {
      // Revert on error
      state = AsyncData(current);
    }
  }

  Future<void> toggleBookmark(String postId) async {
    final uid = _uid;
    if (uid == null) return;

    final current = state.value;
    if (current == null) return;

    final post = current.posts.firstWhere((p) => p.id == postId);
    final wasBookmarked = post.isBookmarked;

    // Optimistic update
    final updatedPost = post.copyWith(isBookmarked: !wasBookmarked);
    final updatedPosts =
        current.posts.map((p) => p.id == postId ? updatedPost : p).toList();
    state = AsyncData(current.copyWith(posts: updatedPosts));

    try {
      if (wasBookmarked) {
        await _sb
            .from('community_bookmarks')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', uid);
      } else {
        await _sb.from('community_bookmarks')
            .upsert({'post_id': postId, 'user_id': uid});
      }
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> votePoll(String postId, int optionIndex) async {
    final uid = _uid;
    if (uid == null) return;

    final current = state.value;
    if (current == null) return;

    final post = current.posts.firstWhere((p) => p.id == postId);
    if (post.userVoteIndex != null) return; // already voted

    // Optimistic update
    final newOptions = post.pollOptions!.asMap().entries.map((e) {
      return e.key == optionIndex
          ? e.value.copyWith(votes: e.value.votes + 1)
          : e.value;
    }).toList();

    final updatedPost = post.copyWith(
      pollOptions: newOptions,
      userVoteIndex: optionIndex,
    );
    final updatedPosts =
        current.posts.map((p) => p.id == postId ? updatedPost : p).toList();
    state = AsyncData(current.copyWith(posts: updatedPosts));

    try {
      await _sb.from('community_poll_votes').insert({
        'post_id': postId,
        'user_id': uid,
        'option_index': optionIndex,
      });
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> markSeen() async {
    final uid = _uid;
    if (uid == null) return;

    state = state.whenData((s) => s.copyWith(unseenCount: 0));

    try {
      await _sb.from('community_last_seen').upsert({
        'user_id': uid,
        'last_seen_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<List<CommunityComment>> fetchComments(String postId) async {
    try {
      // author_name is now stored directly on each row — no join needed
      final resp = await _sb
          .from('community_comments')
          .select()
          .eq('post_id', postId)
          .order('created_at');
      return (resp as List)
          .map((j) => CommunityComment.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addComment({
    required String postId,
    required String content,
    required bool isAnonymous,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    await _sb.from('community_comments').insert({
      'post_id': postId,
      'user_id': uid,
      'content': content,
      'is_anonymous': isAnonymous,
      'anon_handle': isAnonymous ? generateAnonHandle() : null,
      // Store real name denormalized at write time
      'author_name': isAnonymous ? null : _myName,
    });

    // Bump local comment count so the card updates immediately
    final current = state.value;
    if (current != null) {
      final updatedPosts = current.posts.map((p) {
        if (p.id == postId) return p.copyWith(commentCount: p.commentCount + 1);
        return p;
      }).toList();
      state = AsyncData(current.copyWith(posts: updatedPosts));
    }
  }

  Future<void> deletePost(String postId) async {
    final uid = _uid;
    if (uid == null) return;
    final current = state.value;
    if (current == null) return;

    // Optimistic remove
    final updatedPosts = current.posts.where((p) => p.id != postId).toList();
    state = AsyncData(current.copyWith(posts: updatedPosts));

    try {
      await _sb.from('community_posts').delete().eq('id', postId).eq('user_id', uid);
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> deleteComment(String commentId, String postId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _sb.from('community_comments').delete().eq('id', commentId).eq('user_id', uid);
      // Decrement local comment count
      final current = state.value;
      if (current != null) {
        final updatedPosts = current.posts.map((p) {
          if (p.id == postId) return p.copyWith(commentCount: (p.commentCount - 1).clamp(0, 9999));
          return p;
        }).toList();
        state = AsyncData(current.copyWith(posts: updatedPosts));
      }
    } catch (_) {}
  }

  Future<void> requestPeerSupport({required String topic, String? note}) async {
    final uid = _uid;
    if (uid == null) return;
    await _sb.from('peer_support_requests').insert({
      'requester_id': uid,
      'topic': topic,
      'note': note,
    });
  }
}

// ─── Providers ─────────────────────────────────────────────

final communityProvider =
    AsyncNotifierProvider<CommunityNotifier, CommunityState>(
  CommunityNotifier.new,
);

/// Lightweight provider just for the unseen badge count — watched by nav bar
final communityUnseenCountProvider = Provider<int>((ref) {
  return ref.watch(communityProvider).whenOrNull(data: (s) => s.unseenCount) ?? 0;
});
