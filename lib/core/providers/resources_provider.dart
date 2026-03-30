import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resource_model.dart';
import '../providers/mood_provider.dart';
import '../providers/auth_provider.dart';

// ─── State ────────────────────────────────────────────────

class ResourcesState {
  final Set<String> bookmarkedIds;
  final Set<String> completedIds;
  final Map<String, bool> ratings; // id -> true=helpful, false=not helpful
  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const ResourcesState({
    this.bookmarkedIds = const {},
    this.completedIds = const {},
    this.ratings = const {},
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  });

  ResourcesState copyWith({
    Set<String>? bookmarkedIds,
    Set<String>? completedIds,
    Map<String, bool>? ratings,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    String? error,
  }) => ResourcesState(
    bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
    completedIds: completedIds ?? this.completedIds,
    ratings: ratings ?? this.ratings,
    selectedCategory: selectedCategory ?? this.selectedCategory,
    searchQuery: searchQuery ?? this.searchQuery,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );

  // Derived lists
  List<ResourceItem> get filteredResources {
    var list = selectedCategory == 'All'
        ? List<ResourceItem>.from(kResources)
        : kResources.where((r) => r.category == selectedCategory).toList();

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((r) =>
        r.title.toLowerCase().contains(q) ||
        r.description.toLowerCase().contains(q) ||
        r.category.toLowerCase().contains(q) ||
        r.subtitle.toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  List<ResourceItem> get bookmarkedResources =>
      kResources.where((r) => bookmarkedIds.contains(r.id)).toList();

  List<ResourceItem> get featuredResources =>
      kResources.where((r) => r.isFeatured).toList();

  List<ResourceItem> get exerciseResources =>
      kResources.where((r) => r.type == 'exercise').toList();

  ResourceItem? get crisisResource =>
      kResources.where((r) => r.type == 'crisis').firstOrNull;

  int get totalXp => completedIds.fold(0, (sum, id) {
    final item = kResources.where((r) => r.id == id).firstOrNull;
    return sum + (item?.xp ?? 0);
  });

  int get weeklyReadCount {
    // In a real scenario this would filter by date; simplified for now
    return completedIds.length;
  }

  /// Smart personalized picks based on user mood + goals
  List<ResourceItem> personalizedFor({
    required int? todayMood,
    required List<String> emotions,
    required List<String> goals,
  }) {
    final moodScore = todayMood ?? 5;

    // Map goal strings to categories
    final goalCats = goals.map((g) {
      final gl = g.toLowerCase();
      if (gl.contains('anxiety')) return 'Anxiety';
      if (gl.contains('depression') || gl.contains('motivation')) return 'Depression';
      if (gl.contains('stress') || gl.contains('academic')) return 'Stress';
      if (gl.contains('sleep')) return 'Sleep';
      if (gl.contains('social') || gl.contains('relationship')) return 'Relationships';
      if (gl.contains('self') || gl.contains('confidence')) return 'Self-Esteem';
      return null;
    }).whereType<String>().toSet();

    // Score each resource
    final scored = <ResourceItem, int>{};
    for (final r in kResources) {
      if (r.type == 'crisis') continue;
      int score = 0;

      // Featured always gets some weight
      if (r.isFeatured) score += 2;
      if (r.isHot) score += 1;

      // Mood-based
      if (moodScore <= 3 && ['Depression', 'Anxiety', 'Crisis'].contains(r.category)) score += 5;
      if (moodScore <= 5 && ['Stress', 'Anxiety', 'Sleep'].contains(r.category)) score += 3;
      if (moodScore >= 7 && ['Self-Esteem', 'Relationships', 'Campus Life'].contains(r.category)) score += 2;

      // Emotion-based
      final em = emotions.map((e) => e.toLowerCase()).toSet();
      if (em.any(['anxious', 'stressed', 'overwhelmed', 'nervous'].contains) && r.category == 'Anxiety') score += 4;
      if (em.any(['sad', 'hopeless', 'empty', 'down'].contains) && r.category == 'Depression') score += 4;
      if (em.any(['tired', 'exhausted', 'low energy'].contains) && r.category == 'Sleep') score += 3;
      if (em.any(['lonely', 'isolated'].contains) && r.category == 'Relationships') score += 3;

      // Goal-based
      if (goalCats.contains(r.category)) score += 3;

      // Exercises always relevant
      if (r.type == 'exercise') score += 1;

      // Not already completed
      if (completedIds.contains(r.id)) score = (score - 2).clamp(0, 100);

      scored[r] = score;
    }

    final sorted = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = sorted.where((e) => e.value > 0).map((e) => e.key).toList();
    return result.isEmpty ? kResources.where((r) => r.isFeatured).toList() : result;
  }
}

// ─── Notifier ─────────────────────────────────────────────

class ResourcesNotifier extends AsyncNotifier<ResourcesState> {
  SupabaseClient get _sb => Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;

  @override
  Future<ResourcesState> build() async {
    final uid = _uid;
    if (uid == null) return const ResourcesState();

    try {
      final results = await Future.wait([
        _sb.from('resource_bookmarks').select('resource_id').eq('user_id', uid),
        _sb.from('resource_reads').select('resource_id, rating').eq('user_id', uid),
      ]);

      final bookmarks = <String>{};
      for (final b in (results[0] as List)) {
        bookmarks.add(b['resource_id'] as String);
      }

      final completed = <String>{};
      final ratings = <String, bool>{};
      for (final r in (results[1] as List)) {
        final id = r['resource_id'] as String;
        completed.add(id);
        if (r['rating'] != null) {
          ratings[id] = (r['rating'] as int) == 1;
        }
      }

      return ResourcesState(
        bookmarkedIds: bookmarks,
        completedIds: completed,
        ratings: ratings,
      );
    } catch (_) {
      return const ResourcesState();
    }
  }

  // ── Actions ───────────────────────────────────────────────

  Future<void> toggleBookmark(String resourceId) async {
    final uid = _uid;
    if (uid == null) return;

    final current = state.value ?? const ResourcesState();
    final wasBookmarked = current.bookmarkedIds.contains(resourceId);

    final newSet = Set<String>.from(current.bookmarkedIds);
    if (wasBookmarked) {
      newSet.remove(resourceId);
    } else {
      newSet.add(resourceId);
    }
    state = AsyncData(current.copyWith(bookmarkedIds: newSet));

    try {
      if (wasBookmarked) {
        await _sb.from('resource_bookmarks')
            .delete()
            .eq('user_id', uid)
            .eq('resource_id', resourceId);
      } else {
        await _sb.from('resource_bookmarks')
            .upsert({'user_id': uid, 'resource_id': resourceId});
      }
    } catch (_) {
      state = AsyncData(current); // revert
    }
  }

  Future<void> markComplete(String resourceId, {bool? helpful}) async {
    final uid = _uid;
    if (uid == null) return;

    final current = state.value ?? const ResourcesState();
    final newCompleted = Set<String>.from(current.completedIds)..add(resourceId);
    final newRatings = Map<String, bool>.from(current.ratings);
    if (helpful != null) newRatings[resourceId] = helpful;

    state = AsyncData(current.copyWith(completedIds: newCompleted, ratings: newRatings));

    try {
      await _sb.from('resource_reads').upsert({
        'user_id': uid,
        'resource_id': resourceId,
        'completed_at': DateTime.now().toIso8601String(),
        if (helpful != null) 'rating': helpful ? 1 : -1,
      });
    } catch (_) {}
  }

  void setCategory(String category) {
    state = state.whenData((s) => s.copyWith(selectedCategory: category));
  }

  void setSearch(String query) {
    state = state.whenData((s) => s.copyWith(searchQuery: query));
  }
}

// ─── Providers ────────────────────────────────────────────

final resourcesProvider =
    AsyncNotifierProvider<ResourcesNotifier, ResourcesState>(
  ResourcesNotifier.new,
);

/// Lightweight provider for completed count — watched by other screens
final resourcesCompletedCountProvider = Provider<int>((ref) {
  return ref.watch(resourcesProvider).whenOrNull(data: (s) => s.completedIds.length) ?? 0;
});

/// Personalized resource picks based on current mood + auth profile
final personalizedResourcesProvider = Provider<List<ResourceItem>>((ref) {
  final resState = ref.watch(resourcesProvider).value;
  if (resState == null) return kResources.where((r) => r.isFeatured).toList();

  final moodState = ref.watch(moodProvider);
  final authState = ref.watch(authProvider);

  return resState.personalizedFor(
    todayMood: moodState.todayEntry?.moodScore,
    emotions: moodState.todayEntry?.emotions ?? [],
    goals: authState.user?.goals ?? [],
  );
});
