class DailyArticle {
  final String id;
  final String title;
  final String category;
  final String emoji;
  final String readTime;
  final String summary;
  final String content;
  final String whyForYou;
  final DateTime generatedAt;

  const DailyArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.emoji,
    required this.readTime,
    required this.summary,
    required this.content,
    required this.whyForYou,
    required this.generatedAt,
  });

  factory DailyArticle.fromJson(Map<String, dynamic> json, DateTime generatedAt) =>
      DailyArticle(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? 'Wellness',
        emoji: json['emoji'] as String? ?? '💡',
        readTime: json['readTime'] as String? ?? '3 min read',
        summary: json['summary'] as String? ?? '',
        content: json['content'] as String? ?? '',
        whyForYou: json['whyForYou'] as String? ?? '',
        generatedAt: generatedAt,
      );
}
